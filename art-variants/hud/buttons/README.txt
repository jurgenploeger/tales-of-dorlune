TALES OF DORLUNE — COLOURED ENAMEL HUD BUTTONS

13 designs, 52 PNGs: normal and pressed, each in light and dark.
Each game PNG is 1280 × 1280 with binary transparency and at most 48 opaque RGB colours.
The picked circle is 1041 × 1041 px, bbox [120,120,1161,1161], centre (640,640).

FILENAMES
button_chat, button_inventory, button_menu, button_character,
button_companions, button_friends, button_quests, button_settings,
button_world_map, button_spells, button_attack, button_items, button_run_away.
For each stem:
  <stem>.png                 Light, normal
  <stem>_pressed.png         Light, pressed
  <stem>_dark.png            Dark, normal
  <stem>_pressed_dark.png    Dark, pressed

The four actual picked button_round bases are reused. Every pixel outside each
new picture is identical to that base. Pixels outside the union of the old and
new pictures also match the previous button. The carving and rim are preserved.
The 625 px picture envelope is about 60% of the 1041 px visible button. The prior 48%
measurement was relative to that same diameter, not the narrower inset face.
Pressed pictures move down exactly 2 px and use a darker palette. Their shape
doesn't change. Each light/dark pair uses pixel-identical picture colours;
only the wood changes between modes.

CONTRAST — KNOWN LITERAL LIMIT
The 6 px dark-brown outline cannot reach 3:1 against the fixed dark pressed face:
even a black outline would reach only about 2.62:1. The brown outline also falls
below 3:1 on the normal dark face. Those raw failures are explicitly recorded in
asset_checks.json, so all_checks_pass is false for that disclosed requirement.
A crisp 2 px pale enamel edge complements the brown outline. The stronger stroke
against each actual adjacent wood colour meets 3:1 in all states. It has no blur
or glow. The file separately reports raw outline contrast, pale-edge contrast,
and effective two-tone contrast; the last is not a raw-outline compliance claim.
All canvas, alpha, palette, geometry, state and preservation checks pass.

DELIVERY
dorlune_hud_buttons_light.zip and dorlune_hud_buttons_dark.zip are independent
ordinary ZIPs, each below 30,000,000 bytes. Each includes 26 PNGs, their 26 matching
8× previews and the same 8 shared review/document files. Extract both into one
folder for the complete kit. Shared files are identical in both ZIPs.

REVIEW FILES
contact_sheet.png: light row on mid-green, dark row on navy; normal/pressed pairs
at 56 pt and 22 pt on a 3× display, with picked blank frames for comparison.
contact_sheet_compact.png: compact light/dark review cards.
phone_size_checks.png: whole-button pairs at 22/56 px and 66/168 px.
Point labels refer to the full 1280 px canvas, retaining its transparent margins.
asset_checks.json: measurements, source preservation, unchanged enamel colours,
pressed shifts, exact 8× preview verification and all contrast calculations.
glyph_geometry.json: per-picture bounds, size, centres, palettes and shift.
palette.json: the per-picture normal and pressed enamel palettes.
art_direction_prompts.txt: the exact image-generation prompts.
previews_8x/: 52 exact nearest-neighbour inspection previews, each 10240 × 10240 px.

Use the 1280 px PNGs in the game. Review-sheet labels/backgrounds aren't game art.
Rectangles use exclusive right/bottom coordinates. Colour counts exclude alpha 0.
