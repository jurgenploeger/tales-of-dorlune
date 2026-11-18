import data from '../data/game.json';

export type Ref = { slug: string; name: string };
export type Stats = { hp: number; mp: number; attack: number; defense: number; magic: number; speed: number };
export const game = data as any;

export const STAT_NAMES: Record<string, string> = {
  hp: 'HP', mp: 'MP', attack: 'Attack', defense: 'Defence', magic: 'Magic', speed: 'Speed',
};
export const STATS = Object.keys(STAT_NAMES);

/** Water beats fire beats metal beats wood beats earth beats water; light and dark beat each other. */
const CYCLE = ['water', 'fire', 'metal', 'wood', 'earth'];
export const ELEMENTS = [...CYCLE, 'light', 'dark'];
export function strongAgainst(e: string): string[] {
  if (e === 'light') return ['dark'];
  if (e === 'dark') return ['light'];
  const i = CYCLE.indexOf(e);
  return i < 0 ? [] : [CYCLE[(i + 1) % CYCLE.length]];
}
export function weakTo(e: string): string[] {
  if (e === 'light') return ['dark'];
  if (e === 'dark') return ['light'];
  const i = CYCLE.indexOf(e);
  return i < 0 ? [] : [CYCLE[(i + CYCLE.length - 1) % CYCLE.length]];
}

export const cap = (s: string) => (s ? s[0].toUpperCase() + s.slice(1) : s);
export const num = (n: number) => n.toLocaleString('en-GB');
export function pct(p: number) {
  const v = p * 100;
  return (v >= 10 || Number.isInteger(v) ? Math.round(v) : Math.round(v * 10) / 10) + '%';
}
export const levels = (l?: number[] | null) => (!l ? '' : l[0] === l[1] ? `${l[0]}` : `${l[0]}–${l[1]}`);
/** A monster's stat at a level: base + growth × (level − 1). */
export const statAt = (m: any, stat: string, level: number) => m.base[stat] + m.growth[stat] * (level - 1);

export const ITEM_TYPES: Record<string, string> = {
  consumable: 'Potions and tools', weapon: 'Weapons', armor: 'Armour', head: 'Hats and helmets',
  gloves: 'Gloves', boots: 'Boots', necklace: 'Necklaces', accessory: 'Rings and charms',
  cape: 'Capes', material: 'Materials',
};
export const ITEM_TYPE: Record<string, string> = {
  consumable: 'Consumable', weapon: 'Weapon', armor: 'Armour', head: 'Hat', gloves: 'Gloves',
  boots: 'Boots', necklace: 'Necklace', accessory: 'Accessory', cape: 'Cape', material: 'Material',
};
export const CLASS_NAMES: Record<string, string> = { fighter: 'Fighter', mage: 'Mage', tamer: 'Beast Tamer', novice: 'Novice' };
export const LAND_KIND: Record<string, string> = { town: 'Town', wild: 'Wild land', cave: 'Cave' };

/** What a quest asks, as a sentence. */
export function objective(q: any): string {
  const o = q.objective;
  const n = o.count ?? 1;
  switch (o.type) {
    case 'defeat': return o.monster ? (n === 1 ? `Defeat ${o.monster.name}` : `Defeat ${n} × ${o.monster.name}`) : `Win ${n} ${n === 1 ? 'battle' : 'battles'}`;
    case 'capture': return o.monster ? `Befriend ${n === 1 ? '' : n + ' × '}${o.monster.name} with a Seal Stone` : `Befriend ${n} ${n === 1 ? 'monster' : 'monsters'} with a Seal Stone`;
    case 'hatch': return 'Hatch your Pet Egg from the Bag';
    case 'reachLevel': return `Reach level ${n}`;
    case 'chooseClass': return 'Join a guild and choose your path';
    case 'cards': return `Collect ${n} kinds of monster card in your Monster Book`;
    case 'bring': return o.item ? `Bring ${n === 1 ? '' : n + ' × '}${o.item.name}` : `Bring ${n}`;
    case 'deliver': return `Take ${o.item ? o.item.name : 'a delivery'} to ${o.to ? `${o.to.name} in ${o.to.land.name}` : 'its owner'}${o.returns ? `, and bring back ${o.returns.name}` : ''}`;
    default: return cap(o.type);
  }
}

export const sortBy = <T,>(list: T[], key: (t: T) => number | string) =>
  [...list].sort((a, b) => (key(a) < key(b) ? -1 : key(a) > key(b) ? 1 : 0));
export const monstersByLevel = sortBy(game.monsters, (m: any) => (m.level ? m.level[0] : 999) * 1000 + (m.boss ? 500 : 0));
export const wildLands = sortBy(game.lands.filter((l: any) => l.levels), (l: any) => l.levels[0]);
export const questsByLevel = sortBy(game.quests, (q: any) => q.minLevel);

/** What a beaten monster gives at a level (BattleController: EXP grows 35% a level, gold 25%). */
export const expAt = (m: any, level: number) => Math.round(m.exp * (1 + 0.35 * (level - 1)));
export const goldAt = (m: any, level: number) => Math.round(m.gold * (1 + 0.25 * (level - 1)));
export const span = (a: number, b: number) => (a === b ? num(a) : `${num(a)}–${num(b)}`);
/** How willing a monster is to be befriended. Its real odds also depend on its wounds, levels and the stone. */
export function ease(rate: number): string {
  if (!rate) return 'Never';
  if (rate >= 0.45) return 'Easy';
  if (rate >= 0.25) return 'Medium';
  if (rate >= 0.12) return 'Hard';
  return 'Very hard';
}
/** EXP from one level to the next (GameSession.expToNext). */
export function expToNext(level: number): number {
  const base = 10 + level * level * 5;
  return level > 100 ? Math.round(base * (1 + (level - 100) / 40)) : base;
}
