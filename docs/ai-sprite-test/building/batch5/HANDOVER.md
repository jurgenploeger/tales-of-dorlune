# Batch 5: the last six regular-size buildings (2026-11-21)

One new chat, the six 8× images attached in this order. The prompt carries what batches 1 to 4 taught: the
sizes and foot rows written in, the shading spelled out, warm yellow only for panes.

> Redraw these 6 buildings from my game, in the order attached, as the project's instructions say:
> 1. **yurt**: a round steppe yurt of cream felt with two red bands, a cone roof of tan felt with a smoke
>    hole and a puff of smoke, an orange door. **70 wide, 79 tall, foot on row 87.**
> 2. **crystal_cottage**: a grey stone cottage with a purple slate roof, pale blue and violet crystal spires
>    growing from the roof and round its foot, a blue arched door, a lit window. **79 wide, 65 tall, foot on
>    row 89.**
> 3. **bell_tower**: a tall grey stone bell tower with a pointed slate spire and a little cross on top, a
>    bronze bell in an open arch, a wooden arched door, grass round its foot. The bell bronze-orange, not
>    yellow. **58 wide, 85 tall, foot on row 93.**
> 4. **gem_workshop**: a stone workshop with a blue slate roof, a lit window, a workbench with coloured gems
>    in its open front, a dark door, a hanging sign on the right with a gem, crystals at its left foot.
>    **79 wide, 56 tall, foot on row 92.**
> 5. **acorn_cottage**: a house shaped like a giant acorn: a scaly tan cap roof with a stem and a leaf on top
>    and a little chimney, a round brown shell body, round lit windows, a small green door, grass and
>    flowers at its foot. **79 wide, 75 tall, foot on row 92.**
> 6. **lake_shrine**: a small white marble shrine with columns, a triangular roof with a blue emblem, a
>    statue inside, snow on its roof and steps, a lamp post on each side. **78 wide, 64 tall, foot on row 92.**
>
> Shade every big form strongly: the side away from the light clearly darker than the front, a thick
> shadow band under every eave, the bottom of each wall a shade darker, doors and windows set deep with a
> shadow on their top and left edge. Warm yellow only for window panes. Follow the project's steps exactly:
> measure, draw, check, and deliver the 1× PNG file for each: every one on a 96 × 96 canvas, fully
> transparent, at exactly the size and foot row given above.

## Results

- **Yurt**: 70 × 79, foot on row 87, exactly ours; **passes** (`form_relief` 0.0183, ours 0.0162). Its drawn
  smoke (rows 9 to 25) cut out, as the game now puffs moving smoke from its smoke hole (`LandStage.smokeHoles`,
  the user: "the smoke needs to be animated"). In the game.
- **Crystal cottage**: exact size; outline not dark enough beside the body, `form_relief` 0.014 (ours 0.0214).
- **Bell tower**: exact size; outline not dark enough, `form_relief` 0.013 (ours 0.0179), one colour too many.
  Both go back for a fix.
- **Gem workshop**: 79 × 56, foot on row 92, exactly ours; its night lights catch only its window's panes.
  Soft 93%, but flat (`form_relief` 0.0139, ours 0.0166): back for the same shading fix.
- **Crystal cottage, second try**: shading fixed (`form_relief` 0.0187), its outline overshot (`outline_rel`
  0.463); each outline pixel moved to the sprite's own colour nearest 24% lighter (1.22 to 1.28 all pass):
  **passes**, soft 93%. In the game (`chatgpt_2_fixed.png`).
