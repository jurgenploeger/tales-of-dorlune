"""Armour sheets fitted to each body: a sheet per body whose head a race's own sheet doesn't reach.

A race's armour sheet (`armor_<kind>_<race>`, items.json `sheets`) is worn by all three of its bodies,
under each body's own head (`head_<body>`). A body whose head sits higher in a frame than the sheet's
collar showed rows of bare neck between chin and collar (`neck_<body>`): four on the human other facing
you on its first step, three on the elf other from behind, two on the human man facing you (the user,
2026-11-10: "The characters should have better fit when wearing armor").

What doesn't fix it, both tried: moving the frame up to the head lifts the feet off the ground on that
step (every armour frame stands on the same row as the body's, measured over all 16 frames of every
body and sheet); raising only the collar leaves a tall block of the collar's dark inside under the chin.

What does: the armour a little taller in that frame, as that body is. Where a body's head ends more
than BARE rows above the collar under it, the frame grows by the rows over that, between the collar and
the hands, by drawing some of its rows twice: the ones most like the row under them (a row of plain
plate or cloth, never a belt's edge), so the shoulders rise to the head and nothing below the hands
moves: feet, legs and hands stay where gloves and boots are painted (tools/worn_marks.py). The sheet's
trim layer (`<sheet>_trim`, tools/dye_art.py) grows by the same rows.

Each body that needs it gets every sheet of its race as `<sheet>_fit_<body>.png` (and that with
`_trim`: the name still starts armor_, as what tells an armour's own face from the hero's does), and is
listed in classes.json (a race's `fitted`), which GameSession.layers and tools/gear_preview.py read. A
race's own sheets aren't touched, so a rerun makes the same files.

    python3 tools/armour_fit.py                 # write the fitted sheets and classes.json's lists
    python3 tools/armour_fit.py --report        # every body and frame: rows of bare neck, before and after
    python3 tools/armour_fit.py --sheet out.png # each frame that changes, before (top) and after

Rerun after tools/wear_art.py, tools/hero_layers.py or tools/dye_art.py cut changes a sheet, a head or
a trim. Needs pillow + numpy.
"""
import argparse
import json
import pathlib
import re

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPRITES = ROOT / "art" / "sprites"
CLASSES = ROOT / "content" / "classes.json"
F = 48
DIRS = ["up", "right", "down", "left"]
# The collar under a head: the sheet's first row in this many columns either side of the head's middle.
HALF = 2
# Rows of bare neck a frame may show, as most do: one reads as a neck, two and more as a head on a pole.
BARE = 1
# Where no hands are marked in a frame, or they're up by the collar, the rows that may be drawn twice end
# this far down the sheet's figure.
CHEST = 0.6


def load(name):
    return np.asarray(Image.open(SPRITES / f"{name}.png").convert("RGBA")).copy()


def races():
    return json.load(open(CLASSES))["races"]


def bodies(race):
    """A race's bodies' ids (tools/hero_layers.py): its own, then each gender sheet's."""
    return [race["id"]] + [f"{race['id']}_{gender}" for gender in (race.get("sheets") or {})]


def sheets():
    """Every armour sheet worn on a race's poses, by race: items.json `sheets`."""
    found = {}
    for item in json.load(open(ROOT / "content" / "items.json"))["items"]:
        for race, sheet in (item.get("sheets") or {}).items():
            found.setdefault(race, set()).add(sheet)
    return {race: sorted(names) for race, names in found.items()}


def frame(a, row, col):
    return a[row * F:(row + 1) * F, col * F:(col + 1) * F]


def bare(sheet, head):
    """Rows of bare neck between a head frame's last row and the collar under its middle, and that
    collar's row."""
    solid = head[..., 3] > 127
    rows = np.nonzero(solid.any(1))[0]
    if len(rows) == 0:
        return 0, None
    low = int(rows[-1])
    cols = np.nonzero(solid[max(0, low - 2):low + 1].any(0))[0]
    cx = int(round((cols[0] + cols[-1]) / 2))
    under = np.nonzero((sheet[:, max(0, cx - HALF):cx + HALF + 1, 3] > 127).any(1))[0]
    if len(under) == 0:
        return 0, None
    return max(0, int(under[0]) - low - 1), int(under[0])


def hands(marks):
    """The first row of a marks frame with a glove on it (red: tools/worn_marks.py), or None."""
    glove = (marks[..., 3] > 127) & (marks[..., 0] > marks[..., 2])
    rows = np.nonzero(glove.any(1))[0]
    return int(rows[0]) if len(rows) else None


def taller(sheet, collar, stop, rows):
    """Which rows of a sheet frame to draw twice to make it `rows` taller between `collar` and `stop`:
    each time the row least unlike the one under it (so a plain stretch of plate or cloth, not an edge),
    never one already drawn twice nor its neighbour. Returned from the top, in the frame as it was."""
    a = sheet.astype(int)
    cost = {y: int(np.abs(a[y] - a[y + 1]).sum()) for y in range(collar + 1, stop)
            if (sheet[y, :, 3] > 127).any() and (sheet[y + 1, :, 3] > 127).any()}
    picked = []
    for _ in range(rows):
        free = [y for y in cost if all(abs(y - p) > 1 for p in picked)] or [y for y in cost if y not in picked]
        if not free:
            break
        picked.append(min(free, key=lambda y: (cost[y], -y)))
    return sorted(picked)


def grown(image, picked):
    """A frame with its `picked` rows drawn twice: everything over each moves up a row."""
    out = image.copy()
    for done, y in enumerate(picked):
        y -= done   # the rows over it have already moved up
        out[:y] = out[1:y + 1]
    return out


def plan(race):
    """For each of a race's bodies, the rows to draw twice in each frame: {body: {(row, col): [rows]}},
    the same for every sheet of the race (they're all cut at the same collar), measured on its first."""
    names = sheets().get(race["id"], [])
    if not names:
        return {}
    sheet, marks = load(names[0]), load(f"marks_{race['id']}")
    found = {}
    for body in bodies(race):
        head = load(f"head_{body}")
        frames = {}
        for row in range(sheet.shape[0] // F):
            for col in range(sheet.shape[1] // F):
                f = frame(sheet, row, col)
                rows, collar = bare(f, frame(head, row, col))
                if rows <= BARE:
                    continue
                solid = np.nonzero((f[..., 3] > 127).any(1))[0]
                chest = int(solid[0] + CHEST * (solid[-1] - solid[0]))
                hand = hands(frame(marks, row, col))
                # Over the hands where there's room; on a step with a hand up by the chest, down to the
                # chest (the glove then sits a row or two low on that one step).
                stop = hand - 1 if hand is not None else chest
                picked = taller(f, collar, stop, rows - BARE)
                if len(picked) < rows - BARE:
                    picked = taller(f, collar, max(stop, chest), rows - BARE)
                if picked:
                    frames[(row, col)] = picked
        if frames:
            found[body] = frames
    return found


def fitted(name, frames):
    """A sheet (or its trim layer) with each of `frames` grown by its rows."""
    out = load(name)
    for (row, col), picked in frames.items():
        frame(out, row, col)[:] = grown(frame(out, row, col), picked)
    return out


def write_classes(lists):
    """Each race's `fitted` in classes.json: the bodies with fitted sheets, written where it was or after
    `sheets`, the file's layout kept."""
    text = CLASSES.read_text()
    text = re.sub(r',\n\s*"fitted": \[[^\]]*\]', "", text)
    for race_id, fit in lists.items():
        if not fit:
            continue
        match = re.search(r'"id": "%s",.*?"sheets": \{[^}]*\}' % re.escape(race_id), text, re.S)
        indent = re.search(r'\n(\s*)"sheets"', match.group(0)).group(1)
        text = text[:match.end()] + f',\n{indent}"fitted": {json.dumps(fit)}' + text[match.end():]
    CLASSES.write_text(text)


def build(write=True):
    plans = {race["id"]: plan(race) for race in races()}
    by_race = sheets()
    made = []
    if write:
        for old in SPRITES.glob("armor_*_fit_*.png"):
            old.unlink()
    for race_id, found in plans.items():
        for body, frames in found.items():
            for name in by_race[race_id]:
                for layer, to in ((name, f"{name}_fit_{body}"), (name + "_trim", f"{name}_fit_{body}_trim")):
                    if not (SPRITES / f"{layer}.png").exists():
                        continue
                    if write:
                        Image.fromarray(fitted(layer, frames), "RGBA").save(SPRITES / f"{to}.png")
                    made.append(to)
    if write:
        write_classes({race_id: list(found) for race_id, found in plans.items()})
    return plans, made


def report():
    by_race = sheets()
    for race in races():
        names = by_race.get(race["id"], [])
        if not names:
            continue
        frames = plan(race)
        for body in bodies(race):
            head = load(f"head_{body}")
            before, after = load(names[0]), fitted(names[0], frames.get(body, {}))
            shown = []
            for row in range(4):
                for col in range(4):
                    was = bare(frame(before, row, col), frame(head, row, col))[0]
                    now = bare(frame(after, row, col), frame(head, row, col))[0]
                    if was:
                        shown.append(f"{DIRS[row]} {col}: {was}" + (f" to {now}" if now != was else ""))
            print(f"{body:14s} {', '.join(shown) or 'none'}")


def contact(out):
    """Each frame that changes, on every sheet of its race, with the body's neck and head: as it was
    (top) and fitted."""
    plans, _ = build(write=False)
    by_race = sheets()
    cells = [(race_id, body, row, col) for race_id, found in plans.items() for body, frames in found.items()
             for (row, col) in frames]
    zoom, pad = 5, 8
    width = max((len(by_race[race_id]) for race_id, _, _, _ in cells), default=1)
    sheet = Image.new("RGB", (width * F * zoom, len(cells) * (2 * F * zoom + pad)), (128, 128, 128))
    for k, (race_id, body, row, col) in enumerate(cells):
        for i, name in enumerate(by_race[race_id]):
            for half, source in enumerate((load(name), fitted(name, plans[race_id][body]))):
                stack = Image.fromarray(np.ascontiguousarray(frame(load(f"neck_{body}"), row, col)), "RGBA")
                stack.alpha_composite(Image.fromarray(np.ascontiguousarray(frame(source, row, col)), "RGBA"))
                stack.alpha_composite(Image.fromarray(np.ascontiguousarray(frame(load(f"head_{body}"), row, col)), "RGBA"))
                shown = stack.resize((F * zoom, F * zoom), Image.NEAREST)
                sheet.paste(shown, (i * F * zoom, k * (2 * F * zoom + pad) + half * F * zoom), shown)
    sheet.save(out)
    print(f"wrote {out}: " + "; ".join(f"{body} {DIRS[row]} {col}" for _, body, row, col in cells))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--report", action="store_true", help="rows of bare neck on every body and frame")
    parser.add_argument("--sheet", help="write a before and after contact sheet here, and nothing else")
    args = parser.parse_args()
    if args.report:
        report()
        return
    if args.sheet:
        contact(args.sheet)
        return
    plans, made = build()
    for race_id, found in plans.items():
        for body, frames in found.items():
            print(f"{body}: " + ", ".join(f"{DIRS[row]} {col} +{len(picked)}" for (row, col), picked in frames.items()))
    print(f"wrote {len(made)} fitted sheet(s) and trim(s) to art/sprites/, and each race's `fitted` in classes.json")


if __name__ == "__main__":
    main()
