"""Lays the rendered emblem (blender/make_icon.py) on a glowing background with bloom, and writes the
game's icons: game/icon.png (512 for the PWA), icon_180.png (iPhone home screen), icon_144.png.
Run: python tools-src/make_icon_art.py <emblem.png>"""
import math
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

W = 1024
emblem = Image.open(sys.argv[1]).convert("RGBA")
box = emblem.getbbox()
emblem = emblem.crop(box)
scale = (W * 0.78) / max(emblem.size)
emblem = emblem.resize((int(emblem.width * scale), int(emblem.height * scale)), Image.LANCZOS)

# Background: deep night purple, a warm burst of light behind the break, faint rays.
bg = Image.new("RGB", (W, W))
px = bg.load()
cx, cy = W * 0.54, W * 0.44
for y in range(W):
    for x in range(W):
        d = math.hypot(x - cx, y - cy) / W
        t = max(0.0, 1.0 - d * 1.55)
        a = math.atan2(y - cy, x - cx)
        ray = 0.5 + 0.5 * math.cos(a * 12)
        glow = t ** 2.2 + 0.1 * ray * t
        px[x, y] = (int(22 + 220 * glow), int(16 + 120 * glow ** 1.3), int(48 + 60 * glow ** 1.6 + 30 * (1 - t)))
img = bg.convert("RGBA")
ex, ey = (W - emblem.width) // 2, (W - emblem.height) // 2
shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
shadow.paste((0, 0, 0, 170), (ex + 10, ey + 18), emblem.split()[3])
img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)))
img.alpha_composite(emblem, (ex, ey))
# Bloom: the brightest parts glow.
bright = img.convert("RGB").point(lambda v: max(0, v - 195) * 3)
img = ImageChops.add(img.convert("RGB"), bright.filter(ImageFilter.GaussianBlur(22)))
img = ImageChops.add(img, bright.filter(ImageFilter.GaussianBlur(6)).point(lambda v: v // 2))
# Vignette.
vig = Image.new("L", (W, W), 0)
ImageDraw.Draw(vig).ellipse((-W * 0.25, -W * 0.25, W * 1.25, W * 1.25), fill=255)
img = Image.composite(img, Image.new("RGB", (W, W), (10, 6, 22)), vig.filter(ImageFilter.GaussianBlur(120)))
img.resize((512, 512), Image.LANCZOS).save("game/icon.png")
img.resize((180, 180), Image.LANCZOS).save("game/icon_180.png")
img.resize((144, 144), Image.LANCZOS).save("game/icon_144.png")
img.resize((400, 400), Image.LANCZOS).save(sys.argv[1].replace(".png", "_final.png"))
