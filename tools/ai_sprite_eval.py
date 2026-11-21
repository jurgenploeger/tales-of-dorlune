"""Score a sprite from a general image model (ChatGPT, Gemini's Nano Banana) against the game's look.

Those models don't draw on a real pixel grid: they paint a big picture (1024 pixels and up) that looks
like pixel art, with blurred edges, drifting "pixels" of uneven size and a background that's never truly
clear. This brings one back to the game's grid and holds it to what Retro Diffusion's art is held to:

1. the background is found from the corners and cleared;
2. the sprite is cut to its bounding box and brought to the size asked for (`--height`, the RD sprite's
   height by default), each new pixel the colour covering most of its block (no blending);
3. its colours are cut to at most `--colours` (RD's monsters use 18 to 33);
4. it's placed on a 40 × 40 canvas (64 for a boss) standing where RD's stand;
5. `pixel_style.py check --kind creature` scores it, and the Pixel Heroes marks
   (docs/sprite-acceptance.md) are measured: outline, inner lines, saturation;
6. a sheet puts it beside RD's own drawing of the same thing, at 1x and 8x, on grass and the battle field.

    python3 tools/ai_sprite_eval.py <image> --rd monster_snowman --out docs/ai-sprite-test/results/chatgpt_1

Writes <out>.png (the sprite as the game would load it) and <out>_sheet.png. Needs pillow + numpy.
"""
import argparse
import os
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GRASS = (104, 160, 72, 255)
FIELD = (40, 36, 52, 255)


def clear_background(im, tolerance):
    """Clear everything that matches the corners' colours (a flat or a checkerboard background)."""
    a = np.array(im.convert("RGBA")).astype(int)
    if (a[..., 3] < 128).mean() > 0.2:  # already has a real transparent background
        a[..., 3] = np.where(a[..., 3] < 128, 0, 255)
        return a
    h, w = a.shape[:2]
    k = max(4, min(h, w) // 40)
    corners = np.concatenate([a[:k, :k], a[:k, -k:], a[-k:, :k], a[-k:, -k:]]).reshape(-1, 4)[:, :3]
    # every distinct background colour (two for a fake checkerboard)
    bgs = []
    for c in corners:
        if all(np.abs(c - b).sum() > tolerance for b in bgs):
            bgs.append(c)
    rgb = a[..., :3]
    bg = np.zeros((h, w), bool)
    for b in bgs[:3]:
        bg |= np.abs(rgb - b).sum(-1) <= tolerance
    # only background that's connected to the edge: a white eye or highlight inside stays
    from scipy import ndimage
    lab, _ = ndimage.label(bg)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    a[..., 3] = np.where(bg, 0, 255)
    return a


def to_grid(a, height):
    """Cut to the sprite and bring it to `height` art pixels, each the majority colour of its block."""
    ys, xs = np.nonzero(a[..., 3])
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = a.shape[:2]
    cell = h / height
    width = max(1, round(w / cell))
    out = np.zeros((height, width, 4), np.uint8)
    for y in range(height):
        for x in range(width):
            y0, y1 = int(y * cell), max(int((y + 1) * cell), int(y * cell) + 1)
            x0, x1 = int(x * w / width), max(int((x + 1) * w / width), int(x * w / width) + 1)
            # the middle of the block, as the edges are where the model blurs
            my, mx = (y1 - y0) // 4, (x1 - x0) // 4
            block = a[y0 + my:y1 - my or y1, x0 + mx:x1 - mx or x1].reshape(-1, 4)
            if (block[:, 3] > 0).mean() < 0.5:
                continue
            rgb = block[block[:, 3] > 0][:, :3]
            near = rgb // 12  # group near-identical colours, take the biggest group
            vals, inv, counts = np.unique(near, axis=0, return_inverse=True, return_counts=True)
            out[y, x, :3] = rgb[inv.ravel() == counts.argmax()].mean(0).astype(np.uint8)
            out[y, x, 3] = 255
    return out


def reduce_colours(a, n):
    alpha = a[..., 3]
    rgb = Image.fromarray(a[..., :3])
    q = rgb.quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = np.dstack([np.array(q), alpha])
    return out


def place(a, canvas, ref):
    """On the canvas where RD's own sprite stands: its feet on the same row, centred."""
    out = np.zeros((canvas, canvas, 4), np.uint8)
    h, w = a.shape[:2]
    bottom = canvas - 4
    if ref is not None:
        ys = np.nonzero(ref[..., 3])[0]
        bottom = ys.max() + 1
    top = max(0, bottom - h)
    left = max(0, (canvas - w) // 2)
    a = a[: canvas - top, : canvas - left]
    out[top:top + a.shape[0], left:left + a.shape[1]] = a
    return out


def marks(a):
    """The Pixel Heroes numbers from docs/sprite-acceptance.md."""
    import colorsys
    from scipy import ndimage
    solid = a[..., 3] > 0
    inner = ndimage.binary_erosion(solid)
    outline = solid & ~inner
    rgb = a[..., :3] / 255.0
    light = rgb.max(-1)
    hsv = np.array([colorsys.rgb_to_hsv(*p) for p in rgb[solid]])
    ol = light[outline]
    return {
        "outline median light (<= 0.25)": float(np.median(ol)),
        "outline share darker than 0.25 (>= 0.5)": float((ol < 0.25).mean()),
        "pixels darker than 0.2 (>= 0.2)": float((light[solid] < 0.2).mean()),
        "median saturation (>= 0.45)": float(np.median(hsv[:, 1])),
        "colours": int(len(np.unique(a[solid][:, :3], axis=0))),
    }


def sheet(ours, ref, path):
    tiles = []
    for img in [ref, ours]:
        if img is None:
            continue
        for bg in (GRASS, FIELD):
            for s in (1, 8):
                t = Image.new("RGBA", (img.shape[1] * s + 16, img.shape[0] * s + 16), bg)
                t.alpha_composite(Image.fromarray(img).resize((img.shape[1] * s, img.shape[0] * s), Image.NEAREST), (8, 8))
                tiles.append(t)
    per = 4
    rows = [tiles[i:i + per] for i in range(0, len(tiles), per)]
    W = max(sum(t.width for t in r) for r in rows)
    H = sum(max(t.height for t in r) for r in rows)
    out = Image.new("RGBA", (W, H), (230, 230, 230, 255))
    y = 0
    for r in rows:
        x = 0
        for t in r:
            out.alpha_composite(t, (x, y))
            x += t.width
        y += max(t.height for t in r)
    out.convert("RGB").save(path)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("image")
    p.add_argument("--rd", help="the RD sprite id to compare with (art/sprites/<id>.png)")
    p.add_argument("--out", required=True)
    p.add_argument("--canvas", type=int, default=40)
    p.add_argument("--height", type=int, help="art pixels tall (default: the RD sprite's height)")
    p.add_argument("--colours", type=int, default=28)
    p.add_argument("--tolerance", type=int, default=60)
    args = p.parse_args()

    ref = None
    if args.rd:
        ref = np.array(Image.open(os.path.join(ROOT, "art/sprites", args.rd + ".png")).convert("RGBA"))
    height = args.height
    if height is None:
        height = (np.ptp(np.nonzero(ref[..., 3])[0]) + 1) if ref is not None else args.canvas - 6

    a = clear_background(Image.open(args.image), args.tolerance)
    a = to_grid(a, height)
    a = reduce_colours(a, args.colours)
    a = place(a, args.canvas, ref)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    Image.fromarray(a).save(args.out + ".png")
    sheet(a, ref, args.out + "_sheet.png")

    print(f"{args.out}.png  ({args.canvas}x{args.canvas}, {height} art pixels tall)")
    print("\nPixel Heroes marks:")
    for k, v in marks(a).items():
        print(f"   {k:42} {v:.3f}" if isinstance(v, float) else f"   {k:42} {v}")
    if ref is not None:
        print(f"\nRD's {args.rd} for comparison:")
        for k, v in marks(ref).items():
            print(f"   {k:42} {v:.3f}" if isinstance(v, float) else f"   {k:42} {v}")
    print()
    sys.stdout.flush()
    subprocess.call([sys.executable, os.path.join(ROOT, "tools/pixel_style.py"), "check", "--kind", "creature", args.out + ".png"]
                    + ([os.path.join(ROOT, "art/sprites", args.rd + ".png")] if args.rd else []))


if __name__ == "__main__":
    main()
