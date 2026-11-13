#!/usr/bin/env python3
"""The street lamps' light at night on what stands round them, as the game draws it (`LampLight`), to see it
without a Mac.

After SpriteCook's "Normal maps for pixel art from the sprite's outline" (2025-11): which way each pixel
faces comes from the sprite's outline (its height how far it lies in from the nearest clear pixel, a
rounded bevel, with a little of its brightness for detail), so a lamp lights the side of a house or a rock
toward it, in three hard steps, and leaves the far side in the night. This mirrors `OutlineNormals` and
`LampLight.makeCopy`; keep the two in step.

    python3 tools/normal_art.py out.png [ids...]   # normals, then each lit from eight ways, at night

Needs pillow, numpy.
"""

import math
import pathlib
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPRITES = ROOT / "art" / "sprites"

BEVEL = 5.0        # OutlineNormals.bevel
DETAIL = 1.2       # OutlineNormals.detail
LAMP = (1.0, 0.85, 0.5)
BOOST = 1.5        # LampLight.boost
NIGHT = (0.42, 0.47, 0.78)   # Sky's night shade, multiplied over the screen


def premultiplied(art_id):
    px = np.asarray(Image.open(SPRITES / f"{art_id}.png").convert("RGBA")).astype(float)
    px[..., :3] *= px[..., 3:4] / 255
    return np.round(px)


def normals(px):
    """`OutlineNormals.normals`: x right, y down, z toward you."""
    h, w = px.shape[:2]
    dist = np.where(px[..., 3] >= 128, np.inf, 0.0)

    def at(x, y):
        return 0.0 if x < 0 or y < 0 or x >= w or y >= h else dist[y, x]

    for y in range(h):
        for x in range(w):
            if dist[y, x] > 0:
                dist[y, x] = min(dist[y, x], at(x - 1, y) + 1, at(x, y - 1) + 1, at(x - 1, y - 1) + 1.414, at(x + 1, y - 1) + 1.414)
    for y in range(h - 1, -1, -1):
        for x in range(w - 1, -1, -1):
            if dist[y, x] > 0:
                dist[y, x] = min(dist[y, x], at(x + 1, y) + 1, at(x, y + 1) + 1, at(x + 1, y + 1) + 1.414, at(x - 1, y + 1) + 1.414)
    t = np.minimum(dist, BEVEL) / BEVEL
    dome = BEVEL * np.sqrt(1 - (1 - t) ** 2)
    alpha = px[..., 3]
    luma = np.where(alpha > 0, (0.299 * px[..., 0] + 0.587 * px[..., 1] + 0.114 * px[..., 2]) / np.maximum(alpha, 1), 0)
    heights = np.where(dist > 0, dome + DETAIL * luma, 0)
    p = np.pad(heights, 1)
    gx = (p[:-2, 2:] + 2 * p[1:-1, 2:] + p[2:, 2:]) - (p[:-2, :-2] + 2 * p[1:-1, :-2] + p[2:, :-2])
    gy = (p[2:, :-2] + 2 * p[2:, 1:-1] + p[2:, 2:]) - (p[:-2, :-2] + 2 * p[:-2, 1:-1] + p[:-2, 2:])
    n = np.dstack([-gx / 8, -gy / 8, np.ones_like(gx)])
    return n / np.linalg.norm(n, axis=2, keepdims=True)


def copy(px, n, way, color=LAMP):
    """`LampLight.makeCopy`: the light's copy, premultiplied, added over the sprite."""
    angle = way * math.pi / 4
    light = np.array([math.cos(angle), -math.sin(angle), 0.55])
    light /= np.linalg.norm(light)
    facing = n @ light
    caught = np.clip((facing - 0.15) / 0.75, 0, 1)   # a third facing you, all of it turned to the lamp
    step = np.floor(caught * 3) / 3
    step = np.where(px[..., 3] > 0, step, 0)
    out = np.zeros_like(px)
    out[..., :3] = np.minimum(255, np.floor(px[..., :3] * np.array(color) * step[..., None] * BOOST))
    out[..., 3] = np.where(step > 0, px[..., 3], 0)
    return out


def at_night(px, add=None, strength=1.0):
    """The sprite on grass under the night's shade, with the light's copy added (`.add`, at `strength`)."""
    h, w = px.shape[:2]
    ground = np.ones((h, w, 3)) * np.array([106, 150, 86])
    a = px[..., 3:4] / 255
    rgb = ground * (1 - a) + px[..., :3]
    if add is not None:
        rgb = np.minimum(255, rgb + add[..., :3] * strength)
    return np.clip(rgb * np.array(NIGHT), 0, 255).astype(np.uint8)


def main(argv):
    out = argv[0]
    ids = argv[1:] or ["house", "cottage_thatched", "stone_townhouse", "boulder", "wooden_crates", "barrels", "water_well", "statue"]
    ids = [i for i in ids if (SPRITES / f"{i}.png").exists()]
    k = 3
    rows = []
    for art_id in ids:
        px = premultiplied(art_id)
        n = normals(px)
        h, w = px.shape[:2]
        tiles = [np.clip((n * 0.5 + 0.5) * 255, 0, 255).astype(np.uint8) * (px[..., 3:4] > 0), at_night(px)]
        # Lit from the left, the top left, above, the right: the lamp beside it.
        for way in (4, 3, 2, 0):
            tiles.append(at_night(px, copy(px, n, way)))
        row = np.concatenate([np.pad(t, ((4, 4), (4, 4), (0, 0)), constant_values=24) for t in tiles], axis=1)
        rows.append(row)
    width = max(r.shape[1] for r in rows)
    board = np.concatenate([np.pad(r, ((0, 0), (0, width - r.shape[1]), (0, 0)), constant_values=24) for r in rows], axis=0)
    Image.fromarray(board).resize((board.shape[1] * k, board.shape[0] * k), Image.NEAREST).save(out)
    print(f"normals | at night | lit from the left, top left, above, right in {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
