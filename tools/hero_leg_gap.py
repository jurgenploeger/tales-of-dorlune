#!/usr/bin/env python3
"""Open the gap between the legs where snapping filled it with outline: a column of three dark pixels between
two legs' skin becomes #.# (the standing views' own gap), the feet keeping an outline on the gap's side.

  hero_leg_gap.py <in.png> <out.png>      (any row of 64 x 64 frames; writes <out>_8x.png too)

Back views (attack up, 2026-11-24): ChatGPT paints the gap a pixel or so wide and the snap closed it."""
import sys, numpy as np
from PIL import Image
r = np.array(Image.open(sys.argv[1]).convert('RGBA'))
dark = lambda p: p[3] > 0 and p[:3].max() < 100
skin = lambda p: p[3] > 0 and p[:3].max() >= 100
n = 0
for k in range(r.shape[1] // 64):
    f = r[:, k*64:(k+1)*64]
    # the shorts' bottom: lowest row with a grey that's not skin is hard to tell; take legs as rows 50..60
    cols = {}
    for y in range(49, 60):
        for x in range(1, 62):
            if dark(f[y, x-1]) and dark(f[y, x]) and dark(f[y, x+1]) and skin(f[y, x-2]) and skin(f[y, x+2]):
                cols.setdefault(x, []).append(y)
    for x, ys in cols.items():
        if len(ys) < 4: continue
        for y in ys: f[y, x] = 0; n += 1
        y = max(ys) + 1
        while y < 61 and dark(f[y, x]) and (y == 60 or f[y+1, x, 3] == 0 or dark(f[y+1, x])):
            if f[min(y+1,63), x, 3] == 0 or y == 60:
                c = f[y, x].copy(); f[y, x] = 0; n += 1
                for xx in (x - 1, x + 1):      # the feet keep an outline on the gap's side
                    if skin(f[y, xx]): f[y, xx] = c
                break
            y += 1
Image.fromarray(r).save(sys.argv[2]); Image.fromarray(r).resize((r.shape[1]*8, 512), Image.NEAREST).save(sys.argv[2][:-4] + '_8x.png')
print('opened', n)
