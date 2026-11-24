#!/usr/bin/env python3
"""Snap a ChatGPT walk painting (8 frames in a 4x2 grid) to a 64x64 row in the approved view's palette.

  hero_snap_walk.py <out> [pixel size, 6.9] [painting.png] [--centre] [--grid COLSxROWS]

--grid: the painting's frames as columns x rows (default 4x2, a walk's 8; an attack's 6 are 3x2).

--centre: each frame moved so its head (its top 18 rows) is centred on column 32, for a painting whose figure
slides across its cell (walk up-right, 2026-11-24): played in place, that jittered.

ChatGPT's own 1x redraws and loses the motion (docs/ai-sprite-test/heroes/HANDOVER.md); its painting is the design.
Each frame keeps its place in its painted cell; its planted foot (its lowest pixel) lands on row 60."""
import sys
CENTRE = "--centre" in sys.argv
sys.argv = [a for a in sys.argv if a != "--centre"]
GC, GR = 4, 2
if "--grid" in sys.argv:
    i = sys.argv.index("--grid"); GC, GR = map(int, sys.argv[i + 1].split("x")); del sys.argv[i:i + 2]
N = GC * GR
import numpy as np
from PIL import Image
P = float(sys.argv[2]) if len(sys.argv) > 2 else 6.9
a = np.array(Image.open(sys.argv[3] if len(sys.argv) > 3 else "painting.png").convert("RGBA")).astype(float)
H, W = a.shape[:2]
dr = np.array(Image.open("/home/user/tales-of-dorlune/docs/ai-sprite-test/heroes/hero64_human_male_down-right.png").convert("RGBA")).astype(int)
pal = np.array(sorted({tuple(c) for c in dr[dr[..., 3] > 0][:, :3]}))

def var(c, ox, oy):
    rgb, m = c[..., :3], c[..., 3] > 200
    t = n = 0
    for y in np.arange(oy, c.shape[0] - P, P):
        for x in np.arange(ox, c.shape[1] - P, P):
            y0, x0 = int(round(y)) + 1, int(round(x)) + 1
            y1, x1 = int(round(y + P)) - 1, int(round(x + P)) - 1
            if y1 > y0 and x1 > x0 and m[y0:y1, x0:x1].all():
                t += rgb[y0:y1, x0:x1].reshape(-1, 3).var(0).sum(); n += 1
    return t / max(n, 1)

def snap(c):
    """Each grid cell's middle colour; solid where most of the cell is."""
    ox, oy = min(((var(c, ox, oy), ox, oy) for ox in np.arange(0, P, 1) for oy in np.arange(0, P, 1)))[1:]
    rows = int((c.shape[0] - oy) // P); cols = int((c.shape[1] - ox) // P)
    out = np.zeros((rows, cols, 4), int)
    for j in range(rows):
        for i in range(cols):
            y0, x0 = int(round(oy + j * P)), int(round(ox + i * P))
            y1, x1 = int(round(oy + (j + 1) * P)), int(round(ox + (i + 1) * P))
            blk = c[y0:y1, x0:x1]
            if (blk[..., 3] > 128).mean() < 0.5:
                continue
            core = blk[1:-1, 1:-1].reshape(-1, 4)
            core = core[core[:, 3] > 200]
            if not len(core):
                core = blk.reshape(-1, 4)[blk.reshape(-1, 4)[:, 3] > 128]
            # each painted pixel to its nearest palette colour, then the cell takes the most common one, an
            # outline colour only where most of the cell is outline: a median let a cell straddling the
            # painting's soft outline go dark, and the outline came out two pixels thick (the user, 2026-11-24)
            idx = np.argmin(((core[:, None, :3] - pal[None]) ** 2).sum(2), 1)
            counts = np.bincount(idx, minlength=len(pal))
            darkpal = pal.max(1) < 0.35 * 255
            if counts[darkpal].sum() * 2 <= counts.sum():
                counts[darkpal] = 0
            out[j, i, :3] = pal[np.argmax(counts)]
            out[j, i, 3] = 255
    return out, oy

cells = []
for k in range(N):
    r, cc = divmod(k, GC)
    c = a[r * H // GR:(r + 1) * H // GR, cc * W // GC:(cc + 1) * W // GC]
    cells.append(snap(c))
# one baseline per painted row: the lowest solid row among that row's 4 frames, at canvas row 60;
# horizontally each frame keeps its place in its painted cell (the cell's middle at column 32)
row = np.zeros((64, 64 * N, 4), np.uint8)
for r in range(GR):
    group = cells[r * GC:(r + 1) * GC]
    base = max(np.nonzero(g[..., 3].any(1))[0].max() for g, _ in group)
    for i, (g, _) in enumerate(group):
        k = r * GC + i
        dy = 60 - np.nonzero(g[..., 3].any(1))[0].max()     # a planted foot is always on the ground
        dx = 32 - g.shape[1] // 2
        if CENTRE:
            ys = np.nonzero(g[..., 3].any(1))[0]
            dx = int(round(32 - np.nonzero(g[ys.min():ys.min() + 18, :, 3].any(0))[0].mean()))
        for y, x in zip(*np.nonzero(g[..., 3])):
            yy, xx = y + dy, x + dx
            if 0 <= yy < 64 and 0 <= xx < 64:
                row[yy, k * 64 + xx] = g[y, x]
out = sys.argv[1]
Image.fromarray(row).save(out + ".png")
Image.fromarray(row).resize((64 * N * 8, 512), Image.NEAREST).save(out + "_8x.png")
for k in range(N):
    ys, xs = np.nonzero(row[:, k * 64:(k + 1) * 64, 3])
    print(k + 1, "rows", ys.min(), ys.max(), "h", ys.max() - ys.min() + 1, "cols", xs.min(), xs.max())
