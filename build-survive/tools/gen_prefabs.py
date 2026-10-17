#!/usr/bin/env python3
"""Готовые постройки для магазина: 5 домов и 5 бункеров.

Создаёт src/ReplicatedStorage/Shared/Prefabs.lua (строки в формате Serializer: дома — v1,
бункеры — v2 с маской выкопанной земли) и tools/preview/prefabs.json (для превью-рендера).

Координаты — локальные координаты участка: x, z от -32 до 32, y = 0 — пол участка, ниже — земля.
Дом стоит в центре участка (x, z от -22 до 22), фасадом к крыльцу с точкой появления (−Z).
Бункер — под землёй, на поверхности только входной павильон в углу участка (x, z от 24 до 32).

Постройка описывается «кистью»: box() закрашивает объём материалом, cut() вырезает,
part()/item() ставят отдельные детали (клинья, цилиндры, шары, особые блоки). В конце закрашенные
объёмы одного материала и цвета склеиваются в как можно меньшее число блоков (не больше 16 стадов
по оси), а детали вырезаются из них — так блоки никогда не пересекаются.

Перед записью всё проверяется: сетка, зоны, пересечения, размеры особых блоков, выкопанная земля
и её связность, лимиты блоков, счётчики охраны/ПВО/щитов/аптечек, а ещё — что игрок может дойти
от входа до каждой комнаты (поиск пути с запасом высоты над головой).
"""
import json
import math
import os
import re
import sys
from collections import Counter, deque

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)
SHARED = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared")
sys.path.insert(0, TOOLS)

import gen_examples as ge  # noqa: E402  (повороты в том же порядке, что Grid.Rotations; цвета материалов)

ROTS = ge.ROTS
rot_index = ge.rot_index
extents = ge.extents

# ---- каталог блоков (сверяется с Shared/Blocks.lua ниже) ----
MAT = dict(ge.MAT)
MAT_COLOR = dict(ge.MAT_COLOR)
SHAPE = dict(ge.SHAPE)
ITEM = dict(ge.ITEM)
ITEM_SIZE = dict(ge.ITEM_SIZE)
ITEM_COLOR = dict(ge.ITEM_COLOR)
# охранник (id 13) — по спецификации v3, если его ещё нет в таблицах gen_examples
ITEM.setdefault("Guard", 13)
ITEM_SIZE.setdefault("Guard", (2, 5, 2))
ITEM_COLOR.setdefault("Guard", (72, 86, 60))
RESIZABLE_MIN = {"Door": (2, 5, 1), "Lamp": (1, 1, 1)}   # особые блоки, которым можно менять размер

FACE = {"-z": 0, "+z": 180, "-x": 90, "+x": -90}  # куда смотрит перед детали (скат клина, лицо охранника)

# ---- правила магазина построек (спецификация v3, раздел PREFABS) ----
HOUSE_XZ = 22                  # дом: x, z от -22 до 22
HOUSE_TOP = 60                 # и не выше 60
KIOSK_LO, KIOSK_HI = 24, 32    # бункер: на поверхности только павильон в углу участка
MAX_PREFAB_BLOCKS = 650        # лимит блоков одной постройки
MAX_ITEM_SIZE = 16             # = Config.MaxBlockSize
HEADROOM = 6                   # высота прохода (персонаж ~5 стадов)
DOOR_HEADROOM = 7              # у дверей

KEYS = {
    "house": ["Cabin", "BrickHouse", "Cottage", "Villa", "Mansion"],
    "bunker": ["Cellar", "Shelter", "MilitaryBunker", "CommandBunker", "DoomsdayBunker"],
}
PRICES = {
    "house": [400, 1500, 5000, 14000, 40000],
    "bunker": [600, 2500, 9000, 20000, 50000],
}


# ---------------------------------------------------------------- настройки игры из Luau
def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def lua_config():
    src = read(os.path.join(SHARED, "Config.lua"))

    def num(pattern):
        m = re.search(pattern, src)
        assert m, "Config.lua: не найдено " + pattern
        return int(m.group(1))
    plot = re.search(r"Config\.PlotSize\s*=\s*Vector3\.new\((\d+),\s*(\d+),\s*(\d+)\)", src)
    assert plot, "Config.lua: PlotSize"
    return {
        "MaxBlocks": num(r"Config\.MaxBlocks\s*=\s*(\d+)"),
        "MaxBlockSize": num(r"Config\.MaxBlockSize\s*=\s*(\d+)"),
        "PlotSize": tuple(int(v) for v in plot.groups()),
        "Depth": num(r"Depth\s*=\s*(\d+)"),
        "Cell": num(r"Cell\s*=\s*(\d+)"),
    }


CFG = lua_config()
assert CFG["MaxBlockSize"] == MAX_ITEM_SIZE, CFG
HALF = CFG["PlotSize"][0] // 2               # 32
CELL, DEPTH = CFG["Cell"], CFG["Depth"]       # 4, 24
NX = CFG["PlotSize"][0] // CELL               # 16
NZ = CFG["PlotSize"][2] // CELL               # 16
NY = DEPTH // CELL                            # 6
COUNT = NX * NY * NZ                          # 1536
assert CFG["PlotSize"][0] == CFG["PlotSize"][2] and COUNT % 4 == 0


def check_catalog():
    """Номера материалов и особых блоков совпадают с Shared/Blocks.lua (охранника там может ещё не быть)."""
    src = read(os.path.join(SHARED, "Blocks.lua"))
    mats = dict((k, int(i)) for i, k in re.findall(r'\{\s*id\s*=\s*(\d+),\s*key\s*=\s*"(\w+)",\s*name\s*=\s*"[^"]*",\s*material', src))
    for k, i in MAT.items():
        assert mats.get(k) == i, ("материал", k, i, mats.get(k))
    items_src = src[src.index("Blocks.Items"):]
    found = {}
    for m in re.finditer(r'\{\s*id\s*=\s*(\d+),\s*key\s*=\s*"(\w+)"(.*?)\n\t\},?|\{\s*id\s*=\s*(\d+),\s*key\s*=\s*"(\w+)"(.*?)\},', items_src, re.S):
        pass
    for m in re.finditer(r'\{\s*id\s*=\s*(\d+),\s*key\s*=\s*"(\w+)"([^{}]*?)\},', items_src):
        found[m.group(2)] = (int(m.group(1)), m.group(3))
    for k, i in ITEM.items():
        if k not in found:
            assert k == "Guard", ("особый блок не найден в Blocks.lua", k)
            print("  (в Blocks.lua пока нет охранника — беру id 13 и размер 2×5×2 из спецификации)")
            continue
        fid, body = found[k]
        assert fid == i, ("особый блок", k, i, fid)
        size = re.search(r"size\s*=\s*Vector3\.new\(([^)]*)\)", body)
        assert size and tuple(int(v) for v in size.group(1).split(",")) == tuple(ITEM_SIZE[k]), ("размер", k)
        assert ("resizable = true" in body) == (k in RESIZABLE_MIN), ("resizable", k)


# ---------------------------------------------------------------- подземелье (как Shared/Underground.lua)
def cell_index(ix, iy, iz):
    """Номер клетки с нуля; ix, iz = 1..16, iy = 1..6 сверху вниз."""
    return (iy - 1) * NX * NZ + (iz - 1) * NX + (ix - 1)


def cell_coords(i):
    return i % NX + 1, i // (NX * NZ) + 1, (i // NX) % NZ + 1


def cells_in_box(lo, hi, eps=0.01):
    """Клетки, которые коробка задевает ниже пола (касание гранью не считается)."""
    if lo[1] >= -eps:
        return []
    x1 = max(1, math.floor((lo[0] + eps + HALF) / CELL) + 1)
    x2 = min(NX, math.ceil((hi[0] - eps + HALF) / CELL))
    z1 = max(1, math.floor((lo[2] + eps + HALF) / CELL) + 1)
    z2 = min(NZ, math.ceil((hi[2] - eps + HALF) / CELL))
    y1 = max(1, math.floor((eps - hi[1]) / CELL) + 1)
    y2 = min(NY, math.ceil((-lo[1] - eps) / CELL))
    return [cell_index(ix, iy, iz) for iy in range(y1, y2 + 1) for iz in range(z1, z2 + 1) for ix in range(x1, x2 + 1)]


def encode_mask(dug):
    """Маска → 384 hex-символа (бит 1 — первая клетка четвёрки); пустая маска — ""."""
    if not dug:
        return ""
    chars = []
    for k in range(COUNT // 4):
        n = sum(1 << b for b in range(4) if 4 * k + b in dug)
        chars.append("%x" % n)
    return "".join(chars)


def decode_mask(hexstr):
    dug = set()
    for k, ch in enumerate(hexstr):
        n = int(ch, 16)
        for b in range(4):
            if n & (1 << b):
                dug.add(4 * k + b)
    return dug


NEIGHBOURS = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))


def dug_connected(dug):
    """Все выкопанные клетки достижимы от верхнего слоя по выкопанным соседям."""
    queue = deque(i for i in dug if cell_coords(i)[1] == 1)
    seen = set(queue)
    while queue:
        ix, iy, iz = cell_coords(queue.popleft())
        for dx, dy, dz in NEIGHBOURS:
            x, y, z = ix + dx, iy + dy, iz + dz
            if 1 <= x <= NX and 1 <= y <= NY and 1 <= z <= NZ:
                j = cell_index(x, y, z)
                if j in dug and j not in seen:
                    seen.add(j)
                    queue.append(j)
    return seen == dug


# ---------------------------------------------------------------- геометрия блоков
def local_point(b, p):
    """Точка участка → локальные координаты блока (без масштаба)."""
    m = ROTS[b["rot"] - 1]
    d = [p[i] - b["pos"][i] for i in range(3)]
    return [sum(m[i][j] * d[i] for i in range(3)) for j in range(3)]


def inside_shape(b, p):
    """Лежит ли точка внутри формы блока (для поиска пути: клин, цилиндр и шар — не коробки)."""
    shape = b.get("shapeName", "Block")
    if b["kind"] == "item" or shape in ("Block", "CornerWedge"):
        return True
    sx, sy, sz = b["size"]
    x, y, z = local_point(b, p)
    if shape == "Wedge":   # скат смотрит на −Z: внизу спереди, наверху сзади
        return (y + sy / 2) / sy <= (z + sz / 2) / sz + 1e-9
    if shape == "Cylinder":   # ось — локальная X
        return (y * y + z * z) <= (sy / 2) ** 2 + 1e-9
    if shape == "Ball":
        return (x / sx) ** 2 + (y / sy) ** 2 + (z / sz) ** 2 <= 0.25 + 1e-9
    raise AssertionError(shape)


def overlap_volume(a, b):
    v = 1.0
    for i in range(3):
        d = min(a["hi"][i], b["hi"][i]) - max(a["lo"][i], b["lo"][i])
        if d <= 0:
            return 0.0
        v *= d
    return v


def split_len(lo, hi, limit=MAX_ITEM_SIZE):
    """Отрезок длиннее limit режется на почти равные целые части."""
    length = hi - lo
    n = -(-length // limit)
    base, extra = divmod(length, n)
    out, a = [], lo
    for k in range(n):
        b = a + base + (1 if k < extra else 0)
        out.append((a, b))
        a = b
    return out


def greedy(cells, n0, n1, n2):
    """Жадная склейка ячеек одного ключа в коробки: сначала вдоль оси 2, потом 1, потом 0."""
    used = bytearray(len(cells))
    s0 = n1 * n2
    out = []
    for a in range(n0):
        for b in range(n1):
            base = a * s0 + b * n2
            for c in range(n2):
                i = base + c
                k = cells[i]
                if not k or used[i]:
                    continue
                c2 = c + 1
                while c2 < n2 and cells[base + c2] == k and not used[base + c2]:
                    c2 += 1
                b2 = b + 1
                while b2 < n1:
                    row = a * s0 + b2 * n2
                    if all(cells[row + q] == k and not used[row + q] for q in range(c, c2)):
                        b2 += 1
                    else:
                        break
                a2 = a + 1
                while a2 < n0:
                    ok = True
                    for bb in range(b, b2):
                        row = a2 * s0 + bb * n2
                        if not all(cells[row + q] == k and not used[row + q] for q in range(c, c2)):
                            ok = False
                            break
                    if not ok:
                        break
                    a2 += 1
                for aa in range(a, a2):
                    for bb in range(b, b2):
                        row = aa * s0 + bb * n2
                        for q in range(c, c2):
                            used[row + q] = 1
                out.append((k, (a, a2), (b, b2), (c, c2)))
    return out


# ---------------------------------------------------------------- постройка
class Prefab:
    def __init__(self, key, kind, tier, name, icon, desc, features):
        assert kind in KEYS and KEYS[kind][tier - 1] == key, (key, kind, tier)
        self.key, self.kind, self.tier, self.name, self.icon = key, kind, tier, name, icon
        self.price = PRICES[kind][tier - 1]
        self.desc, self.features = desc, features
        self.ops = []            # ("box", lo, hi, ключ материала) / ("cut", lo, hi)
        self.parts = []          # отдельные детали
        self.keys = []           # (материал, цвет) закрашенных объёмов
        self.dug = set()         # выкопанные клетки
        self.start = None        # откуда игрок входит (x, y, z — точка на полу)
        self.targets = []        # (название, (x, y, z)) — куда игрок должен дойти
        self.blocks = None

    # ---- кисть
    @staticmethod
    def _box(lo, hi):
        lo, hi = tuple(lo), tuple(hi)
        for i in range(3):
            assert float(lo[i]).is_integer() and float(hi[i]).is_integer() and lo[i] < hi[i], (lo, hi)
        return tuple(int(v) for v in lo), tuple(int(v) for v in hi)

    def box(self, lo, hi, mat, color=None):
        """Закрасить объём материалом (склеивается с соседями того же материала и цвета)."""
        lo, hi = self._box(lo, hi)
        assert mat in MAT, mat
        k = (mat, tuple(color or MAT_COLOR[mat]))
        if k not in self.keys:
            self.keys.append(k)
        self.ops.append(("box", lo, hi, self.keys.index(k) + 1))

    def cut(self, lo, hi):
        """Вырезать закрашенный объём (проём, проход)."""
        lo, hi = self._box(lo, hi)
        self.ops.append(("cut", lo, hi, 0))

    def _add(self, lo, hi, kind, key, rot=1, color=None, shape="Block"):
        lo, hi = self._box(lo, hi)
        ext = tuple(hi[i] - lo[i] for i in range(3))
        m = ROTS[rot - 1]
        size = tuple(sum(abs(m[i][j]) * ext[i] for i in range(3)) for j in range(3))
        assert extents(size, rot) == ext, (key, size, ext)
        b = dict(pos=tuple((lo[i] + hi[i]) / 2 for i in range(3)), size=size, rot=rot, lo=lo, hi=hi, key=key, kind=kind)
        if kind == "item":
            b.update(mat=0, shape=1, item=ITEM[key], color=tuple(color or ITEM_COLOR[key]))
        else:
            b.update(mat=MAT[key], shape=SHAPE[shape], item=0, color=tuple(color or MAT_COLOR[key]), shapeName=shape)
        self.parts.append(b)
        return b

    def part(self, lo, hi, mat, color=None, shape="Block", rot=1):
        """Отдельная деталь из материала (клин, цилиндр, шар или блок, который не надо склеивать)."""
        return self._add(lo, hi, "mat", mat, rot, color, shape)

    def wedge(self, lo, hi, mat, face="-z", color=None, down=False):
        """Клин: скат смотрит в сторону face; down — перевёрнутый (скат снизу, для карнизов и свесов)."""
        return self._add(lo, hi, "mat", mat, rot_index(FACE[face], 180 if down else 0), color, "Wedge")

    def cyl(self, lo, hi, mat, axis="y", color=None):
        """Цилиндр вдоль оси axis."""
        rot = {"x": 1, "y": rot_index(0, 90), "z": rot_index(90)}[axis]
        return self._add(lo, hi, "mat", mat, rot, color, "Cylinder")

    def ball(self, lo, hi, mat, color=None):
        return self._add(lo, hi, "mat", mat, 1, color, "Ball")

    def item(self, lo, hi, key, color=None, face="-z"):
        """Особый блок; face — куда смотрит его перед (сиденье, охранник, турель)."""
        return self._add(lo, hi, "item", key, rot_index(FACE[face]), color)

    def lamp(self, lo, size=(1, 1, 1), color=(255, 226, 160)):
        return self.item(lo, tuple(lo[i] + size[i] for i in range(3)), "Lamp", color)

    # ---- земля
    def dig(self, ix, iy, iz):
        """Выкопать клетки: каждый аргумент — номер или (от, до) включительно."""
        rng = [(v, v) if isinstance(v, int) else v for v in (ix, iy, iz)]
        for x in range(rng[0][0], rng[0][1] + 1):
            for y in range(rng[1][0], rng[1][1] + 1):
                for z in range(rng[2][0], rng[2][1] + 1):
                    assert 1 <= x <= NX and 1 <= y <= NY and 1 <= z <= NZ, (x, y, z)
                    self.dug.add(cell_index(x, y, z))

    def dig_box(self, lo, hi):
        """Выкопать все клетки, которые задевает коробка."""
        self.dug.update(cells_in_box(lo, hi))

    # ---- сборка
    def finish(self):
        """Склеить закрашенные объёмы в блоки, добавить детали, проверить."""
        axes = [set(), set(), set()]
        for _, lo, hi, _ in self.ops:
            for i in range(3):
                axes[i].update((lo[i], hi[i]))
        for p in self.parts:
            for i in range(3):
                axes[i].update((p["lo"][i], p["hi"][i]))
        axes = [sorted(a) for a in axes]
        pos = [{v: n for n, v in enumerate(a)} for a in axes]
        dims = [max(len(a) - 1, 0) for a in axes]
        n0, n1, n2 = dims
        grid = [0] * (n0 * n1 * n2)

        def fill(lo, hi, value):
            r = [range(pos[i][lo[i]], pos[i][hi[i]]) for i in range(3)]
            for a in r[0]:
                for b in r[1]:
                    row = (a * n1 + b) * n2
                    for c in r[2]:
                        grid[row + c] = value
        for op, lo, hi, k in self.ops:
            fill(lo, hi, k if op == "box" else 0)
        for p in self.parts:
            # деталь вырезает из закраски всю свою коробку: блоки не пересекаются
            fill(p["lo"], p["hi"], 0)

        merged = self._merge(grid, dims, axes)
        merged.sort(key=lambda b: (b["lo"][1], b["lo"][2], b["lo"][0]))
        parts = sorted(self.parts, key=lambda b: (b["lo"][1], b["lo"][2], b["lo"][0]))
        self.blocks = merged + parts
        validate(self)
        return self

    def _merge(self, grid, dims, axes):
        """Склейка: для каждого материала выбирается порядок осей, дающий меньше блоков."""
        perms = [(0, 1, 2), (0, 2, 1), (1, 0, 2), (1, 2, 0), (2, 0, 1), (2, 1, 0)]
        best = {}
        for perm in perms:
            pd = [dims[p] for p in perm]
            cells = [0] * len(grid)
            strides = [dims[1] * dims[2], dims[2], 1]
            n = 0
            for a in range(pd[0]):
                for b in range(pd[1]):
                    for c in range(pd[2]):
                        idx = [0, 0, 0]
                        idx[perm[0]], idx[perm[1]], idx[perm[2]] = a, b, c
                        cells[n] = grid[idx[0] * strides[0] + idx[1] * strides[1] + idx[2]]
                        n += 1
            boxes = {}
            for k, ra, rb, rc in greedy(cells, *pd):
                rng = [None, None, None]
                rng[perm[0]], rng[perm[1]], rng[perm[2]] = ra, rb, rc
                lo = tuple(axes[i][rng[i][0]] for i in range(3))
                hi = tuple(axes[i][rng[i][1]] for i in range(3))
                boxes.setdefault(k, []).append((lo, hi))
            for k, lst in boxes.items():
                pieces = [(a, b) for lo, hi in lst
                          for a, b in [((x0, y0, z0), (x1, y1, z1))
                                       for x0, x1 in split_len(lo[0], hi[0])
                                       for y0, y1 in split_len(lo[1], hi[1])
                                       for z0, z1 in split_len(lo[2], hi[2])]]
                if k not in best or len(pieces) < len(best[k]):
                    best[k] = pieces
        out = []
        for k in sorted(best):
            mat, color = self.keys[k - 1]
            for lo, hi in best[k]:
                size = tuple(hi[i] - lo[i] for i in range(3))
                out.append(dict(mat=MAT[mat], shape=1, item=0, pos=tuple((lo[i] + hi[i]) / 2 for i in range(3)),
                                size=size, rot=1, color=color, key=mat, kind="mat", shapeName="Block", lo=lo, hi=hi))
        return out

    # ---- вывод
    def encode(self):
        out = []
        for b in self.blocks:
            out.append("%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%02X%02X%02X" % (
                b["mat"], b["shape"], b["item"],
                round(b["pos"][0] * 2), round(b["pos"][1] * 2), round(b["pos"][2] * 2),
                round(b["size"][0]), round(b["size"][1]), round(b["size"][2]),
                b["rot"], *b["color"]))
        blocks = ";".join(out)
        if self.kind == "bunker":
            return "v2|" + blocks + "|" + encode_mask(self.dug)
        return "v1|" + blocks

    def count(self, key):
        return sum(1 for b in self.blocks if b["kind"] == "item" and b["key"] == key)


# ---------------------------------------------------------------- проверки
def validate(pf):
    blocks = pf.blocks
    name = pf.key
    assert 0 < len(blocks) <= MAX_PREFAB_BLOCKS, (name, "блоков", len(blocks))
    for b in blocks:
        lo, hi, size = b["lo"], b["hi"], b["size"]
        tag = (name, b["key"], lo, hi)
        assert 1 <= b["rot"] <= 24, tag
        assert extents(size, b["rot"]) == tuple(hi[i] - lo[i] for i in range(3)), tag
        # сетка: целый нижний угол повёрнутых габаритов, целые размеры от 1 до 16
        assert all(float(v).is_integer() for v in lo) and all(float(v).is_integer() and 1 <= v <= MAX_ITEM_SIZE for v in size), tag
        if b["kind"] == "item":
            assert b["item"] == ITEM[b["key"]] and b["mat"] == 0, tag
            if b["key"] in RESIZABLE_MIN:
                assert all(size[i] >= RESIZABLE_MIN[b["key"]][i] for i in range(3)), ("маленький", tag)
            else:
                assert tuple(size) == tuple(ITEM_SIZE[b["key"]]), ("размер особого блока", tag, size)
        else:
            assert b["mat"] == MAT[b["key"]] and b["item"] == 0 and b["shape"] in SHAPE.values(), tag
            if b["shapeName"] == "Ball":
                assert size[0] == size[1] == size[2], ("шар", tag)
            if b["shapeName"] == "Cylinder":
                assert size[1] == size[2], ("цилиндр", tag)
        assert all(0 <= c <= 255 for c in b["color"]), tag
        # зоны
        if pf.kind == "house":
            assert -HOUSE_XZ <= lo[0] and hi[0] <= HOUSE_XZ and -HOUSE_XZ <= lo[2] and hi[2] <= HOUSE_XZ, ("вне зоны дома", tag)
            assert 0 <= lo[1] and hi[1] <= HOUSE_TOP, ("высота дома", tag)
        else:
            assert lo[1] >= -DEPTH and hi[1] <= HOUSE_TOP, ("глубина", tag)
            assert -HALF <= lo[0] and hi[0] <= HALF and -HALF <= lo[2] and hi[2] <= HALF, ("вне участка", tag)
            if hi[1] > 0:
                assert KIOSK_LO <= lo[0] and hi[0] <= KIOSK_HI and KIOSK_LO <= lo[2] and hi[2] <= KIOSK_HI, ("над землёй вне павильона", tag)
            for i in cells_in_box(lo, hi):
                assert i in pf.dug, ("блок в невыкопанной земле", tag, cell_coords(i))
    # пересечения (объём общей части коробок)
    order = sorted(range(len(blocks)), key=lambda i: blocks[i]["lo"][0])
    for n, i in enumerate(order):
        a = blocks[i]
        for j in order[n + 1:]:
            b = blocks[j]
            if b["lo"][0] >= a["hi"][0]:
                break
            assert overlap_volume(a, b) <= 1e-6, ("пересечение", name, a["key"], a["lo"], a["hi"], b["key"], b["lo"], b["hi"])
    # земля
    if pf.kind == "house":
        assert not pf.dug, name
    else:
        assert pf.dug and dug_connected(pf.dug), (name, "выкопанные клетки не связаны с поверхностью")
        assert decode_mask(encode_mask(pf.dug)) == pf.dug
        assert len(encode_mask(pf.dug)) == COUNT // 4
    # охрана и оборудование по уровням
    guards, aa, shields = pf.count("Guard"), pf.count("AATurret"), pf.count("Shield")
    assert guards == 0 or pf.tier >= 4, (name, "охрана только с 4 уровня")
    assert aa == 0 or pf.tier >= 3, (name, "ПВО только с 3 уровня")
    assert shields == 0 or pf.tier >= 5, (name, "щит только на 5 уровне")
    walk_check(pf)


# ---------------------------------------------------------------- проходимость
YMIN, YMAX = -DEPTH, HOUSE_TOP + 8
SX, SY = 2 * HALF, YMAX - YMIN


def walk_check(pf):
    """Игрок (2×2 стада, проход высотой HEADROOM) доходит от входа до каждой цели
    по ступеням не выше 1 стада (и обратно), а у каждой двери есть проход высотой DOOR_HEADROOM."""
    solid = bytearray(SX * SX * SY)       # [x][z][y], 1 стад

    def idx(x, z, y):
        return ((x + HALF) * SX + (z + HALF)) * SY + (y - YMIN)
    # земля: под полом всё, что не выкопано
    for x in range(-HALF, HALF):
        for z in range(-HALF, HALF):
            for y in range(YMIN, 0):
                ix, iy, iz = (x + HALF) // CELL + 1, (-y - 1) // CELL + 1, (z + HALF) // CELL + 1
                if cell_index(ix, iy, iz) not in pf.dug:
                    solid[idx(x, z, y)] = 1
    for b in pf.blocks:
        if b["kind"] == "item" and b["key"] == "Door":
            continue    # дверь открывается (E)
        lo, hi = b["lo"], b["hi"]
        full = b["kind"] == "item" or b["shapeName"] in ("Block", "CornerWedge")
        for x in range(lo[0], hi[0]):
            for z in range(lo[2], hi[2]):
                for y in range(lo[1], hi[1]):
                    if full or inside_shape(b, (x + 0.5, y + 0.5, z + 0.5)):
                        solid[idx(x, z, y)] = 1
    # свободная высота над каждым кубиком
    free = bytearray(SX * SX * SY)
    for x in range(-HALF, HALF):
        for z in range(-HALF, HALF):
            run = 0
            base = idx(x, z, YMIN)
            for y in range(SY - 1, -1, -1):
                run = 0 if solid[base + y] else min(run + 1, 255)
                free[base + y] = run

    def stand(x, z, y, h=HEADROOM):
        if not (-HALF <= x < HALF - 1 and -HALF <= z < HALF - 1 and YMIN < y < YMAX - h):
            return False
        cols = (idx(x, z, y), idx(x + 1, z, y), idx(x, z + 1, y), idx(x + 1, z + 1, y))
        return all(free[c] >= h for c in cols) and any(solid[c - 1] for c in cols)

    sx, sy, sz = pf.start
    assert stand(sx, sz, sy), (pf.key, "игроку негде стоять у входа", pf.start)
    seen = {(sx, sz, sy)}
    queue = deque([(sx, sz, sy)])
    while queue:
        x, z, y = queue.popleft()
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            for dy in (0, 1, -1):
                n = (x + dx, z + dz, y + dy)
                if n not in seen and stand(*n):
                    seen.add(n)
                    queue.append(n)
    for label, (tx, ty, tz) in pf.targets:
        ok = any((tx - 1 <= x <= tx and tz - 1 <= z <= tz and y == ty) for x, z, y in [(a, c, b) for a, c, b in seen])
        assert ok, (pf.key, "не дойти до цели", label, (tx, ty, tz))
    # двери: перед и за дверью свободно на её ширину и DOOR_HEADROOM в высоту, под дверью пол
    for b in pf.blocks:
        if not (b["kind"] == "item" and b["key"] == "Door"):
            continue
        lo, hi = b["lo"], b["hi"]
        thin = 0 if hi[0] - lo[0] < hi[2] - lo[2] else 2       # ось толщины двери
        along = 2 - thin
        h = DOOR_HEADROOM
        assert hi[1] - lo[1] >= h, (pf.key, "дверь ниже", h, lo, hi)
        for side in (-1, 1):
            for d in range(1, 3):
                t = lo[thin] - d if side < 0 else hi[thin] + d - 1
                for u in range(lo[along], hi[along]):
                    x, z = (t, u) if thin == 0 else (u, t)
                    for y in range(lo[1], lo[1] + h):
                        assert not solid[idx(x, z, y)], (pf.key, "проход у двери занят", lo, hi, (x, y, z))
        for u in range(lo[along], hi[along]):
            x, z = (lo[0], u) if thin == 2 else (u, lo[2])
            x, z = (u, lo[2]) if thin == 2 else (lo[0], u)
            assert solid[idx(x, z, lo[1] - 1)], (pf.key, "под дверью нет пола", lo, hi)


# ---------------------------------------------------------------- вывод
def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_outputs(prefabs):
    lines = [
        "-- СГЕНЕРИРОВАНО tools/gen_prefabs.py — не редактировать вручную.",
        "-- Готовые постройки для магазина: дома (kind = \"house\", формат v1) и бункеры (\"bunker\", v2 с маской",
        "-- выкопанной земли). blocks — число блоков; guards/aa/shields/medkits — сколько внутри охранников,",
        "-- турелей ПВО, генераторов щита и аптечек. data — строка Serializer.",
        "export type Prefab = {",
        "\tkey: string,",
        "\tkind: string,",
        "\ttier: number,",
        "\tname: string,",
        "\ticon: string,",
        "\tprice: number,",
        "\tdesc: string,",
        "\tfeatures: { string },",
        "\tblocks: number,",
        "\tguards: number,",
        "\taa: number,",
        "\tshields: number,",
        "\tmedkits: number,",
        "\tdata: string,",
        "}",
        "",
        "local Prefabs: { Prefab } = {",
    ]
    for pf in prefabs:
        lines += [
            "\t{",
            "\t\tkey = %s, kind = %s, tier = %d," % (lua_string(pf.key), lua_string(pf.kind), pf.tier),
            "\t\tname = %s, icon = %s, price = %d," % (lua_string(pf.name), lua_string(pf.icon), pf.price),
            "\t\tdesc = %s," % lua_string(pf.desc),
            "\t\tfeatures = { %s }," % ", ".join(lua_string(f) for f in pf.features),
            "\t\tblocks = %d, guards = %d, aa = %d, shields = %d, medkits = %d," % (
                len(pf.blocks), pf.count("Guard"), pf.count("AATurret"), pf.count("Shield"), pf.count("Medkit")),
            "\t\tdata = %s," % lua_string(pf.encode()),
            "\t},",
        ]
    lines += ["}", "", "return Prefabs", ""]
    with open(os.path.join(SHARED, "Prefabs.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))

    def clean(b):
        out = {k: b[k] for k in ("mat", "shape", "item", "pos", "size", "rot", "color", "key", "kind")}
        if b["kind"] == "mat":
            out["shapeName"] = b["shapeName"]
        return out
    data = {
        "rotations": [list(map(list, r)) for r in ROTS],
        "builds": [{
            "key": pf.key, "kind": pf.kind, "tier": pf.tier, "name": pf.name, "price": pf.price,
            "dug": sorted(pf.dug), "blocks": [clean(b) for b in pf.blocks],
        } for pf in prefabs],
    }
    with open(os.path.join(TOOLS, "preview", "prefabs.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)


# ================================================================ ПОСТРОЙКИ
from prefab_designs import DESIGNS  # noqa: E402  (временная заглушка, заменяется ниже)


def main():
    check_catalog()
    prefabs = [fn().finish() for fn in DESIGNS]
    keys = [pf.key for pf in prefabs]
    assert keys == KEYS["house"] + KEYS["bunker"], keys
    houses = [len(pf.blocks) for pf in prefabs if pf.kind == "house"]
    bunkers = [len(pf.blocks) for pf in prefabs if pf.kind == "bunker"]
    # дом и бункер стоят на участке вместе: с запасом под свои блоки игрока
    assert max(houses) + max(bunkers) <= CFG["MaxBlocks"] - 150, (max(houses), max(bunkers), CFG["MaxBlocks"])
    write_outputs(prefabs)
    for pf in prefabs:
        c = Counter(b["key"] for b in pf.blocks if b["kind"] == "item")
        extra = ", ".join("%s %d" % kv for kv in sorted(c.items()))
        print("%-15s %-6s %4d блоков  %s" % (pf.key, pf.kind, len(pf.blocks), extra))


if __name__ == "__main__":
    main()
