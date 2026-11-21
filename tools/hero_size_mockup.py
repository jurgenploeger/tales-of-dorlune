"""A mock-up for choosing the heroes' size: the hero in iron and golden plate and a townsperson beside a
house on town ground, as drawn today (a 48-pixel frame) and as tall as a 64-pixel frame would make them.

The taller panel is the same art blown up by 4/3, so it shows the size on screen, not the detail: a real
64-pixel hero would have its pixels the size they are today, a third more of them each way. Built with
tools/gear_preview.py's paper doll (the game's layers), nothing generated. Every art pixel is drawn at its
points on the map times 4 (a walker's pixel 1 point, the house's and the ground's 1.35 to 1.375,
tools/pixel_scale.py); the ground isn't graded by a land's palette.

    python3 tools/hero_size_mockup.py out.png
"""
import json
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import gear_preview as gp  # noqa: E402

ITEMS = {i["id"]: i for i in json.load(open(ROOT / "content/items.json"))["items"]}
P = 4  # screen pixels per point


def hero(armour=None, helm=None, style="spiky", body="human"):
    out = gp.dressed("human", body, style, ITEMS.get(armour), [ITEMS[helm]] if helm else [])
    im = Image.fromarray((np.clip(out, 0, 1) * 255).round().astype("uint8"), "RGBA")
    return im.crop((0, 96, 48, 144))  # facing you, standing


def panel(scale, label, people):
    W, H, base = 980, 640, 560
    im = Image.new("RGBA", (W, H))
    tile = Image.open(ROOT / "art/sprites/tile_town.png").convert("RGBA").resize((44 * P,) * 2, Image.NEAREST)
    for y in range(0, H, tile.height):
        for x in range(0, W, tile.width):
            im.alpha_composite(tile, (x, y))
    house = Image.open(ROOT / "art/sprites/house.png").convert("RGBA")
    side = round(96 * 1.35 * P)
    im.alpha_composite(house.resize((side, side), Image.NEAREST), (10, base - side + 10))
    x = 440
    for sprite in people:
        a = np.array(sprite)[..., 3]
        feet = np.nonzero(a.any(1))[0].max() + 1
        s = sprite.resize((round(48 * scale),) * 2, Image.NEAREST)
        im.alpha_composite(s, (x, base - round(feet * scale)))
        x += round(28 * scale)
    d = ImageDraw.Draw(im)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 28)
    except OSError:
        font = None
    d.rectangle((0, 0, W, 48), fill=(20, 20, 30, 230))
    d.text((14, 8), label, fill="white", font=font)
    return im


def main(out):
    people = [hero(None, None, "ponytail", "human_female"), hero("iron_plate", "iron_helm"),
              hero("golden_plate", "golden_helm")]
    a = panel(P, "Today: 48-pixel frame", people)
    b = panel(P * 4 / 3, "64-pixel frame: size on screen only", people)
    sheet = Image.new("RGBA", (a.width * 2 + 20, a.height), (255, 255, 255, 255))
    sheet.alpha_composite(a, (0, 0))
    sheet.alpha_composite(b, (a.width + 20, 0))
    sheet.convert("RGB").save(out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "hero_size_mockup.png")
