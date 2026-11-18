#!/usr/bin/env python3
"""Each land as the game shows it, for the website's banners: `view` draws a wide stretch of it at the
game's own angle (tools/palette_preview.py `draw_scene`: its ground turned and laid back, a road, a
pond, its scenery, a town's buildings, the hero and a companion on the road). `scene` is the older
side-on strip, kept for the sheet below. Used by export.py; `python3 website/tools/scenes.py out.png
[land ids]` writes a sheet to look at."""
import os, sys, random, zlib
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import palette_preview as pp  # noqa: E402

W, H, GROUND = 480, 132, 30
TILES = ('tile_', 'sea')


def img(arr):
    return Image.fromarray((np.clip(arr, 0, 1) * 255).round().astype(np.uint8), 'RGBA')


def prop(art, palette):
    try:
        im = img(pp.sprite(art, palette))
    except Exception:
        return None
    box = im.getbbox()
    return im.crop(box) if box else None


def haze(im, colour, amount):
    """A far thing takes on the sky's colour."""
    a = np.asarray(im).astype(float) / 255
    a[..., :3] = a[..., :3] * (1 - amount) + np.array(colour) * amount
    return img(a)


def sky_of(m):
    """The sky behind a land, top and bottom: a cave's dark, a dusk over the dark woods, else the brand's day."""
    theme = m['theme']
    tile = pp.grade(pp.raw(theme['ground']), theme.get('palette'))[..., :3].reshape(-1, 3).mean(0)
    light = float(tile @ np.array([0.299, 0.587, 0.114]))
    if m.get('depth') is not None or 'cave' in m['id'] or 'cavern' in m['id'] or 'glimmerdeep' in m['id']:
        return ['#161a33', '#2b2f55']
    if light < 0.3:
        return ['#1d2a6b', '#6b62b8']
    if m.get('climate') == 'cold':
        return ['#7fb4ea', '#e6f3ff']
    if m.get('climate') == 'hot':
        return ['#4a90e8', '#ffe2b0']
    return ['#4a90e8', '#c9e9ff']


def scene(m, seed=None, width=None):
    W = width or globals()['W']
    theme = m['theme']; palette = theme.get('palette')
    rng = random.Random(seed if seed is not None else zlib.crc32(m['id'].encode()))
    out = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    sky = np.array([int(sky_of(m)[1][i:i + 2], 16) / 255 for i in (1, 3, 5)])
    tall, low = [], []
    for p in theme.get('props', []):
        s = prop(p['art'], palette)
        if s is None or s.width > 150: continue
        (tall if s.height >= 34 else low).append((s, p.get('count', 1)))
    houses = [s for s in (prop(b['art'], palette) for b in m.get('buildings', [])[:8 * W // 480]) if s is not None and s.height <= H - GROUND + 6]
    base = H - GROUND

    def put(s, x, y):
        """Sets s down, and again a scene's width to the left where it runs off the right edge, so the scene tiles."""
        layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        layer.paste(s, (x, y)); layer.paste(s, (x - W, y), s)
        out.alpha_composite(layer)

    def row(things, y, step, amount, scale=1.0, jitter=6):
        if not things: return
        x = rng.randint(0, 10)
        weights = [c for _, c in things]
        while x < W:
            s = rng.choices([t for t, _ in things], weights)[0]
            if scale != 1.0: s = s.resize((max(1, round(s.width * scale)), max(1, round(s.height * scale))), Image.NEAREST)
            if amount: s = haze(s, sky, amount)
            put(s, x, y - s.height + rng.randint(0, 3))
            x += max(8, int(s.width * step) + rng.randint(-jitter, jitter))

    row(tall, base + 2, 0.62, 0.55, 0.75)                 # far
    row(tall, base + 4, 1.25, 0.25)                        # middle
    # the ground: the land's own tile in a strip, its top edge lit, darker toward the foot
    tile = pp.grade(pp.raw(theme['ground']), palette)
    strip = np.zeros((GROUND, W, 4)); reps = W // 32 + 1
    band = np.concatenate([tile[:GROUND]] * reps, 1)[:, :W]
    strip[:] = band; strip[..., 3] = 1
    shade = np.linspace(1.0, 0.72, GROUND)[:, None, None]
    strip[..., :3] *= shade; strip[0, :, :3] = np.clip(strip[0, :, :3] * 1.25 + 0.05, 0, 1); strip[1, :, :3] *= 1.1
    out.alpha_composite(img(strip), (0, base))
    if houses:                                             # a town: its buildings along the street
        x = rng.randint(10, 40)
        for s in houses:
            if x + s.width > W - 10: break
            put(s, x, base + 8 - s.height); x += s.width + rng.randint(14, 40)
    row([(s, c) for s, c in low], base + 12, 2.6, 0, jitter=14)  # near: flowers, bushes, rocks
    return out


if __name__ == '__main__':
    ids = sys.argv[2:] or ['meadowbrook', 'sunny_meadow', 'twilight_woods', 'snow_white_forest', 'genie_desert', 'candy_mountain', 'rat_cavern', 'starfall_isle']
    sheet = Image.new('RGB', (W * 2, (H * 2 + 6) * len(ids)))
    for n, i in enumerate(ids):
        m = pp.maps[i]; top, bottom = sky_of(m)
        bg = Image.new('RGB', (W, H)); px = np.linspace(0, 1, H)[:, None]
        t = np.array([int(top[k:k + 2], 16) for k in (1, 3, 5)]); b = np.array([int(bottom[k:k + 2], 16) for k in (1, 3, 5)])
        bg = Image.fromarray(np.repeat((t * (1 - px) + b * px)[:, None, :], W, 1).astype(np.uint8))
        bg.paste(scene(m), (0, 0), scene(m))
        sheet.paste(bg.resize((W * 2, H * 2), Image.NEAREST), (0, n * (H * 2 + 6)))
    sheet.save(sys.argv[1])


def clouds(width=640, height=96, seed=7):
    """A band of pixel clouds that tiles side to side: white, their undersides in the brand's cloud shade."""
    rng = random.Random(seed)
    a = np.zeros((height, width), int)
    yy, xx = np.mgrid[0:height, 0:width]
    for _ in range(9):
        cx, cy, n = rng.randint(0, width), rng.randint(26, height - 22), rng.randint(3, 6)
        for k in range(n):
            px = cx + (k - n / 2) * rng.randint(11, 16); r = rng.randint(9, 17) - abs(k - n / 2) * 1.5
            py = cy - rng.randint(0, 6)
            for wrap in (-width, 0, width):
                puff = ((xx - px - wrap) ** 2 + ((yy - py) * 1.25) ** 2 <= r * r) & (yy <= cy + 5)
                a[puff] = np.maximum(a[puff], 2)
                a[puff & (yy > py + r * 0.28)] = 1
    out = np.zeros((height, width, 4))
    out[a == 2] = (1, 1, 1, 1); out[a == 1] = (0xEA / 255, 0xF4 / 255, 1, 1)
    return img(out)


def view(m, width=1100, height=230, seed=None, people=True):
    """A wide stretch of the land at the game's angle: a road winding across the screen, a pond and an
    accent patch, its scenery as thick as the land has it, a town's buildings along the road."""
    theme = m['theme']; rng = random.Random(seed if seed is not None else zlib.crc32(m['id'].encode()))
    N = int(width / 62 + height / 31) + 4
    kinds = [['g'] * N for _ in range(N)]
    road = set(); bend = 0
    for d in range(-N, N):            # along the screen: cells whose column and row add up to the same
        if rng.random() < 0.3: bend = max(-2, min(2, bend + rng.choice([-1, 1])))
        for k in (0, 1):
            c = (N - 1 + bend + k + d) // 2 + (1 if (N - 1 + bend + k + d) % 2 and d % 2 else 0); r = N - 1 + bend + k - c
            c = (N + d) // 2 + bend + k; r = (N - d) // 2 - 1
            if 0 <= c < N and 0 <= r < N: kinds[r][c] = 'p'; road.add((c, r))
    def patch(kind, cx, cy, size):
        for r in range(N):
            for c in range(N):
                if (c - cx) ** 2 + (r - cy) ** 2 < size and kinds[r][c] == 'g': kinds[r][c] = kind
    mid = N // 2
    if theme.get('water'): patch('w', mid + rng.randint(6, 9), mid + rng.randint(-1, 2) + 6, 7)
    items, taken = [], set(road)
    near = lambda c, r: min(abs(c - a) + abs(r - b) for a, b in road)
    spots = [(c, r) for c in range(N) for r in range(N) if kinds[r][c] == 'g']
    if 'town' in m:                   # the buildings stand back from the road, on its far side
        row = sorted((c, r) for c, r in spots if near(c, r) == 2 and c + r > N + 1)
        for b, (c, r) in zip(m.get('buildings', []), row[2::4]):
            if pp.assets.get(b['art']): items.append((b['art'], c, r, 1)); taken |= {(c + i, r + j) for i in (-1, 0, 1) for j in (-1, 0, 1)}
    area = m['width'] * m['height']
    for p in theme['props']:
        if p.get('within') or p['art'] not in pp.assets: continue
        n = min(60, max(1, round(p['count'] / area * N * N * (0.5 if 'town' in m else 1.6))))
        for _ in range(n):
            c, r = rng.choice(spots)
            if (c, r) in taken or near(c, r) < 2: continue
            taken.add((c, r)); lo, hi = p.get('size', [1, 1]); items.append((p['art'], c, r, rng.uniform(lo, hi)))
    if people:
        c, r = min(road, key=lambda t: abs(t[0] - mid + 2) + abs(t[1] - mid - 2))
        items.append(('player_walk', c, r, 1)); items.append(('pet_walk', c + 1, r, 1))
    im = pp.draw_scene(m['id'], theme.get('palette'), kinds, items, width, height, seed=rng.randint(0, 99), focus=False)
    return im.quantize(160, dither=Image.Dither.NONE)   # a pixel-art palette, and a file a quarter the size
