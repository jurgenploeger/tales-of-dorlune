# Batch 2: four more buildings in one chat (2026-11-21)

The rest of our code-drawn 96-pixel buildings that fail a hard rule: the **market stall** (`market_tent`,
four lots), the **pavilion tent** (desert), the **tree house** and the **bluebell house** (Starfall Isle's
Glimmerbough). The two grand ones that fail (the Wildfolk Lodge and the Star Observatory, 160 × 160) wait
for a batch of their own.

One chat in the ChatGPT project, all four 8× images attached, this prompt (batch 1's, with what its
follow-ups taught us built in: the 1× files, and the big forms shaded):

> I've attached 4 buildings from my game, each 96 × 96 shown at 8×. Redraw each one in the style of the
> reference buildings, keeping it the same building (same colours, shapes, door, windows and props). Make
> them soft and rounded like the references, not boxes: edges gently curved and uneven, no long
> ruler-straight lines. Shade the big forms as forms: a roof or canopy darker toward its edge with shadow
> under it, the side away from the light in shade, doors and openings set in with a shadow on their top and
> left edge.
>
> Exact sizes, each on its own 96 × 96 canvas:
> 1. **market_tent** (a market stall: teal and white striped awning on posts, a wooden counter with fruit,
>    a red cloth): 78 wide, 64 tall, foot on row 87
> 2. **pavilion_tent** (a striped desert tent in red, orange and cream, a flag on top, ropes and pegs):
>    78 wide, 73 tall, foot on row 90
> 3. **tree_house** (a pink-roofed hut in a round green tree, a ladder, a little platform with a lantern):
>    72 wide, 84 tall, foot on row 92
> 4. **bluebell_house** (a tall blue bluebell flower as a house, its green stem curling over the top, two
>    lit windows, a small round door, green leaves at its foot): 60 wide, 81 tall, foot on row 89
>
> Do them one at a time, as separate images, never combined. For each, deliver the 1× 96 × 96 PNG (fully
> transparent background) and the 8× preview, named by its building (`market_tent.png`,
> `market_tent_8x.png`...). Check each one's size before the next. If you can only make one image per reply,
> do the first and wait for me to say "next".

Then as batch 1: each checked, scored, one blind pick for all four, the winners in the game.

## Results

- **Market stall, try 1** (`market_tent_chatgpt_1_big.png`): the size measured right this time (78 × 64 on
  the 96 canvas, foot on row 88; ours 78 × 64 on row 87), but no 1× file again. Snapped
  (`market_tent_chatgpt_1_96.png`): soft 93%, misses two hard rules, as ours does: straight edges (0.46,
  at most 0.4: the counter's long ruled top and corners) and form shading (0.012, needs 0.016: the counter's
  front in one flat tone). By eye a clear step up from ours (rounded awning, wood grain, the pots).
- **Market stall try 2, pavilion tent and tree house** (all true 96 × 96 PNGs at exactly our sizes and foot
  rows: the instructions' measuring worked):
  - market stall: straight edges fixed; still flat (`form_relief` 0.013, needs 0.016; ours 0.0093). Soft 93%.
  - tree house: flat too (0.013; ours 0.0128). Soft 93%.
  - pavilion tent: its outline doesn't stand apart from the body. Darkening it in code adds too many colours
    on so small a sprite (`colour_density`, hard), so it goes back to ChatGPT.
  Both flat ones beat ours on the same rule; a follow-up asks for the forms shaded deeper, the pavilion's
  outline darker.
- **After the follow-up** (`pavilion_tent_chatgpt_2`, `market_tent_chatgpt_3`, `tree_house_chatgpt_2`,
  `bluebell_house_chatgpt_1`; all true 96 × 96 at our sizes): each still misses a hard rule, but so does
  each of ours, and none is worse:

  | | ours fails | ChatGPT's fails |
  |---|---|---|
  | market stall | straight edges, `form_relief` 0.009 | `form_relief` 0.013 |
  | tree house | `form_relief` 0.013 | `form_relief` 0.015 |
  | bluebell house | `form_relief` 0.011 | `form_relief` 0.013 (and a weak outline, soft 71%) |
  | pavilion tent | `form_relief` 0.015 | `outline_rel` 0.491 (its shading passes, 0.019) |

  Small outline fixes in code didn't land (too many colours on these small sprites, or the other outline
  rule out), so they go to the user's eye as they are: `blind_pick.png`, the key out of the repo till the pick.

## In the game (2026-11-21)

The user: "All chatgpts are better, we don't need to do blind tests anymore." Every building here is in
(`building_art.PICKED`, `art-variants/<id>/`), the blind pick sheet unanswered and its key kept for the record.
