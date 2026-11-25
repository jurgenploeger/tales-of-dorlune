#!/usr/bin/env python3
"""Caves with the plateaus' look, previewed before they go in the game (the user, 2026-11-25: "The caves should
kinda have that same plateau vibe and the gates should look more like a cave opening instead of a black gap").

Drawn with `tools/cliff_preview.py`'s terraces (the look the user picked for the terraced hills and mountains):

1. Now: a cave's mouth as the game paints it (`HillArt.cave`): a smooth black arch with a thin rim, in a rock face.
2. A cave opening: the same arch in a terraced face, but rough, framed by rocks jutting round it, a
   keystone boulder over it, its inside a tunnel going back: rock walls lit at the edges fading into the
   dark in a few flat steps, its floor running in and fading, a few stalactites hanging from its roof,
   rubble at its feet and the road running in.
3. Inside, now: a cave as the game draws it (the screenshot `cave_in_valley`, if it's in the scratch folder).
4. Inside, as plateaus: the passages the floor (level 0), the rock between them raised a level, each edge a
   sheer face of the cliffs' rock, its top dark rock with a pale lip, lit round you by your lantern.

    python3 tools/cave_preview.py out.png [map] [--now now.png]
    python3 tools/cave_preview.py --handover DIR      # the reference pictures for ChatGPT's cave mouths

Needs pillow + numpy.
"""
import math
import pathlib
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import cliff_preview as cp  # noqa: E402
import palette_preview as pp  # noqa: E402

W, H = 520, 420


def setup(levels, lifts, layout, n=16):
    cp.N, cp.W, cp.H = n, W, H
    cp.LIFTS = lifts
    cp.level_field = levels
    cp.water_field = lambda gx, gy: np.zeros(np.shape(gx), bool)
    cp.layout = layout


# ---- 1, 2: the mouth -------------------------------------------------------------------------------------

MOUTH = (7.6, 7.6)        # its foot, on the face's line (gx + gy = 15.2)


def crag(gx, gy):
    """A crag of two levels: a face across the middle with the mouth in it, a smaller one on top behind."""
    gx, gy = np.asarray(gx, float), np.asarray(gy, float)
    front = gx + gy + 0.6 * np.sin(gx * 0.8) + 0.5 * np.sin(gy * 1.1 + 0.5)
    # Flat across the mouth, so its foot is level.
    near = np.hypot(gx - MOUTH[0], gy - MOUTH[1]) < 2.5
    front = np.where(near, gx + gy, front)
    upper = gx + gy + 0.9 * np.sin(gx * 0.9 + 1) + 0.6 * np.sin(gy * 1.4)
    out = np.where(front >= 15.2, 1, 0)
    return np.where(upper >= 22, 2, out)


def mouth_layout(seed=5):
    keep = []
    for prop in ORIGINAL_LAYOUT(5):
        art, gx, gy, lv, scale = prop
        if art == "player_walk":
            continue
        # Clear in front of the mouth and over it.
        if abs((gx - gy) - (MOUTH[0] - MOUTH[1])) < 4 and lv <= 1 and gx + gy < 20:
            continue
        keep.append(prop)
    keep.append(("player_walk", MOUTH[0] - 2.2, MOUTH[1] - 2.2, 0, 1))
    return keep


def road(img, palette):
    """The road running up to the mouth: the land's path tile, a ragged band toward it."""
    a = np.asarray(img).astype(float) / 255
    path = pp.grade(pp.raw("tile_path"), palette)[..., :3]
    ys, xs = np.mgrid[0:H, 0:W].astype(float)
    gx, gy = cp.grid_of(xs, ys, 0)
    across = (gx - gy) - (MOUTH[0] - MOUTH[1]) + 0.25 * np.sin((gx + gy) * 1.3)
    on = (np.abs(across) < 1.25 + 0.15 * cp.speck(np.floor(gx * 4), np.floor(gy * 4), 5)) & (gx + gy < 15.2) & (gx + gy > 4)
    flat = cp.level_field(gx, gy) == 0
    S = path.shape[0]
    u = ((gx % 1) * S).astype(int).clip(0, S - 1)
    v = ((1 - gy % 1) * S).astype(int).clip(0, S - 1)
    # Only over the ground (not where a prop or the face already is): the ground's own pixels, found by
    # being greenish-bright, is too fragile, so drawn before the props instead (`render_mouth`).
    a = np.where((on & flat)[..., None], path[v, u] * 0.95, a)
    return a


def arch_points(half, tall, rough, seed):
    """The opening's outline on screen, from its left foot up over its top to its right foot, rough:
    each point pushed in or out a pixel or three, in runs, as broken rock is."""
    rng = random.Random(seed)
    pts = []
    steps = 30
    jag = 0.0
    for k in range(steps + 1):
        u = k / steps
        x = (2 * u - 1) * half
        bulge = max(0.0, 1 - (2 * u - 1) ** 2) ** 0.5
        if 0 < k < steps:
            jag = max(-rough, min(rough, jag + rng.choice([-1.5, -1, 0, 0, 1, 1.5])))
        else:
            jag = 0
        y = 0.1 * tall + 0.9 * tall * bulge + jag
        pts.append((x, y))
    return pts


def inside_mask(pts, foot):
    fx, fy = foot
    im = Image.new("L", (W, H), 0)
    poly = [(fx + x, fy - y) for x, y in pts]
    ImageDraw.Draw(im).polygon(poly, fill=255)
    return np.asarray(im) > 0


def distance_in(mask, reach=14):
    """How many pixels in from the mask's edge each pixel is (4-neighbour steps), up to `reach`."""
    d = np.where(mask, reach, 0).astype(float)
    edge = mask.copy()
    cur = mask.copy()
    for k in range(reach):
        shrunk = cur.copy()
        shrunk[1:] &= cur[:-1]
        shrunk[:-1] &= cur[1:]
        shrunk[:, 1:] &= cur[:, :-1]
        shrunk[:, :-1] &= cur[:, 1:]
        d = np.where(cur & ~shrunk, k, d)
        cur = shrunk
    return d


def paste(img, sprite, x0, y0):
    h, w = sprite.shape[:2]
    xa, ya, xb, yb = max(0, x0), max(0, y0), min(W, x0 + w), min(H, y0 + h)
    if xa >= xb or ya >= yb:
        return
    part = sprite[ya - y0:yb - y0, xa - x0:xb - x0]
    a = (part[..., 3:] > 0.5).astype(float)
    img[ya:yb, xa:xb] = img[ya:yb, xa:xb] * (1 - a) + part[..., :3] * a


def old_mouth(img, foot, half, tall):
    """As `HillArt.cave` paints it now: a smooth arch, black at its top and a little lighter at its floor,
    a dark line round it, a faint pale lip over it."""
    pts = arch_points(half, tall, 0, 1)
    rim = arch_points(half + 6, tall + 8, 0, 1)
    d = ImageDraw.Draw(img, "RGBA")
    fx, fy = foot
    d.line([(fx + x, fy - y) for x, y in rim], fill=(0, 0, 0, 76), width=3)
    d.line([(fx + x, fy - y - 2) for x, y in arch_points(half + 4, tall + 6, 0, 1)[3:-3]], fill=(255, 255, 255, 76), width=1)
    a = np.asarray(img).astype(float) / 255
    m = inside_mask(pts, foot)
    ys = np.mgrid[0:H, 0:W][0].astype(float)
    t = np.clip((fy - ys) / (tall * 0.6), 0, 1)[..., None]
    col = np.array([0.13, 0.11, 0.14]) * (1 - t) + np.array([0.02, 0.02, 0.03]) * t
    a[..., :3] = np.where(m[..., None], col, a[..., :3])
    img = Image.fromarray((a.clip(0, 1) * 255).astype(np.uint8))
    ImageDraw.Draw(img).line([(fx + x, fy - y) for x, y in pts], fill=(0, 0, 0), width=2)
    return img


def new_mouth(img, foot, half, tall, palette):
    """A cave opening: rough rock round it, a tunnel going back into the dark."""
    a = np.asarray(img).astype(float)[..., :3] / 255
    fx, fy = foot
    rock = pp.grade(pp.raw("tile_cliff_rock"), palette)[..., :3]
    floor = pp.grade(pp.raw("tile_path"), palette)[..., :3]
    global ROCK_MEAN
    ROCK_MEAN = rock.reshape(-1, 3).mean(0) * 1.15
    ys, xs = np.mgrid[0:H, 0:W].astype(float)
    pts = arch_points(half, tall, 3, 7)
    hole = inside_mask(pts, foot)
    # A shadow round the opening on the face, where the rock turns in: two pixels darker all round.
    ring = distance_in(inside_mask(arch_points(half + 4, tall + 4, 3, 7), foot), 5)
    a = np.where((ring > 0)[..., None] & ~hole[..., None], a * 0.62, a)
    # Inside: the tunnel's walls, lit at the edge, stepping down into black (four flat tones, dithered
    # where one gives way to the next).
    depth = distance_in(hole, 16)
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16
    dither = bayer[ys.astype(int) % 4, xs.astype(int) % 4]
    step = np.floor(np.clip(depth / 4.2 + dither * 0.9, 0, 4))
    shade = np.array([0.62, 0.36, 0.18, 0.07, 0.03])[step.astype(int)]
    tex = rock[(ys.astype(int) % rock.shape[0]), (xs.astype(int) % rock.shape[1])]
    # The walls lit from the opening's left (the light's from the top left): its right inside wall brighter.
    side = np.clip(1 + 0.35 * (xs - fx) / half, 0.7, 1.35)[..., None]
    wall = tex * (shade[..., None] * side)
    wall = np.where((step >= 4)[..., None], np.array([0.03, 0.025, 0.04]), wall)
    # Its floor: the road running in, darker the further in, gone into the black about a third of the way up.
    up = fy - ys
    across = np.abs(xs - fx)
    on_floor = hole & (up < tall * 0.32) & (across < half * (0.75 - up / (tall * 1.2)))
    ftex = floor[(ys.astype(int) % floor.shape[0]), (xs.astype(int) % floor.shape[1])]
    fstep = np.floor(np.clip(up / (tall * 0.09) + dither * 0.9, 0, 4)).astype(int)
    fshade = np.array([0.8, 0.55, 0.32, 0.15, 0.05])[fstep]
    wall = np.where(on_floor[..., None], ftex * fshade[..., None], wall)
    a = np.where(hole[..., None], wall, a)
    # Under its roof, a dark band: the overhang.
    roof = hole & (depth <= 2) & (up > tall * 0.45)
    a = np.where(roof[..., None], a * 0.45, a)
    img = (a * 255).astype(np.uint8)
    out = np.asarray(Image.fromarray(img)).astype(float) / 255
    # Stalactites hanging from its roof.
    rng = random.Random(3)
    for k in range(4):
        x = fx + (k - 1.5) * half * 0.42 + rng.uniform(-3, 3)
        top_y = None
        for y in range(int(fy - tall - 6), int(fy)):
            if 0 <= int(x) < W and hole[y, int(x)]:
                top_y = y
                break
        if top_y is None:
            continue
        length = rng.randint(4, 8)
        for j in range(length):
            w = max(0, int(2.5 * (1 - j / length)))
            for dx in range(-w, w + 1):
                xx, yy = int(x) + dx, top_y + j
                if 0 <= xx < W and 0 <= yy < H:
                    lit = 1.0 if dx < 0 else 0.7
                    out[yy, xx] = rock[yy % rock.shape[0], xx % rock.shape[1]] * 0.55 * lit
    # Rocks jutting round it: boulders along the outline, outside it, a big one over the top.
    for k, (x, y) in enumerate(arch_points(half + 5, tall + 5, 2, 11)[::3]):
        if y < tall * 0.15:
            continue
        b = cp.boulder(40 + k, rng.randint(14, 20))
        b = darken_bottom(b)
        paste(out, b, int(fx + x - b.shape[1] / 2), int(fy - y - b.shape[0] / 2))
    key = cp.boulder(77, 30)
    paste(out, darken_bottom(key), int(fx - 15), int(fy - tall - 20))
    # Rubble at its feet, either side of the road.
    for k, dx in enumerate((-half - 9, -half - 2, half + 3, half + 10)):
        b = darken_bottom(cp.boulder(90 + k, rng.randint(9, 13)))
        paste(out, b, int(fx + dx - b.shape[1] / 2), int(fy - b.shape[0] + 2 + rng.randint(-2, 2)))
    return Image.fromarray((out.clip(0, 1) * 255).astype(np.uint8))


ROCK_MEAN = np.array([0.6, 0.55, 0.5])


def darken_bottom(b):
    """A boulder framing the opening, in the face's own rock colour: its lower half a shade darker,
    turned in toward the dark."""
    b = b.copy()
    lum = b[..., :3].mean(-1, keepdims=True)
    b[..., :3] = np.where(b[..., 3:] > 0, lum / 0.62 * ROCK_MEAN, b[..., :3])
    h = b.shape[0]
    b[h // 2:, :, :3] *= 0.8
    return b


def render_mouth(mid, new):
    setup(crag, [0, 96, 150], mouth_layout)
    palette = pp.maps[mid]["theme"].get("palette")
    # The road under everything: drawn by laying the path tile over level 0 before the props; the
    # simplest way is to render without props, lay the road, then lay the props over again.
    props_layout = cp.layout
    cp.layout = lambda seed=5: []
    bare = cp.render(mid, True)
    cp.layout = props_layout
    full = cp.render(mid, True)
    a_bare = np.asarray(bare).astype(float) / 255
    a_full = np.asarray(full).astype(float) / 255
    with_road = road(bare, palette)
    # Where the props drew (the full render differs from the bare one), keep them over the road.
    props = np.abs(a_full - a_bare).sum(-1) > 0.01
    a = np.where(props[..., None], a_full, with_road)
    img = Image.fromarray((a.clip(0, 1) * 255).astype(np.uint8))
    foot = cp.screen_of(MOUTH[0], MOUTH[1], 0)
    foot = (foot[0], foot[1] - 1)
    half, tall = 30, 70
    return new_mouth(img, foot, half, tall, palette) if new else old_mouth(img, foot, half, tall)


# ---- 3, 4: inside -------------------------------------------------------------------------------------------

def passages(gx, gy):
    """A cave's passages as the floor (0) and the rock between them raised (1): a winding passage two
    cells wide, a room where it turns, a side passage off it."""
    gx, gy = np.asarray(gx, float), np.asarray(gy, float)
    main = np.abs((gx - gy) - 2.0 * np.sin((gx + gy) * 0.28)) < 1.6
    room = np.hypot(gx - 8.5, gy - 8.0) < 3.2 + 0.4 * np.sin(np.arctan2(gy - 8, gx - 8.5) * 3)
    side = (np.abs(gy - 9.0 - 0.6 * np.sin(gx * 0.7)) < 1.1) & (gx > 8)
    open_ = main | room | side
    inside = (gx >= 0) & (gy >= 0) & (gx < cp.N) & (gy < cp.N)
    return np.where(open_ | ~inside, 0, 1)


def inside_layout(seed=5):
    rng = random.Random(seed)
    props = []
    for gy in range(cp.N):
        for gx in range(cp.N):
            cx, cy = gx + 0.5, gy + 0.5
            if passages(cx, cy) != 0 or rng.random() > 0.06:
                continue
            # Not right in the way: a cell from the rock's foot.
            if all(passages(cx + dx, cy + dy) == 0 for dx in (-1, 1) for dy in (-1, 1)):
                continue
            props.append((rng.choice(["stalagmite", "rock_formation_small"]), cx, cy, 0, rng.uniform(0.5, 0.75)))
    props.append(("player_walk", 8.2, 7.6, 0, 1))
    return props


def render_inside(mid):
    setup(passages, [0, 64], inside_layout)
    palette = pp.maps[mid]["theme"].get("palette")
    real_raw = pp.raw

    def cave_raw(i, depth=0):
        return real_raw({"tile_rich_grass": "tile_cave_floor", "tile_cliff_rock": "tile_cave_rock"}.get(i, i), depth)
    pp.raw = cave_raw
    try:
        img = cp.render(mid, True)
    finally:
        pp.raw = real_raw
    a = np.asarray(img).astype(float) / 255
    ys, xs = np.mgrid[0:H, 0:W].astype(float)
    # The rock's top: dark rock, its lip a pale line where it meets the face.
    gx, gy = cp.grid_of(xs, ys, cp.LIFTS[1])
    top = passages(gx, gy) == 1
    lip = top & (passages(gx - 0.12, gy - 0.12) == 0)
    rock = pp.grade(pp.raw("tile_cave_rock"), palette)[..., :3]
    tex = rock[(ys.astype(int) % rock.shape[0]), (xs.astype(int) % rock.shape[1])]
    # Its top lighter than the floor (the floor's down in the dark), with broad shading so it reads as rock.
    a = np.where(top[..., None], tex * 0.95, a)
    a = np.where(lip[..., None], np.minimum(1, tex * 1.35 + 0.06), a)
    # Your lantern's light: full round you, falling off in hard steps into the dark.
    px, py = cp.screen_of(8.2, 7.6, 0)
    d = np.hypot((xs - px) / 1.0, (ys - py + 14) / 0.75)
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16
    step = np.floor(np.clip((d - 90) / 38 + bayer[ys.astype(int) % 4, xs.astype(int) % 4] * 0.8, 0, 4)).astype(int)
    light = np.array([1.0, 0.72, 0.48, 0.28, 0.14])[step]
    a = a * light[..., None] * np.array([1.0, 0.97, 0.9])
    return Image.fromarray((a.clip(0, 1) * 255).astype(np.uint8))


def label(img, text):
    d = ImageDraw.Draw(img)
    d.rectangle([4, 4, 12 + 6 * len(text), 18], fill=(20, 24, 40))
    d.text((8, 6), text, fill=(255, 255, 255))
    return img


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    if argv[0] == "--handover":
        handover(argv[1])
        return 0
    out = argv[0]
    mid = argv[1] if len(argv) > 1 and not argv[1].startswith("--") else "valley_of_fear"
    now = argv[argv.index("--now") + 1] if "--now" in argv else None
    global ORIGINAL_LAYOUT
    ORIGINAL_LAYOUT = cp.layout
    shots = [label(render_mouth(mid, False), "mouth now"), label(render_mouth(mid, True), "a cave opening")]
    cp.layout = ORIGINAL_LAYOUT
    inside = [label(render_inside("rat_cavern"), "inside, as plateaus")]
    if now:
        im = Image.open(now).convert("RGB")
        im = im.crop((0, int(im.height * 0.3), im.width, int(im.height * 0.3) + int(im.width * H / W)))
        inside.insert(0, label(im.resize((W, H), Image.LANCZOS), "inside now"))
    rows = [shots, inside]
    sheet = Image.new("RGB", (2 * W + 8, len(rows) * (H + 8) - 8), (20, 20, 24))
    for r, row in enumerate(rows):
        for c, s in enumerate(row):
            sheet.paste(s, (c * (W + 8), r * (H + 8)))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(out)
    print(out)
    return 0


# ---- ChatGPT's hand-off (docs/ai-sprite-test/cave-mouths) -------------------------------------------------------

# A cave mouth's canvas and its opening, in its pixels (one a point in the game): the opening at the bottom
# middle, its sides straight up from the foot row and its top an arch; the road runs in along the bottom row.
MOUTH_W, MOUTH_H = 128, 80
OPEN_X0, OPEN_X1, OPEN_TOP, OPEN_SIDE = 20, 107, 24, 52
FLOOR_ROWS = 8


def opening_mask():
    """The opening's zone on the canvas: straight sides from the foot (row 79) up to OPEN_SIDE, an arch
    over them up to OPEN_TOP."""
    m = np.zeros((MOUTH_H, MOUTH_W), bool)
    cx, half = (OPEN_X0 + OPEN_X1) / 2, (OPEN_X1 - OPEN_X0 + 1) / 2
    for x in range(OPEN_X0, OPEN_X1 + 1):
        u = (x + 0.5 - cx) / half
        top = OPEN_SIDE - (OPEN_SIDE - OPEN_TOP) * max(0.0, 1 - u * u) ** 0.5
        m[int(round(top)):, x] = True
    return m


def layout_guide():
    """The zones at 8x: grey outside (the cliff shows), sandy the rock frame (at least 6 pixels round the
    opening, ragged out toward the edges), dark blue the opening, orange its floor where the road runs in,
    and a white line on the foot row."""
    m = opening_mask()
    grow = m.copy()
    for _ in range(6):
        g = grow.copy()
        g[1:] |= grow[:-1]
        g[:-1] |= grow[1:]
        g[:, 1:] |= grow[:, :-1]
        g[:, :-1] |= grow[:, 1:]
        grow = g
    img = np.zeros((MOUTH_H, MOUTH_W, 3), np.uint8)
    img[:] = (128, 128, 128)
    img[grow & ~m] = (214, 176, 120)
    img[m] = (40, 46, 96)
    floor = m.copy()
    floor[:MOUTH_H - FLOOR_ROWS] = False
    img[floor] = (232, 140, 60)
    big = Image.fromarray(img).resize((MOUTH_W * 8, MOUTH_H * 8), Image.NEAREST)
    d = ImageDraw.Draw(big)
    d.line([(0, MOUTH_H * 8 - 4), (MOUTH_W * 8, MOUTH_H * 8 - 4)], fill=(255, 255, 255), width=2)
    for x in range(0, MOUTH_W * 8, 8 * 8):
        d.line([(x, 0), (x, MOUTH_H * 8)], fill=(150, 150, 150), width=1)
    return big


def handover(out):
    out = pathlib.Path(out)
    out.mkdir(parents=True, exist_ok=True)
    global ORIGINAL_LAYOUT
    ORIGINAL_LAYOUT = cp.layout
    layout_guide().save(out / "layout_guide_8x.png")
    # The cliff face a mouth goes in, as the terraced hills draw it: the bare crag, cropped round the mouth's foot.
    mid = "valley_of_fear"
    setup(crag, [0, 96, 150], lambda seed=5: [])
    bare = cp.render(mid, True)
    fx, fy = cp.screen_of(MOUTH[0], MOUTH[1], 0)
    box = (int(fx - 110), int(fy - 120), int(fx + 110), int(fy + 20))
    face = bare.crop(box)
    face.save(out / "cliff_face_1x.png")
    face.resize((face.width * 4, face.height * 4), Image.NEAREST).save(out / "cliff_face_4x.png")
    # What it is now and what code made of it, both on that face.
    cp.layout = ORIGINAL_LAYOUT
    for name, new in (("mouth_now_4x.png", False), ("mouth_code_4x.png", True)):
        shot = render_mouth(mid, new).crop(box)
        shot.resize((shot.width * 4, shot.height * 4), Image.NEAREST).save(out / name)
    print(out)


ORIGINAL_LAYOUT = None

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
