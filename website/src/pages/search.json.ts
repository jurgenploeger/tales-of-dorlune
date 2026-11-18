import { game, levels, ITEM_TYPE } from '../lib/game';

/** Everything the search page looks through: [name, url, what it is]. */
export function GET() {
  const rows: string[][] = [
    ...game.monsters.map((m: any) => [m.name, `/monsters/${m.slug}/`, m.boss ? 'Boss' : 'Monster']),
    ...game.lands.map((l: any) => [l.name, `/lands/${l.slug}/`, l.kind === 'town' ? 'Town' : `Land, levels ${levels(l.levels)}`]),
    ...game.quests.map((q: any) => [q.title, `/quests/${q.slug}/`, `Quest, level ${q.minLevel}`]),
    ...game.items.map((i: any) => [i.name, `/items/${i.slug}/`, ITEM_TYPE[i.type]]),
    ...game.skills.map((s: any) => [s.name, `/skills/#${s.slug}`, 'Skill']),
    ...game.classes.map((c: any) => [c.name, `/classes/#${c.slug}`, 'Class']),
    ['Start here', '/guide/start/', 'Guide'], ['Walkthrough', '/guide/walkthrough/', 'Guide'],
    ['Where to level', '/guide/leveling/', 'Guide'], ['Elements', '/guide/elements/', 'Guide'],
  ];
  return new Response(JSON.stringify(rows), { headers: { 'Content-Type': 'application/json' } });
}
