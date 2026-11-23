#!/usr/bin/env python3
"""The idle sheet for an approved hero body: 4 frames a direction, a slow breath (docs/ai-sprite-test/heroes).

Assembles the rows ChatGPT drew (hero64_<body>_idle_<direction>.png, 256 x 64), a left row its right twin
mirrored, into hero64_<body>_idle.png (256 x 512, rows clockwise from up) and its 4x. A direction with no row
of its own stays empty: the breath made in code (`breathe`, everything above the waistband and the arms a pixel
lower) left chopped pixels where moved and still columns met (the user, 2026-11-23), so every row is drawn.

  hero_idle.py human_male
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hero_template as t  # noqa: E402

HEROES = os.path.join(t.ROOT, "docs", "ai-sprite-test", "heroes")


def waist(view):
    """The first row of the shorts: the topmost row where grey (unsaturated, mid) pixels are most of the row."""
    a = np.array(view).astype(int)
    solid = a[..., 3] > 0
    rgb = a[..., :3]
    grey = solid & (rgb.max(-1) - rgb.min(-1) < 24) & (rgb.max(-1) > 70)
    for y in range(a.shape[0]):
        if grey[y].sum() >= 3:
            return y
    return a.shape[0] - 14


def breathe(view):
    """Everything above the waistband a pixel lower, and the arms and hands beside the shorts too (columns
    outside the shorts' width move whole, down to the hands' tips); the shorts, legs and feet stay."""
    a = np.array(view)
    w = waist(view)
    solid = a[..., 3] > 0
    ys = np.nonzero(solid)[0]
    band = np.nonzero(solid[w])[0]
    x0, x1 = band.min(), band.max()
    # the shorts' own columns: the waistband row, less any arm touching it (a grey run, its outline either side)
    rgb = a[w, :, :3].astype(int)
    grey = np.nonzero(solid[w] & (rgb.max(-1) - rgb.min(-1) < 24) & (rgb.max(-1) > 70))[0]
    if len(grey):
        x0, x1 = grey.min() - 1, grey.max() + 1
    rgb_all = a[..., :3].astype(int)
    grey_rows = np.nonzero((solid & (rgb_all.max(-1) - rgb_all.min(-1) < 24) & (rgb_all.max(-1) > 70)).sum(1) >= 3)[0]
    shorts_end = grey_rows.max() if len(grey_rows) else w     # the shorts' last row: hands reach no lower than a
    out = a.copy()                                            # couple of rows past it, the legs below it stay
    for x in range(a.shape[1]):
        col = np.nonzero(solid[:, x])[0]
        if not len(col):
            continue
        cut = w
        if not x0 <= x <= x1:            # an arm: down to where its hand ends (feet and legs stay put)
            cut = w
            while cut < a.shape[0] and solid[cut, x]:
                cut += 1
            cut = min(cut + 1, a.shape[0], shorts_end + 3)
        top = col.min()
        out[top + 1:cut, x] = a[top:cut - 1, x]
        out[top, x] = 0
    return Image.fromarray(out)


def sheet(body):
    im = Image.new("RGBA", (t.FRAME * 4, t.FRAME * len(t.DIRECTIONS)), (0, 0, 0, 0))
    for r, d in enumerate(t.DIRECTIONS):
        drawn = os.path.join(HEROES, f"hero64_{body}_idle_{d}.png")
        if os.path.exists(drawn):
            im.alpha_composite(Image.open(drawn).convert("RGBA"), (0, r * t.FRAME))
            continue
        if d.endswith("left"):
            twin = os.path.join(HEROES, f"hero64_{body}_idle_{d[:-4]}right.png")
            if os.path.exists(twin):
                row = Image.open(twin).convert("RGBA")
                for c in range(4):    # each frame mirrored in place, so the frames keep their order
                    f = row.crop((c * t.FRAME, 0, (c + 1) * t.FRAME, t.FRAME)).transpose(Image.FLIP_LEFT_RIGHT)
                    im.paste(f, (c * t.FRAME, r * t.FRAME))
    return im


if __name__ == "__main__":
    body = sys.argv[1] if len(sys.argv) > 1 else "human_male"
    s = sheet(body)
    s.save(os.path.join(HEROES, f"hero64_{body}_idle.png"))
    s.resize((s.width * 4, s.height * 4), Image.NEAREST).save(os.path.join(HEROES, f"hero64_{body}_idle_4x.png"))
    # how close the shift comes to what ChatGPT drew, where it drew a row
    drawn = os.path.join(HEROES, f"hero64_{body}_idle_down.png")
    if os.path.exists(drawn):
        mine = np.array(breathe(t.approved(body, "down"))).astype(int)
        theirs = np.array(Image.open(drawn).convert("RGBA")).astype(int)[:, 64:128]
        print("down, frame 2: the shift and ChatGPT's drawing differ in", int((np.abs(mine - theirs).sum(2) > 0).sum()), "pixels")
    print("wrote", f"hero64_{body}_idle.png")
