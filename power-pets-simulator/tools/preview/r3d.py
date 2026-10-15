"""Простой 3D-растеризатор (алгоритм художника) для проверки сцен и ViewportFrame."""
import math
import numpy as np
from PIL import Image, ImageDraw


def cframe(v):
    pos = np.array(v[:3], dtype=float)
    rot = np.array(v[3:12], dtype=float).reshape(3, 3)
    return pos, rot


BOX_FACES = [
    ([0, 1, 3, 2], (-1, 0, 0)), ([4, 6, 7, 5], (1, 0, 0)),
    ([0, 4, 5, 1], (0, -1, 0)), ([2, 3, 7, 6], (0, 1, 0)),
    ([0, 2, 6, 4], (0, 0, -1)), ([1, 5, 7, 3], (0, 0, 1)),
]
BOX_VERTS = np.array([[x, y, z] for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.5, 0.5)])


def box_polys(size):
    v = BOX_VERTS * size
    return [(v[idx], np.array(n, float)) for idx, n in BOX_FACES]


def wedge_polys(size):
    sx, sy, sz = size / 2
    a = np.array([-sx, -sy, -sz]); b = np.array([sx, -sy, -sz])
    c = np.array([-sx, -sy, sz]); d = np.array([sx, -sy, sz])
    e = np.array([-sx, sy, sz]); f = np.array([sx, sy, sz])
    slope_n = np.array([0, size[2], -size[1]], float)
    slope_n /= np.linalg.norm(slope_n)
    return [
        (np.array([a, b, d, c]), np.array([0, -1, 0.0])),
        (np.array([c, d, f, e]), np.array([0, 0, 1.0])),
        (np.array([a, e, f, b]), slope_n),
        (np.array([a, c, e]), np.array([-1, 0, 0.0])),
        (np.array([b, f, d]), np.array([1, 0, 0.0])),
    ]


def ellipsoid_polys(radii, seg=10):
    polys = []
    rings = seg // 2 + 1
    for i in range(rings - 1):
        t0, t1 = math.pi * i / (rings - 1), math.pi * (i + 1) / (rings - 1)
        for j in range(seg):
            p0, p1 = 2 * math.pi * j / seg, 2 * math.pi * (j + 1) / seg
            pts = []
            for t, p in ((t0, p0), (t0, p1), (t1, p1), (t1, p0)):
                pts.append([math.sin(t) * math.cos(p), math.cos(t), math.sin(t) * math.sin(p)])
            pts = np.array(pts)
            n = pts.mean(axis=0)
            n /= np.linalg.norm(n) + 1e-9
            polys.append((pts * radii, n / radii / np.linalg.norm(n / radii)))
    return polys


def cylinder_polys(length, radius, seg=14):
    """Цилиндр Roblox: ось по локальной X."""
    polys = []
    h = length / 2
    for j in range(seg):
        a0, a1 = 2 * math.pi * j / seg, 2 * math.pi * (j + 1) / seg
        y0, z0, y1, z1 = math.cos(a0) * radius, math.sin(a0) * radius, math.cos(a1) * radius, math.sin(a1) * radius
        quad = np.array([[-h, y0, z0], [h, y0, z0], [h, y1, z1], [-h, y1, z1]])
        n = np.array([0, math.cos((a0 + a1) / 2), math.sin((a0 + a1) / 2)])
        polys.append((quad, n))
    cap = [[0, math.cos(2 * math.pi * j / seg) * radius, math.sin(2 * math.pi * j / seg) * radius] for j in range(seg)]
    cap = np.array(cap)
    polys.append((cap + [h, 0, 0], np.array([1.0, 0, 0])))
    polys.append(((cap + [-h, 0, 0])[::-1], np.array([-1.0, 0, 0])))
    return polys


def part_polys(part):
    """part: dict(class, size, cf, shape, mesh) -> список (мировые вершины, мировая нормаль)."""
    size = np.array(part["size"], float)
    pos, rot = cframe(part["cf"])
    cls = part["class"]
    mesh = part.get("mesh")
    shape = part.get("shape") or "Block"
    if mesh and mesh.get("type") == "Sphere":
        scale = np.array(mesh.get("scale", [1, 1, 1]), float)
        local = ellipsoid_polys(size * scale / 2)
    elif cls == "WedgePart":
        local = wedge_polys(size)
    elif shape == "Ball":
        r = size.min() / 2
        local = ellipsoid_polys(np.array([r, r, r]))
    elif shape == "Cylinder":
        local = cylinder_polys(size[0], min(size[1], size[2]) / 2)
    else:
        local = box_polys(size)
    out = []
    for verts, n in local:
        out.append((verts @ rot.T + pos, rot @ n))
    return out


class Camera:
    def __init__(self, pos, rot, fov_deg, width, height):
        self.pos = np.array(pos, float)
        self.rot = np.array(rot, float)
        self.f = 1 / math.tan(math.radians(fov_deg) / 2)
        self.w, self.h = width, height

    @staticmethod
    def look_at(eye, target, fov, width, height):
        eye, target = np.array(eye, float), np.array(target, float)
        back = eye - target
        back /= np.linalg.norm(back)
        right = np.cross([0, 1, 0], back)
        right /= np.linalg.norm(right)
        up = np.cross(back, right)
        rot = np.stack([right, up, back], axis=1)
        return Camera(eye, rot, fov, width, height)

    def to_cam(self, pts):
        return (pts - self.pos) @ self.rot

    def project(self, pc):
        z = -pc[:, 2]
        aspect = self.w / self.h
        x = pc[:, 0] / z * self.f / aspect
        y = pc[:, 1] / z * self.f
        return np.stack([(x + 1) / 2 * self.w, (1 - y) / 2 * self.h], axis=1)


def clip_near(pc, near=0.1):
    out = []
    n = len(pc)
    for i in range(n):
        a, b = pc[i], pc[(i + 1) % n]
        ina, inb = a[2] < -near, b[2] < -near
        if ina:
            out.append(a)
        if ina != inb:
            t = (-near - a[2]) / (b[2] - a[2])
            out.append(a + (b - a) * t)
    return np.array(out) if len(out) >= 3 else None


def _raster(tri, depth, rgba, zbuf, cbuf, blend):
    H, W = zbuf.shape
    x0 = max(int(np.floor(tri[:, 0].min())), 0)
    x1 = min(int(np.ceil(tri[:, 0].max())), W - 1)
    y0 = max(int(np.floor(tri[:, 1].min())), 0)
    y1 = min(int(np.ceil(tri[:, 1].max())), H - 1)
    if x1 < x0 or y1 < y0:
        return
    (ax, ay), (bx, by), (cx, cy) = tri
    area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
    if abs(area) < 1e-9:
        return
    ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1]
    px, py = xs + 0.5, ys + 0.5
    w0 = ((bx - px) * (cy - py) - (by - py) * (cx - px)) / area
    w1 = ((cx - px) * (ay - py) - (cy - py) * (ax - px)) / area
    w2 = 1 - w0 - w1
    inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
    if not inside.any():
        return
    iz = w0 / depth[0] + w1 / depth[1] + w2 / depth[2]
    z = 1 / np.maximum(iz, 1e-9)
    region_z = zbuf[y0:y1 + 1, x0:x1 + 1]
    mask = inside & (z < region_z)
    if not mask.any():
        return
    region_c = cbuf[y0:y1 + 1, x0:x1 + 1]
    if blend:
        a = rgba[3]
        region_c[mask, :3] = region_c[mask, :3] * (1 - a) + np.array(rgba[:3]) * a
        region_c[mask, 3] = region_c[mask, 3] * (1 - a) + a
    else:
        region_z[mask] = z[mask]
        region_c[mask] = rgba


def render(polys, cam, background, light_dir, ambient, light_color, fog=None, ss=2, image=None, skip_backface=True):
    """Z-буфер. polys: список dict(verts, normal, color(0..1), alpha, emissive). Возвращает RGBA-картинку."""
    W, H = cam.w * ss, cam.h * ss
    big = Camera(cam.pos, cam.rot, 60, W, H)
    big.f = cam.f
    zbuf = np.full((H, W), np.inf)
    cbuf = np.zeros((H, W, 4))
    if image is not None:
        cbuf[:] = np.array(image.convert("RGBA").resize((W, H)), dtype=float) / 255
    else:
        cbuf[:] = np.array(background, dtype=float) / 255
    L = -np.array(light_dir, float)
    L /= np.linalg.norm(L)
    amb = np.array(ambient, float)
    lc = np.array(light_color, float)
    opaque, glass = [], []
    for p in polys:
        verts = p["verts"]
        center = verts.mean(axis=0)
        n = p["normal"]
        to_cam = cam.pos - center
        alpha = p.get("alpha", 1)
        if skip_backface and np.dot(n, to_cam) <= 0 and alpha >= 0.99:
            continue
        pc = big.to_cam(verts)
        if np.all(pc[:, 2] > -0.1):
            continue
        if np.any(pc[:, 2] > -0.1):
            pc = clip_near(pc)
            if pc is None:
                continue
        color = np.array(p["color"], float)
        if p.get("emissive"):
            shade = color * 1.15
        else:
            nn = n if np.dot(n, to_cam) > 0 else -n
            shade = color * (amb + lc * max(0.0, float(np.dot(nn, L))))
        if fog is not None:
            fog_color, density = fog
            k = 1 - math.exp(-density * np.linalg.norm(to_cam))
            shade = shade * (1 - k) + np.array(fog_color) * k
        rgba = (min(1, shade[0]), min(1, shade[1]), min(1, shade[2]), alpha)
        xy = big.project(pc)
        if np.max(np.abs(xy)) > 1e6:
            continue
        depth = -pc[:, 2]
        item = (xy, depth, rgba)
        if alpha >= 0.99:
            opaque.append(item)
        else:
            glass.append((float(depth.mean()), item))
    for xy, depth, rgba in opaque:
        for i in range(1, len(xy) - 1):
            idx = [0, i, i + 1]
            _raster(xy[idx], depth[idx], rgba, zbuf, cbuf, False)
    glass.sort(key=lambda g: -g[0])
    for _, (xy, depth, rgba) in glass:
        for i in range(1, len(xy) - 1):
            idx = [0, i, i + 1]
            _raster(xy[idx], depth[idx], rgba, zbuf, cbuf, True)
    img = Image.fromarray(np.clip(cbuf * 255, 0, 255).astype(np.uint8), "RGBA")
    return img.resize((cam.w, cam.h), Image.LANCZOS)
