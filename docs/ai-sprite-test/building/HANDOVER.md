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

## Results (2026-11-21)

### ChatGPT, try 1

`chatgpt_1.png` (96 × 96, as delivered), `chatgpt_1_8x.png` (768 × 768), `chatgpt_1_raised.png` (moved up 6
rows to stand where ours does), `compare_town.png` (beside RD's house and sleepy cottage at 4×),
`compare_closeup.png` (ours and its at 6×).

- **A real sprite.** It sent a true 96 × 96 PNG beside the 8× picture: the big one is exactly the small one
  at 8×, every 8 × 8 block flat, 39 colours, a clean transparent background, no half-transparent pixels.
  78 × 60, exactly as asked. Nothing to snap or clean: the first general model's picture that's usable
  as delivered.
- **It's still our cottage:** the thatch, the chimney, the blue door on the lower left, two lit windows with
  blue shutters, the flower box, the climbing plant. The window panes are warm yellow for the night lights.
- **By eye, a clear step toward RD's look:** a rounded, lumpy thatch in clumps where ours is an even,
  boxy slab; plaster walls with stones; the odd side wall gone. Beside RD's house and sleepy cottage it
  looks like the same game; ours doesn't.
- **Scored: fails, 71%** (ours: fails, 86%). It now passes the hard rule ours failed (straight edges: 0.26,
  ours 0.46), but misses others: the thatch is **too noisy** (stray single pixels 0.31, the limit 0.25;
  clusters 2.1 pixels, RD's 2.3 to 5.2), its **outline a little light** (0.41, RD's at most 0.35), and,
  by a hair, the hard rule that the outline is darker than what's inside (0.543, needs 0.546).
- **Two slips:** it stands on the canvas's last row (ours stands 6 rows up), and its foot is a flat cut, as
  if cropped, with no edge or tufts. The walls are short under a heavy roof.

Verdict: **promising, not done.** The first try that's plainly better than ours by eye, but it fails the
numbers on noise, and those numbers are what keep a sprite looking like RD's on the phone at 1×. One
follow-up should tell whether it can be tidied:

> Much better. Keep everything, with these fixes: the thatch is too noisy. Draw it in bigger, smoother
> clumps of 3 to 6 pixels of one shade, with fewer single stray pixels. Make the outline a darker shade
> (deep brown round the thatch and walls). Give the building a proper rounded foot with a darker bottom
> edge and two or three grass tufts, and leave 6 empty rows under it at the bottom of the canvas. Make the
> walls 3 or 4 pixels taller. Same 96 × 96, same 8× PNG, transparent.

### ChatGPT, tries 2 and 3 (after the follow-up)

`chatgpt_2.png`, `chatgpt_3.png` as sent (1254 × 1254, blocks of about 13 pixels: a 96 grid, but no 1× file
this time and a soft-edged background), `chatgpt_2_96.png` and `chatgpt_3_96.png` snapped at their own
height (66 and 64: the taller walls asked for), `compare_town_2.png`, `compare_closeup_2.png`.

| | ours | try 1 | try 2 | try 3 |
|---|---|---|---|---|
| score | fail 86% | fail 71% | fail 86% | **fail 93%** |
| hard rules missed | straight edges | outline vs inside | outline vs inside, flat | outline vs inside |
| stray pixels / clusters | ok | too noisy | clusters too big | clusters a bit big |

- **The noise is gone** and the foot is a proper rounded edge with grass tufts, the walls taller, standing
  6 rows up. Try 3 is the cleanest building any model has drawn for us, and passes every soft rule but one.
- **Both fail the outline rule, and that's the follow-up's fault, not ChatGPT's.** `outline_rel` asks that a
  building's outline be a deep shade *of what it rounds* (0.55 or more of the inside's brightness), not a
  near-black line: RD tints its outlines, and a dark line round everything is the commonest tell of art
  drawn in code. The follow-up asked for "a darker outline", and it drew one dark plum line all round.
  Try 1's outline was too light in absolute terms (0.41, at most 0.35) but already a hair too dark next to
  its light thatch; the fix is a *tinted* outline, darker inside the edge, not a darker line.
- Try 2 overshot to big flat clumps with no highlights (flat, a hard rule, by a hair). Try 3 sits between.

Next follow-up, on try 3:

> Very close, keep everything. One fix: the outline. Don't use one dark line all round. Make it a deep
> shade of each colour it borders: a dark golden brown round the thatch, a dark warm grey-brown round the
> walls, a deep blue round the door and shutters. And make the pixels just inside the outline a mid shade,
> so the outline isn't next to the lightest colour. Add a few bright highlight pixels on the thatch's top
> left. Deliver the 96 × 96 PNG at 1× as well as the 8× preview, background fully transparent.

### ChatGPT, try 4 (the tinted outline)

`chatgpt_4.png` (96 × 96) and `chatgpt_4_8x.png`, as delivered; `compare_town_4.png`.

- **Delivered clean again:** a true 96 × 96 PNG, the 8× an exact copy, only clear or solid pixels, 39
  colours, 78 wide, its foot on row 89 as the instructions ask. Nothing snapped or fixed.
- **Every hard rule passes**, the outline one included (0.559, needs 0.546). Of RD's own 29 buildings,
  15 miss a hard rule.
- **Soft 71%, needs 80%:** the outline still a little light in absolute terms (0.44, RD's at most 0.35),
  clumps a bit big (5.7, RD's up to 5.2), and two misses by a hair (broad light areas 0.543 for 0.55, one
  grid-like run 0.035 for 0.033). RD's buildings score 79% to 100% soft, so this is below every one of them.
- Darkening its outline in code didn't help: the two outline rules together want the band just inside the
  edge darker too, and doing that in code added too many colours. It's for the drawing to fix.

Verdict: **one step short.** Plainly better than ours by eye and by the hard rules; not yet at RD's level
by the soft ones. The fix the numbers ask for: a darker band of shade 2 or 3 pixels wide just inside the
roof's and walls' edge (under the eaves especially), with the outline a shade darker again, and slightly
smaller clumps on the thatch.

### ChatGPT, try 5 (a band of shade inside the edge)

`chatgpt_5.png` as delivered (96 × 96, clean, 40 colours, foot on row 89); `chatgpt_5_outline108.png`, its
228 outline pixels 8% lighter; `compare_town_5.png` (4×) and `compare_town_5_1x.png` (game size).

- As delivered: **soft 93%** (RD's buildings: 79% to 100%), every hard rule but one: the outline overshot
  to a little too dark beside what it rounds (`outline_rel` 0.511, needs 0.546; try 4 was on the other side).
  The two outline rules leave a narrow window: at most 0.35 bright, at least 0.55 of what's inside.
- **With its outline 8% lighter it passes:** every hard rule, soft 86% (only the outline's absolute
  light, now 0.38, and one grid-like run miss), level with 9 of RD's 29 buildings. 43 colours.

Verdict: **the first AI-drawn sprite that clears the bar RD's art sets**, with one small, written-down
touch (like `tools/rd_fixes.py`'s exact fixes). Whether it goes in the game is the user's pick, blind
against ours.

## The pick (2026-11-21)

`blind_pick.png`, its key `blind_pick.key.json`: A was ours, B ChatGPT's try 5 with its outline 8% lighter.
**The user picked ChatGPT's** ("Chatgpt is better"). It's in the game: kept as delivered in
`art-variants/thatched_cottage/chatgpt_5.png` (the old drawing beside it, `drawn_in_code.png`), named in
`tools/building_art.py` `PICKED` with its outline lift, so a rerun writes the same sprite; its night window
lights cut by `tools/window_art.py`, held to the rows under its roof (`ROWS`: the straw's highlights are the
panes' yellow).

# Test B2: the stone townhouse

Of our 29 other code-drawn buildings, 11 fail a hard rule. The **stone townhouse** (`stone_townhouse`) is
the most used of them (five lots, in Meadowbrook and other towns) and the cottage's own family: 93% soft,
failing only the hard one the old cottage failed, long straight edges (a box with ruled walls and roof).

Keep: 96 × 96, about **72 wide and 82 tall**, its foot on **row 90**; a blue-grey slate roof with a dormer
window and a chimney on the right; light stone walls; two arched lit windows; a green arched door in the
middle of the front, with a stone step; a window box with pink flowers and ivy up the left. Window panes
warm yellow (night lights).

Attach `stone_townhouse_8x.png` in a new chat of the project (the instructions and reference sheets are in
the project). Prompt:

> Redraw this building from my game in the style of the reference buildings: a stone townhouse, 96 × 96,
> shown at 8×. Keep it the same building: a blue-grey slate roof with a dormer window and a chimney on the
> right, light stone walls, two arched windows with warm yellow light, a green arched door in the middle of
> the front with a stone step, a window box with pink flowers, ivy up the left.
>
> Make it soft and rounded like the references, not a box: the roof's edges and ridge gently curved and
> uneven, slates in rounded rows, walls slightly bulging, stones of different sizes with rounded corners.
> No long ruler-straight lines anywhere.
>
> Size: about 72 pixels wide and 82 tall, its foot on row 90 of the 96 × 96 canvas. Deliver the 1× PNG and
> the 8× preview, as the project's instructions say.

## B2 results

### ChatGPT, try 1 (2026-11-21)

`townhouse_chatgpt_1.png` as sent (1254 × 1254, no 1× file, a soft-edged background, blocks of about 10
image pixels: drawn about 91 × 104, bigger than the 72 × 82 asked), `townhouse_chatgpt_1_96.png` snapped to
82 tall, `townhouse_closeup_1.png` beside ours at 6×.

- Snapped, it **passes every rule, 100%**, first try. Ours fails a hard one (straight edges, 0.57).
- By eye: rounded scalloped slates, the dormer, a rounded stone chimney, stones of many sizes, ivy and the
  window box, the green arched door with its step. Everything asked for is there.
- The cost of the snap: the shrink (104 rows to 82) is ours, not its drawing, and leaves a few stray pixels
  in the right window and the door. A clean 1× at the asked size from ChatGPT would avoid that.
- Its night windows cut cleanly (only the panes: the roof is blue, unlike the straw).

### ChatGPT, try 2 (exact size)

`townhouse_chatgpt_2.png` as delivered: a true 96 × 96 PNG, 72 × 82, its foot on row 90, 34 colours, clean.
Darker overall than try 1, so its outline didn't stand apart from the body (`outline_dark` 0: no edge pixel
under 0.55 of the sprite's middle light). `townhouse_chatgpt_2_outline85.png`, its 254 outline pixels 15%
darker (the least that passes): **passes, every hard rule, 93% soft**. `townhouse_blind_pick.png` sets it
against ours, between RD's house and the new thatched cottage; the key stays out of the repo till the pick.

### The pick (2026-11-21)

A was ours, B ChatGPT's try 2 with its outline 15% darker (`townhouse_blind_pick.key.json`). **The user
picked ChatGPT's.** In the game as the cottage is: `art-variants/stone_townhouse/chatgpt_2.png`,
`building_art.PICKED` with its outline factor 0.85; its night windows cut again (the panes and the lamp
over the door). Two tries, against the cottage's five: the project instructions did their job.
