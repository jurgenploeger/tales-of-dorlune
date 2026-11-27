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
2. `2_hud_kit_A.txt`: the rest of the HUD (portrait ring, name plate with HP, MP and XP grooves, the pill
   for gold and time, round button, skill socket, joystick), the minimap attached as the style to match.
3. `3_windows_tabs_speech_A.txt`: windows, tabs, close button, rows, speech window, chat bubble.
4. `4_buttons_A.txt`: the buttons' pictures.

`follow_ups_if_it_drifts.txt` has the nudges.

## Checked in the game's size (`minimap_in_game.png`)

On today's screenshot (`hud_today_landscape.png`, Sunny Meadow, 2026-11-27), ring at 136 points: the
moons and stars still read as carving at 1×; it holds over the dark grass and, by a thin brown line only,
over the sand road (the kit prompt asks for a bolder outline). Decisions:
- **The ring grows** (the user): its window is 0.8 of its width, so at 136 points it showed 108 of the
  map, under today's 114. Draw it at about 143 points across, so the window is today's map.
- No N on the compass: the prompt ruled out letters; the needle's red half is north.
- ChatGPT's `_8x` files were nearest blow-ups of the same pictures (100 megapixels each): not kept.

## Still to do

Wire the pieces into `WorldHUD` / `HUDStyle` once the kit is in (the game-ui skill: mock-up first,
Screenshots in portrait and landscape, light and dark), with a darker twin for Dark Mode; then update
the skill's opening (it still describes FO's look as glossy blue) and Figma's 07 Game UI.
