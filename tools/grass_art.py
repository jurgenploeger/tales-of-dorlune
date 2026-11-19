#!/usr/bin/env python3
"""The tufts of tall grass the green lands grow (`GrassField`, maps.json theme `tallGrass`), drawn
as tools/grass_preview.py draws them (the user's pick, 2026-11-19: "make the tufts fuller"), in the
plain colours of a grass tile, for the game to grade with each land's palette as it does the ground.

Each of the four designs is a sheet of frames 18 × 20: across, the tuft leaning −8 to 8 pixels at
its tip (17 frames, its rows moved in whole pixels); down, pressed flat by steps (`STAGES`: 0, 0.3,
0.5, 0.75 and 1 of the way to a third of its height), a shade darker past 0.3 and two past 0.6.

  python3 tools/grass_art.py            writes art/sprites/tall_grass_<d>.png, tall_grass_dark_<d>.png
  python3 tools/grass_art.py --sheet out.png   the first frame of each, at 4×
"""
import argparse, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import palette_preview as pp
import grass_preview as gp

LEANS = range(-8, 9)
STAGES = [0.0, 0.3, 0.5, 0.75, 1.0]
SETS = {'tall_grass': 'tile_grass', 'tall_grass_dark': 'tile_dark_grass'}
OUT = os.path.join(pp.R, 'art/sprites')


def sheet(tile, design):
    ramp = gp.ramp_from(pp.raw(tile))
    pic = gp.tuft(design, ramp)
    img = np.zeros((gp.TH * len(STAGES), gp.TW * len(LEANS), 4), np.uint8)
    for row, press in enumerate(STAGES):
        steps = 2 if press > 0.6 else 1 if press > 0.3 else 0
        dark = gp.darker(pic, steps, ramp)
        for col, lean in enumerate(LEANS):
            img[row * gp.TH:(row + 1) * gp.TH, col * gp.TW:(col + 1) * gp.TW] = gp.posed(dark, lean, press, 0)
    return img


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--sheet')
    args = ap.parse_args()
    firsts = []
    for name, tile in SETS.items():
        for d in range(4):
            img = sheet(tile, d)
            if args.sheet:
                firsts.append(img[:gp.TH, 8 * gp.TW:9 * gp.TW])
            else:
                Image.fromarray(img).save(os.path.join(OUT, f'{name}_{d}.png'))
    if args.sheet:
        row = np.concatenate(firsts, 1)
        bg = np.zeros(row.shape[:2] + (3,), np.uint8); bg[:] = (60, 120, 40)
        a = row[..., 3:] / 255
        out = Image.fromarray((bg * (1 - a) + row[..., :3] * a).astype(np.uint8))
        out.resize((out.width * 4, out.height * 4), Image.NEAREST).save(args.sheet)
