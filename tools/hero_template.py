#!/usr/bin/env python3
"""Templates for the 64-pixel hero sheets ChatGPT draws (docs/ai-sprite-test/heroes/HANDOVER.md).

For each of the nine bodies (Human, Elf, Dwarf x Male, Female, Other) and each animation (idle, walk,
run, attack) it writes, into docs/ai-sprite-test/heroes/templates/:

  guide_<body>.png / _8x.png        one 64 x 64 frame: feet row, head top, chin, centre line
  row_<body>_<anim>_8x.png          one direction row of that animation's frames at 8x, to attach
  sheet_<body>_<anim>.png / _4x.png the whole sheet (rows up, right, down, left), today's 48-pixel
                                    walk frames faded in as a pose reference where they exist
  compare_48_64.png                 today's bodies beside the new guide, to scale
  weapon_wheel.png / _8x.png        the 128 x 128 weapon canvas: grip at the middle, 8 angles

Only reads existing art; writes nothing outside the templates folder. Rerun after changing SPEC.
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "ai-sprite-test", "heroes", "templates")
SPRITES = os.path.join(ROOT, "art", "sprites")
FONT = os.path.join(ROOT, "tools", "fonts", "OpenSans-SemiCondensedExtraBold.ttf")

FRAME = 64
FEET = 60            # the row the lowest foot pixel stands on
DIRECTIONS = ["up", "right", "down", "left"]   # the engine's row order (art/assets.json player_walk)
ANIMS = {"idle": 4, "walk": 6, "run": 6, "attack": 6}
OLD_FRAME = 48

# body id: (race, gender, height in pixels, head height, today's body sheet)
SPEC = {
    "human_male":   ("Human", "Male",   46, 18, "body_human"),
    "human_female": ("Human", "Female", 44, 18, "body_human_female"),
    "human_other":  ("Human", "Other",  45, 18, "body_human_other"),
    "elf_male":     ("Elf",   "Male",   47, 18, "body_elf_male"),
    "elf_female":   ("Elf",   "Female", 45, 18, "body_elf"),
    "elf_other":    ("Elf",   "Other",  46, 18, "body_elf_other"),
    "dwarf_male":   ("Dwarf", "Male",   38, 17, "body_dwarf"),
    "dwarf_female": ("Dwarf", "Female", 36, 16, "body_dwarf_female"),
    "dwarf_other":  ("Dwarf", "Other",  37, 17, "body_dwarf_other"),
}

GRID = (200, 200, 205, 255)
FEET_C = (40, 170, 80, 255)
TOP_C = (60, 110, 230, 255)
CHIN_C = (40, 190, 210, 255)
MID_C = (225, 225, 230, 255)


def font(size):
    return ImageFont.truetype(FONT, size)


def guide(body):
    """One 64 x 64 frame of guide lines for a body (transparent elsewhere)."""
    _, _, height, head, _ = SPEC[body]
    im = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    top = FEET - height + 1
    for y in range(0, FRAME, 2):
        d.point((FRAME // 2, y), MID_C)
    for x in range(0, FRAME, 2):
        d.point((x, top), TOP_C)
        d.point((x + 1, top + head), CHIN_C)
    d.line([(0, FEET), (FRAME - 1, FEET)], FEET_C)
    d.rectangle([0, 0, FRAME - 1, FRAME - 1], outline=GRID)
    return im


def up(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def old_frames(body):
    """Today's 48-pixel frames of a body, each set in a 64 frame on the new feet row, or None."""
    path = os.path.join(SPRITES, SPEC[body][4] + ".png")
    if not os.path.exists(path):
        return None
    a = Image.open(path).convert("RGBA")
    frames = {}
    for r, direction in enumerate(DIRECTIONS):
        for c in range(4):
            f = a.crop((c * OLD_FRAME, r * OLD_FRAME, (c + 1) * OLD_FRAME, (r + 1) * OLD_FRAME))
            alpha = np.array(f)[:, :, 3]
            ys = np.nonzero(alpha)[0]
            if not len(ys):
                continue
            g = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
            g.alpha_composite(f, ((FRAME - OLD_FRAME) // 2, FEET - ys.max()))
            frames[(direction, c)] = g
    return frames


def faded(im, alpha=0.35):
    a = np.array(im).astype(float)
    a[:, :, 3] *= alpha
    return Image.fromarray(a.astype(np.uint8))


def sheet(body, anim, old):
    n = ANIMS[anim]
    im = Image.new("RGBA", (FRAME * n, FRAME * 4), (0, 0, 0, 0))
    g = guide(body)
    for r, direction in enumerate(DIRECTIONS):
        for c in range(n):
            im.alpha_composite(g, (c * FRAME, r * FRAME))
            if old and anim == "walk" and c < 4 and (direction, c) in old:
                im.alpha_composite(faded(old[(direction, c)]), (c * FRAME, r * FRAME))
            if old and anim == "idle" and c == 0 and (direction, 0) in old:
                im.alpha_composite(faded(old[(direction, 0)]), (c * FRAME, r * FRAME))
    return im


def labelled(im, k, title, columns, rows):
    """An enlarged sheet on white with frame numbers above and direction names beside it."""
    big = up(im, k)
    pad_l, pad_t = 90, 58
    out = Image.new("RGBA", (big.width + pad_l + 12, big.height + pad_t + 12), (255, 255, 255, 255))
    out.alpha_composite(big, (pad_l, pad_t))
    d = ImageDraw.Draw(out)
    d.text((pad_l, 6), title, fill=(30, 30, 40), font=font(22))
    cw = big.width // columns
    for c in range(columns):
        d.text((pad_l + c * cw + 6, 34), str(c + 1), fill=(90, 90, 100), font=font(16))
    rh = big.height // rows
    for r in range(rows):
        name = DIRECTIONS[r] if rows == 4 else ""
        d.text((8, pad_t + r * rh + rh // 2 - 10), name, fill=(90, 90, 100), font=font(16))
    return out


def row_strip(body, anim):
    n = ANIMS[anim]
    im = Image.new("RGBA", (FRAME * n, FRAME), (0, 0, 0, 0))
    g = guide(body)
    for c in range(n):
        im.alpha_composite(g, (c * FRAME, 0))
    return up(im, 8)


def compare(old_bodies):
    """Today's down-facing frame 1 of each body at 1x in a 48 frame beside the new guide."""
    k = 4
    cell = FRAME * k + 16
    out = Image.new("RGBA", (cell * len(SPEC) + 16, FRAME * k * 2 + 120), (255, 255, 255, 255))
    d = ImageDraw.Draw(out)
    d.text((16, 8), "Today: 48 x 48 frame (top)   New: 64 x 64 frame, guide lines (bottom)   both at 4x",
           fill=(30, 30, 40), font=font(20))
    for i, body in enumerate(SPEC):
        x = 16 + i * cell
        old = old_bodies.get(body)
        if old and ("down", 0) in old:
            f = old[("down", 0)].crop((8, 0, 56, 64))  # back to a 48-wide frame, feet still on row 60
            box = Image.new("RGBA", (OLD_FRAME, FRAME), (0, 0, 0, 0))
            ImageDraw.Draw(box).rectangle([0, FRAME - OLD_FRAME, OLD_FRAME - 1, FRAME - 1], outline=GRID)
            box.alpha_composite(f)
            out.alpha_composite(up(box, k), (x + (FRAME - OLD_FRAME) * k // 2, 40))
        out.alpha_composite(up(guide(body), k), (x, 50 + FRAME * k))
        race, gender, h, _, _ = SPEC[body]
        d.text((x, 60 + FRAME * k * 2), f"{race} {gender}: {h} px", fill=(30, 30, 40), font=font(18))
    return out


def weapon_wheel():
    size = 128
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = size // 2
    d.rectangle([0, 0, size - 1, size - 1], outline=GRID)
    for i in range(8):
        ang = np.radians(-90 + i * 45)  # 0 = straight up, then clockwise
        for t in range(6, 60, 2):
            d.point((round(c + t * np.cos(ang)), round(c + t * np.sin(ang))), MID_C if i % 2 else TOP_C)
    d.rectangle([c - 1, c - 1, c, c], fill=(220, 40, 40, 255))
    big = up(im, 8)
    bd = ImageDraw.Draw(big)
    for i in range(8):
        ang = np.radians(-90 + i * 45)
        bd.text((c * 8 + 470 * np.cos(ang) - 16, c * 8 + 470 * np.sin(ang) - 12), f"{i * 45}°",
                fill=(60, 60, 80, 255), font=font(22))
    return im, big


def main():
    os.makedirs(OUT, exist_ok=True)
    olds = {b: old_frames(b) for b in SPEC}
    for body in SPEC:
        g = guide(body)
        g.save(os.path.join(OUT, f"guide_{body}.png"))
        up(g, 8).save(os.path.join(OUT, f"guide_{body}_8x.png"))
        for anim, n in ANIMS.items():
            row_strip(body, anim).save(os.path.join(OUT, f"row_{body}_{anim}_8x.png"))
            s = sheet(body, anim, olds[body])
            s.save(os.path.join(OUT, f"sheet_{body}_{anim}.png"))
            race, gender = SPEC[body][:2]
            labelled(s, 4, f"{race} {gender}: {anim}, {n} frames x 4 directions, 64 x 64",
                     n, 4).save(os.path.join(OUT, f"sheet_{body}_{anim}_4x.png"))
    compare(olds).save(os.path.join(OUT, "compare_48_64.png"))
    w, wb = weapon_wheel()
    w.save(os.path.join(OUT, "weapon_wheel.png"))
    wb.save(os.path.join(OUT, "weapon_wheel_8x.png"))
    print(f"wrote {len(os.listdir(OUT))} files to {os.path.relpath(OUT, ROOT)}")


if __name__ == "__main__":
    main()
