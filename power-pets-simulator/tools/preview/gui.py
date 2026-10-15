"""Рендер дампа PlayerGui (из мока) в PNG по правилам Roblox UI."""
import json
import math
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

import r3d

SS = 2
GUI = {"Frame", "TextLabel", "TextButton", "ScrollingFrame", "ViewportFrame", "ImageLabel", "ImageButton", "TextBox", "CanvasGroup"}
TEXT = {"TextLabel", "TextButton", "TextBox"}
FONTS = {
    "Heavy": "/usr/share/fonts/opentype/inter/InterDisplay-Black.otf",
    "ExtraBold": "/usr/share/fonts/opentype/inter/InterDisplay-ExtraBold.otf",
    "Bold": "/usr/share/fonts/opentype/inter/Inter-Bold.otf",
    "SemiBold": "/usr/share/fonts/opentype/inter/Inter-SemiBold.otf",
    "Regular": "/usr/share/fonts/opentype/inter/Inter-Regular.otf",
}
_font_cache = {}
WARN = []


def font(weight, size):
    size = max(1, int(round(size)))
    key = (weight, size)
    if key not in _font_cache:
        _font_cache[key] = ImageFont.truetype(FONTS.get(weight, FONTS["Bold"]), size)
    return _font_cache[key]


# ---------------------------------------------------------------- значения
def val(v):
    if isinstance(v, dict) and "t" in v:
        return v["v"] if v["t"] != "Font" else v
    return v


def P(node, name, default=None):
    v = node["props"].get(name)
    return default if v is None else val(v)


def color(v, default=(0.64, 0.635, 0.647)):
    return tuple(v) if v is not None else default


def mods(node):
    out = {}
    for c in node["children"]:
        if c["class"] not in GUI and c["class"] not in out:
            out[c["class"]] = c
    return out


def udim2(u, pw, ph):
    return u[0] * pw + u[1], u[2] * ph + u[3]


def seq_color(cs, t):
    t = np.clip(t, 0, 1)
    times = [k[0] for k in cs]
    out = []
    for ch in range(3):
        out.append(np.interp(t, times, [k[1 + ch] for k in cs]))
    return np.stack(out, axis=-1)


def seq_num(ns, t):
    return np.interp(np.clip(t, 0, 1), [k[0] for k in ns], [k[1] for k in ns])


def gradient_t(w, h, rotation, offset):
    ys, xs = np.mgrid[0:h, 0:w]
    u = (xs + 0.5) / max(w, 1) - 0.5 - offset[0]
    v = (ys + 0.5) / max(h, 1) - 0.5 - offset[1]
    a = math.radians(rotation)
    return 0.5 + u * math.cos(a) + v * math.sin(a)


# ---------------------------------------------------------------- раскладка
def own_size(node, cw, ch):
    size = P(node, "Size", [0, 200, 0, 50] if node["class"] in TEXT else [0, 100, 0, 100])
    sc = P(node, "SizeConstraint", "RelativeXY")
    pw, ph = (ch, ch) if sc == "RelativeYY" else (cw, cw) if sc == "RelativeXX" else (cw, ch)
    w, h = size[0] * pw + size[1], size[2] * ph + size[3]
    m = mods(node)
    ar = m.get("UIAspectRatioConstraint")
    if ar:
        r = P(ar, "AspectRatio", 1)
        if P(ar, "DominantAxis", "Width") == "Height" and P(ar, "AspectType", "FitWithinMaxSize") != "FitWithinMaxSize":
            w = h * r
        elif P(ar, "AspectType", "FitWithinMaxSize") == "FitWithinMaxSize":
            if h > 0 and w / h > r:
                w = h * r
            else:
                h = w / r
        else:
            h = w / r
    sz = m.get("UISizeConstraint")
    if sz:
        mn, mx = P(sz, "MinSize", [0, 0]), P(sz, "MaxSize", [1e9, 1e9])
        w, h = min(max(w, mn[0]), mx[0]), min(max(h, mn[1]), mx[1])
    return max(w, 0), max(h, 0)


def gui_children(node):
    return [c for c in node["children"] if c["class"] in GUI]


def sort_layout(children, lay):
    vis = [c for c in children if P(c, "Visible", True)]
    if P(lay, "SortOrder", "LayoutOrder") == "Name":
        return sorted(vis, key=lambda c: P(c, "Name", ""))
    return sorted(vis, key=lambda c: P(c, "LayoutOrder", 0))


def apply_layout(node, cw, ch):
    """Расставляет детей по UIListLayout / UIGridLayout. Возвращает (ширина, высота) содержимого."""
    m = mods(node)
    kids = gui_children(node)
    if "UIListLayout" in m:
        lay = m["UIListLayout"]
        vertical = P(lay, "FillDirection", "Vertical") == "Vertical"
        pad_u = P(lay, "Padding", [0, 0])
        pad = pad_u[0] * (ch if vertical else cw) + pad_u[1]
        items = sort_layout(kids, lay)
        sizes = [own_size(c, cw, ch) for c in items]
        main = sum(s[1] if vertical else s[0] for s in sizes) + pad * max(0, len(items) - 1)
        cross = max([s[0] if vertical else s[1] for s in sizes] or [0])
        if vertical:
            va = P(lay, "VerticalAlignment", "Top")
            pos = {"Top": 0, "Center": (ch - main) / 2, "Bottom": ch - main}[va]
        else:
            ha = P(lay, "HorizontalAlignment", "Left")
            pos = {"Left": 0, "Center": (cw - main) / 2, "Right": cw - main}[ha]
        for c, (w, h) in zip(items, sizes):
            if vertical:
                ha = P(lay, "HorizontalAlignment", "Left")
                x = {"Left": 0, "Center": (cw - w) / 2, "Right": cw - w}[ha]
                c["_lay"] = (x, pos, w, h)
                pos += h + pad
            else:
                va = P(lay, "VerticalAlignment", "Top")
                y = {"Top": 0, "Center": (ch - h) / 2, "Bottom": ch - h}[va]
                c["_lay"] = (pos, y, w, h)
                pos += w + pad
        return (cross, main) if vertical else (main, cross)
    if "UIGridLayout" in m:
        lay = m["UIGridLayout"]
        cell = P(lay, "CellSize", [0, 100, 0, 100])
        cpad = P(lay, "CellPadding", [0, 5, 0, 5])
        cwid, chei = cell[0] * cw + cell[1], cell[2] * ch + cell[3]
        px, py = cpad[0] * cw + cpad[1], cpad[2] * ch + cpad[3]
        items = sort_layout(kids, lay)
        per_row = max(1, int((cw + px + 1e-6) // (cwid + px)))
        maxc = P(lay, "FillDirectionMaxCells", 0)
        if maxc:
            per_row = min(per_row, maxc)
        cols = min(len(items), per_row)
        rows = math.ceil(len(items) / per_row) if items else 0
        gw = cols * cwid + max(0, cols - 1) * px
        gh = rows * chei + max(0, rows - 1) * py
        x0 = {"Left": 0, "Center": (cw - gw) / 2, "Right": cw - gw}[P(lay, "HorizontalAlignment", "Left")]
        y0 = {"Top": 0, "Center": (ch - gh) / 2, "Bottom": ch - gh}[P(lay, "VerticalAlignment", "Top")]
        for i, c in enumerate(items):
            c["_lay"] = (x0 + (i % per_row) * (cwid + px), y0 + (i // per_row) * (chei + py), cwid, chei)
        return gw, gh
    return None


def layout(node, ox, oy, cw, ch, s):
    """ox, oy — экранное начало области содержимого родителя; cw, ch — её размер в локальных единицах; s — масштаб."""
    m = mods(node)
    if "_lay" in node:
        lx, ly, w, h = node.pop("_lay")
        ax, ay = 0, 0
        x, y = lx, ly
    else:
        w, h = own_size(node, cw, ch)
        pos = P(node, "Position", [0, 0, 0, 0])
        ax, ay = P(node, "AnchorPoint", [0, 0])
        x = pos[0] * cw + pos[1] - ax * w
        y = pos[2] * ch + pos[3] - ay * h
    k = P(m["UIScale"], "Scale", 1) if "UIScale" in m else 1
    sx = x + ax * w - ax * w * k
    sy = y + ay * h - ay * h * k
    X, Y, Wd, Hd = ox + s * sx, oy + s * sy, s * w * k, s * h * k
    s2 = s * k
    node["_geo"] = (X, Y, Wd, Hd, s2)
    pad = m.get("UIPadding")
    pl = pr = pt = pb = 0
    if pad:
        pl = P(pad, "PaddingLeft", [0, 0]); pr = P(pad, "PaddingRight", [0, 0])
        pt = P(pad, "PaddingTop", [0, 0]); pb = P(pad, "PaddingBottom", [0, 0])
        pl, pr = pl[0] * w + pl[1], pr[0] * w + pr[1]
        pt, pb = pt[0] * h + pt[1], pb[0] * h + pb[1]
    cx, cy = X, Y
    inner_w, inner_h = w, h
    if node["class"] == "ScrollingFrame":
        cs = P(node, "CanvasSize", [0, 0, 2, 0])
        cvw, cvh = cs[0] * w + cs[1], cs[2] * h + cs[3]
        auto = P(node, "AutomaticCanvasSize", "None")
        content = apply_layout(node, max(cvw if auto in ("None", "Y") else w, w) - pl - pr, max(cvh, h) - pt - pb)
        if content and auto in ("Y", "XY"):
            cvh = max(cvh, content[1] + pt + pb)
            if content[1] + pt + pb > h + 1:
                node["_scroll"] = (content[1] + pt + pb, h)
        if content and auto in ("X", "XY"):
            cvw = max(cvw, content[0] + pl + pr)
        cvw, cvh = max(cvw, w), max(cvh, h)
        cp = P(node, "CanvasPosition", [0, 0])
        cx, cy = X - s2 * cp[0], Y - s2 * cp[1]
        inner_w, inner_h = cvw, cvh
        # раскладку пересчитываем под окончательный размер холста
        for c in node["children"]:
            c.pop("_lay", None)
        apply_layout(node, inner_w - pl - pr, inner_h - pt - pb)
    else:
        apply_layout(node, inner_w - pl - pr, inner_h - pt - pb)
    for c in gui_children(node):
        layout(c, cx + s2 * pl, cy + s2 * pt, inner_w - pl - pr, inner_h - pt - pb, s2)


# ---------------------------------------------------------------- рисование
class Canvas:
    def __init__(self, w, h, bg):
        self.img = Image.new("RGBA", (w * SS, h * SS), bg)

    def paste(self, layer, x, y, clip):
        x, y = int(round(x)), int(round(y))
        cx0, cy0, cx1, cy1 = [int(round(v)) for v in clip]
        lx0, ly0 = max(x, cx0), max(y, cy0)
        lx1, ly1 = min(x + layer.width, cx1), min(y + layer.height, cy1)
        if lx1 <= lx0 or ly1 <= ly0:
            return
        part = layer.crop((lx0 - x, ly0 - y, lx1 - x, ly1 - y))
        self.img.alpha_composite(part, (lx0, ly0))


def shape_layer(w, h, radius, fill_rgb, alpha, grad=None, outline=None):
    """Скруглённый прямоугольник (или обводка) с заливкой/градиентом."""
    w, h = max(1, int(round(w))), max(1, int(round(h)))
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    r = max(0, min(radius, min(w, h) / 2))
    if outline:
        d.rounded_rectangle((0, 0, w - 1, h - 1), radius=r, fill=255)
        t = outline
        inner = Image.new("L", (w, h), 0)
        ImageDraw.Draw(inner).rounded_rectangle((t, t, w - 1 - t, h - 1 - t), radius=max(0, r - t), fill=255)
        mask = Image.fromarray(np.clip(np.array(mask, int) - np.array(inner, int), 0, 255).astype(np.uint8))
    else:
        d.rounded_rectangle((0, 0, w - 1, h - 1), radius=r, fill=255)
    rgb = np.ones((h, w, 3)) * np.array(fill_rgb)
    a = np.ones((h, w)) * alpha
    if grad is not None:
        t = gradient_t(w, h, grad["rotation"], grad["offset"])
        if grad.get("color"):
            rgb = rgb * seq_color(grad["color"], t)
        if grad.get("transparency"):
            a = a * (1 - seq_num(grad["transparency"], t))
    a = a * (np.array(mask) / 255.0)
    arr = np.dstack([np.clip(rgb * 255, 0, 255), np.clip(a * 255, 0, 255)]).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def grad_of(node):
    g = mods(node).get("UIGradient")
    if not g or not P(g, "Enabled", True):
        return None
    return {
        "color": P(g, "Color"),
        "transparency": P(g, "Transparency"),
        "rotation": P(g, "Rotation", 0),
        "offset": P(g, "Offset", [0, 0]),
    }


def wrap_lines(text, fnt, maxw, wrap):
    lines = []
    for para in text.split("\n"):
        if not wrap:
            lines.append(para)
            continue
        words = para.split(" ")
        cur = ""
        for word in words:
            trial = word if not cur else cur + " " + word
            if fnt.getlength(trial) <= maxw or not cur:
                cur = trial
            else:
                lines.append(cur)
                cur = word
        lines.append(cur)
    return lines


def fit_text(text, weight, w, h, maxs, mins, wrap):
    lo, hi = max(1, int(mins)), max(1, int(maxs))
    best = lo
    while lo <= hi:
        mid = (lo + hi) // 2
        f = font(weight, mid)
        lines = wrap_lines(text, f, w, wrap)
        tw = max(f.getlength(l) for l in lines) if lines else 0
        th = len(lines) * mid * 1.0
        too_long_word = wrap and any(f.getlength(word) > w for word in text.split())
        if tw <= w + 0.5 and th <= h + 0.5 and not too_long_word:
            best = mid
            lo = mid + 1
        else:
            hi = mid - 1
    return best


def draw_text(canvas, node, X, Y, W, H, s, clip):
    text = P(node, "Text", "")
    if not text or P(node, "TextTransparency", 0) >= 1:
        return
    ff = node["props"].get("FontFace")
    weight = ff["weight"] if isinstance(ff, dict) and "weight" in ff else "Regular"
    m = mods(node)
    stroke = m.get("UIStroke")
    stroke_w = 0
    stroke_rgb = (0, 0, 0)
    stroke_a = 0
    if stroke and P(stroke, "ApplyStrokeMode", "Contextual") == "Contextual" and P(stroke, "Enabled", True):
        stroke_w = P(stroke, "Thickness", 1) * s * SS
        stroke_rgb = color(P(stroke, "Color"), (0, 0, 0))
        stroke_a = 1 - P(stroke, "Transparency", 0)
    elif P(node, "TextStrokeTransparency", 1) < 1:
        stroke_w = 1 * SS
        stroke_rgb = color(P(node, "TextStrokeColor3"), (0, 0, 0))
        stroke_a = 1 - P(node, "TextStrokeTransparency", 1)
    wrap = P(node, "TextWrapped", False) or P(node, "TextScaled", False)
    if P(node, "TextScaled", False):
        tsc = m.get("UITextSizeConstraint")
        maxs = min(100, P(tsc, "MaxTextSize", 100)) if tsc else 100
        mins = P(tsc, "MinTextSize", 1) if tsc else 1
        size_local = fit_text(text, weight, W / s, H / s, maxs, mins, wrap)
        size = size_local * s
    else:
        size = P(node, "TextSize", 14) * s
    px = size * SS
    f = font(weight, px)
    lines = wrap_lines(text, f, W * SS, wrap)
    line_h = px * 1.0
    total_h = line_h * len(lines)
    ya = P(node, "TextYAlignment", "Center")
    xa = P(node, "TextXAlignment", "Center")
    y0 = {"Top": 0, "Center": (H * SS - total_h) / 2, "Bottom": H * SS - total_h}[ya]
    pad = int(stroke_w + 4)
    lw, lh = int(W * SS + 2 * pad + 8), int(max(H * SS, total_h) + 2 * pad + 8)
    layer = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    rgb = color(P(node, "TextColor3"), (0.106, 0.165, 0.208))
    alpha = 1 - P(node, "TextTransparency", 0)
    asc, desc = f.getmetrics()
    for i, line in enumerate(lines):
        tw = f.getlength(line)
        x = {"Left": 0, "Center": (W * SS - tw) / 2, "Right": W * SS - tw}[xa]
        y = y0 + i * line_h + (line_h - (asc + desc)) / 2
        d.text((pad + x, pad + y), line, font=f, fill=tuple(int(c * 255) for c in rgb) + (int(alpha * 255),),
               stroke_width=int(round(stroke_w)), stroke_fill=tuple(int(c * 255) for c in stroke_rgb) + (int(stroke_a * alpha * 255),))
    g = grad_of(node)
    if g:
        arr = np.array(layer).astype(float)
        t = gradient_t(lw, lh, g["rotation"], g["offset"])
        if g["color"]:
            # градиент красит заливку текста, обводку не трогаем: приблизительно — по яркости пикселя
            gc = seq_color(g["color"], t)
            fill_mask = (np.abs(arr[..., :3] - np.array(rgb) * 255).sum(axis=2) < 60)[..., None]
            arr[..., :3] = np.where(fill_mask, arr[..., :3] * gc, arr[..., :3])
        if g["transparency"]:
            arr[..., 3] *= 1 - seq_num(g["transparency"], t)
        layer = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    canvas.paste(layer, X * SS - pad, Y * SS - pad, clip)
    # проверка: текст не влезает
    widest = max(f.getlength(l) for l in lines)
    if widest > W * SS + 2 or total_h > H * SS + 2:
        WARN.append(f"текст не влезает: «{text[:40]}» ({int(widest / SS)}×{int(total_h / SS)} в {int(W)}×{int(H)})")


def collect_parts(node, out):
    for c in node["children"]:
        cls = c["class"]
        if cls in ("Part", "WedgePart", "MeshPart", "SpawnLocation", "TrussPart", "CornerWedgePart", "Seat"):
            mesh = None
            for mc in c["children"]:
                if mc["class"] == "SpecialMesh":
                    mesh = {"type": P(mc, "MeshType", "Head"), "scale": P(mc, "Scale", [1, 1, 1])}
            out.append({
                "class": cls, "size": P(c, "Size", [4, 1, 2]), "cf": P(c, "CFrame", [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]),
                "shape": P(c, "Shape", "Block"), "mesh": mesh, "color": color(P(c, "Color"), (0.64, 0.64, 0.64)),
                "transparency": P(c, "Transparency", 0), "material": P(c, "Material", "Plastic"), "name": P(c, "Name", ""),
            })
        collect_parts(c, out)
    return out


def find_id(node, ident):
    if node["id"] == ident:
        return node
    for c in node["children"]:
        r = find_id(c, ident)
        if r:
            return r
    return None


def render_viewport(node, W, H):
    camref = node["props"].get("CurrentCamera")
    cam_node = find_id(node, camref["v"]) if camref else None
    if not cam_node:
        WARN.append("ViewportFrame без камеры")
        return None
    parts = collect_parts(node, [])
    if not parts:
        return None
    pos, rot = r3d.cframe(P(cam_node, "CFrame"))
    w, h = max(2, int(W)), max(2, int(H))
    cam = r3d.Camera(pos, rot, P(cam_node, "FieldOfView", 70), w, h)
    polys = []
    for p in parts:
        if p["transparency"] >= 1:
            continue
        for verts, n in r3d.part_polys(p):
            polys.append({"verts": verts, "normal": n, "color": p["color"], "alpha": 1 - p["transparency"],
                          "emissive": p["material"] == "Neon"})
    amb = np.array(color(P(node, "Ambient"), (0.78, 0.78, 0.78)))
    lc = np.array(color(P(node, "LightColor"), (0.55, 0.55, 0.55)))
    ld = P(node, "LightDirection", [-1, -1, -1])
    return r3d.render(polys, cam, (0, 0, 0, 0), ld, amb, lc, ss=3)


def draw_node(canvas, node, clip):
    if node["class"] not in GUI or not P(node, "Visible", True):
        return
    X, Y, W, H, s = node["_geo"]
    rotation = P(node, "Rotation", 0)
    if abs(rotation) > 0.01:
        sub = Canvas(canvas.img.width // SS, canvas.img.height // SS, (0, 0, 0, 0))
        node["props"]["Rotation"] = 0
        draw_node(sub, node, (0, 0, sub.img.width, sub.img.height))
        node["props"]["Rotation"] = rotation
        center = ((X + W / 2) * SS, (Y + H / 2) * SS)
        rotated = sub.img.rotate(-rotation, resample=Image.BICUBIC, center=center)
        canvas.paste(rotated, 0, 0, clip)
        return
    m = mods(node)
    corner = m.get("UICorner")
    radius = 0
    if corner:
        cr = P(corner, "CornerRadius", [0, 8])
        radius = (cr[0] * min(W, H) + cr[1] * s) * SS
    bt = P(node, "BackgroundTransparency", 0)
    g = grad_of(node)
    if bt < 1 and W > 0 and H > 0:
        layer = shape_layer(W * SS, H * SS, radius, color(P(node, "BackgroundColor3")), 1 - bt, g)
        canvas.paste(layer, X * SS, Y * SS, clip)
    stroke = m.get("UIStroke")
    if stroke and P(stroke, "Enabled", True):
        mode = P(stroke, "ApplyStrokeMode", "Contextual")
        if mode == "Border" or node["class"] not in TEXT:
            t = P(stroke, "Thickness", 1) * s * SS
            sg = grad_of(stroke)
            layer = shape_layer(W * SS + 2 * t, H * SS + 2 * t, radius + t if radius else 0,
                                color(P(stroke, "Color"), (0, 0, 0)), 1 - P(stroke, "Transparency", 0), sg, outline=t)
            canvas.paste(layer, X * SS - t, Y * SS - t, clip)
    if node["class"] == "ViewportFrame":
        img = render_viewport(node, W * SS, H * SS)
        if img is not None:
            it = P(node, "ImageTransparency", 0)
            if it > 0:
                arr = np.array(img).astype(float)
                arr[..., 3] *= 1 - it
                img = Image.fromarray(arr.astype(np.uint8))
            canvas.paste(img, X * SS, Y * SS, clip)
    if node["class"] in TEXT:
        draw_text(canvas, node, X, Y, W, H, s, clip)
    child_clip = clip
    if P(node, "ClipsDescendants", False) or node["class"] == "ScrollingFrame":
        child_clip = (max(clip[0], X * SS), max(clip[1], Y * SS), min(clip[2], (X + W) * SS), min(clip[3], (Y + H) * SS))
    kids = sorted(gui_children(node), key=lambda c: P(c, "ZIndex", 1))
    for c in kids:
        draw_node(canvas, c, child_clip)
    if node.get("_scroll") and P(node, "ScrollBarThickness", 12) > 0:
        total, view = node["_scroll"]
        bar_h = H * view / total
        t = P(node, "ScrollBarThickness", 12) * s
        col = color(P(node, "ScrollBarImageColor3"), (0, 0, 0))
        layer = shape_layer(t * SS, bar_h * SS, t * SS / 2, col, 1 - P(node, "ScrollBarImageTransparency", 0))
        canvas.paste(layer, (X + W - t) * SS, Y * SS, clip)


def render_screen(dump, screen, offset, size, out_path, background=None, only=None):
    cw, ch = size
    canvas = Canvas(screen[0], screen[1], (0, 0, 0, 0))
    if background is not None:
        bg = background.convert("RGBA").resize((screen[0] * SS, screen[1] * SS))
        canvas.img.alpha_composite(bg)
    guis = [c for c in dump["children"] if c["class"] == "ScreenGui" and P(c, "Enabled", True)]
    guis.sort(key=lambda g: P(g, "DisplayOrder", 0))
    for g in guis:
        if only and P(g, "Name") not in only:
            continue
        inset = P(g, "ScreenInsets", "CoreUISafeInsets")
        ox, oy = offset if inset != "None" else (0, 0)
        for c in gui_children(g):
            layout(c, ox, oy, cw, ch, 1)
        for c in sorted(gui_children(g), key=lambda c: P(c, "ZIndex", 1)):
            draw_node(canvas, c, (0, 0, canvas.img.width, canvas.img.height))
    img = canvas.img.resize(tuple(screen), Image.LANCZOS)
    img.save(out_path)
    return img


def render_billboards(dump, out_path, ppstud=60):
    cards = []
    for g in dump["children"]:
        if g["class"] != "BillboardGui":
            continue
        size = P(g, "Size", [0, 100, 0, 100])
        w = size[0] * ppstud + size[1]
        h = size[2] * ppstud + size[3]
        w, h = int(max(40, w)), int(max(40, h))
        c = Canvas(w, h, (70, 120, 90, 255))
        for ch_ in gui_children(g):
            layout(ch_, 0, 0, w, h, 1)
        for ch_ in sorted(gui_children(g), key=lambda c: P(c, "ZIndex", 1)):
            draw_node(c, ch_, (0, 0, c.img.width, c.img.height))
        im = c.img.resize((w, h), Image.LANCZOS)
        cards.append((P(g, "Name", "?"), im))
    if not cards:
        return
    pad = 12
    W = max(im.width for _, im in cards) + 2 * pad
    H = sum(im.height + 30 for _, im in cards) + pad
    sheet = Image.new("RGB", (W, H), (30, 30, 40))
    d = ImageDraw.Draw(sheet)
    y = pad
    for name, im in cards:
        d.text((pad, y), name, fill=(255, 255, 0), font=font("Bold", 16))
        sheet.paste(im, (pad, y + 22), im)
        y += im.height + 30
    sheet.save(out_path)


def load_dumps(path):
    dumps = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("@@DUMP "):
                _, tag, payload = line.rstrip("\n").split(" ", 2)
                dumps[tag] = json.loads(payload)
    return dumps


if __name__ == "__main__":
    src, out_dir = sys.argv[1], sys.argv[2]
    offset = (int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) > 4 else (0, 58)
    full = (int(sys.argv[5]), int(sys.argv[6])) if len(sys.argv) > 6 else None
    dumps = load_dumps(src)
    screen_inner = dumps["screen"]
    screen = list(full) if full else [screen_inner[0] + offset[0] * 2 if offset[0] else screen_inner[0], screen_inner[1] + offset[1]]
    bg = None
    try:
        bg = Image.open(f"{out_dir}/scene_player.png")
    except OSError:
        bg = Image.new("RGB", tuple(screen), (120, 180, 110))
    tags = sys.argv[7].split(",") if len(sys.argv) > 7 else ["hud", "pets", "shop", "shop_passes", "worlds", "rebirth", "hatch_shake", "hatch_reveal", "prompt"]
    for tag in tags:
        WARN.clear()
        dump = dumps[tag]
        render_screen(dump, screen, offset, screen_inner, f"{out_dir}/ui_{tag}.png", background=bg)
        uniq = sorted(set(WARN))
        print(tag, "предупреждений:", len(uniq))
        for w in uniq[:25]:
            print("   ", w)
    WARN.clear()
    render_billboards(dumps["prompt"], f"{out_dir}/billboards.png")
    print("billboards", sorted(set(WARN))[:20])
