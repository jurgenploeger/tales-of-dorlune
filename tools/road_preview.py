#!/usr/bin/env python3
"""Roads of sand with a cobbled middle, pebbles, and the grass growing over their edges, previewed before
they go in the game (the user, 2026-11-17, with a reference picture: "How can we apply these kind of roads
with pebbles and sand? And also the grass that kinda overlaps?").

A crossroads of a wide road and a footpath on the land's grass, drawn a pixel at a time from the game's own
tiles (tile_grass, tile_path's sand, tile_town's cobbles) as `ArtLibrary.organicTile` lays a road (its
edge a wobbling line round the road's middle, `radius` 0.36 a cell, a darker rim inside it), then turned and
squashed as the game's view is. Left: as now. Right: proposed:

- a cobbled band down the middle of a road wide enough for one, sand either side of it, the cobbles' edge
  ragged where stones have come loose;
- loose pebbles in the sand, thickest beside the cobbles;
- the grass growing out over the road's edge in tufts, each its own length (`ArtLibrary.bladeReach`, as the
  grass over the waterline), its tips lit, a soft shadow on the sand under them.

Bigger stones and bolder clumps, and only in villages and towns (the user, 2026-11-17); roads out in the
wild keep their plain sand.

    python3 tools/road_preview.py out.png

Needs pillow + numpy.
"""
import math
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPR = ROOT / "art" / "sprites"
PX = 32
N = 14                                   # cells a side


def tile(name):
    return np.asarray(Image.open(SPR / f"{name}.png").convert("RGB")).astype(float)


GRASS, SAND, COBBLE = tile("tile_grass"), tile("tile_path"), tile("tile_town")


def h(*v):
    x = 2166136261
    for a in v:
        x = ((x ^ (int(a) & 0xffffffff)) * 16777619) & 0xffffffff
    x ^= x >> 15
    x = (x * 2246822519) & 0xffffffff
    x ^= x >> 13
    return (x & 0xffff) / 65535


STONE = 15.0                             # cobbles about this many of the art's pixels across (10 was too fine)


def cobble(px, py):
    """A cobblestone road's pixel at (px, py) in the art's pixels: rounded stones on a jittered grid, each its
    own grey, lit on its top left and shaded at its bottom right, dark gaps of packed earth between them."""
    gx, gy = px / STONE, py / STONE
    cx, cy = math.floor(gx), math.floor(gy)
    best, second, at = 9.0, 9.0, None
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            sx, sy = cx + dx, cy + dy
            jx = sx + 0.2 + 0.6 * h(sx, sy, 1)
            jy = sy + 0.2 + 0.6 * h(sx, sy, 2)
            d = math.hypot(gx - jx, gy - jy)
            if d < best:
                second, best, at = best, d, (sx, sy, gx - jx, gy - jy)
            elif d < second:
                second = d
    edge = second - best
    sx, sy, ox, oy = at
    if edge < 0.1:
        return None                                        # the sand between the stones
    if edge < 0.15:
        return np.array([78, 68, 60.0])                    # each stone's dark outline
    tone = 0.9 + 0.22 * h(sx, sy, 3)
    base = np.array([176, 168, 156.0]) * tone
    lit = -(ox + oy)
    if edge < 0.27:
        base *= 1.14 if lit > 0 else 0.76
    if h(px, py, 9) < 0.08:
        base *= 0.9
    return base


def blade(across):
    """How far the grass reaches over the edge, in cells: rounded clumps along it, each its own width and
    reach, as the reference's grass overhangs the road in soft scallops."""
    k = math.floor(across * 1.1)
    t = across * 1.1 - k
    width = 0.7 + 0.3 * h(k, 3)
    if t > width:
        return 0.02
    u = (t / width) * 2 - 1
    return 0.05 + (0.12 + 0.12 * h(k, 4)) * math.sqrt(max(0, 1 - u * u))


def road_depth(gx, gy):
    """How far in from the road's edge a point is, in cells (below 0 off it): a wide road along x
    (three cells, y 5..8) and a footpath along y (one cell, x 8..9), each edge wobbling."""
    wob = 0.06 * math.sin(gx * 2.3 + gy) + 0.04 * math.sin(gx * 5.1 - gy * 3)
    wide = 1.5 + 0.36 + wob - abs(gy - 6.5)
    foot = 0.5 + 0.36 + wob - abs(gx - 8.5)
    if gy < 6.5:
        foot = foot if gy > 0 else -9
    else:
        foot = -9
    return max(wide, foot), wide


def ground(proposed):
    W = N * PX
    out = np.zeros((W, W, 3))
    for py in range(W):
        for px in range(W):
            gx, gy = px / PX, py / PX
            u, v = px % PX, py % PX
            depth, wide = road_depth(gx, gy)
            g = GRASS[v, u]
            if not proposed:
                if depth > 0:
                    c = SAND[v, u] * (0.72 if depth < 0.06 else 1)
                else:
                    c = g
                out[py, px] = c
                continue
            if depth <= 0:
                out[py, px] = g
                continue
            # The grass over the edge: its tufts, lit at their tips, a shadow past them.
            reach = blade(gx - gy)
            if depth < reach - 0.035:
                out[py, px] = g * (1.22 if depth > reach - 0.09 else 1.0)
                continue
            if depth < reach:
                out[py, px] = g * 0.45                       # the clump's dark edge
                continue
            c = SAND[v, u].copy()
            if depth < reach + 0.09:
                c *= 0.68                                     # its shadow on the road
            # The cobbles down the middle of the wide road, their edge ragged, loose stones at it.
            core = wide - 0.75 + 0.12 * (h(int(gx * 4), int(gy * 4), 3) - 0.5)
            stone = cobble(px, py) if core > -0.25 else None
            if stone is not None and (core > 0 or h(int(px / STONE), int(py / STONE), 21) < 0.5 + core * 2):
                c = stone
            else:
                # Pebbles in the sand: more near the cobbles.
                near = max(0, 1 - abs(core) / 0.6) if wide > 0 else 0.15
                cx, cy = int(gx * 4), int(gy * 4)
                if h(cx, cy, 11) < 0.08 + 0.35 * near:
                    ox, oy = 0.25 + 0.5 * h(cx, cy, 12), 0.25 + 0.5 * h(cx, cy, 13)
                    size = 0.12 + 0.12 * h(cx, cy, 14)
                    dx, dy = gx * 4 - cx - ox, gy * 4 - cy - oy
                    r = dx * dx + dy * dy
                    if r < size * size:
                        c = np.array([158, 150, 140.0]) * (1.15 if dx + dy < -size * 0.3 else 0.9)
                    elif r < (size + 0.06) ** 2:
                        c = np.array([88, 76, 66.0])
            out[py, px] = c
    return out


def project(top):
    """The ground turned 45° and squashed to half its height, as `WorldMap.project` draws it."""
    W = top.shape[0]
    img = Image.fromarray(top.clip(0, 255).astype(np.uint8)).rotate(45, expand=True, resample=Image.NEAREST)
    return img.resize((img.width, img.height // 2), Image.NEAREST)


def main(argv):
    out = argv[0] if argv else "road_preview.png"
    a, b = project(ground(False)), project(ground(True))
    crop = lambda im: im.crop((im.width * 3 // 10, im.height * 3 // 10, im.width * 7 // 10, im.height * 7 // 10)).resize((im.width * 5 // 4, im.height * 5 // 4), Image.NEAREST)
    a, b = crop(a), crop(b)
    board = Image.new("RGB", (a.width * 2 + 30, a.height + 40), (24, 30, 46))
    board.paste(a, (10, 10)); board.paste(b, (a.width + 20, 10))
    d = ImageDraw.Draw(board)
    d.text((14, a.height + 16), "As now", fill=(255, 255, 255))
    d.text((a.width + 24, a.height + 16), "Proposed: cobbles down the middle, pebbles in the sand, grass over the edges", fill=(255, 255, 255))
    board.save(out)
    print(out)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
