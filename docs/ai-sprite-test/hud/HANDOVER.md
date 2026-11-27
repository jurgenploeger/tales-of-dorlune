# The carved-wood HUD, drawn by ChatGPT (direction A)

The user's pick (2026-11-27): the interface restyled from glossy blue to richly carved pale birch with
original mythical symbols (moon phases, eight-point stars, spirals, leaf runes, a tree-of-life
medallion), the art drawn by ChatGPT's image model. "Direction A, Birch & Leaf" of four mocked up over
the real HUD (the artifact https://claude.ai/artifact/BbEWKRiYCnw6yJi5iCTtyK; its renders here as
`mockup_A_*.png`, the wood in them a CSS stand-in).

## Order

1. `1_minimap_A.txt`: the minimap's ring, compass medallion and needle. **Done**, picked:
   `art-variants/hud/minimap/` (1280 × 1280 each, hard alpha, about 40 colours, ring 1127 px across,
   window 900, ring 10% of its width; ChatGPT's own `asset_checks.json`, which matches what we measured).
   The user: "The style is exactly the style direction I was hoping for."
2. `2_hud_kit_A.txt`: the rest of the HUD. **Done**, picked: `art-variants/hud/kit/` (11 pieces and
   their 11 `_dark` twins, 1280 × 1280, hard alpha, 35 to 40 colours; the minimap's three unchanged from
   the first pick; ChatGPT's `asset_checks.json` gives each piece's bounds, centres, diameters, the
   plates' stretch rectangles and cap insets, the bar grooves' and name strip's rectangles, the level
   socket, and every light-to-dark colour mapping). Checked: every dark twin has its light piece's alpha
   pixel for pixel and one dark colour per light one, 31 to 48% darker. `kit_contact_sheet.png`.
3. `3_windows_tabs_speech_A.txt`: windows, tabs, close button, rows, speech window, chat bubble.
4. `4_buttons_A.txt`: the buttons' pictures.

`follow_ups_if_it_drifts.txt` has the nudges.

**Dark Mode at the same time** (the user, 2026-11-27): prompts 2 to 4 ask for a `_dark` twin of every
piece, the minimap's three too: the same drawing pixel for pixel (so the game swaps one for the other,
as `Color.adaptive` swaps colours), the birch stained a dusky walnut about 40% darker and cooler, the
inlays a touch brighter, the insets darker still; in the windows a deep warm brown pane for cream text.

## Checked in the game's size (`minimap_in_game.png`)

On today's screenshot (`hud_today_landscape.png`, Sunny Meadow, 2026-11-27), ring at 136 points: the
moons and stars still read as carving at 1×; it holds over the dark grass and, by a thin brown line only,
over the sand road (the kit prompt asks for a bolder outline). Decisions:
- **The ring grows** (the user): its window is 0.8 of its width, so at 136 points it showed 108 of the
  map, under today's 114. Draw it at about 143 points across, so the window is today's map.
- No N on the compass: the prompt ruled out letters; the needle's red half is north.
- ChatGPT's `_8x` files were nearest blow-ups of the same pictures (100 megapixels each): not kept.

## The kit at game size (`kit_in_game_light_dark.png`, `kit_in_game_closeups.png`)

Laid on a HUD-free landscape shot (Meadowbrook, sand and grass) at the game's sizes: portrait ring 76
points, plate 226 × 70 (stretched in its middle, `stretch_rect`), pills 27 tall, minimap 143, compass 42,
buttons 56 with the game's pixel icons (`ui_talk`, `ui_backpack`, `ui_more`, the Bag's pressed),
joystick 142 and knob 58; names and figures in Allo Dorlune, the face and map from today's HUD.
- The 3 px outline holds the pale wood over sand and grass.
- The plate's name strip (`name_content_rect`) is about 10 points tall: the name fits at 11 points,
  with no room for the HP, MP and XP labels beside the bars; the bars' colours carry them, or the label
  goes inside the bar ("HP 60/60").
- Dark: dark wood under cream lettering and the same bars; heavier on a bright day's world, as the dark
  glass is today.

## Still to do

Wire the pieces into `WorldHUD` / `HUDStyle` once the kit is in (the game-ui skill: mock-up first,
Screenshots in portrait and landscape, light and dark), with the dark twins for Dark Mode; then update
the skill's opening (it still describes FO's look as glossy blue) and Figma's 07 Game UI.
