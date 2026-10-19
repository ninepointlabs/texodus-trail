#!/usr/bin/env python3
"""Render assets/icon.png (256x256): the Yoo-Haul driving into a synthwave sun.

Dev tool, needs Pillow. Run after changing the truck in tools/sprites.py:
    python3 tools/make-icon.py

Also writes the desktop icon set under assets/icons/hicolor: the same pixels
as an SVG (one rect per run of a colour, so it stays crisp at any size) and
PNGs from 16 to 512 px scaled from icon.png with nearest-neighbour, so the
pixel art never blurs.
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

# The scalable icon: runs of one colour along each row, merged with the same
# run in the rows below it.
px = img.load()
runs = {}
for y in range(S):
    x = 0
    while x < S:
        end = x
        while end + 1 < S and px[end + 1, y] == px[x, y]:
            end += 1
        if px[x, y][3]:
            key = (x, end, px[x, y])
            if (key, y - 1) in runs:
                runs[(key, y)] = runs.pop((key, y - 1))
            else:
                runs[(key, y)] = y
        x = end + 1
rects = []
for ((x, end, col), last), first in sorted(runs.items(), key=lambda r: (r[1], r[0][0][0])):
    rects.append('<rect x="%d" y="%d" width="%d" height="%d" fill="#%02x%02x%02x"/>'
                 % (x, first, end - x + 1, last - first + 1, col[0], col[1], col[2]))
icons = os.path.join(os.path.dirname(__file__), "..", "assets", "icons", "hicolor")
svg = os.path.join(icons, "scalable", "apps", "texodus-trail.svg")
os.makedirs(os.path.dirname(svg), exist_ok=True)
with open(svg, "w") as f:
    f.write('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256" shape-rendering="crispEdges">\n'
            + "\n".join(rects) + "\n</svg>\n")
print("wrote", os.path.normpath(svg))

for size in (16, 24, 32, 48, 64, 128, 256, 512):
    png = os.path.join(icons, "%dx%d" % (size, size), "apps", "texodus-trail.png")
    os.makedirs(os.path.dirname(png), exist_ok=True)
    img.resize((size, size), Image.NEAREST).save(png)
    print("wrote", os.path.normpath(png))
