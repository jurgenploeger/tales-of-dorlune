#!/usr/bin/env python3
"""Exports the game's content and sprites for the website (tales-of-dorlune.com).

    pip install pillow numpy
    python3 website/tools/export.py

Reads content/*.json and art/ and writes website/src/data/game.json (every monster, land, quest,
item, class and skill, cross-linked) and website/public/sprites/ (each sprite the site shows, a
derived one recoloured as the game does at load time, tools/palette_preview.py `raw`). The output
is committed, so the site builds with Node alone. Rerun it after the content or art changes.

URLs are made from the names players see, never from content ids: some ids keep old names.
"""
import json, os, re, sys, shutil
from collections import defaultdict
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SITE = os.path.join(ROOT, 'website')
OUT = os.path.join(SITE, 'src', 'data')
SPRITES = os.path.join(SITE, 'public', 'sprites')
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import palette_preview as pp  # noqa: E402  (its `raw` builds a derived sprite)


def load(name):
    return json.load(open(os.path.join(ROOT, 'content', name + '.json')))


def slugify(name):
    s = name.lower().replace("'", '').replace('’', '')
    return re.sub(r'[^a-z0-9]+', '-', s).strip('-')


def slugs(entries, name_key='name'):
    """A slug for each entry's id, from its name; a second of the same name takes its id's words too."""
    seen, out = {}, {}
    for e in entries:
        s = slugify(e[name_key])
        if s in seen:
            s = slugify(e[name_key] + ' ' + e['id'].replace('_', ' '))
        seen[s] = True
        out[e['id']] = s
    return out


# ---------- sprites ----------
def crop(im):
    box = im.getbbox()
    return im.crop(box) if box else im


def sprite(art, folder, name):
    """Writes art's picture (a walk sheet's standing pose facing you) to sprites/<folder>/<name>.png."""
    path = os.path.join(SPRITES, folder, name + '.png')
    try:
        arr = pp.raw(art)
    except Exception:
        return None
    im = Image.fromarray((np.clip(arr, 0, 1) * 255).round().astype(np.uint8), 'RGBA')
    asset = pp.assets.get(art, {})
    base = pp.assets.get((asset.get('derive') or {}).get('from'), {})
    if (asset.get('kind') or base.get('kind')) == 'walk_sheet' or im.size == (192, 192):
        frame = im.width // 4
        im = im.crop((0, 2 * frame, frame, 3 * frame))  # rows: up, right, down, left
    im = crop(im)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, optimize=True)
    return {'src': f'/sprites/{folder}/{name}.png', 'w': im.width, 'h': im.height}


def world_map(maps, world, l_slug):
    """Paints the continent from world.json's shapes (each land in its ground's colour, rivers and
    borders over it) to public/world.png, and returns where each land's middle is, as shares of it."""
    margin = world['margin']
    by = {m['id']: m for m in maps}
    boxes = {k: (x - margin, y - margin, by[k]['width'] + 2 * margin, by[k]['height'] + 2 * margin)
             for k, (x, y) in world['lands'].items()}
    x0 = min(b[0] for b in boxes.values()); y0 = min(b[1] for b in boxes.values())
    W = max(b[0] + b[2] for b in boxes.values()) - x0; H = max(b[1] + b[3] for b in boxes.values()) - y0
    owner = np.zeros((H, W), int); river = np.zeros((H, W), bool)
    colours = [(0, 0, 0)]
    for n, (k, (bx, by_, bw, bh)) in enumerate(boxes.items(), 1):
        theme = by[k]['theme']
        tile = pp.grade(pp.raw(theme['ground']), theme.get('palette'))
        colours.append(tuple(tile[..., :3].reshape(-1, 3).mean(0)))
        for row, runs in enumerate(world['regions'][k]):
            x = 0
            for code, length in zip(runs[::2], runs[1::2]):
                if code in (1, 3):
                    owner[by_ - y0 + row, bx - x0 + x: bx - x0 + x + length] = n
                    if code == 3: river[by_ - y0 + row, bx - x0 + x: bx - x0 + x + length] = True
                x += length
    rgb = np.array(colours)[owner]
    rgb[river] = (0.36, 0.68, 0.93)
    land = owner > 0
    edge = np.zeros_like(land)
    for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        other = np.roll(owner, (dy, dx), (0, 1))
        edge |= land & (other != owner)
    rgb[edge & ~river] *= 0.72
    img = np.dstack([rgb, land.astype(float)])[::-1]   # rows run from the south
    im = Image.fromarray((img.clip(0, 1) * 255).round().astype(np.uint8), 'RGBA')
    box = im.getbbox(); im = im.crop(box)
    im.resize((im.width * 2, im.height * 2), Image.NEAREST).save(os.path.join(SITE, 'public', 'world.png'), optimize=True)
    spots = {}
    for k, (bx, by_, bw, bh) in boxes.items():
        ys, xs = np.nonzero(owner == list(boxes).index(k) + 1)
        # The label sits at the middle of the land's own cells, not of its box.
        cx, cy = np.median(xs), H - 1 - np.median(ys)
        spots[l_slug[k]] = [round(float((cx - box[0]) / (box[2] - box[0])), 4), round(float((cy - box[1]) / (box[3] - box[1])), 4)]
    return {'w': im.width * 2, 'h': im.height * 2, 'spots': spots}


def main():
    monsters = load('monsters')['monsters']
    maps = load('maps')['maps']
    quests = load('quests')['quests']
    items = load('items')['items']
    skills = load('skills')['skills']
    classes = load('classes')
    titles = load('titles')['titles']
    changelog = load('changelog')['releases']
    languages = load('i18n/languages')['languages']
    world = load('world')

    for folder in ('monsters', 'items', 'skills', 'people', 'heroes'):
        shutil.rmtree(os.path.join(SPRITES, folder), ignore_errors=True)

    m_slug, l_slug = slugs(monsters), slugs(maps)
    q_slug, i_slug = slugs(quests, 'title'), slugs(items)
    s_slug = slugs(skills)
    m_by, i_by, q_by, map_by = ({e['id']: e for e in lst} for lst in (monsters, items, quests, maps))
    s_by = {s['id']: s for s in skills}

    def mref(i): return {'slug': m_slug[i], 'name': m_by[i]['name']}
    def iref(i):
        base = i.split('~')[0]
        return {'slug': i_slug[base], 'name': i_by[base]['name']}
    def qref(i): return {'slug': q_slug[i], 'name': q_by[i]['title']}
    def lref(i): return {'slug': l_slug[i], 'name': map_by[i]['name']}
    def froms(d): return [mref(f) for f in (d['from'] if isinstance(d['from'], list) else [d['from']]) if f in m_by]

    # ---------- where things are ----------
    found = defaultdict(list)         # monster -> lands
    boss_at = {}                      # monster -> (land, npc)
    npc_at = {}                       # npc id -> (land, npc)
    sold = defaultdict(list)          # item -> shops
    chests = defaultdict(list)        # item -> lands
    for mp in maps:
        enc = mp.get('encounters') or {}
        total = sum(enc.get('monsters', {}).values()) or 1
        for mid, weight in enc.get('monsters', {}).items():
            found[mid].append({**lref(mp['id']), 'levels': enc.get('levels'), 'share': round(weight / total, 3)})
        for npc in mp['npcs']:
            npc_at[npc['id']] = (mp, npc)
            if npc.get('role') == 'boss':
                boss_at[npc['monster']] = (mp, npc)
            for it in npc.get('stock', []):
                sold[it].append({'shop': npc['name'], **{'land': lref(mp['id'])}})
            if npc.get('role') == 'chest' and npc.get('gives'):
                chests[npc['gives']].append(lref(mp['id']))

    dropped = defaultdict(list)       # item -> bosses
    for mo in monsters:
        for d in mo.get('drops', []):
            dropped[d['item'].split('~')[0]].append({**mref(mo['id']), 'chance': d['chance']})
    quest_drops = defaultdict(list)   # item -> quests whose monsters drop it
    rewarded = defaultdict(list)      # item -> quests
    wanted = defaultdict(list)        # item -> quests that ask for it
    for q in quests:
        for d in q.get('drops', []):
            quest_drops[d['item']].append({'quest': qref(q['id']), 'from': froms(d), 'chance': d['chance']})
        for it in sorted(set(q['reward'].get('items', []))):
            rewarded[it.split('~')[0]].append(qref(q['id']))
        for it in q.get('starterItems', []):
            rewarded[it].append(qref(q['id']))
        o = q['objective']
        ask = o.get('item') if o['type'] == 'deliver' else o.get('target') if o['type'] == 'bring' else None
        if ask in i_by:
            wanted[ask].append(qref(q['id']))
    used_in = defaultdict(list)       # material -> items forged from it
    for it in items:
        for mat in (it.get('recipe') or {}):
            if mat in i_by:
                used_in[mat].append(iref(it['id']))
    unlocks = defaultdict(list)       # quest -> quests it opens
    for q in quests:
        for r in q.get('requires', []):
            unlocks[r].append(qref(q['id']))
    opens = defaultdict(list)         # quest -> roads it opens
    for mp in maps:
        for ex in mp['exits']:
            if ex.get('requires'):
                opens[ex['requires']].append({'from': lref(mp['id']), 'to': lref(ex['to'])})
    hunted = defaultdict(list)        # monster -> quests about it
    for q in quests:
        t = q['objective'].get('target')
        if q['objective']['type'] in ('defeat', 'capture') and t in m_by:
            hunted[t].append(qref(q['id']))
        for d in q.get('drops', []):
            for f in (d['from'] if isinstance(d['from'], list) else [d['from']]):
                if qref(q['id']) not in hunted[f]:
                    hunted[f].append(qref(q['id']))
    learned = defaultdict(list)       # skill -> classes
    for c in classes['classes']:
        for s in c['skills']:
            learned[s['skill']].append({'class': c['name'], 'slug': slugify(c['name']), 'level': s['level']})
    known = defaultdict(list)         # skill -> monsters
    for mo in monsters:
        for s in mo['skills']:
            known[s].append(mref(mo['id']))

    # ---------- monsters ----------
    out_monsters = []
    for mo in monsters:
        lands = sorted(found.get(mo['id'], []), key=lambda l: (l['levels'] or [0])[0])
        boss = None
        if mo['id'] in boss_at:
            mp, npc = boss_at[mo['id']]
            boss = {'land': lref(mp['id']), 'level': npc['level'], 'greeting': npc.get('greeting'),
                    'waves': npc.get('waves', 3), 'victory': npc.get('victory')}
        lows = [l['levels'][0] for l in lands if l['levels']]
        highs = [l['levels'][1] for l in lands if l['levels']]
        level = [boss['level'], boss['level']] if boss else ([min(lows), max(highs)] if lows else None)
        out_monsters.append({
            'slug': m_slug[mo['id']], 'name': mo['name'], 'element': mo['element'], 'lore': mo['lore'],
            'base': mo['base'], 'growth': mo['growth'], 'exp': mo['exp'], 'gold': mo['gold'],
            'captureRate': mo['captureRate'], 'rare': bool(mo.get('rare')), 'boss': bool(mo.get('boss')),
            'variantOf': mref(mo['variantOf']) if mo.get('variantOf') in m_by else None,
            'variants': [mref(o['id']) for o in monsters if o.get('variantOf') == mo['id']],
            'skills': [{'slug': s_slug[s], 'name': s_by[s]['name']} for s in mo['skills'] if s in s_by],
            'drops': [{**iref(d['item']), 'chance': d['chance']} for d in mo.get('drops', [])],
            'lands': lands, 'bossAt': boss, 'level': level, 'quests': hunted.get(mo['id'], []),
            'sprite': sprite(mo['art'], 'monsters', m_slug[mo['id']]),
        })

    # ---------- lands ----------
    order = {mp['id']: n for n, mp in enumerate(maps)}
    out_lands = []
    for mp in maps:
        enc = mp.get('encounters') or {}
        kind = 'town' if 'town' in mp else ('cave' if mp['id'] not in world['lands'] or mp.get('depth') else 'wild')
        total = sum(enc.get('monsters', {}).values()) or 1
        people, services, bosses = [], [], []
        for npc in mp['npcs']:
            role = npc.get('role')
            if role == 'quests':
                given = [qref(q['id']) for q in quests if q['giver'] == npc['id']]
                people.append({'name': npc['name'], 'greeting': npc.get('greeting'), 'quests': given,
                               'sprite': sprite(npc['art'], 'people', slugify(npc['name']))})
            elif role == 'boss':
                bosses.append({**mref(npc['monster']), 'level': npc['level']})
            elif role in ('shop', 'smith', 'healer', 'bank', 'barber', 'guild', 'weaver'):
                services.append({'name': npc['name'], 'role': role, 'greeting': npc.get('greeting'),
                                 'stock': [iref(i) for i in npc.get('stock', [])],
                                 'given': [qref(q['id']) for q in quests if q['giver'] == npc['id']]})
        out_lands.append({
            'slug': l_slug[mp['id']], 'name': mp['name'], 'kind': kind, 'levels': enc.get('levels'),
            'groupSize': enc.get('groupSize'), 'depth': mp.get('depth'),
            'climate': mp.get('climate'), 'danger': bool(mp.get('danger')),
            'monsters': sorted([{**mref(k), 'share': round(v / total, 3), 'rare': bool(m_by[k].get('rare')),
                                 'element': m_by[k]['element']} for k, v in enc.get('monsters', {}).items()],
                               key=lambda x: -x['share']),
            'bosses': bosses, 'people': people, 'services': services,
            'locals': [{'name': l['name'], 'lines': l.get('lines', [])} for l in mp.get('locals', [])],
            'waystone': any(n.get('role') == 'waystone' for n in mp['npcs']),
            'exits': [{**lref(ex['to']), 'edge': ex.get('edge'), 'ship': bool(ex.get('ship')),
                       'requires': qref(ex['requires']) if ex.get('requires') else None} for ex in mp['exits']],
            'start': mp['id'] == load('maps')['start'],
        })
    # A cave's deeper levels are reached by its ladder, not a road: link them in order.
    deep = [l for l in out_lands if l['depth']]
    for l in deep:
        above = next((o for o in out_lands if l['name'].startswith(o['name']) and not o['depth']), None) \
            or next((o for o in out_lands if 'Glimmerdeep' in o['name'] and not o['depth']), None)
        l['above'] = {'slug': above['slug'], 'name': above['name']} if above else None

    # ---------- quests ----------
    out_quests = []
    for q in quests:
        mp, npc = npc_at.get(q['giver'], (None, None))
        obj = dict(q['objective'])
        t = obj.get('target')
        if t in m_by: obj['monster'] = mref(t)
        if t in i_by: obj['item'] = iref(t)
        if obj['type'] == 'deliver':
            to_map, to_npc = npc_at.get(t, (None, None))
            obj['to'] = {'name': to_npc['name'], 'land': lref(to_map['id'])} if to_npc else None
            obj['item'] = iref(obj['item']) if obj.get('item') in i_by else None
            obj['returns'] = iref(obj['returns']) if obj.get('returns') in i_by else None
        reward_items = defaultdict(int)
        for it in q['reward'].get('items', []):
            reward_items[it] += 1
        out_quests.append({
            'slug': q_slug[q['id']], 'title': q['title'], 'description': q['description'],
            'giver': npc['name'] if npc else None, 'land': lref(mp['id']) if mp else None,
            'giverSprite': sprite(npc['art'], 'people', slugify(npc['name'])) if npc else None,
            'minLevel': q.get('minLevel', 1), 'difficulty': q.get('difficulty'),
            'objective': obj, 'question': q.get('question') and {
                'text': q['question']['text'],
                'answers': [{'text': a['text'], 'egg': mref(a['egg'])} for a in q['question']['answers']]},
            'starterItems': [iref(i) for i in q.get('starterItems', [])],
            'reward': {'gold': q['reward'].get('gold', 0), 'exp': q['reward'].get('exp', 0),
                       'items': [{**iref(k), 'count': v} for k, v in reward_items.items()]},
            'requires': [qref(r) for r in q.get('requires', [])],
            'unlocks': unlocks.get(q['id'], []), 'opens': opens.get(q['id'], []),
            'drops': [{'item': iref(d['item']), 'from': froms(d), 'chance': d['chance']} for d in q.get('drops', [])],
        })

    # ---------- items ----------
    out_items = []
    for it in items:
        recipe = it.get('recipe') or {}
        out_items.append({
            'slug': i_slug[it['id']], 'name': it['name'], 'type': it['type'], 'price': it['price'],
            'description': it['description'], 'level': it.get('level'), 'stats': it.get('stats'),
            'classes': it.get('classes'), 'heal': it.get('heal'), 'mp': it.get('mp'),
            'material': it.get('material'), 'tier': it.get('tier'), 'make': it.get('make'),
            'recipe': [{**iref(k), 'count': v} for k, v in recipe.items() if k in i_by] if isinstance(recipe, dict) else [],
            'recipeGold': recipe.get('gold') if isinstance(recipe, dict) else None,
            'soldAt': sold.get(it['id'], []), 'droppedBy': dropped.get(it['id'], []),
            'questDrops': quest_drops.get(it['id'], []), 'rewardOf': rewarded.get(it['id'], []),
            'wantedBy': wanted.get(it['id'], []), 'usedIn': used_in.get(it['id'], []),
            'chests': chests.get(it['id'], []),
            'sprite': sprite(it['art'], 'items', i_slug[it['id']]),
        })

    # ---------- classes and skills ----------
    out_skills = []
    for s in skills:
        out_skills.append({
            'slug': s_slug[s['id']], 'name': s['name'], 'mp': s['mp'], 'kind': s['kind'], 'power': s['power'],
            'target': s['target'], 'element': s.get('element'), 'description': s.get('description'),
            'classes': learned.get(s['id'], []), 'monsters': known.get(s['id'], []),
            'sprite': sprite(s['art'], 'skills', s_slug[s['id']]),
        })
    out_classes = [{
        'slug': slugify(c['name']), 'name': c['name'], 'guild': c.get('guild'), 'description': c['description'],
        'growth': c['growth'],
        'skills': [{'slug': s_slug[s['skill']], 'name': s_by[s['skill']]['name'], 'level': s['level'],
                    'description': s_by[s['skill']].get('description'), 'mp': s_by[s['skill']]['mp']}
                   for s in sorted(c['skills'], key=lambda s: s['level']) if s['skill'] in s_by],
        'master': next(({'name': n['name'], 'land': lref(mp['id'])} for mp in maps for n in mp['npcs']
                        if n.get('role') == 'guild' and n.get('classId') == c['id']), None),
    } for c in classes['classes']]
    out_races = [{'name': r['name'], 'description': r['description'], 'base': r['base'],
                  'sprite': sprite(r['art'], 'heroes', slugify(r['name']))} for r in classes['races']]

    game = {
        'version': changelog[0]['version'], 'date': changelog[0]['date'],
        'counts': {'lands': sum(1 for mp in maps if mp.get('encounters')), 'towns': sum(1 for mp in maps if 'town' in mp),
                   'monsters': len(monsters), 'bosses': sum(1 for mo in monsters if mo.get('boss')),
                   'quests': len(quests), 'items': len(items), 'skills': len(skills),
                   'languages': len(languages), 'maxLevel': 200},
        'classChoiceLevel': classes['classChoiceLevel'],
        'languages': [l['name'] for l in languages],
        'monsters': out_monsters, 'lands': out_lands, 'quests': out_quests, 'items': out_items,
        'skills': out_skills, 'classes': out_classes, 'races': out_races,
        'titles': [{k: t.get(k) for k in ('name', 'kind', 'count', 'rank')} for t in titles],
        'changelog': changelog,
        'world': world_map(maps, world, l_slug),
    }
    os.makedirs(OUT, exist_ok=True)
    json.dump(game, open(os.path.join(OUT, 'game.json'), 'w'), ensure_ascii=False, separators=(',', ':'))
    print({k: (len(v) if isinstance(v, list) else v) for k, v in game.items() if k not in ('changelog',)})
    missing = [e['name'] for lst in (out_monsters, out_items, out_skills) for e in lst if not e['sprite']]
    print('no sprite:', missing)


if __name__ == '__main__':
    main()
