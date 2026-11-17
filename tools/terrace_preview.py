#!/usr/bin/env python3
"""A town's raised terraces (maps.json town `terraces`, `WorldMap.raiseTerrace`, drawn by
`LandStage.placePlateaus`), previewed in two new looks before they go in the game (the user, 2026-11-17,
of Goldburg's: "This elevation should be more like the terraces we did today or another way of elevation").

Now each is a flat-shaded slab: its top paved in the land's accent tile, its walls that tile darkened, a
plain line along the lip. Proposed, drawn as the game draws the ground (turned and squashed,
`palette_preview.project`), the top raised `RISE` points:

- Rock: as the hills' terraces (`HillLooks.terraced`): the top is the town's own ground, its lip a little
  ragged; the walls are the cliffs' rock (`tile_cliff_rock`), lit from the top left, lighter at the lip and
  darker toward the foot, with shade on the ground at their feet; steps cut into the rock.
- Masonry: a retaining wall of stacked sandstone blocks in courses, a capstone row along the lip that sticks
  out a little, the top paved in the town's path; shade at the foot; stone steps.

    python3 tools/terrace_preview.py out.png [map]

Needs pillow + numpy.
"""
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import palette_preview as pp  # noqa: E402

T, C = pp.T, pp.C
N = 12
X0, X1, Y0, Y1 = 2.0, 10.0, 5.0, 9.0            # the terrace, in cells
STAIRS_S = (5.0, Y0)                             # a stair cell in the middle of the front (south) side
STAIRS_W = (X0, 6.0)                             # and of the left (west) side
RISE = 34.0                                      # points (26 now)
W, H = 520, 330


def screen_of(gx, gy, lift):
    ox, oy = pp.project(N * T / 2, N * T / 2)
    x, y = pp.project(gx * T, gy * T)
    return x - ox + W / 2, H / 2 - (y - oy) - lift


def grid_of(xs, ys, lift):
    ox, oy = pp.project(N * T / 2, N * T / 2)
    px = xs - W / 2 + ox
    py = (H / 2 - ys) + oy - lift
    return (py / (C * 0.5) + px / C) / 2 / T, (py / (C * 0.5) - px / C) / 2 / T


def h(a, b, c=0):
    a = np.asarray(a, np.int64)
    b = np.asarray(b, np.int64)
    v = (a * 73856093 ^ b * 19349663 ^ c * 83492791) & 0xFFFFFFFF
    v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((v ^ (v >> 16)) & 0xFFFF) / 65535.0


def sample(tex, u, v):
    """Texture pixels at (u, v) in its own pixels, wrapping."""
    th, tw = tex.shape[:2]
    return tex[np.mod(v.astype(int), th), np.mod(u.astype(int), tw)]


def in_stairs(gx, gy):
    s = (gx >= STAIRS_S[0]) & (gx < STAIRS_S[0] + 1) & (gy >= STAIRS_S[1]) & (gy < STAIRS_S[1] + 1)
    w = (gx >= STAIRS_W[0]) & (gx < STAIRS_W[0] + 1) & (gy >= STAIRS_W[1]) & (gy < STAIRS_W[1] + 1)
    return s, w


def blocks(along, height, light):
    """Stacked sandstone blocks at (along, height) on a face in points: courses 7 high, each block its own
    length and tone, dark mortar between, each block lit along its top."""
    course = np.floor(height / 7.0)
    in_course = height - course * 7.0
    shift = h(course, 1) * 14
    length = 13 + 0 * along
    idx = np.floor((along + shift) / length)
    in_block = along + shift - idx * length
    tone = 0.86 + 0.24 * h(idx, course, 3)
    base = np.array([206.0, 170, 118])[None, :] * tone[:, None]
    base = np.where((in_course > 5.6)[:, None], base * 0.74, base)            # its shaded underside
    base = np.where((in_course < 1.2)[:, None], base * 1.12, base)            # lit along its top
    mortar = (in_course < 0.8) | (in_block < 1.0)
    base = np.where(mortar[:, None], np.array([92.0, 70, 50])[None, :], base)
    grain = (h(np.floor(along * 1.5), np.floor(height * 1.5), 5) - 0.5) * 18
    return (base + grain[:, None]) * light


def render(mid, style):
    m = pp.maps[mid]
    palette = m["theme"].get("palette")
    ground = pp.grade(pp.raw(m["theme"]["ground"]), palette)[..., :3].astype(float) * 255
    path = pp.grade(pp.raw(m["theme"].get("path", "tile_scree")), palette)[..., :3].astype(float) * 255
    rock = pp.grade(pp.raw("tile_cliff_rock"), palette)[..., :3].astype(float) * 255
    ys, xs = np.mgrid[0:H, 0:W].astype(float)
    xs, ys = xs.ravel() + 0.5, ys.ravel() + 0.5
    px = 32 / T                                                               # texture pixels a point
    out = np.zeros((xs.size, 3))
    # The ground everywhere, its shade at the walls' feet.
    gx, gy = grid_of(xs, ys, 0)
    out[:] = sample(ground, gx * T * px, gy * T * px)
    foot_s = (gx >= X0) & (gx < X1) & (gy < Y0) & (gy > Y0 - 0.45)
    foot_w = (gy >= Y0) & (gy < Y1) & (gx < X0) & (gx > X0 - 0.45)
    depth = np.where(foot_s, (Y0 - gy) / 0.45, np.where(foot_w, (X0 - gx) / 0.45, 1))
    out *= (0.62 + 0.38 * np.clip(depth, 0, 1) ** 0.7)[:, None]
    # The top, raised.
    tx, ty = grid_of(xs, ys, RISE)
    rag = (h(np.floor(tx * 6), np.floor(ty * 6), 7) * 0.06) if style == "rock" else 0
    lip = 0.0 if style == "rock" else 0.06                                     # the capstones stick out
    on_top = (tx >= X0 - lip - rag) & (tx < X1) & (ty >= Y0 - lip - rag) & (ty < Y1)
    top_tex = ground if style == "rock" else path
    top = sample(top_tex, tx * T * px, ty * T * px)
    if style == "masonry":
        # Flagstones, half a cell each, every other row shifted half a stone.
        fy = np.floor(ty * 2)
        fx = np.floor(tx * 2 + 0.5 * (fy % 2))
        u, v = tx * 2 + 0.5 * (fy % 2) - fx, ty * 2 - fy
        tone = 0.88 + 0.18 * h(fx, fy, 13)
        flag = np.array([214.0, 186, 140])[None, :] * tone[:, None] + ((h(np.floor(tx * 30), np.floor(ty * 30), 4) - 0.5) * 14)[:, None]
        flag = np.where(((u < 0.06) | (v < 0.08))[:, None], np.array([120.0, 92, 64])[None, :], flag)
        flag = np.where(((u > 0.94) | (v > 0.9))[:, None], flag * 1.1, flag)
        top = flag
        cap = (tx < X0 + 0.1) | (ty < Y0 + 0.1)
        top = np.where(cap[:, None], np.array([222.0, 190, 140])[None, :] * (0.92 + 0.12 * h(np.floor(tx * 3), np.floor(ty * 3), 9))[:, None], top)
    else:
        top = top * 1.08                                                       # the plateau in the open light
        edge = (tx < X0 + 0.04) | (ty < Y0 + 0.04)
        top = np.where(edge[:, None], top * 1.15, top)                         # the lip catches the light
    back = (tx > X1 - 0.03) | (ty > Y1 - 0.03)
    top = np.where(back[:, None], top * 0.62, top)                             # its back edge against the ground behind
    # Faces: the south one (lower right on screen) and the west one (lower left).
    faces = np.zeros(xs.size, bool)
    face_col = np.zeros((xs.size, 3))
    ox, oy = pp.project(N * T / 2, N * T / 2)

    def plane(kind, c, lo, hi, floor=None):
        """A wall in the plane gy = c (`south`, facing down-right) or gx = c (`west`, down-left), from lo to hi
        along it: where each pixel lies on it, how high, and whether it's on it (above `floor(g)` if given)."""
        if kind == "south":
            g = (xs - W / 2 + ox) / (C * T) + c
            z = screen_of(g, c, 0)[1] - ys
        else:
            g = c - (xs - W / 2 + ox) / (C * T)
            z = screen_of(c, g, 0)[1] - ys
        bottom = 0 if floor is None else floor(g)
        return g, z, (g >= lo) & (g < hi) & (z >= bottom) & (z <= RISE)

    cheeks = [plane("west", STAIRS_S[0] + 1, Y0, Y0 + 1, lambda g: (g - Y0) * RISE),
              plane("south", STAIRS_W[1] + 1, X0, X0 + 1, lambda g: (g - X0) * RISE)]
    for (g, z, valid), light in zip(cheeks, (1.0, 0.78)):
        col = blocks(g * T, z, light) if style == "masonry" else sample(rock, g * T * px * 1.3, (RISE - z) * px * 1.3) * (light * 0.85)
        face_col = np.where(valid[:, None], col, face_col)
        faces |= valid
    for side in ("south", "west"):
        # Along the face, its screen x fixes where; its screen y, how high.
        if side == "south":
            ex, _ = grid_of(xs, ys, 0)
            # Points on the south face: (g, Y0, z). x = (g - Y0) * C * T - ox + W/2.
            ox, oy = pp.project(N * T / 2, N * T / 2)
            g = (xs - W / 2 + ox) / (C * T) + Y0
            sx, sy = screen_of(g, Y0, 0)
            z = sy - ys
            valid = (g >= X0) & (g < X1) & (z >= 0) & (z <= RISE) & ~((g >= STAIRS_S[0]) & (g < STAIRS_S[0] + 1))
            along = (g - X0) * T
            light = 0.78
        else:
            ox, oy = pp.project(N * T / 2, N * T / 2)
            g = X0 - (xs - W / 2 + ox) / (C * T)
            sx, sy = screen_of(X0, g, 0)
            z = sy - ys
            valid = (g >= Y0) & (g < Y1) & (z >= 0) & (z <= RISE) & ~((g >= STAIRS_W[1]) & (g < STAIRS_W[1] + 1))
            along = (g - Y0) * T
            light = 1.0
        if style == "rock":
            jag = (h(np.floor(along / 5), 0, 11 if side == "south" else 12) - 0.5) * 3
            valid &= z <= RISE + jag
            col = sample(rock, along * px * 1.3, (RISE - z) * px * 1.3)
            ramp = 1.08 - 0.42 * np.clip(1 - z / RISE, 0, 1) ** 1.4                         # lighter at the lip, dark at the foot
            col = col * (ramp * light)[:, None] if np.ndim(light) else col * (ramp * light)[:, None]
        else:
            col = blocks(along, z, light)
            col *= (0.82 + 0.18 * (z / RISE))[:, None]
        face_col = np.where(valid[:, None], col, face_col)
        faces |= valid
    # Stairs: a slope up each stair cell, with treads.
    stair = np.zeros(xs.size, bool)
    stair_col = np.zeros((xs.size, 3))
    for lift in np.linspace(RISE, 0, 70):
        sgx, sgy = grid_of(xs, ys, lift)
        s, w = in_stairs(sgx, sgy)
        want = np.where(s, (sgy - Y0) * RISE, np.where(w, (sgx - X0) * RISE, -99))
        hit = (s | w) & (np.abs(want - lift) < RISE / 60) & ~stair
        t = np.where(s, sgy - Y0, sgx - X0)
        tread = (t * 5) % 1
        base = np.array([200.0, 178, 140]) if style == "masonry" else sample(rock, sgx * T * px, sgy * T * px) * 1.1
        base = np.broadcast_to(base, (xs.size, 3)) if np.ndim(base) == 1 else base
        col = np.where((tread < 0.25)[:, None], base * 0.7, base)
        stair_col = np.where(hit[:, None], col, stair_col)
        stair |= hit
    out = np.where(on_top[:, None], top, out)
    out = np.where(faces[:, None], face_col, out)
    out = np.where(stair[:, None], stair_col, out)
    return Image.fromarray(np.clip(out.reshape(H, W, 3), 0, 255).astype(np.uint8))


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    out = argv[0]
    mid = argv[1] if len(argv) > 1 else "goldburg"
    panels = [(render(mid, "rock"), "Rock, as the hills' terraces"), (render(mid, "masonry"), "Masonry: stacked sandstone")]
    sheet = Image.new("RGB", (W * 2 + 30, H + 30), (24, 30, 46))
    d = ImageDraw.Draw(sheet)
    for i, (img, title) in enumerate(panels):
        sheet.paste(img, (10 + i * (W + 10), 10))
        d.text((14 + i * (W + 10), H + 14), title, fill=(255, 255, 255))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(out)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
