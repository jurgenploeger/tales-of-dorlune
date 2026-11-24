#!/usr/bin/env python3
"""An approved hero body's animation sheet from the rows ChatGPT drew (docs/ai-sprite-test/heroes).

Assembles hero64_<body>_<anim>_<direction>.png (a row: idle 4 frames, walk 8, attack 6, each 64 x 64), a
left row its right twin mirrored frame by frame, into hero64_<body>_<anim>.png (rows clockwise from up) and its
4x. A direction with no row of its own stays empty: the idle's breath made in code (`breathe`, everything above
the waistband and the arms a pixel lower) left chopped pixels where moved and still columns met (the user,
2026-11-23), so every row is drawn.

  hero_idle.py human_male              the idle sheet
  hero_idle.py human_male walk --gif   the walk sheet, and hero64_<body>_walk.gif: the rows there are, at 4x
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


GIF_MS = {"idle": 300, "walk": 83, "attack": 110}


def rows(body, anim):
    """Each direction's row as drawn, or mirrored from its right twin; None where there's neither."""
    n = t.ANIMS[anim]
    out = {}
    for d in t.DIRECTIONS:
        drawn = os.path.join(HEROES, f"hero64_{body}_{anim}_{d}.png")
        if os.path.exists(drawn):
            out[d] = Image.open(drawn).convert("RGBA")
            continue
        twin = os.path.join(HEROES, f"hero64_{body}_{anim}_{d[:-4]}right.png") if d.endswith("left") else None
        if twin and os.path.exists(twin):
            row, im = Image.open(twin).convert("RGBA"), Image.new("RGBA", (t.FRAME * n, t.FRAME), (0, 0, 0, 0))
            for c in range(n):    # each frame mirrored in place, so the frames keep their order
                im.paste(row.crop((c * t.FRAME, 0, (c + 1) * t.FRAME, t.FRAME)).transpose(Image.FLIP_LEFT_RIGHT),
                         (c * t.FRAME, 0))
            out[d] = im
    return out


def gif(body, anim, path):
    """Every row there is, side by side in the sheet's order, playing at 4x on white."""
    got = [r for d, r in rows(body, anim).items()]
    n, f = t.ANIMS[anim], t.FRAME
    frames = []
    for c in range(n):
        im = Image.new("RGBA", (f * len(got), f), (255, 255, 255, 255))
        for i, r in enumerate(got):
            im.alpha_composite(r.crop((c * f, 0, (c + 1) * f, f)), (i * f, 0))
        frames.append(im.convert("RGB").resize((im.width * 4, im.height * 4), Image.NEAREST))
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=GIF_MS[anim], loop=0)


def sheet(body, anim="idle"):
    im = Image.new("RGBA", (t.FRAME * t.ANIMS[anim], t.FRAME * len(t.DIRECTIONS)), (0, 0, 0, 0))
    got = rows(body, anim)
    for r, d in enumerate(t.DIRECTIONS):
        if d in got:
            im.alpha_composite(got[d], (0, r * t.FRAME))
    return im


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    body = args[0] if args else "human_male"
    anim = args[1] if len(args) > 1 else "idle"
    s = sheet(body, anim)
    s.save(os.path.join(HEROES, f"hero64_{body}_{anim}.png"))
    s.resize((s.width * 4, s.height * 4), Image.NEAREST).save(os.path.join(HEROES, f"hero64_{body}_{anim}_4x.png"))
    if "--gif" in sys.argv:
        gif(body, anim, os.path.join(HEROES, f"hero64_{body}_{anim}.gif"))
    print("wrote", f"hero64_{body}_{anim}.png", "rows:", ", ".join(rows(body, anim)))
