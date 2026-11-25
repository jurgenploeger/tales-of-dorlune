#!/usr/bin/env python3
"""Lift a hairstyle off ChatGPT's painting of the doll wearing it (docs/ai-sprite-test/heroes/PROMPTS.md § 6).

  hero_hair.py lift <snapped.png> <doll view.png> <tag>
      -> hair_<tag>.png (the layer), on_<tag>.png (the doll wearing it) and <tag>_8x.png (doll, painting, layer, worn)

The painting is snapped first with hero_snap_walk.py --grid 1x1 --centre --hair 8 (the hair keeps its own ginger
shades) and thinned with hero_outline_thin.py. It is lined up with the doll by the body below the neck (the head is
under the hair). The layer is the hair as drawn: its saturated ginger pixels, joined into patches (under 5 pixels,
a blush, dropped), and the dark outline pixels touching them where the doll is clear there or differs. Nothing is
redrawn (the user's rule for ChatGPT's art, 2026-11-24)."""
import sys, colorsys
import numpy as np
from PIL import Image
from scipy import ndimage

def hairy(p):
    if p[3] == 0:
        return False
    h, s, v = colorsys.rgb_to_hsv(*(p[:3] / 255))
    return s >= 0.5 and v >= 0.3 and (h * 360 <= 50 or h * 360 >= 350)

def dark(p):
    return p[3] > 0 and p[:3].max() < 0.45 * 255

def align(S, M):
    """The shift (dy, dx) putting S's body below the neck (rows 36 to 60) over the doll's."""
    best = None
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            T = np.roll(np.roll(S, dy, 0), dx, 1)
            d = int(((T[36:61, :, 3] > 0) != (M[36:61, :, 3] > 0)).sum())
            if best is None or d < best[0]:
                best = (d, dy, dx)
    return best[1:]

def lift(S, M):
    dy, dx = align(S, M)
    S = np.roll(np.roll(S, dy, 0), dx, 1)
    hm = np.zeros(S.shape[:2], bool)
    for y in range(40):
        for x in range(64):
            hm[y, x] = hairy(S[y, x].astype(int))
    lab, n = ndimage.label(hm)
    for k in range(1, n + 1):
        if (lab == k).sum() < 5:
            hm[lab == k] = False
    near = ndimage.binary_dilation(hm, np.ones((3, 3), bool)) & ~hm
    for y, x in zip(*np.nonzero(near)):
        p = S[y, x].astype(int)
        if dark(p) and (M[y, x, 3] == 0 or (p != M[y, x]).any()):
            hm[y, x] = True
    layer = np.zeros_like(S); layer[hm] = S[hm]
    return layer, (dy, dx)

def worn(M, layer):
    out = Image.fromarray(M.copy()); out.alpha_composite(Image.fromarray(layer)); return np.asarray(out)

if __name__ == "__main__":
    if sys.argv[1] == "lift":
        S = np.asarray(Image.open(sys.argv[2]).convert("RGBA")); M = np.asarray(Image.open(sys.argv[3]).convert("RGBA"))
        tag = sys.argv[4]
        layer, sh = lift(S, M)
        W = worn(M, layer)
        Image.fromarray(layer).save(f"hair_{tag}.png"); Image.fromarray(W).save(f"on_{tag}.png")
        strip = Image.new("RGBA", (64 * 4, 64), (120, 170, 90, 255))
        for i, a in enumerate((M, np.roll(np.roll(S, sh[0], 0), sh[1], 1), layer, W)):
            strip.alpha_composite(Image.fromarray(a), (i * 64, 0))
        strip.resize((64 * 4 * 8, 512), Image.NEAREST).save(f"{tag}_8x.png")
        ys, xs = np.nonzero(layer[..., 3])
        head = np.nonzero(M[..., 3].any(1))[0].min()
        hx = np.nonzero(M[head:head + 20, :, 3].any(0))[0]
        print(tag, "shift", sh, "hair px", len(ys), "above head", head - ys.min(), "past sides", hx.min() - xs.min(), xs.max() - hx.max())


# ---- wearing a style on every frame -------------------------------------------------------------------------
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def style_view(style, d):
    """(standing view, hair layer) for a direction, a left one its right twin's mirrored; None if not drawn."""
    import hero_ears as he
    if d.endswith("left"):
        r = style_view(style, d[:-4] + "right")
        return None if r is None else (r[0][:, ::-1], r[1][:, ::-1])
    p = os.path.join(he.HEROES, f"hero64_hair_{style}_{d}.png")
    s = he.standing(d)
    return None if s is None or not os.path.exists(p) else (s, np.asarray(Image.open(p).convert("RGBA")))

def wear_style(style, anim, race="human"):
    """The doll's (or the elf's) sheet with the style on every frame of every direction drawn so far: the standing
    view's hair moved with the head (hero_ears.fit), over clear pixels and the head (hero_ears.wear: a raised arm
    stays in front); on the elf, its ears go back over the hair."""
    import hero_ears as he, hero_template as t
    n = t.ANIMS[anim]
    doll = np.asarray(Image.open(os.path.join(he.HEROES, f"hero64_doll_{anim}.png")).convert("RGBA"))
    elf = np.asarray(Image.open(os.path.join(he.HEROES, f"hero64_elf_{anim}.png")).convert("RGBA")) if race == "elf" else None
    out = (elf if elf is not None else doll).copy()
    for r, d in enumerate(t.DIRECTIONS):
        v = style_view(style, d)
        if v is None:
            continue
        ref, hair = v
        for c in range(n):
            sl = (slice(r * 64, (r + 1) * 64), slice(c * 64, (c + 1) * 64))
            f = doll[sl]
            if not f[..., 3].any():
                continue
            w = he.wear(f, hair, he.fit(f, ref), ref)
            if elf is not None:
                e = elf[sl]
                ear = (e[..., 3] > 0) & ((e != f).any(2))
                w = w.copy(); w[ear] = e[ear]
            out[sl] = w
    return out

if __name__ == "__main__" and sys.argv[1] == "wear":
    import hero_ears as he
    style = sys.argv[2]
    for race in ("human", "elf"):
        for anim, ms in (("idle", 250), ("walk", 90), ("attack", 110)):
            sheet = wear_style(style, anim, race)
            name = f"hero64_{race}_{style}_{anim}"
            Image.fromarray(sheet).save(os.path.join(he.HEROES, name + ".png"))
            he.gif(sheet, anim, os.path.join(he.HEROES, name + ".gif"), ms)
            print("wrote", name)
