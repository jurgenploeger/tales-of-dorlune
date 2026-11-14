#!/usr/bin/env python3
"""How big each sprite's art pixels are on screen, in points, as the game draws it on a map.

After SpriteCook's pixel-perfect article (docs/spritecook-notes.md): a sprite whose pixels are a
different size from its neighbours' looks pasted on, however well its colours match (a "mixel").
The game sizes a sprite in points from its PNG (`ArtLibrary.sprite`: the PNG's pixels times the
asset's `scale` in art/assets.json, 1 unless set) and a ground tile to fill its cell
(`WorldMap.tileSize`, 44 points, over a 32-pixel tile). Walkers, monsters and most props are drawn a
point to a pixel; the world's pixels are measured against them.

  pixel_scale.py                 the report: each kind's sizes, and every sprite off the walkers' size
  pixel_scale.py --all           every sprite, not only the ones that are off
  pixel_scale.py --sheet OUT.png a hero, a monster, a tree, a house and the ground side by side, at
                                 their sizes in the game, three screen pixels to a point (a phone)

On top of that, the map sizes its scenery at random as it plants it: a theme prop's `size` range in
content/maps.json (`LandPlan`), a lair's natural ring 0.85 to 1.1, rocks 0.7 to 1.1, reeds 0.75 to 1.
The report lists the maps.json ranges; the ones in Swift are noted.

Battle scales every fighter alike (`BattleScene.fieldScale`), so it keeps them in step with each other.
Item icons and UI art are shown at the HUD's sizes and smoothed over 64 pixels (`IconTile`), not on the
map, so they're left out. Run from the repo root; needs Pillow.
"""
import argparse
import collections
import json
import os
import sys

from PIL import Image

ROOT = os.getcwd()
SPRITES = os.path.join(ROOT, "art", "sprites")
ASSETS = json.load(open(os.path.join(ROOT, "art", "assets.json")))["assets"]
BY_ID = {a["id"]: a for a in ASSETS}
# `WorldMap.tileSize` (TalesOfDorlune/World/WorldMap.swift) over a ground tile's 32 pixels.
CELL_POINTS = 44
TILE_PIXELS = 32
# The kinds drawn on the map, beside each other.
MAP_KINDS = ("walk_sheet", "monster", "prop", "building", "tile")
# How far from a point to a pixel still counts as the same size: a tenth either way.
TOLERANCE = 0.1


def png_size(art_id, depth=0):
    """The picture's size in pixels: its own PNG, else its base's (a `derive` has the base's size)."""
    path = os.path.join(SPRITES, art_id + ".png")
    if os.path.exists(path):
        return Image.open(path).size
    a = BY_ID.get(art_id) or {}
    base = (a.get("derive") or {}).get("from")
    if base and depth < 5:
        return png_size(base, depth + 1)
    layers = (a.get("derive") or {}).get("layers")
    if layers:
        return png_size(layers[0]["id"], depth + 1)
    return None


def points_per_pixel(a):
    """Points one art pixel covers on the map."""
    if a["kind"] == "tile":
        size = png_size(a["id"])
        return CELL_POINTS / (size[0] if size else TILE_PIXELS)
    return float(a.get("scale", 1))


def rows():
    out = []
    for a in ASSETS:
        if a["kind"] not in MAP_KINDS:
            continue
        size = png_size(a["id"])
        if size is None:
            continue
        out.append((a["id"], a["kind"], size, points_per_pixel(a), "derive" in a and not os.path.exists(os.path.join(SPRITES, a["id"] + ".png"))))
    return out


def planted_ranges():
    """Each theme prop's random size range in content/maps.json, with the asset's own scale on top."""
    maps = json.load(open(os.path.join(ROOT, "content", "maps.json")))
    maps = maps.get("maps", maps)
    found = collections.Counter()
    for m in (maps if isinstance(maps, list) else maps.values()):
        if not isinstance(m, dict):
            continue
        for prop in (m.get("theme") or {}).get("props", []):
            rng = prop.get("size")
            if rng and len(rng) == 2:
                s = float((BY_ID.get(prop["art"]) or {}).get("scale", 1))
                found[(round(rng[0] * s, 2), round(rng[1] * s, 2))] += 1
    return found


def report(show_all):
    table = rows()
    walker = 1.0
    print(f"Points per art pixel on the map (a walker's: {walker:g}; off by more than {TOLERANCE:.0%} is listed)\n")
    print(f"{'kind':<11} {'sprites':>7}  sizes (points per pixel: how many)")
    by_kind = collections.defaultdict(collections.Counter)
    for _, kind, _, ppp, _ in table:
        by_kind[kind][round(ppp, 3)] += 1
    for kind in MAP_KINDS:
        c = by_kind.get(kind)
        if not c:
            continue
        sizes = ", ".join(f"{k:g}: {v}" for k, v in sorted(c.items()))
        print(f"{kind:<11} {sum(c.values()):>7}  {sizes}")
    off = [r for r in table if abs(r[3] / walker - 1) > TOLERANCE]
    listed = table if show_all else off
    print(f"\n{len(off)} of {len(table)} sprites are drawn off the walkers' pixel size.")
    if listed:
        print(f"\n{'id':<28} {'kind':<11} {'png':>9} {'pt/px':>6} {'vs walker':>9}")
        for art_id, kind, size, ppp, derived in sorted(listed, key=lambda r: (r[1], -abs(r[3] - walker), r[0])):
            print(f"{art_id:<28} {kind:<11} {size[0]:>4}×{size[1]:<4} {ppp:>6.3g} {ppp / walker:>8.0%}" + ("  (swap)" if derived else ""))
    planted = planted_ranges()
    if planted:
        print(f"\nPlanted at a random size (content/maps.json theme props' `size`, times the asset's scale): "
              f"{sum(planted.values())} props, so two of one kind side by side differ in pixel size.")
        for (lo, hi), n in planted.most_common(8):
            print(f"  {lo:g} to {hi:g} pt/px: {n}")
        print("  Also in Swift (LandPlan): a lair's natural ring 0.85 to 1.1, rocks 0.7 to 1.1, reeds 0.75 to 1.")
    return 0


def sheet(out):
    """A hero, a monster, a tree, a house and a patch of ground at their map sizes, 3 screen pixels a point."""
    picks = []
    for want in ("player_walk", "monster_slime", "tree", "cottage", "tile_grass"):
        a = BY_ID.get(want)
        if a is None:
            a = next((b for b in ASSETS if b["kind"] == {"player_walk": "walk_sheet", "monster_slime": "monster", "tree": "prop",
                                                            "cottage": "building", "tile_grass": "tile"}[want]
                      and os.path.exists(os.path.join(SPRITES, b["id"] + ".png"))), None)
        if a is not None:
            picks.append(a)
    screen = 3
    tiles = []
    for a in picks:
        im = Image.open(os.path.join(SPRITES, a["id"] + ".png")).convert("RGBA")
        if a["kind"] == "walk_sheet":
            im = im.crop((0, 96, 48, 144))
        if a["kind"] == "tile":
            patch = Image.new("RGBA", (im.width * 2, im.height * 2))
            for dx in (0, im.width):
                for dy in (0, im.height):
                    patch.paste(im, (dx, dy))
            im = patch
        k = points_per_pixel(a) * screen
        # Nearest, as the game draws it: at a scale that isn't whole, some pixels come out a screen
        # pixel wider than others, which is what this is here to show.
        tiles.append((a["id"], points_per_pixel(a), im.resize((round(im.width * k), round(im.height * k)), Image.NEAREST)))
    width = sum(t.width for _, _, t in tiles) + 20 * (len(tiles) + 1)
    height = max(t.height for _, _, t in tiles) + 40
    canvas = Image.new("RGBA", (width, height), (112, 160, 88, 255))
    from PIL import ImageDraw
    d = ImageDraw.Draw(canvas)
    x = 20
    for art_id, ppp, t in tiles:
        canvas.alpha_composite(t, (x, height - 20 - t.height))
        d.text((x, 4), f"{art_id}\n{ppp:g} pt/px", fill=(255, 255, 255, 255))
        x += t.width + 20
    canvas.save(out)
    print("wrote", out)
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--all", action="store_true", help="list every sprite, not only the ones off the walkers' size")
    ap.add_argument("--sheet", metavar="OUT", help="draw a lineup at game size instead of the report")
    a = ap.parse_args()
    sys.exit(sheet(a.sheet) if a.sheet else report(a.all))


if __name__ == "__main__":
    main()
