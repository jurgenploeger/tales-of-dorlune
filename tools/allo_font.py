#!/usr/bin/env python3
"""The game's text font (the user's pick, 2026-11-18, from a mock-up of Allo beside the HUD's
SF Pro Rounded Heavy: "Go with roundness 60"): Allo (Josh Puckett, SIL Open Font License,
https://allo.joshpuckett.me; `tools/fonts/AlloVariable.ttf` and `Allo-OFL.txt`, version 1.0.3) cut
to static instances (`CUTS`), roundness 60 (`ROND`) and text size (`opsz` 14), named Allo Dorlune so
they're never mistaken for Allo's own instances:
- Body, weight 620 (560 until 2026-11-20, the user: "slightly thicker"): speech, stories,
  descriptions, notes (`HUDStyle.body`).
- Bold, weight 760: every other label, names, buttons, prices (`HUDStyle.font`; the user,
  2026-11-20: "use it more throughout the app and keep the other font more for headlines and titles
  only"). Window titles, section titles, tabs and big headlines stay in SF Pro Rounded Heavy
  (`HUDStyle.title`).
Latin only: other scripts fall back to the system's font.

    python3 tools/allo_font.py        # → TalesOfDorlune/Resources/Fonts/AlloDorlune-*.ttf

Needs fonttools.
"""
import pathlib
import shutil

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "tools" / "fonts" / "AlloVariable.ttf"
OUT = ROOT / "TalesOfDorlune" / "Resources" / "Fonts"
FAMILY = "Allo Dorlune"
CUTS = {"Body": 620, "Bold": 760}  # style → weight


def cut(style, weight):
    postscript = f"AlloDorlune-{style}"
    axes = {"ROND": 60, "wght": weight, "opsz": 14}
    font = instancer.instantiateVariableFont(TTFont(SOURCE), axes, updateFontNames=False)
    names = font["name"]
    for record in list(names.names):
        if record.nameID in (1, 2, 3, 4, 6, 16, 17, 25):
            names.removeNames(nameID=record.nameID)
    for platform in ((3, 1, 0x409), (1, 0, 0)):
        names.setName(FAMILY, 1, *platform)
        names.setName(style, 2, *platform)
        names.setName(f"{postscript};1.0.3", 3, *platform)
        names.setName(f"{FAMILY} {style}", 4, *platform)
        names.setName(postscript, 6, *platform)
    if "STAT" in font:
        del font["STAT"]
    font["OS/2"].usWeightClass = weight
    OUT.mkdir(parents=True, exist_ok=True)
    font.save(OUT / f"{postscript}.ttf")
    print("wrote", OUT / f"{postscript}.ttf")


def main():
    for style, weight in CUTS.items():
        cut(style, weight)
    shutil.copy(SOURCE.parent / "Allo-OFL.txt", OUT / "Allo-OFL.txt")


if __name__ == "__main__":
    main()
