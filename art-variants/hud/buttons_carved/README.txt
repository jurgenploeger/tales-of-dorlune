TALES OF DORLUNE — CARVED HUD BUTTONS

13 designs, 52 game PNGs: normal and pressed, each in light and dark.
Each game PNG is 1280 × 1280 with binary transparency and at most 40 opaque RGB colours.
The visible circle is 1041 × 1041 px, bbox [120,120,1161,1161], centre (640,640).

NAMES
button_chat, button_inventory, button_menu, button_character,
button_companions, button_friends, button_quests, button_settings,
button_world_map, button_spells, button_attack, button_items, button_run_away.

For each stem:
  <stem>.png                 Light, normal
  <stem>_pressed.png         Light, pressed
  <stem>_dark.png            Dark, normal
  <stem>_pressed_dark.png    Dark, pressed

The four picked button_round bases are reused. Every pixel outside the glyph
is exactly the corresponding original base pixel, including the rim and inset.
All glyphs share a 248 px radial envelope centred at (640,640), leaving about 130 px
to the face boundary. Different aspect ratios retain their proportions.
The pressed state uses the picked recessed face and slightly darker carving.
Its glyph doesn't jump or change shape. Dark twins use the picked kit's exact,
injective light-to-dark palette lookup; geometry and alpha don't change.

Pictures use the existing wood ramp plus up to three exact sage/gold inlay RGBs.
The book's star reads bright through enamel contrast; it has no glow effect.
Menu uses three bars so it stays distinct from the spell book.

FILES
contact_sheet.png: all normal/pressed pairs in a light row on mid-green and a
dark row on deep navy; original blank frames appear at the left for comparison.
contact_sheet_compact.png: the same set in compact review cards.
phone_size_checks.png: glyphs at 22 px and 66 px (22 pt on a 3× display).
asset_checks.json: all canvas/bbox/colour/alpha/centre measurements, original
frame preservation, colour-only dark pairs, pressed states and exact 8× checks.
glyph_geometry.json: each picture's position, envelope, colour accents and mask.
palette.json: exact 40-colour light/dark palette and original base checksums.
art_direction_prompts.txt: the prompts used to generate the carved artwork.
previews_8x/: 52 exact nearest-neighbour previews, each 10240 × 10240 px.

Use the 1280 px PNGs in the game. The 8× PNGs are inspection previews.
Rectangles use exclusive right/bottom coordinates. Colour counts exclude alpha 0.
Review-sheet labels and coloured backgrounds aren't part of any game asset.
