#!/usr/bin/env python3
"""Night by colour, previewed before it goes in the game (the user, 2026-11-17, pointing to SpriteCook's
"pixel-art day-night cycle with a color lookup table" article).

The game's night now multiplies everything by one colour (`Sky.light`: 0.42, 0.47, 0.78 at its deepest), so
every colour slides toward the same murky blue. The article gives each colour its own night colour instead.
Its exact method (each sprite's pixels as indices into a row of at most 256 palette colours) doesn't fit this
game: Retro Diffusion's art and each land's palette grading make thousands of colours. Its idea does, as a
colour cube: every colour's night colour by the article's rule, in OKLab (lightness down, chroma kept more
than a multiply keeps it, hue pushed toward blue), with warm, bright colours kept warm and bright where they
glow (lit windows, lamps, fire). This draws a screenshot of the game three ways: by day, as the game's night
is now, and with the cube.

    python3 tools/night_preview.py out.png shot.png [shot.png ...]

Needs pillow + numpy.
"""
import sys

import numpy as np
from PIL import Image, ImageDraw


def to_linear(c):
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055) * 255


def oklab(rgb):
    l = to_linear(rgb)
    m1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929], [0.2119034982, 0.6806995451, 0.1073969566],
                   [0.0883024619, 0.2817188376, 0.6299787005]])
    lms = np.cbrt(l @ m1.T)
    m2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468], [1.9779984951, -2.4285922050, 0.4505937099],
                   [0.0259040371, 0.7827717662, -0.8086757660]])
    return lms @ m2.T


def from_oklab(lab):
    m2i = np.array([[1, 0.3963377774, 0.2158037573], [1, -0.1055613458, -0.0638541728], [1, -0.0894841775, -1.2914855480]])
    lms = (lab @ m2i.T) ** 3
    m1i = np.array([[4.0767416621, -3.3077115913, 0.2309699292], [-1.2684380046, 2.6097574011, -0.3413193965],
                    [-0.0041960863, -0.7034186147, 1.7076147010]])
    return to_srgb(lms @ m1i.T)


def night(rgb, depth=1.0):
    """Each colour's colour at night, `depth` 0 (day) to 1 (deepest night)."""
    lab = oklab(rgb.astype(float))
    L, a, b = lab[..., 0], lab[..., 1], lab[..., 2]
    chroma = np.hypot(a, b)
    hue = np.arctan2(b, a)
    # What glows: warm (orange to yellow) and bright, and saturated (lit windows, lamp flames, fire), not
    # pale sand or grass.
    warm = np.cos(hue - 1.1)
    glow = np.clip((L - 0.74) / 0.06, 0, 1) * np.clip((warm - 0.6) / 0.2, 0, 1) * np.clip((chroma - 0.13) / 0.03, 0, 1)
    # Everything else: darker, a little less saturated, its hue turned toward blue, and blue added.
    L2 = L * (1 - 0.36 * depth) - 0.03 * depth
    c2 = chroma * (1 - 0.6 * depth)
    blue = -1.45                                             # a night blue's hue in OKLab, a little toward violet
    turn = np.angle(np.exp(1j * (blue - hue)))
    h2 = hue + turn * 0.0 * depth
    a2, b2 = c2 * np.cos(h2), c2 * np.sin(h2)
    a2 += 0.0 * depth
    b2 += -0.045 * depth
    # A glowing colour keeps its light, a touch warmer.
    L2 = L2 * (1 - glow) + np.minimum(1, L * 1.04) * glow
    a2 = a2 * (1 - glow) + (a + 0.01) * glow
    b2 = b2 * (1 - glow) + (b + 0.02) * glow
    return from_oklab(np.stack([L2, a2, b2], -1))


def main(argv):
    out, shots = argv[0], argv[1:]
    rows = []
    for path in shots:
        im = Image.open(path).convert("RGB")
        w, h = im.size
        # The middle of the screen, clear of the HUD.
        im = im.crop((0, int(h * 0.2), w, int(h * 0.72)))
        im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
        day = np.asarray(im).astype(float)
        now = day * np.array([0.42, 0.47, 0.78])
        cube = night(day)
        rows.append([day, now, cube])
    w, h = rows[0][0].shape[1], rows[0][0].shape[0]
    board = Image.new("RGB", (w * 3 + 40, (h + 30) * len(rows) + 10), (24, 30, 46))
    d = ImageDraw.Draw(board)
    for r, row in enumerate(rows):
        for c, (pic, title) in enumerate(zip(row, ["By day", "Night as now (one colour multiplied)", "Night by colour (proposed)"])):
            x, y = 10 + c * (w + 10), 10 + r * (h + 30)
            board.paste(Image.fromarray(np.clip(pic, 0, 255).astype(np.uint8)), (x, y))
            d.text((x + 4, y + h + 6), title, fill=(255, 255, 255))
    board.save(out)
    print(out)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
