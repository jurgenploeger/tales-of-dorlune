#!/usr/bin/env python3
"""Edge Wang tiles for the land's plain ground, after SpriteCook's Wang tiles article
(docs/spritecook-notes.md). Mirrors `ArtLibrary.wangPixels` and `GroundTiles.wang`; keep them in step.

The four versions a ground tile had (`ArtLibrary.tileVariant`) all kept the original's frame, so that
frame repeated along every cell edge and the field showed its grid. A Wang set has 16: each edge of a
cell is colour 0 or 1, and a tile's index is north + 2·east + 4·south + 8·west. Colour 0 is the
original tile's own pixels along that edge, so it meets every tile that keeps the old frame (roads,
ponds and patches are drawn on the original); colour 1 is the tile shifted (a different patch of the
same seamless texture), the same shift on both sides of the edge, so the two cells continue one patch.
Each tile's middle is the tile shifted again, its own for each index. Each corner (a few pixels
square, `corner_size`), where four cells meet, is the original in all of them, so they agree. Strips meet the middle along the
least-difference path (image quilting's minimum error boundary cut), never cross-faded: every pixel is
one of the tile's own.

Which colour an edge takes is a hash of its place in the world (so lands agree along their borders),
and it's 0 unless the cells on both sides are plain ground of the same tile (`GroundTiles.wang`).

  wang_art.py check                  every edge of a random field continues the tile as the tile
                                     continues itself, for every ground tile; nothing new in colour
  wang_art.py --preview OUT.png      before (the four framed versions) and after (Wang) side by side,
                                     a field of each of a few lands' ground, flat, at 2×
  wang_art.py --sheet OUT.png ID     the 16 tiles of one ground tile, at 4×

Run from the repo root; needs Pillow and numpy.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.getcwd()
SPRITES = os.path.join(ROOT, "art", "sprites")
GROUNDS = ["tile_grass", "tile_dark_grass", "tile_sand", "tile_desert", "tile_snow", "tile_scree",
           "tile_forest_floor", "tile_swamp", "tile_cave_floor", "tile_crystal_floor"]


def load(art_id):
    im = Image.open(os.path.join(SPRITES, art_id + ".png")).convert("RGBA")
    return np.asarray(im).astype(np.int32)


# ---------- the tiles (mirrors ArtLibrary.wangPixels) ----------

def shifted(tex, dx, dy):
    """The tile with its texture moved: pixel (x, y) shows the tile's ((x + dx) % n, (y + dy) % n)."""
    return np.roll(np.roll(tex, -dy, axis=0), -dx, axis=1)


def edge_shift(n, side, colour):
    """Where an edge's strip comes from: colour 0 the tile itself; colour 1 a patch half a tile away,
    north and south edges from one, east and west from another."""
    if colour == 0:
        return (0, 0)
    return (n // 2, n // 2) if side in ("north", "south") else (n // 4, n * 3 // 4)


def middle_shift(n, index):
    """Each index's middle: its own patch of the tile (never the original's, so even index 0 differs
    from the old tile inside)."""
    q = max(1, n // 8)
    return ((3 + 5 * index) * q % n, (1 + 3 * index) * q % n) if index else (n // 8 * 3, n // 8 * 5)


def cost(a, b):
    return np.abs(a[..., :3] - b[..., :3]).sum(axis=-1)


def cut_depths(strip, middle, n, band):
    """For a north edge (rows from the top): each column's depth, 2 to `band` rows, where the strip
    gives way to the middle, along the least-difference path whose depth moves at most a row a column
    (dynamic programming), as image quilting cuts."""
    lo, hi = 2, band
    depths = list(range(lo, hi + 1))
    err = cost(strip, middle)  # n × n
    inf = 1 << 40
    total = np.full((n, len(depths)), inf, dtype=np.int64)
    back = np.zeros((n, len(depths)), dtype=np.int64)
    for k, d in enumerate(depths):
        total[0, k] = err[d, 0]
    for x in range(1, n):
        for k, d in enumerate(depths):
            best, arg = inf, k
            for j in (k - 1, k, k + 1):
                if 0 <= j < len(depths) and total[x - 1, j] < best:
                    best, arg = total[x - 1, j], j
            total[x, k] = best + err[d, x]
            back[x, k] = arg
    k = int(np.argmin(total[n - 1]))
    out = [0] * n
    for x in range(n - 1, -1, -1):
        out[x] = depths[k]
        k = int(back[x, k])
    return out


def turn(a, side):
    """Turn a tile so `side` is at the top (north), and back with `unturn`."""
    return {"north": a, "east": np.rot90(a, 1), "south": np.rot90(a, 2), "west": np.rot90(a, 3)}[side]


def unturn(a, side):
    return {"north": a, "east": np.rot90(a, -1), "south": np.rot90(a, -2), "west": np.rot90(a, -3)}[side]


SIDES = ("north", "east", "south", "west")  # bits 1, 2, 4, 8


def wang_tile(tex, index):
    """Tile `index` (0 to 15) of a seamless n × n texture, RGBA int array, row 0 north."""
    n = tex.shape[0]
    band = max(3, n // 4)
    middle = shifted(tex, *middle_shift(n, index))
    out = middle.copy()
    ys, xs = np.mgrid[0:n, 0:n]
    dist = {"north": ys, "south": n - 1 - ys, "west": xs, "east": n - 1 - xs}
    nearest = np.argmin(np.stack([dist[s] for s in SIDES]), axis=0)
    for bit, side in enumerate(SIDES):
        colour = (index >> bit) & 1
        strip = shifted(tex, *edge_shift(n, side, colour))
        depths = cut_depths(turn(strip, side), turn(middle, side), n, band)
        # Rows above each column's depth, turned back: the strip's.
        mask_n = np.zeros((n, n), dtype=bool)
        for x, d in enumerate(depths):
            mask_n[:d, x] = True
        mask = unturn(mask_n, side) & (nearest == bit)
        out[mask] = strip[mask]
    # Each corner, where four cells meet, is the tile itself in all of them, so the four agree.
    c = corner_size(n)
    for y0 in (0, n - c):
        for x0 in (0, n - c):
            out[y0:y0 + c, x0:x0 + c] = tex[y0:y0 + c, x0:x0 + c]
    return out


def corner_size(n):
    return max(2, n // 10)


def old_variant(tex, index):
    """ArtLibrary.variantPixels as it was: shifted and mirrored inside a soft frame of the original."""
    n = tex.shape[0]
    shifts = [(0, 0, False, False), (n // 2, n // 2, False, False), (n // 4, n * 5 // 8, True, False), (n * 5 // 8, n // 4, False, True)]
    dx, dy, mx, my = shifts[index % 4]
    if index % 4 == 0:
        return tex.copy()
    out = tex.astype(float).copy()
    band = n / 5
    for y in range(n):
        for x in range(n):
            sx, sy = (x + dx) % n, (y + dy) % n
            if mx:
                sx = n - 1 - sx
            if my:
                sy = n - 1 - sy
            edge = min(x, y, n - 1 - x, n - 1 - y)
            t = max(0, min(1, (edge - 1) / band))
            inside = t * t * (3 - 2 * t)
            out[y, x] = tex[y, x] * (1 - inside) + tex[sy, sx] * inside
    return np.minimum(255, out).astype(np.int32)


# ---------- placing them (mirrors GroundTiles.wang) ----------

def mix(h):
    h &= (1 << 64) - 1
    h ^= h >> 29
    h = (h * 0xBF58476D1CE4E5B9) & ((1 << 64) - 1)
    h ^= h >> 32
    return h


def edge_colour(col, row, horizontal):
    """An edge's colour from its place in the world: the edge on the south side of world cell (col, row)
    if `horizontal`, else on its west side."""
    h = (col * 0x9E3779B97F4A7C15) ^ (row * 0xC2B2AE3D27D4EB4F) ^ (0x94D049BB133111EB if horizontal else 0)
    return mix(h) & 1


def wang_index(col, row, plain=lambda c, r: True):
    """Cell (col, row)'s tile: each edge its hashed colour, 0 where the cell across it isn't plain ground
    of the same tile (`plain`)."""
    north = edge_colour(col, row + 1, True) if plain(col, row + 1) else 0
    east = edge_colour(col + 1, row, False) if plain(col + 1, row) else 0
    south = edge_colour(col, row, True) if plain(col, row - 1) else 0
    west = edge_colour(col, row, False) if plain(col - 1, row) else 0
    return north + 2 * east + 4 * south + 8 * west


def old_index(col, row):
    """WorldScene.variant(of:)."""
    h = (col * 0x9E3779B97F4A7C15) ^ (row * 0xC2B2AE3D27D4EB4F)
    return mix(h) % 4


def field(tex, cols, rows, tile):
    n = tex.shape[0]
    out = np.zeros((rows * n, cols * n, 4), dtype=np.int32)
    for r in range(rows):
        for c in range(cols):
            y0 = (rows - 1 - r) * n  # row 0 south, at the bottom
            out[y0:y0 + n, c * n:(c + 1) * n] = tile(c, r)
    return out


def check():
    bad = 0
    for g in GROUNDS:
        if not os.path.exists(os.path.join(SPRITES, g + ".png")):
            continue
        tex = load(g)
        n = tex.shape[0]
        tiles = [wang_tile(tex, i) for i in range(16)]
        colours = {tuple(p) for p in tex.reshape(-1, 4)}
        new = sum(1 for t in tiles for p in t.reshape(-1, 4) if tuple(p) not in colours)
        # Pairs of pixels across each edge, as the tile has them across its own wrap.
        pairs_v = {(tuple(a), tuple(b)) for row in range(n) for x in range(n) for a, b in [(tex[row, x], tex[(row + 1) % n, x])]}
        pairs_h = {(tuple(a), tuple(b)) for y in range(n) for col in range(n) for a, b in [(tex[y, col], tex[y, (col + 1) % n])]}
        cols, rows = 20, 20
        plain = lambda c, r: (c * 7 + r * 3) % 11 != 0  # some cells not plain, as a road would leave
        idx = {(c, r): wang_index(c, r, plain) if plain(c, r) else None for c in range(-1, cols + 1) for r in range(-1, rows + 1)}
        seams = 0
        for (c, r), i in idx.items():
            if i is None or not (0 <= c < cols and 0 <= r < rows):
                continue
            t = tiles[i]
            # North: this tile's top row against the north cell's bottom row (the original if not plain).
            up = idx.get((c, r + 1))
            above = tiles[up] if up is not None else tex
            seams += sum((tuple(above[n - 1, x]), tuple(t[0, x])) not in pairs_v for x in range(n))
            right = idx.get((c + 1, r))
            beside = tiles[right] if right is not None else tex
            seams += sum((tuple(t[y, n - 1]), tuple(beside[y, 0])) not in pairs_h for y in range(n))
        print(f"{g}: {n}×{n}, 16 tiles; {new} pixels in a colour the tile hasn't; {seams} pixel pairs across "
              f"edges the tile never has side by side")
        bad += new + seams
    print("✓ every edge continues its tile, nothing new in colour" if bad == 0 else "✗ see above")
    return 1 if bad else 0


def to_image(a, z):
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    return im.resize((im.width * z, im.height * z), Image.NEAREST)


def far(a):
    """The field as the eye takes it in from far off: averaged over 4 × 4 pixels, its contrast
    stretched, shown at the same size, so any pattern repeating tile by tile stands out."""
    h, w = a.shape[0] // 4 * 4, a.shape[1] // 4 * 4
    luma = (0.299 * a[:h, :w, 0] + 0.587 * a[:h, :w, 1] + 0.114 * a[:h, :w, 2])
    small = luma.reshape(h // 4, 4, w // 4, 4).mean(axis=(1, 3))
    lo, hi = np.percentile(small, 2), np.percentile(small, 98)
    g = np.clip((small - lo) / max(1e-6, hi - lo) * 255, 0, 255).astype(np.uint8)
    im = Image.fromarray(g, "L").convert("RGBA")
    return im.resize((w * 2, h * 2), Image.NEAREST)


def preview(out, ids):
    z, cols, rows = 2, 12, 8
    panels = []
    for g in ids:
        if not os.path.exists(os.path.join(SPRITES, g + ".png")):
            continue
        tex = load(g)
        olds = [old_variant(tex, i) for i in range(4)]
        tiles = [wang_tile(tex, i) for i in range(16)]
        before = field(tex, cols, rows, lambda c, r: olds[old_index(c, r)])
        after = field(tex, cols, rows, lambda c, r: tiles[wang_index(c, r)])
        panels.append((g, to_image(before, z), to_image(after, z)))
        panels.append((g + ", zoomed out and blurred (a lattice shows as a grid)", far(before), far(after)))
    w = panels[0][1].width
    h = panels[0][1].height
    sheet = Image.new("RGBA", (w * 2 + 30, (h + 24) * len(panels)), (20, 20, 28, 255))
    d = ImageDraw.Draw(sheet)
    for k, (g, a, b) in enumerate(panels):
        y = k * (h + 24)
        d.text((4, y + 4), f"{g}: before (4 framed versions)", fill=(255, 255, 255, 255))
        d.text((w + 34, y + 4), "after (16 Wang tiles)", fill=(255, 255, 255, 255))
        sheet.alpha_composite(a, (0, y + 20))
        sheet.alpha_composite(b, (w + 30, y + 20))
    sheet.save(out)
    print("wrote", out)


def sheet16(out, art_id):
    tex = load(art_id)
    n = tex.shape[0]
    z = 4
    img = Image.new("RGBA", (4 * (n * z + 8), 4 * (n * z + 20)), (20, 20, 28, 255))
    d = ImageDraw.Draw(img)
    for i in range(16):
        x, y = (i % 4) * (n * z + 8), (i // 4) * (n * z + 20)
        img.alpha_composite(to_image(wang_tile(tex, i), z), (x, y + 16))
        bits = "".join("NESW"[b] if (i >> b) & 1 else "-" for b in range(4))
        d.text((x + 2, y + 2), f"{i} {bits}", fill=(255, 255, 255, 255))
    img.save(out)
    print("wrote", out)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", nargs="?", choices=["check"])
    ap.add_argument("--preview", metavar="OUT")
    ap.add_argument("--sheet", nargs=2, metavar=("OUT", "ID"))
    a = ap.parse_args()
    if a.preview:
        return preview(a.preview, ["tile_grass", "tile_sand", "tile_snow", "tile_dark_grass"])
    if a.sheet:
        return sheet16(*a.sheet)
    sys.exit(check())


if __name__ == "__main__":
    main()
