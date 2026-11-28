# Tales of Dorlune — final interface pieces

This set contains 11 designs in pale birch and their 11 dusky-walnut twins. Each game asset is a centred transparent 1280 × 1280 PNG. The light and dark images use the same palette-index raster and alpha mask; only the palette changes.

## Contents

| File stem | Purpose | Nominal phone box |
| --- | --- | --- |
| `toast_plate` | One-line notification plate | 220 × 30 pt |
| `banner_ribbon` | Celebration or location banner | 300 × 70 pt |
| `reward_card` | Square item well and name strip | 90 × 110 pt |
| `dropdown_menu` | Floating menu panel | 180 × 125 pt example |
| `dropdown_row_selected` | Soft-gold selection strip | 160 × 16 pt example |
| `text_field` | Deep chat/search input | 300 × 34 pt |
| `scroll_thumb` | Plain scrollbar thumb | 6 × 24 pt example |
| `scroll_track` | Vertical sunk track | 6 × 104 pt example |
| `party_frame` | Portrait, name, HP and MP | 140 × 44 pt |
| `coach_arrow` | Downward tutorial pointer | Fits 40 × 40 pt |
| `map_pin` | Star pin for the world map | Fits 24 × 32 pt |

Light files use the listed stem plus `.png`; dark files add `_dark.png`. The two ZIPs can be extracted into the same folder. Their shared documentation is identical.

The `previews_8x` folders contain exact nearest-neighbour 8× previews of every PNG. These previews aren't the game assets. Use the 1280 × 1280 originals from `light` and `dark`.

## Coordinates and resizing

`asset_checks.json` includes each file's canvas, actual opaque bounds, centre, colour count, alpha values, safe content rectangles, inset bounds and stretch settings. `geometry.json` is the smaller layout-only version.

All rectangles use `[x0, y0, x1, y1]`, with the right and bottom values exclusive. Pixel positions are zero-based. Centres use pixel-boundary coordinates, so a centred even-size canvas has centre `[640, 640]`.

**Caps are measured after trimming to the recorded opaque bounds.** The metadata also gives canvas-coordinate stretch rectangles. Subtract the bounds' top-left position from a canvas-coordinate content rectangle when using a trimmed image. Scale the art, caps and content coordinates together to the intended phone size.

| Asset | Stretch method | Fixed caps in trimmed source pixels |
| --- | --- | --- |
| Toast | Horizontal 3-slice | Left 190, right 100 |
| Banner | Horizontal 5-slice | Left 170, centre 140, right 170 |
| Dropdown | 9-slice | 96 px on every side |
| Selected row | Horizontal 3-slice | Left 65, right 65 |
| Text field | Horizontal 3-slice | Left 90, right 90 |
| Scroll track | Vertical 3-slice | Top 64, bottom 64 |
| Party frame | Horizontal 3-slice | Left 420, right 140 |

For the banner, the horizontal cuts are `[0, 170, 490, 630, 950, 1120]` after trimming. Keep segments 0, 2 and 4 intact. Stretch segments 1 and 3 equally so the star stays centred. Don't apply an ordinary single-centre 3-slice to the banner: that would stretch the star.

The reward's flat well measures 727 × 727 px, with a 656 × 656 px safe item rectangle. The party portrait aperture is 255 × 255 px and fully transparent. The map pin's bottom anchor is opaque pixel `[639, 1159]` on the full canvas; its trimmed position is `[367, 1039]`.

## Verification

- All 22 assets: 1280 × 1280, alpha only 0 or 255, 5–36 visible colours.
- All 11 dark twins: identical silhouette, aperture and palette-index drawing.
- All declared runtime content rectangles: opaque and uniformly filled.
- All 22 enlarged previews: every 8 × 8 block exactly matches its source pixel.
- Seven stretch recipes checked at 0.7× and 1.5× lengths; fixed caps and the banner's centre stay unchanged.

`contact_sheet.png` shows light pieces on mid-green and dark pieces on deep navy, alongside approved reference assets. `phone_scale_proof.png` shows nominal-size views and exact 3× enlargements. `stretch_proof.png` shows the resizing checks.

## Palette and drawing record

`palette.json` contains 40 light/dark colour pairs measured from the supplied approved kits. Gold and sage inlays use their approved brighter dark-mode colours. Parchment uses the approved deep warm-brown dark pane.

Source art was generated individually with the built-in image-generation tool using the supplied kits as references. The final exports were normalized for exact canvas size, hard alpha, the measured palette, plain content fills, anchors and repeatable stretch regions. The prompt set is included in `generation_prompts.json`.
