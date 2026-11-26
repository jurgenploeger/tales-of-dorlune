#!/usr/bin/env python3
"""The closed chests out in the world, ChatGPT's drawings (docs/ai-sprite-test/chests, the user, 2026-11-26): each
picked 32 × 32 drawing in `art-variants/chests/` copied to `art/sprites/` as it was drawn, one style per kind of area
(maps.json theme `chest`, `ChestLook`). Opened, a chest shows RD's open `treasure_chest`.

    python3 tools/chest_art.py
    python3 tools/chest_art.py --sheet out.png

Needs pillow + numpy.
"""
import pathlib
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "art-variants" / "chests"
OUT = ROOT / "art" / "sprites"

# The sprite each picked drawing makes, as delivered (32 × 32, alpha 0 or 255).
PICKED = {
    "chest_coral": "chest_coral.png",
    "chest_candy": "chest_candy.png",
    "chest_crystal": "chest_crystal.png",
    "chest_shadow": "chest_shadow.png",
    "chest_swamp": "chest_swamp.png",
}


def main(argv):
    made = {}
    for sprite, source in PICKED.items():
        a = np.array(Image.open(SRC / source).convert("RGBA"))
        assert a.shape[:2] == (32, 32), f"{source}: {a.shape[1]} × {a.shape[0]}, not 32 × 32"
        a[..., 3] = np.where(a[..., 3] > 127, 255, 0)
        a[a[..., 3] == 0] = 0
        Image.fromarray(a, "RGBA").save(OUT / f"{sprite}.png")
        made[sprite] = a
        colours = len(np.unique(a[a[..., 3] > 0][:, :3], axis=0))
        print(f"{sprite}: {colours} colours")
    if argv[:1] == ["--sheet"]:
        sheet = Image.new("RGBA", (len(made) * 36, 32), (150, 150, 150, 255))
        for k, a in enumerate(made.values()):
            sheet.alpha_composite(Image.fromarray(a, "RGBA"), (k * 36, 0))
        sheet.resize((sheet.width * 6, sheet.height * 6), Image.NEAREST).save(argv[1])
        print(argv[1])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
