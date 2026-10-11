# Превью карты сверху по выгрузке из песочницы:
#   python3 tools/run_map.py --json map.json
#   python3 tools/preview.py map.json out.png [--scale 1] [--crop x0 z0 x1 z1] [--labels]
# Рельеф заливается в воксельную сетку (как в Roblox), детали рисуются по высоте их верха,
# потом считаются отмывка рельефа и тени от солнца.
import json, sys, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

args = sys.argv[1:]
src, out = args[0], args[1]
scale = float(args[args.index('--scale') + 1]) if '--scale' in args else 1.0
crop = [float(v) for v in args[args.index('--crop') + 1:args.index('--crop') + 5]] if '--crop' in args else None
labels = '--labels' in args

data = json.load(open(src))
X0, Z0, X1, Z1 = crop if crop else (-460, -1260, 520, 420)
Y0, Y1 = -28.0, 110.0
RES = 2.0 if not crop else 1.0       # шаг вокселя по горизонтали
RY = 1.0                             # по вертикали
nx, nz, ny = int((X1 - X0) / RES), int((Z1 - Z0) / RES), int((Y1 - Y0) / RY)

MATS = ['Air', 'Water', 'Grass', 'LeafyGrass', 'Sand', 'Rock', 'Slate', 'Basalt', 'CrackedLava', 'Mud', 'Ground', 'Asphalt',
        'Concrete', 'Brick', 'Cobblestone', 'Glacier', 'Ice', 'Snow', 'Salt', 'Sandstone', 'Limestone', 'Pavement', 'WoodPlanks']
MID = {m: i for i, m in enumerate(MATS)}
DEFAULT_COL = {'Grass': (106, 127, 63), 'LeafyGrass': (115, 132, 74), 'Sand': (143, 126, 95), 'Rock': (102, 108, 111),
               'Slate': (63, 127, 107), 'Basalt': (30, 30, 37), 'CrackedLava': (232, 156, 74), 'Mud': (58, 46, 36),
               'Ground': (102, 92, 59), 'Asphalt': (115, 123, 107), 'Concrete': (127, 102, 63), 'Brick': (138, 86, 62),
               'Cobblestone': (132, 123, 90), 'Glacier': (101, 176, 234), 'Ice': (129, 194, 224), 'Snow': (195, 199, 218),
               'Salt': (198, 189, 181), 'Sandstone': (137, 90, 71), 'Limestone': (206, 173, 148), 'Pavement': (148, 148, 140),
               'WoodPlanks': (139, 109, 79)}
tcol = {k: tuple(int(c * 255) for c in v) for k, v in data.get('terrainColors', {}).items()}
water_col = np.array([c * 255 for c in data['waterColor']])

vox = np.zeros((nx, ny, nz), dtype=np.uint8)
xs = X0 + (np.arange(nx) + 0.5) * RES
ys = Y0 + (np.arange(ny) + 0.5) * RY
zs = Z0 + (np.arange(nz) + 0.5) * RES

def idx_range(lo, hi, origin, step, n):
    a = max(0, int(math.floor((lo - origin) / step)))
    b = min(n, int(math.ceil((hi - origin) / step)))
    return a, b

def apply_op(op):
    mat = MID.get(op['mat'], 5)
    if op['op'] == 'ball':
        cx, cy, cz = op['center']
        r = op['r']
        lo, hi = np.array([cx - r, cy - r, cz - r]), np.array([cx + r, cy + r, cz + r])
        R = np.eye(3)
        c = np.array([cx, cy, cz])
    else:
        f = op['cf']
        c = np.array(f[0:3])
        R = np.array(f[3:12]).reshape(3, 3)
        if op['op'] in ('block', 'wedge'):
            hs = np.array(op['size']) / 2
        else:  # cyl: ось — локальная Y
            hs = np.array([op['r'], op['h'] / 2, op['r']])
        ext = np.abs(R) @ hs
        lo, hi = c - ext, c + ext
    ia, ib = idx_range(lo[0], hi[0], X0, RES, nx)
    ja, jb = idx_range(lo[1], hi[1], Y0, RY, ny)
    ka, kb = idx_range(lo[2], hi[2], Z0, RES, nz)
    if ia >= ib or ja >= jb or ka >= kb:
        return
    gx, gy, gz = np.meshgrid(xs[ia:ib] - c[0], ys[ja:jb] - c[1], zs[ka:kb] - c[2], indexing='ij')
    if op['op'] == 'ball':
        mask = gx * gx + gy * gy + gz * gz <= op['r'] ** 2
    else:
        # локальные координаты: R^T (p - c)
        lx = R[0, 0] * gx + R[1, 0] * gy + R[2, 0] * gz
        ly = R[0, 1] * gx + R[1, 1] * gy + R[2, 1] * gz
        lz = R[0, 2] * gx + R[1, 2] * gy + R[2, 2] * gz
        if op['op'] == 'block':
            mask = (np.abs(lx) <= hs[0]) & (np.abs(ly) <= hs[1]) & (np.abs(lz) <= hs[2])
        elif op['op'] == 'cyl':
            mask = (np.abs(ly) <= hs[1]) & (lx * lx + lz * lz <= op['r'] ** 2)
        else:  # wedge: высота растёт к +Z
            sx, sy, sz = op['size']
            mask = (np.abs(lx) <= sx / 2) & (np.abs(lz) <= sz / 2) & (ly >= -sy / 2) & ((ly + sy / 2) / sy <= (lz + sz / 2) / sz)
    sub = vox[ia:ib, ja:jb, ka:kb]
    sub[mask] = mat

for op in data['terrain']:
    apply_op(op)

# поверхность: верх твёрдого и верх воды
solid = (vox != 0) & (vox != MID['Water'])
water = vox == MID['Water']
yidx = np.arange(ny)[None, :, None]
top_solid = np.where(solid.any(axis=1), (np.where(solid, yidx, -1)).max(axis=1), -1)
top_water = np.where(water.any(axis=1), (np.where(water, yidx, -1)).max(axis=1), -1)
h_ground = np.where(top_solid >= 0, Y0 + (top_solid + 1) * RY, Y0)
mat_top = np.take_along_axis(vox, np.clip(top_solid, 0, ny - 1)[:, None, :], axis=1)[:, 0, :]
h_water = np.where(top_water >= 0, Y0 + (top_water + 1) * RY, -1e9)

# в пиксели
W, H = int((X1 - X0) * scale), int((Z1 - Z0) * scale)
def to_px(a):
    img = Image.fromarray(a.T.astype(np.float32))
    return np.array(img.resize((W, H), Image.BILINEAR)).astype(np.float64)
def to_px_nearest(a):
    img = Image.fromarray(a.T.astype(np.uint8))
    return np.array(img.resize((W, H), Image.NEAREST))

height = to_px(h_ground)
wtop = to_px(np.where(h_water > -1e8, h_water, Y0 - 100))
mats = to_px_nearest(mat_top)
pal = np.zeros((len(MATS), 3))
for m, i in MID.items():
    pal[i] = tcol.get(m, DEFAULT_COL.get(m, (128, 128, 128)))
color = pal[mats]

# детали
parts = data['parts']
def corners(p):
    sx, sy, sz = p['sz']
    f = p['cf']
    c = np.array(f[0:3]); R = np.array(f[3:12]).reshape(3, 3)
    s = p['s']
    pts = []
    if s in ('Ball', 'MeshSphere'):
        rx, ry, rz = (sx / 2, sy / 2, sz / 2) if s == 'MeshSphere' else (min(sx, sy, sz) / 2,) * 3
        for th in np.linspace(0, math.pi, 7):
            for ph in np.linspace(0, 2 * math.pi, 14, endpoint=False):
                pts.append([rx * math.sin(th) * math.cos(ph), ry * math.cos(th), rz * math.sin(th) * math.sin(ph)])
    elif s == 'Cylinder':
        r = min(sy, sz) / 2
        for xx in (-sx / 2, sx / 2):
            for ph in np.linspace(0, 2 * math.pi, 16, endpoint=False):
                pts.append([xx, r * math.cos(ph), r * math.sin(ph)])
    else:
        for xx in (-sx / 2, sx / 2):
            for yy in (-sy / 2, sy / 2):
                for zz in (-sz / 2, sz / 2):
                    pts.append([xx, yy, zz])
    pts = np.array(pts) @ R.T + c
    return pts

def hull(pts):
    pts = sorted(set(map(tuple, pts)))
    if len(pts) < 3:
        return pts
    def cross(o, a, b): return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0: lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0: up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]

recs = []
for p in parts:
    if p['t'] >= 0.98:
        continue
    pts = corners(p)
    top = pts[:, 1].max()
    recs.append((top, p, pts))
recs.sort(key=lambda r: r[0])
for top, p, pts in recs:
    px = (pts[:, 0] - X0) * scale
    pz = (pts[:, 2] - Z0) * scale
    x0, x1 = int(max(0, math.floor(px.min()))), int(min(W, math.ceil(px.max()) + 1))
    z0, z1 = int(max(0, math.floor(pz.min()))), int(min(H, math.ceil(pz.max()) + 1))
    if x0 >= x1 or z0 >= z1:
        continue
    poly = hull(list(zip(px - x0, pz - z0)))
    if len(poly) < 3:
        continue
    mimg = Image.new('L', (x1 - x0, z1 - z0), 0)
    ImageDraw.Draw(mimg).polygon(poly, fill=255)
    mask = np.array(mimg) > 0
    col = np.array(p['c']) * 255
    if p['m'] == 'Neon':
        col = np.minimum(255, col * 1.15 + 30)
    win_h = height[z0:z1, x0:x1]
    win_c = color[z0:z1, x0:x1]
    t = p['t']
    if t >= 0.5:
        sel = mask & (win_h < top)
        win_c[sel] = win_c[sel] * t + col * (1 - t)
        continue
    sel = mask & (win_h < top)
    win_h[sel] = top
    win_c[sel] = col

# вода поверх
wdepth = wtop - height
wm = wdepth > 0
alpha = np.clip(0.45 + wdepth * 0.04, 0, 0.9)[..., None]
color = np.where(wm[..., None], color * (1 - alpha) + water_col * alpha, color)
height_s = np.where(wm, wtop, height)

# отмывка рельефа
gz, gx = np.gradient(height_s, 1 / scale)
sun = np.array([-0.55, 0.65, -0.5])   # солнце с юго-запада... направление НА солнце: (x, y, z)
sun = sun / np.linalg.norm(sun)
nrm = np.dstack([-gx, np.ones_like(gx), -gz])
nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
lam = np.clip((nrm * sun).sum(axis=2), 0, 1)
shade = 0.55 + 0.6 * lam
# тени: идём от каждой точки к солнцу
shadow = np.zeros_like(height_s, dtype=bool)
dirx, dirz = sun[0], sun[2]
horiz = math.hypot(dirx, dirz)
rise = sun[1] / horiz              # подъём луча на 1 стад по горизонтали
for k in range(1, int(60 * scale)):
    dx, dz = int(round(dirx / horiz * k)), int(round(dirz / horiz * k))
    shifted = np.full_like(height_s, -1e9)
    ys_ = slice(max(0, -dz), H - max(0, dz)); yd = slice(max(0, dz), H - max(0, -dz))
    xs_ = slice(max(0, -dx), W - max(0, dx)); xd = slice(max(0, dx), W - max(0, -dx))
    # shifted[z, x] = height[z + dz, x + dx]
    shifted[ys_, xs_] = height_s[yd, xd]
    shadow |= shifted > height_s + rise * (k / scale) + 0.3
shade = np.where(shadow & ~wm, shade * 0.62, shade)
img = np.clip(color * shade[..., None], 0, 255).astype(np.uint8)
im = Image.fromarray(img)

if labels:
    d = ImageDraw.Draw(im)
    fsize = max(12, int(18 * scale)) if crop else 22
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', fsize)
    LABELS = [(0, -75 - 25, 'Лаб-Сити'), (0, 205, 'Лаборатории'), (310, -95, 'Арена босса'), (-215, -45, 'Башня ребёрта'),
              (0, -205, 'Грибной лес'), (0, -405, 'Слизистое болото'), (0, -605, 'Кристальные пещеры'),
              (0, -805, 'Свалка роботов'), (0, -1005, 'Радиоактивный кратер'), (-250, 250, 'НЛО')]
    for lab in data.get('labels', LABELS):
        x, z, text = lab
        px, pz = (x - X0) * scale, (z - Z0) * scale
        if 0 <= px < W and 0 <= pz < H:
            d.text((px, pz), text, fill=(255, 255, 255), font=font, anchor='mm', stroke_width=3, stroke_fill=(20, 20, 30))
im.save(out)
print(out, im.size, 'parts drawn:', len(recs))
