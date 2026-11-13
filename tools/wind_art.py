#!/usr/bin/env python3
"""Trees and bushes in the wind, every pixel whole (art/wind.json, `WindRig` in TalesOfDorlune/Art/Wind.swift).

Turning a tree to sway it, as the game did, bent its trunk with its crown and smeared its pixels off the
grid. Here, after SpriteCook's "How to make pixel art trees move in the wind" (2025-11): the trunk stays
put and the crown moves in clumps, each a bright puff of leaves with the dark crevices round it as its
borders, a whole pixel at a time.

- Each sprite is split into what stays (trunk, roots, the snow or pond at its foot) and its leaf clumps
  (`split`): the leaves told from the wood by their colours (the crown's top against the trunk's foot),
  cut into clumps by flooding out from each bright spot down to the dark lines between them.
- Under the clumps the crown is drawn again darker (`INSIDE`), so a gap opening between two shows the
  shade inside the tree, never the ground behind it.
- Calm: each clump walks a little loop, one pixel up and over and back (`LOOP` frames, 10 a second), the
  clumps round the edge more than those inside (`flex`), timed by how far across the tree they sit, so
  a ripple runs through the crown and on to the next tree (`WAVELENGTH`, the game times each tree by
  where it stands).
- Gusts: a gust (`GUST` frames) bows the crown downwind, the top more than the bottom, then lets it
  spring back past upright, bounce and settle (`push`): a bouncy, storybook sway, not a storm.

Every rig is its sprite's pixels moved, never redrawn, so it's the same for RD's art and ours, and for
every recolour and land palette of it (the game cuts the frames out of the sprite as it's graded).
A palette swap with no PNG of its own (`big_tree`, `frost_pine`) moves as its base does.

    python3 tools/wind_art.py                     # writes art/wind.json
    python3 tools/wind_art.py check               # each rig still fits its sprite (check_content.py runs it)
    python3 tools/wind_art.py --sheet out.png     # every sprite's clumps, coloured
    python3 tools/wind_art.py --gif out.gif [ids] # a grove in the wind, calm and through a gust

Needs pillow, numpy and scipy. Rerun after redrawing or regenerating any sprite it rigs.
"""

import heapq
import json
import math
import pathlib
import sys

import numpy as np
from PIL import Image
try:
    from scipy import ndimage  # splitting only: `check` runs without it (check_content.py)
except ImportError:
    ndimage = None

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPRITES = ROOT / "art" / "sprites"
OUT = ROOT / "art" / "wind.json"

FPS = 10
LOOP = 16          # frames in the calm loop (1.6 s)
GUST = 32          # frames in a gust, two loops long (3.2 s)
WAVELENGTH = 128   # points between the crests of the ripple running across the trees
# The crown drawn again under its clumps, darker and a little cooler: the shade inside the tree.
INSIDE = (0.52, 0.56, 0.68)

# What moves, by kind:
#   calm: how far (pixels) an edge clump's loop reaches in still air; gust: how far at a gust's height,
#   push: how far a gust bows the top of the crown; period: seconds a swing back and forth takes
#   (the spring), dip: how far the top drops as it bows, sep: how far apart bright spots must be to be
#   two clumps; foot: rows at the bottom that never move (a bush's base on the ground).
KINDS = {
    "tree": dict(dip=1.0, calm=1.0, gust=2.2, push=3.5, period=2.2, sep=7, min_px=14),
    "pine": dict(dip=0.6, calm=1.0, gust=2.0, push=3.0, period=2.4, sep=6, min_px=10),
    "palm": dict(dip=1.2, calm=1.0, gust=2.4, push=3.0, period=2.0, sep=7, min_px=12),
    "bush": dict(dip=0.8, calm=0.8, gust=1.8, push=2.0, period=1.0, sep=5, min_px=8, foot=3),
}

# Every sprite that moves in the wind, and how. `crown`: the lowest row of its crown where the colours
# can't tell (a tree with grass or a pond at its foot); `tiers` for a conifer, cut by its branch tiers.
# Bare trees (dead_tree, frost_tree: twigs) don't: snow and twigs would come apart; nor the lilac bush,
# its crystals stiff.
RIGS = {
    # RD's own
    "tree": dict(kind="tree"),
    "apple_tree": dict(kind="tree"),
    "beehive_tree": dict(kind="tree"),
    "hollow_tree": dict(kind="tree"),
    "snow_tree": dict(kind="tree"),
    "palm_tree": dict(kind="palm"),
    "oasis_palm": dict(kind="palm"),
    "snow_pine": dict(kind="pine"),
    "berry_bush": dict(kind="bush"),
    "frozen_bush": dict(kind="bush", calm=0.0),
    "thorn_bush": dict(kind="bush"),
    "fern": dict(kind="bush"),
    # drawn in code (tools/scenery_art.py)
    "blossom_tree": dict(kind="tree"),
    "dark_tree": dict(kind="tree"),
    "autumn_tree": dict(kind="tree"),
    "red_maple": dict(kind="tree"),
    "golden_tree": dict(kind="tree"),
    "swamp_tree": dict(kind="tree"),
    "lilac_tree": dict(kind="tree"),
    "candy_tree_lemon": dict(kind="tree"),
    "candy_tree_peach": dict(kind="tree"),
    "candy_tree_sky": dict(kind="tree"),
    "bush": dict(kind="bush"),
    "flowering_bush": dict(kind="bush"),
    "autumn_bush": dict(kind="bush"),
    "moss_bush": dict(kind="bush", by_colour=True),   # the moss moves, its stone doesn't
    "dark_bush": dict(kind="bush"),
    "golden_bush": dict(kind="bush"),
    "pine_sapling": dict(kind="pine"),
    "snow_sapling": dict(kind="pine", crown=24),
    "sapling": dict(kind="bush"),
}


def load(art_id):
    return np.asarray(Image.open(SPRITES / f"{art_id}.png").convert("RGBA")).astype(np.int32)


def settings(art_id):
    spec = RIGS[art_id]
    out = dict(KINDS[spec["kind"]])
    out.update(spec)
    return out


# Splitting -------------------------------------------------------------------------------------------

def luma(px):
    return px[..., 0] * 0.299 + px[..., 1] * 0.587 + px[..., 2] * 0.114


def crown_mask(px, cfg):
    """The pixels that move: the crown's, told from the wood's and the ground's by colour."""
    solid = px[..., 3] > 0
    rows = np.nonzero(solid.any(axis=1))[0]
    top, bottom = int(rows.min()), int(rows.max())
    height = bottom - top + 1
    mask = solid.copy()
    if cfg["kind"] == "pine" and "crown" in cfg:
        # Snow on its branches is the colour of the snow it stands in: cut by rows instead.
        mask[cfg["crown"] + 1:] = False
        return mask
    if cfg["kind"] == "bush":
        mask[bottom - cfg.get("foot", 3) + 1:] = False
        if not cfg.get("by_colour"):
            return mask
    # The crown's own colours from its top fifth, the wood's (and the ground's) from its foot.
    leaf = np.unique(px[top:top + max(3, height // 5)][solid[top:top + max(3, height // 5)]][:, :3], axis=0)
    foot_rows = slice(bottom - max(3, height // 6) + 1, bottom + 1)
    wood = np.unique(px[foot_rows][solid[foot_rows]][:, :3], axis=0)
    colours = px[..., :3].reshape(-1, 3)

    def nearest(ref):
        d = ((colours[:, None, :] - ref[None, :, :]) ** 2).sum(axis=2)
        return d.min(axis=1).reshape(px.shape[:2])

    is_leaf = nearest(leaf) <= nearest(wood)
    mask &= is_leaf
    if cfg["kind"] == "bush":
        return mask
    # The crown ends where its rows stop being mostly leaves (or where `crown` says).
    low = cfg.get("crown")
    if low is None:
        low = top
        for y in range(top, bottom + 1):
            row = solid[y]
            if row.sum() and (mask[y].sum() / row.sum() >= 0.35 or y - top < height // 3):
                low = y
            elif y - top >= height // 3:
                break
    mask[low + 1:] = False
    # Specks of leaf colour on the trunk stay with it.
    labels, n = ndimage.label(mask)
    for k in range(1, n + 1):
        if (labels == k).sum() < 6:
            mask[labels == k] = False
    return mask


def seeds(bright, mask, sep):
    """The middles of the bright spots, at least `sep` apart: one clump each."""
    peaks = (bright == ndimage.maximum_filter(np.where(mask, bright, -1), size=sep)) & mask
    labels, n = ndimage.label(peaks)
    points = ndimage.center_of_mass(peaks, labels, range(1, n + 1))
    out = []
    for y, x in sorted(points, key=lambda p: -bright[int(round(p[0])), int(round(p[1]))]):
        y, x = int(round(y)), int(round(x))
        if not mask[y, x]:
            continue
        if all((y - oy) ** 2 + (x - ox) ** 2 >= (sep * 0.8) ** 2 for oy, ox in out):
            out.append((y, x))
    return out


def flood(bright, mask, points):
    """Each crown pixel to the clump whose bright spot reaches it first, flooding downhill in
    brightness, so the borders fall on the dark crevices between puffs (a watershed)."""
    labels = np.zeros(mask.shape, np.int32)
    heap = []
    for k, (y, x) in enumerate(points, 1):
        labels[y, x] = k
        heapq.heappush(heap, (-bright[y, x], y, x))
    h, w = mask.shape
    while heap:
        _, y, x = heapq.heappop(heap)
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not labels[ny, nx]:
                labels[ny, nx] = labels[y, x]
                heapq.heappush(heap, (-bright[ny, nx], ny, nx))
    # Leaves cut off from every spot (a lone leaf) go with the nearest clump.
    lost = mask & (labels == 0)
    if lost.any():
        _, (iy, ix) = ndimage.distance_transform_edt(labels == 0, return_indices=True)
        labels[lost] = labels[iy[lost], ix[lost]]
    return labels


def merge_small(labels, min_px):
    """Clumps too small to read as a puff go into the neighbour they share most border with."""
    while True:
        sizes = np.bincount(labels.ravel())
        small = [k for k in range(1, len(sizes)) if 0 < sizes[k] < min_px]
        if not small:
            break
        k = small[0]
        here = labels == k
        ring = ndimage.binary_dilation(here) & ~here & (labels > 0)
        if not ring.any():
            labels[here] = 0
            continue
        labels[here] = np.bincount(labels[ring]).argmax()
    # Numbered 1..n again.
    ids = [k for k in np.unique(labels) if k]
    out = np.zeros_like(labels)
    for n, k in enumerate(ids, 1):
        out[labels == k] = n
    return out


def tiers(px, mask):
    """A conifer's clumps: its branch tiers, cut where the crown is narrowest between two wide rows."""
    widths = mask.sum(axis=1).astype(float)
    rows = np.nonzero(widths)[0]
    cuts = []
    for y in rows[2:-2]:
        if widths[y] < widths[y - 1] and widths[y] <= widths[y + 1] and widths[y + 2] - widths[y] >= 2:
            if not cuts or y - cuts[-1] >= 3:
                cuts.append(y)
    if len(cuts) < 2:
        # Too smooth to find its tiers (a sapling): bands of five rows.
        cuts = list(range(rows.min() + 5, rows.max() - 2, 5))
    labels = np.zeros(mask.shape, np.int32)
    edges = [rows.min()] + cuts + [rows.max() + 1]
    for n, (a, b) in enumerate(zip(edges, edges[1:]), 1):
        labels[a:b][mask[a:b]] = n
    return labels


def split(art_id):
    """(sprite pixels, clump labels 0 = stays, 1..n), the clumps ordered back to front."""
    cfg = settings(art_id)
    px = load(art_id)
    mask = crown_mask(px, cfg)
    if cfg["kind"] == "pine":
        labels = tiers(px, mask)
    else:
        bright = luma(px).astype(float)
        weight = ndimage.gaussian_filter(mask.astype(float), 1.2)
        smooth = np.where(mask, ndimage.gaussian_filter(np.where(mask, bright, 0), 1.2) / np.maximum(weight, 1e-6), 0)
        labels = flood(smooth, mask, seeds(smooth, mask, cfg["sep"]))
    labels = merge_small(labels, cfg["min_px"])
    # Back to front: the clumps higher on screen are further back, drawn first.
    n = labels.max()
    order = sorted(range(1, n + 1), key=lambda k: ndimage.center_of_mass(labels == k)[0])
    out = np.zeros_like(labels)
    for i, k in enumerate(order, 1):
        out[labels == k] = i
    return px, out


# Moving ----------------------------------------------------------------------------------------------

def push(seconds, period):
    """How far a gust has bowed the crown (1 its furthest) `seconds` after it reaches the tree: a spring
    with little damping, shoved for its first second, so it swings back past upright, bounces and
    settles by the gust's end."""
    omega = 2 * math.pi / period
    damping = 2 * 0.32 * omega
    x = v = 0.0
    dt = 1 / 200
    peak = 0.0
    track = []
    for step in range(int(GUST / FPS / dt) + 1):
        t = step * dt
        force = omega * omega * (math.sin(math.pi * min(t, 1.0)) ** 2 if t < 1.0 else 0.0)
        v += (force - omega * omega * x - damping * v) * dt
        x += v * dt
        track.append(x)
        peak = max(peak, x)
    i = min(int(round(seconds / dt)), len(track) - 1)
    return track[i] / peak


def floor_half(v):
    return int(math.floor(v + 0.5))


def offsets(labels, cfg):
    """Each frame's (dx, dy) for each clump, in pixels, y down: the calm loop, then a gust."""
    n = labels.max()
    solid = labels > 0
    ys, xs = np.nonzero(solid)
    middle = np.array([ys.mean(), xs.mean()])
    top, low = ys.min(), ys.max()
    width = labels.shape[1]
    clumps = []
    reach = max(np.hypot(ys - middle[0], xs - middle[1]).max(), 1)
    for k in range(1, n + 1):
        cy, cx = ndimage.center_of_mass(labels == k)
        edge = math.hypot(cy - middle[0], cx - middle[1]) / reach
        flex = 0.3 + 0.7 * min(1.0, edge * 1.25)          # stiff inside, loose outside
        height = (low - cy) / max(low - top, 1)             # 0 at the crown's foot, 1 at its top
        lean = 0.35 + 0.65 * height                          # the top bows furthest
        ys_k, xs_k = np.nonzero(labels == k)
        # The room it has before it would leave the canvas: it goes no further.
        room = (-int(xs_k.min()), width - 1 - int(xs_k.max()), -int(ys_k.min()), labels.shape[0] - 1 - int(ys_k.max()))
        clumps.append((cx - width / 2, flex, lean, room))
    frames = []
    for f in range(LOOP + GUST):
        gusting = f >= LOOP
        g = f - LOOP
        loop_f = f % LOOP if not gusting else g % LOOP
        if gusting:
            seconds = g / FPS
            rise = math.sin(math.pi * g / GUST) ** 2           # the loop widens through the gust
            bow = push(seconds, cfg["period"])
        else:
            rise, bow = 0.0, 0.0
        row = []
        for x, flex, lean, room in clumps:
            theta = 2 * math.pi * (loop_f / LOOP - x / WAVELENGTH)
            reach_px = flex * (cfg["calm"] + (cfg["gust"] - cfg["calm"]) * rise)
            dx = floor_half(reach_px * (0.5 + 0.5 * math.sin(theta)) + cfg["push"] * lean * bow)
            # Bowed over, the crown dips a little and bobs back up as it springs upright.
            dy = -floor_half(reach_px * (0.5 + 0.5 * math.cos(theta))) + floor_half(cfg["dip"] * lean * abs(bow))
            row += [min(max(dx, room[0]), room[1]), min(max(dy, room[2]), room[3])]
        frames.append(row)
    return frames


def runs(labels, k):
    out = []
    for y in range(labels.shape[0]):
        xs = np.nonzero(labels[y] == k)[0]
        if not len(xs):
            continue
        start = prev = xs[0]
        for x in list(xs[1:]) + [None]:
            if x is not None and x == prev + 1:
                prev = x
                continue
            out += [int(y), int(start), int(prev - start + 1)]
            if x is not None:
                start = prev = x
    return out


def rig(art_id):
    cfg = settings(art_id)
    px, labels = split(art_id)
    return {
        "size": [int(px.shape[1]), int(px.shape[0])],
        "clumps": [runs(labels, k) for k in range(1, labels.max() + 1)],
        "frames": offsets(labels, cfg),
    }


# Drawing (as Wind.swift does) ------------------------------------------------------------------------

def unpack(r):
    w, h = r["size"]
    labels = np.zeros((h, w), np.int32)
    for k, spans in enumerate(r["clumps"], 1):
        for i in range(0, len(spans), 3):
            y, x, n = spans[i:i + 3]
            labels[y, x:x + n] = k
    return labels


def frame(px, labels, row):
    """One frame: what stays, the crown's shade where clumps can part, then each clump moved."""
    out = np.where((labels == 0)[..., None], px, 0)
    crown = labels > 0
    shade = px.copy()
    for c in range(3):
        shade[..., c] = (px[..., c] * INSIDE[c]).astype(np.int32)
    out[crown] = shade[crown]
    h, w = labels.shape
    for k in range(1, labels.max() + 1):
        dx, dy = row[2 * (k - 1)], row[2 * (k - 1) + 1]
        ys, xs = np.nonzero(labels == k)
        ty, tx = ys + dy, xs + dx
        keep = (ty >= 0) & (ty < h) & (tx >= 0) & (tx < w)
        out[ty[keep], tx[keep]] = px[ys[keep], xs[keep]]
    return out.astype(np.uint8)


def frame_at(r, seconds, x, y):
    """Which of a rig's frames a tree at (x, y) shows: `WindField.frame` in Wind.swift."""
    slant = x + 0.35 * y
    u = seconds * FPS / LOOP - slant / WAVELENGTH
    n = math.floor(u)
    f = int((u - n) * LOOP)
    slot = gust_slot(n, y)
    if slot is None:
        return f
    return LOOP + slot * LOOP + f


def mix(*values):
    h = 2166136261
    for v in values:
        h = ((h ^ (v & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    h ^= h >> 15
    h = (h * 2246822519) & 0xFFFFFFFF
    h ^= h >> 13
    return h


CYCLE = 9          # loops between one round of gusts and the next (14.4 s)
BAND = 120         # points: gusts come in patches this tall, or two or three of them together


def gust_slot(n, y):
    """Which loop of a gust a tree's loop `n` is (0 or 1), or None in still air: `WindField.gustSlot`."""
    cycle, at = n // CYCLE, n % CYCLE
    size = 1 + mix(cycle, 7) % 3
    band = (math.floor(y / BAND) + mix(cycle, 11) % 3) // size
    roll = mix(cycle, band, 3)
    if roll % 4 == 0:
        return None                                 # this patch gets no gust this round
    start = 1 + (roll >> 4) % (CYCLE - 4)
    if start <= at < start + 2:
        return at - start
    if (roll >> 9) % 3 == 0 and start + 2 <= at < start + 4:
        return at - start - 2                       # a second gust right behind the first
    return None


# Commands ---------------------------------------------------------------------------------------------

def write():
    rigs = {}
    for art_id in sorted(RIGS):
        rigs[art_id] = rig(art_id)
        print(f"{art_id:18s} {len(rigs[art_id]['clumps']):3d} clumps")
    data = {
        "_about": "Written by tools/wind_art.py: each sprite's leaf clumps (runs of y, x, length, back to front) "
                  "and each frame's whole-pixel move (dx, dy, y down) for each, a calm loop then a gust. "
                  "Wind.swift cuts the frames out of the sprite as it's graded.",
        "fps": FPS, "loop": LOOP, "gust": GUST, "wavelength": WAVELENGTH, "cycle": CYCLE, "band": BAND,
        "inside": list(INSIDE),
        "rigs": rigs,
    }
    text = json.dumps(data, separators=(",", ":"))
    # One rig a line, so a diff shows which changed.
    text = text.replace(',"rigs":{', ',\n"rigs":{\n').replace('},"', '},\n"')
    OUT.write_text(text + "\n")
    print(f"wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB)")


def check():
    """Each rig still fits its sprite: the same size, its clumps on opaque pixels, a frame of moves for
    each clump. Returns the problems."""
    if not OUT.exists():
        return [f"{OUT.relative_to(ROOT)} is missing: run tools/wind_art.py"]
    data = json.loads(OUT.read_text())
    bad = []
    for art_id, r in data["rigs"].items():
        path = SPRITES / f"{art_id}.png"
        if not path.exists():
            bad.append(f"art/wind.json: {art_id} has no art/sprites/{art_id}.png")
            continue
        px = load(art_id)
        w, h = r["size"]
        if px.shape[:2] != (h, w):
            bad.append(f"art/wind.json: {art_id} is rigged at {w}x{h}, its sprite is {px.shape[1]}x{px.shape[0]}: rerun tools/wind_art.py")
            continue
        labels = unpack(r)
        if (labels > 0).sum() and not (px[..., 3][labels > 0] > 0).all():
            bad.append(f"art/wind.json: {art_id}'s clumps cover clear pixels (its sprite changed): rerun tools/wind_art.py")
        frames = r["frames"]
        if len(frames) != data["loop"] + data["gust"] or any(len(f) != 2 * len(r["clumps"]) for f in frames):
            bad.append(f"art/wind.json: {art_id} needs {data['loop'] + data['gust']} frames of a move for each clump")
    for art_id in RIGS:
        if art_id not in data["rigs"]:
            bad.append(f"art/wind.json: no rig for {art_id}: rerun tools/wind_art.py")
    return bad


def sheet(path, ids):
    tiles = []
    rng = np.random.default_rng(3)
    for art_id in ids:
        px, labels = split(art_id)
        colours = rng.integers(60, 255, size=(labels.max() + 1, 3))
        tint = px.copy()
        crown = labels > 0
        tint[..., :3][crown] = (px[..., :3][crown] * 0.35 + colours[labels[crown]] * 0.65).astype(np.int32)
        tiles.append((px, tint))
    k = 4
    cell = 64 * k
    board = Image.new("RGBA", (cell * 2 * 4, cell * math.ceil(len(tiles) / 4)), (66, 92, 70, 255))
    for n, (px, tint) in enumerate(tiles):
        for j, img in enumerate((px, tint)):
            im = Image.fromarray(img.astype(np.uint8)).resize((img.shape[1] * k, img.shape[0] * k), Image.NEAREST)
            board.alpha_composite(im, ((n % 4) * cell * 2 + j * cell, (n // 4) * cell))
    board.save(path)
    print(f"sheet in {path}")


def gif(path, ids, seconds=18.0, zoom=3):
    """A grove: a few rows of trees, as the game times them, from calm through a round of gusts."""
    data = {"rigs": {a: rig(a) for a in ids}}
    grove = []
    rng = np.random.default_rng(5)
    for row in range(3):
        for col in range(len(ids)):
            art_id = ids[(col + row) % len(ids)]
            r = data["rigs"][art_id]
            w, h = r["size"]
            x = 8 + col * 58 + (row % 2) * 29 + int(rng.integers(-6, 7))
            y = row * 46
            grove.append((y, x, art_id))
    grove.sort()
    width = max(x for _, x, _ in grove) + 80
    height = max(y for y, _, _ in grove) + 80
    pixels = {a: load(a) for a in ids}
    labels = {a: unpack(data["rigs"][a]) for a in ids}
    frames = []
    # From the start of a round with gusts in it.
    start = 0.0
    for t in range(int(seconds * FPS)):
        now = start + t / FPS
        canvas = np.zeros((height, width, 4), np.uint8)
        canvas[...] = (106, 150, 86, 255)
        for y, x, art_id in grove:
            r = data["rigs"][art_id]
            # y up in the game: rows further down the screen are lower
            f = frame_at(r, now, x, height - y)
            img = frame(pixels[art_id], labels[art_id], r["frames"][f])
            h, w = img.shape[:2]
            region = canvas[y:y + h, x:x + w]
            a = img[..., 3:4] > 0
            region[...] = np.where(a, img, region)
        im = Image.fromarray(canvas).resize((width * zoom, height * zoom), Image.NEAREST)
        frames.append(im.convert("P", palette=Image.ADAPTIVE, colors=255))
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=1000 // FPS, loop=0, disposal=1)
    print(f"gif in {path} ({len(frames)} frames)")


def main(argv):
    if argv[:1] == ["check"]:
        bad = check()
        for line in bad:
            print("FAIL " + line)
        print("wind rigs fit their sprites" if not bad else f"{len(bad)} problems")
        return 1 if bad else 0
    if "--sheet" in argv:
        i = argv.index("--sheet")
        ids = argv[i + 2:] or sorted(RIGS)
        sheet(argv[i + 1], ids)
        return 0
    if "--gif" in argv:
        i = argv.index("--gif")
        ids = argv[i + 2:] or ["tree", "blossom_tree", "apple_tree", "bush"]
        gif(argv[i + 1], ids)
        return 0
    write()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
