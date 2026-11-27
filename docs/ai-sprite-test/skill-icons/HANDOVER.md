# Skill icons as pixel art, by ChatGPT (2026-11-27)

The user, 2026-11-27: "I want to create new pixel artwork for all spells." Today every skill's icon
(`art/sprites/skill_<id>.png`, 53 of them) is drawn in code as light by `tools/skill_art.py`: glows and
flares on a dark rounded tile, 128 pixels, shown smoothed (playtesting 2026-10-23: "the spell icons don't
have to be pixel art, but could be more like their animations"). This reverses that: each becomes pixel
art in the look of the item icons (Retro Diffusion's, `style_reference_rd_4x.png`), so the skills, the
items and the carved-wood HUD's skill sockets (`art-variants/hud/kit/skill_socket.png`, a round ring
with an empty middle) read as one game.

Redraws of what each skill already shows, not new ideas: `batchN/NN_<id>_today.png` is today's icon at 2×
(its subject and colours), `batchN_today_sheet.png` the batch on one sheet with names.

## How to run it

One chat per batch in the ChatGPT project. Attach `style_reference_rd_4x.png`, the batch's
`batchN_today_sheet.png` and its `NN_<id>_today.png` files in order; paste the prompt with the batch's
list in place of `[LIST]`. Send "next" after each icon. Bring back each 1× PNG named `skill_<id>.png`
and its 8× preview (or the zip).

## The prompt

> Redraw the skill icons from my game as pixel art, one at a time. Each attached `_today` picture is the
> skill's icon now, drawn as soft light: keep what it shows (its subject, its colours by name, its
> sense of motion) and draw it in the look of the attached style sheet, Retro Diffusion's item icons at
> 4×. That's the look to match exactly: chunky and rich, smooth broad shading lit from the top left with
> bright highlights and deep, slightly coloured shadows, a one-pixel outline in a deep shade of each
> thing's own colour (never black), no dithering or grain, no soft glow.
>
> Every icon: a 64 × 64 canvas, transparent, alpha 0 or 255 only; no tile or background behind it (the
> game puts it in a round carved socket or on a coloured tile); the subject centred and kept inside a
> circle about 56 pixels across, so it fits the round socket, filling it well; 20 to 45 colours. Magic is
> drawn as hard pixels: a few crisp sparks, streaks or rings touching the subject are fine, but no blur,
> no glow, no half-transparent pixels. Each skill's main colours as listed, so an element reads at a
> glance (fire orange and red, water blue, wood green, earth brown and ochre, metal silver and gold,
> light gold and white, dark violet, healing green, buffs sky blue and gold, curses violet). Every icon in
> the batch has its own silhouette: no two alike.
>
> [LIST]
>
> For each: say its size and colour count, then deliver its 1× PNG named `skill_<id>.png` and the 8×
> preview, then the next.

## Batch 1: blows and battle cries (13)

1. `bash` (Bash, a heavy swing): a wooden club mid-swing, a short white-orange impact burst at its head.
2. `power_strike` (Power Strike, a crushing blow): a sword coming down hard, a bright star-shaped crack where it lands.
3. `whirlwind` (Whirlwind, spin and hit every foe): a sword's arc curled into a full spinning ring, orange-white.
4. `charge` (Charge, dash through a foe's guard): a spear tip driving forward with speed lines behind it, breaking a small shield.
5. `rush` (Rush, three quick blows): three short slashes side by side, white-orange.
6. `impact` (Impact, a blow that cracks armour): a fist striking a cracking breastplate, shards flying.
7. `double_combo` (Double Combo, two heavy blows): two crossed slash marks, one after the other.
8. `dodge_whip` (Dodge Whip, lash and skip clear): a leather whip's lash in an S curve with a quick blue speed streak.
9. `wild_call` (Wild Call, call the wild on every foe): a claw mark of three green-gold slashes with a paw print.
10. `beast_impact` (God of Beast Impact, you and your companion as one): a fist and a paw striking together, a gold burst between them.
11. `roar` (Roar, a mighty roar): a beast's open mouth in profile with three sound arcs, orange.
12. `gust` (Gust, wings whip up a gale): a curling white-blue wind swirl with a feather in it.
13. `rock_throw` (Rock Throw, hurls a boulder): a brown boulder flying with motion lines and small pebbles.

## Batch 2: elemental magic (13)

1. `fire_bolt` (Fire Bolt): a fireball streaking up to the right with a flaming tail, orange, red and yellow.
2. `ember` (Ember, a little ball of fire): a small single flame with a few hot sparks round it.
3. `meteor_blast` (Meteor Blast, meteors rain on every foe): a dark rock meteor in flames with two smaller ones behind.
4. `stone_spike` (Stone Spike, earth magic): three sharp ochre rock spikes bursting up from the ground.
5. `mud_shot` (Mud Shot, a splat of heavy mud): a brown mud ball flying, drips trailing.
6. `leaf_storm` (Leaf Storm, wood magic on every foe): green leaves swirling in a ring.
7. `vine_whip` (Vine Whip): a thorny green vine lashing in an S curve.
8. `bubble` (Bubble): one big shiny blue bubble with two small ones.
9. `jelly_splash` (Jelly Splash): a blue water drop splashing, little droplets round it.
10. `frost_breath` (Frost Breath, an icy gust that freezes): a pale blue icy breath with sharp snowflakes and an ice shard.
11. `dancing_fountain` (Dancing Fountain, jets of water rain on foes): a blue water jet rising and falling in arcs.
12. `flash` (Flash, a burst of blinding light): a gold and white eight-point burst.
13. `spiritual_lance` (Spiritual Lance, a lance of spirit light): a silver and gold lance pointing up to the right, a bright point.

## Batch 3: healing and blessings (14)

1. `first_aid` (First Aid, patch up one ally): a white bandage roll with a green cross.
2. `blessing` (Healing Spring, water washes over the party): a small spring of green-blue healing water in a stone ring.
3. `recovery` (Recovery, light mends one ally): a green heart with a gold glint.
4. `revive` (Revive, wake a fainted ally): a white feather rising with a small gold ring of light.
5. `full_heal` (Full Heal, back to full HP): a big bright green heart with a plus on it.
6. `mend_beast` (Mend Beast, a strong heal for companions): a green paw print with a small heart.
7. `bless` (Bless, ATK and DEF up): a sword and a shield crossed under a small gold star.
8. `protection` (Protection, DEF up): a sky-blue round shield with a gold rim.
9. `holy_glow` (Holy Glow, MAG up): a gold halo ring over a small white star.
10. `guardianship` (Guardianship, a ward over the whole party): a sky-blue dome over three small figures' heads.
11. `animal_training` (Animal Training, ATK and SPD up): a trainer's whistle with a paw print and a speed streak.
12. `boost` (Boost, ATK up): a red upward arrow with a small flame.
13. `super_boost` (Super Boost, ATK way up): two stacked gold upward arrows, bigger and brighter than Boost.
14. `berserk` (Berserk, a wild rage, DEF down): an angry red face mark, a fierce red flame, a cracked shield edge.

## Batch 4: curses, monsters' moves and travel (13)

1. `curse` (Curse, a foe hits for less): a violet skull with a downward arrow.
2. `poison` (Poison, HP lost each round): a violet-green poison bottle with a skull on it, a bubble rising.
3. `poison_mist` (Poison Mist, a choking cloud): a puffy violet-green cloud with drips.
4. `evil_eye` (Evil Eye, a cold glare): a violet eye with a slit pupil and rays.
5. `shadow_bite` (Shadow Bite, fangs of darkness): two dark violet fangs closing, a crescent of shadow.
6. `venom_bite` (Venom Bite, fangs that poison): two white fangs dripping green venom.
7. `web_shot` (Web Shot, sticky webs): a grey-white spider web, a small violet spider.
8. `beast_lore` (Beast Lore, call out every foe's weak spots): an open book with a red target mark.
9. `nibble` (Nibble): a little bite out of a round, a tiny tooth mark, cute.
10. `pine_needles` (Pine Needles): three sharp green pine needles flying.
11. `bounce` (Bounce): a round jelly mid-bounce over a curved arrow.
12. `golden_spin` (Golden Spin, a dazzling spinning tackle): a golden spinning disc with sparkles.
13. `bridge_of_light` (Bridge of Light, carry yourself to a town): a gold rainbow-like arch of light over a tiny town roof.

## When they come back

`tools/ai_sprite_eval.py <png> --kind item --canvas 64` snaps any big picture to the grid; each is held to
`pixel_style.py check --kind item` and looked at beside the item icons and in the carved skill socket at the
game's sizes (24 points on the battle buttons, about 40 in the socket). Then `tools/skill_art.py` learns to
copy the picked ones (as `item_art.py CHATGPT`), and the game shows them crisp (they're 64 pixels, not 128
smoothed). Every skill keeps its own animation in battle; only the icon changes.
