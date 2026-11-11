#!/usr/bin/env python3
"""The little pictures on the HUD's pills beside the coin (`GoldPill`'s coin, tools/coin_art.py): the
world map's time of day and where you are (the user, 2026-11-11: "The top left pills should become the
same as the coin pill. For the day/night, show a sun or moon icon (create the pixel art for it, similar
to the coin). The coordinates should have a location pin icon (also pixel art)"). Drawn with
tools/pixel_kit.py in the item icons' clean look (64 x 64, lit from the top left, docs/pixel-style.md):

    pill_sun    a gold sun, its rays round it        (day)
    pill_moon   a pale crescent moon, two craters     (night)
    pill_pin    a red map pin, a pale hole in its head (your coordinates)

    python3 tools/hud_icon_art.py                 # all three -> art/sprites/pill_<name>.png
    python3 tools/hud_icon_art.py --sheet out.png # a contact sheet at 4x
"""

import math
import pathlib
import sys

from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from pixel_kit import Material, Sprite  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPRITES = ROOT / "art" / "sprites"


def smooth(base, shades=7, relief=1.0):
    return Material(base, shades=shades, texture=0, variety=0, gloss=0.0, relief=relief, wide=True)


SUN = smooth("#ffcf3a")
RAY = smooth("#f5a524", shades=6)
SHINE = smooth("#fff6c8", shades=3, relief=0.0)
MOON = smooth("#f1e2a6")
CRATER = smooth("#d6c27e", shades=4, relief=0.0)
PIN = smooth("#e2453c")
HOLE = smooth("#fff1dc", shades=4)


def arc(cx, cy, r, a0, a1, steps):
    """Points round a circle from angle `a0` to `a1` (degrees, clockwise on screen from the right)."""
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * t / steps)),
             cy + r * math.sin(math.radians(a0 + (a1 - a0) * t / steps))) for t in range(steps + 1)]


def sun():
    s = Sprite.clean(64)
    cx, cy = 32, 32
    # Eight rays, each a thin triangle pointing out, behind the disc.
    for k in range(8):
        a = math.radians(k * 45 - 90)
        side = math.radians(15)
        s.part()
        s.poly([(cx + 17 * math.cos(a - side), cy + 17 * math.sin(a - side)),
                (cx + 29 * math.cos(a), cy + 29 * math.sin(a)),
                (cx + 17 * math.cos(a + side), cy + 17 * math.sin(a + side))], RAY, bulge=0.6)
    s.part()
    s.ellipse(cx, cy, 17, 17, SUN, bulge=1.2)
    # A streak of shine on its upper left, where the light falls.
    s.stroke(arc(cx, cy, 12, 200, 250, 8), 2.4, SHINE, profile="flat")
    return s


def crescent(c1, r1, c2, r2, steps=32):
    """The part of circle (c1, r1) outside circle (c2, r2), as a polygon: the outer circle's arc
    between the points where the two cross, the long way round, then the inner circle's arc back."""
    (x1, y1), (x2, y2) = c1, c2
    d = math.hypot(x2 - x1, y2 - y1)
    along = (d * d + r1 * r1 - r2 * r2) / (2 * d)
    half = math.sqrt(max(0.0, r1 * r1 - along * along))
    ux, uy = (x2 - x1) / d, (y2 - y1) / d
    mx, my = x1 + ux * along, y1 + uy * along
    p, q = (mx - uy * half, my + ux * half), (mx + uy * half, my - ux * half)

    def angle(c, pt):
        return math.degrees(math.atan2(pt[1] - c[1], pt[0] - c[0]))

    toward = math.degrees(math.atan2(uy, ux))
    # The outer arc from p round the far side (away from the inner circle) to q.
    a0, a1 = angle(c1, p), angle(c1, q)
    while a1 <= a0:
        a1 += 360
    if not (a0 < toward + 180 < a1 or a0 < toward + 540 < a1):
        a1 -= 360
    outer = arc(x1, y1, r1, a0, a1, steps)
    # The inner arc back from q to p, round its side facing the outer circle's middle.
    b0, b1 = angle(c2, q), angle(c2, p)
    while b1 <= b0:
        b1 += 360
    if not (b0 < toward + 180 < b1 or b0 < toward + 540 < b1):
        b1 -= 360
    inner = arc(x2, y2, r2, b0, b1, steps)
    return outer + inner


def moon():
    s = Sprite.clean(64)
    # A crescent, its horns to the upper right: the moon's disc less one set up and to the right of it.
    s.poly(crescent((30, 33), 25, (43, 24), 21), MOON, bulge=1.1)
    s.part()
    s.ellipse(15, 34, 3.4, 3.0, CRATER, profile="flat")
    s.ellipse(22, 48, 2.8, 2.4, CRATER, profile="flat")
    return s


def pin():
    s = Sprite.clean(64)
    cx, cy, r = 32, 24, 17
    # The head's round top and the point under it, as one shape: the circle's arc over the top, then two
    # lines meeting at the point.
    head = arc(cx, cy, r, 145, 395, 32)
    s.poly(head + [(cx, 60)], PIN, bulge=1.2)
    s.part()
    s.ellipse(cx, cy, 6.5, 6.5, HOLE, profile="flat")
    return s


DRAWINGS = {"pill_sun": sun, "pill_moon": moon, "pill_pin": pin}


def main(argv):
    out = {}
    for name, draw in DRAWINGS.items():
        img = draw().render(outline="deep")
        img.save(SPRITES / f"{name}.png")
        out[name] = img
    print(f"wrote {len(out)} pill icons to art/sprites/")
    if "--sheet" in argv:
        path = argv[argv.index("--sheet") + 1]
        k = 4
        board = Image.new("RGBA", (len(out) * 66 * k, 66 * k), (20, 30, 60, 255))
        for n, img in enumerate(out.values()):
            board.alpha_composite(img.resize((64 * k, 64 * k), Image.NEAREST), (n * 66 * k + k, k))
        board.save(path)
        print(f"sheet in {path}")


if __name__ == "__main__":
    main(sys.argv[1:])
