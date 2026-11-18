#!/usr/bin/env python3
"""The game's body text font (the user's pick, 2026-11-18, from a mock-up of Allo beside the HUD's
SF Pro Rounded Heavy: "Go with roundness 60"): Allo (Josh Puckett, SIL Open Font License,
https://allo.joshpuckett.me; `tools/fonts/AlloVariable.ttf` and `Allo-OFL.txt`, version 1.0.3) cut
to one static instance, roundness 60 (`ROND`), weight 560 and text size (`opsz` 14), named Allo
Dorlune so it's never mistaken for Allo's own instances. The game shows speech, stories,
descriptions and notes in it (`HUDStyle.body`); titles, names, buttons and numbers stay in
`HUDStyle.font`. Latin only: other scripts fall back to the system's font.

    python3 tools/allo_font.py        # → TalesOfDorlune/Resources/Fonts/AlloDorlune-Body.ttf

Needs fonttools.
"""
import pathlib
import shutil

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "tools" / "fonts" / "AlloVariable.ttf"
OUT = ROOT / "TalesOfDorlune" / "Resources" / "Fonts"
AXES = {"ROND": 60, "wght": 560, "opsz": 14}
FAMILY, STYLE, POSTSCRIPT = "Allo Dorlune", "Body", "AlloDorlune-Body"


def main():
    font = instancer.instantiateVariableFont(TTFont(SOURCE), AXES, updateFontNames=False)
    names = font["name"]
    for record in list(names.names):
        if record.nameID in (1, 2, 3, 4, 6, 16, 17, 25):
            names.removeNames(nameID=record.nameID)
    for platform in ((3, 1, 0x409), (1, 0, 0)):
        names.setName(FAMILY, 1, *platform)
        names.setName(STYLE, 2, *platform)
        names.setName(f"{POSTSCRIPT};1.0.3", 3, *platform)
        names.setName(f"{FAMILY} {STYLE}", 4, *platform)
        names.setName(POSTSCRIPT, 6, *platform)
    if "STAT" in font:
        del font["STAT"]
    OUT.mkdir(parents=True, exist_ok=True)
    font.save(OUT / f"{POSTSCRIPT}.ttf")
    shutil.copy(SOURCE.parent / "Allo-OFL.txt", OUT / "Allo-OFL.txt")
    print("wrote", OUT / f"{POSTSCRIPT}.ttf")


if __name__ == "__main__":
    main()
