# Иконка (512×512) и обложка (1920×1080) игры «STAY INSIDE»: python3 tools/make_icon.py
import os, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'branding')
os.makedirs(OUT, exist_ok=True)
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
AMBER, RED = (255, 176, 0), (190, 10, 10)

def font(size):
    try:
        return ImageFont.truetype(BOLD, size)
    except OSError:
        return ImageFont.load_default()

def scene(w, h, house_cx, house_w, title_box):
    rnd = random.Random(7)
    img = Image.new('RGB', (w, h))
    px = np.zeros((h, w, 3), np.float32)
    t = np.linspace(0, 1, h)[:, None]
    px[:] = (np.array([5, 8, 20]) * (1 - t) + np.array([18, 24, 44]) * t)[:, None, :].reshape(h, 1, 3)
    img = Image.fromarray(px.astype(np.uint8))
    d = ImageDraw.Draw(img)
    # звёзды и луна с ореолом
    for _ in range(int(w * h / 2500)):
        x, y = rnd.randrange(w), rnd.randrange(int(h * 0.6))
        c = rnd.randrange(120, 230)
        d.point((x, y), fill=(c, c, c))
    mx, my, mr = int(w * 0.78), int(h * 0.2), int(min(w, h) * 0.09)
    glow = Image.new('RGB', (w, h))
    ImageDraw.Draw(glow).ellipse((mx - mr * 3, my - mr * 3, mx + mr * 3, my + mr * 3), fill=(60, 70, 90))
    img = Image.blend(img, Image.composite(glow, img, glow.convert('L')).filter(ImageFilter.GaussianBlur(mr)), 0.6)
    d = ImageDraw.Draw(img)
    d.ellipse((mx - mr, my - mr, mx + mr, my + mr), fill=(232, 230, 214))
    # земля
    gy = int(h * 0.82)
    d.rectangle((0, gy, w, h), fill=(6, 8, 12))
    # дом-силуэт
    hw = house_w
    hx0, hx1 = house_cx - hw // 2, house_cx + hw // 2
    hy0 = gy - int(hw * 0.55)
    dark = (4, 5, 9)
    d.rectangle((hx0, hy0, hx1, gy), fill=dark)
    d.polygon([(hx0 - hw * 0.08, hy0), (house_cx, hy0 - hw * 0.38), (hx1 + hw * 0.08, hy0)], fill=dark)
    d.rectangle((hx1 - hw * 0.22, hy0 - hw * 0.3, hx1 - hw * 0.12, hy0 - hw * 0.05), fill=dark)
    # окна: одно горит янтарём, в нём силуэт; второе — синий свет телевизора
    ww, wh = int(hw * 0.2), int(hw * 0.22)
    lit = (house_cx - int(hw * 0.28), hy0 + int(hw * 0.1))
    tv = (house_cx + int(hw * 0.1), hy0 + int(hw * 0.1))
    for (x, y), col in ((lit, AMBER), (tv, (70, 120, 255))):
        g = Image.new('RGB', (w, h))
        ImageDraw.Draw(g).rectangle((x - ww * 0.4, y - wh * 0.4, x + ww * 1.4, y + wh * 1.4), fill=tuple(int(c * 0.5) for c in col))
        img = Image.composite(g.filter(ImageFilter.GaussianBlur(ww * 0.5)), img, g.convert('L').filter(ImageFilter.GaussianBlur(ww * 0.5)))
        d = ImageDraw.Draw(img)
        d.rectangle((x, y, x + ww, y + wh), fill=col)
        d.line((x + ww // 2, y, x + ww // 2, y + wh), fill=dark, width=max(2, ww // 14))
        d.line((x, y + wh // 2, x + ww, y + wh // 2), fill=dark, width=max(2, ww // 14))
    # высокая худая фигура в горящем окне
    fx, fy = lit[0] + ww * 0.62, lit[1] + wh * 0.18
    d.ellipse((fx - ww * 0.09, fy, fx + ww * 0.09, fy + ww * 0.2), fill=(10, 6, 4))
    d.polygon([(fx - ww * 0.2, lit[1] + wh), (fx - ww * 0.06, fy + ww * 0.2), (fx + ww * 0.06, fy + ww * 0.2), (fx + ww * 0.2, lit[1] + wh)], fill=(10, 6, 4))
    # дверь
    d.rectangle((house_cx - hw * 0.06, gy - hw * 0.24, house_cx + hw * 0.06, gy), fill=(14, 10, 8))
    # красная плашка оповещения
    bh = int(h * 0.11)
    d.rectangle((0, 0, w, bh), fill=RED)
    f = font(int(bh * 0.5))
    txt = '⚠ EMERGENCY ALERT ⚠'
    tw = d.textlength(txt, font=f)
    d.text(((w - tw) / 2, bh * 0.22), txt, font=f, fill=(255, 255, 255))
    # название с обводкой и свечением
    x0, y0, x1, y1 = title_box
    size = int((y1 - y0) * 0.8)
    f = font(size)
    title = 'STAY INSIDE'
    while d.textlength(title, font=f) > (x1 - x0) and size > 10:
        size -= 2
        f = font(size)
    tw = d.textlength(title, font=f)
    tx, ty = x0 + ((x1 - x0) - tw) / 2, y0
    gl = Image.new('RGB', (w, h))
    ImageDraw.Draw(gl).text((tx, ty), title, font=f, fill=(255, 120, 0))
    img = Image.composite(gl.filter(ImageFilter.GaussianBlur(size * 0.18)), img, gl.convert('L').filter(ImageFilter.GaussianBlur(size * 0.18)))
    d = ImageDraw.Draw(img)
    d.text((tx, ty), title, font=f, fill=AMBER, stroke_width=max(2, size // 18), stroke_fill=(20, 8, 0))
    # строки развёртки, шум, виньетка
    a = np.asarray(img).astype(np.float32)
    a[::3] *= 0.82
    a += np.random.default_rng(3).normal(0, 7, a.shape)
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2)
    a *= np.clip(1.15 - 0.55 * r ** 2, 0.25, 1)[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))

icon = scene(512, 512, 256, 300, (24, 400, 488, 470))
icon.save(os.path.join(OUT, 'icon_512.png'))
thumb = scene(1920, 1080, 600, 760, (1040, 470, 1860, 640))
thumb.save(os.path.join(OUT, 'thumbnail_1920x1080.png'))
print('ok', OUT)
