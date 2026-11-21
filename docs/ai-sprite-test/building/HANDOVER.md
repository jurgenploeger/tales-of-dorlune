# Can ChatGPT improve a building we drew in code? Test B1

The town buildings in `tools/building_art.py` are drawn in code with `pixel_kit`, because Retro Diffusion only
made a few. They pass most of the style checks but look boxier and flatter than RD's. The question: can
ChatGPT take one of ours and redraw it in RD's look, keeping what it is?

## The building

**The thatched cottage** (`thatched_cottage`, 96 × 96). It's simple, it's in Meadowbrook, and it
currently *fails* `pixel_style.py check --kind building` (86%, but it misses a hard rule: too many long
straight edges). By eye: a box with a flat, even thatch, straight walls and a side wall at an odd angle,
where RD's cottages are rounded, lumpy and full of small detail.

What has to stay (the game relies on it):
- **96 × 96 pixels**, the building standing on the bottom rows: today it fills x 9 to 86 and y 30 to 89
  (78 wide, 60 tall). Its lot in a town is cut for that footprint.
- **A front door** facing you, on the front's lower left half, so you can walk up to it.
- **Lit windows:** at night `tools/window_art.py` cuts the warm, bright yellow panes out and lights them.
  Windows need panes in a warm, bright yellow, apart from the walls' and thatch's colours.
- **Seen from the front, a little from above,** as the game's other buildings are (you see the front wall
  and the roof's slope above it).
- **No ground slab under it.** It stands on the map's own ground (`tools/deslab.py` exists because RD
  sometimes drew one). A few tufts of grass at its foot are fine.

## What to attach

1. `docs/ai-sprite-test/building/thatched_cottage_8x.png`: our cottage at 8× (768 × 768), the one to redraw.
2. `docs/ai-sprite-test/building/style-reference-buildings.png`: three RD buildings at 6× (the round
   house, the sleepy cottage, the bakery): the look to match.

## The prompt (paste as is, both pictures attached)

> I'm making a cute pixel-art RPG for iPhone. The first image is a building from my game: a thatched
> cottage, 96 × 96 pixels, shown scaled up 8× (each square block is one pixel). The second image shows
> three other buildings from the game, at 6×, in the art style I want.
>
> Redraw the first building in the second image's style. Keep it the same building: a cosy thatched
> cottage with a golden straw roof, a chimney, a blue front door on the lower left of the front, two
> windows with warm yellow light, blue shutters, a window box with pink flowers, a climbing plant.
>
> Make it look like the reference buildings:
> - A soft, rounded, slightly lumpy silhouette, not a box. The thatch thick and rounded at its edges,
>   drawn in clumps of straw with lots of small detail, overhanging the walls.
> - Walls with texture (plaster with a few stones, or timber), not flat colour.
> - Lit from the top left: highlights top left, shade bottom right, a soft shadow under the roof's edge.
> - Hue-shifted shading: shadows lean warmer or cooler, not just darker. 5 or more shades per colour.
> - An outline one pixel wide in a deep shade of each colour it borders, not black.
> - Seen from the front and a little from above, like the reference buildings.
>
> Rules, all of them matter:
> - Real pixel art on a **96 × 96 grid**. The cottage about **78 pixels wide and 60 tall**, standing on the
>   bottom of the canvas with empty space above.
> - Show it scaled up **8× with nearest-neighbour** (a 768 × 768 image): every pixel a perfectly square,
>   equal, hard-edged 8 × 8 block. No pixels of a different size.
> - **No anti-aliasing, no blur, no gradients, no glow.** Flat colour in each pixel. About 30 to 40 colours.
> - The window panes a warm bright yellow that nothing else in the picture uses.
> - **Transparent background, PNG.** No ground, slab or base under it (a few tufts of grass at its foot
>   at most), no shadow on the ground, no text, no border.

Ask for three tries ("make another, different from the first", or a new chat).

### If it drifts
- Too big or uneven pixels: "Your pixels aren't 8 × 8. Redraw it on a strict 96 × 96 grid, scaled up
  exactly 8×, the cottage 78 pixels wide and 60 tall."
- A whole scene: "Only the building, on a transparent background, no ground."
- Lost the building: "Keep the first image's building: same door, windows, chimney and roof shape, only
  redrawn in the reference's style."

## Bring them back

Save each as the PNG ChatGPT gives (not a screenshot, not a JPEG), and send them here. I run:

```
python3 tools/ai_sprite_eval.py <image> --rd thatched_cottage --kind building --colours 40 \
    --out docs/ai-sprite-test/building/chatgpt_1_96
```

It snaps the picture back to the 96 × 96 grid at the cottage's size, scores it against the bands every RD
building we ship sets (`pixel_style.py check --kind building`, the same check ours fails today), and puts
it beside today's cottage on grass and on the dark field. The round trip is checked: today's cottage,
blown up blurry with noise and run back through, scores exactly what it does as drawn (86%).

## How we judge it

It's better if:
1. it passes `pixel_style.py check --kind building` (today's: fails, 86%);
2. beside RD's buildings in a town it looks like the same game, and beside today's cottage it's plainly
   better (a blind pick: `tools/blind_review.py`);
3. it's still recognisably the thatched cottage, with its door and lit windows where the game needs them;
4. at 8× its pixels are clean: no mush, no stray single pixels, no ground slab.

If it wins, one thing changes in how we work: the cottage stops being a drawing in code (rebuilt by
`building_art.py` on every rerun) and becomes a picked picture, as RD's are, kept in `art-variants/` and
named in the tool so a rerun doesn't draw over it. That's your call when we get there.
