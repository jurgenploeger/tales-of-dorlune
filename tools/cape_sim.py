"""A cape that swings, after SpriteCook's "2D cape and cloth physics" article (Verlet, 2026-11-27): a
prototype on the 64-pixel doll (docs/ai-sprite-test/heroes), to judge before anything goes into the game.

The article's chain: 8 points pinned at the neck, each a step of 1/120 s, gravity and drag, links held at
their length (and minimum-only links two apart, so it doesn't fold), a "stays behind the back" limit and a
mirror when the hero turns. It draws its cape as a two-shade ribbon; ours is drawn art (art/sprites/
wear_cape.png, what GearOverlay hangs from the shoulders), so here the picture is bent along the chain
instead: each row of it rides the chain at its own length down, sampled nearest, every pixel whole.

    python3 tools/cape_sim.py out_dir     GIFs: walk, run and stop facing right; a turn; standing in a gust
"""
import os, sys, math
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HEROES = os.path.join(ROOT, "docs", "ai-sprite-test", "heroes")

# The article's numbers, in art pixels for a 46-pixel figure (the doll is 46 tall too).
N = 8
STEP = 1 / 120
GRAVITY = 430.0
DRAG = 1.1                                # 2.2 in the article; on our walk speed the cape stood out flat
PASSES = 10
BEHIND = [0, 1.5, 3, 4.5, 6, 7, 7.5, 8]   # how far ahead of the neck each point may be
BEHIND_PUSH = 0.025
WALK, RUN = 88.0, 150.0                   # points a second (WorldScene.walkSpeed; a run ~1.7×)


class Chain:
    def __init__(self, anchor, length):
        self.gap = length / (N - 1)
        self.x = np.array([[anchor[0], anchor[1] + i * self.gap] for i in range(N)], float)
        self.old = self.x.copy()

    def step(self, anchor, facing, wind=0.0):
        v = self.x - self.old
        self.old = self.x.copy()
        air = np.array([wind, 0.0])
        acc = np.array([0.0, GRAVITY]) + DRAG * (air - v / STEP)
        self.x = self.x + v + acc * STEP * STEP
        self.x[0] = anchor; self.old[0] = anchor
        for _ in range(PASSES):
            for i in range(N - 1):                       # exact links, each fix at once
                self._link(i, i + 1, self.gap, exact=True)
            for i in range(N - 2):                       # two apart, minimum only: no folding up
                self._link(i, i + 2, 2 * self.gap * 0.95, exact=False)
        for i in range(1, N):                             # behind the back
            ahead = (self.x[i, 0] - anchor[0]) * facing
            if ahead > BEHIND[i]:
                self.x[i, 0] -= facing * (ahead - BEHIND[i]) * BEHIND_PUSH * 40

    def _link(self, a, b, rest, exact):
        d = self.x[b] - self.x[a]
        L = math.hypot(*d)
        if L < 1e-6 or (not exact and L >= rest):
            return
        wa = 0.0 if a == 0 else 1.0
        wb = 1.0
        f = (L - rest) / (L * (wa + wb))
        self.x[a] += d * f * wa
        self.x[b] -= d * f * wb

    def mirror(self, anchor):
        for arr in (self.x, self.old):
            arr[:, 0] = anchor[0] - (arr[:, 0] - anchor[0])


def cape_picture(scale):
    """The side view of the status cape (wear_cape.png, row 1 = right), in a cape colour, scaled to the doll."""
    sheet = np.asarray(Image.open(os.path.join(ROOT, "art/sprites/wear_cape.png")).convert("RGBA"))
    side = sheet[48:96]
    ys, xs = np.nonzero(side[..., 3])
    crop = side[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = crop.shape[:2]
    big = Image.fromarray(crop).resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.NEAREST)
    return np.asarray(big)


def anchor_of(frame):
    """The back of the shoulders: the row under the neck (the narrowest row below the head) and its back edge."""
    a = frame[..., 3] > 0
    rows = [y for y in range(64) if a[y].any()]
    top = rows[0]
    widths = {y: np.nonzero(a[y])[0] for y in range(top + 12, top + 26) if a[y].any()}
    neck = min(widths, key=lambda y: widths[y].max() - widths[y].min())
    y = neck + 2
    return np.array([float(np.nonzero(a[y])[0].min() + 3), float(y - 1)])


def bend(pic, chain, anchor, facing):
    """The cape picture riding the chain: each row of it slid along to where the chain is at its length down,
    whole (rotated, its rows came apart into shards: the side view is 20 pixels across), so the cape lifts
    and trails back row by row. Its top against the back of the shoulders."""
    h, w = pic.shape[:2]
    out = np.zeros((64, 64, 4), np.uint8)
    src = pic if facing > 0 else pic[:, ::-1]
    seg = np.diff(chain.x, axis=0)
    lens = np.hypot(seg[:, 0], seg[:, 1])
    cum = np.concatenate([[0], np.cumsum(lens)])
    rest = chain.x[0]
    for r in range(h):
        s = min(r * cum[-1] / max(h - 1, 1), cum[-1] - 1e-6)
        i = max(min(np.searchsorted(cum, s, side="right") - 1, N - 2), 0)
        t = (s - cum[i]) / max(lens[i], 1e-6)
        p = chain.x[i] + seg[i] * t
        Y = int(math.floor(p[1] + 0.5))
        dx = int(math.floor(p[0] - rest[0] + 0.5))
        for c in range(w):
            if src[r, c, 3] == 0:
                continue
            # the picture's back edge (right when facing right) against the anchor
            X = int(anchor[0]) + dx + (c - (w - 1) if facing > 0 else c)
            if 0 <= X < 64 and 0 <= Y < 64:
                out[Y, X] = src[r, c]
    return out


def tint(pic, rgb=(70, 110, 200)):
    """The piece's colour (drawn in a template hue) brought to a cape colour, its shading kept by value."""
    import colorsys
    out = pic.copy()
    h0, s0, _ = colorsys.rgb_to_hsv(*(np.array(rgb) / 255))
    for y, x in zip(*np.nonzero(pic[..., 3])):
        r, g, b = pic[y, x, :3] / 255
        _, s, v = colorsys.rgb_to_hsv(r, g, b)
        if s < 0.15:
            continue
        out[y, x, :3] = (np.array(colorsys.hsv_to_rgb(h0, min(1, s0 * (0.6 + s * 0.5)), v)) * 255).astype(np.uint8)
    return out


def compose(body, cape):
    out = cape.copy()
    m = body[..., 3] > 0
    out[m] = body[m]                                   # from the side the cape hangs behind the body
    return out


def run(out_dir):
    import hero_template as t
    os.makedirs(out_dir, exist_ok=True)
    walk = np.asarray(Image.open(os.path.join(HEROES, "hero64_doll_walk.png")).convert("RGBA"))
    idle = np.asarray(Image.open(os.path.join(HEROES, "hero64_doll_idle.png")).convert("RGBA"))
    def frames(sheet, d, n):
        r = t.DIRECTIONS.index(d)
        return [sheet[r * 64:(r + 1) * 64, c * 64:(c + 1) * 64] for c in range(n)]
    walk_r, idle_r = frames(walk, "right", 8), frames(idle, "right", 4)
    walk_l, idle_l = frames(walk, "left", 8), frames(idle, "left", 4)
    pic = tint(cape_picture(46 / 32))

    def play(script, name):
        """script: list of (frame list, speed px/s, facing, seconds, wind, ms per frame)."""
        chain = None; world_x = 0.0; out = []; facing_was = None
        for fr, speed, facing, secs, wind, ms in script:
            steps = int(secs / STEP); per = max(1, int(ms / 1000 / STEP))
            for k in range(steps):
                f = fr[(k // per) % len(fr)]
                local = anchor_of(f)
                world_x += speed * facing * STEP
                anchor = local + np.array([world_x, 0])
                if chain is None:
                    chain = Chain(anchor, pic.shape[0] - 1)
                    for _ in range(300): chain.step(anchor, facing)
                if facing_was is not None and facing != facing_was:
                    chain.mirror(anchor)
                facing_was = facing
                chain.step(anchor, facing, wind)
                if k % per == 0:
                    view = Chain.__new__(Chain); view.gap = chain.gap
                    view.x = chain.x - np.array([world_x, 0]); view.old = view.x
                    cape = bend(pic, view, local, facing)
                    img = Image.new("RGBA", (64, 64), (120, 170, 90, 255))
                    img.alpha_composite(Image.fromarray(compose(f, cape)))
                    out.append((img.resize((256, 256), Image.NEAREST).convert("RGB"), ms))
        out[0][0].save(os.path.join(out_dir, name), save_all=True, append_images=[o for o, _ in out[1:]],
                       duration=[d for _, d in out], loop=0)
        print("wrote", name, len(out), "frames")

    play([(idle_r, 0, 1, 1.0, 0, 250), (walk_r, WALK, 1, 2.0, 0, 90), (walk_r, RUN, 1, 1.5, 0, 55),
          (idle_r, 0, 1, 2.0, 0, 250)], "cape_walk_run_stop.gif")
    play([(walk_r, WALK, 1, 1.5, 0, 90), (walk_l, WALK, -1, 1.5, 0, 90), (idle_l, 0, -1, 1.5, 0, 250)],
         "cape_turn.gif")
    play([(idle_r, 0, 1, 1.0, 0, 250), (idle_r, 0, 1, 1.2, -115, 250), (idle_r, 0, 1, 2.0, 0, 250)],
         "cape_gust.gif")


if __name__ == "__main__":
    run(sys.argv[1] if len(sys.argv) > 1 else "cape_sim_out")
