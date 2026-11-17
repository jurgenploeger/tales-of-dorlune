#!/usr/bin/env python3
"""Cliffs and terraces, previewed before they go in the game (the user, 2026-11-17: "I feel like our maps still
look a bit flat ... do a preview of the cliffs and terraces first so I can judge").

A patch of a land drawn as the game draws its ground (turned and squashed, `palette_preview.project`), on three
levels instead of one: each raised level's top drawn higher (`LIFTS`) and, where it ends at the front, a wall of
rock the height of the step, so you see up and down:

- the wall's two faces lit as everything is, from the top left: the face turned south-west light, the one
  turned south-east in shade; its rock in courses of stone with joints between, lighter along its lip and
  darker toward its foot;
- the grass of the top hanging over the lip in a ragged fringe, and a dark band on the ground at the foot,
  where the wall stands on it;
- a stream stepping down the levels, falling over each wall in a sheet of streaks into the next, and a pool;
- the land's trees and bushes on every level, a few rocks fallen at the walls' feet.

Left: the same patch flat, as the game draws it now. Right: terraced.

    python3 tools/cliff_preview.py out.png [map]

Needs pillow + numpy.
"""
import math
import pathlib
import random
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import palette_preview as pp  # noqa: E402

T, C = pp.T, pp.C
N = 16
# Screen pixels each level is raised: the first step about two thirds of a cell's height on screen, the
# second a taller cliff.
LIFTS = [0, 30, 74]
W, H = 560, 400


def level_field(gx, gy):
    """The level (0 to 2) at any ground point, its outline curving freely across the cells: a terrace across
    the back, a smaller one on it."""
    gx, gy = np.asarray(gx, float), np.asarray(gy, float)
    back = gx + gy + 1.4 * np.sin(gx * 0.7) + 0.9 * np.sin(gy * 1.1 + 0.5) + 0.5 * np.sin((gx - gy) * 1.7)
    top = gx + gy + 1.0 * np.sin(gx * 0.9 + 1) + 0.6 * np.sin(gy * 1.4)
    out = np.where(back >= 15, 1, 0)
    return np.where((top >= 22) & (gx + 0.8 * np.sin(gy) >= 6), 2, out)


def water_field(gx, gy):
    """The stream down the levels (two cells wide, winding a little) and the pool it falls into."""
    gx, gy = np.asarray(gx, float), np.asarray(gy, float)
    across = gx - gy - 2.5 - 0.6 * np.sin((gx + gy) * 0.45)
    stream = (np.abs(across) < 0.95) & (gx + gy >= 11)
    pool = ((gx - gy - 2.5) / 3.2) ** 2 + ((gx + gy - 9.5) / 2.6) ** 2 < 1
    return (stream | pool) & ~((level_field(gx, gy) > 0) & pool & ~stream)


def layout(seed=5):
    """What stands, on the levels: trees and bushes, bushes thick along the rims, rocks at the walls' feet."""
    rng = random.Random(seed)
    props = []
    trees = ["big_tree", "tree", "blossom_tree", "autumn_tree"]
    bushes = ["bush", "flowering_bush", "shore_grass"]
    for gy in range(N):
        for gx in range(N):
            cx, cy = gx + 0.5, gy + 0.5
            if water_field(cx, cy) or water_field(cx + 0.4, cy + 0.4) or water_field(cx - 0.4, cy - 0.4):
                continue
            lv = int(level_field(cx, cy))
            # Not just behind higher ground, where it would be hidden.
            if any(level_field(cx - k, cy - k) > lv for k in (0.6, 1.2, 1.8, 2.4)):
                continue
            near_edge = level_field(cx - 0.7, cy - 0.7) < lv
            roll = rng.random()
            if near_edge and roll < 0.5:
                props.append((rng.choice(bushes), cx - 0.15, cy - 0.15, lv, rng.uniform(0.8, 1.05)))
            elif roll < 0.13:
                props.append((rng.choice(trees), cx, cy, lv, rng.uniform(0.8, 1.0)))
            elif lv < 2 and level_field(cx + 0.8, cy + 0.8) > lv and roll < 0.6:
                # At a wall's foot, half over it: rocks fallen from it, bushes grown against it.
                art = "rock" if roll < 0.25 else rng.choice(["bush", "shore_grass", "flowering_bush"])
                props.append((art, cx + 0.25, cy + 0.25, lv, rng.uniform(0.5, 0.75) if art == "rock" else rng.uniform(0.85, 1.1)))
    props.append(("player_walk", 4.5, 3.5, 0, 1))
    return props


def grid_of(xs, ys, lift):
    """The ground point (in cells) a pixel shows on a level raised `lift` screen pixels."""
    ox, oy = pp.project(N * T / 2, N * T / 2)
    px = xs - W / 2 + ox
    py = (H / 2 - ys) + oy - lift
    gx = (py / (C * 0.5) + px / C) / 2 / T
    gy = (py / (C * 0.5) - px / C) / 2 / T
    return gx, gy


def screen_of(gx, gy, lift):
    ox, oy = pp.project(N * T / 2, N * T / 2)
    x, y = pp.project(gx * T, gy * T)
    return x - ox + W / 2, H / 2 - (y - oy) - lift


def level_at(terraced, gx, gy):
    inside = (gx >= 0) & (gx < N) & (gy >= 0) & (gy < N)
    out = np.where(inside, level_field(gx, gy), 0) if terraced else np.zeros(gx.shape, int)
    return out, inside


def speck(a, b, c=0):
    h = (a.astype(np.int64) * 73856093 ^ b.astype(np.int64) * 19349663 ^ c * 83492791) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def render(mid, terraced, seed=5):
    m = pp.maps[mid]
    palette = m["theme"].get("palette")
    grass = pp.grade(pp.raw(m["theme"]["ground"]), palette)[..., :3]
    water_tex = pp.grade(pp.raw("tile_water"), palette)[..., :3]
    props = layout(seed)
    img = np.zeros((H, W, 3))
    img[:] = (0.08, 0.1, 0.12)
    ys, xs = np.mgrid[0:H, 0:W].astype(float)
    S = grass.shape[0]
    rock_base = np.array([0.66, 0.6, 0.52])
    moss = np.array([0.36, 0.5, 0.24])
    for L in range(3):
        lift = LIFTS[L]
        gx, gy = grid_of(xs, ys, lift)
        lv, inside = level_at(terraced, gx, gy)
        top = inside & (lv >= L)
        u = ((gx % 1) * S).astype(int).clip(0, S - 1)
        v = ((1 - gy % 1) * S).astype(int).clip(0, S - 1)
        wet = inside & water_field(gx, gy)
        ground = grass[v, u]
        if terraced:
            # Deeper and less even, as the reference's: darker overall, broad patches lighter and darker,
            # and small dark tufts.
            sway = 0.8 + 0.1 * np.sin(gx * 0.9 + gy * 0.4) * np.sin(gy * 0.7 - gx * 0.3)
            tuft = speck(np.floor(gx * 6), np.floor(gy * 6), 61 + L) < 0.12
            ground = ground * (sway * np.where(tuft, 0.8, 1.0))[..., None]
            ground = ground * np.array([0.92, 1.0, 0.94])
        colour = np.where(wet[..., None], water_tex[v, u] * 0.92, ground)
        if terraced and L < 2:
            # The dark band at a wall's foot: the ground just in front of higher ground.
            for d, k in ((0.05, 0.5), (0.12, 0.68), (0.22, 0.84)):
                behind, _ = level_at(terraced, gx + d, gy + d)
                colour = np.where(((behind > L) & top)[..., None], colour * k, colour)
        if terraced and L > 0:
            # The top's rim a shade lighter, where it turns down into the wall.
            ahead, _ = level_at(terraced, gx - 0.07, gy - 0.07)
            colour = np.where(((ahead < L) & top & ~wet)[..., None], np.minimum(1, colour * 1.15), colour)
        img[top] = colour[top]
        if not terraced or L == 0:
            continue
        # The walls under level L's front edges: along each pixel's ray from the top down, the first point
        # inside ground of level L or higher, where the top itself isn't.
        top_clear = ~top
        found = np.zeros(gx.shape, bool)
        depth_px = np.zeros(gx.shape)
        hit_x = np.zeros(gx.shape)
        hit_y = np.zeros(gx.shape)
        tall = LIFTS[L] - LIFTS[L - 1]
        for k in range(1, tall + 1):
            hx, hy = grid_of(xs, ys, lift - k)
            hl, hin = level_at(terraced, hx, hy)
            hit = ~found & top_clear & hin & (hl >= L)
            if hit.any():
                depth_px = np.where(hit, k, depth_px)
                hit_x = np.where(hit, hx, hit_x)
                hit_y = np.where(hit, hy, hit_y)
                found |= hit
        if not found.any():
            continue
        v_px = depth_px.astype(int)
        # Which way the wall faces, from where the lower ground lies: south-west, lit from the top left;
        # south-east, in shade.
        west, _ = level_at(terraced, hit_x - 0.2, hit_y)
        south, _ = level_at(terraced, hit_x, hit_y - 0.2)
        faces_west, faces_south = west < L, south < L
        light = np.where(faces_west & ~faces_south, 1.1, np.where(faces_south & ~faces_west, 0.55, 0.82))
        # Boulders, not bricks: each pixel shaded by the nearest of a scatter of points (every 9 pixels or
        # so), darker at its edge where it meets the next, a crack between them.
        cell = 9.0
        bx, by = np.floor(xs / cell), np.floor(v_px / cell)
        best, second = np.full(xs.shape, 99.0), np.full(xs.shape, 99.0)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                cxp, cyp = bx + dx, by + dy
                fx = (cxp + speck(cxp, cyp, 11 + L)) * cell
                fy = (cyp + speck(cxp, cyp, 23 + L)) * cell * 0.8
                d = np.hypot(xs - fx, v_px - fy)
                second = np.where(d < best, best, np.minimum(second, d))
                best = np.minimum(best, d)
        edge = second - best
        bulge = 1 - 0.22 * np.clip(best / cell, 0, 1)
        tint = 0.93 + 0.1 * speck(bx, by, 5 + L)
        rock = rock_base * (light * bulge * tint)[..., None]
        rock = np.where((edge < 1.2)[..., None], rock * 0.55, rock)
        rock = np.where(((edge > 1.2) & (edge < 2.2) & (best < 3))[..., None], np.minimum(1, rock * 1.12), rock)
        # Moss on the upper stones here and there.
        mossy = (v_px < tall * 0.45) & (speck(np.floor(xs / 5), np.floor(v_px / 4), 31 + L) < 0.28)
        rock = np.where(mossy[..., None], moss * light[..., None], rock)
        # Darker toward the foot, where less light reaches.
        rock = rock * (1 - 0.35 * (v_px / tall) ** 2)[..., None]
        # Grass hanging over the lip: a ragged fringe a few pixels down each column.
        hang = 1 + (speck(xs.astype(int), np.zeros_like(xs, dtype=int), 7) * 5).astype(int)
        fringe = v_px <= hang
        blade = grass[(v_px % S).clip(0, S - 1), (xs.astype(int) % S)] * 0.82
        rock = np.where(fringe[..., None], blade, rock)
        # Where the stream comes over, a sheet of falling water instead of rock: streaks running down,
        # foam where it lands.
        # Narrower than the stream, its sides ragged a pixel or two column by column, blue at its top
        # turning paler as it falls, streaked, foaming where it lands.
        column = xs.astype(int)
        ragged = 0.55 + 0.18 * speck(column // 2, np.zeros_like(column), 13)
        across = hit_x - hit_y - 2.5 - 0.6 * np.sin((hit_x + hit_y) * 0.45)
        fall = (np.abs(across) < ragged) & water_field(hit_x, hit_y)
        streak = speck(column, np.zeros_like(column), 3)
        depth_t = (v_px / tall)[..., None]
        blue = water_tex[8, 8] * 0.95
        body = blue + (np.array([0.82, 0.94, 0.97]) - blue) * (depth_t * 0.7)
        sheet = np.where(((v_px + (streak * 9).astype(int)) % 7 < 2)[..., None], np.minimum(1, body * 1.18 + 0.06), body)
        sheet = np.where((np.abs(across) > ragged - 0.12)[..., None], blue * 0.78, sheet)
        foam = (v_px >= tall - 3) & (speck(column, v_px, 17) < 0.7)
        sheet = np.where(foam[..., None], [0.96, 0.99, 1.0], sheet)
        rock = np.where(fall[..., None], sheet, rock)
        img[found] = rock[found]
    # Foam where each fall lands: the water just in front of a wall the stream comes over.
    if terraced:
        for L in range(2):
            gx, gy = grid_of(xs, ys, LIFTS[L])
            lv, inside = level_at(terraced, gx, gy)
            behind, _ = level_at(terraced, gx + 0.25, gy + 0.25)
            splash = inside & (lv == L) & (behind > L) & water_field(gx, gy) & water_field(gx + 0.3, gy + 0.3)
            churn = speck(xs.astype(int), ys.astype(int), 41) < 0.55
            img[splash & churn] = (0.95, 0.99, 1.0)
    # What stands, back to front.
    drawn = []
    for art, gx, gy, lv, scale in props:
        s = pp.sprite(art, None if art == "player_walk" else palette)
        if scale != 1:
            h, w = s.shape[:2]
            s = np.asarray(Image.fromarray((s * 255).astype(np.uint8)).resize((max(1, round(w * scale)), max(1, round(h * scale))),
                                                                              Image.NEAREST)).astype(float) / 255
        sx, sy = screen_of(gx, gy, LIFTS[lv] if terraced else 0)
        rows = np.where((s[..., 3] > 0.5).any(1))[0]
        foot = rows[-1] if len(rows) else s.shape[0] - 1
        drawn.append((sy, s, int(sx - s.shape[1] / 2), int(sy - foot)))
    for _, s, x0, y0 in sorted(drawn, key=lambda d: d[0]):
        h, w = s.shape[:2]
        xa, ya, xb, yb = max(0, x0), max(0, y0), min(W, x0 + w), min(H, y0 + h)
        if xa >= xb or ya >= yb:
            continue
        part = s[ya - y0:yb - y0, xa - x0:xb - x0]
        a = (part[..., 3:] > 0.5).astype(float)
        img[ya:yb, xa:xb] = img[ya:yb, xa:xb] * (1 - a) + part[..., :3] * a
    return Image.fromarray((img.clip(0, 1) * 255).astype(np.uint8))


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    out = argv[0]
    mid = argv[1] if len(argv) > 1 else "sunny_meadow"
    flat, steps = render(mid, False), render(mid, True)
    sheet = Image.new("RGB", (W * 2 + 8, H), (20, 20, 24))
    sheet.paste(flat, (0, 0))
    sheet.paste(steps, (W + 8, 0))
    sheet.resize((sheet.width * 2, H * 2), Image.NEAREST).save(out)
    print("wrote", out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
