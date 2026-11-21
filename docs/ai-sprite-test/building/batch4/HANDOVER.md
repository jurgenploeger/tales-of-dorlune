# Batch 4 (2026-11-21)

Four more town buildings still drawn in code: the **armour shop**, **tea house**, **garden cottage** and
**teapot house**. One new chat in the project, the four 8× images attached in this order:

> Redraw these 4 buildings from my game, in the order attached, as the project's instructions say:
> 1. **armour_shop**: a stone armour shop with a deep blue slate roof, two lit windows under it, a shop
>    window with helmets on display under a cream awning, a dark red wooden door, a suit of armour on a
>    stand on the left, a hanging sign on the right with a blue shield. **79 wide, 66 tall, foot on row 89.**
> 2. **tea_house**: a little tea house with a green tiled roof and a lit window in the gable, a shop window
>    with teacups under a cream awning, a red door, a hanging sign on the right with a teacup, orange paper
>    lanterns on the left, mushrooms at its foot. **78 wide, 55 tall, foot on row 89.**
> 3. **garden_cottage**: a small cottage with a pink tiled roof, a lit window under the gable and one by
>    the door, a green arched door, a flower box, and a vegetable garden bed with a little white picket
>    fence on its left. **78 wide, 50 tall, foot on row 91.**
> 4. **teapot_house**: a house shaped like a white porcelain teapot with blue trim, a blue knob on its
>    lid, a curved handle on the left and a spout on the right with a puff of steam, round lit windows,
>    a blue arched door. **78 wide, 60 tall, foot on row 89.**
>
> Paper lanterns orange, signs not yellow, so only window panes light up at night. Follow the project's
> steps exactly: measure, draw, check, and deliver the 1× PNG file for each:
> every one on a 96 × 96 canvas, fully transparent, at exactly the size and foot row given above.

## Results

All four true 96 × 96 PNGs at exactly the sizes and foot rows in the prompt: sizes written into the prompt
worked first time.

| | ChatGPT's | ours |
|---|---|---|
| tea house | **passes**, soft 86% | passes |
| teapot house | **passes**, soft 86% (`form_relief` 0.032, ours 0.027) | passes |
| armour shop | `form_relief` 0.0156, needs 0.016 | passes |
| garden cottage | too many colours for its size (`colour_density` 1.58, at most 1.4), outline not dark enough, `form_relief` 0.0159 | passes |

The tea and teapot houses are in the game (`building_art.PICKED`). The armour shop and garden cottage go
back for one fix each.
- **After the fixes:** the garden cottage came as the big picture only (78 × 50 on the 96 canvas, foot on
  row 92); snapped to 32 colours its shading passes (`form_relief` 0.0178) but its outline overshot (0.525);
  each outline pixel moved to the sprite's own colour nearest 20% lighter (no new colours): **passes**, soft
  93%, in the game (`chatgpt_2_fixed.png`). The armour shop's second try changed 471 pixels but stayed a hair
  flat (`form_relief` 0.0154; ours 0.0195).
- **Armour shop, third try** (shaded "much stronger"): `form_relief` 0.0161, **passes**, soft 93%. In the game.
  Gentle shading asks barely moved this number; spelling out each shadow (side wall, eave band, bottom third,
  window and door set in) did.
