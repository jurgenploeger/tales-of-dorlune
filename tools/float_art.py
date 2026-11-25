#!/usr/bin/env python3
"""What floats on a land's lakes, rivers and ponds (the user, 2026-11-25, after ZeFrost's pond: "Our lakes,
rivers and ponds should also have the floating petals, moving a bit up and down slowly so it looks like it's
floating on water, and it should have the white line underneath"), and that white line itself.

Floating things, drawn by hand pixel by pixel (too small for pixel_kit's finish, as the critters are), each on
a 32-pixel canvas like the lily pad's, in the middle of it:
  float_petals        three or four pink petals drifting apart
  float_petals_white  the same in cream
  float_blossom       one small five-petalled flower, a yellow eye
  float_leaf          a small round leaf, a notch cut in it
Each lit from the top left, outlined in a deep shade of its own colour.

And for everything that sits in the water (those, the lily pad and the shallows' rocks), `rim_<id>`: the pale
line where the water meets it, one pixel round the lower half of its outline, on a canvas the same size, so the
game lays it at the same spot and anchor (`LandStage.placeFloaters`, `addScenery`). The thing bobs a pixel over
it; the line stays on the water.

    python3 tools/float_art.py              # writes art/sprites/float_*.png and rim_*.png
    python3 tools/float_art.py --sheet out.png

Needs pillow + numpy.
"""
import pathlib
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPR = ROOT / "art" / "sprites"
SIZE = 32


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def canvas():
    return np.zeros((SIZE, SIZE, 4), np.uint8)


def blob(img, cx, cy, rx, ry, ramp):
    """A small lit oval: `ramp` dark to light (outline, shadow, base, light), lit from the top left."""
    dark, shadow, base, light = (hexrgb(c) for c in ramp)
    for y in range(SIZE):
        for x in range(SIZE):
            e = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if e > 1:
                continue
            lit = (x - cx) / rx + (y - cy) / ry
            colour = light if lit < -0.75 else shadow if lit > 0.55 else base
            img[y, x] = (*colour, 255)
    outline(img, dark, only=lambda y, x: True)


def outline(img, colour, only):
    """A one-pixel outline round what's drawn, in `colour`, where `only(y, x)`."""
    a = img[..., 3] > 0
    ring = np.zeros_like(a)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        ring |= np.roll(np.roll(a, dy, 0), dx, 1)
    ring &= ~a
    for y, x in zip(*np.nonzero(ring)):
        if only(y, x):
            img[y, x] = (*colour, 255)


def petals(ramp):
    img = canvas()
    for cx, cy, rx, ry in ((12.5, 15, 2.6, 1.7), (17, 13.5, 2.4, 1.6), (19.5, 17.5, 2.2, 1.5), (14.5, 19, 1.9, 1.3)):
        part = canvas()
        blob(part, cx, cy, rx, ry, ramp)
        img = np.where(part[..., 3:4] > 0, part, img)
    return img


def blossom():
    img = canvas()
    ramp = ("#b4426e", "#e57fa4", "#f6a8c4", "#ffd8e6")
    for k in range(5):
        t = k / 5 * 2 * np.pi - np.pi / 2
        part = canvas()
        blob(part, 16 + 2.6 * np.cos(t), 16 + 1.8 * np.sin(t), 2.1, 1.6, ramp)
        img = np.where(part[..., 3:4] > 0, part, img)
    for y, x, c in ((16, 16, "#f4c430"), (16, 15, "#f9dc6a"), (15, 16, "#f9dc6a")):
        img[y, x] = (*hexrgb(c), 255)
    return img


def leaf():
    img = canvas()
    blob(img, 16, 16, 4.6, 3.0, ("#2f5a24", "#4c8a34", "#65a843", "#8cc85a"))
    # A notch cut in toward its middle, as a lily pad's.
    for y, x in ((14, 19), (14, 20), (15, 19), (13, 20)):
        img[y, x] = 0
    img[16, 17] = (*hexrgb("#4c8a34"), 255)
    return img


FLOATS = {
    "float_petals": lambda: petals(("#b4426e", "#e57fa4", "#f6a8c4", "#ffd8e6")),
    "float_petals_white": lambda: petals(("#8e8270", "#d8cfbe", "#f2ecdc", "#fffbf0")),
    "float_blossom": blossom,
    "float_leaf": leaf,
}

# What else sits in the water and gets a line where it meets it.
RIMMED = ["lily_pad", "water_rock", "water_rock_2", "water_rock_3", "water_rock_4"]
RIM = (240, 250, 248)


def rim(img):
    """The water's pale line round the lower part of `img`'s outline: the pixels just outside it, below
    the top third of what's drawn, a little out past its sides."""
    a = img[..., 3] > 0
    if not a.any():
        return canvas()
    rows = np.nonzero(a.any(axis=1))[0]
    top, bottom = rows.min(), rows.max()
    cut = top + (bottom - top) * 0.45
    ring = np.zeros_like(a)
    for dy, dx in ((1, 0), (0, 1), (0, -1), (1, 1), (1, -1)):
        ring |= np.roll(np.roll(a, dy, 0), dx, 1)
    ring &= ~a
    out = canvas()
    for y, x in zip(*np.nonzero(ring)):
        if y >= cut:
            out[y, x] = (*RIM, 200)
    return out


def main(argv):
    made = {name: Image.fromarray(draw(), "RGBA") for name, draw in FLOATS.items()}
    for name, img in made.items():
        img.save(SPR / f"{name}.png")
    rims = {}
    for name in list(FLOATS) + RIMMED:
        path = SPR / f"{name}.png"
        if not path.exists():
            continue
        src = np.asarray(Image.open(path).convert("RGBA"))
        rims[name] = Image.fromarray(rim(src), "RGBA")
        rims[name].save(SPR / f"rim_{name}.png")
    print(f"wrote {len(made)} floating things and {len(rims)} waterlines")
    if argv[:1] == ["--sheet"]:
        names = list(rims)
        sheet = Image.new("RGBA", (len(names) * 34, 34), (74, 150, 170, 255))
        for k, name in enumerate(names):
            sheet.alpha_composite(rims[name], (k * 34 + 1, 1))
            sheet.alpha_composite(Image.open(SPR / f"{name}.png").convert("RGBA").resize((SIZE, SIZE), Image.NEAREST), (k * 34 + 1, 0))
        sheet.resize((sheet.width * 6, sheet.height * 6), Image.NEAREST).save(argv[1])
        print(argv[1])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
