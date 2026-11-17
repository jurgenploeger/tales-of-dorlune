#!/usr/bin/env python3
"""A preview of BridgeArt's four materials (WorldMap.Bridge.Material; keep the colours in step with BridgeArt.look): the deck as BridgeArt.deckPicture paints it (north up), turned and
squashed as the game's view is, over water between two banks, with posts and rails along its sides."""
import math, sys
import numpy as np
from PIL import Image, ImageDraw

PX = 32
LOOKS = {
 'wood':    dict(plank=(164,116,70), gap=(78,52,34), beam=(112,76,46), edge=(84,56,34), nail=(60,52,48), cap=(164,116,70), light=(164,116,70), dark=(112,76,46), slabs=False),
 'stone':   dict(plank=(156,152,144), gap=(92,90,90), beam=(124,120,114), edge=(78,76,78), nail=(92,90,90), cap=(184,180,170), light=(164,160,152), dark=(108,104,102), slabs=True),
 'lacquer': dict(plank=(136,92,60), gap=(66,42,30), beam=(176,50,44), edge=(104,28,30), nail=(60,44,40), cap=(238,190,80), light=(206,66,54), dark=(136,36,36), slabs=False),
 'rope':    dict(plank=(188,150,100), gap=(70,52,38), beam=(150,118,76), edge=(96,72,46), nail=(70,52,38), cap=(188,150,100), light=(206,184,136), dark=(150,126,86), slabs=False),
}

def noise(a, b):
    h = (a * 73856093) ^ (b * 19349663)
    h &= 0xffffffff
    h = ((h ^ (h >> 13)) * 0x5bd1e995) & 0xffffffff
    h ^= h >> 15
    return (h & 0xffff) / 65535

def deck(look, lanes, cells):
    L = LOOKS[look]
    shadow, beamw = max(2, PX // 8), max(2, PX // 10)
    wide = lanes * PX; across = wide + 2 * shadow; along = int(cells * PX)
    deep = max(4, PX // 2) if L['slabs'] else max(3, PX // 4)
    img = np.zeros((along, across, 4), float)
    for v in range(along):
        board, inb = v // deep, v % deep
        tone = 0.92 + 0.16 * noise(board, 7)
        for u in range(across):
            ins = u - shadow
            if ins < 0 or ins >= wide: img[v, u] = (0, 0, 0, 0.28 * 255); continue
            if ins in (0, wide - 1): c = L['edge']
            elif ins < beamw or ins >= wide - beamw: c = L['beam']
            elif inb == deep - 1: c = L['gap']
            elif L['slabs'] and (ins + (board % 2) * deep // 2) % deep == 0: c = L['gap']
            elif not L['slabs'] and inb == deep // 2 and ins in (beamw + 1, wide - beamw - 2): c = L['nail']
            else:
                s = tone * (1.12 if inb == 0 else 1)
                if noise(ins, v * 7) < 0.06: s *= 0.85
                c = tuple(min(255, x * s) for x in L['plank'])
            img[v, u] = (*c, 255)
    return img

def scene(look, lanes=3, cells=5, zoom=3, depth=True):
    """`depth`: the deck standing over the water, not lying on it (the user, 2026-11-17: "They look a bit
    too flat, and shouldn't there be a shadow underneath as well and a reflection in the water?"): its
    thickness down its near side, piles under it into the water, its shadow on the water away from the sun
    (down and to the right), and it, its posts and its rails mirrored in the water in the water's dark tone."""
    W, H = 300, 210
    L = LOOKS[look]
    d = deck(look, lanes, cells + 1.2)
    shadow = max(2, PX // 8)
    C = 22  # half a cell's diamond across, in pixels
    THICK = 6 if depth else 0   # how far the deck's top stands over the water, in pixels
    ox, oy = W / 2, H - 40
    yy, xx = np.mgrid[0:H, 0:W]

    def ground(dy=0.0):
        """Which ground cell each pixel shows, for ground lying `dy` pixels up the screen."""
        sx = (xx - ox) / C; sy = (oy - (yy + dy)) / (C * 0.5)
        return (sx + sy) / 2 + 1.5, (sy - sx) / 2

    gx, gy = ground()
    water = (gy > 0) & (gy < cells)
    rip = np.sin(gx * 5 + gy * 3) * np.sin(gy * 7 - gx * 2)
    blue = np.array([58, 150, 190.0])
    canvas = np.where(water[..., None], blue + 10 * rip[..., None], np.array([98, 160, 74]) + 6 * rip[..., None])
    canvas[water & ((gy < 0.18) | (gy > cells - 0.18))] = (40, 110, 150)
    road = ~water & (gx > 0) & (gx < lanes)
    canvas[road] = np.array([196, 168, 120]) + 6 * rip[road][..., None]

    def spot(lane, along, z=0.0):
        x = lane - 1.5
        return (ox + (x - along) * C, oy - (x + along) * C * 0.5 - z)

    first, last = -0.5, cells + 0.5
    n = max(2, round((last - first) / 1.25) + 1)
    sides = (0.06, lanes - 0.06)

    def railings(draw, sign, tint=None, top=THICK):
        """Posts and rails; `sign` -1 draws them hanging down from the water's level (the reflection)."""
        def c(colour): return tint or colour
        for lane in sides:
            pts = [(lane, first + (last - first) * k / (n - 1)) for k in range(n)]
            for (l0, a0), (l1, a1) in zip(pts, pts[1:]):
                # Ropes hang between their posts (`BridgeArt.rails`); rails run straight.
                parts, sag = (4, 2.5) if look == 'rope' else (1, 0)
                for h, colour in ((9, L['light']), (8, L['dark']), (5, L['light']), (4, L['dark'])):
                    for k in range(parts):
                        t0, t1 = k / parts, (k + 1) / parts
                        x0, y0 = spot(l0 + (l1 - l0) * t0, a0 + (a1 - a0) * t0, sign * (top + h - sag * math.sin(math.pi * t0)))
                        x1, y1 = spot(l0 + (l1 - l0) * t1, a0 + (a1 - a0) * t1, sign * (top + h - sag * math.sin(math.pi * t1)))
                        draw.line([(x0, y0), (x1, y1)], fill=c(colour), width=1)
            for lane_, along in pts:
                x, y0 = spot(lane_, along, sign * top); _, y1 = spot(lane_, along, sign * (top + 12))
                draw.rectangle([x - 1, min(y0, y1), x + 1, max(y0, y1)], fill=c(tuple(int(t * 0.9) for t in L['light'])))
                if tint is None:
                    draw.line([(x - 1, y1), (x - 1, y0)], fill=L['light']); draw.line([(x + 1, y1), (x + 1, y0)], fill=L['edge'])
                    draw.line([(x - 1, y1 - 1), (x + 1, y1 - 1)], fill=L['cap'])

    if depth:
        # Its shadow on the water: its footprint a little down and to the right, away from the sun.
        sgx, sgy = ground(-5)
        sgx = sgx - 0.22
        cast = water & (sgx > 0) & (sgx < lanes) & (sgy > -0.4) & (sgy < cells + 0.4)
        canvas[cast] = canvas[cast] * 0.62
        # It mirrored in the water: the deck's underside hanging as far below the water's level as its top
        # stands over it, then its posts and rails, in the water's own dark tone, rows nudged like ripples.
        mirror = Image.new('RGBA', (W, H), (0, 0, 0, 0)); md = ImageDraw.Draw(mirror)
        dark = (30, 92, 128, 255)
        near = [spot(0, first, -THICK), spot(0, last, -THICK), spot(0, last, -THICK - 3), spot(0, first, -THICK - 3)]
        md.polygon(near, fill=dark)
        railings(md, -1, tint=dark)
        m = np.asarray(mirror).astype(float)
        for row in range(H):
            m[row] = np.roll(m[row], int(round(1.2 * math.sin(row * 0.9))), axis=0)
        on = (m[..., 3] > 0) & water
        canvas[on] = canvas[on] * 0.35 + m[on][..., :3] * 0.65

    img = Image.fromarray(canvas.clip(0, 255).astype(np.uint8)).convert('RGBA')
    draw = ImageDraw.Draw(img)
    if depth:
        # Piles under it into the water, a pair under every other post, and the dark of its underside.
        for k in range(1, n - 1, 1):
            along = first + (last - first) * k / (n - 1)
            for lane in (0.0, float(lanes)):
                x, y = spot(lane, along)
                if 0 < along < cells:
                    draw.rectangle([x - 1, y - THICK, x + 1, y + 3], fill=tuple(int(t * 0.55) for t in L['beam']))
                    draw.line([(x - 2, y + 3), (x + 2, y + 3)], fill=(200, 232, 240, 255))    # where it stands in the water
    # The deck, 0.6 onto each bank, its top standing THICK over the water.
    dgx, dgy = ground(THICK)
    u = np.floor((dgx * PX) + shadow).astype(int); v = np.floor((dgy + 0.6) * PX).astype(int)
    ok = (u >= shadow) & (u < d.shape[1] - shadow) & (v >= 0) & (v < d.shape[0])
    layer = np.asarray(img).astype(float)
    if depth:
        # Its thickness down the two sides that face you: under its near long side and its near end.
        for dz in range(THICK, 0, -1):
            fgx, fgy = ground(THICK - dz)
            fu = np.floor(fgx * PX).astype(int); fv = np.floor((fgy + 0.6) * PX).astype(int)
            side = (fu >= 0) & (fu < lanes * PX) & (fv >= 0) & (fv < d.shape[0]) & ~ok
            shade = 0.5 if dz > 1 else 0.36
            layer[side, :3] = np.array(L['beam']) * shade if look != 'stone' else np.array(L['plank']) * (shade + 0.12)
    layer[ok, :3] = d[v[ok], u[ok], :3]
    img = Image.fromarray(layer.clip(0, 255).astype(np.uint8)).convert('RGBA')
    railings(ImageDraw.Draw(img), 1)
    return img.resize((W * zoom, H * zoom), Image.NEAREST)


names = ['wood', 'stone', 'lacquer', 'rope']
titles = {'wood': 'Wood', 'stone': 'Stone', 'lacquer': 'Red lacquer', 'rope': 'Rope (footbridges)'}
flat = "--flat" in sys.argv
out = [a for a in sys.argv[1:] if not a.startswith("--")][0]
tiles = [scene(n, lanes=2 if n == 'rope' else 3, depth=not flat) for n in names]
w, h = tiles[0].size
board = Image.new('RGBA', (w * 2 + 30, h * 2 + 90), (24, 30, 46, 255)); dr = ImageDraw.Draw(board)
for k, (n, t) in enumerate(zip(names, tiles)):
    x, y = 10 + (k % 2) * (w + 10), 10 + (k // 2) * (h + 40)
    board.alpha_composite(t, (x, y)); dr.text((x + 8, y + h + 8), titles[n], fill=(255, 255, 255, 255))
board.save(out); print(out)
