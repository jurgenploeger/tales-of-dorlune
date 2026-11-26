# Closed chests by ChatGPT (2026-11-26)

The chests out in the lands (NPC role `chest`, one at a place in every wild land, a few on summits, one in the
Glimmerdeep) all show `treasure_chest`: Retro Diffusion's open chest, half buried in sand, gold peeking out. The user
(2026-11-26): "For chests that are scattered through the world we need a closed drawing made by chatgpt. If they are
opened, we can keep the open drawing. ... We should also have different chest styles depending on area."

So a chest you haven't opened stands **closed**, in its area's style; once opened it shows today's open chest
(`chest_open_now_8x.png`). Nothing points to them any more (no "!" over them, nothing on the minimap or the world map):
they're found by stumbling on them.

## The styles, and where each stands

| Id | Look | Lands |
| --- | --- | --- |
| `chest_wood` | warm oak planks, dark iron bands, a brass lock | Sunny Meadow, Northern Grassland, Swan Lake, Smiling Forest, Emerald Road, Starfall Isle |
| `chest_beach` | weathered pale driftwood, rope lashings, a shell or starfish on the lid | Pineapple Shore, Ingothold Lake, Hachoo Island |
| `chest_desert` | sun-bleached wood, brass corners, turquoise inlay, a cloth tassel on the lock | Genie Desert, Secret Plain |
| `chest_frost` | pale birch, frosted iron bands, snow on the lid, small icicles | Snow White Forest, Rosen Lake, Moonglow |
| `chest_swamp` | dark wet wood, moss and a creeping vine, a lily-pad lock | Frog Swamp, Lotus Land |
| `chest_shadow` | near-black wood, black iron, a glowing purple gem lock, a wisp of cobweb (spooky but cute) | Twilight Woods, Wolf's Lair, Valley of Fear, Puppet Hill, Sleepy Town |
| `chest_crystal` | grey stone chest, pink and pale blue crystals growing from its corners | Crystal Mountain, the Glimmerdeep |
| `chest_candy` | gingerbread with white icing, candy-cane bands, a gumdrop lock | Candy Mountain |
| `chest_coral` | blue-green shell and coral, a pearl lock | Water Temple |

## How to run it

One chat in the ChatGPT project. Attach, in this order: `style_reference_rd_4x.png` (the look: our props at 4×),
`chest_open_now_8x.png` (today's chest, open, at 8×: the size and view to match). Paste the prompt, send "next" after each.
Bring the PNGs back named by their id, into `art-variants/chests/`.

## The prompt

> Draw nine closed treasure chests for my game, Tales of Dorlune, one at a time, as the project's instructions say,
> except where this message says otherwise. They're props, not buildings: match the first sheet's look exactly (our
> scenery at 4× on grey: chunky shapes, a dark tinted outline, broad shading lit from the top left, few colours, cute
> and a little storybook). The second picture is our chest today, open and half buried, at 8×: match its size, its
> view and how it sits on the ground, but draw it **closed**, standing on the ground (not buried), lid shut.
>
> For all nine: a 32 × 32 canvas, transparent; the chest 22 to 28 wide and 16 to 22 tall, its lowest pixel on row 29,
> roughly centred. Seen from the front and a little from above, from its front corner: its lit front (facing the
> viewer, a little to the left) and its side in shade to the right, the lid's top visible. 12 to 24 colours. Alpha 0
> or 255 only. No ground, slab or cast shadow under it, no text, no gold spilling out (it's shut).
>
> 1. `chest_wood`: warm oak planks, dark iron bands, a brass lock. The classic one.
> 2. `chest_beach`: weathered pale driftwood, rope lashings instead of bands, a small shell or starfish on the lid.
> 3. `chest_desert`: sun-bleached wood, brass corners, turquoise inlay, a little cloth tassel hanging from the lock.
> 4. `chest_frost`: pale birch wood, frosted iron bands, a cap of snow on the lid, a few small icicles along its rim.
> 5. `chest_swamp`: dark wet wood, moss on the lid and a creeping vine, a lock shaped like a lily pad.
> 6. `chest_shadow`: near-black wood, black iron, a softly glowing purple gem as the lock (flat pixels, no blur), a
>    wisp of cobweb at one corner. Spooky but cute.
> 7. `chest_crystal`: a grey stone chest, small pink and pale blue crystals growing from its corners.
> 8. `chest_candy`: gingerbread with white icing drips, candy-cane striped bands, a gumdrop lock.
> 9. `chest_coral`: blue-green shell and coral, a pearl lock.
>
> Before you deliver each, check with code and report: the canvas is 32 × 32; the chest's width, height and lowest
> row; the colour count; alpha only 0 or 255. Then deliver its 1× PNG named by its id and its 8× preview, then the next.

## Back in the game

Each copied from `art-variants/chests/` (a `PICKED` table, snapped to the grid if they come back big,
`tools/ai_sprite_eval.py`), registered in art/assets.json (`kind: prop`), and a land's chests drawn in its style
(maps.json theme `chest`), closed till opened, then `treasure_chest`.

## Results

- **2026-11-26**: three back as asked (32 × 32, alpha 0 or 255, 24 colours each): `chest_coral` (a teal shell, a pearl
  lock), `chest_candy` (gingerbread, candy-cane bands, a green gem lock) and `chest_crystal` (grey stone, pink and blue
  crystals; sent at 8× only, cut back to 1×). Copied as delivered (`tools/chest_art.py` `PICKED`), and Crystal Mountain
  and the Glimmerdeep, Candy Mountain and the Water Temple show them (theme `chest`). Six to come; their lands keep the
  open chest, faded once emptied, till then.
- Earlier the same day: Meanwhile the chests are already off the minimap and the world map, with no "!"
  over them, and `treasure_chest` no longer stands as sand decoration on the three beaches.
