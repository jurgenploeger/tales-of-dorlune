# Batch 3: the most-used town buildings (2026-11-21)

These pass the style check but are still drawn in code, and stand in the most lots: the **bank** (34, in every
town), the **timber-framed house** and the **round cottage** (six each) and the **weapon shop** (five).

The first batch with the project instructions of 2026-11-21 (`../../chatgpt-project-instructions.md`): ChatGPT
measures each size from the attached picture and checks its own 1× file, so the prompt names no sizes.

One chat in the project, all four 8× images attached, in this order:

> Redraw these 4 buildings from my game, in the order attached, as the project's instructions say:
> 1. **bank**: a little white-columned bank with a red tiled roof, a gold coin emblem on the front and a
>    round coin sign on the right, a wooden door between the columns, lit windows, a patch of grass at its
>    foot.
> 2. **timber_house**: a two-storey timber-framed house, a red tiled roof and a chimney, four lit windows,
>    flower boxes, a green door.
> 3. **round_cottage**: a round white stone cottage with a tall pointed teal-tiled roof, a gold finial and a
>    round gold window in the roof, a wooden arched door, a lit window, ivy on the left.
> 4. **weapon_shop**: a stone weapon shop with a red tiled roof, a lit window under the gable, a shop window
>    with swords and axes on a rack, a dark wooden door, a rack of spears on the left, a hanging sign on the
>    right with crossed blades.
>
> The bank's coins are gold, a deeper orange-gold than the windows' warm yellow, so they don't light up at
> night.

Then as before: each checked, scored, one blind pick for all four, the winners in the game.

## Results

- **Bank, try 1** (`bank_chatgpt_1_big.png`): only the big picture again (1254 × 1254, a soft-edged
  background), about 65 × 66 on the 96 canvas, foot on row 91: not the measured 75 × 69 on row 93, so the
  new instructions' measuring and 1× steps didn't happen. Snapped at 66 tall (`bank_chatgpt_1_96.png`):
  every hard rule, soft 93%; the shrink turns its green grass tufts grey-brown, as it muddied the flowers.
  Its 1× file asked for.
- **Bank, try 2** (`bank_chatgpt_2.png`, `_8x`), after "you skipped the project's steps": a true 96 × 96
  PNG, 75 × 69, foot on row 93, exactly ours as measured; 34 colours; the 8× an exact copy. Every hard rule,
  soft 93% (ours 93%). Its coins orange, as asked.
- **Timber house, try 1** (`timber_house_chatgpt_1_big.png`): measured right (71 × 81, foot on row 90; ours
  71 × 81 on 89) but no 1× file. Snapped: every hard rule, soft 93%. Its 1× asked for.
- **Timber house, its 1×** (`timber_house_chatgpt_2.png`): 71 × 81, foot on row 89, exactly ours; 35
  colours; its night lights catch only the 16 panes of its four windows. Its outline didn't stand apart from
  the body (the townhouse's miss); `timber_house_chatgpt_2_outline90.png`, 10% darker: **passes**, soft 86%.
- **Round cottage** (`round_cottage_chatgpt_1.png`): a true 96 × 96 PNG, 58 × 81, foot on row 89, exactly
  ours; 35 colours. **Passes as delivered**, soft 93% (`form_relief` 0.017). Its night lights would catch
  its gold finial too (rows 10 to 12): a `window_art.BOXES` entry from row 40 when it goes in.
