# Batch 1: four buildings at once (2026-11-21)

The next four of our code-drawn buildings that fail a hard rule, the shops first (each stands in three or
four lots): the **flower shop**, **tailor shop**, **book shop** and **dome house**. One chat per building in
the ChatGPT project, all four running at the same time; attach that building's `<id>_8x.png` and paste its
prompt. Send the PNGs back named or captioned by building.

What has to stay for each is in its prompt: the size and the row its foot stands on (its lot is cut for
that footprint), the door, and window panes in warm yellow (the night lights are cut from them).

## Flower shop (`flower_shop_8x.png`)

> Redraw this building from my game in the style of the reference buildings: a small flower shop, 96 × 96,
> shown at 8×. Keep it the same building: a low green tiled roof, a pink and white striped awning over a
> big shop window full of flowers, a green door on the left, a round hanging sign on the right with a pink
> flower, buckets of red and yellow flowers by the door.
>
> Make it soft and rounded like the references, not a box: the roof's edges gently curved and uneven, walls
> slightly bulging, no long ruler-straight lines.
>
> Size: 78 pixels wide and 49 tall, its foot on row 88 of the 96 × 96 canvas. Deliver the 1× PNG and the
> 8× preview, as the project's instructions say.

## Tailor shop (`tailor_shop_8x.png`)

> Redraw this building from my game in the style of the reference buildings: a tailor's shop, 96 × 96,
> shown at 8×. Keep it the same building: a purple slate roof, two lit windows under it, a lilac and white
> striped awning over a shop window with coloured cloth and dresses hanging in it, a purple door on the
> left, a red dress on a stand by the door, a round hanging sign on the right with a needle and thread.
>
> Make it soft and rounded like the references, not a box: the roof's edges and ridge gently curved and
> uneven, slates in rounded rows, walls slightly bulging, no long ruler-straight lines.
>
> Size: 78 pixels wide and 68 tall, its foot on row 89 of the 96 × 96 canvas. Deliver the 1× PNG and the
> 8× preview, as the project's instructions say.

## Book shop (`book_shop_8x.png`)

> Redraw this building from my game in the style of the reference buildings: a book shop, 96 × 96, shown
> at 8×. Keep it the same building: a brown tiled roof, a lit window under it, light brick walls, a shop
> window with rows of colourful books, a dark door on the left, a hanging sign on the right with an open
> book, a small bench with a blue book on it by the door.
>
> Make it soft and rounded like the references, not a box: the roof's edges and ridge gently curved and
> uneven, tiles in rounded rows, walls slightly bulging, bricks of different sizes, no long ruler-straight
> lines.
>
> Size: 78 pixels wide and 67 tall, its foot on row 89 of the 96 × 96 canvas. Deliver the 1× PNG and the
> 8× preview, as the project's instructions say.

## Dome house (`dome_house_8x.png`)

> Redraw this building from my game in the style of the reference buildings: a desert house with an onion
> dome, 96 × 96, shown at 8×. Keep it the same building: sandstone block walls, a teal tiled onion dome on
> top with a small gold finial, two lit windows, a teal arched door at the front, round clay pots at its
> corners.
>
> Make it soft and rounded like the references, not a box: the walls' corners and top edge rounded and a
> little uneven, sandstone blocks of different sizes with rounded corners, the dome's tiles in curved rows,
> no long ruler-straight lines.
>
> Size: 59 pixels wide and 81 tall, its foot on row 89 of the 96 × 96 canvas. Deliver the 1× PNG and the
> 8× preview, as the project's instructions say.

## Then

Each comes back here: checked for a clean 1× at the asked size, scored (`pixel_style.py check --kind
building`), a small written-down outline fix where the two outline rules need it, then one blind-pick sheet
for all four (A or B per row) against ours. The winners go in as the cottage and townhouse did
(`building_art.PICKED`).

## Results (one chat for all four, 2026-11-21)

- **Flower shop:** only the big picture, drawn finer than the grid (blocks of about 11 image pixels); snapped,
  every hard rule, soft 79%, but the shrink muddies its 2-to-3-pixel flowers. Its 1× file asked for.
- **Book shop** (`book_shop_chatgpt_1.png`): a true 96 × 96 PNG, 78 × 67, foot on row 89, 40 colours.
  Soft 100%; misses one hard rule by a hair: `form_relief` 0.0150, needs 0.016 (its big forms lit a little
  flat; ours 0.0163, ChatGPT's cottage 0.0199 and townhouse 0.0185).
- **Tailor shop** (`tailor_shop_chatgpt_1.png`): a true 96 × 96 PNG, 78 × 68, foot on row 89, 40 colours.
  Its outline didn't stand apart from the body (the townhouse's miss); `tailor_shop_chatgpt_1_outline90.png`,
  10% darker, fixes it: soft 100%, and the same hair's miss on `form_relief` (0.0157; ours 0.0168).
- Form shading is the drawing's job, not a fix in code. Follow-up for both, in the same chat:

> The book shop and tailor shop are lit a little flat. Keep everything, but shade the big forms more: the
> roof darker toward its eave with a band of shadow under the eaves on the wall, the side wall in shade, the
> front wall darker toward its foot and its right side, the shop window and door set in with a shadow on
> their top and left edge. Same sizes, same 1× PNGs and 8× previews.
- **Flower shop, its own 1×** (`flower_shop_chatgpt_2.png`): 78 × 49, foot on row 88, 40 colours, clean; the
  buckets' red, yellow and purple kept. Every hard rule passes (`form_relief` 0.018; ours fails it, 0.0155).
  Soft 79%, a point under 80, as RD's two lowest buildings: its outline a little grey (`outline_sat` 0.12),
  a few jagged steps, light in small areas more than broad ones.
- **Dome house** (`dome_house_chatgpt_1.png`): 59 × 81, foot on row 89, 39 colours, clean. **Passes every
  rule, 100%**, as delivered (`form_relief` 0.0195): the first that needs no fix at all.
- **Book shop and tailor shop, re-shaded** (`book_shop_chatgpt_2.png`, `tailor_shop_chatgpt_2.png`): the
  same sizes, clean, 40 colours; `form_relief` 0.0168 and 0.0165. **Both pass every rule, 100%, as
  delivered**, the tailor shop's outline fixed too.

`blind_pick.png`: all four against ours, sides shuffled per row; the key stays out of the repo till the pick.
