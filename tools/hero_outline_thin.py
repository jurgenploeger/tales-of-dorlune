#!/usr/bin/env python3
"""hero_outline_thin.py <in.png> <out.png>: thin a snapped row's outline to one pixel, as the master's: a dark pixel just inside the outer outline takes the
colour of the light pixel straight across from the outline (keeping the shading's side); thin parts (an ear, a
finger) where the dark pixel has the outside on both sides are left. Grey specks on the outer edge outside the
shorts become outline."""
import sys
import numpy as np
from PIL import Image
a = np.array(Image.open(sys.argv[1]).convert("RGBA")).astype(int)
H, W = a.shape[:2]
solid = a[..., 3] > 0
dark = solid & (a[..., :3].max(-1) < 0.35 * 255)
grey = solid & ~dark & (np.abs(a[..., 0] - a[..., 2]) < 20)

# the outline colour most used
cols, cnt = np.unique(a[dark][:, :3], axis=0, return_counts=True)
ink = np.r_[cols[np.argmax(cnt)], 255]
D = ((-1, 0), (1, 0), (0, -1), (0, 1))
inside = lambda y, x: 0 <= y < H and 0 <= x < W
outer = np.zeros_like(solid)
for y, x in zip(*np.nonzero(solid)):
    if any(not inside(y + dy, x + dx) or not solid[y + dy, x + dx] for dy, dx in D):
        outer[y, x] = True
out = a.copy()
# grey on the outer edge that isn't part of the shorts' own run: outline
for y, x in zip(*np.nonzero(grey & outer)):
    run = sum(grey[y, x + k] for k in range(-3, 4) if 0 <= x + k < W)
    if run < 3:
        out[y, x] = ink
n = 0
for y, x in zip(*np.nonzero(dark & ~outer)):
    for dy, dx in D:
        oy, ox = y - dy, x - dx                       # the outline on one side...
        iy, ix = y + dy, x + dx                       # ...and across from it
        if inside(oy, ox) and outer[oy, ox] and dark[oy, ox] and inside(iy, ix) and solid[iy, ix] and not dark[iy, ix]:
            far_y, far_x = y + 2 * dy, x + 2 * dx
            if inside(far_y, far_x) and not solid[far_y, far_x]:
                continue                               # a part two pixels thick: keep its outline
            out[y, x] = a[iy, ix]; n += 1
            break
Image.fromarray(out.astype(np.uint8)).save(sys.argv[2])
Image.fromarray(out.astype(np.uint8)).resize((W * 8, H * 8), Image.NEAREST).save(sys.argv[2][:-4] + "_8x.png")
print("thinned", n)
