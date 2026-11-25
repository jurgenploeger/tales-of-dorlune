#!/usr/bin/env python3
"""A mountain as a stack of plateaus, previewed before it goes in the game (the user, 2026-11-25: "I don't like
the tall mountains we have now, the plateaus we added are really good. Maybe for a mountain we just stack a lot
of plateaus, so you have to walk zig zag to go up?").

Drawn with `tools/cliff_preview.py`'s terraces (the look the user picked for the terraced hills): the mountain is
`LEVELS` plateaus one on another, each smaller than the one under it and set a little back, every one ending in a
sheer face of rock toward you. The way up is a stair cut along each face, rising across it to the plateau above,
the first on the left, the next on the right and so on, so you walk up in a zig-zag. A stair is drawn as the
terraced faces' rock, lit from the top left, a tread and a riser a step (`stairs`).

    python3 tools/mountain_preview.py out.png [map]      # four plateaus | six

Needs pillow + numpy.
"""
import math
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import cliff_preview as cp  # noqa: E402

LIFT = 40            # screen pixels each plateau stands over the one under it (a terraced hill's step)
STAIR_STEPS = 7      # steps in each stair


def mountain(levels, n):
    """The plateau (0 the ground, 1 to `levels`) at each ground point of an `n`-cell patch, and how the rims
    run: each an oval, wider across the screen, set back from the one under it."""
    cx, cy = n * 0.55, n * 0.55                          # the summit, set back up the screen
    outer = n * 0.5
    ring = outer / levels

    def radius(gx, gy):
        gx, gy = np.asarray(gx, float), np.asarray(gy, float)
        a = gx - gy
        b = (gx + gy) - (cx + cy)
        wobble = 0.5 * np.sin(gx * 0.9 + 0.3) + 0.4 * np.sin(gy * 1.2 + 1.1) + 0.25 * np.sin((gx - gy) * 1.6)
        return np.sqrt((a / 1.25) ** 2 + (np.where(b < 0, b * 0.9, b * 1.6)) ** 2) + wobble * 0.6

    def field(gx, gy):
        return np.clip(np.floor((outer - radius(gx, gy)) / ring) + 1, 0, levels).astype(int)
    return field, (cx, cy, outer, ring)


def stairs(img, levels, shape):
    """Each plateau's stair: stone steps cut along the face under its rim, rising across it from its foot on
    one side to the rim on the other, the first left to right, the next right to left, and so on: a zig-zag.
    Each step a tread lit from the top left over a riser in shade, its outer side a dark edge."""
    cx, cy, outer, ring = shape
    out = img.copy()
    d = ImageDraw.Draw(out)
    stone, lit, riser, edge = (150, 140, 124), (182, 172, 152), (96, 88, 78), (46, 40, 38)
    for k in range(levels):
        rim = outer - k * ring                           # plateau k+1's rim, up from plateau k (0 the ground)
        side = 1 if k % 2 == 0 else -1
        # Across the face from -0.75 to +0.15 of the rim's half width (or the mirror of it).
        span = [side * (-0.75 + 0.9 * i / STAIR_STEPS) * rim * 1.25 for i in range(STAIR_STEPS + 1)]
        steps = []
        for i in range(STAIR_STEPS):
            a = (span[i] + span[i + 1]) / 2
            # The rim's front at this point across: walk in from the front until the plateau begins.
            b = -outer * 1.6
            while b < 0 and cp.level_field((a + b + cx + cy) / 2, (b - a + cx + cy) / 2) < k + 1:
                b += 0.05
            b -= 0.3                                      # the stair stands against the face, in front of it
            gx, gy = (a + b + cx + cy) / 2, (b - a + cx + cy) / 2
            z = k * LIFT + LIFT * (i + 1) / STAIR_STEPS
            steps.append((gx, gy, z, a))
        # Back to front, so each step's riser covers the one behind.
        for gx, gy, z, a in sorted(steps, key=lambda t: -(t[0] + t[1])):
            half = abs(span[1] - span[0]) * 0.5 / 2
            corners = [(gx + half, gy - half), (gx - half, gy + half)]
            depth = 0.3
            top = [cp.screen_of(x, y, z) for x, y in corners] + [cp.screen_of(x + depth, y + depth, z) for x, y in corners[::-1]]
            # Its riser down to the ground in front (a step stands on the ones under it, the first on the ground).
            foot = [cp.screen_of(x, y, k * LIFT) for x, y in corners]
            d.polygon([top[0], top[1], foot[1], foot[0]], fill=riser, outline=edge)
            d.polygon(top, fill=stone, outline=edge)
            # Its front edge catches the light.
            d.line([top[0], top[1]], fill=lit, width=1)
    return out


def render(mid, levels, n=26, w=640, h=520):
    cp.N, cp.W, cp.H = n, w, h
    cp.LIFTS = [i * LIFT for i in range(levels + 1)]
    field, shape = mountain(levels, n)
    cp.level_field = field
    cp.water_field = lambda gx, gy: np.zeros(np.shape(gx), bool)
    return stairs(cp.render(mid, True), levels, shape)


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    mid = argv[1] if len(argv) > 1 else "sunny_meadow"
    shots = [render(mid, 4), render(mid, 6)]
    sheet = Image.new("RGB", (sum(s.width for s in shots) + 8, shots[0].height), (20, 20, 24))
    x = 0
    for s, label in zip(shots, ["four plateaus", "six plateaus"]):
        d = ImageDraw.Draw(s)
        d.rectangle([4, 4, 12 + 6 * len(label), 18], fill=(20, 24, 40))
        d.text((8, 6), label, fill=(255, 255, 255))
        sheet.paste(s, (x, 0))
        x += s.width + 8
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(argv[0])
    print(argv[0])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
