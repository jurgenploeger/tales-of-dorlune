TALES OF DORLUNE — SMALL MENU AND BATTLE KIT

18 pieces/states, each with a dark twin: 36 primary PNGs. Each primary PNG is
1280 × 1280, has a transparent outer canvas, hard alpha 0/255 and at most 40 opaque
RGB colours. Each dark twin is exactly the same drawing and alpha mask, recoloured
through the kit's one-to-one palette table. No text or item pictures are baked in.

CONTENTS
The two ordinary ZIPs separate light and dark mode. Each is below 30,000,000 bytes
and contains 18 primary PNGs, their 18 matching 8× previews and these nine shared
documents/proofs. Extract both into the same directory for the complete kit.
The shared files are identical in both archives.

Primary PNGs are the game assets. previews_8x/ contains exact nearest-neighbour
10240 × 10240 inspections; every 8×8 block is checked against the primary PNG.

GEOMETRY AND STRETCHING
asset_checks.json records every canvas, visible bounding box, canvas centre,
bounding-box centre, colour count, alpha values, content/inset rectangles, caps,
dark-pair equality and preview checks. geometry.json provides the same integration
geometry without the full check report. Rectangles are [x0,y0,x1,y1], with right
and bottom exclusive. Coordinates are in the 1280px canvas unless named bbox_local.

Display-point sizes refer to visible artwork bounds, not transparent canvas
padding. Crop to bounding_box before fitting the piece to its stated phone size.
For sliders, progress grooves and battle nameplates, preserve the left/right caps
and repeat or stretch the plain middle only. The JSON gives cap widths relative
to the visible crop as well as full-canvas slice boundaries and cap insets.
Their centre columns and the cap join columns are pixel-identical. stretch_checks.png
shows each at three widths with unchanged ends.

STATE BEHAVIOUR
Item selected: same silhouette/inset, with soft-gold inlay along the rim.
Item empty: same frame, darker and flatter empty inset.
Square button pressed: same rim/silhouette, darker face with an extra recessed step.
Switch: the identical separate knob moves from left to right; on uses sage inlay.
Page dots: same outline; the on state uses gold inlay.
Timer: the entire central circular opening is transparent in both modes.
The small 7–18pt pieces have no carved symbols; the slider knob has its requested
small eight-point star and the timer carries eight moon phases.

CONTACT SHEETS
contact_sheet.png: full light row on mid-green and dark row on deep navy, with the
picked round button and capsule included at the left for style comparison.
contact_sheet_compact.png: the 18 pieces in a six-column layout, light above dark.
phone_size_checks.png: each piece at its stated/suggested visible point dimensions,
at 1× and 3× display density. Open at 100% when checking actual pixel sizes.

COLOURS
palette.json records the shared 40-colour maximum palette and exact dark mappings.
Most of the palette is copied from the picked HUD; the inset and gold entries match
the window kit. Green and gold inlays are a little brighter in dark mode, with no
glow. The artwork is front-on, lit from the top left, with dark brown outlines.
