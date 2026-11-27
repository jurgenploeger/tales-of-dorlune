# Big trees and fairy tree houses at their own size, by ChatGPT (2026-11-26)

The user, 2026-11-26: "We use a lot of stretched pixel art. How can we fix that? Maybe have chatgpt create the pixel
artwork that's needed?" `tools/pixel_scale.py` lists what's drawn bigger than the walkers' pixels. These are the worst
that ChatGPT can redraw: the big trees (`big_<id>`, each its 64-pixel tree shown 1.7 times its size, so every art pixel
is 1.7 of the hero's) and the fairy tree houses (Retro Diffusion's `hollow_tree` recoloured, shown 1.6 and 2.1 times its
size, standing in for a fairy tree house nobody drew). Drawn at the size they're shown, each pixel is the hero's again.

## Batch 1 (this prompt)

| id | canvas | sprite (w × h) | foot row | drawn from |
|---|---|---|---|---|
| `big_blossom_tree` | 108 × 108 | 88 × 88 | 100 | `blossom_tree_now_8x.png` |
| `big_dark_tree` | 108 × 108 | 95 × 97 | 100 | `dark_tree_now_8x.png` |
| `big_frost_tree` | 108 × 108 | 95 × 94 | 100 | `frost_tree_now_8x.png` |
| `big_golden_tree` | 108 × 108 | 37 × 99 | 100 | `golden_tree_now_8x.png` |
| `big_lilac_tree` | 108 × 108 | 71 × 83 | 100 | `lilac_tree_now_8x.png` |
| `big_red_maple` | 108 × 108 | 88 × 87 | 100 | `red_maple_now_8x.png` |
| `big_swamp_tree` | 108 × 108 | 80 × 92 | 100 | `swamp_tree_now_8x.png` |
| `fairy_tree_house` | 102 × 102 | 85 × 90 | 91 | `hollow_tree_now_8x.png` |
| `fairy_tree_house_moon` | 102 × 102 | 85 × 90 | 91 | `hollow_tree_now_8x.png` |
| `fairy_tree_house_rose` | 102 × 102 | 85 × 90 | 91 | `hollow_tree_now_8x.png` |
| `fairy_great_tree` | 134 × 134 | 111 × 118 | 120 | `hollow_tree_now_8x.png` |

The sizes are the 64-pixel drawing's own times the scale it's shown at now, so each stands as tall in the game as
today. The seven trees are ChatGPT's own 64-pixel trees (docs/ai-sprite-test/trees-bushes): the big one is the same
tree, older and grander, with the detail a bigger canvas holds, not the small one blown up.

## Batch 2 (needs the user's OK first: Retro Diffusion art)

`big_tree`, `big_dead_tree`, `big_snow_pine`, `big_frost_pine`, `big_snow_tree`, `big_hollow_tree` and `big_ice_cluster`
are RD's `tree`, `dead_tree`, `snow_pine`, `snow_tree`, `hollow_tree` and `crystal` shown 1.6 to 1.7 times their size.
CLAUDE.md: RD's art stays as drawn. A bigger drawing of each beside RD's small one is new art, not a redraw of RD's,
but it's the user's call. The lollipops (`lollipop`, `_pink`, `_lemon`, `_berry`, `_sky`) are RD's beach umbrella,
unrecoloured, planted at 1.7: they want drawing as lollipops in the first place.

## What the game does with them

- **Graded by each land's palette**: natural colours; the game tints each land's art itself.
- **The wind** (`tools/wind_art.py`): the trunk stays put and the crown moves in clumps, cut by colour (leaves told
  from wood) and from each bright spot down to the dark gaps. Leaves in clearly different colours from the wood, the
  crown as a few big clumps each lit on its own with darker gaps between.
- **Lit windows** (`tools/window_art.py`): a fairy house's window panes in a warm bright yellow nothing else uses, so
  the game can cut them out and light them at night.
- **Shade**: each casts its own outline on the ground away from the sun.

## How to run it

One chat in the ChatGPT project. Attach `style_reference_rd_4x.png` first, then the `_now_8x.png` pictures. Paste the
prompt, then send "next" after each. Bring the 1× PNGs back named by their id, into `art-variants/big_trees/`, each as
a message of its own (images sent while Claude is working aren't saved).

## The prompt

> Draw bigger versions of some of my game's trees, and four fairy tree houses, one at a time, as the project's
> instructions say, except where this message says otherwise. The first picture is our style sheet: match its look
> (chunky shapes, a tinted outline, broad shading lit from the top left, cute and a little storybook). The others are
> today's 64 × 64 drawings at 8×.
>
> **Don't measure the size from the attached pictures this time.** Each one below gives its own canvas, the sprite's
> width and height, and the row its lowest pixel stands on (its foot), with the trunk's foot in the middle of the
> canvas. They're drawn at their full size, not scaled up: every pixel the same size as in the 64 × 64 drawings, so a
> big tree is the same tree with more room for detail (more leaf clumps, bark, roots), never the small one blown up.
> Colours: 30 to 50 on a 108 or 102 canvas, 45 to 70 on the 134 one.
>
> Every one: transparent, alpha 0 or 255 only, no ground, slab or shadow under it (a few grass tufts at its foot at
> most), no text. Natural colours (the game tints each land's art itself). The leaves in clearly different colours
> from the trunk and branches, the crown drawn as a few big leaf clumps, each lit on its own from the top left with
> darker gaps between them (the game moves each clump in the wind).
>
> **Big trees** (canvas 108 × 108, foot on row 100; the same tree as its picture, older and grander):
> 1. `big_blossom_tree` (from the blossom tree): 88 wide, 88 tall. A cherry in full pink blossom, spreading wide,
>    a stout brown trunk with roots.
> 2. `big_dark_tree` (from the dark tree): 95 wide, 97 tall. Gnarled and twisted, crooked branches reaching out, a
>    flat crown of deep violet leaves, a bare twig sticking up. Spooky but cute.
> 3. `big_frost_tree` (from the frost tree): 95 wide, 94 tall. A bare winter tree, dark twisting branches with snow
>    lying along them, a little drift of snow round its foot.
> 4. `big_golden_tree` (from the golden birch): 37 wide, 99 tall. A tall slim birch, a white trunk with black marks,
>    a tall narrow crown of golden yellow leaves.
> 5. `big_lilac_tree` (from the lilac tree): 71 wide, 83 tall. A jacaranda, a broad flat crown of lilac-purple
>    blossom, a few tassels hanging from its edge, a brown trunk.
> 6. `big_red_maple` (from the red maple): 88 wide, 87 tall. A maple in autumn, deep red and scarlet leaves in rounded
>    clumps, a brown trunk.
> 7. `big_swamp_tree` (from the willow): 80 wide, 92 tall. A weeping willow, long green curtains of leaves hanging
>    nearly to the ground, its brown trunk showing between.
>
> **Fairy tree houses** (from the hollow tree's shape: a big old tree you could live in, seen from the front and a
> little from above, a round front door at its foot you could walk up to, two or three small round windows up the
> trunk whose panes are a warm bright yellow nothing else in the picture uses, a few tiny touches: a little lantern,
> mushrooms at the foot, a ladder or a balcony):
> 8. `fairy_tree_house`: canvas 102 × 102, 85 wide, 90 tall, foot on row 91. Lilac-purple leaves, a purple door.
> 9. `fairy_tree_house_moon`: canvas 102 × 102, 85 wide, 90 tall, foot on row 91. Silvery pale blue moonlit leaves, a
>    pale blue door.
> 10. `fairy_tree_house_rose`: canvas 102 × 102, 85 wide, 90 tall, foot on row 91. Rose pink leaves, a pink door.
> 11. `fairy_great_tree`: canvas 134 × 134, 111 wide, 118 tall, foot on row 120. The grandest of them, the fairies'
>     great tree: a huge old trunk with roots spreading wide, pale silver-lilac leaves, a big round door with steps up
>     to it, several windows at different heights, a balcony.

## Bringing them in (for Claude)

Snap each to its grid (`tools/ai_sprite_eval.py`), copy it in as `art/sprites/<id>.png`, set its asset's `scale` to 1
(and drop the `derive`: its own PNG wins over it, the scale doesn't), rerun `tools/wind_art.py` (the trees and the
houses' crowns) and `tools/window_art.py` (the houses' panes, `windows_<id>` registered in art/assets.json), then
`python3 tools/check_content.py`, `tools/pixel_scale.py` (each now at the walkers' 1) and `scripts/sprite_check.py
check <ids> --new`.

## Batch 1's result (2026-11-26)

All eleven exactly the sizes asked, in the game since 0.9.244 (wind rigs, the houses' windows lit).

## Batch 2: Retro Diffusion's own, at their own size (the user's OK, 2026-11-27)

The user, 2026-11-27: "then second chatgpt batch". These are RD's drawings shown bigger than drawn; the big ones are new
drawings beside RD's small ones, which stay as they are.

| id | canvas | sprite (w × h) | foot row | drawn from |
|---|---|---|---|---|
| `big_tree` | 108 × 108 | 75 × 95 | 100 | `tree_now_8x.png` |
| `big_dead_tree` | 108 × 108 | 70 × 90 | 97 | `dead_tree_now_8x.png` |
| `big_snow_pine` | 108 × 108 | 68 × 97 | 100 | `snow_pine_now_8x.png` |
| `big_snow_tree` | 108 × 108 | 90 × 82 | 95 | `snow_tree_now_8x.png` |
| `big_hollow_tree` | 108 × 108 | 90 × 95 | 97 | `hollow_tree_now_8x.png` |
| `big_ice_cluster` | 52 × 52 | 40 × 38 | 43 | `crystal_now_8x.png` (shown icy) |
| `lollipop` | 54 × 54 | 37 × 41 | 44 | `beach_umbrella_now_8x.png` (RD's lollipop, named so) |

`big_frost_pine` follows `big_snow_pine` by `frost_pine`'s recolour, and `lollipop_pink`, `_lemon`, `_berry` and `_sky` the
new `lollipop` by theirs (art/assets.json `derive`), so nothing to draw for them.

### The prompt

Attach `style_reference_rd_4x.png`, then the seven `_now_8x.png` in the table's order.

> Draw seven more of my game's props bigger, one at a time, as the project's instructions say and as the last big
> trees, except where this message says otherwise. The first picture is our style sheet; the others are today's
> drawings at 8×, which the game shows stretched 1.6 to 1.7 times their size. **Don't measure the size from the
> pictures:** each below gives its canvas, the sprite's width and height and its foot row, the trunk or stick in the
> middle. Every pixel the same size as in today's drawings: the same thing with more room for detail, never the small
> one blown up. Colours: 30 to 50 on a 108 canvas, 16 to 30 on the small ones.
>
> Every one: transparent, alpha 0 or 255 only, no ground, slab or shadow under it (a few grass tufts at a tree's foot
> at most), no text. Natural colours (the game tints each land's art itself). A tree's leaves in clearly different
> colours from its trunk, its crown a few big leaf clumps, each lit on its own from the top left with darker gaps
> between them (the game moves each clump in the wind).
>
> 1. `big_tree` (from the round green tree): canvas 108 × 108, 75 wide, 95 tall, foot on row 100. A big old leafy
>    oak, a round full crown of fresh green clumps, a stout brown trunk with roots.
> 2. `big_dead_tree` (from the dead tree): canvas 108 × 108, 70 wide, 90 tall, foot on row 97. A bare dead tree,
>    grey-brown twisting branches reaching out, no leaves, a cracked trunk with roots.
> 3. `big_snow_pine` (from the snowy pine): canvas 108 × 108, 68 wide, 97 tall, foot on row 100. A tall green fir in
>    tiers, snow lying thick on each tier's top, a short brown trunk.
> 4. `big_snow_tree` (from the snowy tree): canvas 108 × 108, 90 wide, 82 tall, foot on row 95. A broad round
>    deciduous tree heavy with snow, white clumps on its crown with green showing between, a brown trunk.
> 5. `big_hollow_tree` (from the hollow tree): canvas 108 × 108, 90 wide, 95 tall, foot on row 97. A huge old oak
>    with a dark hollow in its trunk, gnarled roots, a full crown of green leaf clumps.
> 6. `big_ice_cluster` (from the crystal): canvas 52 × 52, 40 wide, 38 tall, foot on row 43. A cluster of pale icy
>    blue crystals of different heights, faceted, lit top left, white glints.
> 7. `lollipop` (from the swirled lollipop): canvas 54 × 54, 37 wide, 41 tall, foot on row 44. A giant round candy
>    lollipop, a red and cream spiral swirl, a little shine top left, on a thin pale stick standing upright.

## Batch 2's result (2026-11-27)

All seven at their canvas, width and foot row as asked, hard alpha, 27 to 46 colours. In `art-variants/big_trees/` and
`art/sprites/`, scale 1, no `derive`: `big_frost_pine` is `big_snow_pine` by `frost_pine`'s recolour, the four
lollipops `lollipop` by theirs (maps.json `size` [1, 1], was [1.7, 1.7]). Wind rigs for the four leafy ones
(`wind_art.py`; the dead tree bare, as its small one), the ice cluster lit at night as itself (`window_art.py` `LIGHTS`).
`pixel_scale.py`: no prop drawn at 1.7 any more.
