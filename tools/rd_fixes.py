#!/usr/bin/env python3
"""Small, exact fixes to Retro Diffusion sprites, for what RD got wrong and the user asked to have
fixed (CLAUDE.md: RD's art is never redrawn, only this). Each fix names the pixels it clears or
sets and the colours they must have first, so rerunning it changes nothing, and a regenerated
sprite that no longer matches is reported rather than spoiled. Rerun it after regenerating one.

  python3 tools/rd_fixes.py            all of them
  python3 tools/rd_fixes.py --check    only report which still need fixing
"""
import sys
from pathlib import Path

from PIL import Image

SPRITES = Path(__file__).resolve().parent.parent / "art" / "sprites"

SPARK = {"a9e264", "76c263", "65ae5f", "589661", "4d835e", "447058", "598869"}

# Per sprite: (pixels to clear, pixels to set to a colour), each pixel's colour checked first.
FIXES = {
    # The Poison Skeleton's spark: RD drew a little burst of green beside the skull (its prompt
    # asked for "a green poison glow"), and on every recolour of it (the Crimson Skeleton's red
    # most of all) it read as a stray star stuck to the head (playtesting 2026-11-01: "The skeleton
    # monster has a strange star thing at his head"). Cleared, and the skull's outline (dark inside,
    # mid green outside) closed where the spark broke it.
    "monster_poison_skeleton": (
        [(29, 9), (30, 9), (28, 10), (29, 10), (30, 10),
         (28, 11), (29, 11), (30, 11), (31, 11), (32, 11), (33, 11),
         (28, 12), (29, 12), (30, 12), (31, 12),
         (29, 13), (30, 13), (29, 14), (30, 14)],
        [((26, 11), "2c4b47"), ((27, 11), "589661"), ((26, 12), "2c4b47"), ((27, 12), "589661")],
    ),
}


def hexcolour(pixel):
    return "%02x%02x%02x" % pixel[:3]


def fix(name, check_only):
    path = SPRITES / f"{name}.png"
    image = Image.open(path).convert("RGBA")
    px = image.load()
    clear, paint = FIXES[name]
    pending = [p for p in clear if px[p][3] != 0] + [p for p, c in paint if hexcolour(px[p]) != c or px[p][3] != 255]
    if not pending:
        return f"{name}: already fixed"
    unexpected = [p for p in clear if px[p][3] != 0 and hexcolour(px[p]) not in SPARK]
    if unexpected:
        return f"{name}: NOT fixed, the sprite has changed (unexpected colours at {unexpected}); look at it again"
    if check_only:
        return f"{name}: needs fixing ({len(pending)} pixels)"
    for p in clear:
        px[p] = (0, 0, 0, 0)
    for p, c in paint:
        px[p] = (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), 255)
    image.save(path)
    return f"{name}: fixed ({len(pending)} pixels)"


if __name__ == "__main__":
    check = "--check" in sys.argv
    for sprite in FIXES:
        print(fix(sprite, check))
