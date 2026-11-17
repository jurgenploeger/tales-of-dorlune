#!/usr/bin/env python3
"""Less boring lands, previewed before they go in the game (the user, 2026-11-17: "The world building needs to
be better and less boring lands"; asked for all four of: places to find, forests and clearings, ground that
varies, life in the lands).

A patch of Sunny Meadow drawn as the game draws a land (turned and squashed, `palette_preview.project`, graded
with its palette), with the land's own tiles and sprites, twice:

- As now: its props scattered evenly over one ground, each kind in small clusters (`LandPlanner`), the
  farm's pieces (scarecrow, haystacks, pumpkins) dotted about on their own like the trees.
- Proposed:
  - groves and clearings: trees thick where a slow noise field is high and next to none where it's low, so
    there are woods and open meadows, with bushes and ferns along the woods' edges;
  - ground that varies: broad soft patches of the land's richer grass and of wildflowers, and worn earth
    round where people go;
  - places to find: the land's scattered pieces put together into scenes, a farm (a fenced field of pumpkins
    in rows, a scarecrow in it, haystacks by the gate) and a ruin in a clearing (a ring of standing stones
    round a broken pillar), each with a footpath to the road;
  - life: chicks pecking round the farm and rabbits in the meadow, as the critters the game already has.

    python3 tools/land_preview.py out.png [map]

Needs pillow + numpy.
"""
import math
import pathlib
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import palette_preview as pp  # noqa: E402

T, C = pp.T, pp.C
N = 22
W, H = 760, 520
SPR = pathlib.Path(__file__).resolve().parent.parent / "art" / "sprites"


def screen_of(gx, gy):
    ox, oy = pp.project(N * T / 2, N * T / 2)
    x, y = pp.project(gx * T, gy * T)
    return x - ox + W / 2, H / 2 - (y - oy) + 30


def grid_of(xs, ys):
    ox, oy = pp.project(N * T / 2, N * T / 2)
    px = xs - W / 2 + ox
    py = (H / 2 + 30 - ys) + oy
    return (py / (C * 0.5) + px / C) / 2 / T, (py / (C * 0.5) - px / C) / 2 / T


def noise(gx, gy, seed, scale):
    """A smooth field, -1 to 1: a few sines at odd angles."""
    r = random.Random(seed)
    out = 0
    for k in range(4):
        a, b, c = r.uniform(0, 6.28), r.uniform(0.6, 1.4) / scale, r.uniform(0, 6.28)
        out = out + np.sin((gx * math.cos(a) + gy * math.sin(a)) * b * (1 + k * 0.7) + c) / (1 + k)
    return out / 2.1


class Art:
    def __init__(self, mid):
        self.m = pp.maps[mid]
        self.palette = self.m["theme"].get("palette")
        self.cache = {}

    def tile(self, name):
        if name not in self.cache:
            self.cache[name] = (pp.grade(pp.raw(name), self.palette)[..., :3] * 255).astype(float)
        return self.cache[name]

    def sprite(self, name, scale=1.0):
        key = (name, scale)
        if key not in self.cache:
            try:
                arr = pp.grade(pp.raw(name), self.palette)
            except Exception:
                arr = np.asarray(Image.open(SPR / f"{name}.png").convert("RGBA")).astype(float) / 255
            img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA")
            s = scale * pp_scale(name)
            img = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.NEAREST)
            self.cache[key] = img
        return self.cache[key]


def pp_scale(name):
    import json
    if not hasattr(pp_scale, "by"):
        a = json.load(open(SPR.parent / "assets.json"))
        a = a.get("assets", a)
        pp_scale.by = {x["id"]: x.get("scale", 1) for x in a}
    return pp_scale.by.get(name, 1)


def road(gx, gy):
    """How far into the road a point is (cells; below 0 off it): one winding road across the patch."""
    centre = 9 + 1.6 * np.sin(gx * 0.35) + 0.6 * np.sin(gx * 0.9 + 1)
    return 0.95 - np.abs(gy - centre)


def ground(art, proposed, farm, ruin, paths):
    grass, rich, flowers, dirt = art.tile("tile_grass"), art.tile("tile_rich_grass"), art.tile("tile_flowers"), art.tile("tile_path")
    ys, xs = np.mgrid[0:H, 0:W].astype(float)
    gx, gy = grid_of(xs + 0.5, ys + 0.5)
    u = np.mod((gx * 32).astype(int), 32)
    v = np.mod((gy * 32).astype(int), 32)
    out = grass[v, u]
    if proposed:
        n1 = noise(gx, gy, 11, 3.0)
        n2 = noise(gx, gy, 23, 2.2)
        dither = (np.mod(xs.astype(int) + ys.astype(int) * 3, 4) / 4 - 0.4) * 0.12
        out = np.where((n1 + dither > 0.42)[..., None], rich[v, u], out)
        # The farm's field: tilled earth in furrows across it.
        fx, fy = farm
        field = (gx > fx) & (gx < fx + 5) & (gy > fy) & (gy < fy + 3)
        furrow = np.mod(gy - fy, 0.6) < 0.22
        out = np.where(field[..., None], dirt[v, u] * np.where(furrow, 0.62, 0.85)[..., None] * np.array([1.0, 0.86, 0.72]), out)
        # Worn earth round the farm's gate and in the ruin's ring, and the footpaths to them.
        worn = np.full(gx.shape, -9.0)
        for (cx, cy, r) in [(farm[0] + 2.5, farm[1] - 0.8, 1.6), (ruin[0], ruin[1], 1.7)]:
            worn = np.maximum(worn, r - np.hypot(gx - cx, gy - cy))
        for (ax, ay, bx, by) in paths:
            t = np.clip(((gx - ax) * (bx - ax) + (gy - ay) * (by - ay)) / ((bx - ax) ** 2 + (by - ay) ** 2), 0, 1)
            d = np.hypot(gx - (ax + t * (bx - ax)), gy - (ay + t * (by - ay)))
            worn = np.maximum(worn, 0.38 + 0.06 * np.sin(gx * 3 + gy * 2) - d)
        out = np.where((worn + dither * 0.5 > 0)[..., None], dirt[v, u] * 0.97, out)
    r = road(gx, gy)
    out = np.where((r > 0)[..., None], dirt[v, u] * np.where(r < 0.06, 0.75, 1)[..., None], out)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def free(gx, gy, taken, reach=0.7):
    if road(gx, gy) > -0.4:
        return False
    return all(math.hypot(gx - a, gy - b) > reach for a, b in taken)


def place_now(rng):
    """As the game lays it now: the land's mix, spread evenly, a few of a kind together."""
    kinds = ["tree"] * 10 + ["big_tree"] * 2 + ["blossom_tree"] * 2 + ["autumn_tree"] + ["bush"] * 4 + ["flowering_bush"] + \
        ["daisy"] * 3 + ["fern_clump"] * 2 + ["flower_patch"] * 2 + ["thicket"] + ["haystack", "pumpkin_patch", "scarecrow", "mossy_boulder"]
    items, taken = [], []
    for _ in range(170):
        gx, gy = rng.uniform(0, N), rng.uniform(0, N)
        if free(gx, gy, taken, 0.9):
            k = rng.choice(kinds)
            items.append((k, gx, gy, rng.uniform(0.85, 1.05)))
            taken.append((gx, gy))
    return items


def place_proposed(rng, farm, ruin):
    items, taken = [], []
    fx, fy = farm
    # The farm: a fence round a 5 by 3 field, pumpkins in rows, a scarecrow in it, haystacks by its gate.
    for i in range(5):
        for j in range(3):
            if (i, j) != (2, 1):
                items.append(("pumpkin_patch", fx + 0.5 + i, fy + 0.5 + j * 1.0, 0.9))
    items.append(("scarecrow", fx + 2.5, fy + 1.9, 1.0))
    items += [("haystack", fx + 4.2, fy - 1.0, 0.95), ("haystack", fx + 5.0, fy - 1.5, 0.85), ("signpost", fx + 1.0, fy - 1.1, 0.9)]
    items += [("critter_chick_peck", fx + 3.0, fy - 0.9, 1.0), ("critter_chick_hop", fx + 3.6, fy - 1.4, 1.0), ("critter_chick_sit", fx + 2.3, fy - 1.5, 1.0)]
    for x in range(fx - 1, fx + 7):
        for y in range(fy - 2, fy + 5):
            taken.append((x + 0.5, y + 0.5))
    # The ruin: standing stones round a broken pillar in a clearing.
    rx, ry = ruin
    for k in range(7):
        a = k / 7 * 6.283 + 0.4
        if k == 5:
            continue                                   # one fallen, a gap toward the path
        items.append(("standing_stone", rx + 1.6 * math.cos(a), ry + 1.6 * math.sin(a), 0.9))
    items += [("broken_pillar", rx, ry, 1.0), ("mossy_boulder", rx + 1.2, ry + 1.6, 0.6)]
    for x in range(-3, 4):
        for y in range(-3, 4):
            taken.append((rx + x, ry + y))
    # Groves: trees where the field is high, almost none where it's low; their edges in bushes and ferns.
    trees = ["tree"] * 5 + ["big_tree"] * 2 + ["blossom_tree"] + ["autumn_tree"]
    for _ in range(900):
        gx, gy = rng.uniform(-1, N + 1), rng.uniform(-1, N + 1)
        n = float(noise(np.array(gx), np.array(gy), 5, 2.6))
        if n > 0.2 and free(gx, gy, taken, 0.75):
            items.append((rng.choice(trees), gx, gy, rng.uniform(0.85, 1.05)))
            taken.append((gx, gy))
        elif -0.05 < n <= 0.15 and rng.random() < 0.35 and free(gx, gy, taken, 0.75):
            items.append((rng.choice(["bush", "fern_clump", "thicket", "flowering_bush"]), gx, gy, rng.uniform(0.8, 1.0)))
            taken.append((gx, gy))
        elif n <= -0.05 and float(noise(np.array(gx), np.array(gy), 23, 1.6)) > 0.4 and rng.random() < 0.5 and free(gx, gy, taken, 0.45):
            # Wildflowers in drifts in the meadow, not dotted all over it.
            items.append((rng.choice(["daisy", "daisy", "flower_patch", "daisy_yellow"]), gx, gy, 0.9))
            taken.append((gx, gy))
    # Rabbits in the meadow.
    for _ in range(4):
        for _ in range(40):
            gx, gy = rng.uniform(1, N - 1), rng.uniform(1, N - 1)
            if float(noise(np.array(gx), np.array(gy), 5, 2.6)) < -0.2 and free(gx, gy, taken, 0.9):
                items.append((rng.choice(["critter_bunny_brown_sit", "critter_bunny_white_hop", "critter_bunny_grey_sit"]), gx, gy, 1.0))
                taken.append((gx, gy))
                break
    return items


def render(art, proposed, seed=3):
    rng = random.Random(seed)
    farm, ruin = (3, 13), (15.5, 4.5)
    paths = [(farm[0] + 2.5, farm[1] - 0.8, farm[0] + 2.8, 10.4), (ruin[0], ruin[1] + 1.8, ruin[0] - 0.3, 7.6)]
    img = ground(art, proposed, farm, ruin, paths)
    items = place_proposed(rng, farm, ruin) if proposed else place_now(rng)
    for name, gx, gy, s in sorted(items, key=lambda q: -(q[1] + q[2])):
        spr = art.sprite(name, s)
        x, y = screen_of(gx, gy)
        img.alpha_composite(spr, (int(x - spr.width / 2), int(y - spr.height * 0.92)))
    return img


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    out = argv[0]
    art = Art(argv[1] if len(argv) > 1 else "sunny_meadow")
    a, b = render(art, False), render(art, True)
    board = Image.new("RGB", (W * 2 + 30, H + 36), (24, 30, 46))
    board.paste(a, (10, 10))
    board.paste(b, (W + 20, 10))
    d = ImageDraw.Draw(board)
    d.text((14, H + 16), "As now", fill=(255, 255, 255))
    d.text((W + 24, H + 16), "Proposed: groves and clearings, varied ground, a farm and a ruin with paths to them, critters", fill=(255, 255, 255))
    board.save(out)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
