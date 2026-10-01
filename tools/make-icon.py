#!/usr/bin/env python3
"""Render assets/icon.png (256x256): the Yoo-Haul driving into a synthwave sun.

Dev tool, needs Pillow. Run after changing the truck in tools/sprites.py:
    python3 tools/make-icon.py
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import sprites  # noqa: E402  (draws everything on import)

S = 256
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle((8, 8, S - 8, S - 8), radius=48, fill=255)

art = Image.new("RGBA", (S, S))
d = ImageDraw.Draw(art)
top, mid, low = (30, 20, 66), (108, 42, 116), (242, 113, 141)
for y in range(S):
    t = y / 170
    a, b = (top, mid) if t < 0.55 else (mid, low)
    u = t / 0.55 if t < 0.55 else min(1, (t - 0.55) / 0.45)
    d.line([(0, y), (S, y)], fill=tuple(int(a[i] + (b[i] - a[i]) * u) for i in range(3)))

# striped sun
sun = Image.new("RGBA", (130, 130))
sd = ImageDraw.Draw(sun)
for y in range(130):
    u = y / 130
    sd.line([(0, y), (130, y)], fill=(255, int(242 - 140 * u), int(122 - 20 * u)))
m = Image.new("L", (130, 130), 0)
ImageDraw.Draw(m).ellipse((0, 0, 129, 129), fill=255)
md = ImageDraw.Draw(m)
for i, y in enumerate(range(65, 130, 13)):
    md.rectangle((0, y, 130, y + 2 + i * 2), fill=0)
art.paste(sun, (63, 50), m)

# mountains, ground, road
d.polygon([(0, 170), (40, 128), (80, 160), (130, 118), (180, 158), (220, 130), (256, 160), (256, 256), (0, 256)], fill=(86, 51, 121))
d.rectangle((0, 168, S, S), fill=(217, 164, 93))
d.rectangle((0, 196, S, 226), fill=(58, 52, 67))
for x in range(-10, S, 40):
    d.rectangle((x, 209, x + 20, 213), fill=(255, 216, 74))

# the truck
rows = sprites.SPRITES["truck"]
px = 3
ox, oy = 29, 226 - len(rows) * px
for y, row in enumerate(rows):
    for x, c in enumerate(row):
        col = sprites.PALETTE.get(c)
        if col:
            d.rectangle((ox + x * px, oy + y * px, ox + x * px + px - 1, oy + y * px + px - 1), fill=col)
for wx, wy in ((6, 19), (49, 19)):
    for y, row in enumerate(sprites.SPRITES["wheel0"]):
        for x, c in enumerate(row):
            col = sprites.PALETTE.get(c)
            if col:
                d.rectangle((ox + (wx + x) * px, oy + (wy + y) * px, ox + (wx + x) * px + px - 1, oy + (wy + y) * px + px - 1), fill=col)

img.paste(art, (0, 0), mask)
out = os.path.join(os.path.dirname(__file__), "..", "assets", "icon.png")
img.save(out)
print("wrote", os.path.normpath(out))
