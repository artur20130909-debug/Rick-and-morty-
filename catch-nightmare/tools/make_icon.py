# Иконка (512×512) и обложка (1920×1080) игры «Catch a Nightmare»: python3 tools/make_icon.py
# Рисует ночной лес, луну и монстров из игры (Луноголовый, Шкаф с Глазами, Пицца-Демон, сачок).
import os, random
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'branding')
os.makedirs(OUT, exist_ok=True)
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'

def font(size):
    try:
        return ImageFont.truetype(BOLD, size)
    except OSError:
        return ImageFont.load_default()

def gradient(w, h, top, bottom):
    img = Image.new('RGB', (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)))
    return img

def add(img, layer, k):
    # сложить свечение с картинкой (k — сила)
    return ImageChops.add(img, layer.point(lambda v: int(v * k)))

def trees(d, w, h, rnd, base_y, count, color, hmin, hmax):
    for _ in range(count):
        x = rnd.randrange(-40, w + 40)
        th = rnd.randrange(hmin, hmax)
        tw = th // 5
        d.polygon([(x, base_y - th), (x - tw, base_y), (x + tw, base_y)], fill=color)
        d.rectangle((x - tw // 6, base_y - 4, x + tw // 6, base_y + 20), fill=color)

def eye(d, cx, cy, r, color=(255, 225, 74)):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color)
    d.ellipse((cx - r * 0.35, cy - r * 0.6, cx + r * 0.35, cy + r * 0.6), fill=(30, 10, 0))

def moonhead(img, cx, cy, r):
    img = add(img, blob(img.size, (cx - r * 2, cy - r * 2, cx + r * 2, cy + r * 2), (120, 110, 60), r // 2), 1.0)
    d = ImageDraw.Draw(img)
    # тело и руки
    d.rectangle((cx - r * 0.25, cy + r * 0.9, cx + r * 0.25, cy + r * 2.6), fill=(28, 28, 48))
    d.line([(cx - r * 0.3, cy + r * 1.1), (cx - r * 0.9, cy + r * 2.4)], fill=(28, 28, 48), width=max(3, r // 7))
    d.line([(cx + r * 0.3, cy + r * 1.1), (cx + r * 0.9, cy + r * 2.4)], fill=(28, 28, 48), width=max(3, r // 7))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(245, 240, 205))
    for (dx, dy, cr) in [(0.35, -0.35, 0.18), (-0.45, 0.2, 0.13), (0.1, 0.45, 0.1)]:
        d.ellipse((cx + dx * r - cr * r, cy + dy * r - cr * r, cx + dx * r + cr * r, cy + dy * r + cr * r), fill=(216, 210, 168))
    d.ellipse((cx - r * 0.45, cy - r * 0.15, cx - r * 0.2, cy + r * 0.12), fill=(15, 15, 20))
    d.ellipse((cx + r * 0.2, cy - r * 0.15, cx + r * 0.45, cy + r * 0.12), fill=(15, 15, 20))
    # улыбка с зубами
    d.chord((cx - r * 0.5, cy + r * 0.05, cx + r * 0.5, cy + r * 0.65), 0, 180, fill=(20, 10, 10))
    for i in range(5):
        x0 = cx - r * 0.4 + i * r * 0.17
        d.polygon([(x0, cy + r * 0.35), (x0 + r * 0.14, cy + r * 0.35), (x0 + r * 0.07, cy + r * 0.5)], fill=(250, 250, 240))
    return img

def blob(size, box, color, blur):
    layer = Image.new('RGB', size, (0, 0, 0))
    ImageDraw.Draw(layer).ellipse(box, fill=color)
    return layer.filter(ImageFilter.GaussianBlur(blur))

def wardrobe(img, cx, by, s):
    img = add(img, blob(img.size, (cx - s * 1.6, by - s * 3.4, cx + s * 1.6, by + s * 0.2), (90, 70, 10), s // 2), 0.9)
    d = ImageDraw.Draw(img)
    w, h = s * 1.0, s * 3.0
    d.rectangle((cx - w, by - h, cx + w, by), fill=(107, 69, 40))
    d.rectangle((cx - w - s * 0.12, by - h - s * 0.15, cx + w + s * 0.12, by - h + s * 0.05), fill=(85, 54, 32))
    d.rectangle((cx - w * 0.85, by - h * 0.95, cx + w * 0.85, by - s * 0.1), fill=(8, 6, 6))
    # открытые двери
    d.polygon([(cx - w, by - h), (cx - w * 1.9, by - h * 0.92), (cx - w * 1.9, by - s * 0.15), (cx - w, by)], fill=(120, 78, 46))
    d.polygon([(cx + w, by - h), (cx + w * 1.9, by - h * 0.92), (cx + w * 1.9, by - s * 0.15), (cx + w, by)], fill=(120, 78, 46))
    rnd = random.Random(3)
    for _ in range(7):
        ex = cx + rnd.uniform(-w * 0.6, w * 0.6)
        ey = by - rnd.uniform(s * 0.4, h * 0.85)
        eye(d, ex, ey, s * rnd.uniform(0.1, 0.17))
    return img

def pizza(img, cx, by, s):
    img = add(img, blob(img.size, (cx - s * 1.3, by - s * 2.6, cx + s * 1.3, by + s * 0.2), (110, 40, 10), s // 2), 0.9)
    d = ImageDraw.Draw(img)
    d.polygon([(cx - s, by - s * 0.35), (cx + s, by - s * 0.35), (cx, by - s * 2.4)], fill=(255, 207, 64))
    d.rounded_rectangle((cx - s * 1.1, by - s * 0.5, cx + s * 1.1, by - s * 0.1), radius=int(s * 0.15), fill=(217, 160, 102))
    for (dx, dy, r) in [(-0.55, -0.6, 0.15), (0.55, -0.6, 0.13), (0, -1.75, 0.1)]:
        d.ellipse((cx + dx * s - r * s, by + dy * s - r * s, cx + dx * s + r * s, by + dy * s + r * s), fill=(179, 38, 30))
    d.ellipse((cx - s * 0.32, by - s * 1.3, cx - s * 0.12, by - s * 1.1), fill=(255, 40, 40))
    d.ellipse((cx + s * 0.12, by - s * 1.3, cx + s * 0.32, by - s * 1.1), fill=(255, 40, 40))
    d.chord((cx - s * 0.3, by - s * 1.05, cx + s * 0.3, by - s * 0.7), 0, 180, fill=(30, 10, 10))
    d.polygon([(cx - s * 0.3, by - s * 1.9), (cx - s * 0.6, by - s * 2.3), (cx - s * 0.2, by - s * 2.0)], fill=(139, 0, 0))
    d.polygon([(cx + s * 0.3, by - s * 1.9), (cx + s * 0.6, by - s * 2.3), (cx + s * 0.2, by - s * 2.0)], fill=(139, 0, 0))
    return img

def net(d, x0, y0, x1, y1, r):
    d.line([(x0, y0), (x1, y1)], fill=(150, 110, 60), width=max(4, r // 5))
    d.ellipse((x1 - r, y1 - r, x1 + r, y1 + r), outline=(230, 230, 240), width=max(3, r // 8))
    for i in range(-3, 4):
        d.line([(x1 + i * r / 4, y1 - r * 0.95), (x1 + i * r / 4, y1 + r * 0.95)], fill=(200, 200, 215), width=1)
        d.line([(x1 - r * 0.95, y1 + i * r / 4), (x1 + r * 0.95, y1 + i * r / 4)], fill=(200, 200, 215), width=1)

def text_outline(d, xy, text, f, fill, outline=(0, 0, 0), width=6, anchor='mm'):
    d.text(xy, text, font=f, fill=fill, anchor=anchor, stroke_width=width, stroke_fill=outline)

def make_icon():
    w = h = 512
    rnd = random.Random(11)
    img = gradient(w, h, (24, 10, 48), (60, 20, 70))
    d = ImageDraw.Draw(img)
    for _ in range(120):
        x, y = rnd.randrange(w), rnd.randrange(h // 2)
        c = rnd.randrange(130, 230)
        d.point((x, y), fill=(c, c, c))
    trees(d, w, h, rnd, int(h * 0.98), 14, (14, 8, 26), 220, 360)
    img = moonhead(img, 300, 200, 120)
    d = ImageDraw.Draw(img)
    trees(d, w, h, rnd, h + 10, 6, (6, 4, 12), 160, 260)
    net(d, 30, 500, 150, 360, 70)
    # плашка редкости
    d.rounded_rectangle((300, 420, 500, 490), radius=18, fill=(255, 60, 110), outline=(0, 0, 0), width=5)
    text_outline(d, (400, 455), 'MYTHIC', font(40), (255, 255, 255), width=4)
    img.save(os.path.join(OUT, 'icon_512.png'))

def make_thumb():
    w, h = 1920, 1080
    rnd = random.Random(5)
    img = gradient(w, h, (20, 10, 44), (70, 24, 80))
    d = ImageDraw.Draw(img)
    for _ in range(500):
        x, y = rnd.randrange(w), rnd.randrange(h // 2)
        c = rnd.randrange(120, 230)
        d.point((x, y), fill=(c, c, c))
    trees(d, w, h, rnd, int(h * 0.95), 30, (16, 9, 30), 380, 640)
    d.rectangle((0, int(h * 0.9), w, h), fill=(10, 6, 18))
    img = moonhead(img, 380, 470, 190)
    img = wardrobe(img, 980, 960, 150)
    img = pizza(img, 1560, 960, 190)
    d = ImageDraw.Draw(img)
    net(d, 1180, 1080, 1320, 760, 110)
    text_outline(d, (w // 2, 120), 'CATCH A NIGHTMARE', font(150), (255, 214, 74), width=12)
    text_outline(d, (w // 2, 250), 'ПОЙМАЙ • УКРАДИ • СОБЕРИ', font(70), (255, 255, 255), width=8)
    img.save(os.path.join(OUT, 'thumbnail_1920x1080.png'))

if __name__ == '__main__':
    make_icon()
    make_thumb()
    print('ok:', OUT)
