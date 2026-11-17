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

def scene(look, lanes=3, cells=5, zoom=3):
    W, H = 300, 210
    canvas = np.zeros((H, W, 3), float)
    # Ground coords (cells): river along x, banks y<0.9 and y>4.1 ... the bridge runs north (y), lanes along x.
    d = deck(look, lanes, cells + 1.2)
    shadow = max(2, PX // 8)
    C = 22  # half a cell's diamond across, in pixels
    ox, oy = W / 2, H - 40
    yy, xx = np.mgrid[0:H, 0:W]
    sx = (xx - ox) / C; sy = (oy - yy) / (C * 0.5)
    gx = (sx + sy) / 2; gy = (sy - sx) / 2          # ground cells
    gx += 1.5                                         # the deck's lanes from 0 to 3
    water = (gy > 0) & (gy < cells)
    rip = np.sin(gx * 5 + gy * 3) * np.sin(gy * 7 - gx * 2)
    canvas[...] = np.where(water[..., None], np.array([58, 150, 190]) + 10 * rip[..., None], np.array([98, 160, 74]) + 6 * rip[..., None])
    edge = water & ((gy < 0.18) | (gy > cells - 0.18))
    canvas[edge] = (40, 110, 150)
    # The road onto it at each end.
    road = ~water & (gx > 0) & (gx < lanes)
    canvas[road] = np.array([196, 168, 120]) + 6 * rip[road][..., None]
    # The deck, 0.6 onto each bank.
    u = np.floor((gx * PX) + shadow).astype(int); v = np.floor((gy + 0.6) * PX).astype(int)
    ok = (u >= 0) & (u < d.shape[1]) & (v >= 0) & (v < d.shape[0])
    a = np.zeros((H, W)); a[ok] = d[v[ok], u[ok], 3] / 255
    col = np.zeros((H, W, 3)); col[ok] = d[v[ok], u[ok], :3]
    canvas = canvas * (1 - a[..., None]) + col * a[..., None]
    img = Image.fromarray(canvas.clip(0, 255).astype(np.uint8)).convert('RGBA')
    # Posts and rails along both sides, far side first.
    L = LOOKS[look]; draw = ImageDraw.Draw(img)
    def spot(lane, along):
        x = lane - 1.5; return (ox + (x - along) * C, oy - (x + along) * C * 0.5)
    first, last = -0.5, cells + 0.5
    n = max(2, round((last - first) / 1.25) + 1)
    for lane in (0.06, lanes - 0.06):
        pts = [spot(lane, first + (last - first) * k / (n - 1)) for k in range(n)]
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            for h, c in ((9, L['light']), (8, L['dark']), (5, L['light']), (4, L['dark'])):
                draw.line([(x0, y0 - h), (x1, y1 - h)], fill=c, width=1)
        for x, y in pts:
            draw.rectangle([x - 1, y - 12, x + 1, y], fill=tuple(int(t * 0.9) for t in L['light']))
            draw.line([(x - 1, y - 12), (x - 1, y)], fill=L['light']); draw.line([(x + 1, y - 12), (x + 1, y)], fill=L['edge'])
            draw.line([(x - 1, y - 13), (x + 1, y - 13)], fill=L['cap'])
    return img.resize((W * zoom, H * zoom), Image.NEAREST)

names = ['wood', 'stone', 'lacquer', 'rope']
tiles = [scene(n, lanes=2 if n == 'rope' else 3) for n in names]
w, h = tiles[0].size
board = Image.new('RGBA', (w * 2 + 30, h * 2 + 90), (24, 30, 46, 255)); dr = ImageDraw.Draw(board)
for k, (n, t) in enumerate(zip(names, tiles)):
    x, y = 10 + (k % 2) * (w + 10), 10 + (k // 2) * (h + 40)
    board.alpha_composite(t, (x, y)); dr.text((x + 8, y + h + 8), {'wood': 'Wood (as now)', 'stone': 'Stone', 'lacquer': 'Red lacquer', 'rope': 'Rope (footbridges)'}[n], fill=(255, 255, 255, 255))
board.save(sys.argv[1]); print(sys.argv[1])
