TALES OF DORLUNE — CARVED BIRCH WINDOW KIT

34 primary transparent PNGs: 17 light pieces and their _dark twins.
Every primary PNG is 1280 x 1280. Use these native files in the game.
previews_8x/ contains exact 8x nearest-neighbour inspection enlargements.

LIGHT / DARK
Light uses the picked HUD birch and inlays, with quiet parchment content areas.
Dark uses dusky walnut and deep warm brown content areas. Dark twins change
colours only: alpha, silhouettes, carving positions and pixel regions are identical.
The orange close-button face keeps its orange colour.

PLACEMENT AND RESIZING
Bounding boxes and rectangles in asset_checks.json use exclusive right/bottom edges.
The asset centre is a placement anchor; the visible bounding-box centre is also given.
For 9-slice assets, crop to slice_rect (or visible bounding box), preserve the
corner sizes/cap insets, tile carved edge bands, and fill the plain centre.
Do not stretch corner ornaments. The source PNG keeps the entire piece centred.
The outer canvas is transparent; parchment and recessed text panes are opaque.

MAIN WINDOW FRAME AT PHONE SCALE
Use window_frame at 9 source pixels per iPhone point. Its straight rails are
51-52 source pixels, so they render at 5.67-5.78 points. Keep this rail/corner
scale fixed and extend the edge tiles to reach the required window width/height.
Do not enlarge the entire 1280px master to fit a large menu: that thickens the rails.
The four corner crops are 192 x 192 source pixels (21.33 x 21.33 points).
The horizontal motif period is 216px; the vertical motif period is 152px.
The canonical top/bottom/left/right tiles and their one-pixel neutral profiles
are in slices/window_frame/ and slices/window_frame_dark/.
For each edge, place as many complete canonical motif tiles as fit. Distribute
the leftover native pixels as neutral-profile gaps before/between/after those
tiles. Never truncate a moon or star to meet a corner. Match each directional
tile to its own edge so the original top-left lighting stays correct.

TITLE BAR AND FOLDER TABS
Title and open-tab files use horizontal three-slice resizing at 9 source pixels
per point. Their complete end caps are 168px and 224px respectively; only the
single-column plain centre repeats. Their native heights are 184px and 291px.
Keep folder-tab feet joined to the pane. The closed-tab piece is a divider,
so there is no filled inactive tab face.
The open tab intentionally has no dark border across its bottom opening.
Place that opening directly against the same parchment pane colour and keep
the underlying title-bar lower outline behind the tab, not across its face.

SPEECH AND INSET CONTENT
The speech name plaque, next arrow and row divider are independent assets.
They can be positioned without stretching their symbols.
The speech plate reserves a plain right-hand end for the large speaker overlay.
Use the recorded content_rect for text so it stays clear of that speaker.
The chat bubble tail remains within its fixed left cap during horizontal resizing.
Insets are plain, recessed text fields. Add row_divider separately for any row count.

FILES
contact_sheet.png: one light row on mid-green and one dark row on deep navy.
The picked minimap at the left is a visual reference and is not a new asset.
contact_sheet_compact.png: the same kit in a six-column review layout.
asset_checks.json: measured pixel checks, cap sizes, content regions and colour maps.
slices/: native crops of the supplied 9-slice masters; these technical
patches are not 1280px canvases. Their source rectangles are in the JSON.
assembly_proofs/: tiled examples at recorded sizes, preserving all four corners.
window_assembled_light_dark.png in that folder is a blank 720 x 330-point
menu at 2x display scale, with the open tab joined directly to the pane.

NOTES
Use the 1280 x 1280 primary PNGs in the game; previews_8x are exact inspection enlargements.
The 40-entry shared material palette yields 17-32 used opaque colours per piece. Simple lines intentionally use fewer shades; no dithering or filler pixels are added.
The frame has four whole 192 x 192 px corners. At 9 source px per point, its 51-52 px straight rails measure 5.67-5.78 points.
Repeat complete carved edge tiles. For non-multiple lengths, use the supplied neutral profiles for the remainder, so no moon, star or leaf is cut at a corner.
The open tab has a borderless parchment foot; overlap it with the pane at its recorded bottom_join_y. tab_closed is a transparent-backed divider only.
The speech plaque, next arrow and row divider are separate so their symbols and positions stay fixed when their parent panels resize.
The exterior canvas is transparent. Text panes are deliberately opaque, flat parchment in light mode and deep warm brown in dark mode.

PRIMARY LIGHT FILES
window_frame.png
window_title_bar.png
tab_open.png
tab_closed.png
close_button.png
close_button_pressed.png
inset_panel.png
row_divider.png
section_heading_ornament.png
button_capsule.png
button_capsule_pressed.png
button_capsule_gold.png
button_capsule_gold_pressed.png
speech_window.png
speech_name_plaque.png
speech_next_arrow.png
chat_bubble.png
