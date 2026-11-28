#!/usr/bin/env python3
"""Skills in battle as pixel art: ChatGPT's effect sheets (docs/ai-sprite-test/spell-effects, 2026-11-28),
cut into strips the game plays (`PixelSpell`, TalesOfDorlune/Battle/PixelSpells.swift).

    python3 tools/spell_effect_art.py

Each `art-variants/spell_effects/effect_<skill>.png` is 8 columns by 4 rows of 64-pixel frames: the cast
round the caster (6), the bolt flying right (4) and flying up (4), when it has one, and the impact on the
target (8). Written to `art/sprites/spell_<skill>_cast.png`, `_fly.png`, `_flyup.png` and `_impact.png`,
one frame after another along a row, only the frames drawn.
"""
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "art-variants" / "spell_effects"
OUT = ROOT / "art" / "sprites"
FRAME = 64
ROWS = (("cast", 6), ("fly", 4), ("flyup", 4), ("impact", 8))


def main():
    n = 0
    for sheet in sorted(SRC.glob("effect_*.png")):
        if sheet.stem.endswith("_8x"):
            continue
        skill = sheet.stem[len("effect_"):]
        img = Image.open(sheet).convert("RGBA")
        assert img.size == (8 * FRAME, 4 * FRAME), f"{sheet.name}: {img.size}"
        alpha = np.array(img)[..., 3]
        for row, (part, most) in enumerate(ROWS):
            drawn = [c for c in range(most) if alpha[row * FRAME:(row + 1) * FRAME, c * FRAME:(c + 1) * FRAME].any()]
            target = OUT / f"spell_{skill}_{part}.png"
            if not drawn:
                target.unlink(missing_ok=True)
                continue
            count = drawn[-1] + 1
            strip = img.crop((0, row * FRAME, count * FRAME, (row + 1) * FRAME))
            strip.save(target)
        n += 1
    print(f"wrote {n} skills' effects to art/sprites/")


if __name__ == "__main__":
    main()
