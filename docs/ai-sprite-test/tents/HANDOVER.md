# Tents by ChatGPT (2026-11-25)

The torn tent (`torn_tent`) is drawn in code (`tools/lair_art.py`) and the user wants it redrawn by ChatGPT. It
stands in two places, so this asks for two tents:

- `torn_tent`: a hunter's tent by a boss's lair (maps.json `lair`, e.g. the Wolf's Lair), torn and abandoned.
- `camp_tent`: a new one for the wild lands' camps (theme `places`, kind `camp`, 12 of them), which use the torn
  tent today (`LandPlanner.planPlaces`, `own["tent"] ?? "torn_tent"`), though nobody's camp is torn. Whole and
  lived in.

Both are scenery, not buildings: the look to match is Retro Diffusion's props (`style_reference_rd_4x.png`, 4× on
grey, each at its own canvas) and the lair's pieces it stands among (`neighbours_4x.png`: brazier, gold hoard,
bone pile, broken pillar, today's torn tent, a tree stump and barrels, 4×). Today's tent is 32 × 32 and reads as
a small heap beside them; the new ones are a little bigger, 48 × 48 (the game places them at 1 pixel a point, a
walker's own size).

## How to run it

One chat in the ChatGPT project. Attach, in this order: `style_reference_rd_4x.png`, `neighbours_4x.png`,
`torn_tent_now_8x.png`. Paste the prompt, send "next" after the first. Bring the PNGs back named by their id
(`art-variants/tents/`).

## The prompt

> Draw two tents for my game, Tales of Dorlune, one at a time, as the project's instructions say, except where
> this message says otherwise. They're scenery, not buildings: match the first sheet's look exactly (our
> scenery at 4× on grey: chunky shapes, a dark tinted outline, broad shading lit from the top left, few
> colours, cute and a little storybook), and sit well beside the pieces on the second sheet, which they stand
> among. The third picture is today's torn tent at 8×, to replace: keep its idea, not its look.
>
> Size, for both (not measured from the pictures): a 48 × 48 canvas, transparent; the tent 34 to 44 wide and
> 28 to 40 tall, its lowest pixel on row 44, roughly centred. Seen from the front and a little from above, from
> its front corner, as the sheet's props are: its lit front (facing the viewer, a little to the left) and its
> side in shade to the right. 16 to 30 colours. Alpha 0 or 255 only. No ground, slab or cast shadow under it
> (a peg or two and a tuft of grass at its foot at most), no text. Natural colours: the game tints each land's
> art itself.
>
> 1. `camp_tent`: a traveller's A-frame tent of pale canvas, whole and lived in: its front flap tied back on
>    one side showing a dark doorway, guy ropes pegged out at its corners, a patch sewn on its side, a
>    bedroll or a pack by the door. Cosy, someone's camp.
> 2. `torn_tent`: the same kind of tent abandoned by a boss's lair: its canvas faded and stained, a big ragged
>    tear in its side with a flap hanging, one pole leaning, a guy rope loose, claw marks across the front,
>    the doorway dark. Spooky but still cute, not gory.
>
> Before you deliver each, check with code and report: the canvas is 48 × 48; the tent's width, height and
> lowest row; the colour count; alpha only 0 or 255. Then deliver its 1× PNG named by its id and its 8×
> preview, then the next.

## Back in the game

`camp_tent` registered in art/assets.json (`kind: prop`) and made the camps' default tent; both copied from
`art-variants/tents/` (a `PICKED` table in `tools/lair_art.py`, as the brazier and gold hoard are), snapped to
the grid if they come back big (`tools/ai_sprite_eval.py`), with the camp's scale brought from 1.3 to 1.

## Results

(none yet)
