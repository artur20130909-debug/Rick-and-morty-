# Обложки из скриншотов игры: python3 tools/make_covers.py <скрин1> <скрин2> <скрин3>
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'branding')
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
F = lambda s: ImageFont.truetype(BOLD, s)

def grade(img, tint, dark):
    a = np.asarray(img).astype(np.float32) / 255
    a = a ** 1.25 * np.array(tint) * dark
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2)
    a *= np.clip(1.2 - 0.6 * r ** 2, 0.15, 1)[..., None]
    a[::3] *= 0.88
    a += np.random.default_rng(1).normal(0, 0.025, a.shape)
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))

def glowtext(img, xy, text, f, col, glow):
    g = Image.new('L', img.size)
    ImageDraw.Draw(g).text(xy, text, font=f, fill=255)
    gb = g.filter(ImageFilter.GaussianBlur(f.size * 0.2))
    img.paste(Image.new('RGB', img.size, glow), (0, 0), gb)
    ImageDraw.Draw(img).text(xy, text, font=f, fill=col, stroke_width=max(3, f.size // 20), stroke_fill=(15, 5, 0))

def load(src, box):
    im = Image.open(src).convert('RGB')
    k = im.size[0] / 2000            # координаты заданы для ширины 2000
    cx, cy, r = int(1000 * k), int(461 * k), int(22 * k)   # убираем точку прицела
    patch = im.crop((cx - 4 * r, cy - 4 * r, cx + 4 * r, cy + 4 * r)).filter(ImageFilter.GaussianBlur(r))
    mask = Image.new('L', patch.size)
    ImageDraw.Draw(mask).ellipse((3 * r, 3 * r, 5 * r, 5 * r), fill=255)
    im.paste(patch, (cx - 4 * r, cy - 4 * r), mask.filter(ImageFilter.GaussianBlur(r * 0.3)))
    # кнопки Roblox и мобильные кнопки (Бег/Присесть) — сильно размываем
    for x0, y0, x1, y1 in ((120, 20, 560, 165), (1420, 600, 1860, 900), (430, 800, 1560, 905)):
        b = tuple(int(v * k) for v in (x0, y0, x1, y1))
        reg = im.crop(b)
        dark = Image.new('RGB', reg.size, (8, 10, 18))
        im.paste(Image.blend(reg.filter(ImageFilter.GaussianBlur(40 * k)), dark, 0.55), b[:2])
    return im.crop(tuple(int(v * k) for v in box))

def cover(src, box, tint, dark, title_pos, sub, name, size=(1920, 1080)):
    im = load(src, box).resize(size, Image.LANCZOS)
    im = grade(ImageEnhance.Contrast(im).enhance(1.15), tint, dark)
    w, h = size
    d = ImageDraw.Draw(im, 'RGBA')
    for i in range(300):  # затемнение снизу под название
        d.line((0, h - i, w, h - i), fill=(0, 0, 0, int(230 * (1 - i / 300))))
    bh = int(h * 0.09)
    d.rectangle((0, 0, w, bh), fill=(175, 8, 8, 235))
    f = F(int(bh * 0.5)); t = '⚠  EMERGENCY ALERT  ⚠'
    d.text(((w - d.textlength(t, font=f)) / 2, bh * 0.22), t, font=f, fill='white')
    f = F(int(h * 0.15)); t = 'STAY INSIDE'
    tw = ImageDraw.Draw(im).textlength(t, font=f)
    x = (w - tw) / 2 if title_pos == 'c' else w * 0.05
    glowtext(im, (x, h * 0.72), t, f, (255, 180, 20), (255, 90, 0))
    f2 = F(int(h * 0.035))
    ImageDraw.Draw(im).text((x + 6, h * 0.9), sub, font=f2, fill=(230, 220, 200))
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, name), quality=92)
    return im

stairs, tv, lobby = sys.argv[1:4]
cover(stairs, (560, 150, 1440, 645), (0.75, 0.8, 1.15), 0.85, 'c', 'Не поднимайся наверх. Он уже в доме.', 'cover_stairs.png')
cover(tv, (500, 250, 1420, 768), (1.05, 0.9, 0.85), 1.0, 'c', '21:00 — слушай оповещение. Оно спасёт тебе жизнь.', 'cover_tv.png')
cover(lobby, (200, 70, 1700, 914), (0.9, 0.9, 1.1), 1.0, 'c', 'Выбери кабинку. Переживи все ночи.', 'cover_lobby.png')
# иконка 512×512 из кадра с телевизором
im = load(tv, (930, 260, 1430, 760)).resize((512, 512), Image.LANCZOS)
im = grade(ImageEnhance.Contrast(im).enhance(1.2), (1.0, 0.85, 0.85), 0.9)
d = ImageDraw.Draw(im, 'RGBA')
for i in range(170):
    d.line((0, 511 - i, 512, 511 - i), fill=(0, 0, 0, int(240 * (1 - i / 170))))
d.rectangle((0, 0, 512, 52), fill=(175, 8, 8, 240))
f = F(26); t = '⚠ EMERGENCY ALERT ⚠'
d.text(((512 - d.textlength(t, font=f)) / 2, 11), t, font=f, fill='white')
f = F(70); t = 'STAY INSIDE'
glowtext(im, ((512 - ImageDraw.Draw(im).textlength(t, font=f)) / 2, 420), t, f, (255, 180, 20), (255, 90, 0))
im.save(os.path.join(OUT, 'icon_512.png'))
print('ok')
