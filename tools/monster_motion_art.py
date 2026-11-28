#!/usr/bin/env python3
"""Monsters in motion: ChatGPT's sheets (docs/ai-sprite-test/monster-animation, 2026-11-28), copied as drawn.

    python3 tools/monster_motion_art.py

Each sheet is 9 columns (idle 2, walk 4, attack 3: wind-up, strike, recover) by 8 rows (down, right, up,
left, down-right, down-left, up-right, up-left) of square frames (40 pixels, 64 for the big bosses).
`art-variants/monster_sheets/<monster id>_sheet.png` is copied to `art/sprites/motion_<its art>.png`, and a
variant with a sheet of its own (`variants/`) to its art's; every other variant, and a recoloured companion,
recolours its base's sheet as its picture is (`ArtLibrary.motionImage`). `ArtLibrary.motionCycle` reads them:
the walk is the walk cycle, `WalkCycle.idle` and `.attack` the rest.
"""
import json
import pathlib
import shutil

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "art-variants" / "monster_sheets"
OUT = ROOT / "art" / "sprites"


def main():
    monsters = json.loads((ROOT / "content" / "monsters.json").read_text())
    monsters = monsters["monsters"] if isinstance(monsters, dict) else monsters
    n = 0
    for m in monsters:
        src = SRC / f"{m['id']}_sheet.png"
        if not src.exists():
            src = SRC / "variants" / f"{m['id']}_sheet.png"
        if not src.exists() and m["id"] == "dragonfruit":
            src = SRC / "variants" / "dragonfruit_sprout_sheet.png"
        if not src.exists():
            continue
        w, h = Image.open(src).size
        assert w % 9 == 0 and h == w // 9 * 8, f"{src.name}: {w}x{h} isn't 9 by 8 square frames"
        shutil.copyfile(src, OUT / f"motion_{m['art']}.png")
        n += 1
    print(f"wrote {n} monster sheets to art/sprites/")


if __name__ == "__main__":
    main()
