# The landmarks (2026-11-21)

The five big buildings still drawn in code, each standing once in the world: the **Wildfolk Lodge** and the
**Warrior Guild** (the two guild halls), **Starfall Isle's Star Observatory** and **Moonwell**, and the **Emerald
Road's Emerald Spire**. Bigger canvases than the town houses: 160 × 160 (the spire 192 × 192), so the previews
are shown at 6× (the spire at 5×), each 960 pixels.

One new chat, the five images attached in this order:

> Redraw these 5 landmark buildings from my game, in the order attached, as the project's instructions say.
> They're bigger than the houses: each picture is shown at 6× (the last, the spire, at 5×), so their real
> canvases are 160 × 160 (the spire 192 × 192).
> 1. **wildfolk_lodge**: a big log lodge with a mossy green roof and antlers on its gable, a carved round
>    emblem, lit windows, a wooden door under a green awning, a totem on the left, a fence and grass round
>    its foot. **129 wide, 92 tall, foot on row 159 of 160.**
> 2. **warrior_guild**: a grey stone guild hall like a small castle: battlements and two red flags, a red
>    tiled roof with a shield and crossed swords on its gable, lit windows, an arched wooden door with red
>    banners each side, a weapon rack on the left, a training dummy on the right. **127 wide, 95 tall, foot
>    on row 159 of 160.**
> 3. **star_observatory**: a round grey stone tower with a deep navy dome dotted with gold stars, a crescent
>    moon finial, a brass telescope poking out of the dome, lit windows, a navy door, pale blue and violet
>    crystals at its foot. The telescope brass-orange, the stars small. **119 wide, 138 tall, foot on row 159
>    of 160.**
> 4. **moonwell**: a pale lavender marble shrine with a domed roof and a crescent moon on top, round pale blue
>    orbs along its roof, three dark blue arches with glowing pale blue crystals, a round pool of pale blue
>    water in front, a lamp post each side. **124 wide, 100 tall, foot on row 159 of 160.**
> 5. **emerald_spire**: a tall emerald green castle: a central tower with a tall pointed green spire and a
>    green orb on top, two smaller round towers with cone roofs each side, gold trim bands, lit windows, a
>    wooden arched door, a little red flower bed at its foot. **124 wide, 162 tall, foot on row 190 of 192.**
>
> Shade every big form strongly in broad areas, not texture: the side away from the light clearly darker than
> the front, a thick shadow band under every eave and ledge, the bottom of each wall a shade darker, doors and
> windows set deep. The outline a deep shade of what it borders, about half as bright as it, not near-black.
> Warm yellow only for window panes (the moon, stars and telescope not yellow). Follow the project's steps
> exactly: measure, draw, check, and deliver the 1× PNG file for each, fully transparent, on its own canvas
> (160 × 160, the spire 192 × 192) at exactly the size and foot row given above.

## Results

- **Wildfolk Lodge, try 1** (`wildfolk_lodge_chatgpt_1.png`): the size is right (160 × 160, 129 × 92, foot on
  row 159, alpha clean, a true 1× grid). It fails two hard rules: `colour_density` 0.42 (34 colours on 8,180
  pixels; a sprite this big needs 45 or more, ours has 80: the project's "at most 40" was written for 96-pixel
  houses, now scaled with size) and `form_relief` 0.014 (ours fails it too, 0.014). Its outline isn't darker
  than what it rounds (`outline_dark` 0: the mid wall tone all round), the logs one bright orange. Follow-up,
  same chat:

> The lodge is the right size, thanks. Keep its shape and everything on it, same size and foot row, but fix
> three things. 1) Colours: these landmarks are much bigger than the houses, so use 60 to 90 colours, as more
> shades in each ramp (logs, moss, stone, wood, the totem). 2) The outline: each outline pixel clearly darker,
> about half as bright as the pixel just inside it: dark red-brown round the logs, deep green round the moss,
> dark grey round the stones. 3) Shade the big forms in broad areas: the right-hand wing and the lodge's right
> side in clear shade, a thick dark band under the moss roof's eave across the logs, the lower third of the log
> walls a shade darker, the logs lit top left and darker toward the bottom right, the door and windows set deep
> with a dark top and left edge. Then do the other four the same way: 60 to 90 colours each, outline half as
> bright as what it borders.
- **All five, one chat** (`*_chatgpt_1.png`, the lodge `_2`): every one at exactly the asked canvas, size and
  foot row, alpha clean. But every one fails hard rules, where three of ours pass everything (the warrior
  guild, moonwell and spire) and the other two miss one each (the observatory `flat` 0.155 by a hair, the
  lodge `form_relief`). ChatGPT's: `flat` 0.16 to 0.27 (broad single-tone areas, clusters of 9 to 14 pixels
  where 2 to 5 are wanted), 30 to 37 colours where 45 or more are needed (the lodge's follow-up asked for 60 to
  90 and got 36), and four of five with no outline darker than what it rounds. Side by side they're plainer:
  fewer stones, stars and carvings. **Ours kept for all five.** At 160 pixels ChatGPT draws as it does at 96,
  just bigger and so emptier; the houses won because ours were weak there, not here.
- **Second round, lodge (try 3) and warrior guild (try 2):** the follow-up worked on colours and flat areas:
  76 and 75 colours, `flat` passes, the lodge soft 100%. Both outlines overshot (`outline_rel` 0.51 and 0.50);
  each outline pixel snapped to the sprite's own colour nearest 12% lighter, no new colours, fixes both
  (`*_fixed.png`, 0.61 and 0.59). Left on each: `form_relief`, the lodge 0.01358 (ours 0.01365, a tie that
  fails), the guild 0.01454 (ours 0.0195, passes). Side by side the lodge reads nicer than ours; the guild
  paler and flatter. Both back for broad shade (prompt in the chat, 2026-11-21).
