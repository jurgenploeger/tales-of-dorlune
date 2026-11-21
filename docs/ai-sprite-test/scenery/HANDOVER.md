# Scenery test: a tree and two lair pieces (2026-11-21)

Every building drawn in code is ChatGPT's now. Next to try: scenery, one tree and two pieces of a boss's lair,
before doing the rest. Our three already pass every rule (`pixel_style.py check --kind scenery`), unlike most of
the buildings, so ChatGPT's have to beat them by eye and score.

| id | canvas | sprite | foot row | colours (ours) |
|---|---|---|---|---|
| `blossom_tree` (`tools/scenery_art.py`) | 64 × 64 | 52 × 52 | 59 | 57 |
| `brazier` (`tools/lair_art.py`) | 32 × 32 | 20 × 29 | 28 | 39 |
| `gold_hoard` (`tools/lair_art.py`) | 32 × 32 | 30 × 27 | 28 | 57 |

One chat in the project, the three `_8x.png` attached in this order:

> Redraw these 3 sprites from my game, in the order attached, as the project's instructions say. They're
> scenery, not buildings: smaller canvases, shown at 8×, so measure each (64 × 64, 32 × 32, 32 × 32).
> 1. **blossom_tree**: a cherry blossom tree, a round fluffy crown of pink blossom in big soft clumps with a
>    few darker pink hollows between them, a short brown trunk with roots, a few petals. **52 wide, 52 tall,
>    foot on row 59 of 64.** The crown in 6 to 8 distinct rounded clumps, each lit top left with a darker
>    underside, so they can sway separately in the wind; the trunk clearly separate from the crown.
> 2. **brazier**: a boss lair's iron fire bowl on three legs, a bright orange fire in it, a few sparks.
>    **20 wide, 29 tall, foot on row 28 of 32.** The flame in orange, red and pale yellow; the iron dark
>    blue-grey.
> 3. **gold_hoard**: a dragon's heap of gold coins, a few gems (red, blue, green) and a golden goblet on it.
>    **30 wide, 27 tall, foot on row 28 of 32.**
>
> Colours: about as many as the originals: the tree 45 to 60, the brazier 30 to 40, the hoard 40 to 55. The
> outline a deep shade of what it borders, about half as bright as the pixel just inside it. Shade every form
> in broad areas, lit from the top left. Nothing else in the picture: no ground, no shadow under them (a few
> grass tufts at the tree's foot at most). Deliver each as its 1× PNG on a transparent background at exactly
> its canvas, plus the 8× preview, one at a time.

## What happens to them

Scored as scenery against ours. The tree also needs its wind rig made again (`tools/wind_art.py`, its crown cut
into leaf clumps by colour; `check_content.py` checks the rig fits), and its `big_` twin follows by `derive`.
The brazier smokes from its top (`LandStage.addSmoke`); its fire stays as drawn.
