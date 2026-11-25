#!/usr/bin/env python3
"""Snow and ice, previewed before they go into the game (the user, 2026-11-25, pointing to SpriteCook's
"2D pixel art snow and ice": "Can we apply this? Maybe nice for areas that go from one map to another. Also
the lakes/rivers/ponds should have ice").

The article bakes, once, a stage for every pixel (when snow lands on it) and a tone (which of a few snow
colours it takes), and a shader shows every pixel whose stage has come, in hard steps, never a fade. Two uses:

1. Where a green land meets a snowy one (Swan Lake into Snow White Forest): today the seam swaps whole
   cells of grass for snow in patches (`Seam.swift`). Here the green land's own ground is snowed over pixel by
   pixel as it nears the border: stage 1 (a few clusters), 2, 3, 4 (all of it) by how far in, the ground's
   own dark crevices last to go, and the trees' tops capped as their stage comes (`caps`).
2. Ice on a cold land's lakes (Briarmere's): from the shore out (`freeze`, 0 open, 1 frozen over), each pixel
   one of five ice tones a step lighter than the water under it, a light rim along open water, static glare
   streaks, snow drifted on the ice by the shore, and cracks once it's nearly frozen over.

The article's own rules (its palettes, blob/ring/hole clusters, specks, cap depths and ranks, ice tones,
glare and cracks) are followed; screen pixels stand for the art's (the game's are 44/32 points).

    python3 tools/snow_ice_preview.py out.png     # the border (plain | snowed) over the lake at three freezes

Needs pillow, numpy, scipy.
"""
import math
import pathlib
import random
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import palette_preview as pp  # noqa: E402
import pond_preview as pond  # noqa: E402

SNOW = np.array([[0x54, 0x60, 0x88], [0x80, 0x90, 0xba], [0xb8, 0xc6, 0xe4], [0xe2, 0xe9, 0xf7], [0xf8, 0xfa, 0xff]]) / 255
ICE = np.array([[0x42, 0x62, 0x80], [0x68, 0x90, 0xac], [0x92, 0xba, 0xce], [0xbe, 0xdc, 0xe9], [0xea, 0xf6, 0xfb]]) / 255


def bright(rgb):
    return 0.3 * rgb[..., 0] + 0.59 * rgb[..., 1] + 0.11 * rgb[..., 2]


def noise(shape, rng, size):
    """Smoothed noise, mean 0, spread about 1."""
    n = ndimage.uniform_filter(rng.standard_normal(shape), size)
    return n / max(n.std(), 1e-6)


def tones(b, lo_q=5, hi_q=97, mask=None):
    """Each pixel's snow tone 0..4 by its brightness between the ground's lo and hi percentiles."""
    vals = b[mask] if mask is not None else b.ravel()
    lo, hi = np.percentile(vals, lo_q), np.percentile(vals, hi_q)
    return np.clip(np.floor((b - lo) / max(hi - lo, 1e-6) * 5), 0, 4).astype(int)


def ground_stages(rgb, mask, rng):
    """The article's ground bake: a stage 1..4 for every ground pixel (0 off it). Stage 1 a few clusters,
    2 more, 3 most of it, 4 the rest (the darkest crevices last)."""
    h, w = mask.shape
    b = bright(rgb) * 255
    m = ndimage.uniform_filter(b, 3)
    gy, gx = np.gradient(m)
    edge = np.clip(np.hypot(gx, gy) / 2 / 20, 0, 1)
    nz = 0.28 * noise((h, w), rng, 3) + 0.12 * noise((h, w), rng, 5)

    def field(count, rmin, rmax):
        ys, xs = np.nonzero(mask)
        pick = rng.choice(len(ys), size=min(count, len(ys)), replace=False)
        best = np.full((h, w), 1e9)
        yy, xx = np.mgrid[0:h, 0:w]
        for k in pick:
            r = rng.uniform(rmin, rmax) * 2.2      # the art's pixels are about 1.4 of ours and blobs read small
            d = np.hypot(yy - ys[k], xx - xs[k]) / r
            best = np.minimum(best, d)
        return best + nz * 0.35

    def blob(dn, chance, holes):
        core = dn <= 1
        ring = (dn > 1) & (dn < 1.9) & (rng.random((h, w)) < chance * (1.9 - dn) / 0.9)
        darker = b < m - 2
        hole = core & darker & (rng.random((h, w)) < holes)
        return (core | ring) & ~hole, hole

    scale = (h * w) / (320 * 180)
    d1 = field(int(55 * scale), 0.7, 2.6)
    d2 = field(int(90 * scale), 0.8, 2.8)
    d3 = field(int(160 * scale), 1.0, 3.2)
    stage = np.zeros((h, w), int)
    s3, h3 = blob(np.minimum(np.minimum(d1 / 2.6, d2 / 1.9), d3), 0.32, 0.15)
    s3 |= (edge < 0.45) & (rng.random((h, w)) < 0.35)
    s2, h2 = blob(np.minimum(d1 / 1.8, d2), 0.32, 0.22)
    s2 |= rng.random((h, w)) < 0.012
    s1, h1 = blob(d1, 0.38, 0.22)
    s1 |= rng.random((h, w)) < 0.004
    stage[s3] = 3
    stage[s2] = 2
    stage[s1] = 1
    stage[h1 & (stage == 1)] = 2
    stage[h2 & (stage == 2)] = 3
    stage[(stage == 0)] = 4
    stage[~mask] = 0
    return stage


def caps(s, rng, depth=4.5):
    """The article's caps on a sprite (float RGBA): a stage 1..3 for each of its top surfaces' pixels, `depth`
    rows down from where each column starts (or a lit clump starts under a dark gap), only on pixels above a
    tenth of its brightness range (its dark outline and shaded side stay)."""
    a = s[..., 3] > 0.5
    h, w = a.shape
    b = bright(s[..., :3]) * 255
    if not a.any():
        return np.zeros((h, w), int)
    lo, hi = np.percentile(b[a], 10), np.percentile(b[a], 95)
    lit = a & (b > lo + 0.1 * (hi - lo))
    nz = noise((h, w), rng, 3)
    cand = np.zeros((h, w), bool)
    dep = np.zeros((h, w))
    for x in range(w):
        col = np.nonzero(a[:, x])[0]
        if not len(col):
            continue
        starts = [col[0]]
        for y in range(col[0] + 2, h):
            if a[y, x] and b[y, x] - b[y - 2, x] > 28:
                starts.append(y)
        for y0 in starts:
            for k in range(int(depth)):
                y = y0 + k
                if y < h and lit[y, x]:
                    cand[y, x] = True
                    dep[y, x] = k / depth
    out = np.zeros((h, w), int)
    ys, xs = np.nonzero(cand)
    if not len(ys):
        return out
    rank = 0.35 * dep[ys, xs] + 0.25 * (1 - (b[ys, xs] - lo) / max(hi - lo, 1)) + 0.40 * (nz[ys, xs] * 0.25 + 0.5)
    order = np.argsort(rank)
    n = len(order)
    for i, k in enumerate(order):
        out[ys[k], xs[k]] = 1 if i < 0.22 * n else 2 if i < 0.58 * n else 3
    return out


def land_snow(mid):
    """Five snow tones from a snowy land's own snow tile, graded as it is there, dark to light."""
    m = pp.maps[mid]
    tile = pp.grade(pp.raw(m['theme']['ground']), m['theme'].get('palette'))[..., :3].reshape(-1, 3)
    b = bright(tile)
    order = np.argsort(b)
    return np.array([tile[order[int(q * (len(order) - 1))]] for q in (0.04, 0.25, 0.5, 0.75, 0.97)])


def border(out_w=420, out_h=300):
    """Swan Lake's grass running into Snow White Forest: the right of the picture is the border."""
    mid = "swan_lake"
    rng = np.random.default_rng(5)
    r = random.Random(2)
    n = 18
    kinds = [['g'] * n for _ in range(n)]
    for k in range(n):
        kinds[k][9] = 'p'
    m = pp.maps[mid]
    tall = [p for p in m['theme']['props'] if 'tree' in p['art'] and not p.get('within')]
    low = [p for p in m['theme']['props'] if 'bush' in p['art'] and not p.get('within')]
    items = []
    for _ in range(34):
        c, rr = r.randrange(n), r.randrange(n)
        if kinds[rr][c] != 'g':
            continue
        p = r.choice(tall if r.random() < 0.65 else (low or tall))
        lo, hi = p.get('size', [1, 1])
        items.append((p['art'], c, rr, r.uniform(lo, hi)))
    W, H = out_w, out_h

    wave = noise((H, W), np.random.default_rng(11), 41)

    def front(x, y):
        """How far into the snow, 0 at the picture's left third to 1 near its right edge (the border), the
        line between them wandering."""
        xi = np.clip(np.asarray(x).astype(int), 0, W - 1)
        yi = np.clip(np.asarray(y).astype(int), 0, H - 1)
        return np.clip((x - W * 0.28) / (W * 0.6) + 0.12 * wave[yi, xi], 0, 1)

    snow = land_snow("snow_white_forest")

    def shade(img, drawn, props, palette):
        rgb = img[..., :3].copy()
        mask = np.ones(rgb.shape[:2], bool)
        stage = ground_stages(rgb, mask, rng)
        tone = tones(bright(rgb), mask=mask)
        ys, xs = np.mgrid[0:H, 0:W]
        # Each pixel's place in the order snow comes: its stage, and within it a smooth noise, so a stage
        # spreads out from its clusters over a stretch of ground instead of switching on along a line.
        within = np.clip(noise((H, W), rng, 9) * 0.22 + 0.5, 0, 0.999)
        order = (stage - 1 + within) / 4
        on = (stage > 0) & (order < front(xs, ys))
        img[..., :3] = np.where(on[..., None], snow[tone], img[..., :3])
        for k, (art, s, x0, y0, w, h, walker, pad) in enumerate(drawn):
            if walker:
                continue
            cap = caps(s, rng, depth=4.5 if 'tree' in art else 3)
            sh = min(3, int(front(x0 + w / 2, y0 + h) * 3.999))
            if sh <= 0:
                continue
            a = s[..., 3] > 0.5
            t = tones(bright(s[..., :3]), 10, 95, a)
            hit = (cap > 0) & (cap <= sh)
            s[..., :3] = np.where(hit[..., None], snow[np.clip(t + 1, 0, 4)], s[..., :3])

    plain = pp.draw_scene(mid, m['theme'].get('palette'), kinds, items, W, H)
    snowed = pp.draw_scene(mid, m['theme'].get('palette'), kinds, items, W, H, shade=shade)
    return plain, snowed


def lake(freezes, out_w=420, out_h=300):
    """Briarmere's lake at each freeze."""
    mid = "rosen_lake"
    m = pp.maps[mid]
    kinds, items = pond.scene(mid)
    W, H = out_w, out_h
    mask = pond.water_mask(mid, kinds, W, H)
    still = np.asarray(pp.draw_scene(mid, m['theme'].get('palette'), kinds, [], W, H)).astype(float) / 255
    rng = np.random.default_rng(9)
    d = ndimage.distance_transform_edt(mask) / 1.4                 # in art pixels
    dj = d + 1.2 * noise(mask.shape, rng, 5)
    maxd = d.max()
    # Each pixel's ice a step lighter than its water's tone among the water's own (the article's rule, with
    # the lake's own range: the fixed thresholds turned this pale lake all white).
    ice_tone = np.clip(tones(bright(still), 5, 97, mask) + 1, 0, 4)
    ys, xs = np.mgrid[0:H, 0:W]
    glare = (np.mod(xs - 1.4 * ys, 46) < 1.5) | (np.mod(xs - 1.4 * ys + 5, 46) < 0.8)
    drift_rank = 0.55 * d / max(maxd, 1) + 0.40 * (noise(mask.shape, rng, 7) * 0.2 + 0.5) + 0.10 * rng.random(mask.shape)
    # Cracks: random walks from deep spots, each pixel numbered so they draw in over the last fifth.
    crack = np.zeros(mask.shape, float)
    deep = np.argwhere(mask & (d > 5))
    r = random.Random(3)
    for _ in range(5 if len(deep) else 0):
        y, x = deep[r.randrange(len(deep))]
        a = r.uniform(0, 2 * math.pi)
        steps = r.randint(12, 25)
        path = []

        def walk(y, x, a, steps):
            for _ in range(steps):
                a += r.uniform(-0.6, 0.6)
                x += math.cos(a) * 1.4
                y += 0.5 * math.sin(a) * 1.4
                path.append((int(y), int(x)))
                if r.random() < 0.12:
                    walk(y, x, a + r.choice([-1.1, 1.1]), r.randint(3, 6))
            return y, x
        walk(y, x, a, steps)
        for i, (py, px) in enumerate(path):
            if 0 <= py < H and 0 <= px < W and mask[py, px]:
                crack[py, px] = max(crack[py, px], (i + 1) / len(path))
    out = []
    for freeze in freezes:
        front = freeze * (maxd + 3)
        ice = mask & (dj <= front)
        rgb = ICE[ice_tone]
        openw = mask & ~ice
        rim = ice & ndimage.binary_dilation(openw, iterations=1)
        rgb = np.where(rim[..., None], ICE[4], rgb)
        rgb = np.where((glare & (d > 3) & ice)[..., None], ICE[4], rgb)
        snow_share = 0.15 if freeze < 0.7 else 0.42 if freeze < 0.85 else 0.68
        cut = np.percentile(drift_rank[ice], snow_share * 100) if ice.any() else 0
        drift = ice & (drift_rank <= cut) & ~rim
        rgb = np.where(drift[..., None], ICE[np.clip(ice_tone + 1, 0, 4)], rgb)
        reveal = (freeze - 0.8) / 0.2
        cr = ice & (crack > 0) & (reveal >= crack)
        rgb = np.where(cr[..., None], ICE[0], rgb)
        # Laid on the ground's water before anything standing is drawn over it.

        def shade(img, drawn, props, palette, ice=ice, rgb=rgb):
            img[..., :3] = np.where(ice[..., None], rgb, img[..., :3])
        out.append(pp.draw_scene(mid, m['theme'].get('palette'), kinds, items, W, H, shade=shade))
    return out


def label(im, text):
    from PIL import ImageDraw
    im = im.copy()
    d = ImageDraw.Draw(im)
    d.rectangle([4, 4, 8 + 6 * len(text), 18], fill=(20, 24, 40))
    d.text((7, 6), text, fill=(255, 255, 255))
    return im


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    plain, snowed = border()
    lakes = lake([0.45, 0.75, 1.0])
    tiles = [label(plain, "border now"), label(snowed, "border snowed (snow at right)")]
    tiles += [label(im, f"lake freeze {f}") for im, f in zip(lakes, [0.45, 0.75, 1.0])]
    w, h = tiles[0].size
    sheet = Image.new("RGB", (w * 2 + 8, h * 3 + 16), (20, 20, 28))
    spots = [(0, 0), (w + 8, 0), (0, h + 8), (w + 8, h + 8), (0, 2 * h + 16)]
    for im, (x, y) in zip(tiles, spots):
        sheet.paste(im, (x, y))
    sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    sheet.save(argv[0])
    print(argv[0])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
