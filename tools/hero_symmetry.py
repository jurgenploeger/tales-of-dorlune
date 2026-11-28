#!/usr/bin/env python3
"""Is a hero's front or back view even? (docs/ai-sprite-test/heroes/HANDOVER.md, Acceptance)

A front or back view of the base body mirrors across its middle column in shape and in its dark lines (outline,
brows, eyes, mouth); only the shading differs, as the light comes from the top left. ChatGPT's frames drift a pixel
here and there (try 7: a brow 2 pixels on one side and 3 on the other, a foot missing its outline).

  hero_symmetry.py check <png>               list every pixel whose mirror differs; exits 1 if any
  hero_symmetry.py fix <png> [--side right]  mirror the left half's shape and lines onto the right (or the right's
                                             onto the left), each pixel it changes taking the nearest plain shade on
                                             its own side of its row, so the lighting stays; writes <name>_sym.png
                                             and <name>_sym_8x.png

"Dark" is a pixel whose brightest channel is under 0.35, the outline and the face's lines.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

DARK = 0.35


def load(path):
    return np.array(Image.open(path).convert("RGBA")).astype(int)


def axis(a):
    xs = np.nonzero(a[..., 3])[1]
    return xs.min() + xs.max()          # x mirrors to axis - x


def dark(a):
    return (a[..., 3] > 0) & (a[..., :3].max(-1) / 255 < DARK)


def where(y, top, bottom):
    t = (y - top) / max(1, bottom - top)
    return "head" if t < 0.42 else "body" if t < 0.75 else "legs"


def differences(a):
    s = axis(a)
    solid, line = a[..., 3] > 0, dark(a)
    ys = np.nonzero(solid)[0]
    top, bottom = ys.min(), ys.max()
    out = []
    for y in range(a.shape[0]):
        for x in range(a.shape[1]):
            m = s - x
            if m <= x or not (0 <= m < a.shape[1]):
                continue
            if solid[y, x] != solid[y, m]:
                out.append((y, x, m, "shape", where(y, top, bottom)))
            elif solid[y, x] and line[y, x] != line[y, m]:
                out.append((y, x, m, "line", where(y, top, bottom)))
    return out


def plain_near(a, y, x, side_lo, side_hi):
    """The nearest solid, not dark pixel in row y between columns side_lo and side_hi."""
    line = dark(a)
    best = None
    for d in range(1, a.shape[1]):
        for c in (x - d, x + d):
            if side_lo <= c <= side_hi and a[y, c, 3] > 0 and not line[y, c]:
                best = a[y, c].copy()
                break
        if best is not None:
            break
    return best


def edge(a, y, x):
    """Next to a clear pixel (or the canvas edge): an outline pixel."""
    h, w = a.shape[:2]
    return any(not (0 <= y + dy < h and 0 <= x + dx < w) or a[y + dy, x + dx, 3] == 0
               for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)))


def fix(a, side="left"):
    """Even out every difference `differences` finds:
    - the face (lines in the head that aren't its outline): the kept side's rows mirrored whole, eyes, brows and
      mouth with their whites and irises, so both eyes are one drawing;
    - the outline anywhere: the kept side's;
    - a stray line inside the body or legs (not the outline) on one side only: taken out on both, as a seam
      ChatGPT left (try 7's left shin), the pixel taking its row's nearest plain shade on its own side."""
    s = axis(a)
    w = a.shape[1]
    out = a.copy()
    keep_right = side == "right"
    half = lambda x: (x > s - x)          # True on the right of the middle
    face_rows = {y for y, x, m, kind, part in differences(a)
                 if part == "head" and kind == "line" and not edge(a, y, x) and not edge(a, y, m)}
    for y, x, m, kind, part in differences(a):
        src, dst = (m, x) if keep_right else (x, m)    # x is always the left one
        lo, hi = ((s // 2) + 1, w - 1) if half(dst) else (0, (s - 1) // 2)
        if kind == "shape" or edge(a, y, x) or edge(a, y, m):
            out[y, dst] = a[y, src]
        elif part == "head":
            pass                                       # the whole row below
        else:
            for c in (x, m):
                if dark(a)[y, c]:
                    near = plain_near(a, y, c, *(((s // 2) + 1, w - 1) if half(c) else (0, (s - 1) // 2)))
                    if near is not None:
                        out[y, c] = near
    for y in face_rows:
        for x in range(w):
            m = s - x
            if 0 <= m < w and m != x and half(x) != keep_right and a[y, m, 3] and a[y, x, 3] \
                    and not edge(a, y, x) and not edge(a, y, m):
                out[y, x] = a[y, m]
    return out


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("command", choices=["check", "fix"])
    p.add_argument("png")
    p.add_argument("--side", choices=["left", "right"], default="left", help="the side to keep (fix)")
    args = p.parse_args()
    a = load(args.png)
    if args.command == "fix":
        b = fix(a, args.side)
        base = os.path.splitext(args.png)[0]
        Image.fromarray(b.astype(np.uint8)).save(base + "_sym.png")
        Image.fromarray(b.astype(np.uint8)).resize((b.shape[1] * 8, b.shape[0] * 8), Image.NEAREST).save(base + "_sym_8x.png")
        print(f"wrote {base}_sym.png; {len(differences(b))} differences left (was {len(differences(a))})")
        return
    diffs = differences(a)
    s = axis(a)
    print(f"{args.png}: middle column {s / 2:g}, {len(diffs)} pixels differ from their mirror")
    for y, x, m, kind, part in diffs:
        print(f"   row {y:2d}  columns {x:2d} / {m:2d}  {kind:5}  {part}")
    sys.exit(1 if diffs else 0)


if __name__ == "__main__":
    main()
