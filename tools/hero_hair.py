#!/usr/bin/env python3
"""Lift a hairstyle off ChatGPT's painting of the doll wearing it (docs/ai-sprite-test/heroes/PROMPTS.md § 6).

  hero_hair.py lift <snapped.png> <doll view.png> <tag>
      -> hair_<tag>.png (the layer), on_<tag>.png (the doll wearing it) and <tag>_8x.png (doll, painting, layer, worn)

The painting is snapped first with hero_snap_walk.py --grid 1x1 --centre --hair 8 (the hair keeps its own ginger
shades) and thinned with hero_outline_thin.py. It is lined up with the doll by the body below the neck (the head is
under the hair). The layer is the hair as drawn: its saturated ginger pixels, joined into patches (under 5 pixels,
a blush, dropped), and the dark outline pixels touching them where the doll is clear there or differs. Nothing is
redrawn (the user's rule for ChatGPT's art, 2026-11-24)."""
import sys, os, colorsys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
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
    for y in range(64):       # the whole frame: long hair reaches the shoulders and back
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
    if sys.argv[1] == "lift-row":   # hero_hair.py lift-row <snapped row.png> <anim> <direction> <out.png>
        import hero_ears as he, hero_template as t
        S = np.asarray(Image.open(sys.argv[2]).convert("RGBA")); anim, d = sys.argv[3], sys.argv[4]
        D = np.asarray(Image.open(os.path.join(he.HEROES, f"hero64_doll_{anim}_{d}.png")).convert("RGBA"))
        out = np.zeros_like(D)
        for c in range(t.ANIMS[anim]):
            layer, sh = lift(S[:, c * 64:(c + 1) * 64], D[:, c * 64:(c + 1) * 64])
            out[:, c * 64:(c + 1) * 64] = layer
            print("frame", c + 1, "shift", sh, "hair px", int((layer[..., 3] > 0).sum()))
        Image.fromarray(out).save(sys.argv[5])
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

def row_hair(style, anim, d):
    """A row's own hair, frame by frame (hero64_hair_<style>_<anim>_<direction>.png, lifted from ChatGPT's repaint of
    that row with the hair: long hair hanging past the head showed gaps laid on as the standing view's, the user,
    2026-11-26), a left row its right twin's mirrored frame by frame; None if not drawn."""
    import hero_ears as he, hero_template as t
    if d.endswith("left"):
        r = row_hair(style, anim, d[:-4] + "right")
        if r is None:
            return None
        n = t.ANIMS[anim]
        return np.concatenate([r[:, c * 64:(c + 1) * 64][:, ::-1] for c in range(n)], 1)
    p = os.path.join(he.HEROES, f"hero64_hair_{style}_{anim}_{d}.png")
    return np.asarray(Image.open(p).convert("RGBA")) if os.path.exists(p) else None

def wear_hair(frame, hair, shift, ref):
    """hero_ears.wear for hair: over clear pixels and over the head, the standing view's head grown by a pixel, as
    a walk frame's head can stand a pixel past the standing view's and its outline showed through the hair (facing
    right, 2026-11-25); an arm raised past the head stays in front."""
    import hero_ears as he
    grown = ref.copy()
    grown[..., 3] = np.where(ndimage.binary_dilation(ref[..., 3] > 0, np.ones((3, 3), bool)), 255, 0)
    return he.wear(frame, hair, shift, grown)

def clip_front(w, base, f, hair, sh, ref, d):
    """Facing right (and down-right; left ones mirrored) a walk frame's face can stand a pixel or two forward of the
    standing view's, and the fringe moved with the head covered its brow and nose (the user, 2026-11-25): in each
    row where the standing hair stops short of the face's front, it stops as far short of this frame's face."""
    if d not in ("right", "down-right", "left", "down-left"):
        return w
    sgn = 1 if d.endswith("right") else -1
    def front(mask_row):
        xs = np.nonzero(mask_row)[0]
        return None if not len(xs) else (xs.max() if sgn > 0 else xs.min())
    dy, dx = sh
    w = w.copy()
    for yr in range(64):
        y = yr + dy
        if not (0 <= y < 64):
            continue
        rf, hf, ff = front(ref[yr, :, 3] > 0), front(hair[yr, :, 3] > 0), front(f[y, :, 3] > 0)
        if rf is None or hf is None or ff is None or (hf - rf) * sgn >= 0:
            continue
        limit = ff - (rf - hf)
        for x in range(64):
            if hair[yr, x - dx, 3] if 0 <= x - dx < 64 else False:
                if (x - limit) * sgn > 0:
                    w[y, x] = base[y, x]
    return w

def real_ear(diff, f, dark=None):
    """Of the pixels where the elf differs from the doll, the ear: those in rows where some stand 2 or more pixels
    past the doll's head."""
    # only in the rows where the ear stands out past the head: below them (the nape facing right) the elf's own
    # head pixels laid over the hair showed as skin under the ear (the user, 2026-11-25)
    far = ~ndimage.binary_dilation(f[..., 3] > 0, np.ones((3, 3), bool))
    # near what stands past the head: up to 7 pixels in along its row and a row above and below (its own
    # outline along its top and bottom; facing right the hair covered its top edge, the user, 2026-11-25), not
    # the whole row, where ChatGPT's head shaded otherwise showed through the hair as skin
    zone = ndimage.binary_dilation(diff & far, np.ones((1, 15), bool))
    # the row above and below only for the ear's dark outline: its skin there was ChatGPT's head showing
    # through the hair as patches above the ear
    edge = ndimage.binary_dilation(diff & far, np.ones((3, 15), bool)) & dark
    # (not every pixel past the doll: the elf painting's own head outline stood a pixel out round the crown, and
    # laid over long hair it showed as dark specks at its top, the user, 2026-11-26)
    return diff & (zone | edge)

def ear_through(diff, f, worn, reach=3):
    """The ear where it lies over the hair's outer pixels: the elf's pixels joined to what stands past the doll's
    head, over the hair only up to `reach` pixels in from its outside edge. Long hair covering the ear's root ended
    it in a straight line along the hair's edge (the user, 2026-11-26); taken all the way through the hair, the ear
    grew out of the cheek."""
    far = ~ndimage.binary_dilation(f[..., 3] > 0, np.ones((3, 3), bool))
    seed = diff & far
    if not seed.any():
        return np.zeros_like(diff)
    rows = np.nonzero(seed.any(1))[0]
    band = np.zeros_like(diff); band[max(rows.min() - 1, 0):rows.max() + 2] = True
    lab, _ = ndimage.label(diff & band)
    ear = np.isin(lab, [i for i in np.unique(lab[seed]) if i])
    hair = (worn != f).any(2)
    inside = ndimage.distance_transform_cdt(worn[..., 3] > 0, metric="chessboard")
    return ear & (~hair | (inside <= reach))

def lone_specks(img):
    """Opaque pixels with no opaque neighbour, cleared."""
    a = img[..., 3] > 0
    nb = ndimage.convolve(a.astype(int), np.ones((3, 3), int), mode="constant") - a
    out = img.copy(); out[a & (nb == 0)] = 0
    return out

def head_shift(f, ref, anim):
    """How far a frame's head moved from the standing view's. Idle and walk (and so run): its top row, and the middle
    of its top 14 rows, as hero_ears.fit, the best match of the head's colours, jumped a pixel or two between walk
    frames whose heads ChatGPT drew a little differently, and the hair wobbled (the user, 2026-11-25). The attack keeps
    the fit: its fist reaches the head's rows and top."""
    import hero_ears as he
    if anim == "attack":
        return he.fit(f, ref)
    def top_mid(img):
        rows = np.nonzero(img[..., 3].any(1))[0]
        t = int(rows.min())
        xs = [np.nonzero(img[y, :, 3])[0] for y in range(t, t + 14)]
        return t, float(np.mean([(x.min() + x.max()) / 2 for x in xs if len(x)]))
    ft, fm = top_mid(f); rt, rm = top_mid(ref)
    return ft - rt, int(np.floor(fm - rm + 0.5))

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
        own = row_hair(style, anim, d)
        for c in range(n):
            sl = (slice(r * 64, (r + 1) * 64), slice(c * 64, (c + 1) * 64))
            f = doll[sl]
            if not f[..., 3].any():
                continue
            if own is not None:
                # the row's own hair, lifted from this very frame: laid where it was drawn (its own frame the
                # standing view, so it may go over the body, as painted)
                ref, hair = f, own[:, c * 64:(c + 1) * 64]
            # on the elf the hair goes over the elf's frame: the walk and attack ears layers carry ChatGPT's own
            # head pixels round the ears, and laid back over the hair they showed through it as skin and specks
            # (the user, 2026-11-25)
            sh = (0, 0) if own is not None else head_shift(f, ref, anim)
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
            w = clip_front(w, elf[sl] if elf is not None else f, f, hair, sh, ref, d)
            if elf is not None:
                # from the ears' top row down (the standing view's ears, moved with the head), the ears stay over
                # the hair: the sideburns crossed their roots and, facing down-right, the hair at the back of the
                # head flapped over the near ear (the user, 2026-11-25); above it the hair still covers ChatGPT's
                # head pixels round the ears
                e = elf[sl]
                diff = (e[..., 3] > 0) & ((e != f).any(2))
                ear = real_ear(diff, f, e[..., :3].max(2) < 110) | ear_through(diff, f, wear_hair(f, hair, sh, ref))
                top = ear_top(d)
                # from behind (up, up-right, up-left) the ears layer lies over the back of the head: there the hair
                # goes over it and only what stands out past the head shows (2026-11-25)
                if top is not None and not d.startswith("up"):
                    # the ear's rows (`real_ear`), not a band from the standing view's ear top: a walk frame's ear
                    # can start higher, and the hair covered its top edge (the user, 2026-11-25)
                    keep = ear
                    w = w.copy(); w[keep] = e[keep]
            out[sl] = lone_specks(w)
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
