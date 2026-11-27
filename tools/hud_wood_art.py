#!/usr/bin/env python3
"""The carved-wood HUD's art from ChatGPT (art-variants/hud/, docs/ai-sprite-test/hud/HANDOVER.md), fixed
where the user asked, the originals left as drawn:

- `inset_panel_dark`: the sunk list panel in Dark Mode was barely darker than the window's pane (48,31,25
  on 62,43,35): its fill and inner shading are darkened, so it sits as far below the pane as the light
  one does (the user, 2026-11-27: "update the dark list panel").
- `speech_window` (and `_dark`): drawn 43 points tall at the kit's 9 pixels a point, the speech window is
  150. Drawn at 4.5 pixels a point (its carvings as big as the windows' corners), it grows down, not by scaling: one plain row through it, between the star and the leaf on its
  carved left band (`SPEECH_ROW`), repeats, so the moon and star stay at the top, the leaf at the foot,
  every carving its own size (the user: "fix the speech plate").

Writes art-variants/hud/fixed/ and its `fixed.json` (each piece's rows and caps).
  python3 tools/hud_wood_art.py            # write
  python3 tools/hud_wood_art.py --preview out.png
"""
import json, sys
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art-variants/hud/windows"
OUT = ROOT / "art-variants/hud/fixed"

PANE_DARK = (62, 43, 35)
# How far the dark fill sits below the pane, as the light panel's (221,190,140) sits below its (242,226,194).
DARKEN = 0.55
SPEECH_ROW = 672          # a plain row across the whole plate (least detail on its carved band)
SPEECH_HEIGHT_PT = 150    # the speech window's height in the game
PX_PER_PT = 4.5           # the speech plate's scale: half the kit's 9 (geometry.json), as at 9 its rails
                          # were a point and its carvings 6 points, beside the windows' 5.7-point rails


def lum(c):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(x) for x in c[:3])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def darker_inset():
    im = np.array(Image.open(SRC / "inset_panel_dark.png").convert("RGBA"))
    geo = {a["filename"][:-4]: a for a in json.load(open(SRC / "geometry.json"))["assets"]} \
        if isinstance(json.load(open(SRC / "geometry.json"))["assets"], list) else json.load(open(SRC / "geometry.json"))["assets"]
    l, t, r, b = geo["inset_panel"]["slice_rect"]
    inner = im[t + 14:b - 14, l + 14:r - 14]
    shown = inner[inner[..., 3] > 0][:, :3]
    # the fill and its inner shading: the colours inside darker than the pane's
    fills = {tuple(c) for c in np.unique(shown, axis=0) if lum(c) < lum(PANE_DARK)}
    out = im.copy()
    mask = np.zeros(im.shape[:2], bool)
    for c in fills:
        mask |= (im[..., :3] == c).all(-1) & (im[..., 3] > 0)
    out[mask, :3] = (im[mask, :3].astype(float) * DARKEN).round().astype(np.uint8)
    return Image.fromarray(out), sorted(fills)


def taller_speech(dark):
    name = "speech_window_dark" if dark else "speech_window"
    im = Image.open(SRC / f"{name}.png").convert("RGBA")
    top, foot = 448, 832
    want = round(SPEECH_HEIGHT_PT * PX_PER_PT)
    grow = want - (foot - top)
    w = im.width
    out = Image.new("RGBA", (w, want), (0, 0, 0, 0))
    out.paste(im.crop((0, top, w, SPEECH_ROW)), (0, 0))
    row = im.crop((0, SPEECH_ROW, w, SPEECH_ROW + 1))
    for i in range(grow + 1):
        out.paste(row, (0, SPEECH_ROW - top + i))
    out.paste(im.crop((0, SPEECH_ROW + 1, w, foot)), (0, SPEECH_ROW - top + grow + 1))
    return out, grow


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    inset, fills = darker_inset()
    inset.save(OUT / "inset_panel_dark.png")
    info = {"inset_panel_dark": {
        "from": "art-variants/hud/windows/inset_panel_dark.png", "darkened_colours": [list(map(int, c)) for c in fills],
        "factor": DARKEN,
        "fill_before": [48, 31, 25], "fill_after": [round(v * DARKEN) for v in (48, 31, 25)],
        "contrast_to_pane_before": round(contrast((48, 31, 25), PANE_DARK), 2),
        "contrast_to_pane_after": round(contrast([round(v * DARKEN) for v in (48, 31, 25)], PANE_DARK), 2),
        "light_panel_contrast_to_its_pane": round(contrast((221, 190, 140), (242, 226, 194)), 2),
        "slices": "as art-variants/hud/windows/geometry.json inset_panel (80 px corners)"}}
    for dark in (False, True):
        im, grow = taller_speech(dark)
        n = "speech_window_dark" if dark else "speech_window"
        im.save(OUT / f"{n}.png")
        info[n] = {"from": f"art-variants/hud/windows/{n}.png, rows 448 to 832",
                   "size_px": list(im.size), "height_pt": SPEECH_HEIGHT_PT, "px_per_pt": PX_PER_PT,
                   "repeated_row_in_source": SPEECH_ROW, "rows_added": grow,
                   "vertical_stretch_rows": [SPEECH_ROW - 448, SPEECH_ROW - 448 + grow + 1],
                   "horizontal_cap_insets_px": [216, 124], "stretch_cols": [280, 1092],
                   "bounding_box_x": [64, 1216],
                   "content_rect": [290, 26, 942, im.height - 26],
                   "speaker_overlay_cols": [990, 1216]}
    (OUT / "fixed.json").write_text(json.dumps(info, indent=2) + "\n")
    print(json.dumps({k: {kk: v[kk] for kk in v if 'contrast' in kk or kk in ('size_px', 'rows_added')} for k, v in info.items()}, indent=1))
    if "--preview" in sys.argv:
        path = sys.argv[sys.argv.index("--preview") + 1]
        sheet = Image.new("RGBA", (2700, 1700), (80, 130, 90, 255))
        sheet.paste(Image.new("RGBA", (2700, 850), (18, 28, 50, 255)), (0, 850))
        for k, n in enumerate(["speech_window", "speech_window_dark"]):
            im = Image.open(OUT / f"{n}.png").crop((64, 0, 1216, round(SPEECH_HEIGHT_PT * PX_PER_PT)))
            im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
            sheet.alpha_composite(im, (40, 40 + k * 850))
        for k, (n, src) in enumerate([("inset_panel_dark", SRC), ("inset_panel_dark", OUT)]):
            pane = Image.new("RGBA", (1200, 500), PANE_DARK + (255,))
            pane.alpha_composite(Image.open(src / f"{n}.png").crop((60, 434, 1220, 846)).resize((1160, 412)), (20, 44))
            sheet.alpha_composite(pane.resize((1000, 417)), (1660, 40 + k * 430) if k == 0 else (1660, 40 + 430))
        sheet.convert("RGB").save(path)


if __name__ == "__main__":
    main()
