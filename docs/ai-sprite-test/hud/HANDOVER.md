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
3. `3_windows_tabs_speech_A.txt`: the windows. **Done**, picked: `art-variants/hud/windows/` (17 pieces and
   their 17 `_dark` twins: window frame, title bar, open tab, closed-tab divider, close button and pressed,
   inset panel, row divider, section rule, capsule buttons plain and gold with pressed, speech window,
   name plaque, next arrow, chat bubble; `slices/` the frame's, tab's, bar's and panel's cut pieces;
   `geometry.json` every piece's slice and content rectangles, cap insets and the scale: **9 source pixels
   a point**, the frame's rails 5.7 points, its corners 21; edge motifs tile whole, 216 px along, 152 down,
   leftovers spread as one-pixel neutral columns). Checked: every dark twin has its light one's alpha
   and one dark colour per light one. `windows_contact_sheet.png`.
4. `4_buttons_A.txt`: the buttons' pictures. **Done**: `art-variants/hud/buttons/` (13 designs, normal and
   pressed, light and dark: 52 PNGs on the picked `button_round` bases, every pixel outside the picture
   the base's own; each dark twin one dark colour per light one; ChatGPT's JSON for light and dark, its
   README and prompts). At 56 points (`buttons_game_size.png`) the light ones read, their outline 5 : 1 to
   the face (chat's 2.1). **The dark ones are faint**: a dark carving on dark wood, outline 2.2 : 1, under
   the 3 : 1 an icon needs. Tried (`buttons_dark_inlay_try.png`, bottom row): the light picture inlaid in
   the dark button, pale birch in walnut. The user, 2026-11-27: "The visuals inside the buttons are a bit hard to
   recognise, because they look very similar and there's not much contrast": `4b_buttons_colour_A.txt` asks
   ChatGPT to redraw only the pictures, each an enamel inlay in its own colours, bigger (60% of the face),
   with a 6 px dark outline, keeping their colours in the dark twins. **Done**, picked:
   `art-variants/hud/buttons/` (the carved-only first set kept in `art-variants/hud/buttons_carved/`). Every
   pixel outside a picture is the picked base's; light and dark pictures pixel-identical, only the wood
   changes. At 56 points (`buttons_colour_game_size.png`, `hud_with_buttons.png`) each reads at a glance by
   its colour. ChatGPT flagged that no outline reaches 3 : 1 on the dark pressed face (black would be
   2.62 : 1); the pictures' own colours carry them there (the bag's brown on walnut the weakest, 1.35).

5. `5_menu_battle_bits_A.txt`: the menus' and battles' small pieces. **Done**: `art-variants/hud/bits/` (18 pieces
   and their dark twins: item slot normal, selected and empty, equip slot, switch off, on and its knob, slider
   track and knob, square icon button and pressed, progress groove, count badge, notice dot, page dots, battle
   nameplate, turn timer ring; `geometry.json` their insets and caps). Every dark twin its light one's alpha,
   one dark colour per light one. At game size (`bits_game_size.png`): all read; the selected item slot's gold
   rim was faint in the light look, so `tools/hud_wood_art.py` deepens its three gold tones to a richer amber
   (`art-variants/hud/fixed/item_slot_selected.png`, `selected_slot_fix.png`: as drawn, then fixed).

6. `6_last_pieces_A.txt`: the last pieces. **Done**: `art-variants/hud/last/` (11 pieces and their dark twins: toast
   plate, banner, reward card, dropdown menu and its selected row, text field, scroll track and thumb, party frame,
   tutorial arrow, map pin). Every dark twin its light one's alpha, one dark colour per light one. At game size
   (`last_pieces_in_game.png`, light and dark over the HUD kit) all read and match the kit. With it the carved-wood
   art is complete.

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

## The windows at game size (`windows_in_game_light_dark.png`)

Quests with its tabs and NPC speech, light and dark, over the kit's HUD (assembled as `README.txt` says).
- The frame, title bar, folder tab, chips (the capsule three-sliced), sunk rows and close button read
  as one with the HUD; cream text on the dark pane, ink on the parchment.
- **The speech plate was drawn too short** (43 points at the kit's 9 pixels a point; the speech window is
  150), and **the dark list panel barely sat below the pane** (48,31,25 on 62,43,35). Both fixed in code,
  the originals kept (the user, 2026-11-27): `tools/hud_wood_art.py` writes `art-variants/hud/fixed/`
  and its `fixed.json`.
  - `inset_panel_dark.png`: its fill and inner shading darkened (×0.55), so it sits as far below the pane
    as the light panel does (contrast 1.39 : 1 each; it was 1.18).
  - `speech_window.png` / `_dark`: drawn at 4.5 pixels a point (at 9 its rails were a point thick and its
    carvings 6 points, beside the windows' 5.7-point rails), and grown to 150 points by repeating one
    plain row between the star and the leaf: moon and star stay at its top left, the leaf at its foot.
    The name plaque sits right of the carved band, so the moon shows. `windows_in_game_fixed.png`.

## Lines over heroes' heads stay simple

The user, 2026-11-27: "The chat messages from heroes in the game can still have the simplified version."
What heroes say over their heads (yours, other adventurers', the bots': `Walker.say` →
`Nodes.speechBubble`) keeps today's plain bubble; the carved `chat_bubble.png` isn't used for them. The
wood is for the HUD, the windows and talking to people (the speech window).

## Still to do

Wire the pieces into `WorldHUD` / `HUDStyle` once the kit is in (the game-ui skill: mock-up first,
Screenshots in portrait and landscape, light and dark), with the dark twins for Dark Mode; then update
the skill's opening (it still describes FO's look as glossy blue) and Figma's 07 Game UI.
