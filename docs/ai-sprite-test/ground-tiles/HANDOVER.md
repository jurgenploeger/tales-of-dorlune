# Ground tiles at the walkers' pixel size, by ChatGPT: a pilot (2026-11-26)

The user, 2026-11-26, after the cliff faces were fixed: "It's better. Still a bit blurry on some parts of lands, so maybe
we need pixel art made by chatgpt for different surfaces?" Every ground tile is 32 pixels drawn over a 44-point cell
(`WorldMap.tileSize`), so each art pixel is 1.375 points against a walker's 1 (`tools/pixel_scale.py`). On a phone (3
screen pixels a point) that's 4.125 screen pixels an art pixel, rounded to 4 or 5: uneven, so it reads soft. A tile drawn
at **44 × 44** is one point a pixel, 3 screen pixels each, crisp, and the same size as the characters' pixels.

These three are Retro Diffusion's (`request` in art/assets.json); CLAUDE.md keeps RD's art as drawn *in code*. Redrawing
them by ChatGPT is the user's call (2026-11-26, "Yes" to this pilot). If the pilot reads crisp in the game, the other
ground tiles follow (about 20 drawn, the rest recolours of them).

## The pilot

| id | what it is | where it shows |
|---|---|---|
| `tile_grass` | the green lands' plain ground | Sunny Meadow, Meadowbrook's countryside, most green lands |
| `tile_path` | roads and trails out in the lands, a place's earth | every wild land's roads |
| `tile_cliff_rock` | a terraced range's faces (`bank`), drawn on the screen's pixels | Lotus Land, most wild lands' terraces |

`<id>_now_8x.png` is today's tile at 8×, `<id>_now_tiled_4x.png` the same repeated 3 × 3 (its seams and the pattern
repeating). The new one keeps its kind and its colours, and loses the long streaks (the grass's vertical strokes read
as stripes across a whole field).

## What the game does with them

- **Graded by each land's palette** (maps.json `theme.palette`): natural colours; the game tints each land's ground.
- **Repeated on every cell**, and its edges swapped between versions (`tools/wang_art.py`, `ArtLibrary.wangTile`): it
  must tile seamlessly on all four sides, and a strip along each edge shifted against its neighbour must still meet.
- **Roads drawn from curves** (`ArtLibrary.organicTile`): the path's pixels shown inside a road's wobbly edge over the
  grass, so the path tile is the road's surface everywhere.
- **The cliff rock on the screen's pixels**, a tile every 44 points across and up a face (`HillArt.lifting`): it
  repeats up and across a tall wall, so it wants rock that reads as rock at any cut, not one big feature.

## How to run it

One chat in the ChatGPT project. Attach `style_reference_rd_4x.png` first, then the six `_now_` pictures. Paste the
prompt, then send "next" after each. Bring the 1× PNGs back named by their id, into `art-variants/ground_tiles/`.

## The prompt

> Redraw three of my game's ground tiles, one at a time, as the project's instructions say, except where this
> message says otherwise. The first picture is our style sheet. The others are today's 32 × 32 tiles, each at 8× and
> repeated 3 × 3 at 4× to show how they tile.
>
> **Don't measure the size from the attached pictures.** Each new tile is **44 × 44 pixels**: today's are stretched
> to fill a 44-point cell in the game, which makes their pixels uneven on a phone; at 44 they're one point each, the
> same size as the characters' pixels.
>
> Every tile:
> - **Seamless on all four sides:** its right edge continues into its left and its bottom into its top, with no seam,
>   line or change of shade where two copies meet. Check it in code by repeating it 3 × 3 and send me that preview
>   (`<id>_tiled.png`, 132 × 132, at 4×) with the tile.
> - **Fully opaque** (every pixel alpha 255), a flat texture seen from above, no objects, no light from one side (it's
>   repeated everywhere, so a light corner would show as a grid), no border, no text.
> - **No long streaks or lines** running across the tile: they line up into stripes across a whole field. Small
>   clusters of 2 to 6 pixels in a few shades, scattered evenly, so nothing reads as a pattern when repeated.
> - **12 to 24 colours**, hue-shifted shades (shadows a little cooler or warmer, not just darker), a few single
>   pixels at most.
> - **Natural colours** close to today's (the game tints each land's ground itself).
>
> 1. `tile_grass`: lush bright green meadow grass seen from above: short tufts and blade tips in clusters, lighter tips
>    and darker gaps, a few yellow-green highlights. Not long vertical blades.
> 2. `tile_path`: a sandy dirt road seen from above: pale warm sand with soft darker patches and a few small pebbles
>    (2 to 3 pixels, a lit top-left pixel and a dark bottom-right one), evenly spread.
> 3. `tile_cliff_rock`: a rough grey-brown rock cliff face seen from the front: stones and cracks in small clusters,
>    a little green moss in a few clumps, even all over (it's repeated up and across tall walls, so no single big
>    stone or ledge that would show as a grid).

## Bringing them in (for Claude)

Check each in code (44 × 44, opaque, seamless: every edge row and column against the opposite one, as
`tools/wang_art.py check` holds the field to its seams), fix a seam if one is left, copy it in as
`art/sprites/<id>.png` (the original kept in `art-variants/ground_tiles/rd/`), rerun `tools/wang_art.py` and `check`,
`tools/palette_preview.py`, `python3 tools/check_content.py`, `tools/pixel_scale.py` (the three at 1, the rest still
1.375), then a Screenshots run (`slope_lotus`, `hill_bare`, `road_fade`, `continent_border`) before and after.
