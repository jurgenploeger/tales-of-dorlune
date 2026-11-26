# Walls by ChatGPT (2026-11-26)

The user, 2026-11-26: "Now lets have chatgpt create other walls as well" (after the gates' depth,
docs/ai-sprite-test/gate-depth). The walls still drawn in code:

- **A city's stone wall** (`tools/city_wall_art.py`, maps.json town `walls: "stone"`: Ingothold, Prismhaven):
  `city_wall` (the face), `city_wall_top` (the walk behind its battlements, seen from above) and `city_tower`
  (the round towers at its corners and gates).
- **The low field-stone walls along the roads** (`BorderArt.lowWallPicture` and `lowWallTop`, drawn in Swift):
  the face, the capstones on top, and an end where a wall stops (today a flat colour).

The terrace walls stay as they are: the user picked them from `tools/terrace_preview.py`. So do the wooden fences
and the cliffs. Everything here is graded by each land's palette, so it's drawn in **warm neutral grey stone**,
which each land tints to its own. (Ingothold's turns purple-brown, as in `city_wall_in_game.png`.)

## How each is used, and its layout

The game slants every face along the map's diagonals, a column at a time, and lays every top back into the screen
(`TownFence.pieces`). So each is drawn **face on, square to the viewer**, and each wall piece **tiles side to
side** (its column 0 follows on from its last column, the stones wrapping round), with no outline down its sides.

1. **`city_wall`: 24 × 37**, one cell's stretch of the wall's face. The battlements are in rows 0 to 5: two merlons,
   on the cell's quarters (about x 3 to 8 and x 15 to 20), with gaps at the middle and at both ends, so the halves a
   corner turns between look alike. The walk's level is at row 6. Below that are courses of rough-cut stones, a
   dark plinth and a little moss at the foot on row 36. Its light stones and shadows are lit from the top left.
2. **`city_wall_top`: 24 × 10**, the walk seen from straight above: flagstones, worn smooth in the middle. Row 0 is
   the far edge, where the game stands the far parapet (the face's own merlons). Row 9 is the near edge, behind
   the near battlements. It tiles side to side like the face, with no outline except a dark line along row 0.
3. **`city_tower`: 30 × 60**, a round tower: courses curving round it, lit on the left and shaded on the right, a
   ring of merlons round its top, a slit window or two, and its foot on rows 57 to 59 with moss and a plinth. It
   stands where wall stretches meet, so it's drawn whole, with an outline all round.
4. **`low_wall`: 32 × 14**, one stretch of a knee-high wall of field stones along a road: a row of flat slabs on
   edge along the top (rows 0 to 2), two courses of rounded, uneven stones (rows 3 to 11), a darker foot with moss
   (rows 12 and 13). It tiles side to side every 32 pixels.
5. **`low_wall_top`: 32 × 8**, its capstones seen from straight above: flat stones of uneven length in two rows,
   lit as they face the sky, a dark edge along row 0 (the far side). It tiles side to side.
6. **`low_wall_end`: 10 × 14**, where a low wall stops: its end, the same courses as the face lining up row for
   row, a step darker. Column 0 is its near edge, where it meets the face, with no outline there.

## How to run it

One chat in the ChatGPT project. Attach, in this order:
1. `style_reference_rd_4x.png`, for the look.
2. `city_wall_in_game.png` and `low_wall_in_game.png`, today's walls in Ingothold, graded.
3. `city_wall_now_8x.png`, `city_wall_tiled_6x.png`, `city_wall_top_now_8x.png` and `city_tower_now_8x.png`, today's
   at their exact sizes.

Paste the prompt, then send "next" after each piece. Bring the PNGs back named by their id, into `art-variants/walls/`.

## The prompt

> Redraw my game's walls, one piece at a time, as the project's instructions say, except where this message says
> otherwise. Match the style sheet's look (chunky shapes, a dark tinted outline, broad shading lit from the top
> left, few colours, cute and a little storybook). Use warm neutral grey stone (the game tints it for each land),
> and moss in a muted green. The second and third pictures are today's walls in the game, and the rest are
> today's pieces at their exact sizes: keep each one's size and layout exactly, and beat its look.
>
> Every piece is drawn face on, square to the viewer (the game slants it to the map's angle). Every wall piece
> tiles side to side: its column 0 follows on from its last column, its stones wrapping round, with no outline
> down its left or right side. Alpha 0 or 255 only, no text.
>
> 1. `city_wall`, 24 × 37: one stretch of a city wall's face. Battlements in rows 0 to 5: two merlons, on the
>    quarters (about x 3 to 8 and x 15 to 20), with gaps at the middle and both ends. Below them, courses of
>    rough-cut stones of varied sizes, a dark plinth and a little moss along its foot on row 36. 16 to 28 colours.
> 2. `city_wall_top`, 24 × 10: the walk along the top, seen from straight above. Flagstones, worn smooth down the
>    middle, a dark line along row 0 (its far edge), none along the sides. Lighter than the face, as it faces the
>    sky. 8 to 16 colours.
> 3. `city_tower`, 30 × 60: a round tower, its stone courses curving round it, lit on the left and shaded on the
>    right, a ring of merlons round its top, a slit window or two, a plinth and moss at its foot on rows 57 to 59.
>    Outline all round. 20 to 32 colours.
> 4. `low_wall`, 32 × 14: a knee-high wall of field stones along a country road. A row of flat slabs on edge along
>    the top (rows 0 to 2), two courses of rounded, uneven stones (rows 3 to 11), a darker foot with moss (rows 12
>    and 13). 12 to 20 colours.
> 5. `low_wall_top`, 32 × 8: its capstones seen from straight above. Flat stones of uneven length in two rows, lit
>    as they face the sky, a dark line along row 0. 8 to 14 colours.
> 6. `low_wall_end`, 10 × 14: where a low wall stops. Its end in the same courses as the face, lining up row for
>    row, a step darker. Column 0 is its near edge, with no outline there; outline on the far edge and the bottom.
>    8 to 14 colours.
>
> Before you deliver each, check with code and report: its size; for the wall pieces (1, 2, 4, 5), that column 0
> and the last column tile (shown by the piece repeated three times side by side); the colour count; alpha only 0
> or 255. Then deliver its 1× PNG named by its id, its 8× preview, and for the wall pieces the repeat at 4×, then
> the next.

## Back in the game

`city_wall`, `city_wall_top` and `city_tower` are copied over `tools/city_wall_art.py`'s, in a `PICKED` table, as
`gate_art.py` does for the gates. The low wall's three pieces are registered in art/assets.json. `BorderArt.lowWallPicture`,
`lowWallTop` and `TownFence.pieces`' flat end then take them where they're drawn. The palette grades them all as it does today.

## Results

- **2026-11-26**: asked for. Back the same day: `city_wall_top`, `city_tower`, `low_wall`, `low_wall_top` and
  `low_wall_end`, at their sizes, hard alpha (in, `tools/city_wall_art.py` `PICKED`). `city_wall`'s face came only as
  its 8× preview; still to bring back as a file.
