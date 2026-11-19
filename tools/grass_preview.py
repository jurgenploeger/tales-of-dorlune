#!/usr/bin/env python3
"""Tall grass you wade through, after SpriteCook's interactive tall grass article
(spritecook.ai/blog/interactive-tall-grass-top-down-pixel-art): a patch of small tufts, each its
own sprite standing on its base and sorted with the walkers, that lean away from you on a spring,
rustle as you push in, are pressed flat behind your feet and stand up again, and hide your legs
along the grass's own top edge (the "wading cut"), every row moved in whole pixels.

To pick a look before any Swift (as canopy_preview.py, pond_preview.py did):

  python3 tools/grass_preview.py --gif out.gif     the hero walking through a patch
  python3 tools/grass_preview.py -o out.png        the tufts in each grass land's colours

Sizes are the article's, scaled to our walker (36 pixels tall to its 32): tufts 18 x 20, 14 apart
across and 9 down, their bottom 11 rows solid so nothing shows through their base.
"""
import argparse, colorsys, math, random
import numpy as np
from PIL import Image

import palette_preview as pp

TW, TH = 18, 20                # a tuft's picture
SOLID = 11                     # its bottom rows, filled
STEP_X, STEP_Y = 14, 9         # how far apart, across and down
SPRING_HZ, DAMPING = 2.6, 0.22
MAX_LEAN, FRONT_LEAN = 8.0, 2.0
PRESS_IN, PRESS_OUT = 0.12, 0.7
SHAKE_FOR, SHAKE_PX, SHAKE_SPEED, COOLDOWN = 0.35, 1.0, 40.0, 0.7
CUT_BELOW, CUT_SMOOTH, CUT_MOST, CUT_SCRAP = 2, 5, 13, 12
FPS = 20


# ---------- the tufts ----------

def ramp(mid):
    """Five greens from the land's grass tile as graded there (`ramp_from`)."""
    th = pp.maps[mid]['theme']
    return ramp_from(pp.sprite(th.get('ground', 'tile_grass'), th.get('palette')))


def ramp_from(img):
    """Five greens from a grass tile's pixels, darkest first, hue-shifted as the house look is
    (darks toward blue, lights toward yellow): docs/pixel-style.md."""
    im = img[..., :3][img[..., 3] > 0.5] if img.shape[-1] == 4 else img.reshape(-1, 3)
    h, s, v = colorsys.rgb_to_hsv(*im.mean(0))
    out = []
    # Each step's value a share of the ground's, not a fixed step off it: from dark grass a fixed step
    # down ran to black, and Twilight Woods' tufts read as navy blots (2026-11-19).
    for share, dh, ds in [(0.42, 0.06, 0.10), (0.67, 0.03, 0.06), (0.92, 0.0, 0.0), (1.13, -0.03, -0.05), (1.3, -0.06, -0.14)]:
        r, g, b = colorsys.hsv_to_rgb((h + dh) % 1, min(1, max(0, s + ds)), min(1, v * share))
        out.append((int(r * 255), int(g * 255), int(b * 255)))
    return out


def blade(img, x0, lean, height, curl, tone, ramp_, width=2):
    """One blade from its foot at the bottom row up `height` rows, bending `lean` pixels at its
    tip (more toward the top), its tip one pixel wide, its edge facing away from the light darker."""
    for r in range(height):
        t = r / max(1, height - 1)
        x = x0 + lean * t ** 1.5 + curl * math.sin(t * math.pi)
        y = TH - 1 - r
        w = 3 if t < 0.3 else 2 if t < 0.65 else 1
        for k in range(w):
            xx = int(round(x)) + k
            if 0 <= xx < TW and 0 <= y < TH:
                shade = tone + (1 if t > 0.7 else 0) - (1 if k == w - 1 and w > 1 else 0)
                img[y, xx] = ramp_[max(0, min(4, shade))] + (255,)


def tuft(design, ramp_):
    """Four designs (`design` 0 to 3; flipped too in the patch): blades fanning from a solid base,
    tapering from three pixels at the foot to one at the tip, the back ones darker, the front ones
    lit on the left (the draft the user liked, 2026-11-19, over rounder puffs), a few more blades
    than that draft so it reads full."""
    rng = random.Random(design * 7 + 1)
    img = np.zeros((TH, TW, 4), np.uint8)
    # The base: the bottom rows filled in the mid-dark green, rounded at its corners.
    for y in range(TH - SOLID, TH):
        inset = max(0, 3 - (y - (TH - SOLID))) if y < TH - SOLID + 3 else 0
        inset = max(inset, 1 if y == TH - 1 else 0)
        for x in range(2 + inset, TW - 2 - inset):
            img[y, x] = ramp_[1] + (255,)
    n = 12 + design % 3
    for i in range(n):
        back = i < n // 2
        x0 = 2 + (TW - 6) * (i + 0.5) / n + rng.uniform(-1, 1)
        lean = (x0 - TW / 2) * rng.uniform(0.5, 0.9) + rng.uniform(-1.5, 1.5)
        height = rng.randint(TH - 6, TH) if not back else rng.randint(TH - 8, TH - 3)
        tone = 1 if back else 2 + (1 if x0 < TW / 2 else 0)
        blade(img, x0, lean, height, rng.uniform(-1, 1), tone, ramp_)
    return img


def darker(img, steps, ramp_):
    """The trampled look: every green a step or two down its ramp."""
    if steps == 0: return img
    out = img.copy()
    for i in range(4, -1, -1):
        m = np.all(img[..., :3] == ramp_[i], axis=-1) & (img[..., 3] > 0)
        out[m, :3] = ramp_[max(0, i - steps)]
    return out


def posed(img, lean, press, shake):
    """A tuft as drawn this frame: each row moved by lean × ((h − 1 − row) / (h − 1))^1.6 in whole
    pixels, squashed toward its base by up to two thirds (its base row kept), never a fraction."""
    h = TH
    p = press * press * (3 - 2 * press)
    h2 = max(1, int(round(h * (1 - 0.67 * p))))
    out = np.zeros_like(img)
    for i in range(h2):
        src = int(round(i * (h - 1) / max(1, h2 - 1))) if h2 > 1 else h - 1
        row = img[src]
        r = h - h2 + i
        k = ((h2 - 1 - i) / (h2 - 1)) ** 1.6 if h2 > 1 else 0
        s = int(math.floor((lean + shake) * k + 0.5))
        out[r] = np.roll(row, s, axis=0)
        if s > 0: out[r, :s] = 0
        if s < 0: out[r, s:] = 0
    return out


# ---------- the patch ----------

class Tuft:
    def __init__(self, x, y, design, flip):
        self.x, self.y, self.design, self.flip = x, y, design, flip
        self.lean = self.vel = 0.0
        self.side = 0
        self.press = 0.0
        self.age = 99.0
        self.cool = 0.0
        self.phase = random.random()
        self.edge = False


def patch(cx, cy, rx, ry, seed=2):
    rng = random.Random(seed)
    tufts = []
    row = 0
    y = cy - ry
    while y <= cy + ry:
        x = cx - rx + (STEP_X / 2 if row % 2 else 0)
        while x <= cx + rx:
            jx, jy = x + rng.uniform(-2, 2), y + rng.uniform(-1, 1)
            d = ((jx - cx) / rx) ** 2 + ((jy - cy) / ry) ** 2
            if d <= 1:
                t = Tuft(int(round(jx)), int(round(jy)), rng.randrange(4), rng.random() < 0.5)
                t.edge = d > 0.72
                tufts.append(t)
            x += STEP_X
        y += STEP_Y; row += 1
    return tufts


def step(tufts, px, py, dt, moving):
    """The spring, the press and the rustle, for a walker with feet at (px, py)."""
    w = 2 * math.pi * SPRING_HZ
    for f in tufts:
        dx, dy = f.x + TW / 2 - px, f.y - py
        near = abs(dx) < 13 and -11 < dy < 9
        if near and f.side == 0: f.side = 1 if dx >= 0 else -1    # keep the side till you're gone
        if not near: f.side = 0
        front = 0 <= dy < 9 and abs(dx) < 9
        most = FRONT_LEAN if front else MAX_LEAN
        target = f.side * most * max(0, 1 - abs(dx) / 13) if near else 0.0
        if abs(target) > 1.5 and f.cool <= 0 and moving:
            f.age, f.cool = 0.0, COOLDOWN
        f.vel += (-w * w * (f.lean - target) - 2 * DAMPING * w * f.vel) * dt
        f.lean = max(-MAX_LEAN, min(MAX_LEAN, f.lean + f.vel * dt))
        behind = -7 <= dy < 0 and abs(dx) < 7 and not f.edge
        goal = 1.0 if behind else 0.0
        rate = dt / PRESS_IN if goal > f.press else dt / PRESS_OUT
        f.press = min(goal, f.press + rate) if goal > f.press else max(goal, f.press - rate)
        f.age += dt; f.cool -= dt


def draw(base, tufts, hero, hx, hy, pics, ramp_):
    """Tufts and the hero sorted by their feet (the hero as if a pixel higher, so a tuft level with
    his feet stands in front), then the wading cut: per column of his frame, hidden from two
    pixels below the top of the grass in front of him, the cut smoothed over five columns and
    never more than 13 rows, scraps under 12 pixels hidden too."""
    img = base.copy()
    H, W = img.shape[:2]
    feet = hy - 1
    behind = [f for f in tufts if f.y < feet]
    front = [f for f in tufts if f.y >= feet]

    def lay(layer, f):
        pic = pics[f.design]
        if f.flip: pic = pic[:, ::-1]
        steps = 2 if f.press > 0.6 else 1 if f.press > 0.3 else 0
        pic = darker(pic, steps, ramp_)
        shake = SHAKE_PX * math.sin(f.age * SHAKE_SPEED + f.phase * 6) if f.age < SHAKE_FOR else 0
        pic = posed(pic, f.lean, f.press, shake)
        x0, y0 = f.x, f.y - TH + 1
        a = pic[..., 3:] / 255
        sl = layer[y0:y0 + TH, x0:x0 + TW]
        if sl.shape[:2] != pic.shape[:2]: return
        sl[..., :3] = sl[..., :3] * (1 - a) + pic[..., :3] * a
        sl[..., 3:] = np.maximum(sl[..., 3:], pic[..., 3:])

    rgba = np.concatenate([img, np.full((H, W, 1), 255, np.uint8)], -1).astype(float)
    for f in sorted(behind, key=lambda f: f.y): lay(rgba, f)
    over = np.zeros((H, W, 4), float)
    for f in sorted(front, key=lambda f: f.y): lay(over, f)

    hh, hw = hero.shape[:2]
    x0, y0 = int(hx - hw // 2), int(hy - hh + 1)
    h = hero.astype(float).copy()
    # The cut, column by column of his frame.
    cut = np.full(hw, hh, float)
    for c in range(hw):
        col = over[y0:y0 + hh, x0 + c, 3] if 0 <= x0 + c < W else np.zeros(hh)
        rows = np.nonzero(col[hh - CUT_MOST - 4:] > 0)[0]
        if len(rows): cut[c] = hh - CUT_MOST - 4 + rows[0] + CUT_BELOW
    sm = np.array([cut[max(0, c - CUT_SMOOTH // 2):c + CUT_SMOOTH // 2 + 1].max() for c in range(hw)])
    sm = np.maximum(sm, hh - CUT_MOST)
    for c in range(hw):
        h[int(sm[c]):, c, 3] = 0
    # Scraps of him left below the cut's line, fewer than 12 pixels, go too.
    lowest = int(sm.min())
    if lowest < hh:
        scrap = h[lowest:, :, 3] > 0
        if 0 < scrap.sum() < CUT_SCRAP: h[lowest:, :, 3] = 0
    a = h[..., 3:] / 255
    sl = rgba[y0:y0 + hh, x0:x0 + hw]
    sl[..., :3] = sl[..., :3] * (1 - a) + h[..., :3] * a
    a = over[..., 3:] / 255
    rgba[..., :3] = rgba[..., :3] * (1 - a) + over[..., :3] * a
    return rgba[..., :3].astype(np.uint8)


def hero_frames():
    sheet = np.asarray(Image.open(pp.R + 'art/sprites/player_walk.png').convert('RGBA'))
    rows = {'up': 0, 'left': 1, 'down': 2, 'right': 3}
    return {d: [sheet[r * 48:(r + 1) * 48, c * 48:(c + 1) * 48] for c in range(4)] for d, r in rows.items()}


def ground(mid, W, H, cx, cy, rx, ry, ramp_):
    """The land's ground, and under the patch one flat dark green so the gaps read as depth."""
    N = 12
    img = np.asarray(pp.draw_scene(mid, pp.maps[mid]['theme'].get('palette'), [['g'] * N for _ in range(N)],
                                   [], W, H, 3, lighting=False).convert('RGB')).copy()
    yy, xx = np.mgrid[0:H, 0:W]
    inside = ((xx - cx - TW / 2) / (rx - 2)) ** 2 + ((yy - cy + 4) / (ry - 1)) ** 2 <= 1
    img[inside] = ramp_[1]
    return img


def walk(mid, frames_out, zoom=3):
    W, H = 220, 150
    cx, cy, rx, ry = 110, 80, 70, 38
    ramp_ = ramp(mid)
    pics = [tuft(d, ramp_) for d in range(4)]
    base = ground(mid, W, H, cx, cy, rx, ry, ramp_)
    tufts = patch(cx, cy, rx, ry)
    heroes = hero_frames()
    # In from the left, through the middle, down, back out to the left, a stop on the way.
    route = [(30, 70), (100, 70), (100, 70), (100, 112), (40, 112), (40, 140)]
    speed = 40.0                       # pixels a second, a walker's pace on screen
    x, y = route[0]
    out = []
    t = 0.0
    sub = 4
    for (gx, gy) in route[1:]:
        while True:
            dx, dy = gx - x, gy - y
            d = math.hypot(dx, dy)
            hold = d < 0.5
            if hold and len(out) % 1 == 0:
                pass
            mv = speed / FPS
            moving = d > 0.5
            if moving:
                x += dx / d * min(d, mv); y += dy / d * min(d, mv)
            for _ in range(sub): step(tufts, x, y, 1 / FPS / sub, moving)
            t += 1 / FPS
            dirn = ('right' if dx > 0 else 'left') if abs(dx) >= abs(dy) else ('down' if dy > 0 else 'up')
            fr = heroes[dirn][int(t * 8) % 4 if moving else 1]
            img = draw(base, tufts, fr, int(round(x)), int(round(y)), pics, ramp_)
            out.append(Image.fromarray(img).resize((W * zoom, H * zoom), Image.NEAREST))
            if not moving:
                for _ in range(int(FPS * 0.8)):
                    for _ in range(sub): step(tufts, x, y, 1 / FPS / sub, False)
                    img = draw(base, tufts, fr, int(round(x)), int(round(y)), pics, ramp_)
                    out.append(Image.fromarray(img).resize((W * zoom, H * zoom), Image.NEAREST))
                break
    out[0].save(frames_out, save_all=True, append_images=out[1:], duration=int(1000 / FPS), loop=0)
    return out


def sheet(mids, path, zoom=4):
    rows = []
    for mid in mids:
        ramp_ = ramp(mid)
        pics = [tuft(d, ramp_) for d in range(4)]
        tiles = []
        for p in pics:
            for v in (p, darker(p, 1, ramp_), darker(p, 2, ramp_), posed(p, 6, 0, 0), posed(p, 0, 1, 0)):
                bg = np.zeros((TH + 4, TW + 4, 3), np.uint8); bg[:] = ramp_[1]
                a = v[..., 3:] / 255
                bg[2:-2, 2:-2] = (bg[2:-2, 2:-2] * (1 - a) + v[..., :3] * a).astype(np.uint8)
                tiles.append(bg)
        rows.append(np.concatenate(tiles, 1))
    img = Image.fromarray(np.concatenate(rows, 0))
    img.resize((img.width * zoom, img.height * zoom), Image.NEAREST).save(path)


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('maps', nargs='*', default=['sunny_meadow', 'twilight_woods', 'frog_swamp'])
    ap.add_argument('-o', '--out', default='grass-preview.png')
    ap.add_argument('--gif')
    args = ap.parse_args()
    if args.gif:
        walk(args.maps[0], args.gif)
    else:
        sheet(args.maps, args.out)
