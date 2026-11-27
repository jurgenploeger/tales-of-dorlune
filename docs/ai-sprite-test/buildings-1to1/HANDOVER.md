# Every building at its own size, by ChatGPT (2026-11-27)

The user, 2026-11-27: "Yes now keep going with the town buildings. I want to do big batches at once with chatgpt."
`tools/pixel_scale.py` lists 118 buildings drawn bigger than the walkers' pixels: every building is a 96-pixel
drawing (160 or 192 for the five landmarks) shown at `scale` 1.35, so each art pixel is 1.35 of the hero's, 4 screen
pixels on a phone against the hero's 3. Drawn at the size it's shown (130 × 130, 216, 259), each pixel is the hero's.

111 to draw: 26 of Retro Diffusion's, 85 drawn by ChatGPT or in code. The 7 recolours (`house_green`, `house_purple`,
`inn_red`, `inn_teal`, `item_shop_red`, `sleepy_cottage_lilac`, `guild_hall`) follow their base. Redrawing RD's is the
user's call (CLAUDE.md keeps RD's art as drawn in code): their "keep going with the town buildings" after the list.

**One view for all** (the user, 2026-11-27: "The adobe house tall looks from the front, while all our other
buildings have an angle, we should update that across all the buildings as well"). Today about half face straight on
(`adobe_house_tall`, `candy_cottage`, `puppet_theater`, `snow_cabin`, `stone_hut`, `thatched_cottage`, `tea_house`,
`music_hall`, `toll_house`, the five landmarks...) and half are seen from a corner (`inn`, `apothecary`, `armour_shop`,
`weapon_shop`, `timber_house`, `crystal_cottage`, `creaky_mill`, `tailor_shop`: `style_reference_corner_4x.png`). The
corner view is the one that sits on the ground, which the game draws as diamonds, so every redraw takes it: the front
wall with the door facing down and to the left, the right-hand side wall running back up to the right in shade, the
roof seen a little from above. Round buildings (a yurt, an igloo, a lighthouse, a tent) stay round, seen a little from
above, their door on the left of the front.

Each new size is today's times 1.35: its canvas, width, height and foot row (its lowest pixel's row), the building
centred as today's, so it stands where it stands and as big.

## How to run it

One chat per batch in the ChatGPT project. In the first message attach the batch's pictures in order (the style
sheet, then its sheets of today's drawings at 4×, four to a sheet, each labelled with its number, id and new size;
nine pictures at most), paste the prompt and the batch's list. Send "next" after each. If its drawings start to
drift (sizes off, the look changing, colours creeping up), start a fresh chat with the same pictures and the prompt,
and add "Continue from number N." Bring the 1× PNGs back named by their id, zipped, a batch at a time.

## The prompt

> Redraw these buildings from my game bigger, one at a time, as the project's instructions say, except where this
> message says otherwise. The first picture is our style sheet: eight of our buildings at 4×, all seen from the same
> corner. The others are sheets of today's drawings at 4×, four to a sheet, each labelled with its number, id and its
> new size.
>
> **Every building in the style sheet's corner view**, whichever way today's picture faces: the front wall with the
> door facing down and to the left, the right-hand side wall running back up to the right in shade, the roof seen a
> little from above, lit from the top left. Many of today's pictures face straight on: turn them to this view. A round
> building (a yurt, an igloo, a tent, a tower) stays round, seen a little from above, its door on the left of its
> front.
>
> **Don't measure the sizes from the pictures.** Today's are drawn at 96 pixels and shown 1.35 times bigger in the
> game, so their pixels are bigger than the characters'. Each new one is drawn at the size it's shown: the canvas,
> width, height and foot row in the list (the foot row is the row its lowest pixel stands on). It's the same building:
> the same shape, colours, door, windows, signs and props, with the detail a bigger canvas holds (more roof tiles,
> bricks, planks, trim and small touches), turned to the corner view where it isn't. Never today's picture scaled up.
> Turned, its width and height may move a little (within a tenth); its canvas and foot row stay exactly as listed.
>
> Every one:
> - Transparent, alpha 0 or 255 only, centred left to right, its lowest pixel on the foot row.
> - No ground, slab, base or cast shadow under it. Where today's stands on a patch of ground or a stone slab, leave it
>   out and keep the building itself as big (a few grass tufts or a doorstep at most).
> - Window panes in a warm bright yellow that nothing else uses (the game lights them at night). Where today's has
>   yellow thatch, cloth, an awning or gold, make it a straw, cream or orange tone clearly unlike the panes.
> - No smoke drawn from a chimney or stack (the game animates it).
> - 40 to 70 colours on a 130 canvas, 60 to 90 on the bigger ones, hue-shifted, a tinted outline, lit from the top left.
> - Natural colours (the game tints each land's art itself).
>
> For each: say its number, id, size, foot row and colour count, deliver its 1× PNG named by its id and the 4×
> preview, then wait for "next".
>
> Here's the list:


### Batch 1: Retro Diffusion's buildings (26)

**Brought in 2026-11-27 (0.9.254).** All 26 came back at their box and foot row exactly, hard alpha. Windows recut
(new `BOXES` for the house, the tall adobe house and the stilt hut; the adobe house, candy cottage and fisher's
shack have none), the pagoda's and stilt hut's lanterns re-rigged, the forge's fire re-boxed, the inn's and snow
cabin's chimneys moved, nothing left to deslab. Left as they are: the house's three roof recolours keep a few
orange specks on the roof's lightest tiles. The witch hut's first try lost its character (pale stone, a black hole
for a door); its second (`witch_hut_redo/`, 2026-11-27) is in, the first kept as `witch_hut_try1.png`. Still: the house's three roof recolours keep a few
orange specks on the roof's lightest tiles (no hue window takes them without the door); `pixel_style.py`'s
building bands, calibrated on RD's 96-pixel drawings, fail several of them narrowly (`form_relief` most): recalibrate
once all four batches are in.

Attach `batch1/0_style_reference_corner_4x.png` first, then `batch1/sheet_1.png` to `sheet_7.png` in order. The prompt, then this list:

> 1. `adobe_house`: canvas 130 × 130, 93 wide, 97 tall, foot row 107
>
> 2. `adobe_house_tall`: canvas 130 × 130, 95 wide, 97 tall, foot row 112
>
> 3. `bakery`: canvas 130 × 130, 78 wide, 88 tall, foot row 102
>
> 4. `beach_hut`: canvas 130 × 130, 76 wide, 85 tall, foot row 106
>
> 5. `blacksmith`: canvas 130 × 130, 77 wide, 85 tall, foot row 102
>
> 6. `candy_cottage`: canvas 130 × 130, 100 wide, 96 tall, foot row 111
>
> 7. `crooked_house`: canvas 130 × 130, 96 wide, 113 tall, foot row 118
>
> 8. `desert_tent`: canvas 130 × 130, 105 wide, 95 tall, foot row 111
>
> 9. `dwarf_cottage`: canvas 130 × 130, 104 wide, 96 tall, foot row 107
>
> 10. `fisher_shack`: canvas 130 × 130, 96 wide, 81 tall, foot row 103
>
> 11. `forest_lodge`: canvas 130 × 130, 105 wide, 100 tall, foot row 116
>
> 12. `house`: canvas 130 × 130, 109 wide, 107 tall, foot row 116
>
> 13. `igloo`: canvas 130 × 130, 107 wide, 108 tall, foot row 116
>
> 14. `inn`: canvas 130 × 130, 89 wide, 96 tall, foot row 106
>
> 15. `item_shop`: canvas 130 × 130, 107 wide, 105 tall, foot row 118
>
> 16. `lily_cottage`: canvas 130 × 130, 96 wide, 105 tall, foot row 118
>
> 17. `magic_tower`: canvas 130 × 130, 51 wide, 108 tall, foot row 112
>
> 18. `moon_pagoda`: canvas 130 × 130, 108 wide, 101 tall, foot row 112
>
> 19. `puppet_theater`: canvas 130 × 130, 78 wide, 93 tall, foot row 106
>
> 20. `sleepy_cottage`: canvas 130 × 130, 92 wide, 99 tall, foot row 110
>
> 21. `snow_cabin`: canvas 130 × 130, 86 wide, 85 tall, foot row 102
>
> 22. `stone_hut`: canvas 130 × 130, 105 wide, 88 tall, foot row 107
>
> 23. `swamp_stilt_hut`: canvas 130 × 130, 93 wide, 105 tall, foot row 114
>
> 24. `water_shrine`: canvas 130 × 130, 101 wide, 105 tall, foot row 116
>
> 25. `windmill`: canvas 130 × 130, 61 wide, 92 tall, foot row 108
>
> 26. `witch_hut`: canvas 130 × 130, 120 wide, 111 tall, foot row 112


### Batch 2: the five landmarks and the first 23 town buildings (28)

**Brought in 2026-11-27 (0.9.257).** All 28 at their box and foot row exactly, hard alpha, faithful to the drawings
before (the moonwell's stone now lilac). `building_art.py` `PICKED` points them at `art-variants/buildings_1to1/`, the
96-pixel drawings kept in `art-variants/<id>/`. Windows recut (`BOXES` for six whose stone, thatch, hives or cap lit
up; the bell tower none), the armour shop's, book shop's and apothecary's signs and the guild's two flags re-rigged,
the apothecary's, brick house's and coral house's chimney smoke moved, and the acorn cottage's and beekeeper's new
chimneys given smoke.

Attach `batch2/0_style_reference_corner_4x.png` first, then `batch2/sheet_1.png` to `sheet_7.png` in order. The prompt, then this list:

> 1. `emerald_spire`: canvas 259 × 259, 167 wide, 219 tall, foot row 257
>
> 2. `moonwell`: canvas 216 × 216, 167 wide, 135 tall, foot row 215
>
> 3. `star_observatory`: canvas 216 × 216, 161 wide, 186 tall, foot row 215
>
> 4. `warrior_guild`: canvas 216 × 216, 171 wide, 128 tall, foot row 215
>
> 5. `wildfolk_lodge`: canvas 216 × 216, 174 wide, 124 tall, foot row 215
>
> 6. `acorn_cottage`: canvas 130 × 130, 107 wide, 101 tall, foot row 125
>
> 7. `apothecary`: canvas 130 × 130, 92 wide, 107 tall, foot row 121
>
> 8. `apple_cellar`: canvas 130 × 130, 101 wide, 88 tall, foot row 121
>
> 9. `armour_shop`: canvas 130 × 130, 107 wide, 89 tall, foot row 121
>
> 10. `assay_office`: canvas 130 × 130, 99 wide, 97 tall, foot row 121
>
> 11. `aviary_shop`: canvas 130 × 130, 101 wide, 103 tall, foot row 121
>
> 12. `bank`: canvas 130 × 130, 101 wide, 93 tall, foot row 126
>
> 13. `beekeeper_cottage`: canvas 130 × 130, 103 wide, 95 tall, foot row 121
>
> 14. `bell_tower`: canvas 130 × 130, 78 wide, 115 tall, foot row 126
>
> 15. `bluebell_house`: canvas 130 × 130, 81 wide, 109 tall, foot row 121
>
> 16. `book_shop`: canvas 130 × 130, 105 wide, 90 tall, foot row 121
>
> 17. `briar_cottage`: canvas 130 × 130, 100 wide, 101 tall, foot row 121
>
> 18. `brick_house`: canvas 130 × 130, 90 wide, 101 tall, foot row 121
>
> 19. `carved_chalet`: canvas 130 × 130, 103 wide, 103 tall, foot row 121
>
> 20. `chime_cottage`: canvas 130 × 130, 86 wide, 109 tall, foot row 121
>
> 21. `coral_house`: canvas 130 × 130, 93 wide, 97 tall, foot row 121
>
> 22. `creaky_mill`: canvas 130 × 130, 103 wide, 99 tall, foot row 121
>
> 23. `crystal_cottage`: canvas 130 × 130, 107 wide, 88 tall, foot row 121
>
> 24. `crystal_lodge`: canvas 130 × 130, 100 wide, 104 tall, foot row 121
>
> 25. `cupcake_house`: canvas 130 × 130, 89 wide, 105 tall, foot row 121
>
> 26. `dairy_shop`: canvas 130 × 130, 100 wide, 86 tall, foot row 121
>
> 27. `dome_house`: canvas 130 × 130, 80 wide, 109 tall, foot row 121
>
> 28. `dwarf_boathouse`: canvas 130 × 130, 104 wide, 92 tall, foot row 121


### Batch 3: town buildings, part 2 (28)

**Brought in 2026-11-27 (0.9.260).** All 28 at their box and foot row exactly, hard alpha, 64 colours each. Windows
recut (`BOXES` for seven: an awning, gold, a deck, rock and a lid lit up), the flower, gem and emerald shops' signs
and the pavilion's flag re-rigged, the glass-lantern shop's and firefly house's lanterns rigged by their own colours
(`sway_art.swing` `hues`/`sat`: boxed, the wall behind swung with them), five smoke points and the lighthouse's lamp
moved.

Attach `batch3/0_style_reference_corner_4x.png` first, then `batch3/sheet_1.png` to `sheet_7.png` in order. The prompt, then this list:

> 1. `emerald_shop`: canvas 130 × 130, 97 wide, 100 tall, foot row 121
>
> 2. `firefly_house`: canvas 130 × 130, 97 wide, 95 tall, foot row 121
>
> 3. `flag_tower`: canvas 130 × 130, 101 wide, 104 tall, foot row 121
>
> 4. `flower_cup_house`: canvas 130 × 130, 96 wide, 103 tall, foot row 121
>
> 5. `flower_shop`: canvas 130 × 130, 105 wide, 66 tall, foot row 119
>
> 6. `frog_hut`: canvas 130 × 130, 100 wide, 93 tall, foot row 121
>
> 7. `garden_cottage`: canvas 130 × 130, 105 wide, 68 tall, foot row 123
>
> 8. `gem_workshop`: canvas 130 × 130, 107 wide, 76 tall, foot row 125
>
> 9. `glass_lantern_shop`: canvas 130 × 130, 78 wide, 109 tall, foot row 121
>
> 10. `horse_stable`: canvas 130 × 130, 103 wide, 84 tall, foot row 121
>
> 11. `ice_cream_parlour`: canvas 130 × 130, 90 wide, 104 tall, foot row 121
>
> 12. `ice_fishing_hut`: canvas 130 × 130, 95 wide, 95 tall, foot row 121
>
> 13. `juice_shack`: canvas 130 × 130, 101 wide, 93 tall, foot row 121
>
> 14. `lake_pavilion`: canvas 130 × 130, 99 wide, 95 tall, foot row 121
>
> 15. `lake_shrine`: canvas 130 × 130, 105 wide, 86 tall, foot row 125
>
> 16. `lamp_house`: canvas 130 × 130, 105 wide, 50 tall, foot row 121
>
> 17. `lantern_cottage`: canvas 130 × 130, 103 wide, 95 tall, foot row 121
>
> 18. `lighthouse`: canvas 130 × 130, 84 wide, 107 tall, foot row 121
>
> 19. `lookout_hut`: canvas 130 × 130, 97 wide, 95 tall, foot row 121
>
> 20. `lotus_pagoda`: canvas 130 × 130, 97 wide, 103 tall, foot row 121
>
> 21. `miners_lodge`: canvas 130 × 130, 103 wide, 99 tall, foot row 121
>
> 22. `moon_teahouse`: canvas 130 × 130, 100 wide, 99 tall, foot row 121
>
> 23. `music_box_house`: canvas 130 × 130, 95 wide, 100 tall, foot row 121
>
> 24. `music_hall`: canvas 130 × 130, 105 wide, 105 tall, foot row 121
>
> 25. `nightcap_tower`: canvas 130 × 130, 86 wide, 105 tall, foot row 121
>
> 26. `owl_tower`: canvas 130 × 130, 81 wide, 109 tall, foot row 121
>
> 27. `painter_studio`: canvas 130 × 130, 103 wide, 97 tall, foot row 121
>
> 28. `pavilion_tent`: canvas 130 × 130, 105 wide, 99 tall, foot row 122


### Batch 4: town buildings, part 3 (29)

Attach `batch4/0_style_reference_corner_4x.png` first, then `batch4/sheet_1.png` to `sheet_8.png` in order. The prompt, then this list:

> 1. `pearl_diver_hut`: canvas 130 × 130, 95 wide, 99 tall, foot row 121
>
> 2. `pillow_cottage`: canvas 130 × 130, 93 wide, 93 tall, foot row 121
>
> 3. `pineapple_hut`: canvas 130 × 130, 95 wide, 107 tall, foot row 121
>
> 4. `post_office`: canvas 130 × 130, 103 wide, 93 tall, foot row 121
>
> 5. `raft_teahouse`: canvas 130 × 130, 100 wide, 95 tall, foot row 121
>
> 6. `reed_boathouse`: canvas 130 × 130, 103 wide, 93 tall, foot row 121
>
> 7. `round_cottage`: canvas 130 × 130, 78 wide, 109 tall, foot row 121
>
> 8. `sandstone_house`: canvas 130 × 130, 92 wide, 109 tall, foot row 121
>
> 9. `shell_house`: canvas 130 × 130, 95 wide, 95 tall, foot row 121
>
> 10. `smokehouse`: canvas 130 × 130, 99 wide, 95 tall, foot row 121
>
> 11. `spice_shop`: canvas 130 × 130, 103 wide, 86 tall, foot row 121
>
> 12. `star_dome`: canvas 130 × 130, 97 wide, 107 tall, foot row 121
>
> 13. `stick_house`: canvas 130 × 130, 92 wide, 103 tall, foot row 121
>
> 14. `stone_townhouse`: canvas 130 × 130, 97 wide, 111 tall, foot row 122
>
> 15. `straw_house`: canvas 130 × 130, 93 wide, 90 tall, foot row 121
>
> 16. `stump_house`: canvas 130 × 130, 103 wide, 101 tall, foot row 121
>
> 17. `swan_boathouse`: canvas 130 × 130, 100 wide, 101 tall, foot row 121
>
> 18. `tailor_shop`: canvas 130 × 130, 105 wide, 92 tall, foot row 121
>
> 19. `tea_house`: canvas 130 × 130, 105 wide, 74 tall, foot row 121
>
> 20. `teapot_house`: canvas 130 × 130, 101 wide, 69 tall, foot row 121
>
> 21. `thatched_cottage`: canvas 130 × 130, 105 wide, 86 tall, foot row 121
>
> 22. `timber_house`: canvas 130 × 130, 96 wide, 109 tall, foot row 121
>
> 23. `toll_house`: canvas 130 × 130, 103 wide, 95 tall, foot row 121
>
> 24. `toymaker_workshop`: canvas 130 × 130, 92 wide, 101 tall, foot row 121
>
> 25. `tree_house`: canvas 130 × 130, 97 wide, 113 tall, foot row 125
>
> 26. `weapon_shop`: canvas 130 × 130, 104 wide, 85 tall, foot row 121
>
> 27. `well_house`: canvas 130 × 130, 97 wide, 90 tall, foot row 121
>
> 28. `woodcutter_cabin`: canvas 130 × 130, 103 wide, 99 tall, foot row 121
>
> 29. `yurt`: canvas 130 × 130, 95 wide, 85 tall, foot row 118

## Bringing them in (for Claude)

For each: check its canvas, width, height and foot row against the list (snap to the grid with `tools/ai_sprite_eval.py`
if it's off-grid), opaque or clear pixels only, warm panes found by `tools/window_art.py`'s rule. Then:

- Copy it to `art/sprites/<id>.png` and `art-variants/buildings_1to1/<id>.png`; RD's originals kept in
  `art-variants/buildings_1to1/rd/`. Point `tools/building_art.py`'s `PICKED` at the new files, so a rerun keeps them.
- art/assets.json: `scale` 1 on the building and on each recolour of it; an RD building loses its `request` (its prompt
  kept in the `rd/` folder's notes), so the RD rule no longer covers the new drawing.
- Everything placed by pixel on the old drawings, redone or dropped: `tools/window_art.py` (`BOXES`, `PAINT`, `GLASS`,
  `SKIP` entries for the redrawn ids; rerun), `tools/sway_art.py` `PIECES` (signs, lanterns, flags) and
  `tools/wind_art.py`, `tools/fire_art.py` (the blacksmith's forge), `LandStage.smokeHoles` (the chimneys' and spouts'
  points, `*_nosmoke`), `tools/deslab.py` (`inn`, `magic_tower`), then `tools/grain.py`.
- `python3 tools/check_content.py`, `tools/pixel_scale.py` (every building at 1), `scripts/sprite_check.py check <ids>
  --new`, and a Screenshots run of the towns by day and night.
