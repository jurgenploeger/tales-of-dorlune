#!/usr/bin/env python3
"""A preview of BridgeArt's four materials (WorldMap.Bridge.Material; keep the colours in step with BridgeArt.look): the deck as BridgeArt.deckPicture paints it (north up), turned and
squashed as the game's view is, over water between two banks, with posts and rails along its sides."""
import math, sys
import numpy as np
from PIL import Image, ImageDraw

PX = 44   # a ground tile's pixels a cell (`WorldMap.tilePixels`; 32 till 0.9.247)
LOOKS = {
 'wood':    dict(plank=(164,116,70), gap=(78,52,34), beam=(112,76,46), edge=(84,56,34), nail=(60,52,48), cap=(164,116,70), light=(164,116,70), dark=(112,76,46), slabs=False),
 'stone':   dict(plank=(156,152,144), gap=(92,90,90), beam=(124,120,114), edge=(78,76,78), nail=(92,90,90), cap=(160,156,148), light=(132,128,122), dark=(96,92,90), slabs=True),
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

def scene(look, lanes=3, cells=5, zoom=3, depth=True, ends='now', crop=None):
    """`depth`: the deck standing over the water, not lying on it (the user, 2026-11-17: "They look a bit
    too flat, and shouldn't there be a shadow underneath as well and a reflection in the water?"): its
    thickness down its near side, piles under it into the water, its shadow on the water away from the sun
    (down and to the right), and it, its posts and its rails mirrored in the water in the water's dark tone."""
    W, H = 300, 210
    L = LOOKS[look]
    d = deck(look, lanes, cells + 1.2)
    # How its ends meet the land (the user, 2026-11-17: "The connection with the land looks still a bit
    # too perfect"). 'now': the deck's end a straight line across the road. 'worn': its last boards
    # broken off raggedly, the road's earth trodden onto them. 'sill': a sill of rough stones under each
    # end, wider than the deck, with tufts of grass at its corners. 'both': the two together.
    if ends in ('worn', 'both'):
        rows = d.shape[0]
        for v in range(rows):
            into = (0.6 * PX - v) / PX if v < 0.6 * PX else (v - (rows - 0.6 * PX)) / PX   # cells onto the bank
            if into <= 0.2:
                continue
            for u in range(d.shape[1]):
                gone = (into - 0.2) / 0.4
                if noise(u // 2, v // 2 + 91) < gone * 1.15:
                    d[v, u, 3] = 0
                elif noise(u // 2 + 5, v // 2 + 17) < 0.25 * gone:
                    d[v, u, :3] = (188, 160, 114)         # earth trodden onto the boards
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
    # The road's edges worn uneven, as the game's are (`ArtLibrary.organicTile`), not ruled.
    wob = 0.16 * np.sin(gy * 2.3 + 1) + 0.1 * np.sin(gy * 5.1)
    ragged = ~water & (gx > -0.2 + wob) & (gx < lanes + 0.2 + wob)
    if ends != 'now':
        canvas[ragged & ~road] = np.array([186, 160, 112]) + 6 * rip[ragged & ~road][..., None]
    if ends in ('sill', 'both'):
        for lo, hi in ((-1.0, -0.45), (cells + 0.45, cells + 1.0)):
            band = (gy > lo) & (gy < hi) & (gx > -0.35) & (gx < lanes + 0.35)
            stone = np.floor(gx * 2.2 + (0.5 if lo < 0 else 0)).astype(int)
            tone = 0.82 + 0.3 * np.vectorize(lambda a: noise(int(a), 3))(stone)
            joint = np.abs(gx * 2.2 + (0.5 if lo < 0 else 0) - np.round(gx * 2.2 + (0.5 if lo < 0 else 0))) < 0.07
            rim = (gy - lo < 0.06) | (hi - gy < 0.06) | (gx < -0.29) | (gx > lanes + 0.29)
            canvas[band] = (np.array([150, 146, 138])[None, :] * tone[band][:, None])
            canvas[band & (joint | rim)] = (86, 84, 86)

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
    ok[ok] &= d[v[ok], u[ok], 3] > 0
    layer = np.asarray(img).astype(float)
    if depth:
        # Its thickness down the two sides that face you: under its near long side and its near end.
        for dz in range(THICK, 0, -1):
            fgx, fgy = ground(THICK - dz)
            fu = np.floor(fgx * PX).astype(int); fv = np.floor((fgy + 0.6) * PX).astype(int)
            side = (fu >= 0) & (fu < lanes * PX) & (fv >= 0) & (fv < d.shape[0]) & ~ok
            if ends in ('worn', 'both'):
                side &= (fgy > -0.15) & (fgy < cells + 0.15)      # no side under the broken ends
            shade = 0.5 if dz > 1 else 0.36
            layer[side, :3] = np.array(L['beam']) * shade if look != 'stone' else np.array(L['plank']) * (shade + 0.12)
    layer[ok, :3] = d[v[ok], u[ok], :3]
    img = Image.fromarray(layer.clip(0, 255).astype(np.uint8)).convert('RGBA')
    railings(ImageDraw.Draw(img), 1)
    if ends in ('sill', 'both'):
        # Tufts of grass and a pebble or two at the sill's corners.
        dr = ImageDraw.Draw(img)
        for lane, along, k in ((-0.5, -0.75, 0), (lanes + 0.5, -0.75, 1), (-0.5, cells + 0.75, 2), (lanes + 0.5, cells + 0.75, 3)):
            x, y = spot(lane, along)
            for b in range(5):
                bx = x + (b - 2) * 1.5
                dr.line([(bx, y), (bx + (b - 2) * 0.6, y - 4 - (b % 2) * 2)], fill=(52, 120, 50) if b % 2 else (84, 150, 62))
            px, py = x + (5 if k % 2 else -5), y + 2
            dr.ellipse([px - 2, py - 1, px + 2, py + 1], fill=(160, 156, 148), outline=(86, 84, 86))
    if crop:
        img = img.crop(crop)
    return img.resize((img.width * zoom, img.height * zoom), Image.NEAREST)


def bow(look='stone', lanes=3, cells=5, zoom=4, rise=15):
    """A bow bridge (the user, 2026-11-17: "perhaps it should be more lifted up or become a bow bridge when
    it's stone"): the deck rising in an arch from bank to bank, `rise` pixels at its middle, on a wall of
    stone down its near side with an arch through it for the water, its rails following the curve, and
    the whole mirrored in the water."""
    W, H = 300, 220
    L = LOOKS[look]
    C = 22
    ox, oy = W / 2, H - 44
    yy, xx = np.mgrid[0:H, 0:W]
    sx = (xx - ox) / C; sy = (oy - yy) / (C * 0.5)
    gx = (sx + sy) / 2 + 1.5; gy = (sy - sx) / 2
    water = (gy > 0) & (gy < cells)
    rip = np.sin(gx * 5 + gy * 3) * np.sin(gy * 7 - gx * 2)
    canvas = np.where(water[..., None], np.array([58, 150, 190.0]) + 10 * rip[..., None], np.array([98, 160, 74]) + 6 * rip[..., None])
    canvas[water & ((gy < 0.18) | (gy > cells - 0.18))] = (40, 110, 150)
    wob = 0.16 * np.sin(gy * 2.3 + 1) + 0.1 * np.sin(gy * 5.1)
    road = ~water & (gx > -0.15 + wob) & (gx < lanes + 0.15 + wob)
    canvas[road] = np.array([196, 168, 120]) + 6 * rip[road][..., None]

    lo, hi = -0.6, cells + 0.6              # the deck's ends, on the banks
    def lift(along):
        t = min(1, max(0, (along - lo) / (hi - lo)))
        return rise * math.sin(math.pi * t)
    def spot(lane, along, z=0.0):
        x = lane - 1.5
        return (ox + (x - along) * C, oy - (x + along) * C * 0.5 - z)

    # Its shadow on the water, and it mirrored there: the wall's arch and the deck's edge, hanging down.
    img = Image.fromarray(canvas.clip(0, 255).astype(np.uint8)).convert('RGBA')
    px = img.load()
    def wall(sign, colour_of):
        steps = int((hi - lo) * C * 2)
        for k in range(steps + 1):
            along = lo + (hi - lo) * k / steps
            x, y0 = spot(0, along)
            top = lift(along)
            # The arch through it: an opening over the water, leaving a ring of stone under the deck.
            t = (along - 0) / cells
            opening = 0 < t < 1
            arch = (rise - 5) * math.sqrt(max(0, 1 - ((t - 0.5) / 0.46) ** 2)) if opening else 0
            for z in range(int(round(top)) + 1):
                if z < arch:
                    continue
                yy_ = int(round(y0 - sign * z)); xx_ = int(round(x))
                if 0 <= xx_ < W and 0 <= yy_ < H:
                    c = colour_of(along, z, top, arch)
                    if c is not None:
                        px[xx_, yy_] = c
    dark = (30, 92, 128, 255)
    def mirrored(along, z, top, arch):
        return dark if 0 < along < cells else None
    wall(-1, mirrored)
    # The deck, boards up the curve, drawn from its far side to its near side.
    d = deck(look, lanes, hi - lo)
    sh = max(2, PX // 8)
    for v in range(d.shape[0] * 2):
        along = lo + v / 2 / PX
        z = lift(along)
        for u in range(lanes * PX * 2, -1, -1):
            lane = u / 2 / PX
            c = d[min(d.shape[0] - 1, v // 2), min(d.shape[1] - 1, sh + u // 2)]
            if c[3] < 255:
                continue
            x, y = spot(lane, along, z)
            xi, yi = int(round(x)), int(round(y))
            if 0 <= xi < W and 0 <= yi < H:
                # Lit where it climbs toward the sun (the far half), shaded where it falls away.
                slope = math.cos(math.pi * min(1, max(0, (along - lo) / (hi - lo))))
                k = 1 + 0.10 * slope
                px[xi, yi] = (int(min(255, c[0] * k)), int(min(255, c[1] * k)), int(min(255, c[2] * k)), 255)
    def stone(along, z, top, arch):
        course = int(z) // 4
        joint = int(z) % 4 == 0 or int((along * 9 + (course % 2) * 0.5)) != int((along * 9 + (course % 2) * 0.5 - 0.12))
        ring = arch > 0 and z < arch + 3
        base = 104 if ring else 128
        tone = base * (0.9 + 0.2 * noise(int(along * 9 + course % 2 * 0.5), course))
        if joint and not ring:
            tone *= 0.72
        if z >= int(round(top)) - 1:
            tone = 168            # the coping along its top
        return (int(tone), int(tone * 0.98), int(tone * 0.94), 255)
    wall(1, stone)
    draw = ImageDraw.Draw(img)
    # Posts and rails along both sides, following the curve.
    first, last = lo + 0.1, hi - 0.1
    n = max(2, round((last - first) / 1.25) + 1)
    for lane in (lanes - 0.06, 0.06):
        pts = [first + (last - first) * k / (n - 1) for k in range(n)]
        for a0, a1 in zip(pts, pts[1:]):
            for part in range(6):
                b0, b1 = a0 + (a1 - a0) * part / 6, a0 + (a1 - a0) * (part + 1) / 6
                for h, colour in ((9, L['light']), (8, L['dark']), (5, L['light']), (4, L['dark'])):
                    draw.line([spot(lane, b0, lift(b0) + h), spot(lane, b1, lift(b1) + h)], fill=colour, width=1)
        for along in pts:
            x, y = spot(lane, along, lift(along))
            draw.rectangle([x - 1, y - 12, x + 1, y], fill=tuple(int(t * 0.9) for t in L['light']))
            draw.line([(x - 1, y - 12), (x - 1, y)], fill=L['light']); draw.line([(x + 1, y - 12), (x + 1, y)], fill=L['edge'])
            draw.line([(x - 1, y - 13), (x + 1, y - 13)], fill=L['cap'])
    return img.resize((W * zoom, H * zoom), Image.NEAREST)


names = ['wood', 'stone', 'lacquer', 'rope']
titles = {'wood': 'Wood', 'stone': 'Stone', 'lacquer': 'Red lacquer', 'rope': 'Rope (footbridges)'}
flat = "--flat" in sys.argv
out = [a for a in sys.argv[1:] if not a.startswith("--")][0]
if "--bow" in sys.argv:
    tiles = [("Stone, as it is now (flat, with a sill)", scene('stone', depth=True, ends='sill', zoom=4)),
             ("Stone as a bow bridge", bow('stone')), ("Red lacquer as a bow bridge", bow('lacquer'))]
    columns = 3
elif "--ends" in sys.argv:
    # How a bridge's ends meet the land, four ways, on the stone bridge and the wooden one.
    picks = [('now', 'A: as now'), ('worn', 'B: boards broken off, earth trodden on'), ('sill', 'C: a stone sill and tufts'), ('both', 'D: B and C together')]
    tiles = [(f"{titles[n]}  {label}", scene(n, depth=True, ends=e, zoom=5, crop=(150, 78, 300, 200))) for n in ('stone', 'wood') for e, label in picks]
    columns = 4
else:
    tiles = [(titles[n], scene(n, lanes=2 if n == 'rope' else 3, depth=not flat)) for n in names]
    columns = 2
w, h = tiles[0][1].size
rows = (len(tiles) + columns - 1) // columns
board = Image.new('RGBA', (w * columns + 10 * (columns + 1), (h + 40) * rows + 10), (24, 30, 46, 255)); dr = ImageDraw.Draw(board)
for k, (title, t) in enumerate(tiles):
    x, y = 10 + (k % columns) * (w + 10), 10 + (k // columns) * (h + 40)
    board.alpha_composite(t, (x, y)); dr.text((x + 8, y + h + 8), title, fill=(255, 255, 255, 255))
board.save(out); print(out)
