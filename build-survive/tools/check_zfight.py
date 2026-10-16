#!/usr/bin/env python3
"""Поиск мерцающих граней (z-fighting) на карте «Build & Survive».

Две грани мерцают, когда смотрят в одну сторону, лежат почти в одной плоскости и перекрываются:
видеокарта не может решить, какая из них ближе, и в кадре проступает то одна, то другая.
Скрипт ищет:
  1. пары граней разных деталей: одно направление, расхождение плоскостей не больше TOL
     (0.06 стада), общая видимая площадь больше MIN_AREA (0.05 кв. стада);
  2. боковые поверхности соосных цилиндров одного радиуса (разница радиусов не больше TOL);
  3. верхние грани деталей ближе SURFACE_TOL (0.3 стада) над или под поверхностью рельефа
     (трава, песок, вода): гладкий рельеф Roblox не идеально плоский и проступает сквозь деталь.

Детали читаются из src/Workspace/Map.model.json и Plots.model.json (только видимые,
Transparency < 1): у блоков 6 граней, у клиньев 5 (скат тоже), у цилиндров — торцы
(вписанные многоугольники) и боковая поверхность. Шары пропускаются. Рельеф — операции
MapLayout.Terrain из tools/preview/map.json с котлованами под участками (их вырезает
Underground.carveAll при запуске сервера, см. CARVE_*).
Не считаются места, спрятанные внутри другой непрозрачной детали или глубоко в рельефе:
перед гранью (в 0.03 стада по нормали) должно быть пусто, иначе её никто не увидит.
Земля участков (Ground) ничего не заслоняет: игрок её выкапывает и видит стенки котлована.

Запуск (после генерации карты):
  python3 tools/gen_map.py && python3 tools/check_zfight.py
Код возврата 1, если найдено мерцание, не указанное в EXCEPTIONS.
"""
import fnmatch
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TOL = 0.06           # грани ближе этого считаются совпадающими
MIN_AREA = 0.05      # меньшая общая площадь не заметна
SURFACE_TOL = 0.3    # запас над и под поверхностью рельефа
LOOK = 0.03          # насколько отступить от грани по нормали, проверяя, видна ли она
BURIED = 0.3         # грань глубже этого в рельефе не видна
PARALLEL = 1 - 1e-6  # косинус угла между нормалями «параллельных» граней
CAP_SEGMENTS = 24    # торец цилиндра — вписанный многоугольник

# Котлован под каждым участком (Underground.carveAll): CFrame участка * (0, -13.25, 0), размер 72×26.5×72
CARVE_OFFSET = -13.25
CARVE_HALF = (36.0, 13.25, 36.0)

# Детали, которые во время игры пропадают (землю выкапывают): они ничего не заслоняют
DYNAMIC = ["Plots/*/Ground/*"]

# Намеренные совпадения: (шаблон пути A, шаблон пути B или "terrain", причина).
# Пути вида "Plots/Plot1/Ground/Slab", шаблоны — fnmatch.
EXCEPTIONS = [
    # Заглушка земли из файла карты: при запуске сервер (Underground.rebuild) заменяет её
    # плитой и грунтом по слоям, а рельеф под участком вырезается. Верх грунта (y = -2 от пола)
    # закрыт плитой, низ — дном котлована.
]


# ---------------------------------------------------------------- векторы
def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def scale(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(a):
    l = math.sqrt(dot(a, a))
    return (a[0] / l, a[1] / l, a[2] / l)


class Frame:
    """Положение и поворот детали: rot — строки матрицы, столбцы — локальные оси в мире."""

    def __init__(self, pos, rot):
        self.p = tuple(pos)
        self.axes = [tuple(rot[i][k] for i in range(3)) for k in range(3)]

    def vec(self, v):
        x = (0.0, 0.0, 0.0)
        for k in range(3):
            x = add(x, scale(self.axes[k], v[k]))
        return x

    def point(self, v):
        return add(self.p, self.vec(v))

    def local(self, x):
        d = sub(x, self.p)
        return tuple(dot(d, a) for a in self.axes)


# ---------------------------------------------------------------- 2D-многоугольники
def area2(poly):
    s = 0.0
    for i in range(len(poly)):
        x0, y0 = poly[i - 1]
        x1, y1 = poly[i]
        s += x0 * y1 - x1 * y0
    return s / 2


def ccw(poly):
    return poly if area2(poly) >= 0 else poly[::-1]


def side(a, b, p):
    return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])


def clip(subject, clipper):
    """Пересечение двух выпуклых многоугольников (оба против часовой стрелки)."""
    out = subject
    for i in range(len(clipper)):
        a, b = clipper[i - 1], clipper[i]
        inp, out = out, []
        for j in range(len(inp)):
            p, q = inp[j - 1], inp[j]
            sp, sq = side(a, b, p), side(a, b, q)
            if sq >= 0:
                if sp < 0:
                    t = sp / (sp - sq)
                    out.append((p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])))
                out.append(q)
            elif sp >= 0:
                t = sp / (sp - sq)
                out.append((p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])))
        if not out:
            break
    return out


def inside2(poly, p):
    return all(side(poly[i - 1], poly[i], p) >= 0 for i in range(len(poly)))


def samples(poly, count=400):
    """Точки внутри выпуклого многоугольника и площадь, приходящаяся на каждую."""
    total = area2(poly)
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    step = max(math.sqrt(total / count), 0.02)
    pts = []
    y = min(ys) + step / 2
    while y < max(ys):
        x = min(xs) + step / 2
        while x < max(xs):
            if inside2(poly, (x, y)):
                pts.append((x, y))
            x += step
        y += step
    if not pts:
        cx = sum(xs) / len(xs)
        cy = sum(ys) / len(ys)
        return [(cx, cy)], total
    return pts, total / len(pts)


# ---------------------------------------------------------------- детали
class Part:
    def __init__(self, path, cls, props):
        self.path = path
        self.cls = cls
        self.size = tuple(props["Size"])
        cf = props["CFrame"]["CFrame"]
        self.cf = Frame(cf["position"], cf["orientation"])
        self.shape = props.get("Shape", "Block")
        if cls == "WedgePart":
            self.shape = "Wedge"
        elif cls == "CornerWedgePart":
            self.shape = "CornerWedge"
        self.transparency = props.get("Transparency", 0)
        self.half = tuple(s / 2 for s in self.size)
        # AABB в мире
        h = [sum(abs(self.cf.axes[k][i]) * self.half[k] for k in range(3)) for i in range(3)]
        self.lo = tuple(self.cf.p[i] - h[i] for i in range(3))
        self.hi = tuple(self.cf.p[i] + h[i] for i in range(3))

    def contains(self, x, margin=0.005):
        """Точка внутри детали (с отступом margin от поверхности)."""
        q = self.cf.local(x)
        hx, hy, hz = self.half
        if self.shape == "Ball":
            r = min(self.size) / 2
            return dot(q, q) < (r - margin) ** 2
        if self.shape == "Cylinder":
            r = min(hy, hz)
            return abs(q[0]) < hx - margin and q[1] * q[1] + q[2] * q[2] < (r - margin) ** 2
        if abs(q[0]) >= hx - margin or abs(q[1]) >= hy - margin or abs(q[2]) >= hz - margin:
            return False
        if self.shape == "Wedge":
            # под скатом: скат проходит через центр, наружу смотрит (0, hz, -hy)
            l = math.hypot(hy, hz)
            return (q[1] * hz - q[2] * hy) / l < -margin
        if self.shape == "CornerWedge":
            return False  # не используется на карте; считаем прозрачным для проверки видимости
        return True


class Face:
    def __init__(self, part, normal, verts):
        self.part = part
        self.n = norm(normal)
        self.verts = verts
        k = 1.0 / len(verts)
        self.c = (sum(v[0] for v in verts) * k, sum(v[1] for v in verts) * k, sum(v[2] for v in verts) * k)
        self.lo = tuple(min(v[i] for v in verts) for i in range(3))
        self.hi = tuple(max(v[i] for v in verts) for i in range(3))

    def basis(self):
        helper = (1.0, 0.0, 0.0) if abs(self.n[1]) > 0.9 else (0.0, 1.0, 0.0)
        u = norm(cross(helper, self.n))
        v = cross(self.n, u)
        return u, v

    def project(self, verts, u, v):
        return ccw([(dot(sub(x, self.c), u), dot(sub(x, self.c), v)) for x in verts])

    def lift(self, p2, u, v):
        return add(self.c, add(scale(u, p2[0]), scale(v, p2[1])))


def faces_of(part):
    hx, hy, hz = part.half
    cf = part.cf
    out = []
    if part.shape == "Ball" or part.shape == "CornerWedge":
        return out
    if part.shape == "Cylinder":
        r = min(hy, hz)
        for s in (-1, 1):
            ring = []
            for k in range(CAP_SEGMENTS):
                t = math.tau * k / CAP_SEGMENTS
                ring.append(cf.point((s * hx, math.cos(t) * r, math.sin(t) * r)))
            out.append(Face(part, cf.axes[0] if s > 0 else scale(cf.axes[0], -1), ring))
        return out
    if part.shape == "Wedge":
        a, b, c, d = (-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz)
        e, f = (-hx, hy, hz), (hx, hy, hz)
        local = [
            ((0, -1, 0), (a, b, c, d)),                 # низ
            ((0, 0, 1), (d, c, f, e)),                  # зад
            ((-1, 0, 0), (a, e, d)),                    # левый бок
            ((1, 0, 0), (b, c, f)),                     # правый бок
            ((0, hz, -hy), (a, b, f, e)),               # скат
        ]
        for n, vs in local:
            out.append(Face(part, cf.vec(n), [cf.point(v) for v in vs]))
        return out
    h = (hx, hy, hz)
    for k in range(3):
        u, w = (k + 1) % 3, (k + 2) % 3
        for s in (-1, 1):
            verts = []
            for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                q = [0.0, 0.0, 0.0]
                q[k] = s * h[k]
                q[u] = a * h[u]
                q[w] = b * h[w]
                verts.append(cf.point(q))
            out.append(Face(part, scale(cf.axes[k], s), verts))
    return out


def load_parts():
    parts = []

    def walk(node, path):
        props = node.get("properties", {})
        if "Size" in props and "CFrame" in props and props.get("Transparency", 0) < 1:
            parts.append(Part(path, node["className"], props))
        for child in node.get("children", []):
            walk(child, path + "/" + child["name"])

    for name in ("Map", "Plots"):
        tree = json.load(open(os.path.join(ROOT, "src", "Workspace", name + ".model.json"), encoding="utf-8"))
        walk(tree, name)
    return parts


class Grid:
    """Пространственный хеш по AABB: быстро найти детали рядом с точкой."""

    def __init__(self, cell=16.0):
        self.cell = cell
        self.cells = {}

    def key(self, x):
        return tuple(int(math.floor(c / self.cell)) for c in x)

    def insert(self, item, lo, hi):
        a, b = self.key(lo), self.key(hi)
        for i in range(a[0], b[0] + 1):
            for j in range(a[1], b[1] + 1):
                for k in range(a[2], b[2] + 1):
                    self.cells.setdefault((i, j, k), []).append(item)

    def near(self, x):
        return self.cells.get(self.key(x), ())


# ---------------------------------------------------------------- рельеф
class Terrain:
    def __init__(self, data):
        self.cyls = []   # (центр, низ, верх, радиус, материал)
        self.balls = []  # (центр, радиус)
        self.blocks = [] # (низ, верх) — оси мира
        self.water = []
        for op in data["terrain"]:
            p = tuple(op["pos"])
            if op["op"] == "Cylinder":
                rec = ((p[0], p[2]), p[1] - op["height"] / 2, p[1] + op["height"] / 2, op["radius"], op["material"])
                (self.water if op["material"] == "Water" else self.cyls).append(rec)
            elif op["op"] == "Ball":
                self.balls.append((p, op["radius"]))
            else:
                h = [s / 2 for s in op["size"]]
                self.blocks.append((tuple(p[i] - h[i] for i in range(3)), tuple(p[i] + h[i] for i in range(3))))
        self.carves = [Frame(Frame(pl["pos"], pl["rot"]).point((0, CARVE_OFFSET, 0)), pl["rot"]) for pl in data["plots"]]

    def carved(self, x, margin=0.0):
        for cf in self.carves:
            q = cf.local(x)
            if all(abs(q[i]) <= CARVE_HALF[i] + margin for i in range(3)):
                return True
        return False

    def solid(self, x, margin, balls_only=False):
        """Точка внутри твёрдого рельефа глубже margin. Цилиндры острова стоят друг на друге
        (дно, тело, трава), поэтому столб рельефа считается сплошным от самого нижнего до самого верхнего."""
        if self.carved(x, margin):
            return False
        for c, r in self.balls:
            d = sub(x, c)
            if dot(d, d) < (r - margin) ** 2:
                return True
        if balls_only:
            return False
        lo = hi = None
        for (cx, cz), y0, y1, r, _ in self.cyls:
            if (x[0] - cx) ** 2 + (x[2] - cz) ** 2 < (r - margin) ** 2:
                lo = y0 if lo is None else min(lo, y0)
                hi = y1 if hi is None else max(hi, y1)
        if lo is not None and lo + margin < x[1] < hi - margin:
            return True
        for b0, b1 in self.blocks:
            if all(b0[i] + margin < x[i] < b1[i] - margin for i in range(3)):
                return True
        return False

    def surface(self, x, z):
        """Верх рельефа в точке (x, z): (высота, материал) или None."""
        best = None
        for (cx, cz), y0, y1, r, mat in self.cyls:
            if (x - cx) ** 2 + (z - cz) ** 2 <= r * r and (best is None or y1 > best[0]):
                best = (y1, mat)
        for lo, hi in self.blocks:
            if lo[0] <= x <= hi[0] and lo[2] <= z <= hi[2] and (best is None or hi[1] > best[0]):
                best = (hi[1], "Block")
        if best is not None and self.carved((x, best[0] - 0.01, z)):
            return None  # здесь котлован: его стены и дно закрыты деталями Foundation
        if best is None:
            for (cx, cz), y0, y1, r, mat in self.water:
                if (x - cx) ** 2 + (z - cz) ** 2 <= r * r:
                    return (y1, mat)
        return best


# ---------------------------------------------------------------- проверка
class Checker:
    def __init__(self, parts, terrain):
        self.parts = parts
        self.terrain = terrain
        self.grid = Grid()
        for p in parts:
            if p.transparency == 0 and not any(fnmatch.fnmatch(p.path, d) for d in DYNAMIC):
                self.grid.insert(p, p.lo, p.hi)

    def hidden(self, x, n, skip):
        """Место на грани не видно: прямо перед ним твёрдая деталь или толща рельефа."""
        y = add(x, scale(n, LOOK))
        for p in self.grid.near(y):
            if p not in skip and p.contains(y):
                return True
        return self.terrain.solid(y, BURIED)

    def visible_area(self, face, poly, u, v, skip):
        pts, w = samples(poly)
        return sum(w for p in pts if not self.hidden(face.lift(p, u, v), face.n, skip))

    def face_pairs(self, faces):
        """Совпадающие грани разных деталей."""
        clusters = {}
        groups = []
        for f in faces:
            key = tuple(int(round(c * 1000)) for c in f.n)
            found = None
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    for dz in (-1, 0, 1):
                        for g in clusters.get((key[0] + dx, key[1] + dy, key[2] + dz), ()):
                            if dot(g[0], f.n) > PARALLEL:
                                found = g
                                break
            if found is None:
                found = (f.n, [])
                clusters.setdefault(key, []).append(found)
                groups.append(found)
            found[1].append(f)
        issues = []
        for n, members in groups:
            members.sort(key=lambda f: dot(n, f.c))
            ds = [dot(n, f.c) for f in members]
            for i, a in enumerate(members):
                for j in range(i + 1, len(members)):
                    if ds[j] - ds[i] > TOL + 0.01:
                        break
                    b = members[j]
                    if a.part is b.part:
                        continue
                    if any(a.lo[k] > b.hi[k] + TOL or b.lo[k] > a.hi[k] + TOL for k in range(3)):
                        continue
                    issue = self.pair(a, b)
                    if issue:
                        issues.append(issue)
        return issues

    def pair(self, a, b):
        u, v = a.basis()
        pa = a.project(a.verts, u, v)
        pb = a.project(b.verts, u, v)
        inter = clip(pa, pb)
        if len(inter) < 3 or area2(inter) <= MIN_AREA:
            return None
        gap = max(abs(dot(b.n, sub(a.lift(p, u, v), b.c))) for p in inter)
        if gap > TOL:
            return None
        vis = self.visible_area(a, inter, u, v, (a.part, b.part))
        if vis <= MIN_AREA:
            return None
        cx = sum(p[0] for p in inter) / len(inter)
        cy = sum(p[1] for p in inter) / len(inter)
        return ("грани", a.part.path, b.part.path, gap, vis, a.lift((cx, cy), u, v))

    def cylinder_sides(self):
        """Боковые поверхности соосных цилиндров одного радиуса."""
        cyls = [p for p in self.parts if p.shape == "Cylinder"]
        cyls.sort(key=lambda p: p.lo[0])
        issues = []
        for i, a in enumerate(cyls):
            ax = a.cf.axes[0]
            ra = min(a.half[1], a.half[2])
            for b in cyls[i + 1:]:
                if b.lo[0] > a.hi[0] + TOL:
                    break
                if any(a.lo[k] > b.hi[k] + TOL or b.lo[k] > a.hi[k] + TOL for k in (1, 2)):
                    continue
                rb = min(b.half[1], b.half[2])
                if abs(ra - rb) > TOL or abs(dot(ax, b.cf.axes[0])) < PARALLEL:
                    continue
                d = sub(b.cf.p, a.cf.p)
                along = dot(d, ax)
                off = sub(d, scale(ax, along))
                if dot(off, off) > TOL * TOL:
                    continue
                t0 = max(-a.half[0], along - b.half[0])
                t1 = min(a.half[0], along + b.half[0])
                if t1 - t0 <= 0:
                    continue
                full = math.tau * ra * (t1 - t0)
                if full <= MIN_AREA:
                    continue
                # видимость: кольца точек по длине общего участка
                e1, e2 = a.cf.axes[1], a.cf.axes[2]
                total = seen = 0
                for k in range(5):
                    t = t0 + (t1 - t0) * (k + 0.5) / 5
                    for m in range(16):
                        ang = math.tau * m / 16
                        radial = add(scale(e1, math.cos(ang)), scale(e2, math.sin(ang)))
                        x = add(a.cf.point((t, 0, 0)), scale(radial, ra))
                        total += 1
                        if not self.hidden(x, radial, (a, b)):
                            seen += 1
                vis = full * seen / total
                if vis > MIN_AREA:
                    issues.append(("бока цилиндров", a.path, b.path, abs(ra - rb), vis, a.cf.p))
        return issues

    def terrain_faces(self, faces):
        """Верхние грани у самой поверхности рельефа."""
        issues = []
        for f in faces:
            if f.n[1] < 0.98:
                continue
            u, v = f.basis()
            poly = f.project(f.verts, u, v)
            pts, w = samples(poly, 900)
            area = 0.0
            worst = None
            for p in pts:
                x = f.lift(p, u, v)
                s = self.terrain.surface(x[0], x[2])
                if s is None:
                    continue
                dy = x[1] - s[0]
                if abs(dy) > SURFACE_TOL:
                    continue
                y = add(x, scale(f.n, LOOK))
                if self.terrain.solid(y, 0.0, balls_only=True):
                    continue
                if any(q is not f.part and q.contains(y) for q in self.grid.near(y)):
                    continue
                area += w
                worst = (dy, s[1], x)
            if area > MIN_AREA:
                issues.append(("рельеф (%s)" % worst[1], f.part.path, "terrain", worst[0], area, worst[2]))
        return issues


def excepted(issue):
    _, a, b = issue[:3]
    for pa, pb, _ in EXCEPTIONS:
        if (fnmatch.fnmatch(a, pa) and fnmatch.fnmatch(b, pb)) or (fnmatch.fnmatch(b, pa) and fnmatch.fnmatch(a, pb)):
            return True
    return False


def main():
    data = json.load(open(os.path.join(ROOT, "tools", "preview", "map.json"), encoding="utf-8"))
    parts = load_parts()
    terrain = Terrain(data)
    checker = Checker(parts, terrain)
    faces = [f for p in parts for f in faces_of(p)]
    issues = checker.face_pairs(faces) + checker.cylinder_sides() + checker.terrain_faces(faces)
    issues.sort(key=lambda it: (it[1], it[2]))
    print("деталей: %d, граней: %d, операций рельефа: %d" % (len(parts), len(faces), len(data["terrain"])))
    bad = 0
    for issue in issues:
        kind, a, b, gap, area, pos = issue
        skip = excepted(issue)
        bad += 0 if skip else 1
        what = "до поверхности %+.2f" % gap if b == "terrain" else "зазор %.3f" % gap
        print("%s: %s  ×  %s  — %s, площадь %.2f, у (%.1f, %.1f, %.1f)%s"
              % (kind, a, b, what, area, *pos, "  (исключение)" if skip else ""))
    print("мерцающих мест: %d (исключений: %d)" % (bad, len(issues) - bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
