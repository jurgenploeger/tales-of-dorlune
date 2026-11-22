# Town gates by ChatGPT (2026-11-22)

Redraws of the four towns' own gates, drawn in code by `tools/gate_art.py` (Meadowbrook, Prismhaven, Ingothold,
Larkspur). RD's `town_gate`, which the quests' gates across borders keep, stays as it is.

A gate isn't one picture in the game: `TownFence.widened` cuts it into parts to span a road of any width, so a
redraw has to keep the layout exactly (`gate_art.fitted` checks it):

- the canvas 70 × 51, the gate filling it edge to edge (its box all 70 × 51);
- a pillar at each side, x 0 to 26 and x 43 to 69, drawn whole;
- the lintel across rows 2 to 11; the game repeats its stretch at x 14 to 25 between the pillars, so column 14
  and column 26 must be the same pixels in those rows (a pattern repeating every 12 or 6 pixels);
- what hangs in the middle (a sign, a banner, a keystone) in x 27 to 42, rows 0 to 31 only; nothing below row 31
  between the pillars, and nothing in columns 26 or 43 from row 12 to 31.

Files to attach, in this order: `layout_guide_8x.png` (the zones over today's Meadowbrook gate: blue the pillars,
orange the lintel, magenta the stretch that repeats, green what hangs, red empty), `widened_4x.png` (today's four,
as drawn and widened over a road), the gate's own `<gate>_8x.png`, and `../new-buildings/style_reference_4x.png`
(the look). Back here: `gate_art.py` copies a pick (`PICKED`), `fitted` checks it, `--sheet` shows it widened.

## The prompt

> Redraw my game's four town gates, one at a time, as the project's instructions say. A gate is cut into parts
> by the game to span a road of any width, so its layout must be exact; the attached guide shows it:
>
> - Canvas exactly 70 × 51, transparent. The gate fills it edge to edge: some pixel in column 0, column 69,
>   row 0 and row 50.
> - Two pillars: the left one in x 0 to 26, the right one in x 43 to 69, standing on row 50.
> - The lintel (the beam across the top) in rows 2 to 11, running from pillar to pillar. The game repeats its
>   stretch from x 14 to 25 to make it longer, so in rows 2 to 11 make column 26 exactly the same pixels as
>   column 14 (a pattern that repeats every 12 pixels, or 6; joints or planks at x 2, 8, 14, 20, 26...).
> - What hangs in the middle (a sign, banner or keystone) only in x 27 to 42, rows 0 to 31. Nothing at all
>   between x 27 and 42 below row 31 (that's the road), and nothing in column 26 or column 43 from row 12 to 31.
>
> Match the style sheet's look (soft rounded shapes, chunky tinted outline, broad shading lit from the top
> left, cute and storybook), 24 to 36 colours, alpha 0 or 255 only. Keep what each gate is from its attached
> 8× picture (the same idea, colours by name, what hangs from it), changing only the look:
>
> 1. `gate_meadowbrook`: a farm village's lychgate, braced oak posts on stone footings under a little thatched
>    roof, roses climbing the posts, a sign with a rose on it hanging from the beam.
> 2. `gate_prismhaven`: the rainbow city's, pale cut stone, the pillars capped, a crystal set in the keystone,
>    a banner in the rainbow's colours hanging under it.
> 3. `gate_ingothold`: the desert miners' city, sandstone banded in gold, red cloth hanging down the pillars,
>    a gold medallion with crossed pickaxes over the way in.
> 4. `gate_larkspur`: painted pale blue boards with a white rail and curled brackets, lilac at the posts' feet,
>    a bluebird perched on the sign over the way in.
>
> Before you deliver each, check with code and report: the canvas is 70 × 51; the gate's bounding box is the
> whole canvas; rows 2 to 11 of column 14 equal those of column 26; nothing opaque in x 27 to 42 below row 31;
> nothing opaque in columns 26 and 43 from row 12 to 31; the colour count; alpha only 0 or 255. Then deliver its
> 1× PNG named by its id, its 8× preview, and a preview of it widened (the pillars 130 pixels apart, the stretch
> x 14 to 25 of rows 2 to 11 repeated between them, the middle part centred), then the next.

## Results
