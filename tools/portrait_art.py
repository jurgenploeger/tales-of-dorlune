#!/usr/bin/env python3
"""The townsfolk's portraits in the speech window: ChatGPT's drawings (docs/ai-sprite-test/npc-portraits,
2026-11-28), 128 x 160, four moods each, copied as drawn.

    python3 tools/portrait_art.py

`art-variants/npc_portraits/portraits.json` names each NPC art's portrait (several townsfolk share one look);
each is copied to `art/sprites/portrait_<art>_<mood>.png`, which `NPCPortrait` shows (neutral when a mood
has none).
"""
import json
import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "art-variants" / "npc_portraits"
OUT = ROOT / "art" / "sprites"
MOODS = ("neutral", "happy", "worried", "surprised")


def main():
    table = json.loads((SRC / "portraits.json").read_text())
    n = 0
    for art, portrait in sorted(table.items()):
        for mood in MOODS:
            src = SRC / f"{portrait}_{mood}.png"
            if src.exists():
                shutil.copyfile(src, OUT / f"portrait_{art}_{mood}.png")
                n += 1
    print(f"wrote {n} portraits to art/sprites/")


if __name__ == "__main__":
    main()
