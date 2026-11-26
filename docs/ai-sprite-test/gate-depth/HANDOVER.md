# Gates' depth by ChatGPT (2026-11-26)

Since 0.9.206 the gates go back into the screen (the user, 2026-11-25: "The gates should also be thicker because now
it's too flat"). The game builds that depth itself: it stacks copies of the arch's outline, filled with two flat tones
of its average colour, lit on top and shaded at the ends (`TownFence.gate`, `depth_today_4x.png`). The user,
2026-11-26: "Currently for the town gates we used our pixels to create them thicker, but we should ask chatgpt to draw
them".

The front of each gate stays as drawn (the four towns' by ChatGPT, 2026-11-22; the quests' `town_gate` by Retro
Diffusion, which stays as it is). What's asked for is the depth, in **two pieces per gate**, drawn face on:

- **`<gate>_top`**: the top of the gate seen from straight above (the beam's top and the pillars' caps), what you see
  of it going back into the screen. The game lays it back from the front's top edge, slanted to the gate's angle, as
  it lays a city wall's walk (`TownFence.pieces`, `drawTop`).
- **`<gate>_side`**: a pillar's side, what you see of it at the gate's end. The game stands it at the end that faces
  you, slanted back, and mirrors it for a gate turned the other way.

Gates stand along both of the map's diagonals, and the game spans roads of any width by repeating part of a gate
(`TownFence.widened`). That's why the depth can't be drawn into the front picture itself, and why the top keeps the
front's layout across.

## The layout (`pieces_guide_8x.png`)

The side piece (green) is at the left, the front (today's Meadowbrook gate) at the right, and the top piece above the front.

- **`_top`: 70 × 10.** Columns line up with the front's: the pillars' caps in x 0 to 26 and x 43 to 69 (blue), the
  beam's top across x 27 to 42 (orange). The game repeats x 14 to 25 (magenta) to make it longer, as with the front, so
  every row's column 26 must be the same pixels as its column 14 (a pattern repeating every 12 or 6 pixels). Row 0 is
  the far edge, row 9 the near edge, which meets the front's top row. The tops face the sky, so they're the lightest
  part of the gate, lit from the top left. Its outline is only along the far edge and the two ends, never along
  row 9, where it joins the front. Only what's on top of the gate: nothing hanging, no road.
- **`_side`: 10 × 51.** One pillar's side, as tall as the front (51 rows, standing on row 50). Column 0 is the edge
  nearest you, where it meets the front's left edge. Column 9 is the far edge. It's in the pillar's own material and
  courses (the same stones, planks, bands and trim as the front's pillar, lining up row for row), a step darker than
  the front, as it's turned from the light. Its outline is on the far edge and the bottom, never on column 0. Its top
  rows match the top piece's ends.

## How to run it

One chat in the ChatGPT project. Attach, in this order: `pieces_guide_8x.png`, `depth_today_4x.png` (today's depth,
to beat), `style_reference_rd_4x.png` (the look), then each gate's own `<gate>_8x.png` as you get to it. Paste the
prompt, and send "next" after each gate. Bring the PNGs back named by their id, into `art-variants/gate_depth/`.

## The prompt

> Draw the depth of my game's five gates, one gate at a time, as the project's instructions say, except where this
> message says otherwise. Each gate's front is already drawn (attached, 8×) and stays as it is. For each, draw two
> pieces that show its thickness, face on, in exactly its colours and materials. The game slants them back into
> the screen behind the front. The attached guide shows the layout, which must be exact:
>
> - `<gate>_top`: 70 × 10, transparent. The top of the gate seen from straight above: the pillars' caps in x 0 to 26
>   and x 43 to 69, the beam's top between, its columns lining up with the front's. In every row column 26 must be
>   exactly the same pixels as column 14 (the game repeats x 14 to 25 to widen the gate). Row 0 is the far edge, row
>   9 the near edge, which joins the front's top row. Lit from the top left: the gate's lightest part. Outline along
>   row 0 and at both ends, never along row 9.
> - `<gate>_side`: 10 × 51, transparent. One pillar's side, standing on row 50: the same stones, planks, bands or
>   trim as the front's pillar, its courses lining up row for row, a step darker as it faces away from the light.
>   Column 0 is its near edge (where it meets the front), column 9 its far edge. Outline on the far edge and the
>   bottom, never on column 0. Its top rows meet the top piece's ends.
>
> Match the style sheet's look (soft rounded shapes, chunky tinted outline, broad shading lit from the top left,
> cute and storybook) and each front's own palette. Alpha 0 or 255 only, no text.
>
> 1. `gate_meadowbrook`: its thatched little roof seen from above on top, its braced oak post with a rose climbing
>    up the side.
> 2. `gate_prismhaven`: pale cut stone, the pillars' caps and the keystone's top, the side in the same courses.
> 3. `gate_ingothold`: sandstone banded in gold; the side with its red cloth hanging down.
> 4. `gate_larkspur`: pale blue painted boards, the white rail along the top, the side's boards and bracket.
> 5. `town_gate`: the grey stone arch (attached 8×), its rubble stones on top and down the side.
>
> Before you deliver each gate, check with code and report: `_top` is 70 × 10 and every row's column 26 equals its
> column 14; `_side` is 10 × 51; alpha only 0 or 255; the colour count of each. Then deliver the two 1× PNGs named by
> their ids, and a preview at 4× of the gate put together (the front, the top laid back above it slanting up to the
> left by half a pixel a pixel, the side at its left slanting the same way), then the next gate.

## Back in the game

Copied from `art-variants/gate_depth/` (a `PICKED` table in `tools/gate_art.py`, checked by a `fitted` for the two
pieces as for the front), registered in art/assets.json. `TownFence.gate` then draws the gate's top piece laid back,
widened as the front is, and its side piece at the end that shows, mirrored for the other angle, in place of the
stacked copies. A gate with no pieces drawn keeps today's depth.

## Results

- **2026-11-26**: asked for. Back the same day: `gate_ingothold_top` (70 × 10, its stretch repeating cleanly, 11 colours),
  `gate_ingothold_side` and `gate_larkspur_side` (10 × 51, 11 and 7 colours), with previews put together (kept in
  `art-variants/gate_depth/`). In (`tools/gate_art.py` `DEPTH`, `depth_fitted`; `TownFence.gate` draws them over the flat
  tones). Larkspur's top, and Meadowbrook's, Prismhaven's and the quests' gate's pieces, still to come.
- **2026-11-26, later**: the rest in: Larkspur's top, and Meadowbrook's, Prismhaven's and `town_gate`'s top and side
  (each top's column 26 its column 14, alpha 0 or 255; the three from before came back the same). Every gate has both.
