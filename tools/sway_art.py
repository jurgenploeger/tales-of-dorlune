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


def swing(box, hook, reach=2, wall=False, period=1.4):
    return dict(kind="swing", box=box, hook=hook, reach=reach, wall=wall, period=period)


def flutter(box, pole, reach=1, wall=False):
    return dict(kind="flutter", box=box, pole=pole, reach=reach, wall=wall)


# Each building's moving pieces: `box` is (x0, y0, x1, y1), inclusive, in its PNG's pixels; every opaque pixel
# in it (below `hook`) moves.
PIECES = {
    "weapon_shop": [swing((75, 58, 87, 72), hook=58)],
    "armour_shop": [swing((104, 77, 117, 90), hook=76)],
    "tailor_shop": [swing((70, 53, 83, 66), hook=53)],
    "book_shop": [swing((104, 79, 117, 93), hook=78)],
    "flower_shop": [swing((76, 63, 86, 74), hook=63)],
    "gem_workshop": [swing((76, 63, 87, 77), hook=63)],
    "tea_house": [swing((78, 57, 86, 68), hook=57), swing((10, 59, 22, 65), hook=59, reach=1)],
    "apothecary": [swing((19, 82, 33, 99), hook=81)],
    "emerald_shop": [swing((76, 57, 85, 68), hook=57)],
    # ChatGPT's 1:1 redraws (2026-11-27, docs/ai-sprite-test/buildings-1to1): these, the shops' and the guild's.
    "swamp_stilt_hut": [swing((97, 67, 111, 81), hook=67, reach=1)],
    "glass_lantern_shop": [swing((24, 47, 30, 55), hook=47, reach=1, wall=True),
                           swing((32, 48, 38, 54), hook=48, reach=1, wall=True),
                           swing((54, 49, 59, 54), hook=49, reach=1, wall=True),
                           swing((62, 50, 67, 54), hook=50, reach=1, wall=True)],
    "firefly_house": [swing((17, 53, 24, 66), hook=53, reach=1, wall=True),
                      swing((33, 53, 40, 66), hook=53, reach=1, wall=True),
                      swing((56, 53, 63, 66), hook=53, reach=1, wall=True),
                      swing((75, 53, 83, 66), hook=53, reach=1)],
    "moon_pagoda": [swing((26, 44, 35, 57), hook=44, reach=1), swing((97, 44, 106, 57), hook=44, reach=1),
                    swing((15, 75, 24, 88), hook=75, reach=1), swing((107, 75, 116, 88), hook=75, reach=1)],
    "pavilion_tent": [flutter((50, 18, 55, 23), pole=49)],
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
