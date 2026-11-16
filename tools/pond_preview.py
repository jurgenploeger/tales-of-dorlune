#!/usr/bin/env python3
"""Layered pond water, previewed before it goes into the game (the user, 2026-11-16, pointing to SpriteCook's
"Pixel art pond water: reflections and ripples": "Can we apply this").

The article's method, on a lake drawn as the game draws one (`tools/palette_preview.py`): every water pixel
gets a tone, an index into a short palette, never a blend, in six layers, on a 5-second loop whose every
motion turns a whole number of times:

1. Depth: tone 3 near the shore, 2 further out, 1 in the middle (distance to land after a soft blur).
2. Sky light: the near half lighter, tone 3 from a quarter of the way down from the far shore, 4 from halfway.
3. Reflections: every sprite drawn flipped about its foot, squashed to 0.55, in three flat dark tones (the
   darker wins where two meet), each row shifted a whole pixel by a slow wave (none in the first 3 rows).
4. Shore: damp ground on the near and side banks, a shallow edge there (tone 7), light dashes lapping on a
   ring 2 to 3 pixels out.
5. Back bank: its waterline dark, the bank mirrored 6 rows down in its own tones, a waterline that creeps.
6. Drops rippling out, glints on the sky-lit water.

The article works in art pixels; the game's are 44/32 points, so its distances are scaled by `PX`.

    python3 tools/pond_preview.py out.png [map]       # before | after
    python3 tools/pond_preview.py --gif out.gif [map] # after, the 5-second loop

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

PX = 44 / 32          # points per art pixel on the map
LOOP = 5.0            # seconds
# The article's palette (tones 0-6 water dark to light, 7 shallows over mud, 8 bank mud, 9 bank grass),
# taken to each land's own water colour (`toned`).
TONES = np.array([[0x1d, 0x3a, 0x44], [0x24, 0x50, 0x5a], [0x2c, 0x66, 0x70], [0x3a, 0x7f, 0x84],
                  [0x5a, 0x9f, 0xa0], [0x8c, 0xc8, 0xc0], [0xc4, 0xec, 0xe2], [0x5a, 0x93, 0x84],
                  [0x2c, 0x3b, 0x36], [0x2d, 0x52, 0x46]]) / 255


def phase(t, cycles):
    return 2 * math.pi * cycles * t / LOOP


def brightness(rgb):
    return (0.3 * rgb[..., 0] + 0.59 * rgb[..., 1] + 0.11 * rgb[..., 2]) * 255


def toned(water_rgb):
    """The palette carried to a land's water: each water tone as bright, against tone 3, as the article's,
    in the land's own water colour (darker toward its deep shade, lighter toward a pale sky); the bank's
    and the shallows' as they are, tinted a little toward it."""
    ref = brightness(TONES[3])
    # The tile's own colour is its lightest ripples' too: tone 3, the shore's, a little under it.
    water_rgb = water_rgb * 0.88
    out = TONES.copy()
    deep = water_rgb * 0.45 + np.array([0.02, 0.05, 0.08])
    pale = water_rgb + (np.array([0.86, 0.96, 0.95]) - water_rgb) * 0.75
    for k in range(7):
        f = brightness(TONES[k]) / ref
        if f <= 1:
            out[k] = deep + (water_rgb - deep) * (f - brightness(TONES[0]) / ref) / (1 - brightness(TONES[0]) / ref)
        else:
            top = brightness(TONES[6]) / ref
            out[k] = water_rgb + (pale - water_rgb) * (f - 1) / (top - 1)
    out[7] = (TONES[7] + water_rgb) / 2
    return np.clip(out, 0, 1)


def scene(mid, seed=4):
    """A lake on a patch of the map, trees and bushes round it, thickest along its far (upper) bank."""
    m = pp.maps[mid]
    th = m['theme']
    rng = random.Random(seed)
    n = 18
    kinds = [['g'] * n for _ in range(n)]
    for r in range(n):
        for c in range(n):
            # An oval lake, wider across the screen (along c - r) than down it.
            u, v = (c - 8.5), (r - 8.0)
            a, b = (u - v) / 2, (u + v) / 2
            if (a / 3.6) ** 2 + (b / 2.4) ** 2 + 0.08 * math.sin(3 * a + b) < 1:
                kinds[r][c] = 'w'
    for r in range(n):
        kinds[r][2] = 'p'
    tall = [p for p in th['props'] if 'tree' in p['art'] and not p.get('within')]
    low = [p for p in th['props'] if ('bush' in p['art'] or 'rock' in p['art']) and not p.get('within')]
    items, taken = [], set()

    def free(c, r):
        return 0 <= c < n and 0 <= r < n and kinds[r][c] == 'g' and (c, r) not in taken

    def near_water(c, r):
        return any(0 <= c + dc < n and 0 <= r + dr < n and kinds[r + dr][c + dc] == 'w'
                   for dc in (-1, 0, 1) for dr in (-1, 0, 1))

    # The far bank: land cells whose next cell down the screen (c - 1, r - 1) is water, a tree or a
    # bush on most, standing right at the water's edge.
    for c in range(1, n):
        for r in range(1, n):
            if free(c, r) and kinds[r - 1][c - 1] == 'w' and rng.random() < 0.8:
                p = rng.choice(tall if rng.random() < 0.7 else low or tall)
                taken.add((c, r))
                lo, hi = p.get('size', [1, 1])
                items.append((p['art'], c, r, rng.uniform(lo, hi)))
    for _ in range(26):
        c, r = rng.randrange(n), rng.randrange(n)
        if free(c, r) and not near_water(c, r):
            p = rng.choice(tall + low)
            taken.add((c, r))
            lo, hi = p.get('size', [1, 1])
            items.append((p['art'], c, r, rng.uniform(lo, hi)))
    items.append(('player_walk', 6, 4, 1))
    return kinds, items


def water_mask(mid, kinds, W, H):
    """Which screen pixels are the lake: the scene drawn with magenta water, nothing on it."""
    m = pp.maps[mid]
    key = m['theme'].get('water') or 'tile_water'
    real = pp.raw
    magenta = np.zeros((32, 32, 4))
    magenta[..., 0] = magenta[..., 2] = magenta[..., 3] = 1

    def raw(i, depth=0):
        return magenta.copy() if i == key else real(i, depth)
    pp.raw = raw
    try:
        img = np.asarray(pp.draw_scene(mid, None, kinds, [], W, H, tint=False, lighting=False, focus=False)).astype(float) / 255
    finally:
        pp.raw = real
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    mask = (r > 0.45) & (b > 0.45) & (g < 0.6 * np.minimum(r, b))
    # The article's first step: blurred and cut at a half, so notches in the bank smooth out.
    return ndimage.gaussian_filter(mask.astype(float), 2 * PX) > 0.5


def runs_from_far_shore(mask):
    """How many rows each water pixel lies under the far (upper) shore in its column."""
    out = np.zeros(mask.shape, int)
    for x in range(mask.shape[1]):
        count = 0
        for y in range(mask.shape[0]):
            count = count + 1 if mask[y, x] else 0
            out[y, x] = count
    return out


def layers(img, drawn, mask, tones, t, seed=7):
    """The six layers over the scene's ground (`img`, before anything standing is drawn on it)."""
    H, W = mask.shape
    rng = random.Random(seed)
    ys, xs = np.mgrid[0:H, 0:W]
    land_dist = ndimage.distance_transform_edt(mask) / PX          # art pixels to the nearest land
    row = runs_from_far_shore(mask)
    depth_rows = max(1, row.max())

    # 1 Depth.
    tone = np.where(land_dist < 3, 3, np.where(land_dist > 7, 1, 2))
    # 2 Sky light on the near half.
    interior = land_dist >= 3
    tone = np.where(interior & (row >= depth_rows * 0.23), np.maximum(tone, 3), tone)
    tone = np.where(interior & (row >= depth_rows * 0.47), 4, tone)

    # 3 Reflections: each sprite flipped about its foot, squashed, in three dark tones, rows shifted.
    reflect = np.full((H, W), 99)
    standing = [d for d in drawn if not d[6]]
    allb = np.concatenate([brightness(s[..., :3])[s[..., 3] > 0.5] for _, s, *_ in standing]) if standing else np.array([0])
    dark_cut = np.percentile(allb, 15)
    for art, s, x0, y0, w, h, walker, _ in drawn:
        rows = np.where((s[..., 3] > 0.5).any(1))[0]
        if not len(rows):
            continue
        foot = rows[-1]
        bright = brightness(s[..., :3])
        level = np.where(bright < dark_cut, 0, np.where(bright < 110, 1, 2))
        base_y = y0 + foot
        for r in range(1, int(foot / 0.55)):
            src = foot - int(r / 0.55)
            if src < 0:
                break
            y = base_y + r
            if not 0 <= y < H:
                continue
            amp = 0 if r <= 3 else (1 if r <= 30 * PX else 2)
            shift = round(amp * math.sin(r / PX * 0.75 - phase(t, 2)))
            on = s[src, :, 3] > 0.5
            for x in np.nonzero(on)[0]:
                X = x0 + x + shift
                if 0 <= X < W and mask[y, X]:
                    reflect[y, X] = min(reflect[y, X], level[src, x])
    # Always a step darker than the water it lies on: the game's trees are brighter than the article's
    # forest, and their lit crowns in tone 2 vanished into the tone 2 water by the far bank.
    tone = np.where(reflect < 99, np.maximum(0, np.minimum(tone - 1, reflect)), tone)

    # Banks: far bank land lies right above water; the rest of the shore is near and side.
    land = ~mask
    above_water = np.zeros_like(mask)
    above_water[:-1] = land[:-1] & mask[1:]
    far_bank = ndimage.binary_dilation(above_water, structure=np.ones((3, 1)), iterations=2) & land
    near_land = ndimage.binary_dilation(mask, iterations=max(1, round(PX))) & land & ~far_bank
    shore_water = mask & ndimage.binary_dilation(near_land, iterations=max(1, round(1.5 * PX)))

    # 4 Shore: damp ground, a shallow edge, lapping dashes on a ring 2 to 3 pixels out.
    img[near_land, :3] *= 0.82
    tone = np.where(shore_water & (tone >= 3), 7, tone)
    closed = ndimage.binary_closing(mask, structure=np.ones((5, 5)))
    lap_dist = ndimage.distance_transform_edt(closed) / PX
    ring = 2 + (0.5 + 0.5 * math.sin(phase(t, 2)))       # out to 3 and back, twice a loop
    cy, cx = np.argwhere(mask).mean(0)
    angle = np.arctan2((ys - cy) * 2, xs - cx)
    lapping = np.sin(angle * 11 + phase(t, 1)) + np.sin(angle * 17 - phase(t, 2))
    dashes = mask & (np.abs(lap_dist - ring) < 0.6) & (lapping > 1.2) & ~far_bank
    tone = np.where(dashes, 5, tone)

    # 5 Back bank: the waterline dark, the bank mirrored 6 rows down, faint ripples, a waterline that creeps.
    line = mask & np.vstack([np.zeros((1, W), bool), land[:-1]])
    tone = np.where(line, 0, tone)
    ground = img[..., :3].copy()
    gb = brightness(ground)
    green = (ground[..., 1] > ground[..., 0]) & (ground[..., 1] > ground[..., 2])
    bank_tone = np.where(gb < 36, 0, np.where(green, 9, 8))
    for k in range(1, int(6 * PX) + 1):
        art_row = k / PX
        if 4.5 < art_row < 5.5:
            continue           # the fifth row left as water: broken, not a band
        shift = round(math.sin(ys[0, 0] + art_row * 0.45 - phase(t, 2))) if art_row > 3.5 else 0
        src_y = np.clip(ys - 2 * k + 1, 0, H - 1)      # mirrored about the waterline
        src_x = np.clip(xs + shift, 0, W - 1)
        here = mask & (row == k + 1) & land[np.clip(ys - k - 1, 0, H - 1), xs]
        here &= land[src_y, src_x]
        mirrored = bank_tone[src_y, src_x]
        wave = np.sin(xs * 0.6 + art_row * 1.3 - phase(t, 2)) * np.sin(xs * 0.23 + phase(t, 1))
        rippled = (art_row > 1.5) & (art_row < 5.5) & (wave > 0.95)
        mirrored = np.where(rippled, np.where(mirrored == 9, 0, 1), mirrored)
        tone = np.where(here & (reflect == 99), mirrored, tone)
    creep = np.sin(xs * 0.31 + phase(t, 1)) + np.sin(xs * 0.17 - phase(t, 1))
    lifted = np.vstack([line[1:], np.zeros((1, W), bool)]) & (creep > 0.6)
    img[lifted, :3] = tones[0]

    # 6 Drops rippling out and glints on the sky-lit water.
    sky = mask & interior & (row >= depth_rows * 0.3)
    spots = np.argwhere(sky)
    drops = [tuple(spots[rng.randrange(len(spots))]) for _ in range(2)] if len(spots) else []
    for n, (dy, dx) in enumerate(drops):
        start = LOOP * n / max(1, len(drops))
        age = (t - start) % LOOP
        frame = int(age / 0.2)
        if frame < 5:
            rx, ry = [(1, 0), (2, 1), (4, 2), (6, 3), (8, 4)][frame]
            rx, ry = rx * PX, max(0.6, ry * PX)
            e = ((xs - dx) / max(rx, 0.6)) ** 2 + ((ys - dy) / ry) ** 2
            edge = (np.abs(e - 1) < 0.35) & mask
            if frame >= 3:
                edge &= np.abs(ys - dy) >= ry / 2
            tone = np.where(edge, 6 if frame < 3 else 5, tone)
    for g in range(20):
        gy, gx = spots[rng.randrange(len(spots))] if len(spots) else (0, 0)
        born = rng.uniform(0, LOOP)
        life = ((t - born) % LOOP) / 0.6
        if life >= 1:
            continue
        width = 1 if life < 0.15 else 3 if life < 0.3 else 5 if life < 0.65 else 4 if life < 0.85 else 2
        half = width * PX / 2
        on = mask & (np.abs(ys - gy) < 0.7) & (np.abs(xs - gx) <= half)
        if 0.65 <= life < 0.85:
            on &= np.abs(xs - gx) > PX * 0.6
        middle = np.abs(xs - gx) <= PX * 0.7
        tone = np.where(on, np.where(middle & (life < 0.85), 6, 5), tone)

    img[mask, :3] = tones[tone[mask]]


def frame(mid, t, kinds, items, mask, W, H):
    m = pp.maps[mid]
    water = pp.grade(pp.raw(m['theme'].get('water') or 'tile_water'), m['theme'].get('palette'))
    tones = toned(water[..., :3].reshape(-1, 3).mean(0))

    def shade(img, drawn, props, palette):
        layers(img, drawn, mask, tones, t)
    return pp.draw_scene(mid, m['theme'].get('palette'), kinds, items, W, H, shade=shade)


def main(argv):
    gif = '--gif' in argv
    args = [a for a in argv if a != '--gif']
    if not args:
        print(__doc__)
        return 1
    out = args[0]
    mid = args[1] if len(args) > 1 else 'sunny_meadow'
    W, H = 520, 340
    kinds, items = scene(mid)
    mask = water_mask(mid, kinds, W, H)
    if gif:
        frames = [frame(mid, k / 10, kinds, items, mask, W, H).resize((W * 2, H * 2), Image.NEAREST)
                  for k in range(int(LOOP * 10))]
        frames[0].save(out, save_all=True, append_images=frames[1:], duration=100, loop=0)
    else:
        m = pp.maps[mid]
        before = pp.draw_scene(mid, m['theme'].get('palette'), kinds, items, W, H)
        after = frame(mid, 1.3, kinds, items, mask, W, H)
        sheet = Image.new('RGB', (W * 2 + 8, H), (20, 20, 24))
        sheet.paste(before, (0, 0))
        sheet.paste(after, (W + 8, 0))
        sheet.resize((sheet.width * 2, H * 2), Image.NEAREST).save(out)
    print('wrote', out)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
