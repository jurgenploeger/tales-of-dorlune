#!/usr/bin/env python3
"""The app icon's dark look and the festive app icons, copied from the user's picked drawings
(art-variants/app_icon_picked/, 2026-11-24): the hero with his golden sword, cropped in close, at night
(`dark.png`) and in each season by day and at night (`halloween.png`, `halloween_dark.png`, and so on:
autumn leaves and jack-o'-lanterns, spring blossom and painted eggs, snowy firs, baubles, presents and a
scarf). They replace what tools/app_icon_art.py drew for AppIcon-Dark and tools/season_icon_art.py for
AppIcon-<Season>; both leave those alone while a picked drawing is here (`picked`).

Each drawing is painted big (1254 pixels) on a grid of art pixels that drifts a little (about 13 pixels
a cell), so it's snapped to the grid (`GRID` cells, each the commonest colour in its middle, as
tools/ai_sprite_eval.py does), scaled up by a whole number (`SCALE`) and cut to 1024 round the middle:
crisp pixels, nothing smeared by a resize.

Tinted (iOS's Tinted and Clear looks) is made from them as tools/app_icon_art.py `tint` makes it: the
hero bright from the day drawing, on the night drawing pushed dim. The hero is the same in every drawing
and the scenery isn't, so he's the cells that agree across all seven (`hero_mask`), his holes filled
(the Christmas scarf, the gaps in his hair).

    python3 tools/picked_icon_art.py                    # writes the icons
    python3 tools/picked_icon_art.py --preview out.png  # each light, dark and tinted at Home Screen sizes

Needs pillow, numpy and scipy.
"""

import argparse
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

import app_icon_art

ROOT = Path(__file__).resolve().parent.parent
PICKED = ROOT / "art-variants/app_icon_picked"
ASSETS = ROOT / "TalesOfDorlune/Resources/Assets.xcassets"
SEASONS = ("Halloween", "Christmas", "Easter")
# 96 cells over 1254 pixels (13.06 a cell, the drawings' own grid); 96 × 11 = 1056, cut to 1024.
GRID, SCALE, SIZE = 96, 11, 1024


def picked(name: str) -> Path:
    """The picked drawing `name` (dark, halloween, halloween_dark…), which may not be there."""
    return PICKED / f"{name.lower()}.png"


def snap(path: Path) -> np.ndarray:
    """The drawing on its grid, `GRID` cells a side, 0 to 1."""
    a = np.asarray(Image.open(path).convert("RGB")).astype(int)
    cell = a.shape[0] / GRID
    out = np.zeros((GRID, GRID, 3))
    for y in range(GRID):
        for x in range(GRID):
            y0, y1 = int(y * cell), int((y + 1) * cell)
            x0, x1 = int(x * cell), int((x + 1) * cell)
            m = (y1 - y0) // 4  # the middle of the cell: the edges are where the painting blurs
            block = a[y0 + m:y1 - m, x0 + m:x1 - m].reshape(-1, 3)
            _, inv, counts = np.unique(block // 12, axis=0, return_inverse=True, return_counts=True)
            out[y, x] = block[inv.ravel() == counts.argmax()].mean(0) / 255
    return out


def scaled(rgb: np.ndarray) -> Image.Image:
    big = np.repeat(np.repeat(rgb, SCALE, axis=0), SCALE, axis=1)
    cut = (big.shape[0] - SIZE) // 2
    big = big[cut:cut + SIZE, cut:cut + SIZE]
    return Image.fromarray((np.clip(big, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")


def hero_mask(images: list) -> np.ndarray:
    """The cells every drawing agrees on (the hero), the biggest such piece, its holes filled."""
    stack = np.stack(images)
    agree = np.abs(stack - np.median(stack, axis=0)).max(axis=3)
    same = (agree < 0.16).mean(axis=0) >= 6 / 7
    same = ndimage.binary_opening(same, np.ones((2, 2)))
    parts, count = ndimage.label(same)
    if count == 0:
        return same
    biggest = 1 + np.argmax(ndimage.sum(same, parts, range(1, count + 1)))
    return ndimage.binary_fill_holes(parts == biggest)


def write(folder: Path, names: dict) -> None:
    for name, image in names.items():
        image.save(folder / name, optimize=True)
        print(f"wrote {(folder / name).relative_to(ROOT)}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--preview", type=Path, help="write each light, dark and tinted at Home Screen sizes here")
    args = parser.parse_args()

    dark = snap(picked("dark"))
    seasons = {s: (snap(picked(s)), snap(picked(f"{s}_dark"))) for s in SEASONS}
    hero = hero_mask([dark] + [image for pair in seasons.values() for image in pair])
    print(f"hero: {hero.mean():.0%} of the icon")

    rows = []
    tinted = app_icon_art.tint(dark, hero, dark)
    write(ASSETS / "AppIcon.appiconset", {"AppIcon-Dark.png": scaled(dark), "AppIcon-Tinted.png": scaled(tinted)})
    rows.append((Image.open(app_icon_art.LIGHT).convert("RGB"), scaled(dark), scaled(tinted)))
    for season, (day, night) in seasons.items():
        images = (scaled(day), scaled(night), scaled(app_icon_art.tint(night, hero, day)))
        write(ASSETS / f"AppIcon-{season}.appiconset",
              dict(zip((f"AppIcon-{season}{s}.png" for s in ("", "-Dark", "-Tinted")), images)))
        rows.append(images)

    if args.preview:
        sizes = [300, 120, 60]
        cell = sum(sizes) + 10 * (len(sizes) + 1)
        sheet = Image.new("RGB", (3 * cell, len(rows) * 320), (242, 242, 247))
        for r, row in enumerate(rows):
            for c, image in enumerate(row):
                x = c * cell + 10
                for side in sizes:
                    sheet.paste(app_icon_art.rounded(image, side), (x, r * 320 + 10))
                    x += side + 10
        sheet.save(args.preview)
        print(f"preview in {args.preview}: the app icon, then {', '.join(SEASONS)}; light, dark, tinted")


if __name__ == "__main__":
    main()
