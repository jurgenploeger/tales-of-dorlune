#!/usr/bin/env python3
"""The sea along the continent's coast, as the game draws it (`ContinentScene.shallows`), to see it without a Mac.

After SpriteCook's "2D water shorelines with a distance field" (2025-11): one number per spot of sea, how far
it lies from the land, gives the shallows in bands that follow every bay and round every point (where the
game had flat bands a whole cell at a time, stepping along the grid), and waves that roll in toward the
shore. This mirrors `shallowField` (the distances, `SAMPLES` a cell, out from each land cell taken as a
square) and `shallowShader` (bands and crests on the sea's own 32 pixels a cell); keep the two in step.

    python3 tools/shore_art.py out.png [land] [--at X,Y]   # before and after, turned as the game shows it
    python3 tools/shore_art.py --gif out.gif [land]        # the waves rolling in

Needs pillow, numpy. Reads content/world.json's shapes and art/sprites/sea.png.
"""

import json
import math
import pathlib
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

CELL = 32          # the sea's pixels a cell (tools/water_art.py)
CHUNK = 32         # cells a side of a chunk (World.chunkSize)
SAMPLES = 4        # ContinentScene.shallowSamples
REACH = 5          # ContinentScene.shallowReach
UNDER = 0.75       # ContinentScene.shallowUnder
PALE = np.array([0.8, 0.96, 0.95])


def world_land():
    """Which world cells are land: a set-like bool grid with its south-west corner."""
    from world_layout import decode
    world = json.loads((ROOT / "content" / "world.json").read_text())
    margin = world["margin"]
    cells = []
    for land_id, rows in world["regions"].items():
        x0, y0 = world["lands"][land_id]
        for r, runs in enumerate(rows):
            row = np.array(decode(runs))
            for c in np.nonzero(row)[0]:
                cells.append((x0 - margin + int(c), y0 - margin + r))
    xs = np.array([c[0] for c in cells])
    ys = np.array([c[1] for c in cells])
    low = (xs.min() - 8, ys.min() - 8)
    grid = np.zeros((ys.max() - low[1] + 9, xs.max() - low[0] + 9), bool)
    grid[ys - low[1], xs - low[0]] = True
    return grid, low


def field(land, x0, y0, cols, rows):
    """`shallowField`'s distances over cells x0.. and y0.. (in `land`'s indices, row = y), SAMPLES a cell,
    out from the land (under it, less than none), as the game stores them (one byte, eased between)."""
    nx, ny = cols * SAMPLES + 1, rows * SAMPLES + 1
    out = np.zeros((ny, nx))
    h, w = land.shape
    for j in range(ny):
        y = y0 + j / SAMPLES
        for i in range(nx):
            x = x0 + i / SAMPLES
            col, row = min(w - 1, int(x)), min(h - 1, int(y))
            inside = land[row, col]
            around = 1 if inside else REACH
            nearest = UNDER if inside else float(REACH)
            for r in range(max(0, row - around), min(h - 1, row + around) + 1):
                dy = max(0.0, r - y, y - (r + 1))
                if dy >= nearest:
                    continue
                for c in range(max(0, col - around), min(w - 1, col + around) + 1):
                    if land[r, c] != inside:
                        dx = max(0.0, c - x, x - (c + 1))
                        nearest = min(nearest, math.hypot(dx, dy))
            d = -nearest if inside else nearest
            out[j, i] = round(max(0, min(255, (d + UNDER) / (REACH + UNDER) * 255)))
    return out


def sample(f, px, py):
    """Bilinear, as the texture's linear filtering: f at spot coordinates (px, py)."""
    ny, nx = f.shape
    px = np.clip(px, 0, nx - 1)
    py = np.clip(py, 0, ny - 1)
    i0, j0 = np.floor(px).astype(int), np.floor(py).astype(int)
    i1, j1 = np.minimum(i0 + 1, nx - 1), np.minimum(j0 + 1, ny - 1)
    fx, fy = px - i0, py - j0
    top = f[j0, i0] * (1 - fx) + f[j0, i1] * fx
    bottom = f[j1, i0] * (1 - fx) + f[j1, i1] * fx
    return top * (1 - fy) + bottom * fy


def shade(f, cols, rows, t):
    """`shallowShader` over the pixels: premultiplied RGBA, y up (row 0 the south)."""
    w, h = cols * CELL, rows * CELL
    pix_x, pix_y = np.meshgrid(np.arange(w) + 0.5, np.arange(h) + 0.5)
    d = sample(f, pix_x / CELL * SAMPLES, pix_y / CELL * SAMPLES) / 255 * (REACH + UNDER) - UNDER
    pale = np.floor(np.clip(1 - d / 3.4, 0, 1) * 6) / 6 * 0.44
    phase = d / 0.95 + t * 0.22
    swell = np.mod(np.floor(phase), 61)
    crest = 1 - (np.mod(phase, 1) >= 0.085)
    bx, by = np.floor(pix_x / 10) + swell * 3.17, np.floor(pix_y / 10) + swell * 3.17
    gap = np.mod(np.sin(bx * 12.9898 + by * 78.233) * 43758.5453, 1)
    reach = np.clip((2.8 - d) / 0.9, 0, 1) * np.clip((d - 0.3) / 0.45, 0, 1)
    wave = crest * (gap >= 0.35) * reach * 0.5
    rgb = PALE[None, None, :] * pale[..., None] * (1 - wave[..., None]) + wave[..., None]
    a = pale * (1 - wave) + wave
    return np.dstack([rgb, a])


def old_bands(land, x0, y0, cols, rows):
    """The flat bands a cell at a time the game drew before (ContinentScene.shallowTiles)."""
    alphas = [0.42, 0.3, 0.18, 0.08]
    reach = 3
    out = np.zeros((rows * CELL, cols * CELL))
    for r in range(rows):
        for c in range(cols):
            y, x = y0 + r, x0 + c
            is_land = land[y, x]
            nearest = reach + 1
            for dr in range(-reach, reach + 1):
                for dc in range(-reach, reach + 1):
                    if (dc or dr) and land[y + dr, x + dc] != is_land:
                        nearest = min(nearest, math.hypot(dc, dr))
            band = (0 if nearest < 1.5 else None) if is_land else math.ceil(nearest)
            if band is not None and band <= reach:
                out[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL] = alphas[band]
    return out


def picture(land, x0, y0, cols, rows, overlay):
    """Sea, its coast's overlay (premultiplied RGBA or an alpha of the pale green), and the land (a flat
    meadow, cut square: the game's own cut edge is drawn over the water by the land), y down."""
    sea = np.asarray(Image.open(ROOT / "art" / "sprites" / "sea.png").convert("RGB")).astype(float) / 255
    n = sea.shape[0] // CELL
    h, w = rows * CELL, cols * CELL
    out = np.zeros((h, w, 3))
    for r in range(rows):
        for c in range(cols):
            sr, sc = (y0 + r) % n, (x0 + c) % n
            # the sea's picture by row from the south (`seaGroups`)
            tile = sea[(n - 1 - sr) * CELL:(n - sr) * CELL, sc * CELL:(sc + 1) * CELL]
            out[h - (r + 1) * CELL:h - r * CELL, c * CELL:(c + 1) * CELL] = tile
    if overlay.ndim == 2:
        a = overlay[::-1][..., None]
        out = out * (1 - a) + PALE * a
    else:
        o = overlay[::-1]
        out = out * (1 - o[..., 3:4]) + o[..., :3]
    mask = np.kron(land[y0:y0 + rows, x0:x0 + cols][::-1], np.ones((CELL, CELL))).astype(bool)
    out[mask] = (0.47, 0.66, 0.33)
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))


def turned(img):
    """As the game shows the ground: turned an eighth and squashed to half its height."""
    big = img.rotate(45, resample=Image.NEAREST, expand=True)
    return big.resize((big.width, big.height // 2), Image.NEAREST).resize((big.width * 2, big.height), Image.NEAREST)


def coast_spot(land, low, land_id, cols, rows):
    """The most winding stretch of coast near `land_id`: a window about half land, with the most coast."""
    world = json.loads((ROOT / "content" / "world.json").read_text())
    x0, y0 = world["lands"][land_id]
    mx, my = world["middles"][land_id]
    cx, cy = x0 + mx - low[0], y0 + my - low[1]
    edge = land & ~(np.roll(land, 1, 0) & np.roll(land, -1, 0) & np.roll(land, 1, 1) & np.roll(land, -1, 1))
    h, w = land.shape
    best = None
    for y in range(rows, h - rows, 3):
        for x in range(cols, w - cols, 3):
            win = land[y - rows // 2:y + rows // 2, x - cols // 2:x + cols // 2]
            if not 0.35 < win.mean() < 0.6:
                continue
            score = edge[y - rows // 2:y + rows // 2, x - cols // 2:x + cols // 2].sum() - 0.02 * math.hypot(x - cx, y - cy)
            if best is None or score > best[0]:
                best = (score, x, y)
    return best[1], best[2]


def main(argv):
    gif = "--gif" in argv
    if gif:
        argv = [a for a in argv if a != "--gif"]
    at = None
    if "--at" in argv:
        i = argv.index("--at")
        at = tuple(int(v) for v in argv[i + 1].split(","))
        argv = argv[:i] + argv[i + 2:]
    out = argv[0]
    land_id = argv[1] if len(argv) > 1 else "pineapple_shore"
    land, low = world_land()
    cols, rows = 28, 20
    cx, cy = (at[0] - low[0], at[1] - low[1]) if at else coast_spot(land, low, land_id, cols, rows)
    x0, y0 = cx - cols // 2, cy - rows // 2
    f = field(land, x0, y0, cols, rows)
    if gif:
        frames = []
        for k in range(40):
            img = turned(picture(land, x0, y0, cols, rows, shade(f, cols, rows, k * 0.2)))
            frames.append(img.convert("P", palette=Image.ADAPTIVE, colors=255))
        frames[0].save(out, save_all=True, append_images=frames[1:], duration=200, loop=0)
        print(f"gif in {out}")
        return 0
    before = turned(picture(land, x0, y0, cols, rows, old_bands(land, x0, y0, cols, rows)))
    after = turned(picture(land, x0, y0, cols, rows, shade(f, cols, rows, 3.0)))
    board = Image.new("RGB", (before.width * 2 + 16, before.height), (20, 20, 30))
    board.paste(before, (0, 0))
    board.paste(after, (before.width + 16, 0))
    board.save(out)
    print(f"before | after in {out} (world cell {cx + low[0]},{cy + low[1]})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
