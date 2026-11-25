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

SAT = 0.5          # lift --sat: lower for a painting already in calm colours (it stays above the skin's 0.45)

def hairy(p):
    if p[3] == 0:
        return False
    h, s, v = colorsys.rgb_to_hsv(*(p[:3] / 255))
    # hue 12 and up: a reddish inner ear is as saturated as the hair (it came off with the hair facing up-right)
    return s >= SAT and v >= 0.3 and 12 <= h * 360 <= 50

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
    return (layer if NO_GRADE else grade(layer)), (dy, dx)

# ChatGPT paints the hair a very saturated ginger (asked for, so it parts from the skin), and every hair colour is
# worked from it: too bright and unnatural (the user, 2026-11-25). The lifted layer is graded once, the user's pick B
# of three: saturation x0.72, brightness x0.9, hue 4 degrees toward red (copper). Still inside appearance.json's
# hairLayer window, so the game's colours all reach it.
GRADE = (0.72, 0.9, -4)

def grade(layer, g=GRADE):
    sm, vm, dh = g
    out = layer.copy()
    for y, x in zip(*np.nonzero(layer[..., 3])):
        h, s, v = colorsys.rgb_to_hsv(*(layer[y, x, :3] / 255))
        r, gg, b = colorsys.hsv_to_rgb(((h * 360 + dh) % 360) / 360, min(1, s * sm), min(1, v * vm))
        out[y, x, :3] = np.round(np.array([r, gg, b]) * 255).astype(np.uint8)
    return out

def worn(M, layer):
    out = Image.fromarray(M.copy()); out.alpha_composite(Image.fromarray(layer)); return np.asarray(out)

NO_GRADE = False
if __name__ == "__main__":
    if "--no-grade" in sys.argv:    # ChatGPT painted it in the toned-down colours already: grading again dulled it
        NO_GRADE = True; sys.argv.remove("--no-grade")
    if "--sat" in sys.argv:
        i = sys.argv.index("--sat"); SAT = float(sys.argv[i + 1]); del sys.argv[i:i + 2]
    if sys.argv[1] == "grade":     # grade a layer lifted before GRADE: hero_hair.py grade <in.png> <out.png>
        Image.fromarray(grade(np.asarray(Image.open(sys.argv[2]).convert("RGBA")))).save(sys.argv[3])
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

def wear_hair(frame, hair, shift, ref):
    """hero_ears.wear for hair: over clear pixels and over the head, the standing view's head grown by a pixel, as
    a walk frame's head can stand a pixel past the standing view's and its outline showed through the hair (facing
    right, 2026-11-25); an arm raised past the head stays in front."""
    import hero_ears as he
    grown = ref.copy()
    grown[..., 3] = np.where(ndimage.binary_dilation(ref[..., 3] > 0, np.ones((3, 3), bool)), 255, 0)
    return he.wear(frame, hair, shift, grown)

def ear_top(d):
    """The top row of the elf's ears in a direction's standing view (hero64_doll_ears_<direction>.png), or None."""
    import hero_ears as he
    v = he.view(d)
    if v is None:
        return None
    rows = np.nonzero(v[1][..., 3].any(1))[0]
    return int(rows.min()) if len(rows) else None

def wear_style(style, anim, race="human"):
    """The doll's (or the elf's) sheet with the style on every frame of every direction drawn so far: the standing
    view's hair moved with the head (hero_ears.fit), over clear pixels and the head (hero_ears.wear: a raised arm
    stays in front); on the elf, over the elf's frame, so the hair covers the ears' roots."""
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
            # on the elf the hair goes over the elf's frame: the walk and attack ears layers carry ChatGPT's own
            # head pixels round the ears, and laid back over the hair they showed through it as skin and specks
            # (the user, 2026-11-25)
            sh = he.fit(f, ref)
            if elf is not None and d.startswith("up"):
                # from behind the hair goes over the ears wherever it lies (laid over the elf's frame, the ears'
                # pixels where the head is clear showed through it as lines, the user, 2026-11-25); the elf shows
                # wherever no hair went
                w0 = wear_hair(f, hair, sh, ref)
                bare = (w0 == f).all(2)
                w = w0.copy(); w[bare] = elf[sl][bare]
                out[sl] = w
                continue
            w = wear_hair(elf[sl] if elf is not None else f, hair, sh, ref)
            if elf is not None:
                # from the ears' top row down (the standing view's ears, moved with the head), the ears stay over
                # the hair: the sideburns crossed their roots and, facing down-right, the hair at the back of the
                # head flapped over the near ear (the user, 2026-11-25); above it the hair still covers ChatGPT's
                # head pixels round the ears
                e = elf[sl]
                ear = (e[..., 3] > 0) & ((e != f).any(2))
                top = ear_top(d)
                # from behind (up, up-right, up-left) the ears layer lies over the back of the head: there the hair
                # goes over it and only what stands out past the head shows (2026-11-25)
                if top is not None and not d.startswith("up"):
                    band = np.zeros_like(ear); band[max(top + sh[0], 0):] = True
                    keep = ear & band
                    w = w.copy(); w[keep] = e[keep]
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
