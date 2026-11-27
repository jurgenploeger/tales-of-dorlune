#!/usr/bin/env python3
"""Lit windows at night (the user, 2026-11-18: "during the night the lights in houses should be brighter"): each
building's windows cut into a picture of their own (`windows_<id>.png`, the rest clear), which the game lays over
the building above the night's shade as it grows dark (`LandStage.addWindows`), so the windows glow as drawn
while the house dims. Retro Diffusion's art stays as it is.

A window pixel is warm and bright (a lit pane's yellow). Thatch, gold trim and lantern-lit awnings are too, so
only small patches of them count (`BIGGEST` pixels at most, a pane or a small window; a thatched roof is one
patch of hundreds), and `SKIP` names what has no windows to light (gates, fences, tents and stalls, and the
few whose roofs still came through). The forge and the brazier keep their own fire (`tools/fire_art.py`): a still
copy of the flame over it at night hid the flame moving.

    python3 tools/window_art.py              # writes art/sprites/windows_<id>.png and lists the ids
    python3 tools/window_art.py --sheet out.png

Needs pillow + numpy + scipy.
"""
import json
import pathlib
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPR = ROOT / "art" / "sprites"
BIGGEST = 64
FEWEST = 6
SKIP = {"fence", "town_gate", "market_tent", "market_stall", "pavilion_tent", "desert_tent", "yurt", "blacksmith",
        "bakery", "beach_hut", "windmill", "adobe_house", "candy_cottage", "fisher_shack", "bell_tower", "puppet_theater", "mushroom_house"}


# Where a building's windows are, as boxes (rows y0 to y1, columns x0 to x1), when bright warm pixels
# elsewhere would pass for panes too: the thatched cottage's straw, the book shop's hanging sign, a yellow
# cloth in the tailor's window, the dome house's sandstone along its wall top (the pictures ChatGPT drew,
# 2026-11-21). Only pixels in a box count.
FAIRY_HOUSE = [(39, 48, 46, 55), (51, 60, 34, 43), (59, 68, 50, 59)]
BOXES = {"thatched_cottage": [(60, 96, 0, 96)],
         # ChatGPT's fairy tree houses (2026-11-26, docs/ai-sprite-test/big-trees): a cross through each little round
         # window cuts its pane into specks too small to count unboxed; the balcony, ladder and lantern stay dark.
         "fairy_tree_house": FAIRY_HOUSE, "fairy_tree_house_moon": FAIRY_HOUSE, "fairy_tree_house_rose": FAIRY_HOUSE,
         "fairy_great_tree": [(52, 61, 66, 75), (61, 70, 41, 50), (61, 70, 82, 91), (69, 78, 60, 69), (84, 93, 45, 54)],
         "tailor_shop": [(50, 64, 0, 96)],
         "tree_house": [(40, 52, 0, 96)],
         "round_cottage": [(40, 96, 0, 96)],
         "sandstone_house": [(39, 55, 25, 37), (66, 82, 25, 37)],
         "spice_shop": [(63, 77, 18, 29)],
         "stump_house": [(55, 70, 20, 75)],
         "reed_boathouse": [(58, 72, 26, 38), (58, 72, 55, 67)],
         "raft_teahouse": [(63, 74, 28, 70)],
         "pineapple_hut": [(56, 70, 22, 33), (56, 70, 61, 72)],
         "well_house": [(48, 56, 35, 46), (60, 78, 22, 33)],
         "pillow_cottage": [(71, 80, 27, 37), (71, 80, 58, 68)],
         "toll_house": [(63, 72, 23, 29), (63, 72, 52, 58)],
         "pearl_diver_hut": [(57, 64, 28, 35), (57, 64, 61, 68)],
         # ChatGPT's redraws of RD's buildings (2026-11-27, docs/ai-sprite-test/buildings-1to1): their roofs' warm specks
         # left out. The adobe house, candy cottage and fisher's shack have no windows (SKIP).
         "house": [(76, 98, 28, 42), (76, 98, 74, 92)],
         "adobe_house_tall": [(48, 63, 40, 48), (48, 63, 64, 73)],
         "swamp_stilt_hut": [(54, 72, 33, 41)],
         "witch_hut": [(72, 81, 22, 30)],
         # Batch 2's (2026-11-27): warm stone, thatch, hives and a cap's specks left out; the bell tower has none (SKIP).
         "acorn_cottage": [(49, 63, 39, 53), (80, 94, 65, 79)],
         "assay_office": [(80, 100, 26, 43)],
         "beekeeper_cottage": [(80, 97, 25, 38), (80, 97, 66, 79)],
         "book_shop": [(75, 88, 56, 68)],
         "carved_chalet": [(58, 70, 49, 60), (88, 104, 27, 39), (88, 104, 68, 80)],
         "dome_house": [(77, 87, 42, 51), (78, 98, 64, 75)],
         # Batch 3's: an awning's, gold's, a deck's, rock's and a lid's warm specks left out.
         "flower_shop": [(86, 100, 54, 83)],
         "frog_hut": [(52, 68, 24, 38), (52, 68, 76, 90)],
         "lamp_house": [(98, 110, 35, 45), (98, 110, 71, 81)],
         "lookout_hut": [(67, 81, 37, 47), (67, 81, 75, 85)],
         "miners_lodge": [(81, 100, 26, 40), (81, 94, 65, 73)],
         "ice_fishing_hut": [(82, 96, 36, 49)],
         "music_box_house": [(87, 101, 24, 34), (87, 101, 62, 74)],
         "toymaker_workshop": [(63, 80, 30, 44), (64, 76, 69, 77)]}   # its windows, not the clock's face


# Windows the warm rule can't find (Retro Diffusion drew their glass dim, orange or dark, and a few of ChatGPT's
# panes carry mullions that split them): every pixel in each box is lit, laid on a lamplight ramp by how light it
# is in the box (`paint`), so the frames and mullions stay darker. Rows y0 to y1, columns x0 to x1.
PAINT = {"sandstone_house": [(44, 56, 27, 36), (66, 78, 27, 36)],
         "spice_shop": [(64, 76, 25, 35)]}
DEEP, PALE = np.array([205, 105, 40]), np.array([255, 238, 160])
# Which pixels of a `PAINT` box are the glass (the user, 2026-11-25: lit as whole boxes, the inn's slanted
# windows lit the plaster round them and the round house's lit its wall above them): the house's dark holes,
# the inn's orange panes. Others light the whole box.
GLASS = {}

# Lights (the user, 2026-11-22: "fires, lanterns, street lights and anything else that could have light in the
# evening/night should be lit up"): what glows of each, cut as a window is and laid above the night's shade with a
# soft glow round it (`LandStage.addWindows`). A lit pixel is bright (value from `v`) and coloured (saturation from
# `s`), or a white-hot core beside one; `boxes` keeps it to the light (a torch's flame, not its pole).
# ChatGPT's wall torches (2026-11-26): the flame in rows 0 to 16, its brass bracket below it kept dark.
TORCH = {"boxes": [(0, 17, 0, 32)]}
LIGHTS = {"street_lamp": {}, "wall_torch": TORCH, "wall_torch_2": TORCH, "wall_torch_3": TORCH, "wall_torch_4": TORCH,
          "tiki_torch": {"boxes": [(0, 13, 8, 24)]}, "moon_lantern_post": {}, "spooky_lantern": {}, "wisp_lantern": {},
          "stone_lantern": {}, "mine_lantern_post": {"boxes": [(25, 36, 18, 28)]},
          "firefly_jar_post": {"boxes": [(20, 36, 16, 28)]}, "magic_lamp": {"boxes": [(0, 13, 0, 32)]},
          "bubbling_cauldron": {}, "fallen_star": {}, "crystal": {}, "big_ice_cluster": {}, "star_crystal": {}, "crystal_spire": {},
          "amethyst_spire": {}, "crystal_geode": {}, "glow_moss_rock": {}, "moon_flower": {"s": 0.1}, "fairy_ring": {}}


def light(name, v=0.72, s=0.25, boxes=None):
    """A light's glowing pixels (`LIGHTS`), as drawn."""
    path = SPR / f"{name}.png"
    if not path.exists():
        return None
    im = np.asarray(Image.open(path).convert("RGBA")).astype(float)
    rgb = im[..., :3] / 255
    top, low = rgb.max(-1), rgb.min(-1)
    sat = np.where(top > 0, (top - low) / np.maximum(top, 1e-6), 0)
    solid = im[..., 3] > 0
    lit = solid & (top >= v) & (sat >= s)
    lit |= solid & (top >= 0.93) & ndimage.binary_dilation(lit, iterations=2)
    if boxes:
        inside = np.zeros(lit.shape, bool)
        for y0, y1, x0, x1 in boxes:
            inside[y0:y1, x0:x1] = True
        lit &= inside
    labels, count = ndimage.label(lit, structure=np.ones((3, 3)))
    keep = np.zeros(lit.shape, bool)
    for index in range(1, count + 1):
        if (labels == index).sum() >= 2:
            keep |= labels == index
    if keep.sum() < 4:
        return None
    out = np.zeros(im.shape, np.uint8)
    out[keep] = im[keep].astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def paint(name):
    """`PAINT`'s windows: every pixel in each box on a lamplight ramp by its lightness there."""
    im = np.asarray(Image.open(SPR / f"{name}.png").convert("RGBA")).astype(float)
    out = np.zeros(im.shape, np.uint8)
    luma = im[..., :3] @ np.array([0.299, 0.587, 0.114])
    for y0, y1, x0, x1 in PAINT[name]:
        box = (slice(y0, y1), slice(x0, x1))
        solid = im[box][..., 3] > 0
        rgb = im[box][..., :3] / 255
        top, low = rgb.max(-1), rgb.min(-1)
        sat = np.where(top > 0, (top - low) / np.maximum(top, 1e-6), 0)
        if GLASS.get(name) == "dark":
            # The glass is the darkest of it, inside the frame: the biggest patch under the frame's shade.
            dark = solid & (luma[box] < 55)
            labels, count = ndimage.label(dark)
            if count:
                sizes = ndimage.sum(dark, labels, range(1, count + 1))
                dark = labels == (1 + int(np.argmax(sizes)))
            solid = dark
        elif GLASS.get(name) == "warm":
            solid &= (sat > 0.4) & (rgb[..., 0] > rgb[..., 2]) & (luma[box] > 80)
            # The highlights between its panes too, where glass lies on both sides.
            solid |= (im[box][..., 3] > 0) & (luma[box] > 170) & ndimage.binary_closing(solid, iterations=1)
        if not solid.any():
            continue
        lo, hi = luma[box][solid].min(), luma[box][solid].max()
        t = np.clip((luma[box] - lo) / max(hi - lo, 1), 0, 1) ** 0.8
        colour = DEEP + (PALE - DEEP) * t[..., None]
        out[box][..., :3] = np.where(solid[..., None], colour, out[box][..., :3]).astype(np.uint8)
        out[box][..., 3] = np.where(solid, 255, out[box][..., 3])
    return Image.fromarray(out, "RGBA")


def derived():
    """Recolours with no picture of their own (`house_green`, `pink_crystal`): their base's windows or light,
    recoloured by the same rules, as the game recolours the sprite."""
    assets = json.load(open(ROOT / "art" / "assets.json"))["assets"]
    lit = set(buildings()) | set(LIGHTS)
    out = {}
    for a in assets:
        d = a.get("derive")
        if not d or d.get("layers") or (SPR / f"{a['id']}.png").exists() or a.get("kind") not in ("building", "prop"):
            continue
        base = d["from"]
        made = cut(base) if base in lit else None
        if a["id"] in LIGHTS_DERIVED or a.get("kind") == "building":
            made = made or (light(base, **{k: v for k, v in LIGHTS.get(base, {}).items() if k == "s"}) if a["id"] in LIGHTS_DERIVED else None)
        if made is None:
            continue
        from palette_preview import recolor
        flat = np.asarray(made).astype(float) / 255
        out[a["id"]] = Image.fromarray((np.clip(recolor(flat, d["recolor"]), 0, 1) * 255).round().astype(np.uint8), "RGBA")
    return out


# Recolours that are lights, though their bases aren't (a glowing mushroom from a plain one): their base's bright
# pixels cut as a light's would be, then recoloured.
LIGHTS_DERIVED = {"glow_mushroom", "pink_crystal", "violet_crystal", "amber_crystal", "crystal_shard", "pink_shard",
                  "ice_cluster"}


def cut(name):
    """Whatever of `name` lights up at night: its painted windows, its light, or its warm panes."""
    if name in PAINT:
        return paint(name)
    if name in LIGHTS:
        spec = LIGHTS[name]
        return light(name, s=spec.get("s", 0.25), boxes=spec.get("boxes"))
    return windows(name)


def buildings():
    assets = json.load(open(ROOT / "art" / "assets.json"))
    assets = assets.get("assets", assets)
    return [a["id"] for a in assets if a.get("kind") == "building" and a["id"] not in SKIP and not a["id"].startswith("gate_")]


def windows(name):
    path = SPR / f"{name}.png"
    if not path.exists():
        return None
    im = np.asarray(Image.open(path).convert("RGBA")).astype(int)
    r, g, b, a = (im[..., i] for i in range(4))
    inside = np.zeros(a.shape, bool)
    for y0, y1, x0, x1 in BOXES.get(name, []):
        inside[y0:y1, x0:x1] = True
    # Inside a box a pane may be a pure yellow too (no blue in it at all: the glass lantern shop's), as gold
    # trim can't sneak in there.
    # And a little more orange (green from 150): the genie lamp's panes, its colours merged.
    warm = (a > 200) & (r >= 225) & ((g >= 175) | (inside & (g >= 150))) & (b <= g - 35) & ((b >= 60) | inside) & (r - b >= 60)
    if name in BOXES:
        warm &= inside
    labels, count = ndimage.label(warm, structure=np.ones((3, 3)))
    keep = np.zeros(warm.shape, bool)
    for index in range(1, count + 1):
        patch = labels == index
        if (2 if name in BOXES else 4) <= patch.sum() <= BIGGEST:   # not a speck of bright brick (in a box, a pane)
            keep |= patch
    if keep.sum() < FEWEST:
        return None
    out = np.zeros(im.shape, np.uint8)
    # A little brighter and warmer than drawn: lit from inside.
    lit = np.clip(im[..., :3] * np.array([1.06, 1.04, 0.96]) + np.array([8, 6, 0]), 0, 255)
    out[..., :3] = np.where(keep[..., None], lit, 0)
    out[..., 3] = np.where(keep, 255, 0)
    return Image.fromarray(out, "RGBA")


def main(argv):
    made = {name: img for name in [*buildings(), *LIGHTS] if (img := cut(name)) is not None}
    made.update(derived())
    if argv[:1] == ["--sheet"]:
        tiles = []
        for name, img in made.items():
            base = np.asarray(Image.open(SPR / f"{name}.png").convert("RGBA")).astype(float)
            base[..., :3] *= np.array([0.42, 0.47, 0.78])
            tile = Image.new("RGBA", img.size, (16, 20, 36, 255))
            tile.alpha_composite(Image.fromarray(base.astype(np.uint8), "RGBA"))
            tile.alpha_composite(img)
            tile.thumbnail((96, 96), Image.NEAREST)
            tiles.append(tile)
        cols = 10
        sheet = Image.new("RGB", (cols * 100, ((len(tiles) + cols - 1) // cols) * 100), (16, 20, 36))
        for i, tile in enumerate(tiles):
            sheet.paste(tile, (i % cols * 100, i // cols * 100))
        sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(argv[1])
        print(argv[1])
        return 0
    for name, img in made.items():
        img.save(SPR / f"windows_{name}.png")
    print(" ".join(sorted(made)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
