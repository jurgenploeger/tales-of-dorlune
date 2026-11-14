#!/usr/bin/env python3
"""Blind review: is the art we draw in code as good as Retro Diffusion's? The user picks, not knowing which.

The goal (the user, 2026-11-14): draw pixel art in code as good as Retro Diffusion's, so new art needn't
come from it. "As good as" is the user's verdict, judged blind, kind by kind
(.claude/skills/sprite-creation, *Drawing as well as Retro Diffusion*). Each row pairs a sprite drawn in
code with one of Retro Diffusion's of the same kind and nearest size, sides shuffled, labelled only A and
B, at 1x and 4x on the map's green. The answer key goes to a file of its own; don't open it or show it
before the answers are in.

  blind_review.py sheet OUT.png [--kind building|prop] [--pairs 8] [--seed N]
        the sheet, and OUT.key.json beside it (which side was code)
  blind_review.py score OUT.key.json ANSWERS
        ANSWERS: the user's pick per row, in order, A, B or = for "can't tell / as good" (e.g. "AB=BA=AB").
        Prints how often the code drawing was picked or tied, which rows it lost, and which won.

Code wins a kind when, over 16 rows or more, it's picked or tied in at least half. Record each round's
result in the skill's table, with its date and seed. Run from the repo root; needs Pillow.
"""
import argparse
import json
import os
import random
import re
import sys

from PIL import Image, ImageDraw

ROOT = os.getcwd()
SPRITES = os.path.join(ROOT, "art", "sprites")
ASSETS = json.load(open(os.path.join(ROOT, "art", "assets.json")))["assets"]
TOOLS = "".join(open(os.path.join(ROOT, "tools", f)).read() for f in os.listdir(os.path.join(ROOT, "tools")) if f.endswith("_art.py"))
KINDS = ("building", "prop")


def drawn_in_code(a):
    """Its own PNG, made by a tools/*_art.py: no Retro Diffusion `request`, or a tool that draws it by name."""
    i = a["id"]
    if not a.get("request"):
        return True
    return bool(re.search(r"""["']%s["']\s*:\s*\w*draw""" % re.escape(i), TOOLS) or re.search(r"def draw_%s\b" % re.escape(i), TOOLS))


def pools(kind):
    code, rd = [], []
    for a in ASSETS:
        path = os.path.join(SPRITES, a["id"] + ".png")
        if a["kind"] != kind or not os.path.exists(path):
            continue
        im = Image.open(path)
        (code if drawn_in_code(a) else rd).append((a["id"], im.size))
    return code, rd


def sheet(out, kind, pairs, seed):
    rng = random.Random(seed)
    code, rd = pools(kind)
    if not code or not rd:
        sys.exit(f"no {kind}s drawn both ways to compare")
    picks = rng.sample(code, min(pairs, len(code)))
    rows, key = [], []
    used = set()
    for cid, csize in picks:
        # Retro Diffusion's of the nearest size, not used yet in this sheet, picked at random among the closest.
        ranked = sorted((r for r in rd if r[0] not in used), key=lambda r: abs(r[1][0] * r[1][1] - csize[0] * csize[1]))
        if not ranked:
            break
        rid = rng.choice(ranked[:4])[0]
        used.add(rid)
        code_left = rng.random() < 0.5
        left, right = (cid, rid) if code_left else (rid, cid)
        rows.append((left, right))
        key.append({"row": len(rows), "A": left, "B": right, "code": "A" if code_left else "B"})
    z = 4
    images = [[Image.open(os.path.join(SPRITES, i + ".png")).convert("RGBA") for i in row] for row in rows]
    cw = max(im.width for row in images for im in row)
    ch = max(im.height for row in images for im in row)
    panel = cw * (z + 1) + 30
    width = 60 + 2 * panel
    height = len(rows) * (ch * z + 24) + 10
    canvas = Image.new("RGBA", (width, height), (112, 160, 88, 255))
    d = ImageDraw.Draw(canvas)
    for r, row in enumerate(images):
        y = 10 + r * (ch * z + 24)
        d.text((8, y + 4), str(r + 1), fill=(255, 255, 255, 255))
        for s, im in enumerate(row):
            x = 40 + s * panel
            d.text((x, y), "AB"[s], fill=(255, 255, 255, 255))
            canvas.alpha_composite(im, (x, y + 14 + ch - im.height))
            big = im.resize((im.width * z, im.height * z), Image.NEAREST)
            canvas.alpha_composite(big, (x + cw + 10, y + 14 + ch * z - big.height))
    canvas.save(out)
    keyfile = os.path.splitext(out)[0] + ".key.json"
    json.dump({"kind": kind, "seed": seed, "rows": key}, open(keyfile, "w"), indent=1)
    print(f"wrote {out} ({len(rows)} rows of {kind}s) and its key, {keyfile}: don't open the key till the answers are in")


def score(keyfile, answers):
    key = json.load(open(keyfile))
    rows = key["rows"]
    answers = answers.strip().upper()
    if len(answers) != len(rows) or set(answers) - set("AB="):
        sys.exit(f"want {len(rows)} answers, each A, B or =")
    won = tied = 0
    for row, pick in zip(rows, answers):
        code, other = row[row["code"]], row["B" if row["code"] == "A" else "A"]
        if pick == "=":
            tied += 1
            verdict = "tie"
        elif pick == row["code"]:
            won += 1
            verdict = "code picked"
        else:
            verdict = "Retro Diffusion picked"
        print(f"{row['row']:>2}. code {code} vs RD {other}: {verdict}")
    n = len(rows)
    share = (won + tied) / n
    print(f"\n{key['kind']}s, seed {key['seed']}: code picked {won}, tied {tied}, lost {n - won - tied} of {n}: "
          f"picked or tied {share:.0%} ({'as good, on this round' if share >= 0.5 else 'not yet'})")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("sheet")
    p.add_argument("out")
    p.add_argument("--kind", choices=KINDS, default="building")
    p.add_argument("--pairs", type=int, default=8)
    p.add_argument("--seed", type=int, default=None)
    p = sub.add_parser("score")
    p.add_argument("key")
    p.add_argument("answers")
    a = ap.parse_args()
    if a.cmd == "sheet":
        seed = a.seed if a.seed is not None else random.randrange(1 << 30)
        return sheet(a.out, a.kind, a.pairs, seed)
    return score(a.key, a.answers)


if __name__ == "__main__":
    main()
