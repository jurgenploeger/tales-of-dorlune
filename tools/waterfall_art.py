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


# Waterfalls over the terraces' cliffs (the user, 2026-11-17: "Also add the waterfalls over the cliffs"),
# in three pieces the game fits to each face (`LandStage.placeCliffFalls`): the stream on the level above
# running to the lip (`cliff_fall_top`), the sheet of water down the face, stretched to its height
# (`cliff_fall_sheet`), and the pool it lands in at the foot (`cliff_fall_pool`), and the spring pond the stream
# runs out of up there (`cliff_fall_spring`; the user, 2026-11-25: "there is no water it comes from ... at the
# bottom of the waterfall should be a lake or pond": the pool grown into a pond). Hard pixels in the
# waterfall's water colours, no outline but the water's own deep shade along its sides; four frames each.
STONE, STONE_DARK, STONE_LIGHT, MOSS = (0x8e, 0x8a, 0x80), (0x4e, 0x4a, 0x48), (0xb4, 0xb0, 0xa4), (0x6a, 0x9a, 0x3e)
INK = (0x2e, 0x2a, 0x30)
TOP_W, TOP_H = 20, 12
SHEET_W, SHEET_H = 14, 24
POOL_W, POOL_H = 52, 20
SPRING_W, SPRING_H = 40, 17


def _image(h, w):
    return np.zeros((h, w, 4), np.uint8)


def _put(img, x, y, colour):
    if 0 <= y < img.shape[0] and 0 <= x < img.shape[1]:
        img[y, x] = (*colour, 255)


def _stone(img, cx, cy, rx, ry):
    """A little stone: a dark rim, lit on its top left."""
    for y in range(cy - ry - 1, cy + ry + 2):
        for x in range(cx - rx - 1, cx + rx + 2):
            e = ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2
            if e <= 1:
                lit = (x - cx) + (y - cy) < -0.5 * (rx + ry) * 0.6
                _put(img, x, y, STONE_LIGHT if lit else STONE)
            elif e <= 1.9 and img[y if 0 <= y < img.shape[0] else 0, x if 0 <= x < img.shape[1] else 0, 3] == 0:
                _put(img, x, y, INK)


def cliff_top(frame=0):
    """The stream on the level above, running toward you to the lip: wider at the lip (the bottom), its
    ripples running down a pixel a frame, a stone or two on its banks."""
    img = _image(TOP_H, TOP_W)
    rng = np.random.default_rng(11)
    offsets = rng.integers(0, 6, TOP_W)
    for y in range(TOP_H):
        t = y / (TOP_H - 1)
        half = 3 + 3.5 * t
        left, right = round(TOP_W / 2 - half), round(TOP_W / 2 + half) - 1
        for x in range(left, right + 1):
            if x in (left, right):
                colour = DEEP
            else:
                k = (y - frame + offsets[x]) % 6
                colour = LIGHT if k == 0 else MID if k < 3 else BASE
            _put(img, x, y, colour)
        if y == TOP_H - 1:
            for x in range(left + 1, right):
                _put(img, x, y, LIGHT)                  # the lip, catching the light
    _stone(img, 3, TOP_H - 4, 2, 1)
    _stone(img, TOP_W - 4, TOP_H - 3, 2, 1)
    _put(img, 4, TOP_H - 6, MOSS)
    _put(img, TOP_W - 5, TOP_H - 5, MOSS)
    return Image.fromarray(img, "RGBA")


def cliff_sheet(frame=0):
    """The sheet of water down the face: streaks running down 2.5 pixels a frame, its sides in deep shade."""
    img = _image(SHEET_H, SHEET_W)
    rng = np.random.default_rng(5)
    offsets = rng.integers(0, 10, SHEET_W)
    lengths = rng.integers(1, 4, SHEET_W)
    for y in range(SHEET_H):
        left, right = 1, SHEET_W - 2
        for x in range(left, right + 1):
            if x in (left, right):
                colour = DEEP
            else:
                k = (y - round(frame * 2.5) + offsets[x]) % 10
                colour = LIGHT if k < lengths[x] else MID if k < lengths[x] + 2 else BASE
                if x in (left + 1, right - 1) and colour == BASE:
                    colour = DEEP if (y + x) % 3 == 0 else BASE
            _put(img, x, y, colour)
    return Image.fromarray(img, "RGBA")


def cliff_pool(frame=0):
    """The pool at the foot: foam where the water lands, churned differently each frame, a ring of deep
    water and stones round its rim, spray thrown up."""
    img = _image(POOL_H, POOL_W)
    cx, cy = POOL_W / 2 - 0.5, POOL_H / 2
    for y in range(POOL_H):
        for x in range(POOL_W):
            e = ((x - cx) / 24.5) ** 2 + ((y - cy) / 8.6) ** 2
            if e > 1:
                continue
            churn = ((x * 73856093) ^ (y * 19349663) ^ (frame * 83492791)) % 11
            near = ((x - cx) / 6) ** 2 + ((y - cy + 5) / 3) ** 2
            colour = FOAM if near < 1 and churn < 7 else LIGHT if e < 0.55 and churn < 4 else MID if e < 0.75 else BASE
            if e > 0.8:
                colour = DEEP
            _put(img, x, y, colour)
    for sx, sy, rx, ry in ((3, 11, 2, 1), (POOL_W - 4, 9, 2, 2), (12, POOL_H - 2, 2, 1), (POOL_W - 15, POOL_H - 2, 3, 1)):
        _stone(img, sx, sy, rx, ry)
    # Rings spreading from where it lands, out on the still water, a step each frame.
    ring = 7 + 3 * frame
    for x in range(POOL_W):
        for y in range(POOL_H):
            r = (((x - cx) / ring) ** 2 + ((y - cy + 4) / (ring * 0.36)) ** 2) ** 0.5
            if 0.94 < r < 1.06 and img[y, x, 3] and tuple(img[y, x, :3]) in (BASE, MID) and (x + frame) % 4:
                _put(img, x, y, LIGHT)
    for dx, dy in ((-6, 1), (5, 0), (-3, 2), (4, 2)):
        if (dx + dy + frame) % 3:
            _put(img, round(cx) + dx, dy + (frame % 2), FOAM)
    return Image.fromarray(img, "RGBA")


def cliff_spring(frame=0):
    """The pond on the level above that the stream runs out of, toward you (the bottom middle, where the
    stream's narrow head meets it): still water, deep in its middle, a glint drifting a pixel a frame, a
    rim of stones and moss."""
    img = _image(SPRING_H, SPRING_W)
    cx, cy = SPRING_W / 2 - 0.5, SPRING_H / 2 - 1
    for y in range(SPRING_H):
        for x in range(SPRING_W):
            e = ((x - cx) / 18.5) ** 2 + ((y - cy) / 6.8) ** 2
            if e > 1:
                continue
            colour = DEEP if e > 0.8 else BASE if e < 0.35 else MID
            _put(img, x, y, colour)
    # Its mouth toward you, where the stream leaves it.
    for y in range(round(cy) + 5, SPRING_H):
        for x in range(round(cx) - 2, round(cx) + 3):
            _put(img, x, y, DEEP if x in (round(cx) - 2, round(cx) + 2) else MID)
    for k in range(3):
        gx = round(cx) - 8 + k * 6 + (frame + k) % 4
        _put(img, gx, round(cy) - 2 + k % 2, LIGHT)
        _put(img, gx + 1, round(cy) - 2 + k % 2, LIGHT)
    for sx, sy, rx, ry in ((3, 7, 2, 2), (SPRING_W - 4, 8, 2, 1), (10, 2, 2, 1), (SPRING_W - 12, 1, 2, 1), (8, SPRING_H - 3, 2, 1),
                           (SPRING_W - 9, SPRING_H - 3, 2, 1)):
        _stone(img, sx, sy, rx, ry)
    for mx, my in ((5, 5), (SPRING_W - 6, 6), (14, 1), (SPRING_W - 15, SPRING_H - 3)):
        _put(img, mx, my, MOSS)
    return Image.fromarray(img, "RGBA")


CLIFF_FALLS = {}
for _k in range(FRAMES):
    _suffix = "" if _k == 0 else f"_{_k + 1}"
    CLIFF_FALLS[f"cliff_fall_top{_suffix}"] = (lambda k: lambda: cliff_top(k))(_k)
    CLIFF_FALLS[f"cliff_fall_sheet{_suffix}"] = (lambda k: lambda: cliff_sheet(k))(_k)
    CLIFF_FALLS[f"cliff_fall_pool{_suffix}"] = (lambda k: lambda: cliff_pool(k))(_k)
    CLIFF_FALLS[f"cliff_fall_spring{_suffix}"] = (lambda k: lambda: cliff_spring(k))(_k)


def main(argv):
    sheet = None
    if "--sheet" in argv:
        i = argv.index("--sheet")
        sheet = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    out = {}
    for name in argv or list(DRAWINGS) + list(CLIFF_FALLS):
        img = DRAWINGS[name]().render(outline="tinted") if name in DRAWINGS else CLIFF_FALLS[name]()
        img.save(SPRITES / f"{name}.png")
        out[name] = img
    print(f"wrote {len(out)} waterfall frames to art/sprites/")
    if sheet and "--cliff" in argv:
        pass
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
