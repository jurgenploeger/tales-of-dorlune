# Boss lairs and odd props by ChatGPT (2026-11-26)

The user, 2026-11-26: "Now help me get the boss lair pieces and odd props to be drawn with chatgpt". The last world
objects still drawn in code: the bosses' lair pieces (`tools/lair_art.py`; its brazier, gold hoard and torn tent are
ChatGPT's already) and a few props no generated sprite was right for (`tools/prop_art.py`). Redraws: each keeps its
canvas and where it stands, so the game places it as before.

`lair_now_6x.png`, `wall_torch_frames_6x.png`, `props_now_6x.png` and `ship_now_2x.png` are today's, at their sizes.

## What the game does with them

- **Graded by each land's palette** (not the cave pieces' rock): draw them in natural colours.
- **Lights**: the wall torches' flames are cut out and given a glow at night (`tools/window_art.py` `LIGHTS`), so a
  flame is a few bright warm pixels, no halo.
- **The wall torch** is four frames played in a loop (`WorldScene.lightTheRoad`): the iron plate, bracket and torch
  must be the **same pixels in every frame**, only the flame and its sparks change.
- **The waystone's** runes and crystal are found by their **blue** (`WaystoneMagic`: the brightest blue lights up when
  it wakes), so they stay blue; the game fades the whole stone while it sleeps.
- **The ship** sits on the sea by the middle of its picture: the **middle of its waterline is the canvas's middle**
  (x 101, y 164). It lies along the map's east, its bow up the screen to the right, its stern and its south side
  toward you, and is mirrored for a pier going north.

## How to run it

One chat in the ChatGPT project. Attach, in this order: `style_reference_rd_4x.png` (the look), then the four sheets
of today's. Paste the prompt, send "next" after each. Bring the PNGs back in one zip, named by their id.

## The prompt

> Redraw these props for my game, one at a time, as the project's instructions say, except where this message says
> otherwise. The first picture is our style sheet: match its look exactly (chunky shapes, a dark tinted outline,
> broad shading lit from the top left, few colours, cute and a little storybook). The other sheets are today's
> drawings at their exact sizes, to beat: keep each one's canvas, its size in it and where its lowest pixel sits.
>
> Every one: transparent, alpha 0 or 255 only; seen from the front and a little from above, as the style sheet's are;
> no ground, slab or drop shadow under it (a little moss or grass at a foot at most); no text. Natural colours (the
> game tints each land's art). Anything that gives light has its flame or glow as a few bright pixels, no halo round
> it: the game adds the glow.
>
> **Boss lairs**
> 1. `standing_stone`, 32 × 48, lowest pixel on row 47: a tall grey standing stone leaning a touch, a weathered rune cut
>    in its face, moss at its foot. 12 to 24 colours.
> 2. `warning_post`, 32 × 48, row 47: a warning on the way into a monster's lair: a crooked wooden stake with a
>    cross-piece, a skull on top and a torn red rag hanging from it. 12 to 24 colours.
> 3. `junk_throne`, 32 × 48, row 47: the Rat King's throne, a throne first: a tall arched back with a purple panel and
>    a knob at each corner, armrests, a cushioned seat on legs; junk in its making: a board nailed across the back,
>    mismatched legs, a dented pot on top for a crown, a few bones at its foot. 16 to 30 colours.
> 4. `broken_pillar`, 32 × 48, row 46: a fallen temple's pillar still standing but broken off two thirds up: fluted
>    pale stone, a worn base, a jagged top, a chunk of it lying at its foot, ivy up one side. 12 to 24 colours.
> 5. `bone_pile`, 32 × 32, row 28: a heap of old bleached bones a beast left in its den: long bones crossed every way,
>    ribs, a skull on top. 10 to 20 colours.
> 6. `wall_torch`, `wall_torch_2`, `wall_torch_3`, `wall_torch_4`: four frames of one torch on a cave wall, each 32 ×
>    48, the lowest pixel on row 34, the top of the flame at row 0 or 1: a dark iron plate on the rock, a bracket
>    holding a wooden torch leaning out, its head wrapped and burning. The plate, bracket and torch exactly the same
>    pixels in all four; only the flame flickers (taller, leaning, splitting) and a spark or two moves. 16 to 32
>    colours each.
>
> **Props**
> 7. `waystone`, 32 × 48, row 47: a tall dressed stone with shoulders and a pointed head, on a round two-step plinth
>    of cut stone with moss at its foot; a blue crystal set in its head and three blue runes cut down its face,
>    glowing, and a few blue sparks in the air. The crystal, runes and sparks blue and the only blue in it. 16 to 32
>    colours.
> 8. `lost_pile`, 40 × 32, row 31: what an adventurer lost when they fell: a fat burlap sack standing up, tied at the
>    neck, gold coins spilled in front of it, a red potion and a sword leaning on it. 16 to 30 colours.
> 9. `candy_cane`, 32 × 48, row 47: a giant candy cane stuck in the ground, a straight shaft with its hook curling over
>    to the left (one hook, not an arch), red stripes winding round the white. 6 to 14 colours.
> 10. `cave_ladder`, 48 × 48, row 44: the way down to a cave's deeper level: a round pit in the cave floor, ringed with
>     grey stones, black at its heart, a wooden ladder standing up out of it, leaning back a little. 10 to 22 colours.
> 11. `cave_rope`, 32 × 72, row 69: the way back up: a knotted hemp rope hanging from high above, its end coiled on
>     the floor in a dim pool of light. It fades into the dark toward the top (dither it out over its top rows, alpha
>     still only 0 or 255). 12 to 28 colours.
> 12. `ship`, 202 × 328: a little wooden sailing ship moored at a pier, seen as the attached `ship_now_2x.png` is:
>     lying along the diagonal, its bow up and to the right, its stern and its near side toward you; one mast with a
>     square cream sail with a gold star on it, a jib to the bow, a pennant on top, a teal and gold band along the
>     hull, lit stern windows (a few warm pixels), barrels on deck, and a gangplank down off its near side toward the
>     bottom right. The middle of its waterline exactly at x 101, y 164; nothing below the hull's waterline (the game
>     draws the sea). 30 to 60 colours.
>
> Before you deliver each, check with code and report: its canvas size; its lowest row (for the ship, the middle of
> its waterline); its width and height; the colour count; alpha only 0 or 255; for the wall torches, that the four
> frames differ only in the flame and sparks. Then deliver its 1× PNG named by its id and an 8× preview (the ship at
> 2×), then the next.

## Back in the game

The lair pieces copied in `tools/lair_art.py` `PICKED`, the props in `tools/prop_art.py` `PICKED`, each from
`art-variants/<id>/chatgpt_1.png` as before, checked for canvas, foot row and hard alpha. Then `tools/window_art.py`
reruns for the torches' flames, and `pixel_style.py check --kind scenery` scores them.

## Results

- **2026-11-26**: asked for.
