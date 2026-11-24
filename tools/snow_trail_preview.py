#!/usr/bin/env python3
"""Footprints in the snow (and the sand, --sand), after SpriteCook's trail render texture article
(spritecook.ai/blog/2d-trail-render-texture-snow-grass-water): one small map of bytes, one per
pixel, black where nothing has happened; every walker stamps it (a faint dab under the body each
frame, a strong print where a foot comes down), it fades a whole number of levels each frame, and
the snow reads it through two cutoffs into a shallow and a deep dent, lit from the top left: a
shadowed wall along the dent's top, its left edge darker, a bright lip along its bottom. As the map
fades the print fills back in. The same map is what the tall grass would read later.

To pick a look before any Swift (as grass_preview.py, pond_preview.py did):

  python3 tools/snow_trail_preview.py --gif out.gif        three looks side by side, the hero walking
  python3 tools/snow_trail_preview.py -o out.png           a still of each, near the end of the walk
  python3 tools/snow_trail_preview.py --map rosen_lake ... another snow land
  python3 tools/snow_trail_preview.py --sand -o out.png  the sand looks in four sand lands (S2 picked)

The walk sheet's strides are frames 0 and 2 (one foot forward), its feet together 1 and 3; a foot
comes down as a stride frame starts, the prints left and right of the line by turns. A cobbled path
crosses the snow: no prints on it (in the game, only on the land's own snow ground).
"""
import argparse, math
import numpy as np
from PIL import Image

import palette_preview as pp

FPS = 30                       # the article's rate; the fade is levels a frame at this rate
SPEED = 40.0                   # pixels a second, as grass_preview walks

# Three looks for snow: (name, fade levels a frame at 30 fps, cutoffs, lip, how strong the dent's tint).
# The user picked C (2026-11-24): SnowTrail.swift has it.
LOOKS = [
    dict(name='A: article', fade=3, cuts=(90.5, 166.5), lip='snow', wall=True, tint=(0.16, 0.30)),
    dict(name='B: soft, slow', fade=1, cuts=(110.5,), lip=None, wall=False, tint=(0.20,)),
    dict(name='C: deep, slow', fade=1, cuts=(70.5, 140.5, 210.5), lip='snow', wall=True, tint=(0.18, 0.32, 0.46)),
]
# And for sand (--sand; S2 picked, 2026-11-24, Footprints.swift): its lip the palette's highlight half mixed with white, not the snow's white.
SAND_LOOKS = [
    dict(name='S1: sand, shallow', fade=1, cuts=(90.5, 170.5), lip='highlight', lip_alpha=0.5, wall=True, tint=(0.14, 0.26)),
    dict(name='S2: sand, as snow C', fade=1, cuts=(70.5, 140.5, 210.5), lip='highlight', wall=True, tint=(0.18, 0.32, 0.46)),
]
SAND_LANDS = ['pineapple_shore', 'goldburg_lake', 'genie_desert', 'secret_plain']

DAB = dict(peak=0.30, sx=4.0, sy=2.0)          # under the body, every frame (for the grass; never dents)
BOOT = dict(peak=1.3, sx=3.0, sy=1.8)          # where a foot comes down: flat white at its middle
FOOT_APART = 4                                  # pixels either side of the line the prints fall


def stamp(canvas, cx, cy, peak, sx, sy):
    """A soft dot, min(1, peak * exp(-(dx/sx)^2 - (dy/sy)^2)), kept where brighter (the article's)."""
    H, W = canvas.shape
    r = int(max(sx, sy) * 3) + 1
    x0, x1, y0, y1 = max(0, int(cx) - r), min(W, int(cx) + r + 1), max(0, int(cy) - r), min(H, int(cy) + r + 1)
    if x0 >= x1 or y0 >= y1: return
    yy, xx = np.mgrid[y0:y1, x0:x1]
    v = np.minimum(1, peak * np.exp(-((xx - cx) / sx) ** 2 - ((yy - cy) / sy) ** 2))
    canvas[y0:y1, x0:x1] = np.maximum(canvas[y0:y1, x0:x1], np.round(v * 255).astype(np.uint8))


def hero_frames():
    sheet = np.asarray(Image.open(pp.R + 'art/sprites/player_walk.png').convert('RGBA'))
    rows = {'up': 0, 'left': 1, 'down': 2, 'right': 3}
    return {d: [sheet[r * 48:(r + 1) * 48, c * 48:(c + 1) * 48] for c in range(4)] for d, r in rows.items()}


FEET_ROW = 43                  # the frame's lowest drawn row (Walker.feet)


def scene(mid, W, H, N=12):
    """The land's snow, a path across it, and which screen pixels are snow ground (not path)."""
    kinds = [['g'] * N for _ in range(N)]
    for r in range(N):
        kinds[r][N // 2 - 1] = 'p'                    # a road along one diagonal of the diamond grid
    img = np.asarray(pp.draw_scene(mid, pp.maps[mid]['theme'].get('palette'), kinds, [], W, H, 3,
                                   lighting=False).convert('RGB')).astype(float)
    # Which cell each pixel shows, as draw_scene works it out.
    T, C = pp.T, pp.C
    ox, oy = pp.project(N * T / 2, N * T / 2)
    ys, xs = np.mgrid[0:H, 0:W]
    px = xs - W / 2 + ox; py = (H / 2 - ys) + oy
    gx = (py / (C * 0.5) + px / C) / 2; gy = (py / (C * 0.5) - px / C) / 2
    cc = np.floor(gx / T).astype(int).clip(0, N - 1); rr = np.floor(gy / T).astype(int).clip(0, N - 1)
    snow = np.array([[k == 'g' for k in row] for row in kinds])[rr, cc]
    return img, snow


def colours(mid, ground):
    """The dent's tint and the lips, from the land: its palette's shadow colour (CanopyShade.lean
    takes the same); the snow's own brightest, and its highlight half mixed with white (sand)."""
    p = pp.maps[mid]['theme'].get('palette') or {}
    shadow = pp.hexrgb(p.get('shadow', '#3050E0')) * 255
    snow = np.percentile(ground.reshape(-1, 3), 98, axis=0)
    snow = np.minimum(255, snow * 1.04 + 4)
    warm = 255 * (0.55 + 0.45 * pp.hexrgb(p.get('highlight', '#FFFFFF')))
    return shadow, {'snow': snow, 'highlight': warm}


SAND_SHADE = '#5A3018'      # a warm brown the sand's dents lean toward, with the palette's shadow
SAND_SHADE_SHARE = 0.6      # how much of it: on its own a blue shadow turned the sand's dents grey-green



def dents(ground, snow, canvas, look, shadow, lip):
    """The snow as the map has it: each cutoff a level deeper; a level's top edge (the pixel above
    shallower) a step deeper still, its left edge half a step, and the bright lip on the snow just
    under a dent's bottom edge."""
    img = ground.copy()
    level = np.zeros(canvas.shape, int)
    for k, cut in enumerate(look['cuts']):
        level[canvas > cut] = k + 1
    level[~snow] = 0
    tints = look['tint']
    for k in range(1, len(look['cuts']) + 1):
        m = level == k
        a = tints[k - 1]
        # Toward the shadow colour at the snow's own brightness, so it reads as shade, not paint.
        img[m] = img[m] * (1 - a) + shadow * a * (img[m].mean(-1, keepdims=True) / 255)
    if look['wall']:
        up = np.zeros_like(level); up[1:] = level[:-1]
        left = np.zeros_like(level); left[:, 1:] = level[:, :-1]
        wall = (level > 0) & (up < level)
        img[wall] *= 0.82
        side = (level > 0) & (left < level) & ~wall
        img[side] *= 0.92
    if look['lip']:
        above = np.zeros_like(level); above[1:] = level[:-1]
        rim = (level == 0) & (above > 0) & snow
        a = look.get('lip_alpha', 0.65)
        img[rim] = img[rim] * (1 - a) + lip[look['lip']] * a
    return img


def paste(img, sprite, x0, y0):
    h, w = sprite.shape[:2]
    H, W = img.shape[:2]
    sx0, sy0 = max(0, -x0), max(0, -y0)
    ex, ey = min(w, W - x0), min(h, H - y0)
    if ex <= sx0 or ey <= sy0: return
    s = sprite[sy0:ey, sx0:ex].astype(float)
    a = s[..., 3:] / 255
    sl = img[y0 + sy0:y0 + ey, x0 + sx0:x0 + ex]
    sl[:] = sl * (1 - a) + s[..., :3] * a


def walk(mid, W=220, H=150):
    """Yields (frame index, hero x, feet y, direction, walk frame, footfall or None) along a loop."""
    route = [(20, 60), (120, 60), (120, 60), (150, 120), (60, 128), (30, 90), (30, 90)]
    x, y = route[0]
    t, last_frame, steps = 0.0, None, 0
    for gx, gy in route[1:]:
        while True:
            dx, dy = gx - x, gy - y
            d = math.hypot(dx, dy)
            if d < 0.5:
                for _ in range(int(FPS * 0.6)):
                    yield x, y, dirn, 1, None
                break
            mv = SPEED / FPS
            x += dx / d * min(d, mv); y += dy / d * min(d, mv)
            t += 1 / FPS
            dirn = ('right' if dx > 0 else 'left') if abs(dx) >= abs(dy) else ('down' if dy > 0 else 'up')
            frame = int(t * 8) % 4
            fall = None
            if frame != last_frame and frame in (0, 2):
                # A foot down, beside the line by turns, across the way you walk.
                side = 1 if steps % 2 else -1
                steps += 1
                nx, ny = -dy / d, dx / d
                fall = (x + nx * FOOT_APART * side, y + ny * FOOT_APART * side * 0.6)
            last_frame = frame
            yield x, y, dirn, frame, fall
    # Then stand a while, so the prints fade.
    for _ in range(FPS * 4):
        yield x, y, dirn, 1, None


def render(mid, looks=LOOKS):
    W, H = 220, 150
    ground, snow = scene(mid, W, H)
    shadow, lip = colours(mid, ground)
    heroes = hero_frames()
    canvases = [np.zeros((H, W), np.uint8) for _ in looks]
    frames = []
    for x, y, dirn, fr, fall in walk(mid, W, H):
        panels = []
        for look, canvas in zip(looks, canvases):
            tint_to = shadow if look['lip'] != 'highlight' else shadow * (1 - SAND_SHADE_SHARE) + pp.hexrgb(SAND_SHADE) * 255 * SAND_SHADE_SHARE
            canvas[:] = np.maximum(0, canvas.astype(int) - look['fade']).astype(np.uint8)
            stamp(canvas, x, y - 1, **DAB)
            if fall: stamp(canvas, fall[0], fall[1], **BOOT)
            img = dents(ground, snow, canvas, look, tint_to, lip)
            sprite = heroes[dirn][fr]
            paste(img, sprite, int(round(x)) - 24, int(round(y)) - FEET_ROW)
            panels.append(np.clip(img, 0, 255).astype(np.uint8))
        frames.append(panels)
    return frames


def label(panel, text, zoom):
    from PIL import ImageDraw
    im = Image.fromarray(panel).resize((panel.shape[1] * zoom, panel.shape[0] * zoom), Image.NEAREST)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 8 + 7 * len(text), 18], fill=(20, 24, 40))
    d.text((5, 3), text, fill=(240, 240, 255))
    return np.asarray(im)


def join(panels, zoom, names=None):
    gap = np.full((panels[0].shape[0] * zoom, 6, 3), 30, np.uint8)
    out = []
    for i, (p, name) in enumerate(zip(panels, names or [l['name'] for l in LOOKS])):
        if i: out.append(gap)
        out.append(label(p, name, zoom))
    return Image.fromarray(np.concatenate(out, 1))


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--map', default='snow_white_forest')
    ap.add_argument('-o', '--out', default='snow-trail-preview.png')
    ap.add_argument('--gif')
    ap.add_argument('--zoom', type=int, default=3)
    ap.add_argument('--sand', action='store_true', help='the sand looks, a row a sand land (a still only)')
    args = ap.parse_args()
    if args.sand:
        rows = []
        for mid in SAND_LANDS:
            frames = render(mid, SAND_LOOKS)
            k = len(frames) - FPS * 4 - 1
            rows.append(np.asarray(join(frames[k], args.zoom, [f"{l['name']} | {mid}" for l in SAND_LOOKS])))
        Image.fromarray(np.concatenate(rows, 0)).save(args.out)
        raise SystemExit
    frames = render(args.map)
    if args.gif:
        # Every third frame at twice the size, on one palette, so the GIF stays a few megabytes.
        ims = [join(f, 2) for f in frames[::3]]
        pal = ims[len(ims) // 2].quantize(colors=128, method=Image.Quantize.MEDIANCUT)
        ims = [im.quantize(palette=pal, dither=Image.Dither.NONE) for im in ims]
        ims[0].save(args.gif, save_all=True, append_images=ims[1:], duration=int(3000 / FPS), loop=0, optimize=True)
    # A still near the end of the walk, before the prints fade.
    k = len(frames) - FPS * 4 - 1
    join(frames[k], args.zoom).save(args.out)
