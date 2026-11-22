#!/usr/bin/env python3
"""Lit windows at night (the user, 2026-11-18: "during the night the lights in houses should be brighter"): each
building's windows cut into a picture of their own (`windows_<id>.png`, the rest clear), which the game lays over
the building above the night's shade as it grows dark (`LandStage.addWindows`), so the windows glow as drawn
while the house dims. Retro Diffusion's art stays as it is.

A window pixel is warm and bright (a lit pane's yellow). Thatch, gold trim and lantern-lit awnings are too, so
only small patches of them count (`BIGGEST` pixels at most, a pane or a small window; a thatched roof is one
patch of hundreds), and `SKIP` names what has no windows to light (gates, fences, tents and stalls, and the
few whose roofs still came through). The forge keeps its own fire (`tools/fire_art.py`).

    python3 tools/window_art.py              # writes art/sprites/windows_<id>.png and lists the ids
    python3 tools/window_art.py --sheet out.png

Needs pillow + numpy + scipy.
"""
import json
import pathlib
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPR = ROOT / "art" / "sprites"
BIGGEST = 64
FEWEST = 6
SKIP = {"fence", "town_gate", "market_tent", "market_stall", "pavilion_tent", "desert_tent", "yurt", "blacksmith",
        "bakery", "beach_hut", "adobe_house_tall", "windmill", "puppet_theater", "mushroom_house"}


# Where a building's windows are, as boxes (rows y0 to y1, columns x0 to x1), when bright warm pixels
# elsewhere would pass for panes too: the thatched cottage's straw, the book shop's hanging sign, a yellow
# cloth in the tailor's window, the dome house's sandstone along its wall top (the pictures ChatGPT drew,
# 2026-11-21). Only pixels in a box count.
BOXES = {"thatched_cottage": [(60, 96, 0, 96)],
         "book_shop": [(55, 66, 40, 52)],
         "tailor_shop": [(50, 64, 0, 96)],
         "dome_house": [(52, 60, 32, 40), (55, 72, 52, 60)],
         "tree_house": [(40, 52, 0, 96)],
         "round_cottage": [(40, 96, 0, 96)],
         "wildfolk_lodge": [(124, 140, 38, 92)],
         "acorn_cottage": [(38, 48, 28, 40), (60, 72, 48, 60)],
         "dairy_shop": [(66, 79, 15, 45)],
         "glass_lantern_shop": [(45, 56, 41, 52)],
         "assay_office": [(58, 73, 21, 36)],
         "miners_lodge": [(58, 73, 21, 34), (56, 71, 53, 61)],
         "sandstone_house": [(39, 55, 25, 37), (66, 82, 25, 37)],
         "spice_shop": [(63, 77, 18, 29)],
         "stump_house": [(55, 70, 20, 75)],
         "apple_cellar": [(64, 75, 23, 35), (64, 75, 55, 67)],
         "reed_boathouse": [(58, 72, 26, 38), (58, 72, 55, 67)],
         "frog_hut": [(28, 43, 20, 76)],
         "raft_teahouse": [(63, 74, 28, 70)],
         "pineapple_hut": [(56, 70, 22, 33), (56, 70, 61, 72)],
         "well_house": [(48, 56, 35, 46), (60, 78, 22, 33)],
         "lamp_house": [(70, 80, 25, 34), (70, 80, 54, 63)],
         "lookout_hut": [(54, 63, 28, 38), (54, 63, 56, 65)],
         "warrior_guild": [(112, 124, 50, 104)],
         "emerald_spire": [(100, 109, 80, 92), (124, 137, 74, 100), (148, 160, 50, 124)]}


def buildings():
    assets = json.load(open(ROOT / "art" / "assets.json"))
    assets = assets.get("assets", assets)
    return [a["id"] for a in assets if a.get("kind") == "building" and a["id"] not in SKIP and not a["id"].startswith("gate_")]


def windows(name):
    path = SPR / f"{name}.png"
    if not path.exists():
        return None
    im = np.asarray(Image.open(path).convert("RGBA")).astype(int)
    r, g, b, a = (im[..., i] for i in range(4))
    inside = np.zeros(a.shape, bool)
    for y0, y1, x0, x1 in BOXES.get(name, []):
        inside[y0:y1, x0:x1] = True
    # Inside a box a pane may be a pure yellow too (no blue in it at all: the glass lantern shop's), as gold
    # trim can't sneak in there.
    # And a little more orange (green from 150): the genie lamp's panes, its colours merged.
    warm = (a > 200) & (r >= 225) & ((g >= 175) | (inside & (g >= 150))) & (b <= g - 35) & ((b >= 60) | inside) & (r - b >= 60)
    if name in BOXES:
        warm &= inside
    labels, count = ndimage.label(warm, structure=np.ones((3, 3)))
    keep = np.zeros(warm.shape, bool)
    for index in range(1, count + 1):
        patch = labels == index
        if (2 if name in BOXES else 4) <= patch.sum() <= BIGGEST:   # not a speck of bright brick (in a box, a pane)
            keep |= patch
    if keep.sum() < FEWEST:
        return None
    out = np.zeros(im.shape, np.uint8)
    # A little brighter and warmer than drawn: lit from inside.
    lit = np.clip(im[..., :3] * np.array([1.06, 1.04, 0.96]) + np.array([8, 6, 0]), 0, 255)
    out[..., :3] = np.where(keep[..., None], lit, 0)
    out[..., 3] = np.where(keep, 255, 0)
    return Image.fromarray(out, "RGBA")


def main(argv):
    made = {name: img for name in buildings() if (img := windows(name)) is not None}
    if argv[:1] == ["--sheet"]:
        tiles = []
        for name, img in made.items():
            base = np.asarray(Image.open(SPR / f"{name}.png").convert("RGBA")).astype(float)
            base[..., :3] *= np.array([0.42, 0.47, 0.78])
            tile = Image.new("RGBA", img.size, (16, 20, 36, 255))
            tile.alpha_composite(Image.fromarray(base.astype(np.uint8), "RGBA"))
            tile.alpha_composite(img)
            tile.thumbnail((96, 96), Image.NEAREST)
            tiles.append(tile)
        cols = 10
        sheet = Image.new("RGB", (cols * 100, ((len(tiles) + cols - 1) // cols) * 100), (16, 20, 36))
        for i, tile in enumerate(tiles):
            sheet.paste(tile, (i % cols * 100, i // cols * 100))
        sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(argv[1])
        print(argv[1])
        return 0
    for name, img in made.items():
        img.save(SPR / f"windows_{name}.png")
    print(" ".join(sorted(made)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
