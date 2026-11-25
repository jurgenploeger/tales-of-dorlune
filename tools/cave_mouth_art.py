#!/usr/bin/env python3
"""The caves' mouths, ChatGPT's drawings (docs/ai-sprite-test/cave-mouths, the user, 2026-11-25), brought to the
game's grid: each picked drawing in `art-variants/cave_mouth/` is painted big (about 12 pixels a pixel) on a
128 × 80 canvas, so it's cut back to 128 × 80, each pixel the colour covering most of the middle of its block,
alpha 0 or 255, its near-identical colours merged and cut to `COLOURS`.

    python3 tools/cave_mouth_art.py              # writes art/sprites/cave_mouth*.png
    python3 tools/cave_mouth_art.py --sheet out.png

Needs pillow + numpy.
"""
import pathlib
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import ai_sprite_eval as ai  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "art-variants" / "cave_mouth"
OUT = ROOT / "art" / "sprites"
W, H = 128, 80
COLOURS = 56

# The sprite each picked drawing makes. `cave_mouth_rat_a` (a big sign that read as a heart) lost to the small one.
PICKED = {
    "cave_mouth": "cave_mouth.webp",
    "cave_mouth_glimmer": "cave_mouth_glimmer.webp",
    "cave_mouth_slime": "cave_mouth_slime.webp",
    "cave_mouth_rat": "cave_mouth_rat.webp",
}


def to_grid(path):
    a = np.array(Image.open(path).convert("RGBA")).astype(int)
    h, w = a.shape[:2]
    out = np.zeros((H, W, 4), np.uint8)
    for y in range(H):
        for x in range(W):
            y0, y1 = int(y * h / H), int((y + 1) * h / H)
            x0, x1 = int(x * w / W), int((x + 1) * w / W)
            my, mx = (y1 - y0) // 4, (x1 - x0) // 4
            block = a[y0 + my:y1 - my, x0 + mx:x1 - mx].reshape(-1, 4)
            solid = block[block[:, 3] > 127]
            if len(solid) < len(block) / 2:
                continue
            rgb = solid[:, :3]
            near = rgb // 12
            _, inv, counts = np.unique(near, axis=0, return_inverse=True, return_counts=True)
            out[y, x, :3] = rgb[inv.ravel() == counts.argmax()].mean(0).astype(np.uint8)
            out[y, x, 3] = 255
    return ai.reduce_colours(out, COLOURS).astype(np.uint8)


def main(argv):
    made = {}
    for sprite, source in PICKED.items():
        a = to_grid(SRC / source)
        Image.fromarray(a, "RGBA").save(OUT / f"{sprite}.png")
        made[sprite] = a
        colours = len(np.unique(a[a[..., 3] > 0][:, :3], axis=0))
        floor = a[H - 1, 24:104, 3].min() > 0
        print(f"{sprite}: {colours} colours, road row {'open' if floor else 'NOT open'}")
    if argv[:1] == ["--sheet"]:
        sheet = Image.new("RGBA", (len(made) * (W + 4), H), (120, 110, 100, 255))
        for k, a in enumerate(made.values()):
            sheet.alpha_composite(Image.fromarray(a, "RGBA"), (k * (W + 4), 0))
        sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(argv[1])
        print(argv[1])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
