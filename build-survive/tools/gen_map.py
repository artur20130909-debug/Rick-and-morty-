#!/usr/bin/env python3
"""Генератор карты для «Build & Survive».

Создаёт:
  src/Workspace/Map.model.json        лобби, мосты, вражеские базы, деревья
  src/Workspace/Plots.model.json      6 участков для строительства с вышками и котлованом под полом
  src/ReplicatedStorage/Shared/MapLayout.lua   координаты для скриптов + рельеф (terrain)
  tools/preview/map.json              то же самое для превью-рендера

Запуск: python3 tools/gen_map.py
"""
import json
import math
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rng = random.Random(1337)

FLOOR = 5.0          # высота пола участков и лобби
PLOT_R = 250.0       # расстояние от центра до участков
FORT_R = 600.0       # расстояние до вражеских баз
ISLAND_R = 76.0      # радиус острова участка
LOBBY_R = 92.0       # радиус острова лобби
INNER_RING_TOP = 0.2 # мраморный круг в центре лобби выше пола на столько
PLOT_HALF = 32.0     # половина ширины зоны строительства

PLOT_COLORS = [(226, 64, 64), (56, 128, 236), (64, 196, 96), (246, 200, 50), (160, 84, 230), (250, 132, 40)]
PLOT_NAMES = ["Красный", "Синий", "Зелёный", "Жёлтый", "Фиолетовый", "Оранжевый"]


# ---------------------------------------------------------------- CFrame
def matmul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def matvec(m, v):
    return tuple(sum(m[i][k] * v[k] for k in range(3)) for i in range(3))


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def scale(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def norm(a):
    l = math.sqrt(a[0] ** 2 + a[1] ** 2 + a[2] ** 2)
    return (a[0] / l, a[1] / l, a[2] / l)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


class CF:
    def __init__(self, p=(0, 0, 0), r=None):
        self.p = tuple(float(x) for x in p)
        self.r = r or [[1, 0, 0], [0, 1, 0], [0, 0, 1]]

    def __mul__(self, o):
        return CF(add(self.p, matvec(self.r, o.p)), matmul(self.r, o.r))

    def point(self, v):
        return add(self.p, matvec(self.r, v))

    def vec(self, v):
        return matvec(self.r, v)

    def json(self):
        r = [[round(x, 6) + 0.0 for x in row] for row in self.r]
        return {"CFrame": {"position": [round(x, 4) for x in self.p], "orientation": r}}

    def lua(self):
        c = [*self.p] + [x for row in self.r for x in row]
        return "CFrame.new(%s)" % ", ".join("%.9g" % x for x in c)


def T(x, y, z):
    return CF((x, y, z))


def angles(rx, ry, rz):
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    Rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    Ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    Rz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    return CF((0, 0, 0), matmul(matmul(Rx, Ry), Rz))


def look_at(eye, target, up=(0, 1, 0)):
    back = norm(sub(eye, target))
    right = norm(cross(up, back))
    upv = cross(back, right)
    r = [[right[0], upv[0], back[0]], [right[1], upv[1], back[1]], [right[2], upv[2], back[2]]]
    return CF(eye, r)


VERTICAL = angles(0, 0, math.pi / 2)  # повернуть цилиндр осью вверх
ALONG_Z = angles(0, math.pi / 2, 0)   # повернуть цилиндр осью вдоль -Z

# ---------------------------------------------------------------- детали
PREVIEW = []


def col(c):
    return [round(c[0] / 255, 4), round(c[1] / 255, 4), round(c[2] / 255, 4)]


def part(name, size, cf, color, material="SmoothPlastic", cls="Part", shape=None, transparency=0.0,
         collide=True, shadow=True, children=None, props=None, attrs=None, reflectance=0.0, preview=True):
    p = {
        "Size": [round(s, 4) for s in size],
        "CFrame": cf.json(),
        "Color": col(color),
        "Material": material,
        "Anchored": True,
        "TopSurface": "Smooth",
        "BottomSurface": "Smooth",
    }
    if shape:
        p["Shape"] = shape
    if transparency:
        p["Transparency"] = transparency
    if reflectance:
        p["Reflectance"] = reflectance
    if not collide:
        p["CanCollide"] = False
    if not shadow:
        p["CastShadow"] = False
    if props:
        p.update(props)
    node = {"name": name, "className": cls, "properties": p}
    if children:
        node["children"] = children
    if attrs:
        node["attributes"] = attrs
    if preview and transparency < 1:
        PREVIEW.append({
            "cls": cls, "shape": shape or "Block", "size": list(size), "pos": list(cf.p), "rot": cf.r,
            "color": list(color), "material": material, "transparency": transparency,
        })
    return node


def cyl(name, cf_center, height, diameter, color, material="SmoothPlastic", **kw):
    """Вертикальный цилиндр."""
    return part(name, (height, diameter, diameter), cf_center * VERTICAL, color, material, shape="Cylinder", **kw)


def ball(name, center, d, color, material="SmoothPlastic", **kw):
    return part(name, (d, d, d), T(*center), color, material, shape="Ball", **kw)


def model(name, children, cls="Model", attrs=None):
    node = {"name": name, "className": cls, "children": children}
    if attrs:
        node["attributes"] = attrs
    return node


def folder(name, children):
    return {"name": name, "className": "Folder", "children": children}


def light(kind="PointLight", rng_=16, brightness=1.5, color=(255, 220, 170), shadows=False, angle=None, face=None):
    p = {"Range": rng_, "Brightness": brightness, "Color": col(color), "Shadows": shadows}
    if angle:
        p["Angle"] = angle
    if face:
        p["Face"] = face
    return {"name": kind, "className": kind, "properties": p}


FONT_HEAVY = {"Font": {"family": "rbxasset://fonts/families/BuilderSans.json", "weight": "Heavy", "style": "Normal"}}
FONT_BOLD = {"Font": {"family": "rbxasset://fonts/families/BuilderSans.json", "weight": "Bold", "style": "Normal"}}


def udim2(sx, ox, sy, oy):
    return {"UDim2": [[sx, ox], [sy, oy]]}


def label(name, text, pos, size, color=(255, 255, 255), font=FONT_BOLD, stroke=None, align=None, wrapped=False):
    props = {
        "Text": text, "TextScaled": True, "BackgroundTransparency": 1, "TextColor3": col(color),
        "FontFace": font, "Position": udim2(*pos), "Size": udim2(*size), "TextWrapped": wrapped,
    }
    if align:
        props["TextXAlignment"] = align
    kids = []
    if stroke:
        kids.append({"name": "Stroke", "className": "UIStroke", "properties": {"Thickness": stroke[0], "Color": col(stroke[1])}})
    node = {"name": name, "className": "TextLabel", "properties": props}
    if kids:
        node["children"] = kids
    return node


def surface_gui(children, face="Front", pps=40, light_influence=0.4):
    return {"name": "SurfaceGui", "className": "SurfaceGui", "properties": {
        "Face": face, "SizingMode": "PixelsPerStud", "PixelsPerStud": pps, "LightInfluence": light_influence,
        "ClipsDescendants": True,
    }, "children": children}


# ---------------------------------------------------------------- рельеф
TERRAIN = []


def t_cyl(center, height, radius, material):
    TERRAIN.append({"op": "Cylinder", "pos": list(center), "height": height, "radius": radius, "material": material})


def t_ball(center, radius, material):
    TERRAIN.append({"op": "Ball", "pos": list(center), "radius": radius, "material": material})


def t_block(center, size, material):
    TERRAIN.append({"op": "Block", "pos": list(center), "size": list(size), "material": material})


def island(cx, cz, r, rocks=8, avoid_angles=()):
    t_cyl((cx, -19.7, cz), 40.6, r + 12, "Sand")          # пляж
    t_cyl((cx, -23, cz), 34, r + 24, "Sand")               # подводная ступень (от -40 до -6)
    t_cyl((cx, -19, cz), 42, r, "Ground")                  # тело острова
    t_cyl((cx, 3, cz), 2, r - 1, "Grass")                  # трава
    for i in range(rocks):
        a = rng.uniform(0, math.tau)
        if any(abs((a - b + math.pi) % math.tau - math.pi) < 0.28 for b in avoid_angles):
            continue
        rr = r + rng.uniform(-2, 6)
        t_ball((cx + math.cos(a) * rr, rng.uniform(-1, 2), cz + math.sin(a) * rr), rng.uniform(3.5, 7), "Rock")


# ---------------------------------------------------------------- декор
def tree(name, x, y, z, s=1.0):
    kids = []
    h = 9 * s
    kids.append(cyl("Trunk", T(x, y + h / 2, z), h, 1.6 * s, (110, 78, 52), "Wood"))
    leaf = rng.choice([(74, 124, 52), (62, 112, 48), (88, 140, 60)])
    kids.append(ball("Leaves", (x, y + h + 1.5 * s, z), 8 * s, leaf, "LeafyGrass"))
    kids.append(ball("Leaves2", (x + 2.2 * s, y + h - 0.5 * s, z + 1.2 * s), 5.6 * s, leaf, "LeafyGrass"))
    kids.append(ball("Leaves3", (x - 2 * s, y + h, z - 1.6 * s), 5.2 * s, leaf, "LeafyGrass"))
    return model(name, kids)


def rock_deco(name, x, y, z, s):
    c = rng.choice([(118, 116, 110), (98, 96, 92), (132, 128, 120)])
    return part(name, (s * 1.4, s, s * 1.2), T(x, y + s * 0.3, z) * angles(rng.uniform(-0.3, 0.3), rng.uniform(0, 3), rng.uniform(-0.3, 0.3)), c, "Rock")


def lamp_post(name, x, z, face_angle):
    kids = [
        cyl("Pole", T(x, FLOOR + 4, z), 8, 0.5, (40, 42, 46), "Metal"),
        cyl("Base", T(x, FLOOR + 0.3, z), 0.6, 1.4, (40, 42, 46), "Metal"),
        part("Lamp", (1.2, 1.2, 1.2), T(x, FLOOR + 8.4, z), (255, 226, 170), "Neon",
             children=[light(rng_=18, brightness=1.4, shadows=True)]),
        part("Cap", (1.8, 0.3, 1.8), T(x, FLOOR + 9.15, z), (40, 42, 46), "Metal"),
    ]
    return model(name, kids)


def flag_pole(name, x, z, color, h=14):
    # полотнище смотрит от центра лобби — в сторону своего моста (а не сквозь табло позади флага)
    out = norm((x, 0, z))
    cloth = (x + out[0] * 2.6, FLOOR + h - 2, z + out[2] * 2.6)
    kids = [
        cyl("Pole", T(x, FLOOR + h / 2, z), h, 0.45, (210, 210, 215), "Metal"),
        ball("Top", (x, FLOOR + h + 0.3, z), 0.8, (240, 200, 70), "Metal"),
        part("Cloth", (0.15, 3, 5), look_at(cloth, add(cloth, out)), color, "Fabric"),
    ]
    return model(name, kids)


# ---------------------------------------------------------------- ЛОББИ
def build_lobby(plot_angles):
    kids = []
    island(0, 0, LOBBY_R, rocks=18, avoid_angles=plot_angles)
    # площадь на уровне пола, бортик на 0.1 ниже, мраморный круг — ступенька на 0.2 выше
    # (совпадающие по высоте верхние грани мерцали бы)
    kids.append(cyl("Plaza", T(0, FLOOR - 0.8, 0), 1.6, 78, (104, 108, 116), "Slate"))
    kids.append(cyl("PlazaRim", T(0, FLOOR - 0.9, 0), 1.6, 80, (70, 72, 78), "Slate"))
    kids.append(cyl("InnerRing", T(0, FLOOR + INNER_RING_TOP - 0.6, 0), 1.2, 54, (226, 222, 212), "Marble"))
    kids.append(cyl("Pedestal", T(0, FLOOR + 1.5, 0), 3, 14, (180, 180, 176), "Concrete"))
    kids.append(cyl("PedestalRim", T(0, FLOOR + 3.05, 0), 0.4, 14.6, (240, 196, 70), "Foil", reflectance=0.2))
    # Памятник — списанная ракета
    base_y = FLOOR + 3
    kids.append(cyl("MissileBody", T(0, base_y + 13, 0), 26, 4.2, (236, 236, 240), "SmoothPlastic"))
    kids.append(cyl("MissileBand", T(0, base_y + 18, 0), 1.6, 4.4, (210, 40, 40), "SmoothPlastic"))
    kids.append(cyl("MissileBand2", T(0, base_y + 4, 0), 1.0, 4.4, (30, 30, 34), "SmoothPlastic"))
    for i, (h, d) in enumerate([(2.2, 3.6), (2.0, 2.6), (1.6, 1.5), (1.0, 0.6)]):
        y = base_y + 26 + sum(x[0] for x in [(2.2, 3.6), (2.0, 2.6), (1.6, 1.5), (1.0, 0.6)][:i]) + h / 2
        kids.append(cyl("Nose%d" % i, T(0, y, 0), h, d, (210, 40, 40), "SmoothPlastic"))
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        d = (math.cos(a), 0, math.sin(a))
        p = (d[0] * 3.6, base_y + 3.2, d[2] * 3.6)
        kids.append(part("Fin%d" % i, (0.5, 6, 3.2), look_at(p, add(p, d)), (210, 40, 40), "SmoothPlastic", cls="WedgePart"))
    kids.append(part("Plaque", (6, 1.6, 0.4), T(0, FLOOR + 1.8, 7.05), (40, 40, 44), "Metal", children=[
        surface_gui([label("T", "МИР ВАШЕМУ БУНКЕРУ", (0.05, 0, 0.1, 0), (0.9, 0, 0.8, 0), (240, 200, 90), FONT_HEAVY)], face="Back", pps=50)
    ]))

    # Табло с названием
    board_cf = look_at((0, FLOOR + 14, -31), (0, FLOOR + 14, 0))
    for x in (-22, 22):
        kids.append(cyl("TitlePillar", T(x, FLOOR + 9, -31), 18, 2.4, (60, 62, 70), "Metal"))
    kids.append(part("TitleBoard", (44, 12, 1), board_cf, (22, 26, 36), "SmoothPlastic", children=[
        surface_gui([
            {"name": "Bg", "className": "Frame", "properties": {"Size": udim2(1, 0, 1, 0), "BackgroundColor3": col((20, 24, 36)), "BorderSizePixel": 0},
             "children": [{"name": "G", "className": "UIGradient", "properties": {
                 "Color": {"ColorSequence": {"keypoints": [{"time": 0, "color": col((40, 50, 80))}, {"time": 1, "color": col((14, 16, 24))}]}},
                 "Rotation": 90}}]},
            label("Title", "BUILD & SURVIVE", (0.04, 0, 0.08, 0), (0.92, 0, 0.5, 0), (255, 200, 60), FONT_HEAVY, stroke=(6, (60, 20, 0))),
            label("Sub", "Построй что угодно — и переживи ракетный шторм", (0.06, 0, 0.6, 0), (0.88, 0, 0.18, 0), (230, 236, 255), FONT_BOLD),
            label("Hint", "Твой участок уже ждёт тебя • кнопка «ОСАДА» — начать испытание", (0.1, 0, 0.8, 0), (0.8, 0, 0.12, 0), (150, 170, 210), FONT_BOLD),
        ], face="Front", pps=30, light_influence=0.15),
    ]))
    kids.append(part("TitleFrame", (45, 0.6, 1.4), board_cf * T(0, 6.2, 0), (240, 190, 60), "Metal"))
    kids.append(part("TitleFrame2", (45, 0.6, 1.4), board_cf * T(0, -6.2, 0), (240, 190, 60), "Metal"))

    # Таблица рекордов и правила
    lb_cf = look_at((-36, FLOOR + 9, 4), (0, FLOOR + 9, 4))
    kids.append(part("Leaderboard", (16, 14, 0.8), lb_cf, (20, 24, 34), "SmoothPlastic", children=[
        surface_gui([
            label("Header", "🏆 РЕКОРДЫ СЕРВЕРА", (0.05, 0, 0.03, 0), (0.9, 0, 0.12, 0), (255, 210, 80), FONT_HEAVY),
            {"name": "Rows", "className": "Frame", "properties": {"Position": udim2(0.05, 0, 0.18, 0), "Size": udim2(0.9, 0, 0.78, 0), "BackgroundTransparency": 1}},
        ], face="Front", pps=40, light_influence=0.2),
    ]))
    for dz in (-7, 7):
        kids.append(cyl("LbLeg", T(-36.2, FLOOR + 1, 4 + dz * 0.8), 4, 0.8, (60, 62, 70), "Metal"))
    info_cf = look_at((36, FLOOR + 9, 4), (0, FLOOR + 9, 4))
    lines = [
        "1. Строй на своём участке: блоки, клинья, колёса, двигатели...",
        "2. Нажми «ОСАДА» — по постройке начнут стрелять.",
        "3. Сначала пули, потом мины, ракеты... в конце — ядерка и лазер из космоса!",
        "4. Выживай, получай золото, покупай прочные материалы.",
        "5. После осады постройка восстановится сама.",
    ]
    rows = [label("Header", "КАК ИГРАТЬ", (0.05, 0, 0.03, 0), (0.9, 0, 0.12, 0), (120, 220, 255), FONT_HEAVY)]
    for i, line in enumerate(lines):
        rows.append(label("L%d" % i, line, (0.05, 0, 0.19 + i * 0.155, 0), (0.9, 0, 0.13, 0), (230, 236, 250), FONT_BOLD, align="Left", wrapped=True))
    kids.append(part("InfoBoard", (16, 14, 0.8), info_cf, (20, 24, 34), "SmoothPlastic", children=[surface_gui(rows, pps=40, light_influence=0.2)]))
    for dz in (-7, 7):
        kids.append(cyl("InfoLeg", T(36.2, FLOOR + 1, 4 + dz * 0.8), 4, 0.8, (60, 62, 70), "Metal"))

    # Магазин
    shop_cf = look_at((-18, FLOOR, 27), (0, FLOOR, 0))
    shop = [
        part("Counter", (10, 3.2, 3), shop_cf * T(0, 1.6, 0), (150, 104, 64), "WoodPlanks", children=[
            {"name": "ShopPrompt", "className": "ProximityPrompt", "properties": {
                "ActionText": "Открыть магазин", "ObjectText": "Магазин блоков", "HoldDuration": 0,
                "MaxActivationDistance": 14, "RequiresLineOfSight": False, "KeyboardKeyCode": "E"}},
        ]),
        part("CounterTop", (10.6, 0.4, 3.6), shop_cf * T(0, 3.4, 0), (200, 170, 120), "Wood"),
        part("BackWall", (10, 8, 0.6), shop_cf * T(0, 4, 4), (120, 84, 52), "WoodPlanks"),
        cyl("PostL", shop_cf * T(-4.8, 4.5, -1.6), 9, 0.6, (90, 64, 40), "Wood"),
        cyl("PostR", shop_cf * T(4.8, 4.5, -1.6), 9, 0.6, (90, 64, 40), "Wood"),
        part("Sign", (8, 1.8, 0.4), shop_cf * T(0, 10.2, -1.8), (30, 34, 44), "SmoothPlastic", children=[
            surface_gui([label("T", "🛒 МАГАЗИН", (0.03, 0, 0.08, 0), (0.94, 0, 0.84, 0), (255, 210, 80), FONT_HEAVY)], pps=50, light_influence=0.2)
        ]),
    ]
    for i in range(6):
        c = (230, 64, 52) if i % 2 == 0 else (245, 245, 240)
        x = -4.2 + i * 1.68
        shop.append(part("Awning%d" % i, (1.68, 1.2, 6), shop_cf * T(x, 9, 1) * angles(math.radians(-18), 0, 0), c, "Fabric"))
    # ящики с «блоками» на прилавке
    for i, (c, m) in enumerate([((161, 115, 72), "WoodPlanks"), ((168, 84, 62), "Brick"), ((152, 157, 162), "DiamondPlate"), ((44, 26, 60), "Basalt")]):
        shop.append(part("Sample%d" % i, (1.6, 1.6, 1.6), shop_cf * T(-3.3 + i * 2.2, 4.4, 0) * angles(0, 0.3 * i, 0), c, m))
    kids.append(model("Shop", shop))

    # Спавн лобби: целиком на мраморном круге
    kids.append(part("LobbySpawn", (8, 0.4, 8), T(0, FLOOR + INNER_RING_TOP + 0.2, 22), (255, 196, 64), "SmoothPlastic", cls="SpawnLocation",
                     props={"Neutral": True, "Duration": 0, "AllowTeamChangeOnTouch": False}, transparency=0.2))

    # Флаги участков, фонари, деревья. Фонарь стоит рядом с флагом у выхода к мосту: между мостами
    # уже заняты места табло, магазина и досок, и фонари втыкались бы в их задние стенки
    for i, a in enumerate(plot_angles):
        kids.append(flag_pole("Flag%d" % (i + 1), math.cos(a) * 34, math.sin(a) * 34, PLOT_COLORS[i]))
        a2 = a + math.radians(6)
        kids.append(lamp_post("Lamp%d" % (i + 1), math.cos(a2) * 37, math.sin(a2) * 37, a2))
    trees = []
    n = 0
    while n < 22:
        a = rng.uniform(0, math.tau)
        if any(abs((a - b + math.pi) % math.tau - math.pi) < 0.22 for b in plot_angles):
            continue
        r = rng.uniform(46, LOBBY_R - 8)
        if abs(math.sin(a) * r + 31) < 8 and abs(math.cos(a) * r) < 26:
            continue
        x, z = math.cos(a) * r, math.sin(a) * r
        if abs(x + 36) < 8 and abs(z - 4) < 10 or abs(x - 36) < 8 and abs(z - 4) < 10:
            continue
        trees.append(tree("Tree%d" % n, x, 4, z, rng.uniform(0.85, 1.35)))
        n += 1
    for i in range(10):
        a = rng.uniform(0, math.tau)
        if any(abs((a - b + math.pi) % math.tau - math.pi) < 0.25 for b in plot_angles):
            continue
        r = rng.uniform(LOBBY_R - 10, LOBBY_R - 2)
        trees.append(rock_deco("Rock%d" % i, math.cos(a) * r, 3.5, math.sin(a) * r, rng.uniform(2, 4.5)))
    kids.append(model("Nature", trees))
    return model("Lobby", kids)


# ---------------------------------------------------------------- МОСТЫ
def build_bridge(i, a):
    d = (math.cos(a), 0, math.sin(a))
    r0, r1 = LOBBY_R - 8, PLOT_R - ISLAND_R + 6
    L = r1 - r0
    mid = scale(d, (r0 + r1) / 2)
    cf = look_at((mid[0], FLOOR - 0.5, mid[2]), (mid[0] + d[0], FLOOR - 0.5, mid[2] + d[2]))
    # настил: верх на уровне пола, низ лежит на траве
    kids = [part("Deck", (10, 1, L), cf, (140, 100, 64), "WoodPlanks")]
    for side in (-4.7, 4.7):
        kids.append(part("Rail", (0.5, 0.5, L), cf * T(side, 3.6, 0), (120, 84, 52), "Wood"))
        kids.append(part("RailLow", (0.35, 0.35, L), cf * T(side, 2.0, 0), (120, 84, 52), "Wood"))
        # стойки толще перил и выше их на 0.2, наружу выступают за край настила на 0.1;
        # крайние стоят на 0.1 внутри концов настила, а не свисают с них:
        # ни одна грань не совпадает с гранями настила и перил
        n = int(L // 8)
        for k in range(n + 1):
            z = max(-L / 2 + 0.5, min(L / 2 - 0.5, -L / 2 + k * (L / n)))
            kids.append(part("Post", (0.8, 3.75, 0.8), cf * T(side, 2.175, z), (110, 76, 46), "Wood"))
        # сваи из воды доходят до середины настила
        for k in range(int(L // 16) + 1):
            z = -L / 2 + 4 + k * 16
            if z > L / 2:
                break
            kids.append(cyl("Pile", cf * T(side * 0.85, -6.25, z), 12.5, 1.6, (90, 64, 42), "Wood"))
    return model("Bridge%d" % (i + 1), kids)


# ---------------------------------------------------------------- ВЫШКИ
GROUND = 4.0                 # верх травы острова
T_STEEL = (70, 74, 80)
T_DARK = (40, 42, 46)
T_OLIVE = (66, 76, 56)
T_HAZARD = (240, 190, 40)
T_SAND = (178, 158, 112)


def strip(name, p0, p1, w, t, color, material="SmoothPlastic", **kw):
    """Плоская полоса от p0 до p1: ширина w (горизонтально), толщина t."""
    return part(name, (w, t, math.dist(p0, p1)), look_at(scale(add(p0, p1), 0.5), p1), color, material, **kw)


def local_aabb(node, inv, origin):
    """AABB детали в системе вышки: центр ± |R|·size/2."""
    pr = node["properties"]
    cf = pr["CFrame"]["CFrame"]
    p = matvec(inv, sub(tuple(cf["position"]), origin))
    r = matmul(inv, cf["orientation"])
    h = [sum(abs(r[i][j]) * pr["Size"][j] / 2 for j in range(3)) for i in range(3)]
    return [p[i] - h[i] for i in range(3)], [p[i] + h[i] for i in range(3)]


def check_supported(name, nodes, tcf, ground=GROUND + 0.05, tol=0.05):
    """Без зазоров: низ AABB каждой видимой детали лежит на земле либо касается/входит в AABB
    другой детали, причём по цепочке таких опор деталь доходит до земли."""
    inv = [list(row) for row in zip(*tcf.r)]
    boxes = [(n["name"], *local_aabb(n, inv, tcf.p)) for n in nodes if n["properties"].get("Transparency", 0) < 1]

    def rests_on(a, b):
        (lo, hi), (lo2, hi2) = a[1:], b[1:]
        return (lo2[1] - tol <= lo[1] <= hi2[1] + tol
                and lo[0] <= hi2[0] + tol and lo2[0] <= hi[0] + tol
                and lo[2] <= hi2[2] + tol and lo2[2] <= hi[2] + tol)

    held = {i for i, b in enumerate(boxes) if b[1][1] <= ground}
    grew = True
    while grew:
        grew = False
        for i, b in enumerate(boxes):
            if i not in held and any(rests_on(b, boxes[j]) for j in held):
                held.add(i)
                grew = True
    loose = [boxes[i][0] for i in range(len(boxes)) if i not in held]
    assert not loose, "%s: детали висят в воздухе: %s" % (name, ", ".join(loose))


def build_tower(name, base, center):
    """Пулемётная вышка у угла участка. Возвращает (модель, позиция дула)."""
    # система вышки: начало под колонной на y=0, -Z смотрит на центр участка (только рысканье)
    tcf = look_at((base[0], 0, base[2]), (center[0], 0, center[2]))
    dist = math.hypot(center[0] - base[0], center[2] - base[2])

    def at(x, y, z):
        return tcf * T(x, y, z)

    kids = [
        # бетонное основание (утоплено в траву), колонна, жёлто-чёрное кольцо
        part("Footing", (9, 1.8, 9), at(0, GROUND + 0.1, 0), (150, 148, 142), "Concrete"),
        cyl("Column", at(0, 11.1, 0), 12.2, 4, (124, 124, 120), "Concrete"),
        cyl("HazardRing", at(0, 14, 0), 2, 4.4, T_HAZARD, "Metal"),
        cyl("HazardStripe", at(0, 14, 0), 0.7, 4.6, (28, 28, 30), "Metal"),
        # площадка 8×8 из рифлёного металла: 17.2..18.0
        part("Deck", (8, 0.8, 8), at(0, 17.6, 0), (92, 96, 102), "DiamondPlate"),
    ]
    # лестница снаружи (+Z): стоит на основании, поручни выходят над площадкой
    for sx in (-0.75, 0.75):
        kids.append(part("LadderRail", (0.24, 15.5, 0.24), at(sx, 12.65, 4.1), T_STEEL, "Metal"))
    for k in range(1, 6):
        kids.append(part("Rung", (1.6, 0.2, 0.2), at(0, 5 + 13 * k / 6, 4.1), T_STEEL, "Metal", shape="Cylinder"))
    # перила по бокам (сзади проход к лестнице, спереди мешки)
    for sx in (-3.75, 3.75):
        for sz in (-3.75, 3.75):
            kids.append(cyl("RailPost", at(sx, 19.45, sz), 2.9, 0.3, T_STEEL, "Metal"))  # выше поручня на 0.24
        kids.append(part("Handrail", (0.22, 0.22, 7.8), at(sx, 20.55, 0), T_HAZARD, "Metal"))
    # мешки с песком подковой по краю площадки
    kids.append(part("Sandbags", (6.6, 1, 1), at(0, 18.5, -3.4), T_SAND, "Fabric", shape="Cylinder"))
    for sx in (-3.4, 3.4):
        kids.append(part("Sandbags", (5.5, 1, 1), at(sx, 18.5, -0.15) * ALONG_Z, T_SAND, "Fabric", shape="Cylinder"))

    # турель: поворотное основание 18.0..18.5, голова 3.2×2.2×3.4 стоит на нём (18.5..20.7)
    kids.append(cyl("TurretBase", at(0, 18.25, 0), 0.5, 3.4, (48, 50, 54), "Metal"))
    head = at(0, 19.6, 0)
    kids += [
        part("Head", (3.2, 2.2, 3.4), head, T_OLIVE, "Metal"),
        part("Armor", (3.2, 1.3, 1), head * T(0, -0.45, -2.2), (80, 92, 68), "Metal", cls="WedgePart"),
        part("Eye", (1.6, 0.26, 0.16), head * T(0, 0.85, -1.76), (255, 50, 40), "Neon"),
        part("Scope", (1.7, 0.44, 0.44), head * T(0.95, 1.32, -0.45) * ALONG_Z, (30, 32, 34), "Metal", shape="Cylinder"),
        cyl("Antenna", head * T(-1.2, 2.4, 1.3), 2.6, 0.1, (30, 32, 34), "Metal"),
        # ящик с патронами слева, лента уходит в бок головы
        part("AmmoBox", (0.9, 1.2, 1.6), head * T(-2.05, -0.5, 0.1), (92, 100, 64), "Metal"),
        strip("AmmoBelt", head.point((-2.0, 0.14, 0.3)), head.point((-1.5, 0.48, -0.45)), 0.5, 0.08, (196, 156, 66), "Metal"),
    ]
    # спаренные стволы: из головы вниз к центру участка (только тангаж)
    gun = look_at(head.point((0, 0.3, -1.2)), (center[0], FLOOR + 6, center[2]))
    for sx in (-0.6, 0.6):
        g = gun * T(sx, 0, 0)
        kids += [
            part("Jacket", (4.2, 0.8, 0.8), g * T(0, 0, -1.7) * ALONG_Z, (44, 46, 48), "DiamondPlate", shape="Cylinder"),
            part("Barrel", (1.95, 0.36, 0.36), g * T(0, 0, -4.475) * ALONG_Z, (28, 30, 32), "Metal", shape="Cylinder"),
            part("Brake", (0.5, 0.52, 0.52), g * T(0, 0, -4.9) * ALONG_Z, (70, 72, 76), "Metal", shape="Cylinder"),
        ]
    muzzle_pos = gun.point((0, 0, -5.45))
    # прожектор на правом боку головы, светит вниз на участок
    lamp = look_at(head.point((2.05, 0.35, -0.55)), tcf.point((2.05, FLOOR, -dist * 0.6))) * ALONG_Z
    kids += [
        part("Searchlight", (1.1, 0.9, 0.9), lamp, T_DARK, "Metal", shape="Cylinder",
             children=[light("SpotLight", rng_=45, brightness=3, color=(255, 236, 200), angle=50, face="Right")]),
        part("Lens", (0.1, 0.72, 0.72), lamp * T(0.57, 0, 0), (255, 240, 205), "Neon", shape="Cylinder"),
    ]
    check_supported(name, kids, tcf)
    kids.append(part("Muzzle", (0.4, 0.4, 0.4), T(*muzzle_pos), (0, 0, 0), transparency=1, collide=False, shadow=False,
                     props={"CanQuery": False, "CanTouch": False}))
    return model(name, kids), muzzle_pos


# ---------------------------------------------------------------- УЧАСТКИ
# Всё ниже — в системе участка: пол на y = 0, -Z смотрит на лобби. Трава острова на y = -1.
UG_DEPTH = 24.0              # глубина котлована под зоной строительства (Config.Underground.Depth)
SLAB = 2.0                   # толщина бетонной плиты пола
RIM = 6.0                    # толщина стенок котлована: от ±32 до ±38
RIM_TOP = -0.1               # верх стенок чуть ниже пола (над травой на 0.9)
BEDROCK = 3.0                # толщина дна котлована
PATH_TOP = -0.5              # верх тропинки: на 0.5 выше травы, чтобы рельеф не проступал сквозь неё
SIGN_Z = -43.5               # табличка владельца над концом тропинки (на крыльце)
SIGN_BOTTOM = 7.2            # низ таблички над полом: выше головы персонажа
SIGN_H = 3.8                 # высота таблички
SLAB_COLOR = (164, 166, 164)
SOIL_COLOR = (118, 92, 64)
RIM_COLOR = (78, 80, 84)
BEDROCK_COLOR = (62, 62, 66)
NO_TOUCH = {"CanTouch": False}


def plot_ground(pcf):
    """Заглушка земли, чтобы участок выглядел целым в Studio без запуска: плита пола (Layer = 1, верхний
    слой клеток) и один брусок грунта на всю глубину (Layer = 0: он занимает слои 1–6 сразу).
    При запуске Underground.rebuild удаляет детали без атрибута Rect и собирает слои клеток заново."""
    soil_h = UG_DEPTH - SLAB
    return folder("Ground", [
        part("Slab", (2 * PLOT_HALF, SLAB, 2 * PLOT_HALF), pcf * T(0, -SLAB / 2, 0), SLAB_COLOR, "Concrete",
             props=NO_TOUCH, attrs={"Layer": 1}),
        part("Soil", (2 * PLOT_HALF, soil_h, 2 * PLOT_HALF), pcf * T(0, -SLAB - soil_h / 2, 0), SOIL_COLOR, "Ground",
             props=NO_TOUCH, attrs={"Layer": 0}),
    ])


def plot_foundation(pcf):
    """Неподвижные дно и стенки котлована. Рельеф под участком вырезается при запуске
    (Underground.carveAll: коробка 72×26.5×72), стенки до ±38 закрывают ступеньки вокселей.
    Стенки стоят на дне, а не проходят сквозь него: иначе их наружные и нижние грани совпали бы с гранями дна."""
    outer = 2 * (PLOT_HALF + RIM)           # 76
    wall_h = RIM_TOP + UG_DEPTH             # от дна (-24) до -0.1
    wall_y = (RIM_TOP - UG_DEPTH) / 2
    mid = PLOT_HALF + RIM / 2               # середина стенки: 35
    kids = [part("Bedrock", (outer, BEDROCK, outer), pcf * T(0, -UG_DEPTH - BEDROCK / 2, 0), BEDROCK_COLOR, "Concrete",
                 props=NO_TOUCH)]
    for z in (-mid, mid):  # стенки вдоль X — во всю длину
        kids.append(part("Rim", (outer, wall_h, RIM), pcf * T(0, wall_y, z), RIM_COLOR, "Concrete", props=NO_TOUCH))
    for x in (-mid, mid):  # стенки вдоль Z — между ними
        kids.append(part("Rim", (RIM, wall_h, 2 * PLOT_HALF), pcf * T(x, wall_y, 0), RIM_COLOR, "Concrete", props=NO_TOUCH))
    return folder("Foundation", kids)


def plot_path(pcf):
    """Тропинка от моста к крыльцу с бордюром из камней. Верх тропинки на 0.5 выше травы, низ утоплен
    в рельеф; камни бордюра на 0.2 выше тропинки и заходят в неё на 0.2. Концы спрятаны под настилом
    моста (он начинается с z = -70) и внутри крыльца (с z = -44), так что совпадающих граней нет."""
    z0, z1 = -73.0, -43.0
    bottom = -1.9
    kids = [part("Path", (8, PATH_TOP - bottom, z1 - z0), pcf * T(0, (PATH_TOP + bottom) / 2, (z0 + z1) / 2),
                 (128, 120, 108), "Cobblestone")]
    curb_top = PATH_TOP + 0.2
    count = 12
    span = (z1 - z0 - 0.8) / count  # камни короче тропинки на 0.4 с каждого конца: их торцы не совпадают с её торцами
    for side in (-1, 1):
        for k in range(count):
            z = z0 + 0.4 + (k + 0.5) * span
            c = (98, 96, 92) if (k + (side > 0)) % 2 == 0 else (110, 108, 102)
            kids.append(part("Curb", (0.8, curb_top - bottom, span - 0.15), pcf * T(side * 4.2, (curb_top + bottom) / 2, z),
                             c, "Slate"))
    return kids


def build_plot(i, a, layout):
    center = (math.cos(a) * PLOT_R, FLOOR, math.sin(a) * PLOT_R)
    pcf = look_at(center, (0, FLOOR, 0))
    color = PLOT_COLORS[i]
    island(center[0], center[2], ISLAND_R, rocks=12, avoid_angles=(a + math.pi,))
    kids = [
        plot_ground(pcf),
        plot_foundation(pcf),
        # невидимая плоскость пола: к её верхней грани крепится сетка строительства (клиент)
        part("GridPlane", (2 * PLOT_HALF, 0.2, 2 * PLOT_HALF), pcf * T(0, -0.05, 0), (255, 255, 255), transparency=1,
             collide=False, shadow=False, props={"CanQuery": False, "CanTouch": False}),
        # крыльцо лежит на стенке котлована и не доходит до её внутренней грани (z = -32) на 0.5
        part("Porch", (16, 2, 11.5), pcf * T(0, -1, -38.25), (110, 112, 118), "Slate"),
    ]
    kids += plot_path(pcf)
    # неоновая рамка зоны строительства стоит на стенках котлована; полосы вдоль X — между полосами вдоль Z
    for sx, sz, x, z in ((64, 0.5, 0, 32.25), (64, 0.5, 0, -32.25), (0.5, 65, 32.25, 0), (0.5, 65, -32.25, 0)):
        kids.append(part("Border", (sx, 0.4, sz), pcf * T(x, (RIM_TOP + 0.3) / 2, z), color, "Neon"))
    for x in (-32.5, 32.5):
        for z in (-32.5, 32.5):
            kids.append(cyl("Corner", pcf * T(x, (RIM_TOP + 3) / 2, z), 3 - RIM_TOP, 1.4, (60, 62, 68), "Metal"))
            kids.append(ball("CornerLight", pcf.point((x, 3.3, z)), 1.2, color, "Neon"))
    # табличка владельца — арка над входом с тропинки: низ на SIGN_BOTTOM над крыльцом, под ней проходит персонаж
    sign_y = SIGN_BOTTOM + SIGN_H / 2
    post_top = SIGN_BOTTOM + SIGN_H - 1      # столбы входят в табличку снизу
    for x in (-5.5, 5.5):
        kids.append(cyl("SignPost", pcf * T(x, (post_top - 0.5) / 2, SIGN_Z), post_top + 0.5, 0.8, (60, 62, 68), "Metal"))
    kids.append(part("Sign", (12, SIGN_H, 0.5), pcf * T(0, sign_y, SIGN_Z), (22, 26, 36), "SmoothPlastic", children=[
        surface_gui([
            {"name": "Stripe", "className": "Frame", "properties": {"Size": udim2(1, 0, 0.12, 0), "BackgroundColor3": col(color), "BorderSizePixel": 0}},
            label("Owner", "Свободный участок", (0.04, 0, 0.18, 0), (0.92, 0, 0.5, 0), (255, 255, 255), FONT_HEAVY),
            label("Info", "Участок %d • %s" % (i + 1, PLOT_NAMES[i]), (0.04, 0, 0.7, 0), (0.92, 0, 0.22, 0), (180, 190, 210), FONT_BOLD),
        ], pps=40, light_influence=0.2),
    ]))
    kids.append(part("Spawn", (6, 0.4, 6), pcf * T(0, 0.2, -38), color, "SmoothPlastic", cls="SpawnLocation",
                     props={"Neutral": True, "Duration": 0, "AllowTeamChangeOnTouch": False}, transparency=0.35))
    # пулемётные вышки по углам
    towers = []
    muzzles = []
    for k, (x, z) in enumerate(((-46, -46), (46, -46), (-46, 46), (46, 46))):
        tower, muzzle_pos = build_tower("Tower%d" % (k + 1), pcf.point((x, 0, z)), center)
        towers.append(tower)
        muzzles.append(muzzle_pos)
    kids.append(folder("Towers", towers))
    kids.append(folder("Blocks", []))
    kids.append(folder("Effects", []))
    # деревья на острове (вне зоны строительства и не у вышек)
    nature = []
    n = 0
    tries = 0
    while n < 9 and tries < 200:
        tries += 1
        lx, lz = rng.uniform(-ISLAND_R + 6, ISLAND_R - 6), rng.uniform(-ISLAND_R + 6, ISLAND_R - 6)
        if lx * lx + lz * lz > (ISLAND_R - 6) ** 2:
            continue
        if abs(lx) < 40 and abs(lz) < 40:
            continue
        if abs(lx) < 10 and lz < -30:
            continue
        if any((lx - tx) ** 2 + (lz - tz) ** 2 < 100 for tx, tz in ((-46, -46), (46, -46), (-46, 46), (46, 46))):
            continue
        p = pcf.point((lx, 0, lz))
        nature.append(tree("Tree%d" % n, p[0], 4, p[2], rng.uniform(0.8, 1.2)))
        n += 1
    kids.append(model("Nature", nature))
    layout.append({"index": i + 1, "cf": pcf, "color": color, "towers": muzzles, "angle": a, "center": center})
    return model("Plot%d" % (i + 1), kids, attrs={"PlotIndex": i + 1})


# ---------------------------------------------------------------- ВРАЖЕСКИЕ БАЗЫ
def build_fort(i, a, layout_entry):
    pos = (math.cos(a) * FORT_R, 0, math.sin(a) * FORT_R)
    target = layout_entry["center"]
    fcf = look_at(pos, (target[0], 0, target[2]))
    dark, steel = (58, 62, 68), (84, 88, 96)
    kids = [part("Deck", (96, 4, 72), fcf * T(0, 4, 0), dark, "DiamondPlate")]
    for x in (-40, 0, 40):
        for z in (-28, 28):
            kids.append(cyl("Pylon", fcf * T(x, -14, z), 34, 7, (70, 66, 60), "CorrodedMetal"))
    for x in (-48.3, 48.3):
        kids.append(part("Stripe", (0.6, 1, 72), fcf * T(x, 5.6, 0), (240, 190, 40), "SmoothPlastic"))
    # командная башня
    kids.append(part("Tower", (16, 26, 14), fcf * T(-30, 19, 20), (66, 70, 76), "Concrete"))
    kids.append(part("Windows", (16.2, 1.6, 14.2), fcf * T(-30, 27, 20), (255, 90, 60), "Neon"))
    kids.append(part("TowerTop", (18, 1.4, 16), fcf * T(-30, 32.7, 20), (40, 44, 50), "Metal"))
    kids.append(cyl("Antenna", fcf * T(-30, 40, 20), 14, 0.6, (180, 180, 186), "Metal"))
    kids.append(part("AntennaLight", (1.2, 1.2, 1.2), fcf * T(-30, 47.4, 20), (255, 40, 40), "Neon", shape="Ball",
                     children=[light(rng_=30, brightness=3, color=(255, 50, 40))]))
    # радар
    kids.append(cyl("RadarMast", fcf * T(32, 11, 22), 10, 1.6, steel, "Metal"))
    kids.append(part("RadarDish", (0.8, 14, 14), fcf * T(32, 18, 22) * angles(0, 0.6, math.radians(35)), (210, 214, 220), "Metal", shape="Cylinder"))
    # пусковые рельсы с ракетами
    rails = []
    for x in (-10, 0, 10):
        rcf = fcf * T(x, 9, -14) * angles(math.radians(22), 0, 0)
        kids.append(part("Rail", (2.4, 1, 16), rcf, steel, "Metal"))
        kids.append(part("RailMissile", (11, 1.5, 1.5), rcf * T(0, 1.3, -1) * ALONG_Z, (236, 236, 240), "SmoothPlastic", shape="Cylinder"))
        kids.append(ball("RailNose", rcf.point((0, 1.3, -6.6)), 1.5, (210, 40, 40), "SmoothPlastic"))
        kids.append(part("RailBase", (3, 5, 3), fcf * T(x, 5.5, -8), dark, "Metal"))  # низ внутри палубы
        rails.append(rcf.point((0, 2.5, -9)))
    # шахты самонаводящихся ракет
    silos = []
    for x in (8, 22):
        for z in (6, 20):
            kids.append(cyl("Silo", fcf * T(x, 7, z), 2, 8, (90, 94, 100), "Metal"))
            kids.append(cyl("SiloHatch", fcf * T(x, 8.05, z), 0.2, 6.4, (20, 20, 22), "SmoothPlastic"))
            kids.append(cyl("SiloStripe", fcf * T(x, 6.8, z), 0.5, 8.3, (240, 190, 40), "SmoothPlastic"))
            silos.append(fcf.point((x, 12, z)))
    # миномёты
    mortars = []
    for x in (-36, -26, -16):
        mcf = fcf * T(x, 6.5, -24)
        kids.append(cyl("MortarBase", mcf, 1.4, 5, (70, 74, 70), "Metal"))
        bcf = mcf * T(0, 2.2, -0.6) * angles(math.radians(35), 0, 0) * VERTICAL
        kids.append(part("MortarTube", (5, 1.2, 1.2), bcf, (40, 44, 40), "Metal", shape="Cylinder"))
        mortars.append(mcf.point((0, 5, -2.2)))
    # ящики и флаги: каждый ящик в своей ячейке через 16 стадов (одинаковые верхние грани не пересекаются),
    # перед командной башней
    for k in range(6):
        c = rng.choice([(70, 90, 70), (110, 96, 70), (80, 84, 92)])
        x = -40 + k * 16 + rng.uniform(-3, 3)
        kids.append(part("Crate", (6, 3.4, 3.4), fcf * T(x, 7.7, rng.uniform(29.5, 33.5)) * angles(0, rng.uniform(-0.2, 0.2), 0), c, "Metal"))
    for x in (-46, 46):
        kids.append(cyl("FlagPole", fcf * T(x, 13, -34), 18, 0.5, (190, 190, 196), "Metal"))
        kids.append(part("FlagCloth", (0.15, 3.4, 6), fcf * T(x, 19.6, -34) * angles(0, math.pi / 2, 0) * T(0, 0, 3), (150, 20, 24), "Fabric"))
    layout_entry["fort"] = {"cf": fcf, "rails": rails, "silos": silos, "mortars": mortars}
    return model("Fort%d" % (i + 1), kids)


# ---------------------------------------------------------------- ГОРЫ НА ГОРИЗОНТЕ
def mountains():
    for k in range(14):
        a = k / 14 * math.tau + rng.uniform(-0.12, 0.12)
        r = rng.uniform(1150, 1500)
        x, z = math.cos(a) * r, math.sin(a) * r
        size = rng.uniform(150, 230)
        t_ball((x, -size * 0.35, z), size, "Rock")
        t_ball((x + rng.uniform(-40, 40), size * 0.35, z + rng.uniform(-40, 40)), size * 0.42, "Rock")
        t_ball((x, size * 0.62, z), size * 0.18, "Snow")
        t_ball((x + rng.uniform(-60, 60), -10, z + rng.uniform(-60, 60)), size * 0.55, "Grass")


# ---------------------------------------------------------------- СБОРКА
def main():
    angles_ = [math.radians(30 + 60 * i) for i in range(6)]
    # море и дно
    t_cyl((0, -20, 0), 40, 1700, "Water")
    t_cyl((0, -46, 0), 12, 1700, "Sand")
    layout = []
    plots = [build_plot(i, a, layout) for i, a in enumerate(angles_)]
    lobby = build_lobby(angles_)
    bridges = [build_bridge(i, a) for i, a in enumerate(angles_)]
    forts = [build_fort(i, a, layout[i]) for i, a in enumerate(angles_)]
    mountains()

    map_tree = {"className": "Folder", "children": [lobby, folder("Bridges", bridges), folder("EnemyForts", forts)]}
    plots_tree = {"className": "Folder", "children": plots}
    ws = os.path.join(ROOT, "src", "Workspace")
    os.makedirs(ws, exist_ok=True)
    json.dump(map_tree, open(os.path.join(ws, "Map.model.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(plots_tree, open(os.path.join(ws, "Plots.model.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    # MapLayout.lua
    def v3(p):
        return "Vector3.new(%.7g, %.7g, %.7g)" % p
    L = ["-- СГЕНЕРИРОВАНО tools/gen_map.py — не редактировать вручную.", "local MapLayout = {}", ""]
    L.append("MapLayout.Floor = %g" % FLOOR)
    L.append("MapLayout.LobbySpawn = Vector3.new(0, %g, 22)" % (FLOOR + 3))
    L.append("MapLayout.Plots = {")
    for p in layout:
        f = p["fort"]
        L.append("\t{")
        L.append("\t\tindex = %d," % p["index"])
        L.append("\t\tcf = %s," % p["cf"].lua())
        L.append("\t\ttowers = { %s }," % ", ".join(v3(m) for m in p["towers"]))
        L.append("\t\tfortCf = %s," % f["cf"].lua())
        L.append("\t\trails = { %s }," % ", ".join(v3(m) for m in f["rails"]))
        L.append("\t\tsilos = { %s }," % ", ".join(v3(m) for m in f["silos"]))
        L.append("\t\tmortars = { %s }," % ", ".join(v3(m) for m in f["mortars"]))
        L.append("\t},")
    L.append("}")
    L.append("")
    L.append("-- Рельеф: строится скриптом TerrainGen при запуске (или командой в Studio, см. README)")
    L.append("MapLayout.Terrain = {")
    for op in TERRAIN:
        if op["op"] == "Cylinder":
            L.append('\t{ "Cylinder", %s, %g, %g, Enum.Material.%s },' % (v3(tuple(op["pos"])), op["height"], op["radius"], op["material"]))
        elif op["op"] == "Ball":
            L.append('\t{ "Ball", %s, %g, Enum.Material.%s },' % (v3(tuple(op["pos"])), round(op["radius"], 2), op["material"]))
        else:
            L.append('\t{ "Block", %s, %s, Enum.Material.%s },' % (v3(tuple(op["pos"])), v3(tuple(op["size"])), op["material"]))
    L.append("}")
    L.append("")
    L.append("return MapLayout")
    open(os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "MapLayout.lua"), "w", encoding="utf-8").write("\n".join(L) + "\n")

    prev = os.path.join(ROOT, "tools", "preview")
    os.makedirs(prev, exist_ok=True)
    json.dump({
        "parts": PREVIEW, "terrain": TERRAIN,
        "plots": [{"index": p["index"], "pos": list(p["cf"].p), "rot": p["cf"].r, "color": p["color"], "towers": p["towers"]} for p in layout],
        "forts": [{"pos": list(p["fort"]["cf"].p), "rot": p["fort"]["cf"].r} for p in layout],
    }, open(os.path.join(prev, "map.json"), "w"))
    print("parts:", len(PREVIEW), "terrain ops:", len(TERRAIN))


if __name__ == "__main__":
    main()
