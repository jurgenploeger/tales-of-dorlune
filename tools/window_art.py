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
        "bakery", "beach_hut", "thatched_cottage", "adobe_house_tall", "windmill", "puppet_theater", "mushroom_house"}


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
    warm = (a > 200) & (r >= 225) & (g >= 175) & (b <= g - 35) & (b >= 60) & (r - b >= 60)
    labels, count = ndimage.label(warm, structure=np.ones((3, 3)))
    keep = np.zeros(warm.shape, bool)
    for index in range(1, count + 1):
        patch = labels == index
        if 4 <= patch.sum() <= BIGGEST:           # not a speck of bright brick either
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
