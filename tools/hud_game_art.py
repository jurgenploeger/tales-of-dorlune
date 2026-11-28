#!/usr/bin/env python3
"""The carved-wood HUD at game size: ChatGPT's 1280-pixel pieces (art-variants/hud/, docs/ai-sprite-test/hud/
HANDOVER.md) cut and shrunk to 3 pixels a point into the asset catalog, `Assets.xcassets/Wood/`, each with its
Dark Mode twin as the catalog's dark appearance (so SwiftUI swaps them as the look changes, `WoodArt`).

    python3 tools/hud_game_art.py

- `WoodWindowFrame`: the window frame as a nine-slice, its corners 64 pixels (21 points), one whole motif of
  each rail between them (216 and 152 source pixels, 72 and 51 here) to tile, its parchment pane cut out:
  the windows keep their deep pane under it, a warm walnut in both looks (`HUDStyle.glass`), for their
  cream text.
- `WoodClose` and `WoodClosePressed`: the close button, 30 points.
- `WoodButton<Name>` and `...Pressed`: the round buttons with their enamel pictures, 56 points, and the
  plain one (`WoodButtonRound`) for a button with none.
- `WoodMinimapRing` (its ring 143 points, its window 114), `WoodCompass` and `WoodNeedle` (42).
- `WoodJoystickBase` (142) and `WoodJoystickKnob` (58), `WoodPortraitRing` (its ring 76).
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
HUD = ROOT / "art-variants/hud"
CAT = ROOT / "TalesOfDorlune/Resources/Assets.xcassets/Wood"
X = 3  # pixels a point


def load(path, dark):
    p = Path(path)
    return Image.open(p.with_name(p.stem + ("_dark" if dark else "") + p.suffix)).convert("RGBA")


def shrink(img, size):
    return img.resize(size, Image.LANCZOS)


def write(name, light, dark):
    folder = CAT / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    light.save(folder / f"{name}.png")
    dark.save(folder / f"{name}_dark.png")
    (folder / "Contents.json").write_text(json.dumps({
        "images": [
            {"filename": f"{name}.png", "idiom": "universal", "scale": "3x"},
            {"appearances": [{"appearance": "luminosity", "value": "dark"}], "filename": f"{name}_dark.png",
             "idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")


def round_piece(path, diameter_px, points, box=None):
    """A round piece, its `diameter_px` (in the 1280 canvas) `points` across: the whole canvas, or `box`."""
    out = []
    for dark in (False, True):
        img = load(path, dark)
        if box:
            img = img.crop(box)
        k = points * X / diameter_px
        out.append(shrink(img, (round(img.width * k), round(img.height * k))))
    return out


def window_frame():
    geo = json.loads((HUD / "windows/geometry.json").read_text())["assets"]["window_frame"]
    l, t, r, b = geo["slice_rect"]
    c = geo["cap_insets_px"][0]
    ph, pv = geo["edge_tile_period_px"]["horizontal"], geo["edge_tile_period_px"]["vertical"]
    light = load(HUD / "windows/window_frame.png", False)
    a = np.array(light)
    pane = (a[..., :3] == geo["pane_rgb_light"]).all(-1) & (a[..., 3] > 0)
    labels, _ = ndimage.label(pane)
    cut = labels == labels[640, 640]
    out = []
    for dark in (False, True):
        src = np.array(load(HUD / "windows/window_frame.png", dark))
        src[cut, 3] = 0
        src = Image.fromarray(src)
        # Corners, one motif of each rail, a clear middle.
        xs = [(l, l + c), (l + c, l + c + ph), (r - c, r)]
        ys = [(t, t + c), (t + c, t + c + pv), (b - c, b)]
        cw, mw, mh = 64, 72, 51
        sizes_x, sizes_y = [cw, mw, cw], [cw, mh, cw]
        sheet = Image.new("RGBA", (sum(sizes_x), sum(sizes_y)), (0, 0, 0, 0))
        oy = 0
        for (y0, y1), hy in zip(ys, sizes_y):
            ox = 0
            for (x0, x1), wx in zip(xs, sizes_x):
                sheet.alpha_composite(shrink(src.crop((x0, y0, x1, y1)), (wx, hy)), (ox, oy))
                ox += wx
            oy += hy
        out.append(sheet)
    write("WoodWindowFrame", *out)


def main():
    window_frame()
    for state in ("", "_pressed"):
        write("WoodClose" + ("Pressed" if state else ""), *round_piece(HUD / f"windows/close_button{state}.png", 1040, 30, (120, 120, 1160, 1160)))
        write("WoodButtonRound" + ("Pressed" if state else ""), *round_piece(HUD / f"kit/button_round{state}.png", 1041, 56, (120, 120, 1161, 1161)))
    names = sorted(p.stem[len("button_"):] for p in (HUD / "buttons").glob("button_*.png")
                   if not p.stem.endswith(("_dark", "_pressed")))
    for name in names:
        camel = "".join(w.capitalize() for w in name.split("_"))
        for state in ("", "_pressed"):
            write(f"WoodButton{camel}" + ("Pressed" if state else ""),
                  *round_piece(HUD / f"buttons/button_{name}{state}.png", 1041, 56, (120, 120, 1161, 1161)))
    write("WoodMinimapRing", *round_piece(HUD / "kit/minimap_frame.png", 1127, 143))
    write("WoodCompass", *round_piece(HUD / "kit/compass_medallion.png", 1033, 42))
    write("WoodNeedle", *round_piece(HUD / "kit/compass_needle.png", 1033, 42))
    write("WoodJoystickBase", *round_piece(HUD / "kit/joystick_base.png", 1041, 142, (120, 120, 1161, 1161)))
    write("WoodJoystickKnob", *round_piece(HUD / "kit/joystick_knob.png", 1041, 58, (120, 120, 1161, 1161)))
    write("WoodPortraitRing", *round_piece(HUD / "kit/hero_portrait_ring.png", 1041, 76))
    (CAT / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    print("wrote", len(list(CAT.glob("*.imageset"))), "pieces to", CAT.relative_to(ROOT))


if __name__ == "__main__":
    main()
