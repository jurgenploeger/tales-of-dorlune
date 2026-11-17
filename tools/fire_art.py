#!/usr/bin/env python3
"""Fire that moves (the user, 2026-11-17, of Goldburg's forges: "These buildings with fire should have the
fire move"), from the sprite's own pixels, as the trees' wind is (`tools/wind_art.py`): Retro Diffusion's
art stays as drawn, only its flame's pixels move.

For each sprite in `FIRES`, the flame (its bright, warm pixels inside `box`, and the near-white core) and
the glow round it (the deep reds inside `glow`) are cut from the PNG, and four frames are made of that
corner of it, the rest clear: `fire_<id>_0.png` to `_3` (the first as drawn). In each, every column of the
flame reaches a pixel higher or lower than drawn (its tongues licking up and dropping back, neighbouring
columns moving together), a few of its pixels a step brighter or darker on its own ramp, and the glow a
little brighter or dimmer. The game lays them over the building and plays them (`LandStage.addFire`), so
the frames are cut at the sprite's own size and graded with it.

    python3 tools/fire_art.py              # writes the frames into art/sprites/
    python3 tools/fire_art.py --sheet out.png
    python3 tools/fire_art.py --gif out.gif

Needs pillow + numpy.
"""
import colorsys
import pathlib
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPR = ROOT / "art" / "sprites"

# Each sprite with a fire: the flame's box and the glow's box round it (x0, y0, x1, y1, inclusive), in
# the PNG's pixels.
FIRES = {
    "blacksmith": {"box": (39, 51, 58, 64), "glow": (34, 45, 64, 64)},
}
FRAMES = 4
# How far each frame's tongues reach past the drawing (pixels, up is +), and how bright its glow is.
REACH = [None, (-1, 1), (0, 2), (-1, 1)]
GLOW = [1.0, 1.08, 0.95, 1.04]


def hsv(rgb):
    return colorsys.rgb_to_hsv(*(rgb / 255.0))


def is_flame(px):
    if px[3] < 128:
        return False
    h, s, v = hsv(px[:3].astype(float))
    warm = h < 0.17 or h > 0.95
    return (warm and s > 0.45 and v > 0.72) or (s <= 0.45 and v > 0.85)


def is_glow(px):
    if px[3] < 128:
        return False
    h, s, v = hsv(px[:3].astype(float))
    return (h < 0.1 or h > 0.95) and s > 0.45 and 0.3 < v <= 0.72


def frames(sprite, spec):
    src = np.asarray(Image.open(SPR / f"{sprite}.png").convert("RGBA")).astype(int)
    x0, y0, x1, y1 = spec["box"]
    gx0, gy0, gx1, gy1 = spec["glow"]
    flame = np.zeros(src.shape[:2], bool)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            flame[y, x] = is_flame(src[y, x])
    glow = np.zeros(src.shape[:2], bool)
    for y in range(gy0, gy1 + 1):
        for x in range(gx0, gx1 + 1):
            glow[y, x] = not flame[y, x] and is_glow(src[y, x])
    # The flame's ramp: its colours from darkest to brightest.
    colours = sorted({tuple(src[y, x, :3]) for y, x in zip(*np.nonzero(flame))}, key=lambda c: sum(c))
    rank = {c: i for i, c in enumerate(colours)}
    rng = np.random.default_rng(7)
    out = []
    for f in range(FRAMES):
        img = np.zeros_like(src)
        # The corner it covers: the glow's box, as drawn.
        img[gy0:gy1 + 1, gx0:gx1 + 1] = src[gy0:gy1 + 1, gx0:gx1 + 1]
        if REACH[f] is not None:
            low, high = REACH[f]
            # Each column's reach, neighbours moving together.
            raw = rng.integers(low, high + 1, x1 - x0 + 3)
            reach = np.round(np.convolve(raw, np.ones(3) / 3, mode="valid")).astype(int)
            for i, x in enumerate(range(x0, x1 + 1)):
                rows = [y for y in range(y0, y1 + 1) if flame[y, x]]
                if not rows:
                    continue
                k = reach[i]
                for y in range(y0 - 2, max(rows) + 1):   # never down past its foot, into the hearth
                    from_y = y + k
                    inside = y0 <= from_y <= y1 and flame[from_y, x]
                    if inside:
                        img[y, x] = src[from_y, x]
                    elif flame[y, x]:
                        # Where the flame dropped back: what's behind it, the nearest unlit pixel above.
                        above = next((yy for yy in range(y - 1, gy0 - 1, -1) if not flame[yy, x]), None)
                        img[y, x] = src[above, x] if above is not None else src[y, x]
            # A few pixels a step brighter or darker on its ramp.
            for y, x in zip(*np.nonzero(flame)):
                c = tuple(img[y, x, :3])
                if c in rank and rng.random() < 0.18:
                    j = int(np.clip(rank[c] + rng.choice([-1, 1]), 0, len(colours) - 1))
                    img[y, x, :3] = colours[j]
        # The glow round it, brighter or dimmer.
        for y, x in zip(*np.nonzero(glow)):
            if not is_flame(img[y, x]):
                img[y, x, :3] = np.clip(src[y, x, :3] * GLOW[f], 0, 255)
        out.append(Image.fromarray(img.astype(np.uint8), "RGBA"))
    return out


def main(argv):
    made = {sprite: frames(sprite, spec) for sprite, spec in FIRES.items()}
    if argv[:1] == ["--sheet"] or argv[:1] == ["--gif"]:
        for sprite, fs in made.items():
            base = Image.open(SPR / f"{sprite}.png").convert("RGBA")
            shots = []
            for frame in fs:
                shot = Image.new("RGBA", base.size, (60, 52, 40, 255))
                shot.alpha_composite(base)
                shot.alpha_composite(frame)
                shots.append(shot.resize((base.width * 4, base.height * 4), Image.NEAREST))
            if argv[0] == "--gif":
                shots[0].save(argv[1], save_all=True, append_images=shots[1:], duration=110, loop=0)
            else:
                sheet = Image.new("RGBA", (sum(s.width for s in shots), shots[0].height))
                for i, s in enumerate(shots):
                    sheet.paste(s, (i * s.width, 0))
                sheet.save(argv[1])
        print(argv[1])
        return 0
    for sprite, fs in made.items():
        for i, frame in enumerate(fs):
            frame.save(SPR / f"fire_{sprite}_{i}.png")
    print("wrote", sum(len(f) for f in made.values()), "frames")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
