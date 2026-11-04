"""Armour sheets whose views disagree in colour, brought to one: the cape as the back view draws it.

Retro Diffusion drew the ranger cloak's back as a green cape, and its front and sides as a near-black
mass (the human's cape behind his dark coat, the dwarf's cape wings either side of him). A tier's tint or
a dye recolours the green (DyeDef.mains, items.json `tint`), so the cloak changed colour only from behind,
and it read as two garments (the user, 2026-11-04: "match all views").

In the front and side views, a cape pixel is a near-black one whose whole 3 x 3 neighbourhood is
near-black too (the dark mass less a one-pixel rim; skin and hair are never that dark, and a bare-headed
sheet has no head): the rim stays as the outline, and thin dark details (a coat's seams, belts) stay as drawn. Each cape pixel
takes the back view's cape shade (`VIEWS` base), one step lighter where it's lit from the top left (its
pixel above or to its left isn't cape), so it keeps a light edge as the back's has. Shapes are not
touched, only those pixels' colours. A rerun changes nothing (the cape is no longer near-black).

A cape shade drawn just under the dyes' floor (`dye_art.DARK`, DyeDef `minValue`) stayed its own colour
under every tint and dye, in patches: `lift` raises it, in every view, to the same hue a hair over it.

    python3 tools/armour_views.py            # fix the sheets in VIEWS
    python3 tools/armour_views.py --dry-run  # count what would change
Rerun `tools/dye_art.py cut` and `check` after.
"""
import pathlib
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import dye_art  # noqa: E402

FRAME = 48
BACK = 0   # the sheet's first row of frames: walking up, the back view
DARK = 0.16   # near-black: the cape as drawn in the front and side views, under the back's cape shades
# Per sheet: the back view's cape shade for the cape in shadow, and its lit shade, both in the ranger
# cloak's main family (DyeDef.mains `ranger_cloak`, value over dye_art.DARK so a dye takes them); and
# shades lifted over that floor (`lift`: the dwarf's darkest green, at 0.18, to 0.215).
VIEWS = {
    "armor_ranger_cloak_human": dict(base="#243c21", lit="#2d5425"),
    "armor_ranger_cloak_dwarf": dict(base="#2d5425", lit="#456633", lift={"#102f14": "#133717"}),
}


def colour(text):
    return np.array([int(text[i:i + 2], 16) for i in (1, 3, 5)], np.uint8)


def cape(a):
    """The near-black cape pixels of a sheet's front and side views, and which of them are lit."""
    h, s, v = dye_art.hsv(a[..., :3].astype(float) / 255)
    dark = (a[..., 3] > 127) & (v < DARK)
    found = np.zeros(dark.shape, bool)
    for fy in range(0, a.shape[0], FRAME):
        if fy // FRAME == BACK:
            continue
        for fx in range(0, a.shape[1], FRAME):
            box = (slice(fy, fy + FRAME), slice(fx, fx + FRAME))
            found[box] = ndimage.binary_erosion(dark[box], np.ones((3, 3), bool))
    above = np.zeros_like(found)
    above[1:] = found[:-1]
    left = np.zeros_like(found)
    left[:, 1:] = found[:, :-1]
    return found, found & ~(above & left)


def fix(name, dry_run=False):
    rule = VIEWS[name]
    path = dye_art.SPRITES / f"{name}.png"
    a = np.asarray(Image.open(path).convert("RGBA")).copy()
    found, lit = cape(a)
    a[found & ~lit, :3] = colour(rule["base"])
    a[lit, :3] = colour(rule["lit"])
    lifted = 0
    for old, new in rule.get("lift", {}).items():
        shade = (a[..., 3] > 127) & (a[..., :3] == colour(old)).all(-1)
        a[shade, :3] = colour(new)
        lifted += int(shade.sum())
    print(f"{name}: {int(found.sum())} cape pixels ({int(lit.sum())} lit), {lifted} lifted")
    if (found.any() or lifted) and not dry_run:
        Image.fromarray(a).save(path)


if __name__ == "__main__":
    for sheet in VIEWS:
        fix(sheet, dry_run="--dry-run" in sys.argv)
