#!/usr/bin/env python3
"""Примеры построек: бункер, боевой робот, танк и деревянный домик.

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
    "Seat", "DriverSeat", "Wheel", "Thruster", "Balloon", "Door", "Lamp", "Flag", "TNT", "Medkit", "AATurret", "Shield"])}
ITEM_SIZE = {
    "Seat": (2, 1, 2), "DriverSeat": (2, 1, 2), "Wheel": (2, 4, 4), "Thruster": (3, 2, 2), "Balloon": (4, 4, 4),
    "Door": (4, 7, 1), "Lamp": (1, 1, 1), "Flag": (1, 8, 1), "TNT": (2, 2, 2), "Medkit": (2, 2, 2),
    "AATurret": (3, 2, 3), "Shield": (3, 3, 3),
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
    b = Build("Деревянный домик", "Стартовый домик из бесплатных материалов")
    b.m((-6, 0, -6), (6, 1, 6), "Wood", color=(120, 84, 52))
    b.m((-6, 1, 5), (6, 7, 6), "Wood")
    b.m((-6, 1, -5), (-5, 7, 5), "Wood")
    b.m((5, 1, -5), (6, 7, 5), "Wood")
    b.m((-6, 1, -6), (-1, 7, -5), "Wood")
    b.m((1, 1, -6), (6, 7, -5), "Wood")
    b.m((-1, 5, -6), (1, 7, -5), "Wood")
    b.m((-7, 7, -7), (0, 11, 7), "Plastic", shape="Wedge", rot=rot_index(FACE["-x"]), color=(200, 60, 50))
    b.m((0, 7, -7), (7, 11, 7), "Plastic", shape="Wedge", rot=rot_index(FACE["+x"]), color=(200, 60, 50))
    b.m((-4, 3, -7), (-2, 5, -6), "Plastic", color=(150, 210, 240))
    b.m((2, 3, -7), (4, 5, -6), "Plastic", color=(150, 210, 240))
    b.i((2, 1, 2), (4, 2, 4), "Seat")
    for k, z in enumerate(range(-14, -6, 2)):
        b.m((-1, 0, z), (1, 1, z + 1), "Plastic", color=(150, 150, 146))
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
