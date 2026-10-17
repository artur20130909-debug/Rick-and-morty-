#!/usr/bin/env python3
"""Примеры построек: уютный дом, бункер, боевой робот и танк.

Создаёт src/ReplicatedStorage/Shared/Examples.lua (строки в формате Serializer)
и tools/preview/examples.json (для превью-рендера).
Координаты — локальные координаты участка: x, z от -32 до 32, y от 0 (пол) вверх.
"""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

MAT = {k: i + 1 for i, k in enumerate([
    "Wood", "Plastic", "Brick", "Stone", "Concrete", "Glass", "Ice", "Neon", "Sandbag", "Rubber",
    "Metal", "ArmorGlass", "Steel", "Lead", "Titanium", "Obsidian", "Gold", "Crystal"])}
ITEM = {k: i + 1 for i, k in enumerate([
    "Seat", "DriverSeat", "Wheel", "Thruster", "Balloon", "Door", "Lamp", "Flag", "TNT", "Medkit", "AATurret", "Shield",
    "Guard"])}
ITEM_SIZE = {
    "Seat": (2, 1, 2), "DriverSeat": (2, 1, 2), "Wheel": (2, 4, 4), "Thruster": (3, 2, 2), "Balloon": (4, 4, 4),
    "Door": (4, 7, 1), "Lamp": (1, 1, 1), "Flag": (1, 8, 1), "TNT": (2, 2, 2), "Medkit": (2, 2, 2),
    "AATurret": (3, 2, 3), "Shield": (3, 3, 3), "Guard": (2, 5, 2),
}
MAT_COLOR = {
    "Wood": (161, 115, 72), "Plastic": (232, 232, 236), "Brick": (168, 84, 62), "Stone": (128, 128, 124),
    "Concrete": (162, 162, 157), "Glass": (170, 214, 235), "Ice": (176, 222, 255), "Neon": (0, 255, 210),
    "Sandbag": (196, 172, 124), "Rubber": (44, 44, 48), "Metal": (152, 157, 162), "ArmorGlass": (120, 184, 255),
    "Steel": (88, 94, 102), "Lead": (96, 102, 124), "Titanium": (206, 210, 220), "Obsidian": (44, 26, 60),
    "Gold": (255, 204, 64), "Crystal": (80, 255, 240),
}
ITEM_COLOR = {
    "Seat": (140, 96, 60), "DriverSeat": (46, 48, 54), "Wheel": (30, 30, 32), "Thruster": (110, 114, 122),
    "Balloon": (235, 64, 52), "Door": (120, 82, 50), "Lamp": (255, 226, 160), "Flag": (200, 200, 205),
    "TNT": (200, 40, 36), "Medkit": (240, 240, 240), "AATurret": (70, 82, 70), "Shield": (60, 70, 96),
    "Guard": (72, 86, 60),
}
SHAPE = {"Block": 1, "Wedge": 2, "CornerWedge": 3, "Cylinder": 4, "Ball": 5}


# ---- повороты — тот же порядок, что в Grid.lua ----
def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def angles(rx, ry, rz):
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    Ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    Rz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    return mul(mul(Rx, Ry), Rz)


def snap(m):
    return tuple(tuple(int(round(x)) for x in row) for row in m)


H = math.pi / 2
ROTS = []
for yaw in range(4):
    for pitch in range(4):
        for roll in range(4):
            m = snap(mul(mul(angles(0, yaw * H, 0), angles(pitch * H, 0, 0)), angles(0, 0, roll * H)))
            if m not in ROTS:
                ROTS.append(m)
assert len(ROTS) == 24


def rot_index(yaw_deg=0, roll_deg=0, pitch_deg=0):
    m = snap(mul(mul(angles(0, math.radians(yaw_deg), 0), angles(math.radians(pitch_deg), 0, 0)), angles(0, 0, math.radians(roll_deg))))
    return ROTS.index(m) + 1


def extents(size, idx):
    m = ROTS[idx - 1]
    return tuple(sum(abs(m[i][j]) * size[j] for j in range(3)) for i in range(3))


class Build:
    def __init__(self, name, desc):
        self.name, self.desc, self.blocks = name, desc, []

    def add(self, lo, hi, kind, key, rot=1, color=None, shape="Block"):
        """lo/hi — углы AABB в координатах участка; размер блока вычисляется с учётом поворота."""
        ext = tuple(hi[i] - lo[i] for i in range(3))
        m = ROTS[rot - 1]
        # размер в собственных осях блока: ext = |M| * size  ->  size = |M|^T * ext (для осевых поворотов)
        size = tuple(sum(abs(m[i][j]) * ext[i] for i in range(3)) for j in range(3))
        if kind == "item":
            assert size == ITEM_SIZE[key] or key in ("Door", "Lamp"), (key, size)
        assert extents(size, rot) == ext, (key, size, ext)
        center = tuple((lo[i] + hi[i]) / 2 for i in range(3))
        for i in range(3):
            assert float(lo[i]).is_integer(), (key, lo)
        assert -32 <= lo[0] and hi[0] <= 32 and -32 <= lo[2] and hi[2] <= 32 and lo[1] >= 0 and hi[1] <= 96, (key, lo, hi)
        assert max(size) <= 16, (key, size)
        if kind == "item":
            c = color or ITEM_COLOR[key]
            self.blocks.append(dict(mat=0, shape=1, item=ITEM[key], pos=center, size=size, rot=rot, color=c, key=key, kind="item"))
        else:
            c = color or MAT_COLOR[key]
            self.blocks.append(dict(mat=MAT[key], shape=SHAPE[shape], item=0, pos=center, size=size, rot=rot, color=c, key=key, kind="mat", shapeName=shape))

    def m(self, lo, hi, key, **kw):
        self.add(lo, hi, "mat", key, **kw)

    def i(self, lo, hi, key, **kw):
        self.add(lo, hi, "item", key, **kw)

    def encode(self):
        out = []
        for b in self.blocks:
            out.append("%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%02X%02X%02X" % (
                b["mat"], b["shape"], b["item"],
                round(b["pos"][0] * 2), round(b["pos"][1] * 2), round(b["pos"][2] * 2),
                round(b["size"][0]), round(b["size"][1]), round(b["size"][2]),
                b["rot"], *b["color"]))
        return "v1|" + ";".join(out)


FACE = {"-z": 0, "+z": 180, "-x": 90, "+x": -90}  # куда смотрит скат клина


def hut():
    b = Build("Уютный дом", "Стартовый дом с крыльцом, садом и забором")
    # Дом 24×20 (стены x -12..12, z -4..16), фасад смотрит на лобби (−Z).
    DARK = (92, 60, 38)        # тёмное дерево: столбы, балки, рамы
    WALL = (208, 166, 112)     # светлые доски стен
    ROOF = (172, 74, 54)       # черепица
    WHITE = (242, 242, 238)    # наличники, забор
    SHUT = (58, 122, 86)       # ставни
    CREAM = (230, 214, 178)    # потолок и фронтоны
    STONE = (120, 118, 112)
    WARM = (255, 214, 150)     # свет ламп

    def wall(lo, hi):
        b.m(lo, hi, "Wood", color=WALL)

    def window(lo, hi, out):
        """Стекло в проёме стены; снаружи (сдвиг out) — подоконник, верхняя планка и ставни."""
        b.m(lo, hi, "Glass")
        a = 0 if out[0] == 0 else 2             # ось вдоль стены
        olo = [lo[k] + out[k] for k in range(3)]
        ohi = [hi[k] + out[k] for k in range(3)]

        def part(a0, a1, y0, y1, color):
            l, h = list(olo), list(ohi)
            l[a], h[a], l[1], h[1] = a0, a1, y0, y1
            b.m(tuple(l), tuple(h), "Plastic", color=color)
        part(lo[a] - 1, hi[a] + 1, lo[1] - 1, lo[1], WHITE)    # подоконник
        part(lo[a] - 1, hi[a] + 1, hi[1], hi[1] + 1, WHITE)    # верхняя планка
        part(lo[a] - 1, lo[a], lo[1], hi[1], SHUT)             # ставни
        part(hi[a], hi[a] + 1, lo[1], hi[1], SHUT)

    # ---- каменный фундамент и деревянный пол (у входа внутри — каменная полоса)
    for x0, x1 in ((-13, 0), (0, 13)):
        b.m((x0, 0, -5), (x1, 2, -1), "Stone", color=STONE)
        b.m((x0, 0, 15), (x1, 2, 17), "Stone", color=STONE)
    b.m((-13, 0, -1), (-11, 2, 15), "Stone", color=STONE)
    b.m((11, 0, -1), (13, 2, 15), "Stone", color=STONE)
    for x0, x1 in ((-11, 0), (0, 11)):
        b.m((x0, 0, -1), (x1, 2, 15), "Wood", color=(146, 100, 62))

    # ---- угловые столбы и верхние балки из тёмного дерева (выступают на 1 наружу,
    # передняя и задняя — ещё и внутрь, как карниз под потолком)
    for x0 in (-13, 11):
        for z0 in (-5, 15):
            b.m((x0, 2, z0), (x0 + 2, 12, z0 + 2), "Wood", color=DARK)
    for x0, x1 in ((-11, 0), (0, 11)):
        b.m((x0, 11, -5), (x1, 12, -2), "Wood", color=DARK)
        b.m((x0, 11, 14), (x1, 12, 17), "Wood", color=DARK)
    b.m((-13, 11, -3), (-11, 12, 6), "Wood", color=DARK)
    b.m((-13, 11, 6), (-11, 12, 15), "Wood", color=DARK)
    b.m((11, 11, -3), (13, 12, 8), "Wood", color=DARK)
    b.m((11, 11, 8), (12, 12, 11), "Wood", color=DARK)       # у трубы балка тоньше
    b.m((11, 11, 11), (13, 12, 15), "Wood", color=DARK)

    # ---- стены высотой 9 + балка: передняя с дверью и двумя окнами
    for x0, x1 in ((-11, -2), (2, 11)):
        wall((x0, 2, -4), (x1, 5, -3))
    for x0, x1 in ((-11, -10), (-6, -2), (2, 6), (10, 11)):
        wall((x0, 5, -4), (x1, 9, -3))
    for x0, x1 in ((-11, 0), (0, 11)):
        wall((x0, 9, -4), (x1, 11, -3))
    b.i((-2, 2, -4), (2, 9, -3), "Door", color=(52, 96, 70))
    window((-10, 5, -4), (-6, 9, -3), (0, 0, -1))
    window((6, 5, -4), (10, 9, -3), (0, 0, -1))
    # задняя стена
    for x0, x1 in ((-11, 0), (0, 11)):
        wall((x0, 2, 15), (x1, 11, 16))
    # боковые стены, в каждой окно
    for x0, s in ((-12, -1), (11, 1)):
        wall((x0, 2, -3), (x0 + 1, 11, 0))
        wall((x0, 2, 0), (x0 + 1, 5, 4))
        wall((x0, 9, 0), (x0 + 1, 11, 4))
        wall((x0, 2, 4), (x0 + 1, 11, 15))
        window((x0, 5, 0), (x0 + 1, 9, 4), (s, 0, 0))

    # ---- двускатная крыша: три ряда клиньев 4×3 на скат, свес 2, конёк на высоте 21
    for j in range(3):
        y0 = 12 + 3 * j
        for x0, x1 in ((-14, 0), (0, 14)):
            b.m((x0, y0, -6 + 4 * j), (x1, y0 + 3, -2 + 4 * j), "Brick", shape="Wedge", color=ROOF)
            b.m((x0, y0, 14 - 4 * j), (x1, y0 + 3, 18 - 4 * j), "Brick", shape="Wedge", rot=rot_index(FACE["+z"]), color=ROOF)
    # светлый потолок; его торцы и блоки выше закрывают фронтоны под клиньями
    for x0, x1 in ((-12, 0), (0, 12)):
        b.m((x0, 12, -2), (x1, 15, 14), "Plastic", color=CREAM)
    for x0, s in ((-12, -1), (11, 1)):
        b.m((x0, 15, 2), (x0 + 1, 18, 10), "Plastic", color=CREAM)
        # чердачное окошко с подоконником под свесом крыши
        xo = x0 + s
        b.m((xo, 15, 5), (xo + 1, 17, 7), "Glass")
        b.m((xo, 14, 4), (xo + 1, 15, 8), "Plastic", color=WHITE)
    # коньковая балка
    for x0, x1 in ((-15, 0), (0, 15)):
        b.m((x0, 21, 5), (x1, 22, 7), "Wood", color=DARK)

    # ---- кирпичная труба снаружи у правого торца
    BR = (132, 66, 52)
    b.m((13, 0, 7), (16, 2, 12), "Brick", color=BR)
    b.m((12, 2, 8), (16, 12, 11), "Brick", color=BR)
    b.m((14, 12, 8), (16, 24, 11), "Brick", color=BR)
    b.m((13, 24, 7), (17, 25, 12), "Stone", color=(86, 84, 82))

    # ---- крыльцо: настил, столбы, балка, навес и фонарь у двери
    b.m((-6, 0, -10), (6, 2, -5), "Wood", color=(132, 90, 56))
    for x0 in (-6, 5):
        b.m((x0, 2, -10), (x0 + 1, 9, -9), "Wood", color=DARK)
    b.m((-6, 9, -10), (6, 10, -9), "Wood", color=DARK)
    b.m((-6, 10, -5), (6, 11, -4), "Wood", color=DARK)       # прогон навеса у стены
    b.m((-6, 10, -10), (6, 12, -5), "Brick", shape="Wedge", color=ROOF)
    b.i((-4, 6, -5), (-3, 7, -4), "Lamp", color=WARM)

    # ---- внутри: стол на ножках, два сиденья и яблоко
    b.m((-8, 4, 0), (-4, 5, 4), "Wood", color=(196, 150, 100))
    for x0 in (-8, -5):
        for z0 in (0, 3):
            b.m((x0, 2, z0), (x0 + 1, 4, z0 + 1), "Wood", color=DARK)
    b.i((-10, 2, 1), (-8, 3, 3), "Seat", rot=rot_index(FACE["+x"]))
    b.i((-4, 2, 1), (-2, 3, 3), "Seat", rot=rot_index(FACE["-x"]))
    b.m((-7, 5, 1), (-6, 6, 2), "Plastic", shape="Ball", color=(214, 40, 40))
    # кровать у левой стены: рама, спинки, одеяло и подушка
    b.m((-11, 2, 8), (-7, 4, 14), "Wood", color=(122, 78, 48))
    b.m((-11, 2, 14), (-7, 7, 15), "Wood", color=DARK)
    b.m((-11, 2, 7), (-7, 5, 8), "Wood", color=DARK)
    b.m((-11, 4, 8), (-7, 5, 12), "Plastic", color=(64, 104, 190))
    b.m((-11, 4, 12), (-7, 5, 14), "Plastic", color=(246, 246, 242))
    # книжный шкаф у задней стены
    SH = (118, 78, 48)
    b.m((1, 2, 13), (2, 9, 15), "Wood", color=SH)
    b.m((5, 2, 13), (6, 9, 15), "Wood", color=SH)
    b.m((2, 5, 13), (5, 6, 15), "Wood", color=SH)
    b.m((1, 9, 13), (6, 10, 15), "Wood", color=SH)
    for x0, y0, h, c in ((2, 2, 3, (190, 52, 48)), (3, 2, 2, (52, 92, 184)), (4, 2, 3, (60, 146, 82)),
                         (2, 6, 2, (226, 184, 60)), (4, 6, 3, (132, 72, 166))):
        b.m((x0, y0, 13), (x0 + 1, y0 + h, 15), "Plastic", color=c)
    # камин у правой стены: очаг, кирпичные стенки, полено, неоновый огонь, полка
    FB = (172, 88, 64)
    b.m((7, 2, 7), (11, 3, 12), "Stone", color=(104, 102, 98))
    b.m((9, 3, 7), (11, 7, 8), "Brick", color=FB)
    b.m((9, 3, 11), (11, 7, 12), "Brick", color=FB)
    b.m((10, 3, 8), (11, 7, 11), "Brick", color=(74, 44, 36))            # закопчённая задняя стенка
    b.m((9, 3, 8), (10, 4, 11), "Wood", shape="Cylinder", rot=rot_index(90), color=(84, 54, 34))
    b.m((9, 4, 9), (10, 6, 10), "Neon", color=(255, 168, 48))
    b.m((9, 4, 8), (10, 5, 9), "Neon", shape="Ball", color=(255, 96, 32))
    b.m((9, 4, 10), (10, 5, 11), "Neon", shape="Ball", color=(255, 96, 32))
    b.m((9, 7, 7), (11, 9, 12), "Brick", color=FB)
    b.m((8, 9, 6), (11, 10, 13), "Wood", color=DARK)                     # каминная полка
    b.m((10, 10, 8), (11, 12, 11), "Brick", color=FB)
    b.m((9, 10, 9), (10, 11, 10), "Gold", shape="Cylinder", rot=rot_index(0, 90))
    # потолочные балки и люстра на цепи
    for x0 in (-7, 6):
        b.m((x0, 11, -2), (x0 + 1, 12, 14), "Wood", color=DARK)
    b.m((0, 11, 6), (1, 12, 7), "Steel", shape="Cylinder", rot=rot_index(0, 90), color=(60, 60, 64))
    b.i((-1, 10, 5), (2, 11, 8), "Lamp", color=WARM)

    # ---- двор: дорожка из камня от калитки к крыльцу
    b.m((-2, 0, -26), (2, 1, -10), "Stone", color=(146, 142, 134))
    # белый забор: калитка, кирпичные столбы с фонарями, столбики и перекладины
    b.i((-2, 1, -26), (2, 4, -25), "Door", color=WHITE)
    for x0 in (-4, 2):
        b.m((x0, 0, -27), (x0 + 2, 5, -25), "Brick")
        b.i((x0, 5, -27), (x0 + 2, 6, -25), "Lamp", color=WARM)
        b.m((x0, 6, -27), (x0 + 2, 7, -25), "Plastic", color=(56, 58, 62))
    for s in (-1, 1):
        xc = 19 if s > 0 else -20                   # угловой столбик
        xm = 11 if s > 0 else -12                   # средний столбик — перед перекладинами
        x0, x1 = (4, 19) if s > 0 else (-19, -4)
        for y0 in (1, 3):
            b.m((x0, y0, -26), (x1, y0 + 1, -25), "Plastic", color=WHITE)
            b.m((xc, y0, -25), (xc + 1, y0 + 1, -18), "Plastic", color=WHITE)   # вдоль боков двора
        b.m((xc, 0, -26), (xc + 1, 5, -25), "Plastic", color=WHITE)
        b.m((xm, 0, -27), (xm + 1, 5, -26), "Plastic", color=WHITE)
        b.m((xc, 0, -18), (xc + 1, 5, -17), "Plastic", color=WHITE)
    # клумба: деревянный ящик, два куста и цветы-шары
    b.m((-14, 0, -22), (-6, 1, -19), "Wood", color=(98, 66, 42))
    b.m((-14, 1, -22), (-12, 3, -20), "Plastic", shape="Ball", color=(66, 140, 60))
    b.m((-8, 1, -21), (-6, 3, -19), "Plastic", shape="Ball", color=(78, 156, 68))
    for x0, z0, c in ((-14, -20, (255, 120, 180)), (-12, -22, (230, 48, 56)), (-11, -20, (255, 212, 60)),
                      (-10, -22, (150, 90, 220)), (-9, -20, (250, 250, 250)), (-8, -22, (255, 140, 40))):
        b.m((x0, 1, z0), (x0 + 1, 2, z0 + 1), "Plastic", shape="Ball", color=c)
    # два дерева за забором: ствол и крона-шар
    for tx, green in ((-27, (70, 148, 62)), (25, (92, 166, 74))):
        b.m((tx, 0, -21), (tx + 2, 7, -19), "Wood", shape="Cylinder", rot=rot_index(0, 90), color=(104, 72, 46))
        b.m((tx - 3, 7, -24), (tx + 5, 15, -16), "Plastic", shape="Ball", color=green)
    # почтовый ящик у калитки и флаг на каменном основании
    b.m((6, 0, -29), (7, 3, -28), "Wood", color=DARK)
    b.m((6, 3, -30), (7, 4, -28), "Plastic", shape="Cylinder", rot=rot_index(90), color=(196, 52, 46))
    b.m((11, 0, -17), (14, 1, -14), "Stone", color=(132, 130, 124))
    b.i((12, 1, -16), (13, 9, -15), "Flag", rot=rot_index(90))
    return b


def bunker():
    b = Build("Бункер «Судный день»", "Бетон, броня и свинец, щит и ПВО. Выдерживает ядерку")
    b.m((-14, 0, -14), (0, 1, 0), "Concrete")
    b.m((0, 0, -14), (14, 1, 0), "Concrete")
    b.m((-14, 0, 0), (0, 1, 14), "Concrete")
    b.m((0, 0, 0), (14, 1, 14), "Concrete")
    # задняя и боковые стены
    b.m((-14, 1, 12), (0, 9, 14), "Concrete")
    b.m((0, 1, 12), (14, 9, 14), "Concrete")
    b.m((-14, 1, -12), (-12, 9, 0), "Concrete")
    b.m((-14, 1, 0), (-12, 9, 12), "Concrete")
    b.m((12, 1, -12), (14, 9, 0), "Concrete")
    b.m((12, 1, 0), (14, 9, 12), "Concrete")
    # передняя стена с дверью и окнами из бронестекла
    b.m((-14, 1, -14), (-2, 5, -12), "Concrete")
    b.m((2, 1, -14), (14, 5, -12), "Concrete")
    for x0, x1, k in ((-14, -10, "Concrete"), (-10, -6, "ArmorGlass"), (-6, -2, "Concrete"), (2, 6, "Concrete"), (6, 10, "ArmorGlass"), (10, 14, "Concrete")):
        b.m((x0, 5, -14), (x1, 7, -12), k)
    b.m((-14, 7, -14), (-2, 9, -12), "Concrete")
    b.m((2, 7, -14), (14, 9, -12), "Concrete")
    b.m((-2, 8, -14), (2, 9, -12), "Steel")
    b.i((-2, 1, -13), (2, 8, -12), "Door", color=(70, 76, 84))
    # крыша: броня + свинец
    for x0 in (-14, 0):
        for z0 in (-14, 0):
            b.m((x0, 9, z0), (x0 + 14, 11, z0 + 14), "Steel")
            b.m((x0, 11, z0), (x0 + 14, 12, z0 + 14), "Lead")
    # мешки с песком по краю крыши
    b.m((-14, 12, -14), (0, 13, -13), "Sandbag")
    b.m((0, 12, -14), (14, 13, -13), "Sandbag")
    b.m((-14, 12, 13), (0, 13, 14), "Sandbag")
    b.m((0, 12, 13), (14, 13, 14), "Sandbag")
    b.m((-14, 12, -13), (-13, 13, 0), "Sandbag")
    b.m((-14, 12, 0), (-13, 13, 13), "Sandbag")
    b.m((13, 12, -13), (14, 13, 0), "Sandbag")
    b.m((13, 12, 0), (14, 13, 13), "Sandbag")
    # наклонная броня по бокам
    for z0 in (-12, 0):
        b.m((-17, 0, z0), (-14, 9, z0 + 12), "Concrete", shape="Wedge", rot=rot_index(FACE["-x"]))
        b.m((14, 0, z0), (17, 9, z0 + 12), "Concrete", shape="Wedge", rot=rot_index(FACE["+x"]))
    # убежище из обсидиана внутри
    b.m((-6, 1, 9), (6, 7, 10), "Obsidian")
    b.m((-6, 1, 0), (-5, 7, 9), "Obsidian")
    b.m((5, 1, 0), (6, 7, 9), "Obsidian")
    b.m((-5, 1, 0), (-1, 7, 1), "Obsidian")
    b.m((1, 1, 0), (5, 7, 1), "Obsidian")
    b.m((-6, 7, 0), (6, 8, 10), "Lead")
    b.i((-4, 1, 6), (-2, 3, 8), "Medkit")
    b.i((0, 6, 4), (1, 7, 5), "Lamp")
    for x, z in ((-9, -8), (8, -8), (-9, 6), (8, 6)):
        b.i((x, 8, z), (x + 1, 9, z + 1), "Lamp")
    # оборудование на крыше
    b.i((-12, 12, -12), (-9, 14, -9), "AATurret")
    b.i((9, 12, 9), (12, 14, 12), "AATurret")
    b.i((-2, 12, -2), (1, 15, 1), "Shield")
    b.i((11, 12, -12), (12, 20, -11), "Flag")
    # кольцо мешков с песком снаружи
    b.m((-16, 0, -19), (-4, 2, -18), "Sandbag")
    b.m((4, 0, -19), (16, 2, -18), "Sandbag")
    b.m((-20, 0, -16), (-19, 2, 0), "Sandbag")
    b.m((-20, 0, 0), (-19, 2, 16), "Sandbag")
    b.m((19, 0, -16), (20, 2, 0), "Sandbag")
    b.m((19, 0, 0), (20, 2, 16), "Sandbag")
    b.m((-16, 0, 18), (0, 2, 19), "Sandbag")
    b.m((0, 0, 18), (16, 2, 19), "Sandbag")
    return b


def robot():
    b = Build("Боевой робот", "Едет на колёсах в ступнях, двигатели на спине. Садись за кресло на плечах")
    for s in (-1, 1):
        x0, x1 = (-6, -2) if s < 0 else (2, 6)
        b.m((x0, 1, -4), (x1, 3, 4), "Metal")                                   # ступня
        b.m((x0, 1, -6), (x1, 3, -4), "Metal", shape="Wedge")                   # носок
        wx0, wx1 = (-8, -6) if s < 0 else (6, 8)
        b.i((wx0, 0, -4), (wx1, 4, 0), "Wheel")
        b.i((wx0, 0, 0), (wx1, 4, 4), "Wheel")
        lx0, lx1 = (-5, -2) if s < 0 else (2, 5)
        b.m((lx0, 3, -2), (lx1, 7, 1), "Steel")                                  # голень
        b.m((lx0, 7, -2), (lx1, 8, 1), "Gold")                                   # колено
        b.m((lx0, 8, -2), (lx1, 11, 1), "Steel")                                 # бедро
    b.m((-6, 11, -3), (6, 13, 2), "Metal")                                       # таз
    b.m((-6, 13, -4), (6, 21, 3), "Steel")                                       # торс
    b.m((-2, 15, -5), (2, 19, -4), "Crystal")                                    # ядро
    b.m((-5, 19, -5), (-2, 20, -4), "Neon", color=(255, 70, 50))
    b.m((2, 19, -5), (5, 20, -4), "Neon", color=(255, 70, 50))
    for s in (-1, 1):
        sx0, sx1 = (-10, -6) if s < 0 else (6, 10)
        b.m((sx0, 17, -2), (sx1, 21, 2), "Titanium", shape="Ball")               # плечо
        ax0, ax1 = (-10, -7) if s < 0 else (7, 10)
        b.m((ax0, 9, -2), (ax1, 17, 1), "Steel")                                 # рука
        hx0, hx1 = (-11, -7) if s < 0 else (7, 11)
        b.m((hx0, 6, -3), (hx1, 9, 1), "Metal")                                  # кулак
        tx0, tx1 = (-4, -2) if s < 0 else (2, 4)
        b.i((tx0, 17, 3), (tx1, 19, 6), "Thruster", rot=rot_index(90))         # реактивные двигатели
    b.m((-3, 21, -4), (3, 26, 1), "Titanium")                                    # голова
    b.m((-2, 23, -5), (-1, 24, -4), "Neon", color=(255, 40, 40))                # глаза
    b.m((1, 23, -5), (2, 24, -4), "Neon", color=(255, 40, 40))
    b.m((-2, 21, -5), (2, 22, -4), "Metal")                                      # челюсть
    b.m((2, 26, -1), (3, 30, 0), "Metal", shape="Cylinder", rot=rot_index(0, 90))  # антенна
    b.m((2, 30, -1), (3, 31, 0), "Neon", shape="Ball", color=(255, 60, 60))
    b.i((-1, 21, 1), (1, 22, 3), "DriverSeat")
    return b


def tank():
    b = Build("Танк", "Восемь колёс, башня и пушка. Садись в кресло и жми WASD")
    b.m((-6, 2, -8), (6, 5, 8), "Steel")                                          # корпус
    b.m((-6, 2, -11), (6, 5, -8), "Steel", shape="Wedge")                         # лобовая броня
    b.m((-6, 2, 8), (6, 5, 10), "Metal")
    for x0, x1 in ((-8, -6), (6, 8)):
        for z0 in (-8, -4, 0, 4):
            b.i((x0, 0, z0), (x1, 4, z0 + 4), "Wheel")
        b.m((x0, 4, -8), (x1, 5, 8), "Rubber")                                     # крылья над колёсами
    b.m((-4, 5, -3), (4, 8, 5), "Steel")                                          # башня
    b.m((-3, 8, -2), (3, 9, 4), "Metal")
    b.m((-1, 6, -13), (1, 8, -3), "Metal", shape="Cylinder", rot=rot_index(90))   # ствол
    b.m((-1, 6, -15), (1, 8, -13), "Steel", shape="Ball")
    b.i((-1, 5, 5), (1, 6, 7), "DriverSeat")
    b.i((4, 5, 8), (5, 13, 9), "Flag")
    b.m((-5, 5, 6), (-2, 6, 9), "Sandbag")
    b.i((2, 9, 0), (3, 10, 1), "Lamp", color=(255, 60, 40))
    return b


def main():
    builds = [hut(), bunker(), robot(), tank()]
    lines = ["-- СГЕНЕРИРОВАНО tools/gen_examples.py — не редактировать вручную.",
             "-- Примеры построек, которые можно загрузить в окне «Сохранения».",
             "return {"]
    for bd in builds:
        lines.append("\t{")
        lines.append('\t\tname = "%s",' % bd.name)
        lines.append('\t\tdesc = "%s",' % bd.desc)
        lines.append('\t\tdata = "%s",' % bd.encode())
        lines.append("\t},")
    lines.append("}")
    open(os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "Examples.lua"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    prev = os.path.join(ROOT, "tools", "preview")
    os.makedirs(prev, exist_ok=True)
    json.dump({"rotations": [list(map(list, r)) for r in ROTS],
               "builds": [{"name": bd.name, "blocks": bd.blocks} for bd in builds]},
              open(os.path.join(prev, "examples.json"), "w"), ensure_ascii=False)
    for bd in builds:
        print(bd.name, len(bd.blocks), "блоков")


if __name__ == "__main__":
    main()
