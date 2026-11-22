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

## The land capes, drawn one by one (asked for 2026-11-22)

The user: "For the lands we need an original image from chatgpt because these recolours aren't that nice."
Attach `cape_family_4x.png` (the nine done, the shape to keep) and paste:

> Draw the capes of my game's lands, one at a time, all on exactly the same cape shape as the attached family
> (the collar, puffed shoulders with a highlight, the round clasp, straight sides falling to a scalloped hem, a
> badge in the middle). Each in its two colours, the first the cloth, the second the trim, clasp and badge, and
> with its own badge. Match the family's look and size exactly. Each at exactly 64 × 64, a 1× PNG, alpha 0 or 255
> only, then the next.

Chat 1: `northern_grassland_cape` (#9BBF6A, #F0F0E0, a windblown kite), `pineapple_shore_cape` (#F2B134, #3E9E5A,
a pineapple), `slime_cave_cape` (#59C9A5, #F5D94E, a smiling slime), `twilight_woods_cape` (#5B3FA6, #C9B8FF, a
crescent moon over a tree), `smiling_forest_cape` (#3F8F3A, #E8C468, a smiling acorn), `candy_mountain_cape`
(#F28DB2, #FFFFFF, a swirl lollipop), `frog_swamp_cape` (#5E7F3A, #9ED36A, a frog on a lily pad),
`wolf_lair_cape` (#5A5A66, #C0392B, a wolf's head), `swan_lake_cape` (#3FA7B5, #F7F7F7, a swan),
`valley_of_fear_cape` (#3B3F5C, #9CC9FF, a little ghost), `lotus_land_cape` (#C86FA8, #7FD18B, a lotus flower),
`rat_cavern_cape` (#6B5B4B, #C9A46B, a rat's head), `puppet_hill_cape` (#A0342F, #F2C14E, a puppet on strings),
`genie_desert_cape` (#E0A84F, #3A6EC4, a genie lamp).

Chat 2: `goldburg_lake_cape` (#D4AF37, #2E6DA4, crossed pickaxes over a wave), `crystal_mountain_cape` (#8FD3E8,
#FFFFFF, a crystal), `sleepy_town_cape` (#7E6BC4, #F5E7A1, a sleeping moon in a nightcap),
`snow_white_forest_cape` (#E8EEF7, #C0303C, a red apple), `moonglow_cape` (#2C3E7A, #F5E7A1, a full moon with a
rabbit), `secret_plain_cape` (#B5893F, #5C3A1E, a galloping horse), `hachoo_island_cape` (#E2563C, #2B2B2B, a
sneezing nose, a puff), `starfall_isle_cape` (#1F2A5C, #FFE680, a falling star), `glimmerdeep_cape` (#2A2160,
#9FE8FF, a glowing geode), `rosen_lake_cape` (#B0223F, #3F7A3A, a rose), `water_temple_cape` (#1E6FA8, #7FE3E0,
a conch shell), `mysterious_cave_cape` (#3A2E4F, #B9A6E0, an eye in the dark), `emerald_road_cape` (#1E9E5A,
#F2D16B, an emerald).
- **Land capes, first 15, and the leather gloves** (2026-11-22): asked for a 64-pixel PNG, ChatGPT drew two with code
  (8 and 13 colours, flat); asked to paint big with its image model instead, every one came back a 1254-pixel picture
  on a clean grid, snapped to 64 (`ai_sprite_eval.py --canvas 64`, 18 to 35 colours) and all one family, each land's
  badge on the cape shape of the nine. In: Pineapple Shore, the Gooey Grotto, Twilight Woods, Smiling Forest, Gumdrop
  Peaks, Frog Swamp, the Wolf's Lair, Swan Lake, Shiverdell, Lotus Land, Rat Cavern, Marionette Rise, Genie Desert,
  Ingothold Lake and the Hidden Steppe, and the leather gloves. Still recoloured from Sunny Meadow's till drawn:
  Windswept Downs (its kite cape to be redrawn with the front trim), Crystal Mountain, Dozywick, Snow White Forest,
  Moonwhisper, Sneezle Sands, Starfall Isle, the Glimmerdeep, Briarmere, Tidewater Shrine, the Whispering Hollow and
  Emerald Road.
