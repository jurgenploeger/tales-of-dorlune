#!/usr/bin/env python3
"""The elf: the doll's sheets with the ears layer fitted to every frame.

  hero_ears.py        -> hero64_elf_<anim>.png (+ _4x) and hero64_elf_<anim>.gif for idle, walk, attack, and the run

One doll for both races (the user, 2026-11-24); an Elf is the doll with ears (hero64_doll_ears_<direction>.png,
drawn on that direction's standing view). In each frame the head is found by sliding the standing view's head over
it (a few pixels each way, the best match of colours; the top row alone fails where a fist is raised past the head),
and the ears go on moved by as much. A left view uses its right twin's ears mirrored. Rows with no ears drawn yet stay
the plain doll."""
import os
import numpy as np
from PIL import Image
import hero_template as t
import hero_idle as hi

HEROES = hi.HEROES
HEAD = (13, 37)     # the rows the head (and ears) span in a standing view


def standing(d):
    name = "hero64_doll_master.png" if d == "down" else f"hero64_doll_{d}.png"
    p = os.path.join(HEROES, name)
    return np.asarray(Image.open(p).convert("RGBA")) if os.path.exists(p) else None


def ears(d):
    p = os.path.join(HEROES, f"hero64_doll_ears_{d}.png")
    return np.asarray(Image.open(p).convert("RGBA")) if os.path.exists(p) else None


def view(d):
    """(standing view, ears) for a direction, a left one mirrored from its right twin; None without ears."""
    if d.endswith("left"):
        r = view(d[:-4] + "right")
        return None if r is None else (r[0][:, ::-1], r[1][:, ::-1])
    s, e = standing(d), ears(d)
    return None if s is None or e is None else (s, e)


def fit(frame, ref):
    """How far the head moved from the standing view: the shift where the most head pixels match."""
    y0, y1 = HEAD
    head = ref[y0:y1]
    best, at = -1, (0, 0)
    for dy in range(-5, 6):
        for dx in range(-5, 6):
            f = frame[y0 + dy:y1 + dy, max(dx, 0):64 + min(dx, 0)]
            h = head[:, max(-dx, 0):64 - max(dx, 0)]
            if f.shape != h.shape:
                continue
            solid = h[..., 3] > 0
            score = (solid & (f[..., 3] > 0) & (np.abs(f[..., :3].astype(int) - h[..., :3]).sum(2) == 0)).sum()
            if score > best:
                best, at = score, (dy, dx)
    return at


def wear(frame, ear, shift, ref):
    """The ears moved with the head, over clear pixels and over the head wherever the standing view has it (the
    frames' heads are shaded a little differently, and their small human ear sits a pixel apart: covering only
    pixels that matched the standing view left that ear showing, the user, 2026-11-24); an arm raised past the
    head, where the standing view is clear, stays in front of them."""
    dy, dx = shift
    moved = np.zeros_like(ear)
    ys, xs = np.nonzero(ear[..., 3])
    for y, x in zip(ys, xs):
        Y, X = y + dy, x + dx
        if 0 <= Y < 64 and 0 <= X < 64:
            here = frame[Y, X]
            if here[3] == 0 or ref[y, x, 3]:
                moved[Y, X] = ear[y, x]
    im = Image.fromarray(frame.copy())
    im.alpha_composite(Image.fromarray(moved))
    return np.asarray(im)


def row_ears(anim, d):
    """A row's own ears, frame by frame (hero64_doll_ears_<anim>_<direction>.png, lifted from ChatGPT's elf
    painting of that row), a left row its right twin's mirrored frame by frame; None if not drawn."""
    if d.endswith("left"):
        r = row_ears(anim, d[:-4] + "right")
        if r is None:
            return None
        n = t.ANIMS[anim]
        return np.concatenate([r[:, c * 64:(c + 1) * 64][:, ::-1] for c in range(n)], 1)
    p = os.path.join(HEROES, f"hero64_doll_ears_{anim}_{d}.png")
    return np.asarray(Image.open(p).convert("RGBA")) if os.path.exists(p) else None


def elf(anim):
    """Idle's heads are the standing views', so the standing ears fit them; walk and attack were painted apart,
    their heads 30 to 70% like the standing views', so they take ears ChatGPT painted on each row (the user,
    2026-11-24) and stay the plain doll till then."""
    n = t.ANIMS[anim]
    doll = np.asarray(Image.open(os.path.join(HEROES, f"hero64_doll_{anim}.png")).convert("RGBA"))
    out = doll.copy()
    for r, d in enumerate(t.DIRECTIONS):
        own = row_ears(anim, d)
        if own is not None:
            band = Image.fromarray(doll[r * 64:(r + 1) * 64].copy())
            band.alpha_composite(Image.fromarray(own[:, :band.width]))
            out[r * 64:(r + 1) * 64] = np.asarray(band)
            continue
        v = view(d) if anim == "idle" else None
        if v is None:
            continue
        ref, ear = v
        for c in range(n):
            f = doll[r * 64:(r + 1) * 64, c * 64:(c + 1) * 64]
            if f[..., 3].any():
                out[r * 64:(r + 1) * 64, c * 64:(c + 1) * 64] = wear(f, ear, fit(f, ref), ref)
    return out


def gif(sheet, anim, path, ms):
    n = t.ANIMS[anim]
    rows = [r for r in range(len(t.DIRECTIONS)) if sheet[r * 64:(r + 1) * 64, :, 3].any()]
    frames = []
    for c in range(n):
        im = Image.new("RGBA", (64 * len(rows), 64), (255, 255, 255, 255))
        for i, r in enumerate(rows):
            im.alpha_composite(Image.fromarray(sheet[r * 64:(r + 1) * 64, c * 64:(c + 1) * 64]), (i * 64, 0))
        frames.append(im.convert("RGB").resize((im.width * 4, 256), Image.NEAREST))
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=ms, loop=0)


if __name__ == "__main__":
    for anim in t.ANIMS:
        s = elf(anim)
        im = Image.fromarray(s)
        im.save(os.path.join(HEROES, f"hero64_elf_{anim}.png"))
        im.resize((im.width * 4, im.height * 4), Image.NEAREST).save(os.path.join(HEROES, f"hero64_elf_{anim}_4x.png"))
        gif(s, anim, os.path.join(HEROES, f"hero64_elf_{anim}.gif"), hi.GIF_MS[anim])
        if anim == "walk":
            gif(s, anim, os.path.join(HEROES, "hero64_elf_run.gif"), hi.RUN_MS)
        print("wrote", f"hero64_elf_{anim}.png", "ears on:", ", ".join(d for d in t.DIRECTIONS if view(d)))
