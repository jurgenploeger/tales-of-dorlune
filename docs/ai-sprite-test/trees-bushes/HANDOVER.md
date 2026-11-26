# Trees and bushes by ChatGPT (2026-11-26)

The user, 2026-11-26: "Oke lets do trees and bushes now" (after the walls, docs/ai-sprite-test/walls). These are the
trees and bushes still drawn in code (`tools/scenery_art.py`, `pixel_kit`): 11 trees and 10 bushes and saplings, in
every wild land, so they set each land's look more than anything else. `trees_now_4x.png` and `bushes_now_8x.png` are
today's, `trees_in_game.png` some of them in Larkspur's fields (the lilac trees and bushes, beside Retro Diffusion's
round green `tree`, which stays as it is, as do RD's `tree`, `pine`, `apple_tree` and `berry_bush`).

Redraws, not new species: each keeps its kind and its canvas, so every land that plants it, its big twin (`big_<id>`,
the same picture at a larger scale) and its wind rig follow.

## What the game does with them

- **Graded by each land's palette**: draw them in their own natural colours; the game tints them per land.
- **The wind** (`tools/wind_art.py`): the trunk stays put and the crown moves in clumps, a whole pixel at a time. It
  finds the clumps itself: the leaves told from the wood **by colour** (so the crown's colours must differ from the
  trunk's), then cut into clumps from each **bright spot** down to the **dark crevices** between them. So a crown drawn
  as a few big leaf clumps, each lit on its own with darker gaps between, moves best; a crown that's one smooth blob
  moves as one piece.
- **Shade**: each casts its own outline on the ground away from the sun, so the shape itself is the shadow.
- **Snow**: near a snowy land the game caps their lit clusters with snow, so nothing to draw for that.

## The layout

- **Trees: 64 × 64**, transparent, the trunk's foot on **row 59**, the trunk in the middle (its foot about x 26 to
  38). 36 to 56 wide, 46 to 58 tall (the birch narrower, about 22 wide).
- **Bushes and saplings: 32 × 32**, transparent, their lowest pixel on **row 28**, in the middle. 18 to 29 wide, 16
  to 26 tall (the two saplings and the fir taller and narrower).

Every one: alpha 0 or 255 only; seen from the front and a little from above, as `style_reference_rd_4x.png`'s are; no
ground, slab or drop shadow under it (a few grass blades at its foot at most; `frost_tree` and `snow_sapling` keep their
little drift of snow); no text.

## How to run it

One chat in the ChatGPT project. Attach, in this order: `style_reference_rd_4x.png` (the look), `trees_in_game.png`,
`trees_now_4x.png` and `bushes_now_8x.png` (today's, to beat). Paste the prompt, then send "next" after each. Bring the
PNGs back named by their id, into `art-variants/trees/`, each as a message of its own (images sent while Claude is
working aren't saved).

## The prompt

> Redraw my game's trees and bushes, one at a time, as the project's instructions say, except where this message
> says otherwise. The first picture is our style sheet: match its look exactly (chunky shapes, a dark tinted
> outline, broad shading lit from the top left, few colours, cute and a little storybook). The second is some of
> them in the game; the last two are today's drawings, to beat: keep each one's kind, size and foot, and make it
> lovelier.
>
> Sizes:
> - **Trees**: a 64 × 64 canvas; the trunk's foot on row 59, in the middle (about x 26 to 38); 36 to 56 wide, 46 to
>   58 tall. 16 to 32 colours.
> - **Bushes**: a 32 × 32 canvas; the lowest pixel on row 28, in the middle; 18 to 29 wide, 16 to 26 tall. 10 to 24
>   colours.
>
> Every one: transparent, alpha 0 or 255 only, no ground, slab or shadow under it, no text. Natural colours (the
> game tints each land's art itself). The leaves in clearly different colours from the trunk and branches. Draw a
> crown as a few big leaf clumps, each lit on its own from the top left, with darker gaps between them (the game
> moves each clump in the wind).
>
> **Trees**
> 1. `blossom_tree`: a cherry tree in full pink blossom, spreading wide, a short brown trunk with roots.
> 2. `dark_tree`: a gnarled, twisted dark tree, crooked branches reaching out, a flat crown of deep violet leaves,
>    a bare twig sticking up. Spooky but cute.
> 3. `autumn_tree`: an oak in autumn, round clumps of orange leaves, a sturdy brown trunk with roots.
> 4. `red_maple`: a maple in autumn, deep red and scarlet leaves in rounded clumps, a brown trunk.
> 5. `golden_tree`: a slim birch, a white trunk with black marks, a tall narrow crown of golden yellow leaves
>    (about 22 wide).
> 6. `frost_tree`: a bare winter tree, dark twisting branches, snow lying on its branches, a little drift of snow
>    round its foot.
> 7. `swamp_tree`: a weeping willow, long green curtains of leaves hanging down nearly to the ground, its brown
>    trunk showing between.
> 8. `lilac_tree`: a jacaranda, a broad flat crown of lilac-purple blossom, a few tassels hanging from its edge, a
>    brown trunk.
> 9. `candy_tree_lemon`: a candy tree: a round cotton-candy crown in pale lemon yellow on a straight lollipop stick
>    striped white and golden yellow.
> 10. `candy_tree_peach`: the same candy tree, its crown peach pink and its stick striped white and red.
> 11. `candy_tree_sky`: the same candy tree, its crown pale sky blue and its stick striped white and blue.
>
> **Bushes**
> 1. `bush`: a round leafy green bush.
> 2. `flowering_bush`: the same round green bush with a few small white flowers with yellow middles.
> 3. `golden_bush`: a round shrub of golden autumn leaves.
> 4. `lilac_bush`: a low green bush with spikes of lilac-purple flowers rising out of it.
> 5. `dark_bush`: a bramble: a dark violet thorny tangle, a few bare thorny stems curling out of it.
> 6. `moss_bush`: a grey boulder with a thick cushion of moss growing over its top.
> 7. `dry_bush`: a tumbleweed, a round tangle of dry tan twigs.
> 8. `pine_sapling`: a young fir, a dark green cone of tiers of needles, a stub of trunk (about 20 wide, 25 tall).
> 9. `snow_sapling`: the same young fir with snow lying on each tier, a little drift of snow round its foot.
> 10. `sapling`: a young leafy tree, a round green crown on a thin brown trunk (about 19 wide, 26 tall).
>
> Before you deliver each, check with code and report: its canvas size; its lowest row and its foot's middle column;
> its width and height; the colour count; alpha only 0 or 255. Then deliver its 1× PNG named by its id and its 8×
> preview, then the next.

## Back in the game

Copied from `art-variants/trees/` (a `PICKED` table in `tools/scenery_art.py`, checked for size, foot and hard alpha,
as `tools/city_wall_art.py` does the walls), over the code's drawings. Then `tools/wind_art.py` reruns to rig the new
crowns (`check_content.py` checks every rig fits), and `tools/pixel_style.py check --kind scenery` scores them.

## Results

- **2026-11-26**: asked for.
