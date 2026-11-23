#!/usr/bin/env python3
"""Templates for the 64-pixel hero sheets ChatGPT draws (docs/ai-sprite-test/heroes/HANDOVER.md).

For each of the nine bodies (Human, Elf, Dwarf x Male, Female, Other) and each animation (idle, walk,
run, attack) it writes, into docs/ai-sprite-test/heroes/templates/:

  guide_<body>.png / _8x.png        one 64 x 64 frame: feet row, head top, chin, centre line
  row_<body>_<anim>_8x.png          one direction row of that animation's frames at 8x, to attach
  sheet_<body>_<anim>.png / _4x.png the whole sheet (8 rows, clockwise from up), today's 48-pixel
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
OLD_DIRECTIONS = ["up", "right", "down", "left"]   # today's 48-pixel sheets' rows (art/assets.json player_walk)
# Eight directions, clockwise from up (the user, 2026-11-23). ChatGPT draws up to down along the right side;
# down-left, left and up-left are the right side mirrored for the body and hair.
DIRECTIONS = ["up", "up-right", "right", "down-right", "down", "down-left", "left", "up-left"]
DRAWN = ["up", "up-right", "right", "down-right", "down"]
ANIMS = {"idle": 4, "walk": 6, "run": 6, "attack": 6}
OLD_FRAME = 48

# The LPC paper-doll standard's frame (64 x 64, feet near the bottom, body about 48 tall), semi-chibi: about
# three heads tall, the shoulders about as wide as the head (the user's pick, 2026-11-23, after ChatGPT's tries 1
# to 5 in docs/ai-sprite-test/heroes/tries: a 2.4-head chibi read as a toddler, broad shoulders as a bodybuilder).
# body id: (race, gender, height, head, chest width, limb width, legs from shorts to soles, foot width, sheet today)
SPEC = {
    "human_male":   ("Human", "Male",   48, 16, 14, 5, 15, 6, "body_human"),
    "human_female": ("Human", "Female", 46, 16, 13, 4, 14, 5, "body_human_female"),
    "human_other":  ("Human", "Other",  47, 16, 13, 5, 15, 6, "body_human_other"),
    "elf_male":     ("Elf",   "Male",   48, 16, 13, 4, 16, 5, "body_elf_male"),
    "elf_female":   ("Elf",   "Female", 46, 16, 12, 4, 15, 5, "body_elf"),
    "elf_other":    ("Elf",   "Other",  47, 16, 12, 4, 15, 5, "body_elf_other"),
    "dwarf_male":   ("Dwarf", "Male",   40, 15, 16, 6, 9, 7, "body_dwarf"),
    "dwarf_female": ("Dwarf", "Female", 38, 14, 15, 5, 9, 7, "body_dwarf_female"),
    "dwarf_other":  ("Dwarf", "Other",  39, 15, 15, 6, 9, 7, "body_dwarf_other"),
}

GRID = (200, 200, 205, 255)
FEET_C = (40, 170, 80, 255)
TOP_C = (60, 110, 230, 255)
CHIN_C = (40, 190, 210, 255)
MID_C = (225, 225, 230, 255)
LEGS_C = (235, 140, 40, 255)
CHEST_C = (200, 90, 200, 255)


def font(size):
    return ImageFont.truetype(FONT, size)


def guide(body):
    """One 64 x 64 frame of guide lines for a body (transparent elsewhere)."""
    _, _, height, head, chest, _, legs, _, _ = SPEC[body]
    im = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    top = FEET - height + 1
    leg_top = FEET - legs                   # the shorts' hem
    for x in range(0, FRAME, 3):
        d.point((x, leg_top), LEGS_C)
    cy = top + head + 4                     # chest width ticks, a little under the chin
    for x in (FRAME // 2 - chest // 2, FRAME // 2 - chest // 2 + chest - 1):
        d.line([(x, cy - 1), (x, cy + 1)], CHEST_C)
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
    path = os.path.join(SPRITES, SPEC[body][-1] + ".png")
    if not os.path.exists(path):
        return None
    a = Image.open(path).convert("RGBA")
    frames = {}
    for r, direction in enumerate(OLD_DIRECTIONS):
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
    im = Image.new("RGBA", (FRAME * n, FRAME * len(DIRECTIONS)), (0, 0, 0, 0))
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
    pad_l, pad_t = 170, 58
    out = Image.new("RGBA", (big.width + pad_l + 12, big.height + pad_t + 12), (255, 255, 255, 255))
    out.alpha_composite(big, (pad_l, pad_t))
    d = ImageDraw.Draw(out)
    d.text((pad_l, 6), title, fill=(30, 30, 40), font=font(22))
    cw = big.width // columns
    for c in range(columns):
        d.text((pad_l + c * cw + 6, 34), str(c + 1), fill=(90, 90, 100), font=font(16))
    rh = big.height // rows
    for r in range(rows):
        name = DIRECTIONS[r] + ("" if DIRECTIONS[r] in DRAWN else " (mirror)") if rows == len(DIRECTIONS) else ""
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
        race, gender, h = SPEC[body][:3]
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


# --- the size board: how big a hero can be beside the world, and how much room armour gets ---------------

TRIES = os.path.join(ROOT, "docs", "ai-sprite-test", "heroes", "tries")
# name: (height, head, torso width, limb width, leg length, foot width)
BUILDS = {b: (v[2], v[3], v[4], v[5], v[6], v[7]) for b, v in SPEC.items()
          if b in ("human_male", "elf_female", "dwarf_male")}
SKIN = [(236, 204, 176), (214, 178, 150), (178, 140, 118), (96, 66, 60)]      # light, mid, shade, outline
SHORTS = [(150, 144, 140), (122, 116, 114), (96, 90, 90), (58, 52, 56)]
STEEL = [(176, 196, 222), (130, 154, 190), (92, 112, 150), (40, 48, 78)]
LEATHER = [(176, 120, 76), (140, 90, 56), (106, 64, 42), (58, 34, 26)]
GOLD = [(255, 220, 110), (230, 170, 50), (180, 120, 30), (96, 60, 20)]


def mannequin(build, armour=False):
    """A plain front-facing figure drawn in code: grey-free skin doll, feet on the canvas's last row."""
    H, head, tw, lw, legs, fw = BUILDS[build]
    W = max(tw + 2 * lw + 12, head + 12)
    parts = np.zeros((H + 8, W), np.int8)      # 0 clear, 1 skin, 2 shorts, 3 steel, 4 leather, 5 gold
    cx = W // 2
    top = 8                                     # headroom for a helmet
    def box(x0, y0, x1, y1, v):
        parts[max(y0, 0):y1, max(x0, 0):x1] = v
    def ellipse(x0, y0, x1, y1, v):
        yy, xx = np.mgrid[0:parts.shape[0], 0:W]
        a, b = (x1 - x0) / 2, (y1 - y0) / 2
        m = ((xx + .5 - (x0 + a)) / a) ** 2 + ((yy + .5 - (y0 + b)) / b) ** 2 <= 1
        parts[m] = v
    hw = round(head * 1.08)
    neck = 2
    torso = H - head - neck - legs
    y_neck, y_torso = top + head, top + head + neck
    y_legs = y_torso + torso
    # legs and feet
    gap = 1 if lw < 6 else 2
    lx = cx - gap // 2 - lw if gap % 2 == 0 else cx - lw
    rx = cx + (gap - gap // 2)
    box(lx, y_legs, lx + lw, top + H, 1)
    box(rx, y_legs, rx + lw, top + H, 1)
    box(lx + lw - fw, top + H - 2, lx + lw, top + H, 1)
    box(rx, top + H - 2, rx + fw, top + H, 1)
    # torso, neck, arms
    box(cx - tw // 2, y_torso, cx - tw // 2 + tw, y_legs, 1)
    box(cx - max(3, tw // 4), y_neck, cx + max(3, tw // 4), y_torso + 1, 1)
    arm = torso + lw // 2 + 1
    box(cx - tw // 2 - 1 - lw, y_torso + 1, cx - tw // 2 - 1, y_torso + 1 + arm, 1)
    box(cx + tw - tw // 2 + 1, y_torso + 1, cx + tw - tw // 2 + 1 + lw, y_torso + 1 + arm, 1)
    # shorts: lower third of the torso and the top of the legs
    sy = y_legs - max(3, torso // 3)
    box(cx - tw // 2, sy, cx - tw // 2 + tw, y_legs + max(2, legs // 4), 2)
    parts[y_legs:y_legs + max(2, legs // 4), cx - gap // 2:cx + (gap - gap // 2)] = 0
    ellipse(cx - hw / 2, top, cx + hw / 2, top + head, 1)
    if armour:
        box(cx - tw // 2, y_torso, cx - tw // 2 + tw, sy + 1, 3)                       # chest plate
        box(cx - tw // 2, sy, cx - tw // 2 + tw, sy + 2, 4)                            # belt
        parts[sy:sy + 2, cx - 1:cx + 1] = 5                                            # buckle
        pw = lw + 4
        ellipse(cx - tw / 2 - pw + 1, y_torso - 1, cx - tw / 2 + 3, y_torso + lw + 2, 3)  # pauldrons
        ellipse(cx + tw / 2 - 3, y_torso - 1, cx + tw / 2 + pw - 1, y_torso + lw + 2, 3)
        for x0 in (cx - tw // 2 - 1 - lw, cx + tw - tw // 2 + 1):                      # gloves
            box(x0, y_torso + 1 + arm - lw - 1, x0 + lw, y_torso + 1 + arm, 4)
        bh = max(4, legs // 2)                                                         # boots
        box(lx - 1, top + H - bh, lx + lw + 1, top + H, 4)
        box(rx - 1, top + H - bh, rx + lw + 1, top + H, 4)
        box(lx + lw - fw - 1, top + H - 3, lx + lw, top + H, 4)
        box(rx, top + H - 3, rx + fw + 1, top + H, 4)
        ellipse(cx - hw / 2 - 2, top - 3, cx + hw / 2 + 2, top + head * 0.75, 3)       # helmet
        box(cx - hw // 2 - 2, top + round(head * .42), cx + hw // 2 + 3, top + round(head * .42) + 2, 3)
        parts[top + round(head * .42) + 2:top + round(head * .75) + 1, cx - hw // 2 + 2:cx + hw // 2 - 1] = \
            np.where(parts[top + round(head * .42) + 2:top + round(head * .75) + 1, cx - hw // 2 + 2:cx + hw // 2 - 1] == 3,
                     1, parts[top + round(head * .42) + 2:top + round(head * .75) + 1, cx - hw // 2 + 2:cx + hw // 2 - 1])
        parts[y_torso + 2:y_torso + 5, cx - 1:cx + 1] = 5                              # pendant
    ramps = {1: SKIN, 2: SHORTS, 3: STEEL, 4: LEATHER, 5: GOLD}
    out = np.zeros(parts.shape + (4,), np.uint8)
    h_, w_ = parts.shape
    for y in range(h_):
        for x in range(w_):
            v = parts[y, x]
            if not v:
                continue
            r = ramps[v]
            near = [parts[y + dy, x + dx] if 0 <= y + dy < h_ and 0 <= x + dx < w_ else 0
                    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1))]
            if 0 in near:
                c = r[3]                                   # outline, a deep shade of its own part
            elif any(n != v and n < v for n in near) or any(n != v for n in near):
                c = r[2]                                   # an inner line where parts meet
            else:
                # lit from the top left: lighter in the left third, shade in the right third
                xs = np.nonzero(parts[y] == v)[0]
                t = (x - xs.min()) / max(1, xs.max() - xs.min())
                c = r[0] if t < .34 else r[1] if t < .72 else r[2]
            out[y, x] = c + (255,)
    # eyes
    if True:
        ey = top + round(head * .55)
        for ex in (cx - round(hw * .22) - 1, cx + round(hw * .22) - 1):
            ew = 2 if head < 22 else 3
            if parts[ey, ex] == 1:
                out[ey:ey + ew + 1, ex:ex + ew] = (60, 40, 50, 255)
                out[ey, ex] = (255, 255, 255, 255)
    return Image.fromarray(out)


def trimmed(im):
    a = np.array(im.convert("RGBA"))
    ys, xs = np.nonzero(a[:, :, 3])
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def chatgpt_big(path, cell=12.8):
    """ChatGPT's painted 'pixel art': each cell's middle colour, so it shows at the size it was drawn."""
    im = Image.open(path).convert("RGBA")
    a = np.array(im).astype(int)
    bg = a[4, 4, :3]
    n = round(im.width / cell)
    out = np.zeros((n, n, 4), np.uint8)
    for j in range(n):
        for i in range(n):
            p = a[min(im.height - 1, int((j + .5) * cell)), min(im.width - 1, int((i + .5) * cell))]
            if np.abs(p[:3] - bg).sum() > 40 and p[3] > 128:
                out[j, i] = p[:3].tolist() + [255]
    return Image.fromarray(out)


def asset_scale(name):
    import json
    assets = json.load(open(os.path.join(ROOT, "art", "assets.json")))["assets"]
    entry = next((a for a in assets if a.get("id") == name), {})
    return entry.get("scale", 1)


def world_piece(name):
    im = trimmed(Image.open(os.path.join(SPRITES, name + ".png")).convert("RGBA"))
    s = asset_scale(name)
    if s != 1:
        im = im.resize((round(im.width * s), round(im.height * s)), Image.NEAREST)
    return im


def board():
    """Everything side by side at game size (1 art pixel = 1 point), feet on one line, on grass."""
    pieces = []
    hero = old_frames("human_male")[("down", 0)]
    pieces.append(("hero today", trimmed(hero)))
    for b in BUILDS:
        name = " ".join(SPEC[b][:2])
        pieces.append((name, trimmed(mannequin(b))))
        pieces.append((name + "\n+ armour", trimmed(mannequin(b, True))))
    tries = [("ChatGPT 1", "try1_human_male.png", None), ("ChatGPT 2", "try2_human_male_big.png", "big"),
             ("ChatGPT 3", "try3_human_male.png", None), ("ChatGPT 4", "try4_human_male.png", None), ("ChatGPT 5", "try5_human_male.png", None)]
    for label, f, kind in tries:
        p = os.path.join(TRIES, f)
        if os.path.exists(p):
            pieces.append((label, trimmed(chatgpt_big(p) if kind else Image.open(p).convert("RGBA"))))
    for name, label in (("monster_jelly", "jelly"), ("town_gate", "town gate"), ("tree", "tree"),
                        ("house", "house"), ("inn", "inn")):
        pieces.append((label, world_piece(name)))
    gap = 10
    width = sum(p.width for _, p in pieces) + gap * (len(pieces) + 1)
    tall = max(p.height for _, p in pieces)
    ground = 14
    im = Image.new("RGBA", (width, tall + 24 + ground), (0, 0, 0, 0))
    grass = Image.open(os.path.join(SPRITES, "tile_grass.png")).convert("RGBA")
    for x in range(0, im.width, grass.width):
        for y in range(0, im.height, grass.height):
            im.alpha_composite(grass, (x, y))
    base = 24 + tall
    x = gap
    spots = []
    for label, p in pieces:
        im.alpha_composite(p, (x, base - p.height))
        spots.append((label, x, p.width, p.height))
        x += p.width + gap
    k = 3
    big = im.resize((im.width * k, im.height * k), Image.NEAREST)
    pad = 64
    out = Image.new("RGBA", (big.width, big.height + pad), (255, 255, 255, 255))
    out.alpha_composite(big)
    d = ImageDraw.Draw(out)
    for label, x0, w, h in spots:
        txt = label + f"\n{h} pt"
        d.multiline_text((x0 * k, big.height + 6), txt, fill=(30, 30, 40), font=font(15), spacing=2)
    d.line([(0, base * k), (big.width, base * k)], fill=(255, 255, 255, 90), width=1)
    return im, out


def main():
    import sys
    if "--board" in sys.argv:
        os.makedirs(OUT, exist_ok=True)
        im, big = board()
        im.save(os.path.join(OUT, "size_board.png"))
        big.save(os.path.join(OUT, "size_board_3x.png"))
        print("wrote size_board.png and size_board_3x.png")
        return
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
            labelled(s, 4, f"{race} {gender}: {anim}, {n} frames x 8 directions, 64 x 64",
                     n, len(DIRECTIONS)).save(os.path.join(OUT, f"sheet_{body}_{anim}_4x.png"))
    compare(olds).save(os.path.join(OUT, "compare_48_64.png"))
    w, wb = weapon_wheel()
    w.save(os.path.join(OUT, "weapon_wheel.png"))
    wb.save(os.path.join(OUT, "weapon_wheel_8x.png"))
    print(f"wrote {len(os.listdir(OUT))} files to {os.path.relpath(OUT, ROOT)}")


if __name__ == "__main__":
    main()
