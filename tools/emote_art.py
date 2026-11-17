#!/usr/bin/env python3
"""Emotes (the user, 2026-11-17: "Can we add these emote/reactions features to the game?"): a little speech
bubble over someone's head with a picture in it, a heart, a ! or a ?, sleep, an idea... Our own drawings,
pixel by pixel, after the idea of a pixel-art emote set the user pointed to, not its pictures.

Each is a 24 × 24 picture (`art/sprites/emote_<name>.png`): a cream bubble with a dark outline and a tail
that curves down and away to the left (as a speech bubble's does, not a straight point), lit along its top
left, and its picture in the middle, drawn from a map of letters below (`ICONS`, `PALETTE`). The game pops
one over a walker for a few seconds (`Walker.emote`, `Emote`).

    python3 tools/emote_art.py                  # writes them all
    python3 tools/emote_art.py --sheet out.png  # every emote at 4x on the grass

Needs pillow + numpy.
"""
import pathlib
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPRITES = ROOT / "art" / "sprites"
SIZE = 24

INK = (0x3a, 0x2f, 0x4a)
FILL = (0xff, 0xf6, 0xe4)
LIT = (0xff, 0xff, 0xff)
SHADE = (0xe8, 0xd8, 0xc0)

PALETTE = {
    "k": INK,
    "r": (0xe0, 0x4a, 0x5a), "R": (0xa8, 0x30, 0x4a), "p": (0xff, 0xa6, 0xb4),
    "b": (0x4a, 0x7a, 0xe0), "B": (0x2e, 0x4a, 0xa0), "c": (0xa6, 0xd2, 0xff),
    "y": (0xff, 0xd2, 0x4a), "Y": (0xd8, 0x9a, 0x20), "w": (0xff, 0xff, 0xff),
    "g": (0x4a, 0xb0, 0x60), "G": (0x2e, 0x7a, 0x40),
    "o": (0xff, 0x9a, 0x3a), "O": (0xd0, 0x6a, 0x20),
    "s": (0xf2, 0xb9, 0x8a), "S": (0xc8, 0x80, 0x50),
    "m": (0xb4, 0xb4, 0xc4), "M": (0x72, 0x72, 0x88),
    "n": (0xff, 0x8a, 0xa0),
}

ICONS = {
    "heart": """
        .kk...kk.
        krrk.krrk
        kprrkrrrk
        kprrrrrRk
        .krrrrRk.
        ..krrRk..
        ...kRk...
        ....k....""",
    "exclaim": """
        .kkk.
        krrrk
        krrrk
        krrRk
        .krk.
        .kRk.
        ..k..
        .kkk.
        krrRk
        .kkk.""",
    "question": """
        .kkkkk.
        kbbbbbk
        kbk.kBk
        .k.kbBk
        ..kbBk.
        ..kbk..
        ...k...
        ..kkk..
        ..kbB..
        ..kkk..""",
    "dots": """
        BB.BB.BB
        BB.BB.BB""",
    "happy": """
        .k.....k.
        k.k...k.k
        .........
        nn.....nn
        ...k.k...
        ....k....""",
    "sweat": """
        ...k...
        ..kck..
        ..kck..
        .kcbbk.
        kcbbbbk
        kcbbbbk
        kbbbbBk
        .kbbBk.
        ..kkk..""",
    "sleep": """
        BBBBB....
        ...B.....
        ..B......
        .B.......
        BBBBB.BBB
        .......B.
        ......B..
        ......BBB""",
    "idea": """
        ..kkkkk..
        .kyyyyyk.
        kywyyyyYk
        kywyyyyYk
        kyyyyyyYk
        .kyyyyYk.
        ..kyyYk..
        ..kmmmk..
        ..kMMMk..
        ...kkk...""",
    "music": """
        ....kkkk
        ....kBBk
        ....kBk.
        ....kBk.
        ....kBk.
        .kkkkBk.
        kBBBBBk.
        kBBBBk..
        .kkkk...""",
    "check": """
        ........kk
        .......kGk
        ......kGk.
        kk...kGk..
        kGk.kGk...
        .kGkGk....
        ..kGk.....
        ...k......""",
    "gloom": """
        ...kkk.....
        ..kmmmkkk..
        .kmmmmmmmk.
        kmmmmmmmmMk
        kMMMMMMMMMk
        .kkkkkkkkk.
        ..c..c..c..
        .c..c..c...""",
    "sun": """
        ....o....
        .o.....o.
        ..kkkkk..
        .kyyyyyk.
        okyyyyYko
        .kyyyYYk.
        ..kkkkk..
        .o.....o.
        ....o....""",
    "wave": """
        .k.k.k...
        ksksksk..
        ksksksk.k
        ksssssskS
        kssssssSk
        ksssssSk.
        .kssSSk..
        ..kkkk...""",
    "laugh": """
        .k.....k.
        k.k...k.k
        .........
        ..kkkkk..
        ..krrrk..
        ...kkk...""",
    "anger": """
        .kk...kk.
        .krk.krk.
        ..krkrk..
        kkk...kkk
        krr...rrk
        kkk...kkk
        ..krkrk..
        .krk.krk.
        .kk...kk.""",
}

# The bubble's body (a rounded box, its corners cut a pixel or two) and its tail: rows under the body,
# each a run of pixels further left as it goes down, so the tail curves away instead of pointing.
BODY = (1, 1, 22, 17)          # left, top, right, bottom
TAIL = [(18, 6, 10), (19, 5, 8), (20, 4, 6), (21, 3, 4)]


def shape():
    """Where the bubble is filled: its body with rounded corners, and its tail."""
    mask = np.zeros((SIZE, SIZE), bool)
    left, top, right, bottom = BODY
    mask[top:bottom + 1, left:right + 1] = True
    # Each corner rounded off: its pixel and two along each side of it cleared.
    for dy, dx in ((0, 0), (0, 1), (1, 0), (0, 2), (2, 0)):
        for y, x in ((top + dy, left + dx), (top + dy, right - dx), (bottom - dy, left + dx), (bottom - dy, right - dx)):
            mask[y, x] = False
    for y, x0, x1 in TAIL:
        mask[y, x0:x1 + 1] = True
    return mask


def bubble():
    mask = shape()
    out = np.zeros((SIZE, SIZE, 4), np.uint8)
    # The outline: every clear pixel beside the filled ones (not diagonally, for a clean one-pixel line).
    edge = np.zeros_like(mask)
    edge[1:] |= mask[:-1]
    edge[:-1] |= mask[1:]
    edge[:, 1:] |= mask[:, :-1]
    edge[:, :-1] |= mask[:, 1:]
    edge &= ~mask
    out[mask] = (*FILL, 255)
    out[edge] = (*INK, 255)
    # Lit along its top and left inside the line, a shade along its bottom right.
    left, top, right, bottom = BODY
    for x in range(left + 2, right - 1):
        if mask[top + 1, x]:
            out[top + 1, x] = (*LIT, 255)
    for y in range(top + 2, bottom - 1):
        if mask[y, left + 1]:
            out[y, left + 1] = (*LIT, 255)
    for x in range(left + 2, right - 1):
        if mask[bottom - 1, x]:
            out[bottom - 1, x] = (*SHADE, 255)
    return out


def emote(name):
    out = bubble()
    rows = [line.strip() for line in ICONS[name].strip("\n").splitlines()]
    height, width = len(rows), max(len(r) for r in rows)
    left, top, right, bottom = BODY
    x0 = (left + right + 1) // 2 - width // 2
    y0 = (top + bottom + 1) // 2 - height // 2
    for y, row in enumerate(rows):
        for x, letter in enumerate(row):
            if letter in PALETTE:
                out[y0 + y, x0 + x] = (*PALETTE[letter], 255)
    return Image.fromarray(out, "RGBA")


def icon(name):
    """The picture alone, on nothing: what the game sets in its own speech bubble over someone's head
    (`Nodes.emoteBubble`), the bubble drawn here kept for the chat's picker."""
    rows = [line.strip() for line in ICONS[name].strip("\n").splitlines()]
    height, width = len(rows), max(len(r) for r in rows)
    out = np.zeros((height, width, 4), np.uint8)
    for y, row in enumerate(rows):
        for x, letter in enumerate(row):
            if letter in PALETTE:
                out[y, x] = (*PALETTE[letter], 255)
    return Image.fromarray(out, "RGBA")


def main(argv):
    sheet = None
    if "--sheet" in argv:
        i = argv.index("--sheet")
        sheet = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    made = {}
    for name in argv or list(ICONS):
        img = emote(name)
        img.save(SPRITES / f"emote_{name}.png")
        icon(name).save(SPRITES / f"emote_{name}_icon.png")
        made[name] = img
    print(f"wrote {len(made)} emotes to art/sprites/")
    if sheet:
        columns = 5
        rows = (len(made) + columns - 1) // columns
        board = Image.new("RGBA", (columns * 30, rows * 30), (88, 150, 64, 255))
        for k, img in enumerate(made.values()):
            board.alpha_composite(img, ((k % columns) * 30 + 3, (k // columns) * 30 + 3))
        board.resize((board.width * 4, board.height * 4), Image.NEAREST).save(sheet)
        print("wrote", sheet)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
