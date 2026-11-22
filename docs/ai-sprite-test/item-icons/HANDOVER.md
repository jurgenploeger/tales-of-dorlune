# Item icons by ChatGPT (2026-11-22)

The user, 2026-11-22: "Can we now update our old item icons?" 328 of the 504 item icons are drawn in code
(`tools/item_art.py`, a 32-pixel design finished at 64 by `pixel_kit.restyle(clean=True)`); they read plainer
than Retro Diffusion's, and some families are one shape in many colours (the capes, the whips, the gauntlets).
RD's icons (the weapons `weapon_art.py PICKED`, the armour `armour_art.py`, the potions) stay as they are.

Redraws, not new items: each keeps what it is (the attached 8× picture: its shape, colours by name, what's on
it), drawn in RD's look (`style_reference_rd_4x.png`: the Potion, a blade, two plates, a cloak, a robe, two axes).
A family that's one design in many colours (the land capes, the copper to topaz set pieces) is drawn once and
recoloured in code to each, as `item_art.py` derives them now.

Held to docs/pixel-style.md *Item icons: the clean look* by `pixel_style.py check --kind item` (or `rd_item`,
size and outline only, as RD's are) and by eye beside RD's Potion.

## How to run it

One chat per batch in the ChatGPT project, `style_reference_rd_4x.png` and that batch's `_8x.png` attached in
the list's order, the **prompt** pasted with the batch's list in place of `[LIST]`. Send "next" after each.

## The prompt

> Redraw these item icons from my game, one at a time, as the project's instructions say. Each attached 8×
> picture is today's icon: keep what it is (its shape, its colours by name, what's on it), and draw it in the
> look of the attached style sheet: Retro Diffusion's icons at 4× (the potion, a sword, armour, a cloak, axes).
> That's the look to match exactly: chunky and rich, smooth broad shading lit from the top left with bright
> highlights and deep, slightly coloured shadows, a one-pixel outline in a deep shade of each thing's own
> colour (never black), no dithering or grain, no glow round it.
>
> Every icon: a 64 × 64 canvas, transparent, alpha 0 or 255 only; the item centred and filling the tile (about
> 52 to 62 pixels across its longer side, as the style sheet's do); seen as the sheet's are; 25 to 45 colours;
> nothing else in the picture (no background, shadow, sparkles off the item or text).
>
> [LIST]
>
> For each: say its size and colour count, then deliver its 1× PNG named by its id and the 8× preview, then the
> next.

## Batch 1: capes and gloves (18)

1. `sunny_meadow_cape`: a land's cape, a short cape with a round gold clasp at the collar and a gold badge on
   its back; drawn once in this land's green and gold, the game recolours it for every other land.
2. `monster_book_cape`: for beating every kind of monster: a deep cape with a book stitched on its back.
3. `card_collector_cape`: for holding every monster card: a cape patterned like a deck of cards.
4. `quest_cape`: for finishing every quest: a cape stitched with little figures of everyone you helped.
5. `bossbane_cape`: for beating every boss: a dark, fierce cape with a crowned skull badge.
6. `wayfarer_cape`: for setting foot in every land: a travel-worn cape, its hem dusty, a compass clasp.
7. `storyleaf_cape`: the Dorlune Cape, for earning every other cape: the grandest, gold-trimmed, a leaf badge.
8. `beastfriend_cape`: for raising a companion to level 200: a cape with a paw-print badge, fur at the collar.
9. `legend_cape`: for reaching level 200: a regal cape with a star badge and gold trim.
10. `copper_gauntlets`: a gauntlet in warm copper from an armour set; drawn once, recoloured to silver, onyx,
    sapphire, jade, aquamarine, ruby, amethyst and topaz.
11. `leather_gloves`: soft brown leather gloves, a first grip.
12. `iron_gauntlets`: heavy iron gauntlets, big knuckles.
13. `falcon_gloves`: a falconer's long leather glove, a feather on the cuff.
14. `dragonhide_gauntlets`: red scaled gauntlets, warm from the dragon.
15. `starforged_gauntlets`: dark steel gauntlets with a star set in the back.
16. `starpetal_gauntlets`: silver gauntlets set with crystal petals.
17. `prospectors_gloves`: thick leather gloves with brass knuckles.
18. `orchard_gloves`: soft green picking gloves, a leaf on the cuff.

## The batches after

Batch 2: the other five gloves, the boots (13 of their own and the set's), the 18 accessories. Then the hats
and helms (65), the necklaces (15), the weapons drawn in code (26: whips, wands, staffs), the consumables (13),
and the materials (111) in four or five batches. About 270 drawings in all.

## Results
- **Capes** (2026-11-22, three rounds): asked to keep each icon's shape, ChatGPT kept today's lumpy blob and
  pasted a badge on (round 1, all nine under the soft bar); told to draw real capes, it did, but four drifted off
  their item's `color` (the colour the cape is worn in) and each came out a shape of its own (round 2). Round 3:
  one cape shape for the family (the collar, puffed shoulders, gold clasp, straight sides to a scalloped hem, the
  badge in the middle), each in its item's colours, delivered at 64 or as big pictures snapped back to the grid
  (`ai_sprite_eval.py --canvas 64`, about 20 screen pixels to one). Soft scores are low (42 to 92%: ChatGPT's
  outline and inner band aren't the clean finish's), but by eye beside RD's Potion they're the step up; in, all
  nine (`item_art.py CHATGPT`), and the 27 other land capes recoloured from Sunny Meadow's (`recolour_cape`: its
  green cloth onto the land's `color`, its gold onto its `accent`). The gloves are still to come.
