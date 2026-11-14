#!/usr/bin/env python3
"""The pieces of the bosses' lairs (maps.json, a boss's `lair`, `lairRing` and `lairApproach`) that no
sprite had: a standing stone, a brazier, a gold hoard, a warning post, a junk throne, a heap of bones, a
hunter's torn tent and a broken pillar, drawn in code with tools/pixel_kit.py in the
game's pixel style (docs/pixel-style.md), lit from the top left and outlined in a deep shade of each.

    python3 tools/lair_art.py                   # all → art/sprites/<id>.png
    python3 tools/lair_art.py brazier           # just these
    python3 tools/lair_art.py --sheet out.png   # a contact sheet at 4× on the meadow's green

Scored against RD's scenery: `python3 tools/pixel_style.py check --kind scenery art/sprites/<id>.png`.
"""

import math
import pathlib
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from pixel_kit import Material, Sprite  # noqa: E402
from scenery_art import SIDE_LIGHT, foliage, grounded, rng  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPRITES = ROOT / "art" / "sprites"


def scene(w=32, h=32):
    s = Sprite(w, h)
    s.light, s.rim, s.seams = SIDE_LIGHT, "lower", False
    return s


def standing_stone():
    """A tall grey standing stone, leaning a touch, a weathered rune cut in its face, moss at its foot."""
    s = scene(32, 48)
    stone, cut = Material("#8e8c96", texture=0.06), Material("#5a5866", texture=0.0)
    moss = foliage("#6a9a3e")
    s.poly([(10, 45), (9, 22), (11, 9), (16, 4), (21, 6), (23, 18), (24, 45)], stone, bulge=2.0)
    s.poly([(20, 45), (21, 22), (22, 12), (23, 18), (24, 45)], stone, profile="flat", tone=0.3)   # its shaded side
    for a, b in (((15, 16), (15, 26)), ((15, 21), (18, 18)), ((15, 21), (18, 24))):
        s.stroke([a, b], 1.0, cut, profile="flat")
    for x, y, r in ((11, 44, 3.2), (16, 45, 2.6), (22, 44.5, 2.8), (9, 41, 1.8)):
        s.ellipse(x, y, r, r * 0.6, moss[1 if x < 18 else 2])
    return s


def brazier():
    """A lit brazier: an iron bowl on three legs, a fire in it, burning at a lair's way in."""
    s = scene(32, 32)
    iron, rim = Material("#4e4a56", texture=0.03, gloss=0.4), Material("#6e6a78", texture=0.02)
    for a, b in (((12, 29), (14, 19)), ((20, 29), (18, 19)), ((16, 30), (16, 19))):
        s.stroke([a, b], 1.6, iron)
    s.ellipse(16, 18, 8, 4, iron)
    s.ellipse(16, 15.5, 8.5, 2.2, rim)
    s.ellipse(16, 15.5, 6.8, 1.5, Material("#2e2228", texture=0.0), profile="flat")
    flames = [Material(c, texture=0.0, relief=0.0) for c in ("#e8502a", "#ff9a30", "#ffe070")]
    for scale, mat in zip((1.0, 0.68, 0.38), flames):
        h, w = 12 * scale, 6.2 * scale
        s.poly([(16, 15 - h), (16 + w * 0.6, 15 - h * 0.5), (16 + w, 15), (16 - w, 15), (16 - w * 0.6, 15 - h * 0.55)], mat,
               profile="flat", tone=0.6)
    s.overlay = np.zeros((32, 32, 4), np.uint8)
    for x, y in ((12, 4), (20, 6), (16, 1)):
        s.overlay[y, x] = (255, 214, 96, 255)                       # sparks
    return s


def gold_hoard():
    """A heap of gold coins, a goblet and gems in it: a dragon's, or a greedy brute's. A big bright mound,
    lit gold on its top left and deep orange at its foot, coins standing out of it as discs each with a
    dark lower rim, a goblet on top, a ruby and a sapphire, and a glint or two. It was a low lump in the
    corner of its frame and lost blind to RD's props (2026-11-14): it has to read as gold at 1x."""
    s = scene(32, 32)
    gold, deep = Material("#f4c430", texture=0.02, gloss=0.6), Material("#c27a18", texture=0.02)
    coin, rim = Material("#ffe27a", texture=0.0), Material("#a8640e", texture=0.0)
    s.ellipse(16, 26.5, 14, 4.2, deep)
    s.ellipse(16, 22, 12.5, 7.5, gold, bulge=2.0)
    s.ellipse(14.5, 16.5, 7.5, 5.5, gold, bulge=1.8)
    for x, y in ((8, 21), (12, 18.5), (17, 14.5), (20, 19), (24, 23), (10, 25), (15, 23.5), (19.5, 25.5)):
        s.ellipse(x, y + 0.7, 1.9, 1.0, rim, profile="flat")
        s.ellipse(x, y, 1.9, 1.0, coin, profile="flat")
    for x, y in ((3.5, 29), (28, 28.5), (25.5, 30)):                    # spilled on the ground
        s.ellipse(x, y + 0.6, 1.7, 0.9, rim, profile="flat")
        s.ellipse(x, y, 1.7, 0.9, coin, profile="flat")
    s.stroke([(22, 15), (22, 11.5)], 1.3, gold)                          # a goblet standing on top
    s.poly([(19, 6.5), (25, 6.5), (24, 11.5), (20, 11.5)], gold, bulge=0.8)
    s.ellipse(22, 6.6, 3, 0.9, Material("#7a3e0a", texture=0.0), profile="flat")
    s.ellipse(22, 15.3, 2.6, 0.8, deep, profile="flat")
    s.ellipse(9.5, 17.5, 2.0, 1.9, Material("#e0304a", texture=0.0, gloss=0.9))
    s.ellipse(18, 21, 1.7, 1.6, Material("#3aa8f0", texture=0.0, gloss=0.9))
    s.overlay = np.zeros((32, 32, 4), np.uint8)
    for x, y in ((13, 13), (6, 19)):                                     # glints, a small cross each
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            s.overlay[y + dy, x + dx] = (255, 252, 230, 255)
    return s


def warning_post():
    """A warning on the way into a lair: a crooked stake, a cross-piece, a skull on top and a torn red
    rag hanging from it."""
    s = scene(32, 48)
    wood, bone, rag = Material("#7a5232", texture=0.07), Material("#e8e0cc", texture=0.03), Material("#b03030", texture=0.04)
    s.stroke([(16, 46), (15.5, 26), (16.5, 14)], 2.6, wood)
    s.stroke([(9, 22), (23, 20)], 2.0, wood)
    s.poly([(18, 21), (23, 20.5), (24, 30), (21, 27), (19, 31)], rag, bulge=0.8)
    s.ellipse(16.5, 10, 4.6, 4.0, bone)
    s.poly([(13.5, 12), (19.5, 12), (19, 15.5), (14, 15.5)], bone)
    dark = Material("#2a2026", texture=0.0)
    for x in (14.6, 18.4):
        s.ellipse(x, 10.4, 1.2, 1.3, dark, profile="flat")
    s.stroke([(15, 14.6), (18, 14.6)], 0.8, dark, profile="flat")
    return s


def junk_throne():
    """The Rat King's throne, a throne first: a tall arched back with a purple panel and a knob at each
    corner, armrests, a cushioned seat on four legs. Junk shows in its making: a board nailed across
    the back, mismatched legs, a dented pot for a crown, bones about its foot. (Crates heaped into a
    seat read as no throne at all: playtesting 2026-10-23.)"""
    s = scene(32, 48)
    wood, dark = Material("#9a6438", texture=0.06), Material("#6a3e22", texture=0.05)
    cloth, iron = Material("#8a3aa8", texture=0.04), Material("#8a8894", texture=0.03, gloss=0.5)
    gold, bone = Material("#e0b040", texture=0.03, gloss=0.6), Material("#e2d8c2", texture=0.03)
    arch = [(16 + 9.5 * math.cos(a), 13 - 8 * math.sin(a)) for a in np.linspace(0, math.pi, 13)]
    s.poly([(25.5, 38), (25.5, 13)] + arch + [(6.5, 13), (6.5, 38)], wood, bulge=1.2)          # the back
    inner = [(16 + 6.5 * math.cos(a), 14 - 5.5 * math.sin(a)) for a in np.linspace(0, math.pi, 11)]
    s.poly([(22.5, 33), (22.5, 14)] + inner + [(9.5, 14), (9.5, 33)], cloth)                  # its panel
    s.stroke([(8, 22), (24, 26)], 2.0, dark, profile="flat")                                  # a board nailed across
    for x, y in ((9.5, 22.6), (22.5, 25.6)):
        s.ellipse(x, y, 0.6, 0.6, iron, profile="flat")
    for x in (6.5, 25.5):                                                                      # knobs at its corners
        s.ellipse(x, 12, 2.2, 2.2, gold)
    s.poly([(12, 5), (20, 5), (19, 0.5), (13, 0.5)], iron)                                     # a dented pot, its crown
    s.ellipse(16, 5, 4.6, 1.3, iron)
    for x0, x1 in ((2, 9), (23, 30)):                                                          # armrests on posts
        s.stroke([(x0 + 1.5, 42), (x0 + 1.5, 32)], 2.0, dark)
        s.stroke([(x0, 31), (x1, 31)], 2.4, wood)
        s.ellipse(x0 + 0.5 if x0 < 16 else x1 - 0.5, 31, 1.6, 1.6, gold)
    s.poly([(7, 41), (25, 41), (25, 36), (7, 36)], dark, profile="flat", tone=0.45)           # the seat's front
    s.ellipse(16, 35, 9.5, 2.6, Material("#c83848", texture=0.04))                             # a red cushion
    for x, top in ((8.5, 41), (23.5, 41)):                                                     # legs, one a log
        s.stroke([(x, top), (x, 46)], 2.0, dark)
    s.stroke([(15.5, 41), (16.5, 46)], 2.4, wood)
    for x, y in ((4, 47), (27, 47)):
        s.stroke([(x - 2, y), (x + 2, y - 1)], 1.1, bone)
        s.ellipse(x - 2.3, y, 0.9, 0.9, bone)
    return s


def bone_pile():
    """A heap of old bones a beast has left about its den: long bones crossed every way, ribs, and a
    skull on top, bleached, a shade darker where they lie on each other."""
    s = scene(32, 32)
    bone, old = Material("#e8e0cc", texture=0.03), Material("#bdb29a", texture=0.03)
    dark = Material("#2a2026", texture=0.0)
    s.ellipse(16, 26, 11, 3.6, old, profile="flat", bulge=0.6)                                # the heap's foot
    for a, b in (((6, 27), (22, 22)), ((9, 21), (26, 27)), ((5, 24), (17, 19)), ((14, 27), (27, 20)),
                      ((11, 18), (21, 25))):
        mat = bone if a[0] < 12 else old
        s.stroke([a, b], 1.6, mat)
        for end in (a, b):                                                                     # knobbed ends
            s.ellipse(end[0], end[1], 1.4, 1.2, mat)
    for k in range(4):                                                                         # a rib cage
        x = 19 + k * 1.8
        s.stroke([(x, 24), (x + 1.4, 19), (x + 0.4, 16.5)], 0.9, bone)
    s.ellipse(12, 15, 4.2, 3.6, bone)                                                          # the skull on top
    s.poly([(9.5, 16.5), (14.5, 16.5), (14, 19.5), (10, 19.5)], bone)
    for x in (10.6, 13.4):
        s.ellipse(x, 15.4, 1.0, 1.1, dark, profile="flat")
    return s


def torn_tent():
    """A hunter's tent by a lair, torn: an A-frame of pale canvas seen from its front corner, its front a
    bright triangle with a dark doorway (so it reads as a tent at 1x), its side in shade with a ragged
    hole torn in it and a flap hanging, the poles crossed above its peak, a pack by the door. It was a
    dull brown heap and lost blind to RD's props (2026-11-14)."""
    s = scene(32, 32)
    canvas, side = Material("#ecd8a8", texture=0.03), Material("#b8946a", texture=0.03)
    pole, dark = Material("#6a4a2e", texture=0.04), Material("#2e2024", texture=0.0)
    s.poly([(12, 7), (23, 10), (31, 27), (19, 28)], side, profile="flat", tone=0.42)                           # its side, in shade
    s.poly([(2, 28), (12, 7), (20, 28)], canvas, profile="flat", tone=0.82)                                     # its lit front
    s.poly([(12, 13), (8, 28), (16, 28)], dark, profile="flat")                                 # the doorway
    s.poly([(12, 13), (16, 28), (18, 26)], canvas, profile="flat", tone=0.45)                   # its flap pinned back
    s.poly([(22, 15), (26, 14), (28, 21), (25, 24), (23, 20)], dark, profile="flat")             # the tear
    s.poly([(26, 14), (29, 16), (28.5, 22), (27, 20)], side, profile="flat", tone=0.75)          # torn flap hanging
    s.stroke([(10, 3.5), (14, 9)], 1.2, pole)                                                   # poles crossed at the peak
    s.stroke([(14.5, 3.5), (10.5, 9)], 1.2, pole)
    s.stroke([(23, 10), (24.5, 6.5)], 1.2, pole)
    s.stroke([(2, 28), (0.5, 30.5)], 0.7, pole, profile="flat")                                 # a peg
    s.ellipse(25, 28.5, 3.2, 2.4, Material("#8a5a32", texture=0.04))                            # a pack
    s.stroke([(23.5, 27), (26.5, 26.5)], 0.8, Material("#c8a060", texture=0.0), profile="flat")
    return s


def broken_pillar():
    """A fallen temple's pillar, still standing but broken off two thirds up: fluted pale stone, a
    worn base, its top jagged, a chunk of it lying at its foot and ivy up one side."""
    s = scene(32, 48)
    stone, deep = Material("#d0ccc0", texture=0.06), Material("#9a968c", texture=0.05)
    ivy = foliage("#5a8a3a")
    s.poly([(8, 46), (24, 46), (24, 42), (8, 42)], deep, profile="flat", tone=0.5)             # its base
    s.poly([(7, 42), (25, 42), (24, 39), (8, 39)], stone)
    s.poly([(10, 39), (22, 39), (22, 17), (19, 13), (16, 16), (13, 11), (10, 15)], stone, profile="cylinder")
    for x in (13, 16, 19):                                                                     # its fluting
        s.stroke([(x, 38), (x, 18 if x != 16 else 19)], 0.7, deep, profile="flat")
    s.poly([(24, 46), (31, 44), (30, 40), (25, 41)], stone, bulge=1.2)                         # a fallen chunk
    for x, y, r in ((10.5, 36, 1.8), (10, 31, 1.6), (11, 26, 1.4), (10.5, 22, 1.2), (12, 33, 1.2)):
        s.ellipse(x, y, r, r * 0.8, ivy[0 if y < 30 else 1])
    return s


PROPS = {"standing_stone": standing_stone, "brazier": brazier, "gold_hoard": gold_hoard, "warning_post": warning_post,
         "junk_throne": junk_throne, "bone_pile": bone_pile, "torn_tent": torn_tent, "broken_pillar": broken_pillar}


def main(argv):
    sheet = None
    if "--sheet" in argv:
        i = argv.index("--sheet")
        sheet = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    ids = argv or list(PROPS)
    out = {}
    for name in ids:
        img = PROPS[name]().render(outline="tinted")
        img = grounded(img) if img.height in (32, 64) else img
        img.save(SPRITES / f"{name}.png")
        out[name] = img
    print(f"wrote {len(out)} lair props to art/sprites/")
    if sheet:
        k = 4
        board = Image.new("RGBA", (sum(i.width * k + 16 for i in out.values()) + 16, 48 * k + 32), (106, 150, 86, 255))
        x = 16
        for img in out.values():
            big = img.resize((img.width * k, img.height * k), Image.NEAREST)
            board.alpha_composite(big, (x, board.height - 16 - big.height))
            x += big.width + 16
        board.save(sheet)
        print(f"sheet in {sheet}")


if __name__ == "__main__":
    main(sys.argv[1:])
