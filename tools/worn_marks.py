#!/usr/bin/env python3
"""Where gloves and boots go on each hero body, marked once, offline: art/sprites/marks_<body>.png.

The game used to look for the hands in each frame as it dressed a hero: the patches of skin under the
chin. That found nothing on bodies whose hands Retro Diffusion drew as white cuffs or gloves (the human
man, the human other), and took a neck or a belt buckle for a hand on others (a red bib on an elf or a
dwarf in ruby gauntlets), so gloves showed on some bodies and not others (2026-11-10, the user: "It
should also be more clear when it's wearing different gloves and shoes"). Now every frame of every
body layer has its hands and boots marked here, where they can be looked at and corrected, and
GearOverlay.trinkets paints the marks (tools/gear_preview.py `trinkets` is the same):

    red   (255, 0, 0)      a glove: the hand, and the sleeve's end over it
    pink  (255, 128, 128)  its band: the cuff's top row, painted a shade lighter
    blue  (0, 0, 255)      a boot
    sky   (128, 128, 255)  its band: the boot's top row

    python3 tools/worn_marks.py                  # writes the marks
    python3 tools/worn_marks.py --sheet out.png  # every body, its marks over it, at 4x

Needs pillow + numpy. Rerun after tools/hero_layers.py changes a body layer.
"""
import argparse
import colorsys
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPRITES = ROOT / "art" / "sprites"
F = 48
DIRS = ["up", "right", "down", "left"]
GLOVE, GLOVE_BAND, BOOT, BOOT_BAND = (255, 0, 0), (255, 128, 128), (0, 0, 255), (128, 128, 255)
# A hand's rows from its lowest up, the rows of sleeve over it its cuff takes, and how far up the
# figure (from its top, as a share of its height) a hand's lowest row can be.
HAND_ROWS, CUFF_ROWS = 3, 3
HAND_BAND = (0.5, 0.74)
# Facing you or away, a patch this near the figure's middle is a buckle, a neck or a chest, not a hand.
MIDDLE = 3.0
# Where no hand shows on a side facing you or away (a sleeve over it, a dark mitt), the arm's end: the
# figure's outermost pixels on that side between these shares of its height, this many rows and columns.
ARM_BAND = (0.5, 0.72)
ARM_ROWS, ARM_COLS = 3, 3
BOOT_ROWS = 5
# Hands a body's sheet drew in a colour of their own (the human other's orange mitts), counted as skin
# below the chin: (hue from, hue to, least saturation, least value).
MITTS = {"human_other": (15, 40, 0.75, 0.8), "dwarf_other": (15, 40, 0.75, 0.8)}


def bodies():
    return sorted(p.stem[len("body_"):] for p in SPRITES.glob("body_*.png"))


def hsv(p):
    return colorsys.rgb_to_hsv(*p[:3])


def patches(mask):
    seen = np.zeros_like(mask)
    found = []
    for y, x in zip(*np.nonzero(mask)):
        if seen[y, x]:
            continue
        stack, cells = [(y, x)], []
        seen[y, x] = True
        while stack:
            cy, cx = stack.pop()
            cells.append((cy, cx))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < F and 0 <= nx < F and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        found.append(cells)
    return found


def mark_frame(f, facing, mitts=None):
    """The marks for one 48-pixel frame of a bald body, as an RGBA array."""
    out = np.zeros((F, F, 4), np.uint8)
    a = f[..., 3] > 0.5
    rows = np.nonzero(a.any(1))[0]
    if len(rows) == 0 or rows[-1] - rows[0] <= 8:
        return out
    top, feet = rows[0], rows[-1]
    height = feet - top
    cols = np.nonzero(a.any(0))[0]
    middle = (cols[0] + cols[-1]) / 2
    h = np.zeros((F, F)); s = np.zeros((F, F)); v = np.zeros((F, F))
    for y, x in zip(*np.nonzero(a)):
        h[y, x], s[y, x], v[y, x] = hsv(f[y, x])
    skin = a & ((h <= 40 / 360) | (h >= 342 / 360)) & (s > 0.12) & (s < 0.65) & (v > 0.55)
    pale = a & (s < 0.3) & (v >= 0.35)
    if mitts:
        lo_h, hi_h, least_s, least_v = mitts
        skin |= a & (h >= lo_h / 360) & (h <= hi_h / 360) & (s >= least_s) & (v >= least_v)
    # Boots: the body's brown near its feet (GearOverlay's rule since 0.7.28).
    boot = np.zeros((F, F), bool)
    lo = max(0, feet - BOOT_ROWS)
    boot[lo:feet + 1] = (a & (h >= 7 / 360) & (h <= 43 / 360) & (s > 0.35) & (v < 0.75))[lo:feet + 1]
    # Hands: skin, or the pale cuffs and mitts drawn for them, whose lowest row is at hand height; never
    # the face (the biggest patch of skin), nor what's joined to it.
    skins = patches(skin)
    glove = np.zeros((F, F), bool)
    if skins:
        face = max(skins, key=len)
        chin = max(y for y, _ in face)
        touching = set(face)
        for cells in patches(skin | pale):
            if touching & set(cells):
                continue
            low, high = max(y for y, _ in cells), min(y for y, _ in cells)
            xm = float(np.mean([x for _, x in cells]))
            if not (HAND_BAND[0] <= (low - top) / height <= HAND_BAND[1]) or high < chin + 2 or boot[low, int(round(xm))]:
                continue
            if facing in ("up", "down") and abs(xm - middle) < MIDDLE:
                continue
            # A wide pale patch is a hem's trim, not a hand; a lone pixel a neck or a buckle.
            xs = [x for _, x in cells]
            if len(cells) < 2 or max(xs) - min(xs) >= 5:
                continue
            for y, x in cells:
                if y > low - HAND_ROWS - (2 if not any(skin[yy, xx] for yy, xx in cells) else 0):
                    glove[y, x] = True
    # Facing you or away, a side with no hand found: the arm's end.
    if facing in ("up", "down"):
        y0, y1 = int(round(top + ARM_BAND[0] * height)), int(round(top + ARM_BAND[1] * height))
        for side in (-1, 1):
            half = slice(0, int(middle)) if side < 0 else slice(int(np.ceil(middle)) + 1, F)
            if glove[:, half].any():
                continue
            band = a[y0:y1 + 1]
            edge = [(np.nonzero(r)[0][0] if side < 0 else np.nonzero(r)[0][-1]) if r.any() else None for r in band]
            reach = [e for e in edge if e is not None]
            if not reach:
                continue
            far = min(reach) if side < 0 else max(reach)
            # The lowest rows that reach nearly as far out as the arm does.
            at = [y0 + i for i, e in enumerate(edge) if e is not None and abs(e - far) <= 1]
            if not at or abs(far - middle) < MIDDLE + 2:
                continue
            for y in range(max(at) - ARM_ROWS + 1, max(at) + 1):
                for x in (range(far, far + ARM_COLS) if side < 0 else range(far - ARM_COLS + 1, far + 1)):
                    if 0 <= x < F and a[y, x] and v[y, x] >= 0.25 and not boot[y, x]:
                        glove[y, x] = True
    # Each hand's cuff: the sleeve's end over it, a pixel wider each side, never the outline or skin.
    cuff = np.zeros((F, F), bool)
    band = np.zeros((F, F), bool)
    for cells in patches(glove):
        high = min(y for y, _ in cells)
        xs = [x for _, x in cells]
        for y in range(max(0, high - CUFF_ROWS), high):
            for x in range(max(0, min(xs) - 1), min(F, max(xs) + 2)):
                if a[y, x] and not skin[y, x] and v[y, x] >= 0.25:
                    cuff[y, x] = True
                    band[y, x] = y == high - CUFF_ROWS
    for y in range(F):
        for x in range(F):
            if boot[y, x]:
                out[y, x] = (*(BOOT_BAND if y == 0 or not boot[y - 1, x] else BOOT), 255)
            if glove[y, x] or cuff[y, x]:
                out[y, x] = (*(GLOVE_BAND if band[y, x] else GLOVE), 255)
    return out


def marks(body):
    sheet = np.asarray(Image.open(SPRITES / f"body_{body}.png").convert("RGBA")).astype(float) / 255
    out = np.zeros(sheet.shape, np.uint8)
    for row in range(sheet.shape[0] // F):
        for col in range(sheet.shape[1] // F):
            out[row * F:(row + 1) * F, col * F:(col + 1) * F] = mark_frame(
                sheet[row * F:(row + 1) * F, col * F:(col + 1) * F], DIRS[row % len(DIRS)], MITTS.get(body))
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--sheet", help="write a contact sheet here instead of the marks")
    args = parser.parse_args()
    names = bodies()
    if not args.sheet:
        for body in names:
            Image.fromarray(marks(body), "RGBA").save(SPRITES / f"marks_{body}.png")
        print(f"wrote art/sprites/marks_<body>.png for {', '.join(names)}")
        return
    zoom = 4
    sheet = Image.new("RGB", (16 * F * zoom, len(names) * F * zoom), (128, 128, 128))
    for r, body in enumerate(names):
        base = Image.open(SPRITES / f"body_{body}.png").convert("RGBA")
        base.alpha_composite(Image.fromarray(marks(body), "RGBA"))
        for k, row in enumerate((2, 1, 0, 3)):   # down, right, up, left
            strip = base.crop((0, row * F, 4 * F, (row + 1) * F)).resize((4 * F * zoom, F * zoom), Image.NEAREST)
            sheet.paste(strip, (k * 4 * F * zoom, r * F * zoom), strip)
    sheet.save(args.sheet)
    print(f"wrote {args.sheet}: {', '.join(names)}; down, right, up, left")


if __name__ == "__main__":
    main()
