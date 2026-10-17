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
    pf.reach = seen
    for label, (tx, ty, tz) in pf.targets:
        ok = any(tx - 1 <= x <= tx and tz - 1 <= z <= tz and y == ty for x, z, y in seen)
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


# ================================================================ ПОМОЩНИКИ ДЛЯ ПОСТРОЕК
def wall_box(normal, w0, w1, a0, a1, y0, y1):
    """Коробка в координатах стены: normal — ось толщины ("x" или "z"), w — толщина, a — вдоль стены."""
    if normal == "z":
        return (a0, y0, w0), (a1, y1, w1)
    return (w0, y0, a0), (w1, y1, a1)


def walls(pf, lo, hi, mat, color=None, t=1):
    """Четыре стены по периметру коробки lo..hi (внешние габариты), толщина t."""
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    pf.box((x0, y0, z0), (x1, y1, z0 + t), mat, color)
    pf.box((x0, y0, z1 - t), (x1, y1, z1), mat, color)
    pf.box((x0, y0, z0 + t), (x0 + t, y1, z1 - t), mat, color)
    pf.box((x1 - t, y0, z0 + t), (x1, y1, z1 - t), mat, color)


def window(pf, normal, w0, w1, a0, a1, y0, y1, out, frame=None, frame_mat="Plastic", glass="Glass", glass_color=None,
           mullions=(), transoms=(), sill=True, glass_w=None):
    """Окно в стене толщиной w0..w1: проём a0..a1 × y0..y1, по краю рама (frame=None — без рамы),
    перемычки mullions (вдоль стены) и transoms (по высоте), снаружи (out = ±1) подоконник.
    glass_w — слой стены, где стоит стекло (по умолчанию вся толщина); остальное — ниша."""
    pf.cut(*wall_box(normal, w0, w1, a0, a1, y0, y1))
    g0, g1 = glass_w or (w0, w1)
    f = 1 if frame else 0
    pf.box(*wall_box(normal, g0, g1, a0 + f, a1 - f, y0 + f, y1 - f), glass, glass_color)
    if frame:
        for lo, hi in ((wall_box(normal, w0, w1, a0, a1, y0, y0 + 1)), (wall_box(normal, w0, w1, a0, a1, y1 - 1, y1)),
                       (wall_box(normal, w0, w1, a0, a0 + 1, y0, y1)), (wall_box(normal, w0, w1, a1 - 1, a1, y0, y1))):
            pf.box(lo, hi, frame_mat, frame)
        for m in mullions:
            pf.box(*wall_box(normal, g0, g1, m, m + 1, y0, y1), frame_mat, frame)
        for t in transoms:
            pf.box(*wall_box(normal, g0, g1, a0, a1, t, t + 1), frame_mat, frame)
        if sill:
            s0, s1 = (w1, w1 + 1) if out > 0 else (w0 - 1, w0)
            pf.box(*wall_box(normal, s0, s1, a0 - 1, a1 + 1, y0, y0 + 1), frame_mat, frame)


def door(pf, normal, w0, w1, a0, a1, y0, h, color, at="out"):
    """Дверной проём в стене и дверь в нём (толщина 1). at — у какой грани стены стоит дверь:
    "out"/"in" — наружная/внутренняя для стен с наружной стороной −Z/−X, "lo"/"hi" — по координате."""
    pf.cut(*wall_box(normal, w0, w1, a0, a1, y0, y0 + h))
    d0 = w0 if at in ("out", "lo") else w1 - 1
    face = "-z" if normal == "z" else "-x"
    pf.item(*wall_box(normal, d0, d0 + 1, a0, a1, y0, y0 + h), "Door", color, face)


def gable_roof(pf, ridge, lo, hi, y0, rise, run, colors, mat="Wood", skip=(), fill=None, fill_lo=None, fill_hi=None):
    """Двускатная крыша из рядов клиньев. ridge — ось конька ("x" или "z"); lo, hi — углы крыши по
    горизонтали (x, z) вместе со свесами; каждый ряд — клин run вглубь и rise в высоту, цвета рядов
    чередуются из colors. skip — коробки (труба), где ряды прерываются. fill — (материал, цвет)
    ступенчатого заполнения под скатами (фронтоны и чердак) в пределах fill_lo..fill_hi (x, z).
    Возвращает высоту конька."""
    (x0, z0), (x1, z1) = lo, hi
    across = (z0, z1) if ridge == "x" else (x0, x1)
    along = (x0, x1) if ridge == "x" else (z0, z1)
    half = (across[1] - across[0]) // 2
    assert (across[1] - across[0]) % 2 == 0 and half % run == 0, (pf.key, "крыша", lo, hi, run)
    rows = half // run

    def piece(a0, a1, c0, c1, y_lo, y_hi):
        if ridge == "x":
            return (a0, y_lo, c0), (a1, y_hi, c1)
        return (c0, y_lo, a0), (c1, y_hi, a1)

    def segments(c0, c1, y_lo, y_hi):
        """Отрезки вдоль конька без коробок skip."""
        cuts = []
        for s_lo, s_hi in skip:
            lo3, hi3 = piece(along[0], along[1], c0, c1, y_lo, y_hi)
            if all(s_lo[i] < hi3[i] and lo3[i] < s_hi[i] for i in range(3)):
                k = 0 if ridge == "x" else 2
                cuts.append((s_lo[k], s_hi[k]))
        out, a = [], along[0]
        for c_lo, c_hi in sorted(cuts):
            if c_lo > a:
                out.append((a, c_lo))
            a = max(a, c_hi)
        if a < along[1]:
            out.append((a, along[1]))
        return out

    faces = ("-z", "+z") if ridge == "x" else ("-x", "+x")
    for j in range(rows):
        y_lo, y_hi = y0 + rise * j, y0 + rise * (j + 1)
        color = colors[j % len(colors)]
        for side, (c0, c1) in enumerate(((across[0] + run * j, across[0] + run * (j + 1)),
                                         (across[1] - run * (j + 1), across[1] - run * j))):
            for s0, s1 in segments(c0, c1, y_lo, y_hi):
                for a0, a1 in split_len(s0, s1):
                    pf.wedge(*piece(a0, a1, c0, c1, y_lo, y_hi), mat, faces[side], color)
        if fill:
            f0, f1 = across[0] + run * (j + 1), across[1] - run * (j + 1)
            if f0 < f1:
                (fx0, fz0), (fx1, fz1) = fill_lo, fill_hi
                if ridge == "x":
                    pf.box((fx0, y_lo, f0), (fx1, y_hi, f1), *fill)
                else:
                    pf.box((f0, y_lo, fz0), (f1, y_hi, fz1), *fill)
    return y0 + rise * rows


def steps(pf, axis, sign, start, a0, a1, y_floor, n, mat, color=None, base=None, depth=1, colors=None):
    """Лестница вверх: n ступеней высотой 1 и глубиной depth, от start по оси axis в сторону sign,
    поперёк — a0..a1. Первая ступень — на y_floor + 1. base — низ ступеней (None — ступени толщиной 1)."""
    for i in range(n):
        p0 = start + sign * depth * i
        p1 = p0 + sign * depth
        top = y_floor + i + 1
        bot = base if base is not None else top - 1
        c = colors[i % len(colors)] if colors else color
        if axis == "z":
            pf.box((a0, bot, min(p0, p1)), (a1, top, max(p0, p1)), mat, c)
        else:
            pf.box((min(p0, p1), bot, a0), (max(p0, p1), top, a1), mat, c)


def table(pf, lo, hi, top_color, leg_color, mat="Wood", top_mat=None):
    """Стол: столешница толщиной 1 на высоте hi[1] и четыре ножки по углам."""
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    pf.box((x0, y1 - 1, z0), (x1, y1, z1), top_mat or mat, top_color)
    for x in (x0, x1 - 1):
        for z in (z0, z1 - 1):
            pf.box((x, y0, z), (x + 1, y1 - 1, z + 1), mat, leg_color)


# ================================================================ ДОМА
def cabin():
    pf = Prefab("Cabin", "house", 1, "Хижина", "🛖",
                "Уютный бревенчатый домик с крыльцом, печью и кроватью. Первый свой дом!",
                ["Брёвна и каменный фундамент", "Крыльцо под навесом", "Печь с трубой", "Стол, лавка и кровать"])
    LOGS = ((128, 88, 54), (114, 77, 47))
    DARK = (78, 52, 34)
    RED = (172, 58, 44)
    STONE = (118, 116, 110)
    ROOF = ((92, 70, 54), (80, 60, 46))
    PLANK = (142, 100, 62)
    WARM = (255, 214, 150)

    # фундамент из камня и дощатый пол с «половиком»
    pf.box((-9, 0, -3), (9, 1, 11), "Stone", STONE)
    pf.box((-7, 0, -1), (7, 1, 9), "Wood", (176, 132, 86))
    pf.box((-3, 0, 1), (3, 1, 5), "Wood", (150, 62, 50))

    # стены из брёвен: слои по 2 стада, передние и задние брёвна выступают за углы
    holes_front = [(-5, 1, 1, 9), (3, 7, 3, 7)]          # дверь, окно (a0, a1, y0, y1)
    holes_back = [(-2, 3, 3, 7)]
    holes_left = [(2, 7, 3, 7)]
    for layer, y in enumerate((1, 3, 5, 7)):
        color = LOGS[layer % 2]
        for z0, holes in ((-3, holes_front), (9, holes_back)):
            for a0, a1 in log_segments(-10, 10, y, holes):
                for s0, s1 in split_len(a0, a1):
                    pf.cyl((s0, y, z0), (s1, y + 2, z0 + 2), "Wood", "x", color)
        for x0, holes in ((-9, holes_left), (7, [])):
            for a0, a1 in log_segments(-1, 9, y, holes):
                pf.cyl((x0, y, a0), (x0 + 2, y + 2, a1), "Wood", "z", LOGS[(layer + 1) % 2])
    # дверь с косяками и перемычкой
    pf.box((-5, 1, -3), (-4, 9, -1), "Wood", DARK)
    pf.box((0, 1, -3), (1, 9, -1), "Wood", DARK)
    pf.box((-4, 8, -3), (0, 9, -1), "Wood", DARK)
    pf.item((-4, 1, -3), (0, 8, -2), "Door", RED)
    # окна в красных рамах со ставнями
    window(pf, "z", -3, -1, 3, 7, 3, 7, -1, RED, glass_w=(-2, -1), mullions=(5,))
    window(pf, "z", 9, 11, -2, 3, 3, 7, 1, RED, glass_w=(9, 10), mullions=(0,))
    window(pf, "x", -9, -7, 2, 7, 3, 7, -1, RED, glass_w=(-8, -7), mullions=(4,))
    SHUTTER = (62, 104, 70)
    for a in (2, 7):
        pf.box((a, 3, -4), (a + 1, 7, -3), "Wood", SHUTTER)
    for a in (1, 7):
        pf.box((-10, 3, a), (-9, 7, a + 1), "Wood", SHUTTER)

    # крыша: ряды клиньев 3×3, конёк вдоль X; под скатами — дощатые фронтоны
    chimney = ((9, 0, 2), (12, 22, 5))
    top = gable_roof(pf, "x", (-11, -5), (11, 13), 9, 3, 3, ROOF, skip=[chimney],
                     fill=("Wood", PLANK), fill_lo=(-9, -3), fill_hi=(9, 11))
    pf.box((-11, top, 3), (9, top + 1, 5), "Wood", DARK)
    # каменная труба у правого фронтона
    pf.box((9, 0, 1), (13, 3, 6), "Stone", STONE)
    pf.box((9, 3, 2), (12, 20, 5), "Stone", (128, 124, 118))
    pf.box((8, 20, 1), (13, 21, 6), "Stone", (96, 94, 90))

    # печь внутри: под, стенки, полка и огонь
    pf.box((4, 1, 1), (7, 2, 6), "Stone", (104, 102, 98))
    pf.box((4, 2, 1), (7, 6, 2), "Stone", STONE)
    pf.box((4, 2, 5), (7, 6, 6), "Stone", STONE)
    pf.box((6, 2, 2), (7, 6, 5), "Brick", (70, 44, 36))
    pf.box((4, 6, 1), (7, 7, 6), "Wood", DARK)
    pf.box((5, 7, 2), (7, 9, 5), "Stone", STONE)
    pf.cyl((5, 2, 2), (6, 3, 5), "Wood", "z", (84, 54, 34))
    pf.part((5, 3, 3), (6, 4, 4), "Neon", (255, 150, 40), "Ball")
    pf.box((5, 3, 2), (6, 4, 3), "Neon", (255, 110, 40))
    pf.box((5, 3, 4), (6, 4, 5), "Neon", (255, 190, 70))

    # кровать в углу, стол и лавки, шкаф
    pf.box((-7, 1, 4), (-3, 2, 9), "Wood", (122, 80, 50))
    pf.box((-7, 2, 4), (-3, 3, 7), "Plastic", (168, 52, 44))
    pf.box((-7, 2, 7), (-3, 3, 8), "Plastic", (244, 240, 230))
    pf.box((-7, 1, 8), (-3, 5, 9), "Wood", DARK)
    table(pf, (-1, 1, 6), (3, 4, 9), (170, 124, 80), DARK)
    pf.item((-3, 1, 7), (-1, 2, 9), "Seat", face="+x")
    pf.item((3, 1, 7), (5, 2, 9), "Seat", face="-x")
    pf.part((1, 4, 7), (2, 5, 8), "Plastic", (214, 40, 40), "Ball")
    pf.box((5, 1, 7), (7, 6, 9), "Wood", DARK)
    pf.box((5, 6, 7), (7, 7, 9), "Wood", (176, 132, 86))
    pf.lamp((0, 8, 3), color=WARM)

    # крыльцо во всю ширину: настил, столбы, балка, навес, перила, фонарь, бочка
    pf.box((-9, 0, -9), (9, 1, -3), "Wood", (136, 96, 60))
    for x in (-9, 8):
        pf.box((x, 1, -9), (x + 1, 7, -8), "Wood", DARK)
    pf.box((-9, 7, -9), (9, 8, -8), "Wood", DARK)
    for x0, x1 in ((-10, 0), (0, 10)):
        pf.wedge((x0, 8, -10), (x1, 10, -5), "Wood", "-z", ROOF[1])
    for x0, x1, posts in ((-8, -5, (-7,)), (2, 8, (3, 5, 7))):
        pf.box((x0, 3, -9), (x1, 4, -8), "Wood", DARK)
        for x in posts:
            pf.box((x, 1, -9), (x + 1, 3, -8), "Wood", DARK)
    for x in (-9, 8):
        pf.box((x, 3, -8), (x + 1, 4, -3), "Wood", DARK)
        pf.box((x, 1, -6), (x + 1, 3, -5), "Wood", DARK)
    pf.lamp((-6, 5, -4), color=WARM)
    pf.cyl((-8, 1, -7), (-6, 4, -5), "Wood", "y", (110, 72, 42))
    pf.box((-8, 4, -7), (-6, 5, -5), "Wood", DARK)

    # поленница за домом и колода с топором
    for n, (z, y) in enumerate(((12, 0), (14, 0), (12, 2), (14, 2))):
        pf.cyl((-9, y, z), (-3, y + 2, z + 2), "Wood", "x", (150, 104, 62) if n % 3 else (132, 90, 54))
    pf.cyl((-12, 0, 12), (-10, 2, 14), "Wood", "y", (120, 84, 52))
    pf.box((-11, 2, 13), (-10, 3, 14), "Metal", (150, 154, 160))

    # дорожка из плоских камней к крыльцу
    for z in (-21, -17, -13):
        pf.box((-4, 0, z), (0, 1, z + 3), "Stone", (146, 142, 134))

    pf.start = (-3, 0, -24)
    pf.targets = [("комната", (-1, 1, 2)), ("у печи", (2, 1, 1))]
    return pf


def brick_house():
    pf = Prefab("BrickHouse", "house", 2, "Кирпичный дом", "🏠",
                "Крепкий кирпичный дом: гостиная с камином и спальня, большие окна и черепичная крыша.",
                ["Кирпичные стены — держат взрывы", "Две комнаты: гостиная и спальня", "Камин и кирпичная труба",
                 "Окна в белых рамах, лужайка"])
    BRICK = (164, 76, 56)
    WHITE = (244, 242, 236)
    SLATE = ((76, 80, 92), (66, 70, 82))
    PLINTH = (112, 110, 106)
    CREAM = (234, 224, 200)
    WARM = (255, 222, 160)
    DOOR = (40, 66, 104)
    WOOD = (150, 104, 66)
    DARK = (92, 62, 40)

    # цоколь, пол, стены, потолок с карнизом
    pf.box((-11, 0, -7), (11, 1, 13), "Concrete", PLINTH)
    pf.box((-9, 0, -5), (9, 1, 11), "Wood", (186, 140, 92))
    walls(pf, (-10, 1, -6), (10, 10, 12), "Brick", BRICK)
    pf.box((-11, 10, -7), (11, 11, 13), "Plastic", WHITE)
    # угловые пилястры из светлого камня
    for x in (-11, 10):
        for z in (-7, 12):
            pf.box((x, 1, z), (x + 1, 10, z + 1), "Concrete", (206, 200, 188))

    # двускатная крыша, конёк вдоль Z: фронтон с круглым окном смотрит на крыльцо
    chimney = ((8, 11, 0), (12, 23, 3))
    top = gable_roof(pf, "z", (-12, -8), (12, 14), 11, 3, 4, SLATE, mat="Concrete", skip=[chimney],
                     fill=("Brick", BRICK), fill_lo=(-10, -6), fill_hi=(10, 12))
    pf.box((-1, top, -8), (1, top + 1, 14), "Concrete", (52, 54, 62))
    pf.cyl((-1, 14, -6), (1, 16, -5), "Glass", "z")
    pf.box((-2, 13, -7), (2, 14, -6), "Plastic", WHITE)
    # кирпичная труба на правой стене; выше карниза она стоит на стене
    pf.box((10, 0, -1), (13, 2, 4), "Concrete", PLINTH)
    pf.box((10, 2, 0), (13, 11, 3), "Brick", (140, 64, 50))
    pf.box((8, 11, 0), (12, 22, 3), "Brick", (140, 64, 50))
    pf.box((7, 22, -1), (13, 23, 4), "Concrete", (70, 70, 74))

    # фасад: дверь с белыми пилястрами, козырёк, фонари, два окна
    door(pf, "z", -6, -5, -2, 2, 1, 7, DOOR)
    for x in (-3, 2):
        pf.box((x, 1, -7), (x + 1, 9, -6), "Plastic", WHITE)
    pf.box((-3, 8, -7), (3, 9, -6), "Plastic", WHITE)
    pf.wedge((-4, 9, -9), (4, 10, -6), "Concrete", "-z", SLATE[0])
    for x in (-5, 4):
        pf.lamp((x, 6, -7), color=WARM)
    for a0 in (-8, 4):
        window(pf, "z", -6, -5, a0, a0 + 4, 3, 8, -1, WHITE, transoms=(6,))
    # окна по бокам и сзади
    for x0, out in ((-10, -1), (9, 1)):
        for a0 in ((-3, 6) if out < 0 else (6,)):
            window(pf, "x", x0, x0 + 1, a0, a0 + 4, 3, 8, out, WHITE, transoms=(6,))
    for a0 in (-7, 3):
        window(pf, "z", 11, 12, a0, a0 + 4, 3, 8, 1, WHITE, transoms=(6,))

    # перегородка между гостиной и спальней
    pf.box((-9, 1, 4), (9, 10, 5), "Plastic", CREAM)
    door(pf, "z", 4, 5, -2, 2, 1, 7, (176, 128, 84))

    # гостиная: камин, диван, столик, ковёр, книжный шкаф, люстра
    pf.box((6, 1, -1), (9, 2, 4), "Concrete", (120, 118, 114))
    pf.box((7, 2, -1), (9, 7, 0), "Brick", (140, 64, 50))
    pf.box((7, 2, 3), (9, 7, 4), "Brick", (140, 64, 50))
    pf.box((8, 2, 0), (9, 7, 3), "Brick", (70, 40, 34))
    pf.box((6, 7, -1), (9, 8, 4), "Wood", DARK)
    pf.box((7, 8, 0), (9, 10, 3), "Brick", (140, 64, 50))
    pf.box((7, 2, 1), (8, 3, 2), "Neon", (255, 140, 40))
    pf.part((7, 2, 0), (8, 3, 1), "Neon", (255, 100, 30), "Ball")
    pf.part((7, 2, 2), (8, 3, 3), "Neon", (255, 180, 60), "Ball")
    pf.box((-4, 0, -3), (4, 1, 2), "Wood", (120, 56, 52))
    SOFA = (78, 104, 140)
    pf.box((-9, 1, -3), (-6, 3, 3), "Plastic", SOFA)
    pf.box((-9, 3, -3), (-8, 5, 3), "Plastic", SOFA)
    pf.box((-9, 3, -4), (-6, 4, -3), "Plastic", (66, 90, 124))
    pf.box((-9, 3, 3), (-6, 4, 4), "Plastic", (66, 90, 124))
    pf.box((-9, 1, -4), (-6, 3, -3), "Plastic", (66, 90, 124))
    pf.box((-9, 1, 3), (-6, 3, 4), "Plastic", (66, 90, 124))
    table(pf, (-4, 1, -2), (-1, 3, 2), (120, 80, 50), DARK)
    pf.box((3, 1, -5), (8, 8, -4), "Wood", DARK)
    for y, cs in ((1, ((190, 52, 48), (52, 92, 184), (60, 146, 82), (226, 184, 60))), (4, ((132, 72, 166), (230, 230, 220), (200, 90, 50), (60, 120, 160)))):
        for i, c in enumerate(cs):
            pf.box((4 + i, y + 1, -4), (5 + i, y + 3, -3), "Plastic", c)
    for y in (4, 7):
        pf.box((3, y, -4), (8, y + 1, -3), "Wood", DARK)
    pf.box((3, 1, -4), (8, 2, -3), "Wood", DARK)
    pf.lamp((-1, 9, -1), (2, 1, 2), WARM)

    # спальня: двуспальная кровать с тумбочками, шкаф
    pf.box((-3, 1, 7), (3, 3, 11), "Wood", (128, 84, 52))
    pf.box((-3, 3, 7), (3, 4, 9), "Plastic", (196, 70, 74))
    pf.box((-3, 3, 9), (3, 4, 10), "Plastic", (248, 246, 240))
    pf.box((-3, 1, 10), (3, 6, 11), "Wood", DARK)
    for x in (-5, 3):
        pf.box((x, 1, 9), (x + 2, 3, 11), "Wood", (128, 84, 52))
        pf.lamp((x + 1, 3, 10), color=WARM)
    pf.box((5, 1, 9), (9, 8, 11), "Wood", (150, 110, 74))
    pf.box((7, 1, 8), (8, 8, 9), "Wood", DARK)
    pf.lamp((0, 9, 6), color=WARM)

    # двор: дорожка из брусчатки, лужайки, живая изгородь, фонарь у дорожки, почтовый ящик
    for z0 in range(-22, -7, 3):
        pf.box((-2, 0, z0), (2, 1, z0 + 3), "Brick", (176, 120, 96) if (z0 // 3) % 2 else (156, 104, 84))
    for x0, x1 in ((-14, -3), (3, 14)):
        pf.box((x0, 0, -21), (x1, 1, -9), "Plastic", (98, 150, 70))
        pf.box((x0, 1, -22), (x1, 2, -21), "Plastic", (60, 112, 52))
    for x in (-9, 6):
        pf.part((x, 1, -12), (x + 3, 4, -9), "Plastic", (70, 130, 60), "Ball")
    pf.box((3, 1, -20), (4, 7, -19), "Metal", (40, 40, 44))
    pf.lamp((3, 7, -20), color=WARM)
    pf.box((-5, 1, -20), (-4, 3, -19), "Wood", DARK)
    pf.cyl((-5, 3, -21), (-4, 4, -19), "Metal", "z", (60, 92, 160))

    pf.start = (-1, 0, -27)
    pf.targets = [("гостиная", (-4, 1, 3)), ("спальня", (5, 1, 6))]
    return pf


def cottage():
    pf = Prefab("Cottage", "house", 3, "Каменный коттедж", "🏡",
                "Двухэтажный коттедж из камня и бетона: лестница на второй этаж, балкон, терраса на крыше "
                "кухни и турель ПВО.",
                ["Камень и бетонные пояса", "Два этажа и лестница", "Балкон и терраса на крыше",
                 "Турель ПВО и аптечка", "Панорамные окна"])
    STONE = (150, 146, 136)
    BAND = (200, 198, 190)
    FRAME = (58, 60, 64)
    TILE = ((168, 86, 58), (152, 76, 52))
    WARM = (255, 224, 170)
    WOOD = (164, 118, 76)
    DARK = (84, 60, 42)
    WHITE = (240, 240, 236)

    # ---- основной дом 18×16, два этажа; пристройка-кухня 12×14 с террасой на крыше
    pf.box((-15, 0, -7), (17, 1, 11), "Concrete", (126, 124, 120))                 # цоколь
    pf.box((-13, 0, -5), (3, 1, 9), "Wood", (176, 134, 92))                       # пол гостиной
    pf.box((4, 0, -3), (15, 1, 9), "Concrete", (214, 210, 200))                   # плитка кухни
    walls(pf, (-14, 1, -6), (4, 20, 10), "Stone", STONE)
    pf.box((4, 1, -4), (16, 10, -3), "Stone", STONE)
    pf.box((4, 1, 9), (16, 10, 10), "Stone", STONE)
    pf.box((15, 1, -3), (16, 10, 9), "Stone", STONE)
    # перекрытие второго этажа выходит наружу поясом; крыша кухни — терраса
    pf.box((-15, 10, -7), (5, 11, 11), "Concrete", BAND)
    pf.box((5, 10, -5), (17, 11, 11), "Concrete", BAND)
    pf.box((-13, 10, -5), (3, 11, 9), "Wood", (176, 134, 92))                     # пол второго этажа
    pf.cut((-11, 10, 6), (-3, 11, 9))                                             # проём над лестницей

    # ---- крыша из черепицы, конёк вдоль X; каменная труба у левого фронтона
    chimney = ((-17, 0, 1), (-14, 30, 4))
    top = gable_roof(pf, "x", (-16, -8), (6, 12), 20, 3, 5, TILE, mat="Brick", skip=[chimney],
                     fill=("Stone", STONE), fill_lo=(-14, -6), fill_hi=(4, 10))
    pf.box((-16, top, 1), (6, top + 1, 3), "Brick", (120, 58, 42))
    pf.box((-18, 0, 0), (-14, 3, 5), "Stone", (118, 116, 110))
    pf.box((-17, 3, 1), (-14, 28, 4), "Stone", (136, 132, 124))
    pf.box((-18, 28, 0), (-13, 29, 5), "Concrete", (90, 90, 92))

    # ---- фасад: дверь под балконом, панорамное окно, окна второго этажа и дверь на балкон
    door(pf, "z", -6, -5, -4, 0, 1, 7, (96, 64, 42))
    window(pf, "z", -6, -5, -13, -6, 2, 9, -1, FRAME, frame_mat="Metal", mullions=(-11, -9), sill=False)
    window(pf, "z", -6, -5, 0, 3, 2, 9, -1, FRAME, frame_mat="Metal", sill=False)
    window(pf, "z", -6, -5, -13, -9, 12, 18, -1, FRAME, frame_mat="Metal", transoms=(15,))
    window(pf, "z", -6, -5, -2, 3, 12, 18, -1, FRAME, frame_mat="Metal", transoms=(15,))
    door(pf, "z", -6, -5, -8, -4, 11, 7, (60, 62, 66))
    # балкон на консоли со стеклянными перилами
    pf.box((-11, 10, -10), (1, 11, -7), "Concrete", BAND)
    pf.box((-11, 11, -10), (1, 14, -9), "Glass", (190, 226, 240))
    for x in (-11, 0):
        pf.box((x, 11, -9), (x + 1, 14, -7), "Glass", (190, 226, 240))
    pf.box((-11, 14, -10), (1, 15, -9), "Metal", FRAME)
    pf.lamp((-6, 9, -9), color=WARM)
    # кухня: большое окно на фасаде и сбоку
    window(pf, "z", -4, -3, 6, 14, 2, 9, -1, FRAME, frame_mat="Metal", mullions=(10,), transoms=(6,), sill=False)
    window(pf, "x", 15, 16, 0, 6, 3, 8, 1, FRAME, frame_mat="Metal")
    # боковые и задние окна дома
    for y0, y1 in ((3, 8), (12, 18)):
        window(pf, "x", -14, -13, -4, 0, y0, y1, -1, FRAME, frame_mat="Metal")
    for a0 in (-12, -4):
        window(pf, "z", 9, 10, a0, a0 + 4, 12, 18, 1, FRAME, frame_mat="Metal")
    window(pf, "z", 9, 10, 8, 12, 3, 8, 1, FRAME, frame_mat="Metal")

    # ---- первый этаж: проход на кухню, камин, диван, лестница
    pf.cut((3, 1, 0), (4, 9, 6))
    pf.box((-13, 1, 0), (-11, 2, 5), "Stone", (112, 110, 104))
    pf.box((-13, 2, 0), (-12, 7, 5), "Stone", (96, 94, 90))
    pf.box((-12, 2, 0), (-11, 7, 1), "Stone", (136, 132, 124))
    pf.box((-12, 2, 4), (-11, 7, 5), "Stone", (136, 132, 124))
    pf.box((-13, 7, 0), (-11, 8, 5), "Concrete", BAND)
    pf.box((-13, 8, 1), (-12, 10, 4), "Stone", (136, 132, 124))
    pf.box((-12, 2, 2), (-11, 3, 3), "Neon", (255, 140, 40))
    pf.part((-12, 2, 1), (-11, 3, 2), "Neon", (255, 110, 30), "Ball")
    pf.part((-12, 2, 3), (-11, 3, 4), "Neon", (255, 180, 60), "Ball")
    SOFA = (196, 186, 166)
    pf.box((-6, 1, 1), (-4, 3, 4), "Plastic", SOFA)
    pf.box((-4, 1, 0), (-3, 5, 5), "Plastic", (176, 166, 146))
    for z in (0, 4):
        pf.box((-6, 1, z), (-4, 4, z + 1), "Plastic", (176, 166, 146))
    pf.box((-11, 0, 0), (-6, 1, 5), "Wood", (92, 110, 128))                       # ковёр
    table(pf, (-10, 1, 1), (-8, 3, 4), (90, 64, 44), DARK)
    steps(pf, "x", -1, -1, 6, 9, 1, 10, "Wood", base=1, colors=(WOOD, (150, 106, 68)))
    pf.lamp((-6, 9, 1), (2, 1, 2), WARM)

    # кухня: столешницы, холодильник, остров со стульями, аптечка
    pf.box((5, 1, 7), (15, 4, 9), "Wood", (236, 234, 228))
    pf.box((5, 4, 7), (15, 5, 9), "Concrete", (60, 60, 64))
    pf.box((12, 1, 3), (15, 8, 6), "Metal", (200, 204, 210))
    pf.box((7, 1, 2), (11, 4, 4), "Wood", (236, 234, 228))
    pf.box((7, 4, 2), (11, 5, 4), "Concrete", (60, 60, 64))
    pf.item((7, 1, -1), (9, 2, 1), "Seat", face="+z")
    pf.item((9, 1, -1), (11, 2, 1), "Seat", face="+z")
    pf.item((5, 5, 7), (7, 7, 9), "Medkit")
    pf.lamp((9, 9, 3), (2, 1, 2), WARM)

    # ---- второй этаж: перила у лестницы, перегородка спальни, дверь на террасу
    pf.box((-11, 11, 5), (-2, 13, 6), "Glass", (190, 226, 240))
    pf.box((-11, 13, 5), (-2, 14, 6), "Wood", DARK)
    pf.box((-3, 11, 6), (-2, 14, 9), "Wood", DARK)
    pf.box((-13, 11, 1), (3, 20, 2), "Plastic", (232, 226, 212))
    door(pf, "z", 1, 2, -4, 0, 11, 7, (176, 128, 84))
    door(pf, "x", 3, 4, 4, 8, 11, 7, (60, 62, 66), at="hi")
    # спальня: кровать, шкаф, лампа
    pf.box((-13, 11, -4), (-9, 13, 1), "Wood", (128, 84, 52))
    pf.box((-13, 13, -4), (-9, 14, -1), "Plastic", (110, 140, 120))
    pf.box((-13, 13, -1), (-9, 14, 0), "Plastic", WHITE)
    pf.box((-13, 11, 0), (-9, 16, 1), "Wood", DARK)
    pf.box((1, 11, -3), (3, 18, 1), "Wood", (150, 110, 74))
    pf.lamp((-5, 19, -1), (2, 1, 2), WARM)
    # кабинет у лестницы: книжный шкаф, стол и лампа
    pf.box((-2, 11, 8), (1, 18, 9), "Wood", DARK)
    for i, c in enumerate(((190, 52, 48), (52, 92, 184), (226, 184, 60))):
        pf.box((-2 + i, 13, 7), (-1 + i, 15, 8), "Plastic", c)
    pf.lamp((0, 19, 4), color=WARM)

    # ---- терраса на крыше кухни: стеклянный парапет, турель ПВО, шезлонги
    pf.box((5, 11, -5), (17, 13, -4), "Glass", (190, 226, 240))
    pf.box((5, 11, 10), (17, 13, 11), "Glass", (190, 226, 240))
    pf.box((16, 11, -4), (17, 13, 10), "Glass", (190, 226, 240))
    pf.item((11, 11, 2), (14, 13, 5), "AATurret")
    for z in (-3, 6):
        pf.item((6, 11, z), (8, 12, z + 2), "Seat", (230, 230, 226), face="+x")
    pf.cyl((9, 11, 7), (10, 16, 8), "Metal", "y", FRAME)
    pf.part((7, 16, 5), (12, 17, 10), "Plastic", (230, 90, 70), "Cylinder", rot_index(0, 90))
    pf.lamp((15, 11, 9), color=WARM)

    # ---- двор: дорожка, клумбы, дерево
    pf.box((-4, 0, -22), (0, 1, -7), "Stone", (170, 166, 156))
    for x0, x1 in ((-20, -6), (2, 10)):
        pf.box((x0, 0, -20), (x1, 1, -12), "Plastic", (98, 150, 70))
        for x in range(x0 + 8 if x0 < -6 else x0, x1, 2):
            pf.part((x, 1, -13), (x + 1, 2, -12), "Plastic", ((230, 80, 100), (250, 210, 70), (160, 100, 220))[(x // 2) % 3], "Ball")
    pf.cyl((-18, 1, -18), (-16, 8, -16), "Wood", "y", (104, 74, 48))
    pf.ball((-21, 8, -21), (-13, 16, -13), "Plastic", (80, 150, 66))

    pf.start = (-3, 0, -26)
    pf.targets = [("гостиная", (-8, 1, -3)), ("кухня", (9, 1, -2)), ("второй этаж", (1, 11, 4)),
                  ("спальня", (-4, 11, -2)), ("балкон", (-6, 11, -8)), ("терраса", (8, 11, 0))]
    return pf


def villa():
    pf = Prefab("Villa", "house", 4, "Современная вилла", "🏙",
                "Вилла из бетона и бронестекла: консольный второй этаж с неоновой подсветкой, бассейн, "
                "гараж со спорткаром и терраса. Вход охраняют двое солдат.",
                ["Бетон, броня и бронестекло", "Консоль второго этажа и неон", "Бассейн, гараж и терраса",
                 "2 охранника у входа", "Турель ПВО на крыше и аптечка"])
    WHITE = (232, 232, 228)
    GRAPH = (62, 66, 74)
    AGLASS = (120, 184, 255)
    NEON = (90, 230, 255)
    WOOD = (156, 108, 68)
    TILE = (214, 212, 204)
    COOL = (226, 240, 255)

    # ---- первый этаж (белый бетон) и гараж
    pf.box((-21, 0, -3), (21, 1, 17), "Concrete", (196, 196, 192))               # платформа
    pf.box((-19, 0, -1), (3, 1, 15), "Concrete", TILE)
    walls(pf, (-20, 1, -2), (4, 10, 16), "Concrete", WHITE)
    pf.box((4, 1, -2), (20, 10, -1), "Concrete", WHITE)
    pf.box((4, 1, 11), (20, 10, 12), "Concrete", WHITE)
    pf.box((19, 1, -1), (20, 10, 11), "Concrete", WHITE)
    pf.box((4, 0, -1), (19, 1, 11), "Concrete", (120, 122, 126))
    pf.box((-21, 10, -3), (21, 11, 17), "Concrete", WHITE)                         # перекрытие и крыша гаража
    pf.box((-16, 10, -8), (10, 11, -3), "Concrete", WHITE)                         # консоль над входом
    # фасад первого этажа — бронестекло от пола до потолка с бетонными рёбрами
    pf.box((-19, 1, -2), (3, 10, -1), "ArmorGlass", AGLASS)
    for x in (-15, -10, -1):
        pf.box((x, 1, -2), (x + 1, 10, -1), "Concrete", WHITE)
    door(pf, "z", -2, -1, -6, -2, 1, 7, (52, 56, 64))
    pf.box((-6, 8, -2), (-2, 10, -1), "Concrete", WHITE)
    # гараж: подъёмные ворота, деревянная обшивка, неон над воротами
    pf.box((4, 1, -3), (20, 10, -2), "Wood", WOOD)
    door(pf, "z", -3, -1, 8, 16, 1, 7, (70, 74, 82))
    pf.box((8, 8, -3), (16, 10, -1), "Concrete", WHITE)
    pf.box((8, 8, -4), (16, 9, -3), "Neon", NEON)
    # боковые окна-щели
    window(pf, "x", -20, -19, 2, 12, 3, 8, -1, None, glass="ArmorGlass", glass_color=AGLASS)
    window(pf, "z", 15, 16, -16, -4, 3, 8, 1, None, glass="ArmorGlass", glass_color=AGLASS)

    # ---- второй этаж: графитовый объём, длинное окно, плоская крыша с подсветкой
    walls(pf, (-16, 11, -8), (10, 20, 16), "Steel", GRAPH)
    pf.box((-15, 10, -7), (9, 11, 15), "Wood", (176, 134, 92))                     # пол второго этажа
    pf.cut((-9, 10, 12), (-1, 11, 15))                                            # проём над лестницей
    pf.box((-15, 12, -8), (9, 18, -7), "ArmorGlass", AGLASS)
    for x in (-8, 1):
        pf.box((x, 12, -8), (x + 1, 18, -7), "Steel", GRAPH)
    window(pf, "x", -16, -15, -4, 12, 12, 18, -1, None, glass="ArmorGlass", glass_color=AGLASS)
    window(pf, "z", 15, 16, -12, 4, 13, 17, 1, None, glass="ArmorGlass", glass_color=AGLASS)
    pf.box((-18, 20, -10), (12, 21, 18), "Concrete", WHITE)
    # неоновые линии под консолями
    pf.box((-16, 9, -8), (10, 10, -7), "Neon", NEON)
    pf.box((-18, 19, -10), (12, 20, -9), "Neon", NEON)
    pf.box((-18, 19, -9), (-17, 20, 18), "Neon", NEON)
    pf.box((-21, 9, -3), (-20, 10, 17), "Neon", NEON)
    # крыша: турель ПВО, солнечные панели, парапет
    pf.item((-2, 21, 2), (1, 23, 5), "AATurret")
    for x0 in (-14, -9, 4):
        pf.wedge((x0, 21, 8), (x0 + 4, 22, 14), "Glass", "-z", (40, 60, 110))
    pf.box((-18, 21, 17), (12, 22, 18), "Concrete", (200, 200, 196))

    # ---- терраса на крыше гаража
    pf.box((10, 11, -3), (21, 13, -2), "Glass", (200, 232, 245))
    pf.box((20, 11, -2), (21, 13, 17), "Glass", (200, 232, 245))
    pf.box((10, 11, 16), (20, 13, 17), "Glass", (200, 232, 245))
    door(pf, "x", 9, 10, 6, 10, 11, 7, (52, 56, 64), at="hi")
    for z in (0, 4):
        pf.item((15, 11, z), (17, 12, z + 2), "Seat", (240, 240, 236), face="-x")
        pf.box((17, 11, z), (18, 13, z + 2), "Plastic", (240, 240, 236))
    pf.box((12, 11, 12), (14, 13, 14), "Concrete", (90, 92, 96))
    pf.ball((12, 13, 12), (14, 15, 14), "Plastic", (70, 140, 70))
    pf.lamp((19, 11, 15), color=COOL)

    # ---- первый этаж внутри: гостиная, кухня с островом, лестница, аптечка
    pf.box((-18, 1, 1), (-16, 3, 9), "Plastic", (60, 62, 68))                      # угловой диван
    pf.box((-16, 1, 1), (-10, 3, 3), "Plastic", (60, 62, 68))
    pf.box((-19, 1, 1), (-18, 5, 9), "Plastic", (48, 50, 56))
    pf.box((-14, 1, 5), (-11, 2, 8), "Wood", WOOD)
    pf.box((-15, 0, 4), (-10, 1, 9), "Plastic", (200, 196, 186))                   # ковёр
    pf.box((-9, 1, 4), (-8, 7, 10), "Steel", GRAPH)                                # стена с экраном
    pf.box((-10, 3, 5), (-9, 6, 9), "Neon", (40, 70, 140))
    pf.box((-6, 1, 3), (0, 4, 6), "Concrete", (40, 42, 46))                         # кухонный остров
    pf.box((-6, 4, 3), (0, 5, 6), "Concrete", (236, 236, 232))
    for x in (-6, -4, -2):
        pf.item((x, 1, 6), (x + 2, 2, 8), "Seat", (40, 42, 46), face="-z")
    pf.box((1, 1, 0), (3, 4, 7), "Concrete", (40, 42, 46))
    pf.box((1, 4, 0), (3, 5, 7), "Concrete", (236, 236, 232))
    pf.box((1, 5, 0), (3, 9, 2), "Metal", (200, 204, 210))
    pf.item((1, 5, 4), (3, 7, 6), "Medkit")
    steps(pf, "x", -1, 1, 12, 15, 1, 10, "Concrete", base=1, colors=((236, 236, 232), (222, 222, 218)))
    for x0 in (-16, -6):
        pf.lamp((x0, 9, 4), (2, 1, 2), COOL)
    pf.lamp((-2, 9, 4), (2, 1, 2), COOL)
    # гараж: спорткар
    CAR = (200, 30, 40)
    pf.box((9, 2, 2), (15, 4, 10), "Metal", CAR)
    pf.wedge((9, 2, 0), (15, 4, 2), "Metal", "-z", CAR)
    pf.wedge((10, 4, 3), (14, 6, 5), "Glass", "-z", (40, 50, 70))
    pf.box((10, 4, 5), (14, 6, 8), "Metal", CAR)
    pf.wedge((10, 4, 8), (14, 5, 10), "Metal", "+z", CAR)
    for x0, x1 in ((8, 9), (15, 16)):
        for z0 in (2, 7):
            pf.cyl((x0, 1, z0), (x1, 4, z0 + 3), "Rubber", "x", (30, 30, 32))
    pf.lamp((11, 9, 5), (2, 1, 2), COOL)

    # ---- второй этаж внутри: спальня, перегородка, перила, кабинет
    pf.box((-15, 11, 4), (9, 20, 5), "Plastic", (236, 232, 222))
    door(pf, "z", 4, 5, 2, 6, 11, 7, (52, 56, 64))
    pf.box((-14, 11, -4), (-6, 13, 3), "Wood", (60, 62, 68))
    pf.box((-14, 13, -4), (-6, 14, 1), "Plastic", (226, 226, 230))
    pf.box((-14, 13, 1), (-6, 14, 2), "Plastic", (110, 160, 220))
    pf.box((-14, 11, 3), (-6, 16, 4), "Wood", WOOD)
    pf.box((-4, 11, 2), (0, 12, 4), "Plastic", (200, 196, 186))
    pf.lamp((-11, 19, -2), (2, 1, 2), COOL)
    pf.box((-9, 11, 11), (0, 13, 12), "Glass", (200, 232, 245))
    pf.box((-1, 11, 12), (0, 13, 15), "Glass", (200, 232, 245))
    pf.box((-9, 13, 11), (0, 14, 12), "Steel", GRAPH)
    pf.box((2, 11, 13), (8, 14, 15), "Wood", WOOD)
    pf.lamp((3, 19, 9), (2, 1, 2), COOL)

    # ---- двор: бассейн с подсветкой, настил, шезлонги; дорожка и подъезд к гаражу; охрана
    pf.box((-22, 0, -22), (-6, 1, -5), "Wood", WOOD)
    pf.box((-20, 1, -19), (-8, 3, -8), "Concrete", (240, 240, 236))
    pf.box((-19, 1, -18), (-9, 2, -9), "Neon", (60, 190, 255))
    pf.box((-19, 2, -18), (-9, 3, -9), "Glass", (90, 180, 240))
    for z0 in (-18, -14):
        pf.item((-22, 1, z0), (-20, 2, z0 + 2), "Seat", (240, 240, 236), face="+x")
    pf.cyl((-20, 1, -8), (-19, 7, -7), "Metal", "y", GRAPH)
    pf.part((-22, 7, -10), (-17, 8, -5), "Plastic", (240, 240, 236), "Cylinder", rot_index(0, 90))
    pf.box((-6, 0, -22), (-2, 1, -3), "Concrete", (226, 224, 216))
    for z in (-19, -14, -9):
        pf.box((-2, 0, z), (-1, 1, z + 1), "Neon", NEON)
    pf.box((8, 0, -22), (16, 1, -3), "Concrete", (74, 76, 80))
    for x in (7, 16):
        pf.box((x, 0, -22), (x + 1, 1, -3), "Neon", NEON)
    pf.item((-9, 1, -6), (-7, 6, -4), "Guard")
    pf.item((-1, 1, -6), (1, 6, -4), "Guard")
    for x in (-12, 2):
        pf.box((x, 1, -7), (x + 2, 3, -5), "Concrete", (90, 92, 96))
        pf.ball((x, 3, -7), (x + 2, 5, -5), "Plastic", (70, 140, 70))

    pf.start = (-5, 0, -26)
    pf.targets = [("гостиная", (-12, 1, 11)), ("кухня", (-4, 1, 9)), ("второй этаж", (2, 11, 8)),
                  ("спальня", (-3, 11, -4)), ("терраса", (13, 11, 2))]
    return pf


def mansion():
    pf = Prefab("Mansion", "house", 5, "Особняк-крепость", "🏰",
                "Трёхэтажный особняк из титана, брони и бронестекла с башнями по углам. На крыше — "
                "вертолётная площадка, две турели ПВО и генератор щита. Охраняют четыре солдата.",
                ["Титан, броня, бронестекло и энергокристалл", "Три этажа и выход на крышу",
                 "Вертолётная площадка с подсветкой", "2 турели ПВО и генератор щита",
                 "4 охранника: у входа и на крыше", "Аптечки на этажах"])
    TI = (206, 210, 220)
    STEEL = (78, 84, 94)
    AG = (120, 184, 255)
    PURPLE = (170, 90, 255)
    CYAN = (90, 230, 255)
    CRYS = (80, 255, 240)
    DARK = (44, 46, 52)
    FLOOR = (60, 64, 72)
    COOL = (230, 240, 255)

    # ---- платформа, стены (низ — броня, выше — титан), перекрытия
    pf.box((-20, 0, -18), (20, 1, 18), "Concrete", (70, 72, 78))
    pf.box((-2, 0, -22), (2, 1, -10), "Plastic", (140, 30, 44))                    # ковровая дорожка
    pf.box((-15, 0, -9), (15, 1, 13), "Obsidian", (40, 30, 52))
    walls(pf, (-16, 1, -10), (16, 10, 14), "Steel", STEEL)
    walls(pf, (-16, 10, -10), (16, 30, 14), "Titanium", TI)
    for y in (10, 20):
        pf.box((-15, y, -9), (15, y + 1, 13), "Steel", FLOOR)
    pf.box((-15, 30, -9), (15, 31, 13), "Titanium", (180, 186, 196))
    pf.cut((-15, 10, 0), (-12, 11, 8))                                             # проёмы над лестницами
    pf.cut((12, 20, 0), (15, 21, 8))
    pf.cut((-15, 30, 0), (-12, 31, 8))
    # неоновые пояса по фасадам между башнями и кристаллические пилоны
    for y, c in ((10, PURPLE), (20, CYAN)):
        pf.box((-13, y, -11), (13, y + 1, -10), "Neon", c)
        pf.box((-13, y, 14), (13, y + 1, 15), "Neon", c)
        pf.box((-17, y, -7), (-16, y + 1, 11), "Neon", c)
        pf.box((16, y, -7), (17, y + 1, 11), "Neon", c)
    for x in (-13, 12):
        pf.box((x, 1, -11), (x + 1, 31, -10), "Crystal", CRYS)

    # ---- четыре круглые башни по углам: титан, неоновые кольца, кристальные шпили
    for cx in (-16, 16):
        for cz in (-10, 14):
            lo = lambda r, y0: (cx - r, y0, cz - r)
            hi = lambda r, y1: (cx + r, y1, cz + r)
            pf.cyl(lo(3, 0), hi(3, 11), "Steel", "y", STEEL)
            pf.cyl(lo(4, 11), hi(4, 12), "Neon", "y", PURPLE)
            pf.cyl(lo(3, 12), hi(3, 23), "Titanium", "y", TI)
            pf.cyl(lo(4, 23), hi(4, 24), "Neon", "y", CYAN)
            pf.cyl(lo(3, 24), hi(3, 35), "Titanium", "y", TI)
            pf.cyl(lo(4, 35), hi(4, 36), "Steel", "y", STEEL)
            pf.cyl(lo(2, 36), hi(2, 40), "Crystal", "y", CRYS)
            pf.ball(lo(1, 40), hi(1, 42), "Neon", PURPLE)

    # ---- фасад: вход 6×8 под козырьком на кристальных колоннах, ленточные окна
    door(pf, "z", -10, -9, -3, 3, 1, 8, (60, 66, 78))
    pf.box((-6, 10, -16), (6, 11, -10), "Steel", STEEL)
    pf.box((-6, 10, -17), (6, 11, -16), "Neon", CYAN)
    for x in (-6, 5):
        pf.box((x, 1, -16), (x + 1, 10, -15), "Crystal", CRYS)
    for x0 in (-11, 5):
        window(pf, "z", -10, -9, x0, x0 + 6, 4, 9, -1, None, glass="ArmorGlass", glass_color=AG)
    for y0, y1 in ((13, 18), (23, 28)):
        window(pf, "z", -10, -9, -11, 11, y0, y1, -1, None, glass="ArmorGlass", glass_color=AG)
        for x in (-6, -1, 4):
            pf.box((x, y0, -10), (x + 2 if x == -1 else x + 1, y1, -9), "Titanium", TI)
        window(pf, "z", 13, 14, -11, 11, y0, y1, 1, None, glass="ArmorGlass", glass_color=AG)
        for x0 in (-16, 15):
            window(pf, "x", x0, x0 + 1, -5, 9, y0, y1, 1 if x0 > 0 else -1, None, glass="ArmorGlass", glass_color=AG)
    for x0 in (-16, 15):
        window(pf, "x", x0, x0 + 1, -5, 9, 4, 9, 1 if x0 > 0 else -1, None, glass="ArmorGlass", glass_color=AG)
    # броневые скосы у основания
    for x0, x1 in ((-12, -7), (7, 12)):
        pf.wedge((x0, 1, -13), (x1, 4, -10), "Steel", "-z", STEEL)
    for x0, face in ((-19, "-x"), (16, "+x")):
        pf.wedge((x0, 1, -6), (x0 + 3, 4, 10), "Steel", face, STEEL)
    # охрана у входа
    for x in (-10, 8):
        pf.item((x, 1, -15), (x + 2, 6, -13), "Guard")

    # ---- лестницы: 1→2 вдоль западной стены, 2→3 вдоль восточной, 3→крыша снова у западной
    stair = ((200, 204, 212), (176, 182, 192))
    steps(pf, "z", 1, -2, -15, -12, 1, 10, "Titanium", base=1, colors=stair)
    steps(pf, "z", 1, -2, 12, 15, 11, 10, "Titanium", base=11, colors=stair)
    steps(pf, "z", 1, -2, -15, -12, 21, 10, "Titanium", base=21, colors=stair)
    for x0, y in ((-12, 11), (11, 21)):
        pf.box((x0, y, -1), (x0 + 1, y + 3, 8), "ArmorGlass", AG)
    pf.box((-15, 11, -1), (-12, 14, 0), "ArmorGlass", AG)
    pf.box((12, 21, -1), (15, 24, 0), "ArmorGlass", AG)

    # ---- первый этаж: холл с кристальным фонтаном, диваны, аптечка
    pf.box((-3, 1, 2), (3, 2, 8), "Titanium", TI)
    pf.box((-2, 1, 3), (2, 2, 7), "Neon", CYAN)
    pf.box((-1, 2, 4), (1, 5, 6), "Crystal", CRYS)
    pf.ball((-2, 5, 3), (2, 9, 7), "Crystal", CRYS)
    for x0, face in ((8, "-x"),):
        for z0 in (-2, 2, 6):
            pf.item((x0 + 3, 1, z0), (x0 + 5, 2, z0 + 2), "Seat", (40, 42, 50), face=face)
    pf.box((14, 1, -3), (15, 5, 10), "Plastic", (40, 42, 50))
    pf.box((7, 1, 1), (10, 3, 7), "Titanium", TI)
    pf.box((-10, 1, 11), (8, 7, 13), "Steel", STEEL)                               # оружейная стойка
    for x in range(-9, 8, 3):
        pf.box((x, 3, 10), (x + 1, 7, 11), "Metal", DARK)
    pf.box((10, 1, 11), (12, 3, 13), "Steel", STEEL)
    pf.item((10, 3, 11), (12, 5, 13), "Medkit")
    for x0 in (-9, 4):
        pf.lamp((x0, 9, -4), (2, 1, 2), COOL)
        pf.lamp((x0, 9, 5), (2, 1, 2), COOL)

    # ---- второй этаж: командный зал — экран, стол, кресла
    pf.box((-7, 11, 12), (7, 19, 13), "Steel", DARK)
    pf.box((-6, 13, 11), (6, 18, 12), "Neon", (30, 90, 160))
    pf.box((-4, 11, 2), (4, 14, 6), "Titanium", TI)
    pf.box((-3, 14, 3), (3, 15, 5), "Neon", CYAN)
    for x in (-4, -1, 2):
        pf.item((x, 11, 7), (x + 2, 12, 9), "Seat", (40, 42, 50), face="-z")
        pf.item((x, 11, -1), (x + 2, 12, 1), "Seat", (40, 42, 50), face="+z")
    pf.item((-11, 11, 10), (-9, 13, 12), "Medkit")
    for x0 in (-6, 4):
        pf.lamp((x0, 19, 0), (2, 1, 2), COOL)
        pf.lamp((x0, 19, 8), (2, 1, 2), COOL)
    # гостевая зона: диван у окна, ковёр, столик; бар напротив
    pf.box((-10, 11, -9), (-4, 13, -7), "Plastic", (52, 54, 62))
    pf.box((-10, 13, -9), (-4, 14, -8), "Plastic", (52, 54, 62))
    pf.box((-9, 10, -6), (-3, 11, -2), "Plastic", (90, 60, 130))
    pf.box((-8, 11, -5), (-5, 12, -3), "Crystal", CRYS)
    pf.box((6, 11, -8), (10, 14, -6), "Titanium", TI)
    pf.box((6, 13, -9), (10, 14, -8), "Neon", PURPLE)

    # ---- третий этаж: спальня хозяина
    pf.box((-6, 21, 6), (4, 23, 13), "Titanium", TI)
    pf.box((-6, 23, 6), (4, 24, 11), "Plastic", (60, 40, 90))
    pf.box((-6, 23, 11), (4, 24, 12), "Plastic", (240, 240, 245))
    pf.box((-6, 21, 12), (4, 28, 13), "Crystal", CRYS)
    for x0 in (-9, 5):
        pf.box((x0, 21, 10), (x0 + 3, 23, 13), "Steel", STEEL)
    pf.item((-8, 23, 11), (-6, 25, 13), "Medkit")
    pf.lamp((6, 23, 11), color=(200, 160, 255))
    pf.box((-4, 20, -6), (4, 21, 0), "Plastic", (60, 40, 90))
    pf.box((6, 21, -8), (10, 23, -5), "Plastic", (60, 40, 90))
    for x0 in (-6, 4):
        pf.lamp((x0, 29, -2), (2, 1, 2), COOL)
        pf.lamp((x0, 29, 6), (2, 1, 2), COOL)

    # ---- крыша: будка над лестницей, площадка с «H», турели, щит, охрана, зубцы
    pf.box((-15, 31, -10), (16, 33, -9), "Titanium", TI)
    pf.box((-16, 31, 13), (16, 33, 14), "Titanium", TI)
    pf.box((-16, 31, -10), (-15, 33, 13), "Titanium", TI)
    pf.box((15, 31, -9), (16, 33, 13), "Titanium", TI)
    for x in (-11, -7, -3, 1, 5, 9):
        for z0 in (-10, 13):
            pf.box((x, 33, z0), (x + 2, 34, z0 + 1), "Titanium", TI)
    walls(pf, (-16, 31, -1), (-11, 38, 11), "ArmorGlass", AG)
    pf.box((-16, 38, -1), (-11, 39, 11), "Titanium", TI)
    pf.box((-16, 37, -2), (-11, 38, -1), "Neon", PURPLE)
    door(pf, "x", -12, -11, 6, 10, 31, 7, (60, 66, 78), at="hi")
    pf.lamp((-14, 37, 4), color=COOL)
    pf.box((-9, 31, -8), (9, 32, 6), "Steel", (56, 60, 66))
    for lo, hi in (((-4, 31, -5), (-2, 32, 3)), ((2, 31, -5), (4, 32, 3)), ((-2, 31, -2), (2, 32, 0))):
        pf.box(lo, hi, "Neon", (255, 210, 60))
    for x in (-9, 8):
        for z in (-8, 5):
            pf.lamp((x, 31, z), color=(255, 80, 60))
    pf.item((-8, 31, 8), (-5, 33, 11), "AATurret")
    pf.item((9, 31, 8), (12, 33, 11), "AATurret")
    pf.box((-2, 31, 7), (3, 32, 12), "Crystal", CRYS)
    pf.item((-1, 32, 8), (2, 35, 11), "Shield")
    pf.item((9, 31, -8), (11, 36, -6), "Guard")
    pf.item((-11, 31, -8), (-9, 36, -6), "Guard")

    pf.start = (-1, 0, -26)
    pf.targets = [("холл", (6, 1, -6)), ("второй этаж", (8, 11, -3)), ("третий этаж", (8, 21, 4)),
                  ("крыша", (0, 32, -2))]
    return pf


def log_segments(a_lo, a_hi, y, holes):
    """Отрезки бревна от a_lo до a_hi на высоте y..y+2 без проёмов holes = [(a0, a1, y0, y1)]."""
    cuts = sorted((a0, a1) for a0, a1, y0, y1 in holes if y0 < y + 2 and y < y1)
    out, a = [], a_lo
    for c0, c1 in cuts:
        if c0 > a:
            out.append((a, c0))
        a = max(a, c1)
    if a < a_hi:
        out.append((a, a_hi))
    return out


DESIGNS = [cabin]


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
