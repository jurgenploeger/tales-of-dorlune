#!/usr/bin/env python3
"""Hamlets along the wild lands' roads, so no land is a few houses in a big empty field.

The user, 2026-11-22: "The world needs to feel alive and no empty boring areas". The wild lands are
about 150 cells across with four or five buildings each (maps.json `buildings`, set down by hand as
x, y out from the land's middle). This adds two or three hamlets to each, four or five buildings a
hamlet, along its roads: a few cells either side of the road (`OFFSET`), a few cells apart along it
(`SPACING`), out from the hub where the road runs through the land (`REACH`). Each spot is held to
`world_layout.py`'s rules for what's set down by hand: on the land and `CONTENT_MARGIN` from its
edge, clear of its rivers, and kept from what's already there. The game then finds each one's plot
near the spot (`WorldMap.placeOwnBuildings`, off the road, within 12 cells).

What stands in a hamlet is the land's own buildings (`POOLS`, else what the land already has, its
one-offs left out: `UNIQUE`), each hamlet a mix of them. Rerun safely: buildings it added carry
`"hamlet": true`, and a rerun takes those out first. Afterwards run `world_layout.py --check` and
`check_content.py`.

    python3 tools/place_hamlets.py            # add (or redo) the hamlets
    python3 tools/place_hamlets.py --dry-run  # say where they'd go
"""
import json
import math
import random
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import world_layout as wl  # noqa: E402

MAPS = ROOT / "content" / "maps.json"

# How many buildings a land should have in all, by its size (cells of its box); hamlets fill the rest.
def wanted(land):
    area = land["width"] * land["height"]
    return 16 if area > 18000 else 13 if area > 12000 else 10 if area > 7000 else 8

HAMLET = 5           # buildings a hamlet, at most
SPACING = 6          # cells between two of a hamlet's buildings along the road
OFFSET = (4, 6)      # cells either side of the road
REACH = (14, 70)     # cells from the hub along a road a hamlet may start
KEEP = 9             # cells from anything already set down by hand (not buildings)
KEEP_BUILDING = 6    # cells from another building
APART = 22           # cells between two hamlets' first houses

# One-offs: landmarks, shrines, guild halls and the like, never copied into a hamlet.
UNIQUE = {"town_gate", "emerald_spire", "star_observatory", "moonwell", "lake_shrine", "water_shrine",
          "puppet_theater", "gem_workshop", "moon_pagoda", "fairy_great_tree", "big_hollow_tree", "bell_tower",
          "magic_tower", "windmill", "guild_hall", "warrior_guild", "wildfolk_lodge", "bank", "inn", "inn_red",
          "inn_teal", "item_shop", "item_shop_red", "blacksmith", "igloo"}

# A land's own mix where what it has isn't enough (or isn't right for houses along its roads).
POOLS = {
    "sunny_meadow": ["beekeeper_cottage", "thatched_cottage", "house_green", "bakery", "garden_cottage", "house"],
    "northern_grassland": ["chime_cottage", "house", "house_purple", "thatched_cottage", "timber_house"],
    "twilight_woods": ["lantern_cottage", "owl_tower", "witch_hut", "crooked_house", "mushroom_house_blue"],
    "smiling_forest": ["woodcutter_cabin", "stump_house", "forest_lodge", "mushroom_house", "acorn_cottage"],
    "snow_white_forest": ["apple_cellar", "carved_chalet", "dwarf_cottage", "snow_cabin"],
    "rosen_lake": ["ice_fishing_hut", "briar_cottage", "snow_cabin", "carved_chalet"],
    "frog_swamp": ["frog_hut", "reed_boathouse", "swamp_stilt_hut", "lily_cottage"],
    "lotus_land": ["lotus_pagoda", "raft_teahouse", "lily_cottage", "swamp_stilt_hut"],
    "swan_lake": ["swan_boathouse", "lake_pavilion", "house_green", "house", "garden_cottage"],
    "goldburg_lake": ["dwarf_boathouse", "smokehouse", "fisher_shack", "beach_hut", "stone_hut"],
    "pineapple_shore": ["pineapple_hut", "juice_shack", "beach_hut", "fisher_shack"],
    "hachoo_island": ["shell_house", "beach_hut", "fisher_shack", "juice_shack"],
    "genie_desert": ["lamp_house", "well_house", "dome_house", "market_tent", "pavilion_tent", "adobe_house"],
    "secret_plain": ["flag_tower", "horse_stable", "yurt", "desert_tent"],
    "crystal_mountain": ["crystal_lodge", "lookout_hut", "stone_hut"],
    "moonglow": ["moon_teahouse", "star_dome", "stone_hut", "snow_cabin"],
    "valley_of_fear": ["apothecary", "creaky_mill", "crooked_house", "witch_hut"],
    "wolf_lair": ["straw_house", "stick_house", "brick_house", "crooked_house"],
    "candy_mountain": ["cupcake_house", "ice_cream_parlour", "candy_cottage", "mushroom_house_gold", "bakery"],
    "puppet_hill": ["toymaker_workshop", "music_box_house", "crooked_house", "witch_hut"],
    "sleepy_town": ["sleepy_cottage", "sleepy_cottage_lilac", "mushroom_house_blue", "mushroom_house"],
    "emerald_road": ["house_green", "forest_lodge"],
    "water_temple": ["stone_hut"],
}


def lands_to_fill(data):
    for land in data["maps"]:
        if "cave" in land["theme"] or land.get("fence") or land.get("town"):
            continue
        if land["id"] == "starfall_isle":      # Glimmerbough, a village already
            continue
        yield land


def pool_for(land):
    if land["id"] in POOLS:
        return POOLS[land["id"]]
    own = [b["art"] for b in land.get("buildings") or [] if b["art"] not in UNIQUE and not b.get("size")]
    return list(dict.fromkeys(own))


def plan(data, world):
    lands = {m["id"]: m for m in data["maps"] if "cave" not in m["theme"]}
    own, sea, wet, away = wl.unpack(world, lands)
    found = {}
    for land in lands_to_fill(data):
        lid = land["id"]
        kept = [b for b in land.get("buildings") or [] if not b.get("hamlet")]
        need = wanted(land) - len(kept)
        pool = pool_for(land)
        if need <= 0 or not pool:
            continue
        x0, y0 = world["lands"][lid]
        mc, mr = world["middles"][lid]
        middle = (x0 + mc, y0 + mr)
        cells = own[lid]
        water = wet[lid]
        # Nothing else set down by hand; the hamlets' own and the land's buildings kept apart less.
        others = [(middle[0] + dx, middle[1] + dy) for (dx, dy), what in wl.content_spots(land) if not what.startswith("building")]
        houses = [(middle[0] + b["x"], middle[1] + b["y"]) for b in kept]
        roads = world["roads"].get(lid, {})
        crossings = {to: (x0 + r["at"][0], y0 + r["at"][1]) for to, r in roads.items()}
        routes = {to: r.get("via") for to, r in roads.items()}
        intos = {to: r["into"] for to, r in roads.items() if "into" in r}
        lines = [stops for what, stops in wl.road_lines(lid, land, middle, crossings, routes, intos) if "road" in what]

        def fits(spot):
            x, y = spot
            m = wl.CONTENT_MARGIN
            if not all((x + i, y + j) in cells for i in range(-m, m + 1) for j in range(-m, m + 1)):
                return False
            r = wl.RIVER_CONTENT + m
            if any((x + i, y + j) in water for i in range(-r, r + 1) for j in range(-r, r + 1)):
                return False
            if any(math.dist(spot, o) < KEEP for o in others):
                return False
            if any(math.dist(spot, h) < KEEP_BUILDING for h in houses):
                return False
            return True

        rng = random.Random(lid)
        starts = []
        for stops in lines:
            points = wl.along(stops)
            hub = points[0]
            walked = 0.0
            for (ax, ay), (bx, by) in zip(points, points[1:]):
                walked += math.dist((ax, ay), (bx, by))
                if REACH[0] <= walked <= REACH[1] and int(walked * 2) % 8 == 0:
                    starts.append((walked, (ax, ay), (bx - ax, by - ay), points))
        rng.shuffle(starts)
        added, firsts = [], []
        for walked, (ax, ay), (dx, dy), points in starts:
            if len(added) >= need:
                break
            if any(math.dist((ax, ay), f) < APART for f in firsts):
                continue
            length = math.hypot(dx, dy) or 1
            ux, uy = dx / length, dy / length          # along the road
            px, py = -uy, ux                           # across it
            hamlet = []
            for k in range(HAMLET):
                side = 1 if k % 2 == 0 else -1
                along_by = (k // 2) * SPACING + (SPACING / 2 if side < 0 else 0)
                off = rng.uniform(*OFFSET)
                spot = (round(ax + ux * along_by + px * off * side), round(ay + uy * along_by + py * off * side))
                if fits(spot) and all(math.dist(spot, h) >= KEEP_BUILDING for h in hamlet):
                    hamlet.append(spot)
                    houses.append(spot)
            if len(hamlet) >= 3:
                firsts.append((ax, ay))
                for spot in hamlet[:need - len(added)]:
                    added.append(spot)
            else:
                for spot in hamlet:
                    houses.remove(spot)
        arts = []
        order = pool[:]
        rng.shuffle(order)
        for n, _ in enumerate(added):
            arts.append(order[n % len(order)])
        found[lid] = [{"art": a, "x": s[0] - middle[0], "y": s[1] - middle[1], "hamlet": True} for a, s in zip(arts, added)]
    return found


def write(found):
    """Each land's buildings: its own kept, then the hamlets', in the file's own layout (one entry a block)."""
    lines = MAPS.read_text().split("\n")
    data = json.loads(MAPS.read_text())
    for land in data["maps"]:
        if land["id"] not in found and not any(b.get("hamlet") for b in land.get("buildings") or []):
            continue
        start = next(i for i, l in enumerate(lines) if l.strip() == f'"id": "{land["id"]}",')
        open_at = next(i for i in range(start, len(lines)) if lines[i].strip() == '"buildings": [')
        indent = lines[open_at][:len(lines[open_at]) - len(lines[open_at].lstrip())]
        close_at = next(i for i in range(open_at + 1, len(lines)) if lines[i] == indent + "]" or lines[i] == indent + "],")
        kept = [b for b in land["buildings"] if not b.get("hamlet")] + found.get(land["id"], [])
        inner = indent + "  "
        block = []
        for n, b in enumerate(kept):
            body = json.dumps(b, indent=2, ensure_ascii=False).split("\n")
            body = [inner + line for line in body]
            if n < len(kept) - 1:
                body[-1] += ","
            block += body
        lines[open_at + 1:close_at] = block
    MAPS.write_text("\n".join(lines))


def main(argv):
    data = json.loads(MAPS.read_text())
    world = json.loads(wl.WORLD.read_text())
    found = plan(data, world)
    for lid, added in found.items():
        print(f"{lid}: +{len(added)} " + ", ".join(f"{b['art']}@{b['x']},{b['y']}" for b in added))
    if "--dry-run" not in argv:
        write(found)
        print(f"added {sum(len(a) for a in found.values())} buildings to {len(found)} lands")


if __name__ == "__main__":
    main(sys.argv[1:])
