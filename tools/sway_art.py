#!/usr/bin/env python3
"""Buildings' hanging signs, lanterns and flags moving in the wind (the user, 2026-11-22: "Is there anything
from the current buildings we have that we can animate to make everything feel more alive? Like a wooden sign
that moves").

They move as the trees do (`tools/wind_art.py`, art/wind.json, `WindRig`): a building's moving pieces are cut
into clumps of its own pixels, moved a whole pixel at a time, still in calm air, and set swinging by the gusts
that cross the land, timed by where the building stands. Nothing is drawn: RD's art and ChatGPT's stay as they
are, only their pixels move.

- `swing`: a sign or lantern hanging from a hook, cut into rows below `hook`; each row swings out by how far
  below the hook it hangs (a pendulum, its bottom `reach` pixels at most), pushed by the gust and swinging back
  past upright, settling by its end (`wind_art.push`).
- `flutter`: a flag on a pole at column `pole`, cut into columns; a wave runs out along it from the pole, more
  at its tip, through the gust.

Behind a piece hanging in the air there's nothing, so as it swings the pixels it leaves are clear (the rig's
`clear` clumps); where the building stands right beside it (`BACKED`), or it hangs against a wall
(`wall=True`), it leaves the crown's shade, as a tree's clumps do, which reads as its shadow on the wall.

`wind_art.py` writes these rigs into art/wind.json with the trees' and checks them; rerun it after editing a
piece here, or after redrawing a building that has one.

    python3 tools/sway_art.py --sheet out.png [ids]   # each building's pieces, marked
    python3 tools/sway_art.py --gif out.gif [ids]     # them through a gust

Needs pillow + numpy.
"""
import math
import pathlib
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPRITES = ROOT / "art" / "sprites"
sys.path.insert(0, str(ROOT / "tools"))


def swing(box, hook, reach=2, wall=False, period=1.4, hues=None, sat=0.0):
    """`hues` (degrees, lo to hi, wrapping past 360) and `sat` keep to the piece's own colours inside its box, grown a
    pixel for its outline: a lantern hung on a wall, the wall round it staying put."""
    return dict(kind="swing", box=box, hook=hook, reach=reach, wall=wall, period=period, hues=hues, sat=sat)


def flutter(box, pole, reach=1, wall=False):
    return dict(kind="flutter", box=box, pole=pole, reach=reach, wall=wall)


# Each building's moving pieces: `box` is (x0, y0, x1, y1), inclusive, in its PNG's pixels; every opaque pixel
# in it (below `hook`) moves.
PIECES = {
    "weapon_shop": [swing((99, 85, 116, 101), hook=84, wall=True, hues=(0, 360), sat=0.2)],  # not the grey stone
    "armour_shop": [swing((104, 77, 117, 90), hook=76)],
    "tailor_shop": [swing((101, 76, 117, 91), hook=75, wall=True)],
    "book_shop": [swing((104, 79, 117, 93), hook=78)],
    "flower_shop": [swing((100, 86, 116, 103), hook=85)],
    "gem_workshop": [swing((102, 86, 118, 104), hook=85)],
    "tea_house": [swing((104, 85, 117, 99), hook=84, wall=True), swing((13, 87, 29, 94), hook=86, reach=1)],
    "apothecary": [swing((19, 82, 33, 99), hook=81)],
    "emerald_shop": [swing((100, 77, 113, 97), hook=76)],
    # Its lanterns' own colours (red, blue, green, purple: anything but the browns of the timber and plaster).
    "glass_lantern_shop": [swing((33, 62, 39, 76), hook=62, reach=1, wall=True, hues=(50, 15), sat=0.4),
                           swing((43, 62, 49, 76), hook=62, reach=1, wall=True, hues=(50, 15), sat=0.4),
                           swing((69, 62, 75, 76), hook=62, reach=1, wall=True, hues=(50, 15), sat=0.4),
                           swing((79, 62, 85, 76), hook=62, reach=1, wall=True, hues=(50, 15), sat=0.4)],
    # Its glass lanterns' teal, the pale stone behind them staying put.
    "firefly_house": [swing((20, 70, 32, 88), hook=70, reach=1, wall=True, hues=(150, 225), sat=0.12),
                      swing((41, 70, 53, 90), hook=70, reach=1, wall=True, hues=(150, 225), sat=0.12),
                      swing((71, 70, 84, 90), hook=70, reach=1, wall=True, hues=(150, 225), sat=0.12),
                      swing((96, 70, 109, 88), hook=70, reach=1, hues=(150, 225), sat=0.12)],
    "moon_pagoda": [swing((26, 44, 35, 57), hook=44, reach=1), swing((97, 44, 106, 57), hook=44, reach=1),
                    swing((15, 75, 24, 88), hook=75, reach=1), swing((107, 75, 116, 88), hook=75, reach=1)],
    "pavilion_tent": [flutter((70, 24, 80, 33), pole=69)],
    "warrior_guild": [flutter((51, 99, 73, 110), pole=50), flutter((171, 88, 190, 98), pole=170)],
}


# How close (pixels across) the building must stand beside a piece for it to be behind its edge.
BACKED = 3


def load(art_id):
    return np.asarray(Image.open(SPRITES / f"{art_id}.png").convert("RGBA")).astype(np.int32)


def mask_of(px, piece):
    x0, y0, x1, y1 = piece["box"]
    m = np.zeros(px.shape[:2], bool)
    m[y0:y1 + 1, x0:x1 + 1] = px[y0:y1 + 1, x0:x1 + 1, 3] > 0
    if piece.get("hues"):
        from scipy import ndimage
        rgb = px[..., :3].astype(float) / 255
        top, low = rgb.max(-1), rgb.min(-1)
        span = np.maximum(top - low, 1e-6)
        sat = np.where(top > 0, (top - low) / np.maximum(top, 1e-6), 0)
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        hue = np.where(top == r, ((g - b) / span) % 6, np.where(top == g, (b - r) / span + 2, (r - g) / span + 4)) * 60
        lo, hi = piece["hues"]
        inside = (hue >= lo) & (hue <= hi) if lo <= hi else (hue >= lo) | (hue <= hi)
        own = inside & (sat >= piece.get("sat", 0.0)) & (top - low > 0.02)
        m &= ndimage.binary_dilation(own & m)
    if piece["kind"] == "swing":
        m[:piece["hook"]] = False
    else:
        m[:, :piece["pole"] + 1] = False
    return m


def push(seconds, period):
    import wind_art
    return wind_art.push(seconds, period)


def floor_half(v):
    return int(math.floor(v + 0.5))


def rig(art_id):
    """The building's rig, as wind_art.py writes a tree's: clumps (runs of y, x, length), each frame's moves,
    and which clumps leave clear pixels behind them (`clear`)."""
    import wind_art
    px = load(art_id)
    h, w = px.shape[:2]
    labels = np.zeros((h, w), np.int32)
    clumps = []          # (piece, the row or column it is)
    backed_by = {}      # clump number: whether the building stands behind it
    moving = np.zeros((h, w), bool)
    for piece in PIECES[art_id]:
        moving |= mask_of(px, piece)
    # Where it hangs right by the building (a sign against its wall), the building is behind its edge:
    # what it leaves as it swings there is its shade, not a hole through the wall.
    near = np.zeros((h, w), bool)
    still = (px[..., 3] > 0) & ~moving
    for d in range(1, BACKED + 1):
        near[:, d:] |= still[:, :-d]
        near[:, :-d] |= still[:, d:]
    for piece in PIECES[art_id]:
        m = mask_of(px, piece) & (labels == 0)
        backed = m & (near | piece["wall"])
        parts = [backed, m & ~backed]
        if piece["kind"] == "swing":
            lines = [(y, (slice(y, y + 1), slice(None))) for y in sorted(set(np.nonzero(m)[0]))]
        else:
            lines = [(x, (slice(None), slice(x, x + 1))) for x in sorted(set(np.nonzero(m)[1]))]
        for at, cut in lines:
            for b, part in zip((True, False), parts):
                sel = np.zeros((h, w), bool)
                sel[cut] = part[cut]
                if sel.any():
                    labels[sel] = len(clumps) + 1
                    backed_by[len(clumps)] = b
                    clumps.append((piece, int(at)))
    frames = []
    for f in range(wind_art.LOOP + wind_art.GUST):
        row = []
        g = f - wind_art.LOOP
        for piece, at in clumps:
            dx = dy = 0
            if g >= 0:
                if piece["kind"] == "swing":
                    x0, y0, x1, y1 = piece["box"]
                    bottom = max(y for (p, y) in clumps if p is piece)
                    depth = (at - piece["hook"] + 1) / (bottom - piece["hook"] + 1)
                    dx = floor_half(piece["reach"] * depth * push(g / wind_art.FPS, piece["period"]))
                else:
                    tip = max(x for (p, x) in clumps if p is piece)
                    out = (at - piece["pole"]) / max(tip - piece["pole"], 1)
                    rise = math.sin(math.pi * g / wind_art.GUST) ** 2
                    dy = floor_half(piece["reach"] * 1.4 * out * rise * math.sin(2 * math.pi * (g / 6 - out)))
            row += [dx, dy]
        frames.append(row)
    clear = [k for k in range(len(clumps)) if not backed_by[k]]
    out = {
        "size": [w, h],
        "clumps": [wind_art.runs(labels, k) for k in range(1, len(clumps) + 1)],
        "frames": frames,
    }
    if clear:
        out["clear"] = clear
    return out


def rigs():
    return {art_id: rig(art_id) for art_id in sorted(PIECES)}


# Previews ------------------------------------------------------------------------------------------------------

def sheet(path, ids, zoom=4):
    tiles = []
    for art_id in ids:
        px = load(art_id).astype(np.uint8)
        im = Image.fromarray(px)
        marked = px.copy()
        for piece in PIECES[art_id]:
            m = mask_of(load(art_id), piece)
            marked[m] = (marked[m] * 0.4 + np.array([255, 0, 160, 255]) * 0.6).astype(np.uint8)
            marked[m, 3] = 255
        both = Image.new("RGBA", (px.shape[1] * 2, px.shape[0]), (150, 160, 150, 255))
        both.alpha_composite(im, (0, 0))
        both.alpha_composite(Image.fromarray(marked), (px.shape[1], 0))
        tiles.append(both.resize((both.width * zoom, both.height * zoom), Image.NEAREST))
    W = max(t.width for t in tiles)
    out = Image.new("RGBA", (W, sum(t.height for t in tiles)), (150, 160, 150, 255))
    y = 0
    for t in tiles:
        out.alpha_composite(t, (0, y))
        y += t.height
    out.save(path)
    print(path)


def gif(path, ids, zoom=4):
    import wind_art
    rows = []
    for art_id in ids:
        px = load(art_id)
        r = rig(art_id)
        labels = wind_art.unpack(r)
        clear = set(r.get("clear", []))
        frames = []
        for row in r["frames"][wind_art.LOOP:]:
            out = wind_art.frame(px, labels, row, clear)
            frames.append(out)
        rows.append(frames)
    pics = []
    for f in range(wind_art.GUST):
        tiles = [Image.fromarray(rows[i][f]) for i in range(len(ids))]
        W = sum(t.width for t in tiles)
        H = max(t.height for t in tiles)
        im = Image.new("RGBA", (W, H), (150, 160, 150, 255))
        x = 0
        for t in tiles:
            im.alpha_composite(t, (x, H - t.height))
            x += t.width
        pics.append(im.resize((W * zoom, H * zoom), Image.NEAREST).convert("RGB"))
    pics[0].save(path, save_all=True, append_images=pics[1:], duration=1000 // wind_art.FPS, loop=0)
    print(path)


def main(argv):
    ids = [a for a in argv if not a.startswith("--") and a in PIECES] or sorted(PIECES)
    if "--sheet" in argv:
        sheet(argv[argv.index("--sheet") + 1], ids)
    elif "--gif" in argv:
        gif(argv[argv.index("--gif") + 1], ids)
    else:
        print(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
