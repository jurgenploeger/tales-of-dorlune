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
- **The gloves and seven more capes** (2026-11-22): painted big, snapped to 64 (34 to 38 colours for the gloves),
  every one in its item's `color` (the colour it's worn in). In: the prospector's, starpetal, starforged,
  dragonhide, falcon and iron gloves, and the copper gauntlet, whose eight set colours (silver to topaz) are it
  recoloured (`item_art.SETS`, `recolour_set`: its hue family from 40 degrees redder, the copper's shadows, to 10
  yellower onto each set's `color`); and the capes of Emerald Road, the Whispering Hollow, Tidewater Shrine,
  Briarmere, the Glimmerdeep, Starfall Isle and Sneezle Sands. Still to come: the orchard gloves, and the capes of
  Windswept Downs (redo), Crystal Mountain, Dozywick, Snow White Forest and Moonwhisper.
- **The orchard gloves** (2026-11-22): in, which finishes the gloves batch 1 asked for. A second copper gauntlet came, a hair different; the first stays, as its eight recolours are checked.
- **The gloves' recolours** (2026-11-22): six gloves are palette swaps of others (the bricklayer's of the leather,
  the netcutter and shiverpeak of the falcon, the Craghulk and Sneezle ore of the dragonhide, the emerald crest of
  the starforged); with their bases ChatGPT's, they're its pictures recoloured to their own `color` (`item_art`,
  `recolour_set`), not the old drawings. `recolour_set` measured a hue's distance across 0 the long way (deep reds
  went green); fixed, the sets unchanged. All the gloves are done but RD's five (bell-ringer's, forgehand,
  pepperfire, crystal-silk and goldleaf), which stay.
- **The last five land capes** (2026-11-22): Windswept Downs (the kite redrawn, with the front trim), Crystal
  Mountain, Dozywick, Snow White Forest and Moonwhisper, painted big and snapped to 64 (21 to 30 colours), each in
  its item's `color` and `accent`. In; every land's cape is now ChatGPT's own, none recoloured from Sunny Meadow's
  (`recolour_cape` stays for a land added later). A second orchard glove came, the same pixel for pixel as the first.

## Batch 2: boots and accessories (32, asked for 2026-11-22)

Two chats: boots (1 to 14), then accessories (15 to 32). Attach `style_reference_rd_4x.png`, then that chat's
`batch2/NN_<id>_8x.png` in order. Painted big, as the capes and gloves that worked were (asked for a 64-pixel
PNG, ChatGPT draws with code: flat, 8 to 13 colours); they're snapped to 64 here. Not in it: what's a palette
swap of one of these (the bunny-hop and marquis boots of the leather, the moonbeam slippers of the speed boots,
the silverfang and frostpeak of the cloudstep; the piper's ring of the power band; the stardust, emerald heart
and firepeak rings of the ruby ring: each is recoloured from ChatGPT's base), the set boots silver to topaz
(the copper pair recoloured, `SETS`), and the lucky clover (`clean_icon_art.py`).

> Redraw these item icons from my game, one at a time. Each attached 8× picture is today's icon: keep what it
> is (its shape, its colours, what's on it), but draw it far better, in the look of the attached style sheet
> (Retro Diffusion's icons at 4×): chunky and rich, smooth broad shading lit from the top left, bright
> highlights, deep, slightly coloured shadows, a one-pixel outline in a deep shade of each part's own colour
> (never black), no dithering, no glow round it.
>
> Paint each with your image model, not with code: one big square picture (about 1024 pixels or more) of a
> 64 × 64 pixel-art icon, every art pixel a crisp square block of one colour, the item centred and filling the
> square (52 to 62 art pixels across its longer side), seen as the sheet's are, 25 to 45 colours, on a plain
> flat background with nothing else (no shadow, sparkles off the item or text).
>
> Keep each family one shape, as a set: the boots all drawn as one pair seen the same way (side by side, toes
> to the left, a little from above), the rings all one ring seen the same way with its stone or ornament on
> top, the charms each hanging from the same small loop. Each in its own colours, as listed.
>
> [LIST]
>
> One at a time; I'll say "next".

Chat 1, boots:
1. `speed_boots`: blue winged speed boots (#3A86E8), little white wings at the ankles.
2. `straw_sandals`: woven straw sandals (#DCC060).
3. `leather_boots`: brown laced leather boots (#9A6232). Plain: other boots are recoloured from it.
4. `traveler_boots`: green traveller boots with gold laces (#46B848), worn from the road.
5. `cloudstep_boots`: white boots standing on a little cloud (#FFFFFF, pale blue shading).
6. `glimmerwing_boots`: violet boots with little moth wings at the heels (#8A5AE8).
7. `windstep_sandals`: light tan sandals laced with red kite string and a little feather (#C49058).
8. `peppermint_boots`: red and white striped peppermint boots (#E0384A).
9. `bogwalker_boots`: tall mossy green waders (#5E8A36).
10. `ratcatcher_boots`: tall olive-brown boots covered in scales (#8A7438).
11. `dozy_slippers`: fluffy lavender slippers with pompoms (#8A6AB8).
12. `steppe_runner_boots`: soft tan hide boots with red woven bands (#C49058).
13. `goldleaf_boots`: ivory boots with gold cuffs and a golden leaf at each heel (#ECE2C8).
14. `copper_boots`: plate boots in warm copper (#B8733A), to match the copper gauntlets; recoloured to eight
    other metals and gems, so one main colour.

Chat 2, accessories:
15. `ruby_ring`: a gold ring with a red ruby. Other rings are recoloured from it.
16. `novice_ring`: a simple copper ring with a small blue stone.
17. `star_charm`: a gold star charm on a small loop.
18. `power_band`: a red wristband with steel studs. The piper's ring is recoloured from it.
19. `golden_ball_charm`: a small shining golden ball with a band and a ruby, on a small loop.
20. `dragon_tooth_charm`: a curved ivory dragon fang capped in gold with a ruby, on a small loop.
21. `persimmon_charm`: a small orange persimmon with a green four-leaf cap, on a small loop.
22. `gumdrop_star_charm`: a plump pink star-shaped gumdrop rolled in sugar, on a small loop.
23. `stargazer_band`: a night-blue silver ring with a tiny gold star.
24. `honeybee_charm`: a little golden honeycomb with a tiny bee, on a small loop.
25. `red_hood_ribbon`: a bright red ribbon tied in a bow.
26. `swan_feather_brooch`: a white swan feather with a silver pin.
27. `lotus_dew_charm`: a small pink lotus bud with a dew drop at its heart, on a small loop.
28. `genies_ring`: a gold ring with a blue gem swirling with smoke.
29. `seven_hearths_ring`: a gold ring set with seven tiny gems of different colours.
30. `moon_rabbit_charm`: a silver rabbit sitting in a crescent moon, on a small loop.
31. `tidesong_ring`: a sea-green silver ring with a small wave on top.
32. `goldleaf_ring`: a gold ring with a leaf curled over the top, still green at the tip.

## Results, batch 2
- **Boots and accessories** (2026-11-22): 31 of the 32, painted big on grey and snapped to 64 (17 to 39 colours).
  The grey had to be cleared everywhere it showed first: the tool clears the background only from the corners,
  and a ring's hole is enclosed. Where ChatGPT drew one twice (the traveller, leather and speed boots), the later
  is in and the first kept as `chatgpt_0.png`. The copper boots are recoloured to the eight set colours as the
  gauntlets are (`SETS`); every palette swap of one of these is ChatGPT's picture recoloured: by its item's
  `color` (the bunny-hop, marquis, moonbeam, silverfang and frostpeak boots) or, with no `color`, by its own
  `derive` rules (the piper's, stardust, emerald heart and firepeak rings). Still to come: the seven hearths ring.

## Batch 3: hats and helms (10 drawings for 65 icons, asked for 2026-11-22)

Every hat that goes with an armour is today one of six shapes in its item's `color` (`item_art.hat_piece`): a
domed helm, a horned dragon helm, a wizard's hat with its tip bent over, a mail coif, a hood, a fur-lined hood.
None has a detail of its own, so ChatGPT draws each shape once and the rest are its picture recoloured to their
`color`, as the set gloves and boots are (`SETS` and the derive loop): one shape per family, guaranteed. The
party hats and the masks the same, from the red hat and the green mask; the Santa hat and bunny ears are their
own. Attach `style_reference_rd_4x.png` and `batch3/NN_<id>_8x.png` in order; the same prompt as batch 2, with:

> Each one is drawn once and recoloured in code to many others, so keep its main material one colour family
> (its shading in that hue), and its trim, horns or band in gold, apart from it.

1. `copper_helm`: a domed helm with cheek guards, eye slits, a nose guard and a crest, in warm copper (#B8733A),
   gold trim and rivets. Recoloured to the iron, golden, oxhide and goldleaf helms and the eight set helms.
2. `dragon_helm`: the same helm in red dragon scale (#E93220) with two gold horns sweeping up and out.
   Recoloured to the golden, azure, emerald, wavecrest and prismscale dragon helms.
3. `copper_hat`: a wizard's hat, a wide brim, its tip bent over, a gold band and a small gold star, in warm copper
   (#B8733A). Recoloured to the silk, mage, dawn, moonlight, briar rose, Liora's, starweave and goldleaf hats and
   the eight set hats.
4. `chain_coif`: a mail coif falling to the shoulders, its face opening in shadow, steel grey (#80929A).
   Recoloured to the gilded coif and the puppeteer's cowl.
5. `ranger_hood`: a soft peaked hood falling in folds to the shoulders, its opening in shadow, forest green
   (#2D5425). Recoloured to the crimson ranger and howlmaster hoods.
6. `copper_hide_hood`: the same hood in warm copper hide (#B8733A), its opening lined with cream fur.
   Recoloured to the snow hoods and the eight set hide hoods.
7. `red_party_hat`: a red paper crown (#D83030) for a New Year party. Recoloured to the other five.
8. `green_halloween_mask`: a green ghoulish mask (#58B040), a wide toothy grin, purple eyes. Recoloured to the
   blue and red.
9. `santa_hat`: a red Santa hat (#D02828) with a white fur band and a white pom on its bent tip.
10. `bunny_ears`: soft white bunny ears (#F4F0F0) on a band, pink inside.
- **Hats and helms** (2026-11-22): all ten drawings (the bunny ears a little after), painted big and
  snapped to 64 (14 to 39 colours); the copper helm came twice, the later in (`chatgpt_0.png` the first). The 55
  others are recoloured from them (`item_art.HAT_FAMILIES`, `hat_family`): to each item's `color` by hue, as the
  sets are, the darkest pixels (a hood's opening, a helm's eye slits) keeping their darkness and taking only the
  new hue (`keep_dark`: on the pale snow hoods they had turned pale), the hide hood's cream fur left as drawn (its
  copper saturated, the fur not, `min_s`), and the grey mail coif tinted by brightness (`tint_grey`: the hue
  recolour skips grey). The trim stays gold on all, the eight silver-trimmed ones too.
