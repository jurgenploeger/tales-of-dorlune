"""The hero's default outfit (v2, docs/ai-sprite-test/heroes): a green tunic with short sleeves, a brown belt, cream
trousers and brown boots, what the hero wears with nothing equipped; not a wearable slot, under every one.

ChatGPT paints the doll wearing it (the way the hair and the elf's ears are done); the outfit is lifted as every
pixel where the painting differs from the doll (an outfit is many colours, so not by hue as the hair is). The
tunic is painted in a green ramp of its own (hue 95 to 140 degrees), so a dye can find it and nothing else.

    hero_outfit.py lift <painting 1x> <doll view> <tag>       outfit_<tag>.png, on_<tag>.png and <tag>_8x.png
    hero_outfit.py lift-row <row 1x> <anim> <direction> <out>  a walk or attack row, frame by frame
"""
import os, sys, colorsys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
HEROES = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs", "ai-sprite-test", "heroes")

TUNIC_HUE = (95, 140)       # degrees
TUNIC_SAT = 0.4


def lift(painting, doll):
    """The outfit: the painting's pixels wherever it differs from the doll, and what it covers of the doll."""
    p = painting.astype(int); d = doll.astype(int)
    diff = (np.abs(p - d).sum(-1) > 0) & (p[..., 3] > 0)
    layer = np.zeros_like(painting)
    layer[diff] = painting[diff]
    removed = int(((d[..., 3] > 0) & (p[..., 3] == 0)).sum())
    past = int((diff & (d[..., 3] == 0)).sum())
    return layer, removed, past


def worn(base, layer):
    out = base.copy()
    m = layer[..., 3] > 0
    out[m] = layer[m]
    return out


def tunic_mask(layer):
    m = np.zeros(layer.shape[:2], bool)
    for y, x in zip(*np.nonzero(layer[..., 3])):
        h, s, v = colorsys.rgb_to_hsv(*(layer[y, x, :3] / 255))
        m[y, x] = TUNIC_HUE[0] <= h * 360 <= TUNIC_HUE[1] and s >= TUNIC_SAT
    return m


def dye(layer, hue, sat=1.0, val=1.0):
    """The tunic's shades turned to `hue` (degrees), their saturation and value kept (times `sat`, `val`)."""
    out = layer.copy()
    for y, x in zip(*np.nonzero(tunic_mask(layer))):
        _, s, v = colorsys.rgb_to_hsv(*(layer[y, x, :3] / 255))
        out[y, x, :3] = (np.array(colorsys.hsv_to_rgb(hue / 360, min(1, s * sat), min(1, v * val))) * 255).round()
    return out


def load(path):
    return np.asarray(Image.open(path).convert("RGBA"))


if __name__ == "__main__":
    if sys.argv[1] == "lift":
        S, M, tag = load(sys.argv[2]), load(sys.argv[3]), sys.argv[4]
        layer, removed, past = lift(S, M)
        Image.fromarray(layer).save(f"outfit_{tag}.png")
        Image.fromarray(worn(M, layer)).save(f"on_{tag}.png")
        strip = Image.new("RGBA", (64 * 4, 64), (120, 170, 90, 255))
        for i, a in enumerate((M, S, layer, worn(M, layer))):
            strip.alpha_composite(Image.fromarray(np.ascontiguousarray(a)), (i * 64, 0))
        strip.resize((64 * 4 * 8, 512), Image.NEAREST).save(f"{tag}_8x.png")
        print(tag, "outfit px", int((layer[..., 3] > 0).sum()), "doll px removed", removed, "past the doll", past,
              "tunic px", int(tunic_mask(layer).sum()))
    if sys.argv[1] == "lift-row":
        import hero_template as t
        S = load(sys.argv[2]); anim, d = sys.argv[3], sys.argv[4]
        r = t.DIRECTIONS.index(d)
        doll = load(os.path.join(HEROES, f"hero64_doll_{anim}.png"))[r * 64:(r + 1) * 64]
        out = np.zeros_like(S)
        for c in range(S.shape[1] // 64):
            sl = slice(c * 64, (c + 1) * 64)
            layer, removed, past = lift(S[:, sl], doll[:, sl])
            out[:, sl] = layer
            print("frame", c + 1, "outfit px", int((layer[..., 3] > 0).sum()), "removed", removed, "past", past)
        Image.fromarray(out).save(sys.argv[5])
