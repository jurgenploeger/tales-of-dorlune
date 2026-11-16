#!/usr/bin/env python3
"""Waterfalls where the rivers spring (the user, 2026-11-16: "We should also have some waterfalls in the
map"): a rocky ledge the river pours off into a foaming pool at its head, in four frames the game plays
in turn (`LandStage.placeWaterfalls`), the water's streaks running down a whole pixel at a time.

The rock is drawn with tools/pixel_kit.py as the lairs' pieces are (lair_art.scene), mossy on its tops;
the water is laid over it in hard pixels after the outline (`Sprite.overlay`), its own deep shade along
its sides. Graded with the land's palette in the game, as all scenery is.

    python3 tools/waterfall_art.py                # writes art/sprites/waterfall.png, _2, _3, _4
    python3 tools/waterfall_art.py --sheet out.png # the four frames at 4x, and a strip of them on grass

Needs pillow + numpy.
"""
import pathlib
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from lair_art import scene  # noqa: E402
from pixel_kit import Material  # noqa: E402
from scenery_art import foliage, puffs  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPRITES = ROOT / "art" / "sprites"
FRAMES = 4

DEEP, BASE, MID, LIGHT, FOAM = ((0x22, 0x66, 0x86), (0x3a, 0x96, 0xbc), (0x62, 0xb6, 0xd6),
                                (0xa8, 0xe2, 0xf0), (0xec, 0xfa, 0xfa))
LIP, FOOT = 15, 54          # where the water leaves the ledge and where it meets its pool
LEFT, RIGHT = 25, 39        # the sheet's sides at the foot (a little narrower at the lip)


def waterfall(frame=0):
    s = scene(64, 64)
    back, rock = Material("#8a867c", texture=0.07), Material("#9a968a", texture=0.07)
    moss = foliage("#6a9a3e")
    # The ledge behind, a notch in its middle where the water runs.
    s.poly([(3, 60), (2, 34), (7, 18), (17, 11), (28, 13), (36, 12), (46, 9), (56, 15), (62, 32), (61, 60)], back, bulge=1.6)
    # Boulders either side of the fall, and higher up on the ledge.
    s.ellipse(13, 47, 11, 12, rock)
    s.ellipse(51, 47, 11, 12, rock)
    s.ellipse(14, 26, 9, 9, rock)
    s.ellipse(50, 24, 10, 10, rock)
    for cx, cy, rx in ((14, 18.5, 6.5), (50, 15.5, 7), (12, 36.5, 7), (52, 36.5, 7)):
        puffs(s, cx, cy, rx, 2.4, moss, 10, 2.4, 170 + int(cx), flat=0.7, bulge=1.6)
    over = np.zeros((64, 64, 4), np.uint8)

    def put(x, y, colour):
        if 0 <= x < 64 and 0 <= y < 64:
            over[y, x] = (*colour, 255)

    rng = np.random.default_rng(7)
    offsets = rng.integers(0, 10, 64)
    lengths = rng.integers(1, 4, 64)
    for y in range(LIP, FOOT + 1):
        t = (y - LIP) / (FOOT - LIP)
        left = round(LEFT + 2 - 2 * t)
        right = round(RIGHT - 1 + 1 * t)
        for x in range(left, right + 1):
            if x in (left, right):
                colour = DEEP
            else:
                # Streaks running down: each column's own place in a 10-pixel cycle, 2.5 pixels a frame.
                k = (y - round(frame * 2.5) + offsets[x]) % 10
                colour = LIGHT if k < lengths[x] else MID if k < lengths[x] + 2 else BASE
                if x in (left + 1, right - 1) and colour == BASE:
                    colour = DEEP if (y + x) % 3 == 0 else BASE
            put(x, y, colour)
        if y == LIP:
            for x in range(left + 1, right):
                put(x, y, LIGHT)                        # the water's lip, catching the light
    # The pool it falls into: foam where it lands, broken up differently each frame.
    for y in range(FOOT - 2, FOOT + 5):
        for x in range(LEFT - 8, RIGHT + 9):
            e = ((x - (LEFT + RIGHT) / 2) / 14.5) ** 2 + ((y - FOOT - 1) / 3.6) ** 2
            if e > 1:
                continue
            churn = ((x * 73856093) ^ (y * 19349663) ^ (frame * 83492791)) % 11
            colour = FOAM if e < 0.45 and churn < 6 else LIGHT if e < 0.8 and churn < 5 else MID if churn < 7 else BASE
            if e > 0.82:
                colour = DEEP if churn % 2 else BASE
            put(x, y, colour)
    # Spray thrown up either side of the foot.
    for dx, dy in ((-9, -3), (8, -4), (-12, -1), (11, -2), (-5, -6), (6, -7)):
        if (dx + dy + frame) % 3:
            put((LEFT + RIGHT) // 2 + dx, FOOT + dy - (frame % 2), FOAM)
    s.overlay = over
    return s


DRAWINGS = {"waterfall": lambda: waterfall(0), "waterfall_2": lambda: waterfall(1),
            "waterfall_3": lambda: waterfall(2), "waterfall_4": lambda: waterfall(3)}


def main(argv):
    sheet = None
    if "--sheet" in argv:
        i = argv.index("--sheet")
        sheet = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    out = {}
    for name in argv or list(DRAWINGS):
        img = DRAWINGS[name]().render(outline="tinted")
        img.save(SPRITES / f"{name}.png")
        out[name] = img
    print(f"wrote {len(out)} waterfall frames to art/sprites/")
    if sheet:
        frames = [Image.open(SPRITES / f"{name}.png").convert("RGBA") for name in DRAWINGS]
        board = Image.new("RGBA", (64 * 4 + 30, 64), (88, 150, 64, 255))
        for k, im in enumerate(frames):
            board.alpha_composite(im, (k * 74, 0))
        board.resize((board.width * 4, board.height * 4), Image.NEAREST).save(sheet)
        print("wrote", sheet)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
