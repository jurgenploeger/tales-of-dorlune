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


def bump(gx, gy):
    """How the ground rises and dips, -1 to 1, slowly across the cells."""
    return (0.5 * np.sin(gx * 1.3 + gy * 0.4) + 0.3 * np.sin(gy * 1.7 - gx * 0.6 + 1) + 0.2 * np.sin((gx + gy) * 2.3))


def top_height(L, gx, gy):
    """Screen pixels the top of level L stands at a ground point: its step's, rising and dipping a few."""
    return LIFTS[L] + (6 if L > 0 else 2) * bump(gx, gy)


def shrub(seed, width):
    """A mass of leafy shrubs, as the reference's thickets: round clumps of leaves heaped together, each lit
    on its top left and darker at its foot and bottom right, leaves speckled, a dark line round the whole.
    RGBA floats, `width` pixels across."""
    rng = random.Random(seed)
    w, h = width, int(width * 0.8)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    shade = np.full((h, w), -1.0)
    clumps = []
    for _ in range(4 + width // 10):
        r = rng.uniform(0.18, 0.3) * width
        cx = rng.uniform(r, w - r)
        cy = rng.uniform(h - r * 1.1 - h * 0.35, h - r)
        clumps.append((cy, cx, r))
    for cy, cx, r in sorted(clumps):              # back (higher) first, each over the one behind
        d = np.hypot(xx - cx, (yy - cy) * 1.15)
        inside = d <= r
        light = 0.5 + 0.5 * ((cx - xx) + (cy - yy) * 1.3) / (r * 1.8) - 0.25 * (d / r) ** 2
        shade = np.where(inside, np.clip(light, 0, 1), shade)
    out = np.zeros((h, w, 4))
    solid = shade >= 0
    ramp = np.array([[0.16, 0.32, 0.13], [0.27, 0.5, 0.18], [0.4, 0.66, 0.22], [0.6, 0.84, 0.34]])
    leaf = speck(xx.astype(int), yy.astype(int), seed) * 0.35
    level = np.clip((shade + leaf - 0.1) * 3.2, 0, 3).astype(int)
    out[solid, :3] = ramp[level[solid]]
    out[solid, 3] = 1
    rim = np.zeros_like(solid)
    rim[1:] |= solid[:-1]
    rim[:-1] |= solid[1:]
    rim[:, 1:] |= solid[:, :-1]
    rim[:, :-1] |= solid[:, 1:]
    rim &= ~solid
    out[rim, :3] = (0.07, 0.15, 0.07)
    out[rim, 3] = 1
    # A few flowers on some.
    if rng.random() < 0.4:
        colour = rng.choice([(1, 0.95, 0.6), (1, 1, 1), (1, 0.7, 0.8)])
        for _ in range(width // 6):
            y, x = rng.randrange(h), rng.randrange(w)
            if solid[y, x] and shade[y, x] > 0.4:
                out[y, x, :3] = colour
    return out


def boulder(seed, width):
    """A big boulder, as the reference's rock formations: a blocky lump with a flat lit top, a front face in
    shade, a crack or two, moss on its top, a dark line round it."""
    rng = random.Random(seed)
    w, h = width, int(width * rng.uniform(0.6, 0.85))
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    cx, cy = w / 2, h / 2
    shape = (np.abs(xx - cx) / (w / 2 - 1)) ** 2.6 + (np.abs(yy - cy) / (h / 2 - 1)) ** 2.6 <= 1
    lip = h * rng.uniform(0.32, 0.42)
    top = yy < lip + 2 * np.sin(xx * 0.4 + seed)
    base = np.array([0.7, 0.64, 0.54])
    light = np.where(top, 1.15, 0.78 - 0.25 * (yy - lip) / h) * (1 + 0.25 * (cx - xx) / w)
    colour = base * (light * (0.94 + 0.1 * speck(xx.astype(int) // 3, yy.astype(int) // 3, seed)))[..., None]
    moss = top & (speck(xx.astype(int) // 2, yy.astype(int) // 2, seed + 9) < 0.45)
    colour = np.where(moss[..., None], [0.34, 0.5, 0.22], colour)
    crack = (~top) & (np.abs(xx - (cx + w * 0.15 * math.sin(seed))) < 0.8) & (yy > lip + 2)
    colour = np.where(crack[..., None], colour * 0.55, colour)
    edge = top & (np.abs(yy - lip - 2 * np.sin(xx * 0.4 + seed)) < 1)
    colour = np.where(edge[..., None], colour * 0.8, colour)
    out = np.zeros((h, w, 4))
    out[shape, :3] = colour[shape]
    out[shape, 3] = 1
    rim = np.zeros_like(shape)
    rim[1:] |= shape[:-1]
    rim[:-1] |= shape[1:]
    rim[:, 1:] |= shape[:, :-1]
    rim[:, :-1] |= shape[:, 1:]
    rim &= ~shape
    out[rim, :3] = (0.2, 0.18, 0.17)
    out[rim, 3] = 1
    return out


def layout(seed=5):
    """What stands, on the levels: trees and bushes, bushes thick along the rims, rocks at the walls' feet."""
    rng = random.Random(seed)
    props = []
    trees = ["big_tree", "tree", "blossom_tree", "autumn_tree"]
    bushes = ["bush", "flowering_bush", "shore_grass"]
    for gy in range(N):
        for gx in range(N):
            cx, cy = gx + 0.5, gy + 0.5
            # Clear of the water all round, not standing in the pool or the stream.
            if any(water_field(cx + dx, cy + dy) for dx in (-0.7, 0, 0.7) for dy in (-0.7, 0, 0.7)):
                continue
            lv = int(level_field(cx, cy))
            # Not just behind higher ground, where it would be hidden.
            if any(level_field(cx - k, cy - k) > lv for k in (0.6, 1.2, 1.8, 2.4)):
                continue
            # On a top, well back from its lip; in front of a wall, far enough out that nothing reaches up
            # over it: the wall's foot is this far up the screen, about 31 pixels a cell straight back.
            if level_field(cx - 0.6, cy - 0.6) < lv:
                continue
            back = next((k for k in np.arange(0.25, 5, 0.25) if level_field(cx + k, cy + k) > lv), None)
            room = 99 if back is None else back * T * C
            roll = rng.random()
            near_rim = level_field(cx - 1.2, cy - 1.2) < lv
            # Thickets in patches across the land, thickest along the rims; boulders here and there, more
            # on the tops; trees where there's room.
            thicket = math.sin(cx * 0.8 + cy * 0.3) + math.sin(cy * 0.9 - cx * 0.5) > 0.4
            jx, jy = rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3)
            if roll < 0.12 and room > 130:
                props.append((rng.choice(trees), cx + jx, cy + jy, lv, rng.uniform(0.8, 1.0)))
            elif (thicket or near_rim) and roll < 0.55 and room > 50:
                props.append(("thicket", cx + jx, cy + jy, lv, rng.uniform(0.6, 0.85)))
            elif 0.55 <= roll < 0.62 and room > 60 and (lv > 0 or thicket):
                props.append(("rock_formation_large", cx + jx, cy + jy, lv, rng.uniform(0.55, 0.75)))
            elif 0.62 <= roll < 0.67 and room > 40:
                props.append(("rock_formation_small", cx + jx, cy + jy, lv, rng.uniform(0.5, 0.7)))
            elif 0.67 <= roll < 0.77 and room > 30:
                props.append(("fern_clump", cx + jx, cy + jy, lv, rng.uniform(0.8, 1.0)))
            elif 0.77 <= roll < 0.87 and room > 26:
                props.append(("flower_patch", cx + jx, cy + jy, lv, rng.uniform(0.8, 1.0)))
            elif 0.87 <= roll < 0.93 and room > 30:
                props.append((rng.choice(bushes), cx + jx, cy + jy, lv, rng.uniform(0.8, 1.05)))
    # Stones round the pool's rim, and lily pads on it.
    for k in range(18):
        t = 2 * math.pi * k / 18
        a_, b_ = 3.5, 2.9
        across, along = a_ * math.cos(t), b_ * math.sin(t)
        gx, gy = (along + across) / 2 + (9.5 + 2.5) / 2, (along - across) / 2 + (9.5 - 2.5) / 2
        if level_field(gx, gy) == 0 and not water_field(gx + 0.45, gy + 0.45) is False and rng.random() < 0.8:
            props.append(("mossy_boulder", gx, gy, 0, rng.uniform(0.35, 0.5)))
    for _ in range(4):
        across, along = rng.uniform(-1.8, 1.8), rng.uniform(-1.5, 1.5)
        gx, gy = (along + across) / 2 + 6.0, (along - across) / 2 + 3.5
        if water_field(gx, gy):
            props.append(("lily_pad", gx, gy, 0, 1))
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
    grass = pp.grade(pp.raw("tile_rich_grass" if terraced else m["theme"]["ground"]), palette)[..., :3]
    cliff = pp.grade(pp.raw("tile_cliff_rock"), palette)[..., :3]
    water_tex = pp.grade(pp.raw("tile_water"), palette)[..., :3]
    props = layout(seed)
    img = np.zeros((H, W, 3))
    img[:] = (0.08, 0.1, 0.12)
    ys, xs = np.mgrid[0:H, 0:W].astype(float)
    S = grass.shape[0]
    rock_base = np.array([0.66, 0.6, 0.52])
    moss = np.array([0.36, 0.5, 0.24])
    for L in range(len(LIFTS)):
        # The top of level L isn't flat: it rises and dips a few pixels (`top_height`), so where it lies
        # on screen depends on where on the ground it is: found by settling on it a few times.
        gx, gy = grid_of(xs, ys, LIFTS[L])
        for _ in range(3):
            gx, gy = grid_of(xs, ys, top_height(L, gx, gy) if terraced else 0)
        lv, inside = level_at(terraced, gx, gy)
        top = inside & (lv >= L)
        u = ((gx % 1) * S).astype(int).clip(0, S - 1)
        v = ((1 - gy % 1) * S).astype(int).clip(0, S - 1)
        wet = inside & water_field(gx, gy)
        ground = grass[v, u]
        if terraced:
            # Deeper and less even, as the reference's: darker overall, broad patches lighter and darker,
            # and small dark tufts; and lit by how it rises and dips, from the top left (north on the
            # ground: the light falls on what rises toward it).
            sway = 0.8 + 0.1 * np.sin(gx * 0.9 + gy * 0.4) * np.sin(gy * 0.7 - gx * 0.3)
            tuft = speck(np.floor(gx * 6), np.floor(gy * 6), 61 + L) < 0.12
            rise = (bump(gx, gy + 0.08) - bump(gx, gy - 0.08)) / 0.16
            lean = (bump(gx + 0.08, gy) - bump(gx - 0.08, gy)) / 0.16
            relief = np.clip(1 - 0.16 * rise + 0.06 * lean, 0.78, 1.18)
            ground = ground * (sway * relief * np.where(tuft, 0.8, 1.0))[..., None]
            ground = ground * np.array([0.92, 1.0, 0.94])
        colour = np.where(wet[..., None], water_tex[v, u] * 0.92, ground)
        if terraced and L < len(LIFTS) - 1:
            # The dark band at a wall's foot: the ground just in front of higher ground.
            for d, k in ((0.05, 0.5), (0.12, 0.68), (0.22, 0.84)):
                behind, _ = level_at(terraced, gx + d, gy + d)
                colour = np.where(((behind > L) & top)[..., None], colour * k, colour)
        if terraced and L > 0:
            # The top rounding over into the wall: a lighter band, then its very lip a shade darker.
            for d, k in ((0.04, 0.82), (0.1, 1.14)):
                ahead, _ = level_at(terraced, gx - d, gy - d)
                colour = np.where(((ahead < L) & top & ~wet)[..., None], np.minimum(1, colour * k), colour)
        img[top] = colour[top]
        if not terraced or L == 0:
            continue
        # The walls under level L's front edges: along each pixel's ray, from above the top down to the
        # ground below, the first point inside the rock (on level L's ground, under its top, over the
        # ground below), where the top itself isn't.
        top_clear = ~top
        found = np.zeros(gx.shape, bool)
        hit_x, hit_y, hit_z = np.zeros(gx.shape), np.zeros(gx.shape), np.zeros(gx.shape)
        for z in range(LIFTS[L] + 8, LIFTS[L - 1] - 4, -1):
            hx, hy = grid_of(xs, ys, z)
            hl, hin = level_at(terraced, hx, hy)
            solid = hin & (hl >= L) & (z <= top_height(L, hx, hy)) & (z >= top_height(L - 1, hx, hy))
            hit = ~found & top_clear & solid
            if hit.any():
                hit_x = np.where(hit, hx, hit_x)
                hit_y = np.where(hit, hy, hit_y)
                hit_z = np.where(hit, z, hit_z)
                found |= hit
        if not found.any():
            continue
        # Each column's wall measured from its own top edge down (the run of wall pixels it's in), so the
        # stone and the light run on smoothly from column to column: worked out from each pixel's own
        # height, they jumped a pixel or two between columns and the walls showed vertical lines.
        start = np.zeros(found.shape)
        stop = np.zeros(found.shape)
        run = np.full(W, -1.0)
        for row in range(H):
            run = np.where(found[row], np.where(run < 0, row, run), -1.0)
            start[row] = run
        run = np.full(W, -1.0)
        for row in range(H - 1, -1, -1):
            run = np.where(found[row], np.where(run < 0, row, run), -1.0)
            stop[row] = run
        v_px = np.where(found, ys - start, 0)
        tall = np.maximum(1, stop - start + 1)
        # Which way the wall faces, from how its top edge runs across the screen: down to the right, it faces
        # south-west into the light from the top left; up to the right, south-east into shade.
        lip_row = np.where(found, start, np.nan)
        ahead = np.roll(lip_row, -3, axis=1)
        behind = np.roll(lip_row, 3, axis=1)
        slope = np.nan_to_num((ahead - behind) / 6, nan=0.0)
        light = 0.82 + 0.56 * np.clip(slope, -0.5, 0.5)
        # Big stones, not cobbles, as a rock face's: each rounded, lit on its top left and shadowed on its
        # bottom right about its middle (the nearest of a scatter of points, every 15 pixels or so), its upper
        # part a paler ledge where it turns to the sky, a dark crack where it meets the next.
        cell = 15.0
        # The stones laid out on the screen itself, so they run on unbroken where a wall bends and its top
        # edge climbs steeply; only the moss, the dark foot and the fringe go by the column's own top edge.
        bx, by = np.floor(xs / cell), np.floor(ys / (cell * 0.8))
        best, second = np.full(xs.shape, 99.0), np.full(xs.shape, 99.0)
        mid_x, mid_y = np.zeros(xs.shape), np.zeros(xs.shape)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                cxp, cyp = bx + dx, by + dy
                fx = (cxp + speck(cxp, cyp, 11 + L)) * cell
                fy = (cyp + 0.2 + 0.6 * speck(cxp, cyp, 23 + L)) * cell * 0.8
                d = np.hypot((xs - fx) * 0.85, ys - fy)
                closer = d < best
                second = np.where(closer, best, np.minimum(second, d))
                mid_x, mid_y = np.where(closer, fx, mid_x), np.where(closer, fy, mid_y)
                best = np.minimum(best, d)
        edge = second - best
        round_ = np.clip(1 + 0.4 * ((mid_x - xs) + (mid_y - ys)) / cell, 0.65, 1.3)
        ledge = (ys - mid_y) < -cell * 0.22
        # Retro Diffusion's rock face (`tile_cliff_rock`) laid on the screen, under the stones' light.
        face = cliff[(ys.astype(int) % cliff.shape[0]), (xs.astype(int) % cliff.shape[1])]
        rock = face * 1.05 * (light * (0.75 + 0.25 * round_) * np.where(ledge, 1.1, 1.0))[..., None]
        rock = np.where((edge < 1.4)[..., None], rock * 0.45, rock)
        # Moss on the upper stones' ledges here and there.
        mossy = ledge & (v_px < tall * 0.6) & (speck(bx, by, 31 + L) < 0.35)
        rock = np.where(mossy[..., None], moss * (light * round_)[..., None], rock)
        # Darker toward the foot, where less light reaches.
        rock = rock * (1 - 0.35 * np.clip(v_px / tall, 0, 1) ** 2)[..., None]
        # Grass hanging over the lip: a ragged fringe a few pixels down each column.
        hang = 1 + (speck(xs.astype(int), np.zeros_like(xs, dtype=int), 7) * 5).astype(int)
        fringe = v_px <= hang
        blade = grass[(v_px.astype(int) % S).clip(0, S - 1), (xs.astype(int) % S)] * 0.82
        rock = np.where(fringe[..., None], blade, rock)
        # Where the stream comes over, a sheet of falling water instead of rock, exactly the stream's width so
        # it meets the stream above and below: blue at its top turning paler as it falls, streaked, its sides
        # a shade darker, foaming where it lands.
        column = xs.astype(int)
        across = hit_x - hit_y - 2.5 - 0.6 * np.sin((hit_x + hit_y) * 0.45)
        fall = water_field(hit_x, hit_y)
        streak = speck(column, np.zeros_like(column), 3)
        depth_t = np.clip(v_px / tall, 0, 1)[..., None]
        blue = water_tex[8, 8] * 0.95
        body = blue + (np.array([0.82, 0.94, 0.97]) - blue) * (depth_t * 0.7)
        sheet = np.where(((v_px.astype(int) + (streak * 9).astype(int)) % 7 < 2)[..., None], np.minimum(1, body * 1.18 + 0.06), body)
        side = np.abs(across) > 0.95 - 0.1 - 0.12 * speck(column // 2, np.zeros_like(column), 13)
        sheet = np.where(side[..., None], blue * 0.78, sheet)
        foam = (v_px >= tall - 3) & (speck(column, v_px.astype(int), 17) < 0.7)
        sheet = np.where(foam[..., None], [0.96, 0.99, 1.0], sheet)
        rock = np.where(fall[..., None], sheet, rock)
        img[found] = rock[found]
    # Foam where each fall lands: the water just in front of a wall the stream comes over.
    if terraced:
        for L in range(len(LIFTS) - 1):
            gx, gy = grid_of(xs, ys, LIFTS[L])
            for _ in range(3):
                gx, gy = grid_of(xs, ys, top_height(L, gx, gy))
            lv, inside = level_at(terraced, gx, gy)
            behind, _ = level_at(terraced, gx + 0.25, gy + 0.25)
            splash = inside & (lv == L) & (behind > L) & water_field(gx, gy) & water_field(gx + 0.3, gy + 0.3)
            churn = speck(xs.astype(int), ys.astype(int), 41) < 0.55
            img[splash & churn] = (0.95, 0.99, 1.0)
    # What stands, back to front.
    drawn = []
    for art, gx, gy, lv, scale in props:
        if art == "@shrub":
            s = shrub(int(gx * 97 + gy * 31), int(scale))
        elif art == "@boulder":
            s = boulder(int(gx * 53 + gy * 17), int(scale))
        else:
            s = pp.sprite(art, None if art == "player_walk" else palette)
        if art.startswith("@"):
            pass
        elif scale != 1:
            h, w = s.shape[:2]
            s = np.asarray(Image.fromarray((s * 255).astype(np.uint8)).resize((max(1, round(w * scale)), max(1, round(h * scale))),
                                                                              Image.NEAREST)).astype(float) / 255
        sx, sy = screen_of(gx, gy, float(top_height(lv, gx, gy)) if terraced else 0)
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
