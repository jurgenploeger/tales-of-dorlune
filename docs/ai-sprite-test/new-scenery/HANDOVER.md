# New scenery for every land, by ChatGPT (2026-11-22)

Not redraws: props the game has never had, two for each wild land, so each land's scenery is its own. Many lands
share one prop list word for word (Sunny Meadow, Windswept Downs and Swan Lake; Pineapple Shore, Ingothold Lake and
Sneezle Sands; Genie Desert and the Hidden Steppe; Shiverdell and Marionette Rise; Twilight Woods, the Wolf's Lair
and Dozywick), and Tidewater Shrine wears Crystal Mountain's mine carts and ore.

The look to match is Retro Diffusion's own scenery, not ChatGPT's buildings: `style_reference_rd_4x.png` holds 21
of RD's props at 4× on grey, each at its own canvas, so the sizes read too. RD's props have far fewer colours than
a building (8 to 27; `pixel_style.json` scenery's median is 2.5 colours a 100 pixels, against a building's 0.6 to
1.2), so the prompt sets its own colour counts over the project instructions'.

## How to run it

One chat per batch in the ChatGPT project, `style_reference_rd_4x.png` attached, the **prompt** pasted with that
batch's list in place of `[LIST]`. Send "next" after each. Bring the PNGs back named by their id.

## The prompt

> Draw these new scenery props for my game, Tales of Dorlune, one at a time, as the project's instructions say,
> except where this message says otherwise. They're new, not redraws: there's no picture of them, so don't
> measure; the sizes are below. The attached sheet shows our scenery at 4× on grey, each at its own canvas:
> match its look exactly (chunky shapes, a dark tinted outline, broad shading lit from the top left, few
> colours, cute and a little storybook). Scenery, not buildings: smaller, simpler, fewer colours.
>
> Sizes, by the letter after each id:
> - **S**: a 32 × 32 canvas; the prop 18 to 28 wide, 16 to 28 tall, its lowest pixel on row 28. 10 to 24 colours.
> - **T** (tall): a 32 × 48 canvas; 12 to 26 wide, 30 to 42 tall, its lowest pixel on row 43. 10 to 22 colours.
> - **L** (large): a 64 × 64 canvas; 36 to 56 wide, 30 to 58 tall, its lowest pixel on row 59. 16 to 30 colours.
>
> Every one: transparent, alpha 0 or 255 only; seen from the front and a little from above, as the sheet's are;
> no ground, slab or shadow under it (a few grass tufts at its foot at most); no text. Draw it in natural
> colours: the game tints each land's art itself. Anything that gives light (a lamp, a torch, a jar of
> fireflies) has its flame or glow as a few bright pixels in it, no halo round it: the game adds the glow.
>
> [LIST]
>
> For each: say its size, foot row and colour count, then deliver its 1× PNG named by its id and the 8×
> preview, then the next.

## The list, in batches

`id` (size, land): what it is. Change any you don't like before sending.

**Batch A: green lands and the coast**
1. `flower_wheelbarrow` (S, Sunny Meadow): a wooden wheelbarrow overflowing with flowers.
2. `beehive_boxes` (S, Sunny Meadow): two stacked white wooden beehive boxes, a few bees.
3. `stone_cairn` (S, Windswept Downs): a stack of flat grey stones, the top one balanced.
4. `hay_cart` (L, Windswept Downs): a two-wheeled wooden cart piled with hay, its shafts resting on the ground.
5. `swan_topiary` (T, Swan Lake): a hedge clipped into a swan, its neck curved, in a round wooden tub.
6. `rowboat_ashore` (L, Swan Lake): a little blue rowboat pulled up on land, its oars in it.
7. `pineapple_cart` (L, Pineapple Shore): a striped-canopy fruit cart piled with pineapples.
8. `tiki_torch` (T, Pineapple Shore): a bamboo torch, bound with rope, a small flame on top.
9. `fish_drying_rack` (L, Ingothold Lake): a wooden frame with fish hung to dry on lines.
10. `lobster_pots` (S, Ingothold Lake): two round wicker lobster traps and a coil of rope.
11. `giant_dandelion` (T, Sneezle Sands): a dandelion clock taller than a person, its seed puff loosening.
12. `pepper_shaker` (S, Sneezle Sands): a giant silver pepper shaker half buried in the sand, a little pepper
    spilled.

**Batch B: woods and dark lands**
1. `firefly_jar_post` (T, Twilight Woods): a crooked wooden post with a glass jar of fireflies hung from it.
2. `twisted_root_arch` (L, Twilight Woods): two great tree roots arching over into a low gateway, moss on top.
3. `picnic_basket` (S, Big Bad Wolf's Lair): a wicker basket with a red checked cloth over it, a loaf poking out.
4. `chopped_woodpile` (S, Big Bad Wolf's Lair): split logs stacked, an axe stuck in a chopping block beside them.
5. `sheep_fence` (L, Dozywick): a short wooden fence, a fluffy sheep leaping over it, eyes shut, asleep.
6. `teddy_bear` (S, Dozywick): a big worn teddy bear sitting slumped, one button eye, a patch on its tummy.
7. `bubbling_cauldron` (S, Shiverdell): a black iron cauldron on three legs, green brew bubbling over.
8. `crow_post` (T, Shiverdell): a crooked fence post with a crow perched on top.
9. `rocking_horse` (S, Marionette Rise): a painted wooden rocking horse, a red saddle, a rope tail.
10. `tin_soldier` (T, Marionette Rise): a toy tin soldier, red coat, tall black hat, a wind-up key in its back.
11. `donut_rock` (S, Gumdrop Peaks): a giant pink-iced donut with sprinkles, standing on its edge.
12. `marshmallow_stack` (S, Gumdrop Peaks): three big soft marshmallows piled up, pink and white.

**Batch C: water, desert and the steppe**
1. `frog_statue` (S, Frog Swamp): a mossy stone frog sitting up, a crown worn smooth.
2. `sunken_rowboat` (L, Frog Swamp): an old rowboat half sunk in mud, reeds through its broken planks.
3. `stone_lantern` (T, Lotus Land): a carved stone garden lantern, a little light in its window.
4. `bamboo_clump` (T, Lotus Land): a clump of green bamboo stalks of different heights, a few leaves.
5. `rug_rack` (L, Genie Desert): a wooden rack with three patterned rugs hung over it.
6. `spice_sacks` (S, Genie Desert): open sacks of red, orange and yellow spices, a scoop in one.
7. `scarf_cairn` (T, Hidden Steppe): a heap of stones with a pole on top, blue scarves tied round it.
8. `wagon_wheel` (S, Hidden Steppe): a big wooden cart wheel leaning on a rock, a spoke broken.
9. `giant_clam` (S, Tidewater Shrine): a giant clam a little open, a pale pearl inside.
10. `tide_pillar` (T, Tidewater Shrine): a broken pale stone pillar crusted with barnacles and seaweed.

**Batch D: snow, mountains and the last**
1. `apple_basket` (S, Snow White Forest): a basket heaped with shiny red apples, one rolled out.
2. `mine_lantern_post` (T, Snow White Forest): a short timber post with a miner's lantern on a hook.
3. `frozen_rose_bush` (S, Briarmere): a rose bush with red roses, its leaves frosted, icicles on the thorns.
4. `sled` (S, Briarmere): a little wooden sled with red runners, a rope to pull it.
5. `pick_in_rock` (S, Crystal Mountain): a grey rock with a pickaxe stuck in it, a crystal showing in the crack.
6. `ore_sacks` (S, Crystal Mountain): two full sacks, one spilling glittering ore.
7. `moon_rabbit_statue` (S, Moonwhisper): a small pale stone rabbit sitting with a mortar and pestle.
8. `moon_gate` (L, Moonwhisper): a round stone gateway, a full circle, a tiled cap on top, a free-standing arch.
9. `emerald_milestone` (S, Emerald Road): a stone milestone with a green gem set in its face.
10. `merchant_cart` (L, Emerald Road): a covered wooden merchant's wagon, green canvas, crates on its back.
11. `fallen_star` (S, Starfall Isle): a fallen star, a chunky five-pointed golden star half sunk in a little crater.
12. `telescope_stand` (T, Starfall Isle): a brass telescope on a wooden tripod, pointing up.

## What happens to them

Scored as scenery (`pixel_style.py check --kind scenery`), registered in `art/assets.json` with no `request`, and
added to their land's theme `props` (maps.json), a few each, with `near` where they belong (the boat by the water,
the carts and milestone by the path). The plants (bamboo, dandelion, rose bush) get a wind rig (`tools/wind_art.py`).
The torch, lanterns, firefly jar and fallen star get a `glow`.

## Results
- **Batch A, green lands and the coast** (2026-11-22): all 12 at exactly the asked canvas, size and foot row, 15
  to 29 colours, alpha clean. Scored as scenery: seven pass every hard rule as delivered; the beehive boxes, stone
  cairn, swan topiary, lobster pots and pepper shaker missed only `outline_rel` (their outline too dark beside
  their inside) and pass once it's snapped 6% lighter (`chatgpt_1_fixed.png`). All in (`prop_art.py PICKED`), two
  props more for each land: Sunny Meadow's wheelbarrow and beehive boxes by its houses and paths, Windswept Downs'
  cairns and hay carts, Swan Lake's swan topiaries and rowboats by the water, Pineapple Shore's fruit carts and tiki
  torches (glowing), Ingothold Lake's fish racks and lobster pots by the water, Sneezle Sands' giant dandelions
  (their seed puffs move in the wind, `wind_art.py`) and pepper shakers.
- **Batch B, woods and dark lands** (2026-11-22): 11 of the 12 (the picnic basket didn't come), all at exactly
  the asked canvas, size and foot row, 14 to 26 colours. Every hard rule passed as delivered but the firefly jar
  post's outline, snapped 6% lighter. All in: Twilight Woods' firefly jar posts by its paths (glowing) and root
  arches among the trees, the Wolf's Lair's woodpiles, Dozywick's sleeping sheep over fences and teddy bears,
  Shiverdell's cauldrons by its houses (glowing, steaming green, `LandStage.smokeHoles`) and crow posts,
  Marionette Rise's rocking horses and tin soldiers, Gumdrop Peaks' donuts and marshmallows.
- **The picnic basket** (asked for again): at the asked size, 20 colours, every rule as delivered (soft 100%). In, by the Wolf's Lair's paths and trees.
- **Batch C, water, desert and the steppe** (2026-11-22): all 10 at exactly the asked canvas, size and foot row,
  15 to 24 colours, every hard rule passed as delivered (soft 82 to 100%). All in: Frog Swamp's frog statues and
  sunken rowboats by the water, Lotus Land's stone lanterns (glowing) and bamboo clumps, the Genie Desert's rug
  racks and spice sacks by its houses, the Hidden Steppe's scarf cairns and wagon wheels by its roads, Tidewater
  Shrine's giant clams by the water and barnacled pillars. The bamboo stays still: rigged for the wind, its stalks
  came apart at the row where the moving part met the still one.
