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
