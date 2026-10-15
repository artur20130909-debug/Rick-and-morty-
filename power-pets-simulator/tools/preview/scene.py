"""Рендер миров из дампа мока: рельеф (по журналу заливок Terrain) + все детали + свет мира."""
import math
import sys
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

import gui
import r3d

TERRAIN_COLORS = {
    "Grass": (96, 196, 70), "LeafyGrass": (80, 200, 90), "Ground": (176, 128, 80), "Cobblestone": (190, 182, 168),
    "Sand": (245, 212, 150), "Sandstone": (222, 166, 104), "Limestone": (238, 222, 190), "Rock": (128, 122, 140),
    "Snow": (235, 240, 255), "Basalt": (78, 60, 122), "Slate": (70, 58, 108), "Pavement": (150, 150, 185),
    "Glacier": (150, 210, 255), "CrackedLava": (255, 110, 200), "Mud": (110, 80, 60), "Salt": (240, 240, 240),
}
WORLDS = {
    "Forest": dict(origin=(0, 0, 0), sky_top=(95, 160, 235), horizon=(205, 236, 255), sun=(-0.45, -0.8, 0.4), sun_color=(0.62, 0.6, 0.55),
                   ambient=(0.5, 0.53, 0.5), water=(40, 160, 190), water_a=0.55, fog=0.0018, sat=1.28, contrast=1.12, stars=False),
    "Desert": dict(origin=(2000, 0, 0), sky_top=(110, 175, 240), horizon=(255, 226, 170), sun=(-0.3, -0.9, 0.3), sun_color=(0.6, 0.57, 0.5),
                   ambient=(0.55, 0.5, 0.45), water=(30, 200, 210), water_a=0.5, fog=0.0022, sat=1.22, contrast=1.14, stars=False),
    "Space": dict(origin=(4000, 60, 0), sky_top=(14, 8, 36), horizon=(70, 45, 130), sun=(0.4, -0.8, -0.45), sun_color=(0.45, 0.45, 0.6),
                  ambient=(0.5, 0.42, 0.65), water=(110, 80, 220), water_a=0.4, fog=0.0012, sat=1.3, contrast=1.16, stars=True),
}


def collect(node, out, skip_names=("Wall",)):
    for c in node["children"]:
        cls = c["class"]
        if cls in ("Part", "WedgePart", "SpawnLocation", "MeshPart", "CornerWedgePart", "TrussPart", "Seat"):
            t = gui.P(c, "Transparency", 0)
            if t < 0.98 and gui.P(c, "Name", "") not in skip_names:
                mesh = None
                for mc in c["children"]:
                    if mc["class"] == "SpecialMesh":
                        mesh = {"type": gui.P(mc, "MeshType", "Head"), "scale": gui.P(mc, "Scale", [1, 1, 1])}
                out.append({
                    "class": cls, "size": gui.P(c, "Size", [4, 1, 2]), "cf": gui.P(c, "CFrame"),
                    "shape": gui.P(c, "Shape", "Block"), "mesh": mesh, "color": gui.color(gui.P(c, "Color"), (0.64, 0.64, 0.64)),
                    "transparency": t, "material": gui.P(c, "Material", "Plastic"),
                })
        if cls not in ("Terrain", "Camera"):
            collect(c, out, skip_names)
    return out


def terrain_mesh(fills, origin, half=260, res=2.0, ylo=-70, yhi=80, water_rgb=(40, 160, 190), water_a=0.5):
    ox, oy, oz = origin
    xs = np.arange(ox - half, ox + half + 0.01, res)
    zs = np.arange(oz - half, oz + half + 0.01, res)
    ys = np.arange(oy + ylo, oy + yhi, 1.0) + 0.5
    names = ["Air"] + sorted(set(f["m"] for f in fills))
    mid = {n: i for i, n in enumerate(names)}
    vox = np.zeros((len(xs), len(zs), len(ys)), dtype=np.uint8)
    X, Z = np.meshgrid(xs, zs, indexing="ij")
    for f in fills:
        cx, cy, cz = f["c"]
        if abs(cx - ox) > half + 200 or abs(cz - oz) > half + 200:
            continue
        m = mid[f["m"]]
        if f["k"] == "Block":
            sx, sy, sz = f["s"]
            col = (np.abs(X - cx) <= sx / 2) & (np.abs(Z - cz) <= sz / 2)
            lo = np.full(X.shape, cy - sy / 2); hi = np.full(X.shape, cy + sy / 2)
        elif f["k"] == "Ball":
            d2 = (X - cx) ** 2 + (Z - cz) ** 2
            col = d2 < f["r"] ** 2
            h = np.sqrt(np.maximum(f["r"] ** 2 - d2, 0))
            lo, hi = cy - h, cy + h
        else:
            col = (X - cx) ** 2 + (Z - cz) ** 2 < f["r"] ** 2
            lo = np.full(X.shape, cy - f["h"] / 2); hi = np.full(X.shape, cy + f["h"] / 2)
        if not col.any():
            continue
        yy = ys[None, None, :]
        inside = col[:, :, None] & (yy >= lo[:, :, None]) & (yy <= hi[:, :, None])
        vox[inside] = m
    water_id = mid.get("Water", -1)
    solid = (vox != 0) & (vox != water_id)
    has_solid = solid.any(axis=2)
    top_idx = np.where(has_solid, len(ys) - 1 - np.argmax(solid[:, :, ::-1], axis=2), 0)
    top_h = np.where(has_solid, ys[top_idx] + 0.5, np.nan)
    top_m = np.take_along_axis(vox, top_idx[:, :, None], axis=2)[:, :, 0]
    water = vox == water_id
    has_water = water.any(axis=2)
    w_idx = len(ys) - 1 - np.argmax(water[:, :, ::-1], axis=2)
    water_h = np.where(has_water, ys[w_idx] + 0.5, np.nan)

    polys = []
    rng = np.random.default_rng(5)
    nx, nz = len(xs), len(zs)
    for i in range(nx - 1):
        for j in range(nz - 1):
            hs = [top_h[i, j], top_h[i + 1, j], top_h[i + 1, j + 1], top_h[i, j + 1]]
            if any(np.isnan(h) for h in hs):
                continue
            name = names[top_m[i, j]]
            shade = 0.94 + 0.12 * rng.random()
            base = np.array(TERRAIN_COLORS.get(name, (150, 150, 150)), float) / 255 * shade
            pts = np.array([[xs[i], hs[0], zs[j]], [xs[i + 1], hs[1], zs[j]], [xs[i + 1], hs[2], zs[j + 1]], [xs[i], hs[3], zs[j + 1]]])
            cols = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            for tri in ((0, 3, 2), (0, 2, 1)):
                v = pts[list(tri)]
                n = np.cross(v[1] - v[0], v[2] - v[0])
                ln = np.linalg.norm(n)
                if ln < 1e-9:
                    continue
                n = n / ln
                if n[1] < 0:
                    n = -n
                color = base
                if n[1] < 0.55:
                    # крутой склон: материал берём из толщи на высоте середины треугольника
                    ci, cj = max((cols[k] for k in tri), key=lambda c: top_h[c])
                    yi = int(np.clip(round(v[:, 1].mean() - 1.5 - ys[0]), 0, len(ys) - 1))
                    mname = names[vox[ci, cj, yi]]
                    if mname not in ("Air", "Water"):
                        color = np.array(TERRAIN_COLORS.get(mname, (150, 150, 150)), float) / 255 * shade
                polys.append({"verts": v, "normal": n, "color": color, "alpha": 1})
    for i in range(nx - 1):
        for j in range(nz - 1):
            if has_water[i, j] and has_water[i + 1, j + 1]:
                h = water_h[i, j]
                v = np.array([[xs[i], h, zs[j]], [xs[i + 1], h, zs[j]], [xs[i + 1], h, zs[j + 1]], [xs[i], h, zs[j + 1]]])
                polys.append({"verts": v, "normal": np.array([0, 1.0, 0]), "color": np.array(water_rgb) / 255, "alpha": water_a})
    def ground(x, z):
        i, j = int(round((x - xs[0]) / res)), int(round((z - zs[0]) / res))
        if 0 <= i < nx and 0 <= j < nz:
            return top_h[i, j]
        return np.nan
    return polys, ground


def sky_image(cam, top, horizon, stars):
    W, H = cam.w, cam.h
    ys = (np.arange(H) + 0.5) / H
    xs = (np.arange(W) + 0.5) / W
    yv = (1 - 2 * ys) / cam.f
    xv = (2 * xs - 1) * (W / H) / cam.f
    dirs_y = []
    for y in yv:
        d = cam.rot @ np.array([0, y, -1.0])
        dirs_y.append(d[1] / np.linalg.norm(d))
    t = np.clip(np.array(dirs_y) * 2.2, 0, 1)[:, None]
    col = np.array(horizon)[None, :] * (1 - t) + np.array(top)[None, :] * t
    img = np.repeat(col[:, None, :], W, axis=1)
    if stars:
        rng = np.random.default_rng(3)
        for _ in range(900):
            x, y = rng.integers(0, W), rng.integers(0, H)
            img[y, x] = (255, 255, 255) if rng.random() < 0.7 else (200, 180, 255)
    a = np.dstack([np.clip(img, 0, 255), np.full((H, W), 255)]).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def post(img, cfg):
    rgb = img.convert("RGB")
    arr = np.array(rgb).astype(float)
    bright = np.clip((arr.max(axis=2) - 240) / 15, 0, 1)[..., None] * arr
    glow = Image.fromarray(bright.astype(np.uint8)).filter(ImageFilter.GaussianBlur(9))
    arr = np.clip(arr + np.array(glow).astype(float) * 0.35, 0, 255)
    rgb = Image.fromarray(arr.astype(np.uint8))
    rgb = ImageEnhance.Color(rgb).enhance(cfg["sat"])
    rgb = ImageEnhance.Contrast(rgb).enhance(cfg["contrast"])
    return rgb


def render_world(dumps, world_id, views, out_prefix, size=(1280, 720)):
    cfg = WORLDS[world_id]
    ws = dumps["workspace"]
    worlds_node = [c for c in ws["children"] if gui.P(c, "Name") == "Worlds"][0]
    wnode = [c for c in worlds_node["children"] if gui.P(c, "Name") == world_id][0]
    parts = collect(wnode, [])
    tpolys, ground = terrain_mesh(dumps["terrain"], cfg["origin"], water_rgb=cfg["water"], water_a=cfg["water_a"])
    polys = list(tpolys)
    for p in parts:
        for verts, n in r3d.part_polys(p):
            polys.append({"verts": verts, "normal": n, "color": p["color"], "alpha": 1 - p["transparency"],
                          "emissive": p["material"] == "Neon"})
    print(world_id, "деталей:", len(parts), "полигонов:", len(polys))
    ox, oy, oz = cfg["origin"]
    for name, (eye, target, fov) in views.items():
        eye = np.array(eye, float) + [ox, 0, oz]
        target = np.array(target, float) + [ox, 0, oz]
        gy = ground(eye[0], eye[2])
        gy = oy if np.isnan(gy) else gy
        eye[1] += gy
        target[1] += gy
        cam = r3d.Camera.look_at(eye, target, fov, *size)
        sky = sky_image(cam, cfg["sky_top"], cfg["horizon"], cfg["stars"])
        img = r3d.render(polys, cam, (0, 0, 0, 255), cfg["sun"], cfg["ambient"], cfg["sun_color"],
                         fog=(np.array(cfg["horizon"]) / 255, cfg["fog"]), ss=1, image=sky)
        post(img, cfg).save(f"{out_prefix}_{world_id}_{name}.png")


if __name__ == "__main__":
    src = sys.argv[1]
    which = sys.argv[2].split(",") if len(sys.argv) > 2 else ["Forest", "Desert", "Space"]
    dumps = gui.load_dumps(src)
    views = {
        "player": ((0, 11, 92), (0, 4, 40), 70),
        "overview": ((0, 150, 260), (0, 0, -20), 60),
        "far": ((-260, 120, -230), (0, 0, 0), 60),
    }
    for w in which:
        render_world(dumps, w, views, "scene")
