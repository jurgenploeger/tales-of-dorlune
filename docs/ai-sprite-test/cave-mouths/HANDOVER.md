# Cave mouths by ChatGPT (2026-11-25)

The way into a cave from the continent, in the rock face of a crag or a terraced mountain. Today the game paints
it into the hill's picture (`HillArt.cave`): a smooth black arch with a thin rim, "a black gap" (the user,
2026-11-25: "the gates should look more like a cave opening instead of a black gap"). A code-drawn try
(`tools/cave_preview.py`, `mouth_code_4x.png`) read as a cave but plain: a few generic boulders round a flat
dark hole. These are to replace it: one picture per cave, laid over the face by the game.

## How the game will use it

- Laid on the rock face with its bottom row on the face's foot, the road running in along that row. One pixel is
  one point in the game, the same size as a walker's pixels.
- The faces are upright on the screen but run along the map's diagonals, so the game shears the picture to lean
  with the face: each column moved up or down half a pixel for each pixel across, in whole pixels (as the town
  terraces' walls are, `tools/terrace_art.py`). Mouths facing west get it mirrored. So it's drawn face on, square
  to the viewer, not leaning.
- Graded with the land's palette as every sprite is: the rock in neutral warm grey so each land's grading turns it
  into that land's rock. Only a cave's own details keep their colour (timber, slime, glowing runes, crystals).
- The game won't scale it: the opening is drawn for a road three cells wide (88 points), the usual one.

## The layout (`layout_guide_8x.png`)

- Canvas exactly 128 × 80, transparent.
- The opening (dark blue in the guide) at the bottom middle: x 20 to 107, its sides straight up from the bottom
  row (79) to about row 52, then an arch up to row 24 at its top. Its outline may be rough and broken, as rock is,
  up to 3 pixels in or out of the guide's, but it stays open down to row 79 across x 24 to 103.
- Inside it: not a flat black hole but a tunnel going back: its walls lit at the edge of the opening, stepping
  down into the dark in a few flat tones toward the middle and the top; the darkest a deep tinted near-black
  (about `#14101a`), never pure black. Its floor (orange in the guide, rows 72 to 79) is the road running in: a
  sandy dirt in the bottom rows (`#e1c589` and darker shades of it), darker and darker the further in, gone into
  the dark by about row 66.
- Round it, the rock frame (sandy in the guide): at least 6 pixels of rock all round the arch and down both
  sides to the bottom row. From there out toward the canvas's edges the frame breaks up raggedly into transparent
  pixels (big rocks jutting, gaps between them), never a hard rectangle or a hard circle, so it sits on the cliff
  face behind it (`cliff_face_4x.png`) as if part of it. Nothing opaque in the bottom row outside the frame's feet.
- The frame's rock in warm greys like the cliff's own (`#6b625b`, `#877b72`, `#a5958e`, with a deep `#3a3330`
  outline and shadow), big stones with a lit top-left edge and a dark lower-right, a keystone or a big boulder
  over the top of the arch, a little rubble at the feet either side of the road. Its underside (the overhang
  inside the top of the arch) in deep shadow.

Files to attach, in this order: `layout_guide_8x.png`, `cliff_face_4x.png` (the face it goes on, and the
rock's look), `mouth_now_4x.png` (today's, to replace), `mouth_code_4x.png` (code's try, to beat), and
`../new-buildings/style_reference_4x.png` (the look). Back here: copy each 1× PNG into
`art-variants/cave_mouth/`, and I fit them in (a `PICKED` table, the shear, `HillArt.cave` laying the picture
instead of painting the arch).

## The prompt

> Draw the entrances to my game's caves, one at a time, as the project's instructions say. Each is laid by the
> game over a cliff face of rock, the road running into it along its bottom row; the attached guide shows its
> layout, which must be exact:
>
> - Canvas exactly 128 × 80, transparent. Drawn face on (square to the viewer, not leaning): the game leans it
>   to fit the face.
> - The opening (dark blue in the guide): x 20 to 107, its sides straight up from the bottom row (79) to about
>   row 52, then arched up to row 24 at its top. Its outline rough like broken rock, up to 3 pixels in or out of
>   the guide's, but open all the way down to row 79 across x 24 to 103, where the road goes in.
> - Inside it, a tunnel going back into the dark, not a flat black hole: its walls lit at the opening's edge and
>   stepping down in 4 or 5 flat tones toward the middle and the top, the darkest a deep tinted near-black
>   (about `#14101a`), never pure black. The overhang just inside the top of the arch in deep shadow. Its floor
>   in the bottom rows the road running in: sandy dirt (`#e1c589` and darker shades of it) on row 79, darker
>   the further in, gone into the dark by about row 66.
> - The rock frame round it: at least 6 pixels of rock round the arch and down both sides to row 79, then
>   breaking up raggedly toward the canvas's edges (big jutting rocks, gaps between them, transparent past
>   them), never a hard rectangle or circle, so it melts into the cliff face (attached) it's laid on. A
>   keystone or a big boulder over the arch, a little rubble at the feet either side of the road. Its rock in
>   warm neutral greys like the cliff's (`#6b625b`, `#877b72`, `#a5958e`, outline and shadow about `#3a3330`):
>   the game recolours it for each land, so no other colour in the rock itself.
>
> Match the style sheet's look (soft rounded shapes, chunky tinted outline, broad shading lit from the top left,
> cute and storybook), 40 to 70 colours, alpha 0 or 255 only. One cave at a time, each with its own touch:
>
> 1. `cave_mouth`: a plain cave in a mountainside; mossy stones on the frame, a few hanging roots.
> 2. `cave_mouth_rat`: the Rat Cavern: old timber props (two posts and a beam) shoring up the opening just
>    inside the rock, a crooked plank sign with a rat's face scratched on it nailed to one post, gnawed edges.
> 3. `cave_mouth_slime`: the Gooey Grotto: green slime dripping over the arch's top and pooling at the
>    feet, a few bubbles; glossy, a bright highlight on each drip.
> 4. `cave_mouth_hollow`: the Whispering Hollow: faint teal runes carved into the frame's stones, glowing softly
>    (flat pixels, no blur), pale roots hanging over the top, a wisp of mist on the floor inside.
> 5. `cave_mouth_glimmer`: the Glimmerdeep: pink and pale blue crystals growing out of the frame round the arch,
>    a few small ones inside on the tunnel walls catching the light.
>
> Before you deliver each, check with code and report: the canvas is 128 × 80; every pixel in x 24 to 103 of
> row 79 is opaque and sandy (the road); every pixel inside the guide's opening is opaque; the frame is opaque
> for at least 6 pixels round the opening; the colour count; alpha only 0 or 255; no pure black. Then deliver its
> 1× PNG named by its id, its 8× preview, and a preview of it laid on the attached cliff face (its bottom row on
> the face's foot, at 4×), then the next.

## Which cave gets which

| Picture | Cave | Its mouths |
| --- | --- | --- |
| `cave_mouth_rat` | Rat Cavern | Valley of Fear, Lotus Land |
| `cave_mouth_slime` | Gooey Grotto | Northern Grassland |
| `cave_mouth_hollow` | Whispering Hollow | Moonglow, Emerald Road |
| `cave_mouth_glimmer` | Glimmerdeep | Starfall Isle |
| `cave_mouth` | any other, now or later | |

## Inside the caves

Not part of this hand-off: a cave's inside is laid out cell by cell to fit its passages, so it stays drawn in
code. Its plan is the plateau look (`tools/cave_preview.py`, "inside, as plateaus": the rock between the passages
raised a level, its edges the cliffs' sheer faces, its top dark rock with a pale lip), built alongside these.

## Results

- **2026-11-25**: four of five back, painted big (1586 × 992, about 12.4 pixels a pixel) on a real transparent
  background: `cave_mouth` (mossy, hanging roots), `cave_mouth_glimmer`, `cave_mouth_slime` and two takes on
  `cave_mouth_rat`, the second the pick (a small sign with a rat's face; the first's big sign read as a heart).
  Snapped to 128 × 80 by `tools/cave_mouth_art.py` (46 to 54 colours, the road row open on all four) and in the
  game (`LandStage.placeMouth`). `cave_mouth_hollow` still to come; the Whispering Hollow has the plain one.
