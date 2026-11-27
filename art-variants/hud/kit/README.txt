TALES OF DORLUNE — BIRCH & LEAF HUD KIT

22 primary transparent PNGs: 11 light pieces and their 11 _dark twins.
Every primary PNG is 1280 x 1280. Use those files in the game.
previews_8x/ contains exact nearest-neighbour inspection enlargements.
contact_sheet.png shows all light pieces on mid-green and matching dark pieces
on deep navy in the same column order.

The three picked light minimap PNGs are unchanged from the supplied ZIP.
Every dark twin keeps its light PNG's alpha and all drawing regions pixel for
pixel. Only palette colours change; the red needle half stays red.

asset_checks.json contains actual bounds, centres, colour counts, alpha hashes,
round diameters, inset dimensions, named content rectangles, cap insets and
every light-to-dark colour mapping. Bounding rectangles use exclusive right
and bottom coordinates. A zero inner diameter means a solid face, not a hole.

hero_plate.png and pill_plate.png have 1128 x 376 visible bounds, exactly3:1.
Their central stretch rectangles and cap insets are recorded in the JSON.
Keep the rounded caps whole; stretch the plain centre horizontally.
The status plate has exactly three recessed grooves plus a blank name area.

The normal and pressed round buttons have identical silhouettes and outer
ornament. The pressed change is restricted to the inner face and bevel.
Portrait and skill apertures are fully transparent. Other inset faces remain
solid wood. No words, numbers, bar fills or button pictures are baked in.

The joystick phases run clockwise from the top: new, waxing crescent, first
quarter, waxing gibbous, full, waning gibbous, last quarter, waning crescent.
Its four small arrowheads point north/east/south/west.
