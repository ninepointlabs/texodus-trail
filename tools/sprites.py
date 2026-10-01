#!/usr/bin/env python3
"""Draw the game's pixel art and write app/Sprites.js.

Every sprite is built from a few drawing calls on a character grid, one
character per pixel, then exported as rows plus a palette that the QML
PixelArt item paints. `--preview out.png` also renders a contact sheet.

    python3 tools/sprites.py [--preview /path/sheet.png]
"""
import json
import os
import sys

PALETTE = {
    ".": None,
    "k": "#1b1424",  # outline
    "w": "#f6f1e7",  # white
    "W": "#cfc8bb",  # white shade
    "o": "#ff7a1a",  # yoo-haul orange
    "O": "#c24e0c",  # orange shade
    "g": "#8fdcff",  # glass
    "G": "#3d8fc4",  # glass shade
    "m": "#f9bfd0",  # mattress
    "M": "#e07b9b",  # mattress stripe
    "r": "#c7a066",  # rope / wood
    "R": "#ff3b3b",  # red
    "y": "#ffe36e",  # yellow
    "Y": "#e0a92c",  # gold
    "d": "#363443",  # dark gray
    "D": "#22202c",  # darker
    "l": "#8d93a3",  # light gray
    "L": "#c3c8d4",  # lighter gray
    "n": "#4f9b3a",  # green
    "N": "#2f6b25",  # dark green
    "v": "#8fcf5a",  # light green
    "b": "#8a5a32",  # brown
    "B": "#5a3a20",  # dark brown
    "t": "#e8c78f",  # tan / tortilla
    "T": "#c79a55",  # tan shade
    "s": "#b7b0a4",  # stone
    "S": "#7d776d",  # stone shade
    "p": "#ff9ec8",  # pink
    "c": "#5fd0d0",  # cyan
    "u": "#4a7bd6",  # blue
    "U": "#2b4f9a",  # dark blue
    "x": "#6b3b1c",  # brisket bark
    "X": "#a8452c",  # brisket smoke ring
    "f": "#f2a541",  # fries / cheese
    "e": "#3a2b1e",  # espresso
}


class Grid:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.rows = [["."] * w for _ in range(h)]

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.rows[y][x] = c

    def rect(self, x, y, w, h, c):
        for j in range(y, y + h):
            for i in range(x, x + w):
                self.px(i, j, c)

    def box(self, x, y, w, h, fill, line="k"):
        self.rect(x, y, w, h, line)
        self.rect(x + 1, y + 1, w - 2, h - 2, fill)

    def hline(self, x, y, w, c):
        self.rect(x, y, w, 1, c)

    def vline(self, x, y, h, c):
        self.rect(x, y, 1, h, c)

    def circle(self, cx, cy, r, c, line=None):
        for j in range(-r, r + 1):
            for i in range(-r, r + 1):
                d = i * i + j * j
                if d <= r * r + r * 0.6:
                    self.px(cx + i, cy + j, c)
        if line:
            for j in range(-r - 1, r + 2):
                for i in range(-r - 1, r + 2):
                    d = i * i + j * j
                    inside = d <= r * r + r * 0.6
                    if not inside and d <= (r + 1) * (r + 1) + (r + 1) * 0.6:
                        self.px(cx + i, cy + j, line)

    def outline(self, line="k"):
        """Add a 1px outline around every opaque pixel (grows into transparent)."""
        src = [row[:] for row in self.rows]
        for y in range(self.h):
            for x in range(self.w):
                if src[y][x] != ".":
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < self.w and 0 <= yy < self.h and src[yy][xx] not in (".", line):
                        self.rows[y][x] = line
                        break

    def draw(self, x, y, art):
        for j, row in enumerate(art):
            for i, c in enumerate(row):
                if c != " " and c != ".":
                    self.px(x + i, y + j, c)

    def export(self):
        return ["".join(r) for r in self.rows]


SPRITES = {}


def sprite(name):
    def deco(fn):
        SPRITES[name] = fn().export()
        return fn
    return deco


# ------------------------------------------------------------------ truck --

@sprite("truck")
def truck():
    """26-foot box truck facing right. Wheels are separate sprites so they
    can spin; they sit at (6, 19) and (49, 19), half inside the wheel wells."""
    g = Grid(66, 31)
    # mattress strapped to the roof, a little askew, because of course it is
    g.rect(5, 0, 33, 3, "m")
    g.hline(5, 0, 33, "w")
    for x in range(8, 38, 5):
        g.vline(x, 1, 2, "M")
    g.rect(3, 1, 2, 2, "m")
    # the box
    g.box(0, 3, 46, 23, "w")
    g.rect(1, 16, 44, 5, "o")
    g.hline(1, 21, 44, "O")
    g.rect(1, 22, 44, 3, "W")
    g.vline(1, 4, 21, "W")        # back door seam
    g.vline(3, 4, 21, "W")
    g.rect(1, 17, 1, 3, "R")       # tail light
    g.draw(39, 17, ["yy.", "yyy", "yy."])  # the little arrow logo
    # rope over the mattress and down the box
    g.vline(12, 0, 4, "r")
    g.vline(31, 0, 4, "r")
    # cab: back wall, roof, slanted windshield, hood
    g.rect(46, 9, 12, 17, "k")
    g.rect(47, 10, 11, 15, "w")
    for i in range(7):                       # windshield slope: one step per row
        g.rect(58, 9 + i, 1 + i, 1, "k")
        g.rect(58, 10 + i, max(0, i), 1, "w")
    g.rect(57, 16, 8, 9, "k")
    g.rect(58, 16, 6, 8, "w")
    # side window and windshield glass
    g.rect(48, 11, 6, 5, "g")
    g.hline(48, 15, 6, "G")
    g.px(49, 12, "w")
    g.px(50, 12, "w")
    for i in range(5):
        g.rect(58, 11 + i, i + 1, 1, "g")
    g.hline(58, 15, 5, "G")
    # door seam and handle
    g.vline(55, 10, 14, "W")
    g.hline(52, 18, 2, "d")
    # orange stripe down the cab
    g.rect(47, 19, 17, 2, "o")
    # headlight, grille, bumper
    g.rect(63, 17, 1, 2, "y")
    g.rect(64, 17, 1, 2, "y")
    g.rect(63, 21, 2, 3, "l")
    g.rect(58, 24, 8, 2, "L")
    # chassis, fuel tank, wheel wells
    g.rect(1, 26, 60, 2, "d")
    g.rect(28, 24, 10, 3, "l")
    # rounded wheel wells, open at the bottom
    for cx in (12, 55):
        g.circle(cx, 25, 7, "D")
    g.rect(0, 28, 66, 3, ".")
    return g


def wheel(frame):
    g = Grid(12, 12)
    g.circle(5, 5, 5, "d", "k")
    g.circle(5, 5, 2, "L")
    g.px(5, 5, "l")
    spokes = [(5, 1), (5, 9), (1, 5), (9, 5)] if frame == 0 else [(2, 2), (8, 8), (2, 8), (8, 2)]
    for x, y in spokes:
        g.px(x, y, "l")
    return g


SPRITES["wheel0"] = wheel(0).export()
SPRITES["wheel1"] = wheel(1).export()


# ------------------------------------------------------------------ flora --

@sprite("palm")
def palm():
    g = Grid(30, 56)
    # trunk, slight lean
    for y in range(14, 56):
        x = 14 + (y - 14) // 14
        g.rect(x, y, 3, 1, "b" if (y // 3) % 2 else "B")
    # fronds
    fronds = [
        [(15, 12), (12, 11), (9, 11), (6, 12), (3, 14), (1, 17)],
        [(15, 12), (18, 11), (21, 11), (24, 12), (27, 14), (28, 17)],
        [(15, 12), (13, 9), (11, 6), (8, 4), (5, 4)],
        [(15, 12), (17, 9), (19, 6), (22, 4), (25, 4)],
        [(15, 12), (15, 8), (15, 4), (14, 1)],
        [(15, 12), (11, 13), (8, 15), (6, 19)],
        [(15, 12), (19, 13), (22, 15), (24, 19)],
    ]
    for f in fronds:
        for i in range(len(f) - 1):
            (x0, y0), (x1, y1) = f[i], f[i + 1]
            steps = max(abs(x1 - x0), abs(y1 - y0))
            for s in range(steps + 1):
                x = round(x0 + (x1 - x0) * s / steps)
                y = round(y0 + (y1 - y0) * s / steps)
                g.px(x, y, "n")
                g.px(x, y + 1, "N")
    g.rect(14, 11, 3, 3, "B")
    g.outline()
    return g


@sprite("joshua")
def joshua():
    g = Grid(34, 44)
    g.rect(15, 18, 4, 26, "b")
    g.vline(15, 18, 26, "B")
    # arms
    for (x0, y0, x1, y1) in [(16, 26, 6, 14), (17, 22, 28, 10), (16, 30, 26, 20), (17, 20, 13, 6)]:
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for s in range(steps + 1):
            x = round(x0 + (x1 - x0) * s / steps)
            y = round(y0 + (y1 - y0) * s / steps)
            g.rect(x, y, 2, 2, "b")
    # spiky tufts
    for (cx, cy) in [(6, 12), (28, 8), (26, 18), (13, 4)]:
        for dx in range(-3, 4):
            for dy in range(-3, 3):
                if abs(dx) + abs(dy) <= 3:
                    g.px(cx + dx, cy + dy, "n" if (dx + dy) % 2 else "N")
        g.px(cx, cy - 4, "v")
        g.px(cx - 4, cy - 1, "v")
        g.px(cx + 4, cy - 1, "v")
    g.outline()
    return g


@sprite("saguaro")
def saguaro():
    g = Grid(26, 50)
    g.rect(10, 4, 6, 46, "n")
    g.rect(11, 2, 4, 2, "n")
    g.vline(12, 4, 46, "v")
    g.vline(15, 4, 46, "N")
    # left arm
    g.rect(4, 22, 6, 4, "n")
    g.rect(4, 10, 4, 14, "n")
    g.rect(5, 8, 2, 2, "n")
    g.vline(5, 10, 14, "v")
    # right arm
    g.rect(16, 28, 5, 4, "n")
    g.rect(18, 16, 4, 14, "n")
    g.rect(19, 14, 2, 2, "n")
    g.vline(21, 16, 14, "N")
    # flower
    g.px(12, 1, "p")
    g.px(13, 1, "y")
    g.outline()
    return g


@sprite("cactus")
def cactus():
    g = Grid(14, 16)
    g.rect(5, 2, 4, 14, "n")
    g.rect(1, 6, 3, 5, "n")
    g.rect(2, 10, 3, 2, "n")
    g.rect(10, 4, 3, 6, "n")
    g.rect(9, 8, 2, 2, "n")
    g.vline(6, 2, 14, "v")
    g.outline()
    return g


@sprite("tumbleweed")
def tumbleweed():
    import math
    g = Grid(18, 18)
    # a tangle: overlapping loops of twig around a hollow-ish core
    for k in range(7):
        cx = 9 + 3 * math.cos(k * 0.9)
        cy = 9 + 3 * math.sin(k * 1.3)
        r = 4.5 + (k % 3)
        for a in range(0, 360, 6):
            x = round(cx + r * math.cos(math.radians(a)))
            y = round(cy + r * 0.9 * math.sin(math.radians(a)))
            if 0 <= x < 18 and 0 <= y < 18 and (x - 9) ** 2 + (y - 9) ** 2 <= 64:
                g.px(x, y, "b" if (a // 30 + k) % 3 else "T")
    return g


@sprite("rock")
def rock():
    g = Grid(16, 9)
    g.rect(2, 3, 12, 6, "s")
    g.rect(4, 1, 7, 3, "s")
    g.rect(2, 7, 12, 2, "S")
    g.rect(9, 2, 3, 6, "S")
    g.outline()
    return g


# ------------------------------------------------------------------ texas --

@sprite("pumpjack")
def pumpjack():
    g = Grid(44, 34)
    # base
    g.rect(2, 30, 40, 4, "d")
    # A-frame
    for y in range(10, 30):
        g.px(20 - (y - 10) // 3, y, "D")
        g.px(21 + (y - 10) // 3, y, "D")
    g.rect(19, 9, 4, 3, "d")
    # walking beam
    g.rect(4, 8, 36, 3, "Y")
    g.hline(4, 10, 36, "B")
    # horse head
    g.rect(1, 6, 5, 9, "Y")
    g.rect(1, 6, 2, 9, "B")
    # rod
    g.vline(2, 15, 15, "l")
    # counterweight + crank
    g.rect(34, 12, 8, 8, "R")
    g.circle(36, 22, 3, "d")
    g.vline(38, 11, 8, "D")
    g.outline()
    return g


@sprite("windmill")
def windmill():
    g = Grid(28, 60)
    for y in range(16, 60):
        spread = (y - 16) // 6
        g.px(13 - spread, y, "l")
        g.px(14 + spread, y, "l")
        if y % 8 == 0:
            g.hline(13 - spread, y, 2 + spread * 2, "l")
    import math
    for a in range(0, 360, 20):
        for s in range(3, 12):
            x = round(13.5 + math.cos(math.radians(a)) * s)
            y = round(12 + math.sin(math.radians(a)) * s)
            g.px(x, y, "L" if a % 40 else "l")
    g.circle(13, 12, 2, "d")
    # tail vane
    g.rect(16, 10, 9, 2, "d")
    g.rect(23, 7, 4, 8, "R")
    return g


@sprite("longhorn")
def longhorn():
    g = Grid(40, 22)
    # body
    g.rect(10, 7, 22, 10, "b")
    g.rect(14, 7, 6, 5, "w")
    g.rect(24, 11, 5, 4, "w")
    g.rect(10, 15, 22, 2, "B")
    # legs
    for x in (11, 15, 26, 30):
        g.rect(x, 17, 2, 5, "B")
    # tail
    g.vline(32, 8, 7, "B")
    g.px(33, 15, "k")
    # head (facing left)
    g.rect(4, 6, 7, 6, "b")
    g.rect(4, 10, 3, 2, "p")
    g.px(6, 8, "k")
    # the famous horns
    g.hline(0, 4, 15, "w")
    g.px(0, 3, "w")
    g.px(14, 3, "w")
    g.hline(5, 5, 5, "W")
    g.outline()
    return g


@sprite("star")
def star():
    g = Grid(21, 20)
    import math
    pts = []
    for i in range(10):
        r = 10 if i % 2 == 0 else 4
        a = math.radians(-90 + i * 36)
        pts.append((10 + r * math.cos(a), 10.5 + r * math.sin(a)))
    for y in range(20):
        for x in range(21):
            # point in polygon
            inside = False
            j = len(pts) - 1
            for i in range(len(pts)):
                xi, yi = pts[i]
                xj, yj = pts[j]
                if ((yi > y + 0.5) != (yj > y + 0.5)) and (x + 0.5 < (xj - xi) * (y + 0.5 - yi) / (yj - yi) + xi):
                    inside = not inside
                j = i
            if inside:
                g.px(x, y, "w")
    return g


# ---------------------------------------------------------------- objects --

@sprite("tombstone")
def tombstone():
    g = Grid(18, 20)
    g.rect(2, 5, 14, 14, "s")
    g.rect(4, 3, 10, 2, "s")
    g.rect(6, 2, 6, 1, "s")
    g.rect(13, 5, 3, 14, "S")
    g.rect(6, 7, 6, 1, "S")
    g.rect(8, 5, 2, 6, "S")
    g.rect(5, 13, 8, 1, "S")
    g.rect(5, 15, 6, 1, "S")
    g.rect(0, 19, 18, 1, "N")
    g.outline()
    return g


@sprite("hat")
def hat():
    g = Grid(28, 14)
    g.rect(8, 2, 12, 8, "b")
    g.rect(12, 1, 4, 2, "b")
    g.rect(13, 3, 2, 3, "B")
    g.rect(8, 8, 12, 2, "x")
    g.rect(1, 10, 26, 2, "b")
    g.rect(0, 9, 3, 2, "b")
    g.rect(25, 9, 3, 2, "b")
    g.hline(3, 12, 22, "B")
    g.outline()
    return g


@sprite("taco")
def taco():
    g = Grid(20, 13)
    g.circle(10, 10, 9, "t")
    g.rect(0, 10, 20, 3, ".")
    g.rect(3, 4, 14, 3, "n")
    g.px(5, 3, "v"); g.px(9, 3, "R"); g.px(13, 3, "v"); g.px(7, 4, "R"); g.px(11, 4, "y"); g.px(15, 4, "R")
    g.rect(2, 6, 16, 2, "x")
    g.circle(10, 10, 6, "T")
    g.rect(0, 10, 20, 3, ".")
    g.outline()
    return g


@sprite("brisket")
def brisket():
    g = Grid(24, 14)
    g.rect(1, 3, 22, 9, "x")
    g.rect(2, 4, 20, 7, "X")
    g.rect(3, 5, 18, 5, "T")
    for x in range(5, 21, 4):
        g.vline(x, 4, 7, "x")
    g.rect(1, 2, 22, 1, "e")
    g.rect(0, 12, 24, 2, "w")
    g.outline()
    return g


@sprite("kolache")
def kolache():
    g = Grid(16, 14)
    g.circle(8, 7, 6, "t")
    g.circle(8, 6, 3, "R")
    g.px(7, 5, "p")
    g.rect(2, 11, 12, 1, "T")
    g.outline()
    return g


@sprite("salad")
def salad():
    g = Grid(20, 14)
    g.circle(10, 4, 6, "n")
    g.px(6, 2, "v"); g.px(12, 1, "v"); g.px(9, 3, "R"); g.px(14, 4, "v")
    g.rect(1, 6, 18, 2, "w")
    g.rect(3, 8, 14, 3, "w")
    g.rect(5, 11, 10, 2, "W")
    g.outline()
    return g


@sprite("burger")
def burger():
    g = Grid(20, 16)
    g.rect(3, 1, 14, 5, "T")
    g.rect(2, 3, 16, 3, "T")
    g.px(6, 2, "w"); g.px(10, 2, "w"); g.px(14, 3, "w")
    g.rect(1, 6, 18, 2, "n")
    g.rect(1, 8, 18, 2, "f")
    g.rect(2, 9, 2, 2, "f")
    g.rect(2, 10, 16, 2, "x")
    g.rect(2, 12, 16, 3, "T")
    g.outline()
    return g


@sprite("steak")
def steak():
    g = Grid(22, 16)
    g.circle(10, 8, 6, "X")
    g.rect(14, 4, 6, 8, "X")
    g.circle(10, 8, 4, "x")
    g.vline(8, 4, 8, "e"); g.vline(12, 4, 8, "e")
    g.rect(16, 6, 3, 2, "w")
    g.outline()
    return g


@sprite("ufo")
def ufo():
    g = Grid(26, 16)
    g.circle(13, 5, 4, "g")
    g.px(12, 3, "w")
    g.rect(2, 7, 22, 3, "L")
    g.rect(5, 6, 16, 1, "L")
    g.rect(4, 10, 18, 1, "l")
    for x in (5, 10, 15, 20):
        g.px(x, 8, "y")
    g.rect(9, 11, 8, 1, "c")
    g.rect(7, 13, 12, 1, "c")
    g.outline()
    return g


@sprite("phone")
def phone():
    g = Grid(12, 20)
    g.box(0, 0, 12, 20, "D")
    g.rect(1, 2, 10, 15, "u")
    g.rect(2, 3, 8, 6, "c")
    g.rect(3, 10, 6, 1, "w")
    g.rect(3, 12, 4, 1, "w")
    g.rect(4, 18, 4, 1, "l")
    g.px(5, 5, "y")
    return g


@sprite("sign")
def sign():
    g = Grid(24, 24)
    g.box(0, 0, 24, 14, "n")
    g.rect(2, 2, 20, 10, "n")
    g.rect(3, 4, 12, 1, "w")
    g.rect(3, 7, 16, 1, "w")
    g.rect(3, 10, 8, 1, "w")
    g.rect(6, 14, 2, 10, "l")
    g.rect(16, 14, 2, 10, "l")
    return g


@sprite("wave")
def wave_():
    g = Grid(24, 14)
    for y in range(4, 14):
        for x in range(24):
            if (x + y * 2) % 8 < 2 and y < 8:
                g.px(x, y, "w")
            elif y >= 6:
                g.px(x, y, "u" if (x // 3 + y) % 2 else "c")
    g.rect(0, 4, 24, 2, "c")
    g.px(3, 2, "w"); g.px(4, 3, "w"); g.px(14, 2, "w"); g.px(15, 3, "w")
    return g


@sprite("money")
def money():
    g = Grid(18, 20)
    g.circle(9, 12, 7, "n")
    g.rect(6, 2, 6, 4, "n")
    g.rect(5, 5, 8, 1, "r")
    g.vline(9, 7, 11, "v")
    g.rect(7, 8, 5, 1, "v"); g.rect(7, 12, 5, 1, "v"); g.rect(7, 16, 5, 1, "v")
    g.px(7, 9, "v"); g.px(7, 10, "v"); g.px(11, 13, "v"); g.px(11, 14, "v"); g.px(11, 15, "v")
    g.outline()
    return g


@sprite("wrench")
def wrench():
    g = Grid(18, 18)
    for i in range(12):
        g.rect(3 + i, 13 - i, 2, 2, "L")
    g.circle(14, 3, 3, "L")
    g.rect(14, 0, 2, 3, ".")
    g.rect(15, 2, 2, 2, ".")
    g.circle(3, 14, 2, "L")
    g.outline()
    return g


@sprite("thermo")
def thermo():
    g = Grid(10, 22)
    g.rect(3, 0, 4, 16, "w")
    g.rect(4, 6, 2, 12, "R")
    g.circle(5, 17, 3, "R")
    for y in (3, 6, 9, 12):
        g.px(7, y, "k")
    g.outline()
    return g


@sprite("snake")
def snake():
    g = Grid(26, 12)
    import math
    for x in range(2, 22):
        y = round(6 + 3 * math.sin(x / 2.5))
        g.rect(x, y, 2, 2, "Y" if (x // 2) % 2 else "b")
    g.rect(21, 3, 4, 3, "Y")
    g.px(23, 3, "k")
    g.px(25, 5, "R")
    g.rect(0, 7, 2, 1, "w")
    g.outline()
    return g


@sprite("cone")
def cone():
    g = Grid(12, 14)
    for y in range(12):
        w = 2 + y // 2
        g.rect(6 - w // 2, y, w, 1, "o" if (y // 3) % 2 == 0 else "w")
    g.rect(0, 12, 12, 2, "o")
    g.outline()
    return g


@sprite("bird")
def bird():
    g = Grid(9, 4)
    g.draw(0, 0, ["k.......k", ".k.....k.", "..k.k.k..", "...k.k..."])
    return g


# --------------------------------------------------------------- the font --

# 5x7 bitmap font for the big pixel headings
FONT = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    " ": ["00000"] * 7,
    "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    ".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
    ",": ["00000", "00000", "00000", "00000", "01100", "00100", "01000"],
    "!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
    "?": ["01110", "10001", "00001", "00010", "00100", "00000", "00100"],
    "'": ["00100", "00100", "01000", "00000", "00000", "00000", "00000"],
    "$": ["00100", "01111", "10100", "01110", "00101", "11110", "00100"],
    ":": ["00000", "01100", "01100", "00000", "01100", "01100", "00000"],
    "(": ["00010", "00100", "01000", "01000", "01000", "00100", "00010"],
    ")": ["01000", "00100", "00010", "00010", "00010", "00100", "01000"],
    "&": ["01100", "10010", "10100", "01000", "10101", "10010", "01101"],
    "/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
    "%": ["11001", "11010", "00010", "00100", "01000", "01011", "10011"],
    "#": ["01010", "01010", "11111", "01010", "11111", "01010", "01010"],
    "*": ["00000", "10101", "01110", "11111", "01110", "10101", "00000"],
    "+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
    "°": ["01100", "10010", "10010", "01100", "00000", "00000", "00000"],
    "·": ["00000", "00000", "00000", "01100", "01100", "00000", "00000"],
}


def write_js(path):
    pal = {k: v for k, v in PALETTE.items() if v}
    for name, rows in SPRITES.items():
        w = len(rows[0])
        assert all(len(r) == w for r in rows), name
        for r in rows:
            for c in r:
                assert c in PALETTE, (name, c)
    with open(path, "w") as f:
        f.write(".pragma library\n\n")
        f.write("// Generated by tools/sprites.py. Edit the drawing code there, not this file.\n\n")
        f.write("var PALETTE = " + json.dumps(pal) + "\n\n")
        f.write("var SPRITES = {\n")
        items = list(SPRITES.items())
        for i, (name, rows) in enumerate(items):
            f.write("  " + json.dumps(name) + ": " + json.dumps(rows) + ("," if i < len(items) - 1 else "") + "\n")
        f.write("}\n\n")
        f.write("var FONT = " + json.dumps(FONT, ensure_ascii=False) + "\n")


def preview(path):
    from PIL import Image
    scale = 4
    pad = 4
    names = list(SPRITES)
    cols = 6
    cw = max(len(SPRITES[n][0]) for n in names) * scale + pad * 2
    ch = max(len(SPRITES[n]) for n in names) * scale + pad * 2
    rows = (len(names) + cols - 1) // cols
    img = Image.new("RGB", (cols * cw, rows * ch), (90, 60, 110))
    for idx, n in enumerate(names):
        ox = (idx % cols) * cw + pad
        oy = (idx // cols) * ch + pad
        for y, row in enumerate(SPRITES[n]):
            for x, c in enumerate(row):
                col = PALETTE.get(c)
                if col:
                    rgb = tuple(int(col[i:i + 2], 16) for i in (1, 3, 5))
                    for dy in range(scale):
                        for dx in range(scale):
                            img.putpixel((ox + x * scale + dx, oy + y * scale + dy), rgb)
    img.save(path)


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(__file__), "..", "app", "Sprites.js")
    write_js(out)
    print("wrote", os.path.normpath(out), len(SPRITES), "sprites")
    if "--preview" in sys.argv:
        p = sys.argv[sys.argv.index("--preview") + 1]
        preview(p)
        print("preview", p)
