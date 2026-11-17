#!/usr/bin/env python3
"""A town's raised terraces in stacked sandstone (the user's pick from `tools/terrace_preview.py`,
2026-11-17), drawn in code: no Retro Diffusion art is redrawn, these replace the flat-shaded slab
`LandStage.placePlateaus` drew and the balustrade it set along the edges.

- `terrace_wall_s.png`, `_w.png` (and `_2`, `_3`): one cell's stretch of the retaining wall under a
  front edge, as the game sees it: sheared along the edge (the south one rising to the right, the west
  one to the left), `RISE` points tall, courses of sandstone blocks, a capstone course along the lip, a
  dark line at the foot. The west face is turned to the light, the south one in shade, as everything is
  lit from the top left. A course's blocks repeat at every cell's edge, so the cells meet whole.
- `terrace_rail_s.png`, `_w.png`: one cell's stretch of the balustrade on the lip, sheared the same way: a
  base course, piers with gaps between them, a capping rail lit along its top.
- `terrace_post.png`: a square post at the corners and either side of the stairs.
- `terrace_flag.png` (and `_2` to `_4`): the paving of the top, flagstones half a cell across, every
  other row shifted half a stone; a tile, seen from above as the ground is.

One art pixel to one of the world's points (a cell's edge is 31.11 points across and 15.56 up on screen,
`WorldMap.project`). Keep `RISE` and `RAIL` in step with `WorldMap.terraceHeight` and
`LandStage.railHeight`.

    python3 tools/terrace_art.py              # writes the PNGs into art/sprites/
    python3 tools/terrace_art.py --sheet out.png

Needs pillow + numpy.
"""
import pathlib
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "art" / "sprites"

EDGE_X, EDGE_Y = 31, 16          # one cell's edge on screen, in pixels (31.11 by 15.56 points)
RISE = 34                        # the wall's height (WorldMap.terraceHeight)
RAIL = 14                        # the balustrade's height
CELL = 44.0                      # a cell's edge in the ground's points

SAND = np.array([206.0, 170, 118])
MORTAR = np.array([96.0, 70, 48])
OUTLINE = SAND * 0.6               # a deep shade of the stone (pixel_style `outline_rel`)


def h(a, b, c=0):
    a = np.asarray(a, np.int64)
    b = np.asarray(b, np.int64)
    v = (a * 73856093 ^ b * 19349663 ^ c * 83492791) & 0xFFFFFFFF
    v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((v ^ (v >> 16)) & 0xFFFF) / 65535.0


def face_coords(height, rising):
    """Each pixel of a sheared face one cell long: how far along the edge (in the ground's points, 0 to 44)
    and how high above it (points); `rising` for an edge climbing to the right."""
    w, hgt = EDGE_X, EDGE_Y + height
    ys, xs = np.mgrid[0:hgt, 0:w].astype(float)
    x = xs + 0.5
    if not rising:
        x = w - x
    up = hgt - (ys + 0.5)
    z = up - x * (EDGE_Y / EDGE_X)
    along = x / EDGE_X * CELL
    return along, z, (w, hgt)


def wall(seed, light, rising):
    along, z, (w, hgt) = face_coords(RISE, rising)
    on = (z >= 0) & (z < RISE)
    course = np.floor(z / 7.0)
    in_course = z - course * 7.0
    length = CELL / 4                                  # four blocks to a cell, so the cells meet whole
    shift = (course % 2) * length / 2
    idx = np.floor((along + shift) / length)
    in_block = along + shift - idx * length
    tone = 0.86 + 0.24 * h(np.mod(idx, 4), course, seed)
    col = SAND[None, None, :] * tone[..., None]
    col = np.where((in_course > 5.6)[..., None], col * 0.76, col)                 # each block's shaded underside
    col = np.where((in_course < 1.2)[..., None], col * 1.1, col)                  # lit along its top
    # A little grain in clumps of two or three pixels, three steps of it.
    grain = (np.floor(h(np.floor(along / 2.8), np.floor(z / 2), seed + 5) * 3) - 1) * 7
    col = col + grain[..., None]
    col = np.where(((in_course < 0.9) | (in_block < 0.9))[..., None], MORTAR, col)
    # The capstones along the lip: a lighter course with a dark line under it.
    cap = z >= RISE - 4
    col = np.where(cap[..., None], SAND * (1.12 + 0.06 * h(np.floor(along / 11), 0, seed + 9))[..., None], col)
    col = np.where(((z >= RISE - 5) & (z < RISE - 4))[..., None], MORTAR, col)
    col = np.where((z >= RISE - 1)[..., None], np.minimum(255, SAND * 1.28), col)  # the lip catching the light
    # Darker toward the foot, and an outline along it.
    col = col * (0.84 + 0.16 * np.clip(course * 7 / RISE, 0, 1))[..., None] * light   # course by course
    col = np.where((z < 1)[..., None], col * (0.72 if light >= 1 else 0.84), col)
    return rgba(col, on)


def rail(light, rising):
    along, z, (w, hgt) = face_coords(RAIL, rising)
    on = (z >= 0) & (z < RAIL)
    m = np.mod(along, CELL / 4)                       # four piers to a cell
    pier = (m >= 2) & (m < 7)
    cap = z >= RAIL - 4
    base = z < 3
    solid = on & (cap | base | pier)
    col = SAND[None, None, :] * light * (0.95 + 0.08 * h(np.floor(along / 11), np.floor(z / 3), 3))[..., None]
    col = np.where(cap[..., None], col * 1.12, col)
    col = np.where((z >= RAIL - 1)[..., None], np.minimum(255, SAND * 1.25), col)
    col = np.where(((z >= RAIL - 5) & (z < RAIL - 4))[..., None], OUTLINE, col)    # the rail's shadow on the piers
    edge = pier & ~cap & ~base & ((m < 3) | (m >= 6))
    col = np.where((edge & (m < 3))[..., None], col * 1.12, col)                   # each pier lit on its left
    col = np.where((edge & (m >= 6))[..., None], col * 0.7, col)
    col = np.where((z < 1)[..., None], OUTLINE, col)
    return rgba(col, solid)


def post():
    """A square post, a cap on top: 10 pixels across, its two faces turned to the light and away."""
    w, hgt = 10, RAIL + 9
    ys, xs = np.mgrid[0:hgt, 0:w].astype(float)
    up = hgt - (ys + 0.5)
    x = xs + 0.5
    on = up <= RAIL + 6 - np.abs(x - 5) * 0.5
    col = np.where((x < 5)[..., None], SAND * 1.05, SAND * 0.78)
    col = col * (0.82 + 0.18 * np.clip(up / RAIL, 0, 1))[..., None]          # darker toward its foot
    col = np.where(((np.mod(up, 6) < 1) & (up < RAIL))[..., None], col * 0.8, col)   # its courses
    top = up > RAIL + 2 - np.abs(x - 5) * 0.5
    col = np.where(top[..., None], np.minimum(255, SAND * 1.25), col)
    col = np.where(((up > RAIL + 1 - np.abs(x - 5) * 0.5) & ~top)[..., None], OUTLINE, col)
    rim = on & ~np.roll(on, 1, axis=1) | on & ~np.roll(on, -1, axis=1) | on & ~np.roll(on, 1, axis=0)
    rim |= on & ((x < 1) | (x > w - 1) | (up < 1))
    col = np.where(rim[..., None], OUTLINE, col)
    return rgba(col, on)


def flag(seed):
    """32 by 32, flagstones of 16, every other row shifted 8: it tiles."""
    ys, xs = np.mgrid[0:32, 0:32]
    row = ys // 16
    sx = np.mod(xs + (row % 2) * 8, 32)
    fx = sx // 16
    u, v = sx % 16, ys % 16
    tone = 0.88 + 0.18 * h(fx, row, seed)
    col = SAND[None, None, :] * 1.04 * tone[..., None]
    col = col + ((h(xs // 3, ys // 2, seed + 7) - 0.5) * 10)[..., None]
    col = np.where(((u == 15) | (v == 15))[..., None], col * 0.82, col)            # each stone's shaded edge
    col = np.where(((u == 1) | (v == 1))[..., None], np.minimum(255, col * 1.1), col)
    col = np.where(((u == 0) | (v == 0))[..., None], MORTAR, col)
    return rgba(col, np.ones((32, 32), bool))


def rgba(col, on):
    # Hue-shifted: the shades lean cool and purple, the lights warm and yellow.
    t = col.mean(axis=-1, keepdims=True) / SAND.mean() - 1
    col = col + np.where(t > 0, t * np.array([34.0, 18, -42]), t * np.array([18.0, 10, -16]))
    out = np.zeros(on.shape + (4,), np.uint8)
    out[..., :3] = np.clip(col, 0, 255).astype(np.uint8)
    out[..., 3] = np.where(on, 255, 0)
    return Image.fromarray(out, "RGBA")


def pieces():
    out = {}
    for i, seed in enumerate((11, 23, 37)):
        suffix = "" if i == 0 else f"_{i + 1}"
        out[f"terrace_wall_s{suffix}"] = wall(seed, 0.8, rising=True)
        out[f"terrace_wall_w{suffix}"] = wall(seed, 1.0, rising=False)
    out["terrace_rail_s"] = rail(0.82, rising=True)
    out["terrace_rail_w"] = rail(1.0, rising=False)
    out["terrace_post"] = post()
    for i, seed in enumerate((3, 5, 7, 13)):
        out["terrace_flag" + ("" if i == 0 else f"_{i + 1}")] = flag(seed)
    return out


def main(argv):
    made = pieces()
    if argv[:1] == ["--sheet"]:
        tiles = list(made.values())
        sheet = Image.new("RGBA", (sum(t.width + 6 for t in tiles) + 6, max(t.height for t in tiles) + 12), (60, 120, 60, 255))
        x = 6
        for t in tiles:
            sheet.alpha_composite(t, (x, 6))
            x += t.width + 6
        sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(argv[1])
        print(argv[1])
        return 0
    for name, img in made.items():
        img.save(OUT / f"{name}.png")
    print("wrote", len(made), "sprites")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
