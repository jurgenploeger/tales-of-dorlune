#!/usr/bin/env python3
"""Retro Diffusion's grain on ChatGPT's art (the user, 2026-11-22: "When I see our new buildings created by chatgpt
next to the retro diffusion, it still looks different and not the same quality").

ChatGPT paints in broad, evenly filled patches; RD speckles every surface with the shades next to it on its ramp.
Measured on the buildings (`pixel_style.py check --kind building`): RD's patches of one colour are about 3 pixels
(`cluster_size` 3.0) with 17% single-pixel specks (`orphans`), ChatGPT's 5.3 and 7%. `grain` scatters, through
every patch of one colour 6 pixels or bigger, pixels of that colour's own darker and lighter neighbour (the nearest
colour of its hue family already in the sprite, a step either way), a little more of the darker toward the bottom
right; at `AMOUNT` it lands on RD's numbers (patches about 3.1, specks about 17%). The outline, warm bright pixels
(lit window panes, flames: `tools/window_art.py` cuts those) and small patches are left as drawn, so art that already
has grain barely changes. Placed by a hash of where each pixel is, so a rerun gives the same picture.

    python3 tools/grain.py in.png out.png [amount]

Used by `building_art.py` (ChatGPT's buildings) and `gate_art.py` (its gates, the lintel's grain repeating every
12 pixels so a gate still widens cleanly: `period`).
"""
import colorsys
import sys

import numpy as np
from PIL import Image

AMOUNT = 0.15
MIN_PATCH = 6


def _hsv(c):
    return colorsys.rgb_to_hsv(*(np.asarray(c[:3], float) / 255))


def _neighbours(colours):
    """Each colour's nearest darker and lighter colour of its hue family in the sprite (or None)."""
    hsv = [_hsv(c) for c in colours]
    dark, light = {}, {}
    for i, (h, s, v) in enumerate(hsv):
        best_d = best_l = None
        for j, (h2, s2, v2) in enumerate(hsv):
            if i == j:
                continue
            dh = min(abs(h - h2), 1 - abs(h - h2)) * 360
            if dh > 28 or abs(s - s2) > 0.3 or (s < 0.12 and s2 >= 0.2):
                continue
            if v2 < v and v - v2 < 0.28 and (best_d is None or v - v2 < best_d[0]):
                best_d = (v - v2, j)
            if v2 > v and v2 - v < 0.28 and (best_l is None or v2 - v < best_l[0]):
                best_l = (v2 - v, j)
        dark[i] = best_d[1] if best_d else None
        light[i] = best_l[1] if best_l else None
    return dark, light


def _hash(x, y):
    h = (x * 73856093 ^ y * 19349663 ^ 83492791) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535


def grain(img, amount=AMOUNT, period=None):
    """`img` with RD's grain. `period`: (rows, every) where the grain repeats every so many pixels across, so a
    stretch of those rows can be tiled (a gate's lintel)."""
    from scipy import ndimage
    a = np.array(img.convert("RGBA"))
    height, width = a.shape[:2]
    solid = a[..., 3] > 0
    colours, inverse = np.unique(a[solid][:, :3], axis=0, return_inverse=True)
    index = np.full((height, width), -1)
    index[solid] = inverse.ravel()
    dark, light = _neighbours([tuple(c) for c in colours])
    edge = solid & ~ndimage.binary_erosion(solid, structure=np.ones((3, 3)))
    out = a.copy()
    for k in range(len(colours)):
        h, s, v = _hsv(colours[k])
        if h * 360 < 60 and s > 0.45 and v > 0.85:
            continue
        labels, count = ndimage.label(index == k)
        sizes = ndimage.sum(np.ones_like(labels), labels, range(1, count + 1))
        for label, size in enumerate(sizes, 1):
            if size < MIN_PATCH:
                continue
            for y, x in zip(*np.nonzero(labels == label)):
                if edge[y, x]:
                    continue
                hx = x
                if period and y in period[0]:
                    hx = x % period[1]
                r = _hash(int(hx), int(y))
                bias = (hx / width + y / height) / 2
                if r < amount * (0.5 + bias) and dark[k] is not None:
                    out[y, x, :3] = colours[dark[k]]
                elif r > 1 - amount * (1.2 - bias) * 0.6 and light[k] is not None:
                    out[y, x, :3] = colours[light[k]]
    return Image.fromarray(out, "RGBA")


if __name__ == "__main__":
    grain(Image.open(sys.argv[1]), float(sys.argv[3]) if len(sys.argv) > 3 else AMOUNT).save(sys.argv[2])
