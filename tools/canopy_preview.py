#!/usr/bin/env python3
"""Prototype: canopy shade under trees, against the round shadows the game lays now.

    pip install pillow numpy
    python3 tools/canopy_preview.py                       # a few forest maps → canopy-preview.png
    python3 tools/canopy_preview.py smiling_forest -o out.png --hours 12 17.5
    python3 tools/canopy_preview.py smiling_forest --gif out.gif   # the shade's flecks in the wind

Each row is palette_preview's patch of a map: first as the game draws it now (a soft round shadow
under each tree, `Lighting.Shadow`), then with canopy shade at each hour asked for. The shade is
each scenery sprite's own silhouette laid on the ground away from the sun (`Sun`, ported below),
the crown's top falling farthest, so it's short at midday and long in the evening; every tree's
shade merged into one (shade doesn't darken twice where two overlap), in hard steps (a core and
a one-pixel paler rim), the ground under it pulled toward the palette's shadow colour, and flecks
of light where the leaves part. Only the ground is shaded: walkers and scenery keep their colours,
so they read as before. The game draws it (`TalesOfDorlune/World/CanopyShade.swift`, on the
continent's flat ground); keep the two in step.
"""
import argparse, math
import numpy as np
from PIL import Image
import palette_preview as pp

# ---------- the sun (mirrors TalesOfDorlune/World/Sun.swift) ----------
def sun(hour):
    hour = hour % 24
    day = 6 <= hour < 18
    across = ((hour - 6) if day else (hour - 18) % 24) / 12
    arc = math.sin(math.pi * across)
    turn = math.atan2(1.0, -0.6) + (across - 0.5) * math.pi
    up = math.radians(max(8, 36 * arc))
    own = min(1, arc / math.sin(math.pi / 12))
    x, y, z = math.cos(turn) * math.cos(up) * own, math.sin(turn) * math.cos(up) * own, math.sin(up) * own + 1 - own
    n = math.sqrt(x * x + y * y + z * z)
    return x / n, y / n, z / n, (1 if day else 0.6)

# ---------- the shade ----------
CORE = 0.62     # deepest, at an object's foot (CanopyPainter.core)
TIP_FADE = 0.65  # how much lighter at the shade's far end (CanopyPainter.tipFade)
SOFTNESS = 2     # two box blurs this many pixels round (CanopyPainter.softness)
FLECK_SHADE = 0.3     # how far the ground is pulled into shade
RIM = 0.32      # the one-pixel rim round it
REACH = 0.55    # how long the shade is next to real geometry (real shadows read far too long at midday)
LONGEST = 2.2   # at most this many times the sprite's height (the low evening sun)
FLECKS = 0.035   # the share of the shade where the leaves part
LEAN = np.array([0.42, 0.5, 0.72])   # what full shade multiplies the ground by (CanopyShade.lean)
FLECK_CUT = 0.875  # the noise over which that share lies: fixed, so chunks meet (CanopyShade.fleckCut)

def value_noise(H, W, cell, seed, phase=(0.0, 0.0)):
    rng = np.random.default_rng(seed)
    gh, gw = H // cell + 3, W // cell + 3
    grid = rng.random((gh, gw))
    ys, xs = np.mgrid[0:H, 0:W]
    fx, fy = xs / cell + phase[0], ys / cell + phase[1]
    ix, iy = np.floor(fx).astype(int) % (gw - 1), np.floor(fy).astype(int) % (gh - 1)
    tx, ty = fx - np.floor(fx), fy - np.floor(fy)
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a, b, c, d = grid[iy, ix], grid[iy, ix + 1], grid[iy + 1, ix], grid[iy + 1, ix + 1]
    return (a + (b - a) * tx) + ((c + (d - c) * tx) - (a + (b - a) * tx)) * ty

def cast(mask, foot_x, foot_y, foot_row, s, H, W):
    """The silhouette `mask` (its foot on `foot_row`) laid on the ground from (foot_x, foot_y), away
    from the sun `s`. Each run of a row is taken as a slice of a round crown: its shade an ellipse as
    wide as the run and half as tall (a round on the ground, as `WorldMap.project` draws it), moved
    along the ground by the slice's height above the foot. Their union is lumpy where the crown is."""
    from PIL import ImageDraw
    x, y, z, _ = s
    k = REACH / 0.866 / max(z, 0.05)
    ox = 0.70710678 * (-x + y) * k             # right on screen, per pixel of height
    dy = -0.35355339 * (-x - y) * k            # down on screen
    length = math.hypot(ox, dy)
    if length > LONGEST: ox, dy = ox * LONGEST / length, dy * LONGEST / length
    im = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(im)
    h, w = mask.shape
    tallest = max(1, foot_row)
    for i in range(h):   # row 0 is the top: the tip's slices first, so the foot's deeper shade wins
        hs = foot_row - i
        if hs < 0: continue
        cols = np.where(mask[i])[0]
        if not len(cols): continue
        depth = 1 - TIP_FADE * min(1, hs / tallest)
        runs = np.split(cols, np.where(np.diff(cols) > 1)[0] + 1)
        for run in runs:
            half = (run[-1] - run[0] + 1) / 2
            cx = foot_x - w / 2 + (run[0] + run[-1]) / 2 + ox * hs
            cy = foot_y + dy * hs
            d.ellipse((cx - half, cy - half / 2, cx + half, cy + half / 2), fill=int(255 * depth))
    return np.asarray(im).astype(float) / 255

def canopy(hour, flecks_phase=(0.0, 0.0)):
    s = sun(hour)
    def shade(img, drawn, props, palette):
        H, W = img.shape[:2]
        depth = np.zeros((H, W))
        for art, spr, x0, y0, w, h, walker, _ in drawn:
            if walker or h < 12: continue   # everything that stands casts it, but a speck (CanopyShade.shortest)
            mask = spr[..., 3] > 0.5
            rows = np.where(mask.any(1))[0]
            if not len(rows): continue
            depth = np.maximum(depth, cast(mask, x0 + w / 2, y0 + rows[-1], rows[-1], s, H, W))
        if not depth.any(): return
        core = depth > 0
        n = value_noise(H, W, 9, 11, flecks_phase)
        inner = core.copy()
        for dx, dy in ((4, 0), (-4, 0), (0, 3), (0, -3)):
            inner &= np.roll(np.roll(core, dy, 0), dx, 1)
        depth = np.where(inner & (n > FLECK_CUT), depth * FLECK_SHADE, depth)
        from PIL import ImageFilter
        im = Image.fromarray((depth * 255).astype(np.uint8))
        im = im.filter(ImageFilter.BoxBlur(SOFTNESS)).filter(ImageFilter.BoxBlur(SOFTNESS))
        a = np.asarray(im).astype(float) / 255 * CORE * s[3]
        # Darker and a little cool, the same in every land (CanopyShade.lean).
        shaded = img[..., :3] * LEAN
        img[..., :3] = img[..., :3] * (1 - a[..., None]) + shaded * a[..., None]
    return shade

def forest(mid, W, H, seed=4, shade=None):
    """A forest glade like the clip's: trees packed round the edge, a clearing in the middle with the
    path winding through it, a few bushes and rocks, and the hero by the path."""
    import random
    m = pp.maps[mid]; th = m['theme']; rng = random.Random(seed)
    N = 16
    kinds = [['g'] * N for _ in range(N)]
    col = N // 2
    for r in range(N):
        kinds[r][col] = 'p'
        if rng.random() < 0.35: col = max(3, min(N - 4, col + rng.choice([-1, 1]))); kinds[r][col] = 'p'
    props = [p for p in th['props'] if not p.get('within')]
    tall = [p for p in props if p.get('shadow') and 'tree' in p['art']] or [p for p in props if p.get('shadow')]
    low = [p for p in props if not p.get('shadow')]
    items = []
    for r in range(N):
        for c in range(N):
            if kinds[r][c] != 'g': continue
            # How far out on screen (0 the middle, 1 the frame's edge): the glade is round on screen.
            x, y = pp.project((c + 0.5) * pp.T, (r + 0.5) * pp.T)
            mx, my = pp.project(N * pp.T / 2, N * pp.T / 2)
            edge = math.hypot((x - mx) / (W * 0.5), (y - my) / (H * 0.5))
            if rng.random() < max(0, edge - 0.5) * 2.2 and tall:
                p = rng.choice(tall); lo, hi = p.get('size', [1, 1])
                items.append((p['art'], c, r, rng.uniform(lo, hi)))
            elif rng.random() < 0.08 and low:
                p = rng.choice(low); lo, hi = p.get('size', [1, 1])
                items.append((p['art'], c, r, rng.uniform(lo, hi)))
    items.append(('player_walk', N // 2 - 1, N // 2, 1))
    return pp.draw_scene(mid, th.get('palette'), kinds, items, W, H, seed, shade=shade)

def row(mid, hours, W, H, phase=(0.0, 0.0)):
    return [forest(mid, W, H)] + [forest(mid, W, H, shade=canopy(h, phase)) for h in hours]

def label(img, text):
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    d.rectangle((4, 4, 8 + 6 * len(text), 16), fill=(0, 0, 0))
    d.text((6, 4), text, fill=(255, 255, 255))
    return img

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('maps', nargs='*', default=['smiling_forest', 'meadowbrook', 'twilight_woods', 'snow_white_forest'])
    parser.add_argument('-o', '--out', default='canopy-preview.png')
    parser.add_argument('--hours', nargs='*', type=float, default=[12, 17.25])
    parser.add_argument('--gif', help='write an animated GIF of the first map at the first hour')
    parser.add_argument('--zoom', type=int, default=2)
    args = parser.parse_args()
    W, H = 420, 280
    if args.gif:
        frames = []
        for f in range(16):
            t = f / 16 * 2 * math.pi
            # A travelling wave: the flecks drift with the gust and settle back.
            phase = (0.35 * math.sin(t), 0.15 * math.sin(t + 0.8))
            im = forest(args.maps[0], W, H, shade=canopy(args.hours[0], phase))
            frames.append(im.resize((W * args.zoom, H * args.zoom), Image.NEAREST))
        frames[0].save(args.gif, save_all=True, append_images=frames[1:], duration=120, loop=0)
        print('wrote', args.gif)
    else:
        cols = 1 + len(args.hours)
        sheet = Image.new('RGB', ((W + 8) * cols, (H + 8) * len(args.maps)), (20, 20, 24))
        for r, mid in enumerate(args.maps):
            names = ['now'] + [f'canopy {int(h):02d}:{int(h % 1 * 60):02d}' for h in args.hours]
            for c, (im, name) in enumerate(zip(row(mid, args.hours, W, H), names)):
                sheet.paste(label(im, f'{mid}: {name}'), (c * (W + 8), r * (H + 8)))
        sheet = sheet.resize((sheet.width * args.zoom, sheet.height * args.zoom), Image.NEAREST)
        sheet.save(args.out)
        print('wrote', args.out)
