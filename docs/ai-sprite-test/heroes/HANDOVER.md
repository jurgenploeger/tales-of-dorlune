# Hero sprites v2: 64-pixel bodies drawn by ChatGPT

Goal: one hero **doll** at a size where armour, gloves, boots, necklaces, belts, hair and held weapons read,
with idle, walk and attack in eight directions (running is the walk played faster). A blank canvas: a smooth,
gender-neutral body in plain shorts, nothing else. Everything a hero wears or holds is a layer drawn over it.

**One doll, no genders, Human and Elf** (the user, 2026-11-24: "For now we're just going to use sprites for one
doll, so no gender. Eventually we're going to introduce different haircuts, and that way the player can decide
themselves what the hero looks like"). The player's look comes from the layers: hair, from short to long, and
for an Elf an **ears layer** fitted to the head like a hat. No dwarves for now. The plan till then was nine
bodies (Human, Elf, Dwarf × Male, Female, Other); the art made so far, drawn as Human Male (`tries/`), is the
doll: bald, flat-chested, in plain shorts.

Prompts: [`PROMPTS.md`](PROMPTS.md). Templates to attach: [`templates/`](templates/), made by
`python3 tools/hero_template.py`. The overview of every sheet: the artifact "Hero Sprite Sheets", https://claude.ai/artifact/AbY18V5Yeojpt8RALckopY .

## Where we are today (measured, 2026-11-23)
- Every hero sheet and layer is 192 × 192: four 48 × 48 frames a row, rows facing up, right, down, left
  (`art/assets.json` `player_walk`, Retro Diffusion's `four_angle_walking`).
- Inside that frame the body is small: humans and elves 30 to 33 px tall and 16 to 21 px wide, dwarves
  24 to 27 px tall. A glove or boot is a few pixels; a necklace one or two.
- Walk only. Idle is the walk's first frame with a blink and a breath (`IdlePoses.swift`); running is the
  walk sped up (`Walker.swift`); in battle the hero stands in walk frame 1 at 2× and only the weapon node
  swings (`BattleScene.swift`, `swing`/`thrust`).

## Size decision: the LPC standard, 64 × 64 frames, a chibi body about 46 px
What others use (sources below):

| Game or system | Character frame | Equipment as layers? |
|---|---|---|
| LPC / Universal LPC Spritesheet Generator | 64 × 64; big swings on 128 or 192 frames | yes, every item its own sheet |
| RPG Maker MV/MZ | 48 × 48 (VX: 32 × 32) | generator only; game uses a flat sheet |
| Stardew Valley | 16 × 32 farmer | yes: body, arms, shirt, pants, hair, hat |
| Tibia | 32 × 32 | partly: tinted regions plus add-ons |
| Ragnarok Online, MapleStory | (not found) | yes: each item anchored to the body per frame |

- Every real dress-up system (LPC, Stardew, Ragnarok, MapleStory) draws each item as its own sprite, aligned
  to the body frame by frame. We already do (`GameSession.layers`, `GearOverlay`); the frame size decides
  how much detail an item gets, not how layering works.
- Chibi figures are 2 to 3 heads tall. Below about 32 px of height, gloves, boots and necklaces shrink to
  single-pixel specks. At 44 to 48 px with a 2.5-head body the torso is about 14 to 18 px: room for a belt
  row, a pendant and cuffs, and 2 × 2 or more pixels for each glove and boot.
- 64 × 64 (LPC's size) leaves 10 to 14 px above the head for hats and helmets and about 8 px a side for
  capes and held weapons.

Chosen (the user, 2026-11-23, after three ChatGPT tries and the size board,
`templates/size_board_3x.png`):
- **The open paper-doll standard's frame (LPC): 64 × 64**, the body about 48 px tall. The lowest foot pixel on
  **row 60**, the body centred on **x 32**.
- **One art pixel stays one point.** The hero gets about 50% taller on screen than today (48 against 31) and
  is about as tall as the town gate (51) and a little under a tree (56). The rest of the game (buildings,
  trees, props, tiles, monsters) is to be brought to the same scale later (the user: "eventually we will
  update everything else in the game as well"); the hero comes first.
- **Chibi, about 2.4 heads tall, shoulders no wider than the head** (the user, 2026-11-23). The numbers are
  measured from the design they picked: ChatGPT's big painting of try 6, snapped to the grid in code
  (`tries/try6_human_male_snapped.png`, 46 px). On the way: a 2.4-head chibi with a toddler face (try 1), a
  stick figure (try 3), a bodybuilder (try 5: 32-pixel shoulders under a 24-pixel head; in chibi sprites the
  head is the widest part), and semi-chibi, three heads tall (try 6's own 1×: "horrible"). Armour widens the
  silhouette (pauldrons, helmets, chunky boots) instead of the base body being broad. Fairyland Online itself was
  2D isometric with Humans, Dwarves and Elves; its proportions aren't recorded anywhere we could read.

| Body | Height | Head | Chest | Arms, legs | Legs | Feet |
|---|---|---|---|---|---|---|
| The doll (Human; an Elf with the ears layer) | 46 | 19 | 12 | 4 | 11 | 6 |

Legs are from the shorts' hem to the soles. `tools/hero_template.py` `SPEC` holds these; the guides draw them (blue: head top, cyan: chin, violet ticks: the chest's width, orange: the shorts' hem, green: feet).

## The sheets
One PNG per body per animation. Columns are frames, rows are **eight directions, clockwise from up**: up,
up-right, right, down-right, down, down-left, left, up-left (the user, 2026-11-23). The world is isometric, so
walking along a row of cells moves diagonally on screen: the diagonals are the views seen most.

| Animation | Frames | Sheet | Notes |
|---|---|---|---|
| idle | 4 | 256 × 512 | a breath: chest and head down a pixel and back, arms settle; blinks stay in code |
| walk | 8 | 512 × 512 | after the user's reference video: contact, lift, pass, reach, twice; 83 ms a frame; the planted foot on row 60 |
| attack | 6 | 384 × 512 | ready, wind-up, strike, follow-through, recover, ready; empty hand closed as a grip |

File names: `hero64_doll_<anim>.png` (one row a direction: `hero64_doll_<anim>_<direction>.png`), for example `hero64_doll_walk.png`.

- ChatGPT draws **five views: down, down-right, right, up-right, up**. **Down-left, left and up-left are
  their mirrors** for the base body and hair. Only layers that differ per side (a weapon hand, a
  one-shouldered cape) get left rows of their own.
- Down-right is a three-quarter front view (both eyes, the far one a pixel narrower, the nose toward the
  right); up-right a three-quarter back view (the back of the head, the near ear and cheek edge, no eyes).
- The attack is drawn empty-handed: the weapon is a layer of its own (below), so one attack works for every
  weapon. The swing arm ends in a closed fist at the grip.

## Layers over the base
Bottom to top: cape-back, **body**, **underwear**, boots, legs, torso armour, gloves, belt, necklace, hair,
hat, cape-front, weapon.

- Each layer is drawn on the approved base sheet as reference and delivered as **that item alone** on
  transparency, same canvas, same frames.
- **Hair** in one brown-to-ginger ramp (hue 15 to 35°): `appearance.json` `hairLayer` (hue 340 to 70)
  recolours exactly that range, so every hair colour comes from one drawing.
- **Armour and cloth** in the material colours of `tools/wear_art.py` `MATERIAL`, so tints and dyes keep
  working. The trim in a second colour nothing else uses, so `dye_art.py cut` can lift it out.
- **Anchors** (made in code or by hand, not by ChatGPT): a marks sheet per body per animation, like today's
  `marks_<body>.png`, one pixel each: main-hand grip red `#FF0000`, off hand blue `#0000FF`, neck green
  `#00FF00`, waist yellow `#FFFF00`, wrists magenta `#FF00FF`, ankles cyan `#00FFFF`, head top orange
  `#FF8000`, eye row violet `#8000FF`. Plus a weapon angle per frame (0 to 315 in 45° steps).

## Weapons
Each weapon is **one sheet of 8 angles** on a 128 × 128 canvas per angle, the grip on the middle pixel
(64, 64), 0° pointing straight up and turning clockwise (`templates/weapon_wheel_8x.png`). Code places it
on each frame's grip mark at that frame's angle, in front of the body or behind it by direction (the rule
`GearArt.posed` keeps today). This avoids asking ChatGPT for every weapon in every frame (22 frames × 8 directions). Draw the 0°, 45° and 90° views; 135° to 315° are those turned in whole quarter
turns or mirrored where the weapon is symmetric, and drawn by hand where it isn't (a bow, a curved blade).

## The workflow
One doll, end to end (it was the Human Male pilot until 2026-11-24).

1. **Set up a ChatGPT project** with `PROMPTS.md` § Project instructions as its instructions and these files:
   `docs/ai-sprite-test/style-reference.png`, `templates/compare_48_64.png`, the body's guide
   (`templates/guide_<body>_8x.png`).
2. **Master frame:** prompt § Master base body for the body. Down-facing, standing, frame 1. Iterate until it
   passes the checks below and you like it. This frame is the character from now on: attach it to every
   later prompt in this body's chat.
3. **Turnaround:** the same pose facing down-right, right, up-right and up (§ Turnaround). Check they match the master in
   height, proportions, underwear and colours before any animation.
4. **Animations, one direction row per prompt:** § Animation row, with `templates/row_<body>_<anim>_8x.png`
   attached. Order: idle, walk, attack; each in down, down-right, right, up-right, up.
5. **Snap and check** every PNG that comes back, even when ChatGPT says it checked:
   `python3 tools/ai_sprite_eval.py <frame.png> --canvas 64 --height <body height> --colours 32 --kind creature --out <out>`
   (frames are snapped one at a time and centred, not yet on row 60; a sheet mode that cuts a row into
   frames and keeps the feet row is a follow-up). Anything off: § Fix prompts, one or two
   fixes at a time, quoting the failing rule.
6. **Assemble** the rows into `hero64_<body>_<anim>.png` (mirror right into left) and look at it at 1× and
   4× beside today's body on grass and on the dark battle field.
7. **Then layers:** the elf's ears (8 directions, five drawn, fitted to the head frame by frame as a hat
   is), hair (`appearance.json`'s styles redrawn for the doll, from cropped to long, so a player makes the
   hero read male, female or neither), then one armour set, gloves, boots, necklace, belt, cape, hat; then
   weapons.

## Acceptance (every frame)
- Canvas 64 × 64 per frame; feet on row 60 at contact frames; height within 1 px of the table; centred on
  x 32 when standing.
- Alpha only 0 or 255; no anti-aliasing, blur, glow or noise; every pixel the same size.
- 20 to 40 colours per sheet; skin in 5 or more hue-shifted shades.
- Lit from the top left. A 1-px outline in a deep shade of what it borders, never black (outline median
  light ≤ 0.25, at least 20% of pixels darker than 0.2, median saturation ≥ 0.45: `docs/pixel-style.md`).
- Chibi: head about 2/5 of the height, shoulders no wider than the head, big eyes with a white catchlight. Two eyes from the front, one from
  the side, none from behind.
- The same character in every frame: height within 1 px, head within 1 to 2 px, underwear the same shape
  and colour, skin the same ramp. Side and back views match the front.
- Front and back views even: `python3 tools/hero_symmetry.py check <png>` finds no pixel whose mirror across the
  middle column differs in shape or in its dark lines (outline, brows, eyes, mouth); only the shading may differ.
  `fix` evens one out (the left side kept, `--side right` the other) as a target to show ChatGPT, or to use.
- Underwear plain and fitted: shorts, one flat neutral colour (warm grey). No anatomy detail, no top.
- Elves: the ears layer is what sets them apart; the same doll otherwise.

## The pilot so far (Human Male, 2026-11-23, `tries/`)
1. **Try 1** (64 × 64, 45 px, every check passed): read as a toddler or a little monk. Small low eyes under
   heavy brows, big ears, a thin neck, a long trunk on stubby legs, fists at the hips, flat shading, the
   shorts outlined in the skin's brown.
2. **Try 2** (a 1254-pixel painting, about 70 px tall, about 30,000 colours, not on a grid): the design the
   user liked: bigger eyes with a catchlight, small ears, a neck, open hands, the shorts outlined in grey.
   Its richness was partly its size; never shrink it, redraw it.
3. **Try 3** (64 × 64, 46 px): followed "legs about 15 px" and came out spindly: 4-pixel limbs, legs too long.
   Hence the sturdy build above.
4. **Try 4** (64 × 64, 48 px, the sturdy build): every number on spec (head 20, neck 8, chest 16, limbs 6,
   legs 10, feet on row 60, 32 colours, alpha clean, the 8× exact). Two things left: no feet (the legs end as
   flat 6-pixel columns) and the arms flexed outward with fists, a bodybuilder pose that every frame after it
   would copy.
5. **Try 5** (the fix of try 4): feet (the leg a pixel narrower at the ankle, rows 57 and 58, a 7-pixel foot
   turned out on rows 59 and 60) and the arms hanging straight with a 2-pixel gap; every other number as
   try 4. With a 16-pixel chest, 2-pixel gaps and 6-pixel arms the shoulders are 32 wide, so he reads broad,
   which leaves room for pauldrons. Not taken: the user found the shoulders too wide and the head too big
   for what they want, and picked semi-chibi (three heads) instead. Its feet, face and shorts carry over.
6. **Try 6**, two pictures in one reply. Its 1× (semi-chibi, three heads, `tries/try6_human_male.png`): "horrible",
   chibi it is. Its big painting (`try6_human_male_big.png`): the design the user liked, but ChatGPT's own 1×
   had redrawn it. Snapped by us with `ai_sprite_eval.py --edges` (its fake grid runs 14 to 18 pixels a cell):
   46 × 22, head 19, shoulders 19 (the head 22 with its ears), legs 11, 21 colours
   (`try6_human_male_snapped.png`). The snap is the candidate master. Two flaws from where the grid slipped:
   a dark smudge at its right ear and the outline missing down its right arm; fix those pixels, or have
   ChatGPT sample its own picture (below).
7. **Try 7**: ChatGPT sampled its own painting with code (`tries/try7_human_male.png`): on spec (46 px, feet on
   row 60, centred on column 32, 21 colours), but uneven, the user saw: 21 pixels differ from their mirror
   (`hero_symmetry.py check`): a brow 2 pixels on one side and 3 on the other, the eyes drawn differently, the
   mouth a pixel off the middle, a stray line down the left shin, the right foot's outline broken, a gap at the
   right hand. `fix` evens it (`try7_human_male_sym.png`); the smile comes out a flat line.
8. **Try 8, the master** (approved by the user, 2026-11-23: "Now this looks great"; `hero64_doll_master.png`):
   ChatGPT sampled its own painting with code again, our evened copy attached as the target, and drew the smile
   back. 46 × 21, feet on row 60, columns 22 to 42, 20 colours, alpha clean, the 8× exact, and
   `hero_symmetry.py check` finds no difference. What worked, for every view after it: ChatGPT paints, makes
   the 1× from its painting with code ("sample, don't redraw"), we check it, and its fixes are asked for with a
   corrected file attached as the target.
   Its brows then read as a bow (the user): arches 4 pixels wide. Three variants were drawn in code (flat,
   a soft slope, a short dash); the user picked flat, 3 pixels on row 23, columns 28 to 30 and 34 to 36
   (`tries/master_brows_a.png`, the target for ChatGPT's change).
9. **Try 9, the master with flat brows** (`hero64_doll_master.png` since 2026-11-23): ChatGPT's change, sampled
   with code, matches the target pixel for pixel; symmetric, 46 px, 20 colours.
10. **Down-right** (`hero64_doll_down-right.png`, approved by the user): the first turnaround view, first try.
    46 px, feet on row 60, the master's box (columns 22 to 42), only the master's 20 colours. Down-left is it
    mirrored (`hero_template.py` `approved()` mirrors any left view with no file of its own).
11. **Right** (`hero64_doll_right.png`, approved by the user, first try): 46 px, feet on row 60, columns
    23 to 41, the master's 20 colours. The near arm hangs at the back edge of the torso, so from the side the
    body reads slim (about 9 px); kept as drawn. Left is it mirrored.
12. **Up-right** (`hero64_doll_up-right.png`, approved by the user, first try): 46 px, feet on row 60,
    columns 23 to 41, the master's 20 colours; the ear's inside and a blush pixel show at the face's edge, no
    eye. Up-left is it mirrored.
13. **Up** (`hero64_doll_up.png`, first try): symmetric (`hero_symmetry.py check` 0), the master's own
    silhouette pixel for pixel, its 20 colours. The standing turnaround is complete: all eight directions,
    five drawn and three mirrored (`hero64_doll_turnaround.png`). Each view took one try once the master
    and the earlier views were attached and ChatGPT made the 1× from its painting with code.
14. **Idle** (`hero64_doll_idle.png`): ChatGPT drew the down row (`hero64_doll_idle_down.png`: frames 1
    and 4 the master exactly, 2 and 3 the upper body and the hands a pixel lower, symmetric). The other rows
    were first made in code by shifting the approved views (`tools/hero_idle.py` `breathe`), but that left
    chopped pixels where moved and still columns met (the user): every row is drawn by ChatGPT instead, the
    tool only assembles them (a left row its right twin mirrored). Done 2026-11-23: down, down-right, right, up-right
    and up drawn (each frames 1 and 4 the approved view exactly, 2 and 3 a pixel lower above the legs, feet on
    row 60, the master's colours; up symmetric), the left three mirrored (`hero64_doll_idle.gif`).
15. **Walk down** (`hero64_doll_walk_down.png`, third try). Try 1 was paintings only, with mitts for
    hands, elbows bent and the knee lifted like a march. Try 2 (`tries/walk_down_try2.png`) had straight arms
    and clean hands, but the legs merged (4 px each, no gap), the lifted leg stopped in a flat bar with no
    foot, and it held only two poses. Try 3 passed: the master's own legs (frames 1 and 4 are the master from
    row 50 down), the foot up 2 then 1 px with its whole shape, a 1 px bob, the opposite hand 1 px lower, the
    head the master's in every frame, the master's colours. What made it work: naming the cycle frame by frame
    and saying "the master's own legs". `tools/hero_idle.py doll walk --gif` assembles the sheet and
    `hero64_doll_walk.gif`.
16. **Walk down-right** (`hero64_doll_walk_down-right.png`, after tries 1 to 9 in `tries/`). ChatGPT kept
    breaking the pieces it moved: legs crossed above the knee, feet cut off as flat bars, shoulders done by widening
    the chest, a gap closed by fattening the belly, hands flared sideways. What worked: a target built in code from
    the approved standing view, moving whole pieces (`tries/walk_down-right_target.png`), shown to the user as a GIF
    until approved, then handed to ChatGPT, which matched it pixel for pixel. The motion the user approved:
    - legs: the thighs never move; each foot lifts whole, 2 px then 1 px, stepping 1 px forward (right) only at the top
      of the lift, the near leg drawn in front where they overlap;
    - arms: the swing is seen in depth, so it shows vertically. The near hand swinging back rises (2 px, then 1);
      the far hand swinging forward drops 1 px and crosses 1 px in front of the hip. Hands never move sideways
      past the standing view's outline (the user: "flaying outwards"), and the body stays its own width (filling a
      gap with the body made "his belly fat");
    - shoulders move at most 1 px with the arms; the head bobs 1 px on frames 2 and 5.
    Lesson: for any view where limbs overlap, build the target in code from the approved still and let ChatGPT
    match it; describing the motion in words took nine tries and never got there.
17. **Walk, 8 frames** (2026-11-24). The user sent a video of the walk they want (`reference/`: 8 poses at
    83 ms, a real stride, a 2 px bob, gear that lags a frame). ChatGPT painted a lively 8-frame down-right walk,
    then its own 1× "turned shit": it redrew instead of sampling, and our "keep the standing view exactly / never
    wider" lines pulled it back to the standing pose. We snapped the painting ourselves (`tools/hero_snap_walk.py`:
    the painting's ~6.9 px cells, each cell's middle colour mapped to the approved view's palette, each frame's
    planted foot on row 60) and the stride survived. A second painting with the arms swinging more was made; the
    user preferred the first (`tries/walk8_down-right_try1_*`), now `hero64_doll_walk_down-right.png`. The
    6-frame walk down and down-right went to `tries/walk6_*_approved.png`; walk down is to be redone the new way.
18. **Walk down, 8 frames, and 1 px outlines** (2026-11-24). ChatGPT sent three walk-down paintings
    (`tries/walk8_down_try1{a,b,c}_painting.png`); the user picked the second (the master's height, the most even
    face). Snapped, the outline came out 2 px thick: ChatGPT paints it about 1.5 of our pixels wide. Two fixes:
    the snap takes each cell's most common colour and goes dark only where most of the cell is outline
    (`tools/hero_snap_walk.py`), then `tools/hero_outline_thin.py` turns a second dark pixel inside the outer
    outline into the colour beside it, leaving thin parts (ears, hands) alone. The down-right walk was thinned
    the same way. Every walk row: snap, then thin.
19. **Walk right, 8 frames** (2026-11-24). Two paintings (`tries/walk8_right_try1{a,b}_painting.png`), snapped at
    7.0 and thinned; the user picked the first (the same motion as the second, without its stray dark marks).
    Walk left is its mirror.
20. **Walk up-right, 8 frames** (2026-11-24). ChatGPT first re-sent its walk-right paintings; asked again with
    only the up-right view and the reference strip attached and the view spelled out (the back of the head, no
    face), it sent three (`tries/walk8_up-right_try1{a,b,c}_painting.png`). The first was the side walk seen a
    little from behind; the user picked the second, snapped at 6.95 and thinned. The second and third drew the
    figure sliding across its cell (the head 6 and 12 px over half a step), which in place jitters: each frame
    was moved so its head stays on column 32 (`hero_snap_walk.py --centre`). Walk up-left is its mirror.
21. **Walk up, 8 frames** (2026-11-24). Two paintings (`tries/walk8_up_try1{a,b}_painting.png`), a true back
    view at the first ask (only the up view and the reference strip attached); the user picked the second,
    snapped at 6.97 and thinned. Its head bobs 3 px over a step (the other walks 1 to 2), kept as painted. The
    walk is complete in all 8 directions.
22. **Attack down, 6 frames** (2026-11-24). Five paintings (`tries/attack6_down_try1{a..e}_painting.png`), the
    same motion in each (ready, the fist raised by the head, a lean in with the fist across the chest, low by
    the far hip, recover, ready); snapped with `hero_snap_walk.py --grid 3x2`. The second was drawn small and
    the fifth on a smoky backdrop; the first lifts a foot on the strike and the fourth snapped with a dark block
    between the legs. The user picked the third, snapped at 7.68 and thinned. The strike is a short chop; the
    sword, placed on the grip, will carry the arc.
23. **Attack down-right, 6 frames** (2026-11-24). Asked with attack down's painting attached, ChatGPT sent that
    painting back; in a new chat with only the down-right view attached and the six beats in words, it sent two
    (`tries/attack6_down-right_try1{a,b}_painting.png`). The second swapped hands mid-swing (the near fist up
    and punching, the far one winding up); the user picked the first, the far (right) fist all through, the
    same swing as attack down. Snapped at 7.78 with `--grid 3x2` and thinned. Attack down-left is its mirror.
24. **Attack right, 6 frames** (2026-11-24). Three paintings (`tries/attack6_right_try1{a,b,c}_painting.png`; the
    first and third near copies). The first raised a thin straight arm above the head (it read as waving) and
    lost the outline under the feet in frames 4 to 6; the user picked the second, the arm cocked back beside
    the head, snapped at 8.43 with `--grid 3x2` and thinned. Attack left is its mirror.
25. **One doll** (the user, 2026-11-24): no genders, Human and Elf only (an Elf is the doll with an ears layer),
    no dwarves for now. Every `hero64_human_male_*` became `hero64_doll_*`; `hero_template.py`'s `SPEC` is the
    one doll, and the other eight bodies' templates are gone.
26. **Attack up-right, 6 frames** (2026-11-24). Two near-identical paintings
    (`tries/attack6_up-right_try1{a,b}_painting.png`), the right fist (on our right) all through; the wind-up
    only pulls it to the ear, a punch more than a swing, fine from behind. The second's ready frames sit a
    pixel apart (a jump as it loops); the user picked the first, snapped at 8.43 with `--grid 3x2` and thinned.
    Attack up-left is its mirror.
27. **Attack up, 6 frames** (2026-11-24): the attack is complete in all 8 directions. Three paintings
    (`tries/attack6_up_try1{a,b,c}_painting.png`; the third on a black blotchy backdrop). Snapped, both filled
    the gap between the legs with outline; `tools/hero_leg_gap.py` reopens it (#.# as in the standing view).
    The first had grey stripes down a leg and on the back, the second a thin arm 6 px above the head in the
    wind-up ("the arm moves too far up", the user). Kept: the second, with the first's wind-up (frame 2), its
    grey stripe painted skin and its legs, which touched, swapped for frame 1's standing legs with the gap.
28. **Elf ears, facing down** (2026-11-24). Asked for the doll as an elf (whole figure, so it draws the ears
    in place), ChatGPT sent three paintings of one design (`tries/ears_down_try1{a,b,c}_painting.png`):
    leaf-shaped ears level with the eyes, pointing out and a little up, an inner shade. Snapped, the heads came
    a pixel narrower than the approved one, so only the ears are kept: the snap's left ear, lifted onto the
    approved head where it differs from it, mirrored for the right (`hero64_doll_ears_down.png`, a layer;
    `hero64_elf_down.png` the doll wearing it). Drawing an ear by hand instead pointed up like a horn. The
    user picked the first painting's (A), the shorter. In-game demos (`demo/`, `tools/hero_demo.py`) at 1×,
    the user's ask.
29. **Elf ears, facing down-right** (2026-11-24): three paintings (`tries/ears_down-right_try1{a,b,c}_painting.png`),
    the near ear out behind the head, the far one's tip past the face. The user picked the first's near ear (as
    long as the down ears; the big painting's, the cleanest, was half as long), its outline closed where it
    faced clear air. Its face had snapped a pixel wider, which moved the right eye: only the ears are kept, the
    approved face untouched. `hero_ears.py` lays them on the down-right frames and, mirrored, the down-left.
30. **The ears as ChatGPT drew them** (the user, 2026-11-24: "Just use what chatgpt provided"). The outlines I
    closed made the ears stiff (a straight six-pixel top edge), and raising their tips in code was "a regression":
    both views now carry the snapped ears with no pixel fixes, only lifted onto the approved head (down-right's
    far side, snapped a pixel wider, taken a column over so the face and its right eye stay the approved ones).
    Lesson: don't redraw ChatGPT's ears; place them.
31. **Elf ear, facing right** (2026-11-24): two paintings (`tries/ears_right_try1{a,b}_painting.png`). The user
    picked the first: its snapped head matched the approved right view pixel for pixel, so its ear (a long leaf
    pointing back and a little up, the small round ear painted over in skin) is placed exactly as drawn. Left is
    its mirror.
32. **The ears off the walk and attack rows** (2026-11-24): fitted from the standing views, they broke there (the
    user: "it still shows part of the human ear"). Those rows were painted apart from the standing views: only
    30 to 70% of their head pixels match after the best shift (idle's 100%). The user chose to have ChatGPT paint
    the ears on each walk and attack row (`hero64_doll_ears_<anim>_<direction>.png`, frame by frame, which
    `hero_ears.py` lays on as they are); till then those rows are the plain doll. Hair and hats will meet the same
    heads.
33. **Elf walk right** (2026-11-24): ChatGPT repainted the picked walk-right painting with the ear added
    (`tries/elf_walk_right_try1{a,b}_painting.png`); the first lined up with the approved walk in every frame with
    no shift, so its ears are lifted frame by frame as drawn (`hero64_doll_ears_walk_right.png`; left mirrored).
    Its ear is bigger than the standing one (8 to 9 px past the head against 5), kept as drawn.
34. **Elf walk down-right** (2026-11-24): one painting (`tries/elf_walk_down-right_try1_painting.png`), lined up
    with the approved walk (a few frames a pixel higher, matched by the head); the near ear behind the head and
    the far tip past the face lifted as drawn (`hero64_doll_ears_walk_down-right.png`; down-left mirrored).
35. **Elf walk down** (2026-11-24): one painting (`tries/elf_walk_down_try1_painting.png`), both ears as drawn
    (`hero64_doll_ears_walk_down.png`); its last four frames were drawn a pixel higher, matched by the head.
36. **Elf attack down** (2026-11-24): one painting (`tries/elf_attack_down_try1_painting.png`), both ears as drawn,
    the raised fist in front of the left ear (`hero64_doll_ears_attack_down.png`). The lifting is
    `tools/hero_ears_row.py` now.
37. **Elf attack down-right** (2026-11-24): two paintings of one drawing (`tries/elf_attack_down-right_try1{a,b}_painting.png`;
    the first with a dark glow round each figure); the second, clean, lined up with no shift
    (`hero64_doll_ears_attack_down-right.png`; down-left mirrored). In frame 2 the raised arm covers the near ear.
38. **Elf attack right** (2026-11-24): two near-identical paintings (`tries/elf_attack_right_try1{a,b}_painting.png`),
    the second picked; frames 3, 5 and 6 lined up a pixel down (`hero64_doll_ears_attack_right.png`; left mirrored).
    The head's edges for the lift come from the standing view (`hero_ears.fit`): in frame 2 the raised arm was taken
    for the back of the head and the human ear stayed. Every drawn direction but up and up-right now has ears.
39. **Elf ears up-right** (2026-11-24): seen from behind, the ears point back toward the viewer. The first try put
    the big ear on the left (my prompt had the sides swapped), the second stuck it straight out sideways with its
    inside showing (`tries/elf_up-right_try1{a,b,c}_painting.png`); the third, told both, rose up and a little out
    with its back to us. Of its six (`try2{a..f}`), the user picked 4 (`d`), whose outline stayed closed when
    snapped (1's lost a pixel of it), one pixel over (`hero64_doll_ears_up-right.png`; up-left mirrored). Idle
    wears it; the walk and attack rows facing up-right still need ears painted on them.
40. **Elf ears up** (2026-11-24): with the from-behind wording, all seven paintings were right
    (`tries/elf_up_try1{a..g}_painting.png`). Snapped, painting 1's ears came out straight 2-pixel strips with flat
    tops (square tabs); the user picked 7, the tallest and most pointed, as drawn, though the snap lost part of each
    ear's outer outline (rows 20 to 23) and its tips sit 2 rows above the up-right ear's
    (`hero64_doll_ears_up.png`). Idle now has ears in every direction; walk and attack still need their up-right
    and up rows painted.
41. **Elf walk up-right** (2026-11-25): three rounds. The first six (`tries/elf_walk_up-right_try1{a..f}`) drew the
    ear 3 to 4 pixels wide inside its outline against the idle's 1 to 3 ("thicker than the idle version", the user);
    told to halve it, the next nine (`try2{a..i}`) were thin but closed the ear off with a line across its base, or
    shrank it to a sliver ("it has a closing line while the idle one doesn't"); told both, open at the base and
    about 3 pixels past the head, the third round's painting 1 (`try3a`) matched: open in every frame, 4 to 6 skin
    pixels past the head (the idle's 7), no grey specks (`hero64_doll_ears_walk_up-right.png`; up-left mirrored).
    Name the ear's width, its reach and its open base in the prompt from the start.
42. **Elf ears up-right, standing, redone from the walk** (2026-11-25): next to the walk, the standing ear looked
    too thin and a different shape (the user). The walk's ear from frame 3 (whose head matches the standing one
    with no shift and whose outline was closed) was laid on the standing view as ChatGPT drew it, rows 31 and
    below left as the standing view has them; one pixel missing at its lower edge, (27, 41), was filled with
    the ear's skin (filled with the outline colour it made two dark pixels side by side, the user), and one outline
    pixel set beside it, (27, 42), so the outer edge stays closed (the user's pick); the dark pixel left inside the ear beside it, (27, 40), turned skin too (the user).
43. **Elf walk up** (2026-11-25): five paintings (`tries/elf_walk_up_try1{a..e}_painting.png`); 2 and 3 stuck the ears
    out sideways, 4 and 5 drew the head bigger or lower so they lined up 2 to 4 pixels off; painting 1 lined up within a
    pixel, its ears as big as the standing up elf's. ChatGPT drew the head from behind tapering under the ears, narrower
    than the doll's, so the doll's wider head and its small human ears showed past it (the user): where its head is
    narrower the doll's pixels go (`hero64_doll_ears_walk_up_cut.png`, applied by `hero_ears.row_cut` before the ears),
    and only the head is lifted, the doll's own neck kept (ChatGPT's came out muddy, the user). Walk now has ears in
    every direction.
44. **Idle ears grown to the walk's** (2026-11-25): on the map the ears grew as he started walking (the user): past
    the doll's outline walking up 39 to 56 pixels against idle's 26, down 40 to 52 against 26, right 18 to 25 against
    11. The walk's whole ear can't go on the standing views (their heads match the walk's only about 35%; it brought
    the walk head's shading and spoiled the face), so only its pixels outside the standing head, from the walk frame
    nearest it (up 3, down 1, right 4), were laid over the idle ears; stray single pixels left by the walk head's
    outline (one by the chin) dropped (the user). Idle now 51, 53 and 25.
45. **Elf attack up-right** (2026-11-25): five paintings (`tries/elf_attack_up-right_try1{a..e}_painting.png`), all
    lined up within a pixel; painting 1 picked, its ear 11 to 19 pixels past the head (idle 17, walk 13 to 20; the
    others ran to 29), no grey specks (`hero64_doll_ears_attack_up-right.png`; up-left mirrored).
46. **Elf attack up** (2026-11-25): five paintings (`tries/elf_attack_up_try1{a..e}_painting.png`; the fifth on a grey
    haze). Lifted as for walk up, ChatGPT's head tops snapped into jagged steps; taking only what lies outside the doll's
    head kept the human ears showing under the elf ears (the user). So `hero_ears_row.py --band 3`: the doll's head
    kept, only a strip 3 pixels in from each side of it (and what lies outside) taken from ChatGPT's, the doll cut
    where ChatGPT's head is narrower there, so the human ears go and the face, shading and raised arm stay. Painting 3
    (`hero64_doll_ears_attack_up.png`, `_cut.png`), ears 44 to 49 pixels past the head (16 where the arm is up).
47. **Idle up with open ears** (2026-11-25): walk and attack facing up have ears open at the base, as ChatGPT drew them;
    the idle's met the head along the human head's outline and showed the human ear's lines under them. The 16 outline
    pixels between ear and head were given the ear's skin beside them (in `hero64_doll_ears_up.png`), at the user's
    word ("or update the idle version so it doesn't close the ears"). The elf now has ears in every direction for
    idle, walk and attack.
48. **Up: tips and specks** (2026-11-25, the user): opened all the way, the idle's ears lost their points; the inner
    line was put back from the tip down to row 23 and the base below kept open, and the two dark red pixels low on
    the right ear (26 and 27, 43) given the skin beside them. The attack's tips had been cut (the band started three
    rows under the head's top); `--band` now also takes what lies past the head's widest sides up to four rows above
    it. Three snap specks in the doll's own attack up (an orange and two greys, frames 2 and 4, low on the right of
    the head) were given the skin beside them, in the doll and so in the elf.
    In attack up frame 2 the raised arm stands right beside the head, so the band ran along the arm and three pixels
    of the human ear by the head's right edge stayed (26, 40; 27, 39-40); they were given the skin beside them in
    the ears layer (the user). Taking the band from the head's own outline instead wiped the line between head and
    arm, so it wasn't kept.
49. **Attack up redone on the human head** (2026-11-25; the walk up was redone the same way by mistake and put back,
    the user: it "shouldn't be updated"): ChatGPT's head pieces left the edges messy (the
    user: "reuse the head shape of the human attack, and just have the elf ears"). Now every frame is the human walk
    or attack as it is, with the idle up ears laid on by the head (as idle does), and the human's own little ears,
    which sit lower in these frames, smoothed into the head's edge: the edge drawn straight from above them to below
    them, their red inner pixels given the skin beside them (`tools/hero_ears_up_smooth.py`, the user's pick). The
    attack row's ears and cut files are taken from it; ChatGPT's attack up elf paintings are no longer used. The walk
    up keeps item 43's.
50. **Idle up ears tilted outward** (2026-11-25): in a loop the ears facing up pointed straight up; the user wanted
    them more outward. Five ChatGPT paintings tilted at about 45° (`tries/elf_up_try2{a..e}_painting.png`); the
    user picked 5, the broadest: its pixels outside the standing head and over the old ears' spots inside it make
    `hero64_doll_ears_up.png`. The walk and attack up laid on the human head with these ears came out messy (the
    human's little ears sit at the head's widest rows, and smoothing them shaved the head), so they stay as they
    were for now; ChatGPT is to repaint them with these ears (the user). The right ear's foot had a doubled outline
    (28 and 29, 41-42); the inner column was given the skin beside it, as the left ear has (the user).
51. **Walk up with the outward ears** (2026-11-25): five ChatGPT repaints of the walk with the new idle ears
    (`tries/elf_walk_up_try2{a..e}_painting.png`); lifted with `hero_ears_row.py --band 3`, the user picked 2 (35 to 49
    pixels past the head, the idle's 40), as lifted. Putting the rows above and below the ears back to the human
    walk was tried and called a regression (the user), so not kept. The run follows the walk.
    In motion the head hobbled (the user): each frame's lower head was ChatGPT's, 1 to 3 pixels wider or narrower,
    and frames 5 to 8 had 1 to 3 outline gaps. Now the rows from the ears' foot to above the neck come from one frame
    (3, closest to the human head) in every frame, moved with the head, and every gap has its outline pixel
    (`tools/hero_ears_walk_up_steady.py`).
52. **Attack up with the outward ears** (2026-11-25): five ChatGPT repaints of the attack with the new ears
    (`tries/elf_attack_up_try2{a..e}_painting.png`), lifted with `hero_ears_row.py --band 3` and steadied as the walk
    (`hero_ears_walk_up_steady.py attack <row> <out> 6`; where the human frame differs from the reference, the raised
    arm by the head, the frame's own pixels stay). The user picked 4 (30 to 34 pixels past the head; ChatGPT drew
    every attack's ears smaller than the idle's 40). In frame 2 the raised arm hides the right ear, as painted.
    Item 49's attack up is replaced: idle, walk, run and attack facing up now wear the outward ears.
53. **Hair: the style list and Spiky facing down** (2026-11-25). The user's list, 16 styles: short (Spiky, Crop, Buzz
    cut, Messy), medium (Bob, Swept fringe, Curly, Mohawk), long (Long straight, Ponytail, Braids, Bun), fantasy (Twin
    tails, Top knot, Wild mane, Side shave). At the engine move, saves with the old `shoulder` need mapping (to Long
    straight or Bob); the other old ids carry over. ChatGPT paints the doll wearing the style (PROMPTS.md § 6),
    snapped with `hero_snap_walk.py --hair 8` (the hair keeps its own shades) and lifted by `tools/hero_hair.py lift`
    (the saturated ginger and the outline touching it). Spiky down: five paintings
    (`tries/hair_spiky_down_try1{a..e}_painting.png`), the user picked 1 (`hero64_hair_spiky_down.png`: 3 pixels
    above the head, 1 past its sides); every `appearance.json` hair colour recolours it whole. `hero_hair.py wear
    spiky` lays it on every frame by the head fit, as the idle ears are, with the elf's ears back over it
    (`hero64_<human|elf>_spiky_<anim>.png`, `.gif`). Every lifted layer is toned down once (`hero_hair.GRADE`,
    saturation x0.72, brightness x0.9, hue 4° toward red: the user's pick B of three; the bright ginger made every
    hair colour look unnatural). On the elf, from the ears' top row down (the standing view's ears moved with the head,
    `hero_hair.ear_top`), the ears stay over the hair (sideburns crossed them; facing down-right the back hair flapped
    over the near ear).
    Spiky down-right: two paintings (`tries/hair_spiky_down-right_try1{a,b}_painting.png`), the user picked 1
    (`hero64_hair_spiky_down-right.png`; down-left its mirror), worn on every frame the same way.
    Spiky right: four paintings (`tries/hair_spiky_right_try1{a..d}_painting.png`), the user picked 1
    (`hero64_hair_spiky_right.png`; left its mirror). The hair now covers the standing head grown by a pixel
    (`hero_hair.wear_hair`): a walk frame's head stood a pixel past it and its outline showed through the hair.
 Idle wears it; up-left mirrored.

## What has gone wrong before (read before prompting)
- ChatGPT failed the monster test (`../HANDOVER.md`): drew bigger than asked (44 to 48 px for 35), and the
  art was flat (1 to 7 shades a ramp against RD's 14). Ask for the size, measure it, and ask for 5 or more
  shades a ramp.
- It won every building (`../building/HANDOVER.md`) once asked for a 1× PNG plus an exact 8× preview and to
  check itself with code. Without the reminder it sometimes sends only a 1254 px picture.
- "Darker outline" gives one dark line round everything. Ask for a deep shade of each colour it borders.
- Sheets: it drops or repeats frames, swaps left and right limbs, and drifts between frames. One row per
  prompt, the master attached each time, and rerun rather than argue.
- From RD's heroes: without "chibi" they come out grown-up; "short hair" gave a bald elf; "wizard" adds a
  beard; the same prompt doesn't give a matched family, so colours are normalised in code afterwards.
- Never shrink a big picture to the grid: faces turn to mush. Draw on the grid.

## After the pilot: moving the game to 64 (not started)
- One doll: `classes.json`'s races and their `sheets` (three bodies a race, `hero_layers.py`, `armour_fit.py`'s
  `fitted` bodies) become the doll plus layers; an Elf the doll with its ears layer. **Dwarves**: players'
  saves hold Dwarf heroes, so they need a decision before the game moves to v2 (shown as Humans, or kept on
  today's 48-pixel dwarf sheets); not decided.
- Swift: the `?? 48` defaults in `ArtLibrary.swift` and `GearOverlay.swift`, the `/ 48` in `GearArt.swift`
  and `BattleScene.swift`; play idle and attack frames in `Walker` and `BattleActor`, and run by playing the walk faster (no run sheet, the user, 2026-11-24).
- Tools: `F = 48` in `hero_layers.py`, `wear_art.py`, `armour_fit.py`, `worn_marks.py`.
- `art/eyes.json` boxes, `docs/sprite-acceptance.md`'s 48-pixel rules, the camera zoom.
- Eight directions: `Direction` (`TalesOfDorlune/World/Geometry.swift`, today down, left, right, up) grows
  the four diagonals; `init(_ vector:)` picks the nearest of eight, keeping today's stickiness near each
  boundary so a sprite doesn't flicker; `SheetLayout` reads eight rows; `GearArt`'s front and side poses and
  `Walker`'s side checks (`isHorizontal`) learn the diagonals; battle's side-on `profile` uses right and left.

## Sources
- LPC: https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator ,
  https://opengameart.org/comment/107223
- RPG Maker MZ: https://itch.io/t/2756278/rpg-maker-mz ,
  https://clockworkraven.itch.io/character-generator-for-rpg-maker-mv
- Stardew Valley: https://stardewvalleywiki.com/Special:MobileDiff/79916...140060 ,
  https://seliel-the-shaper.itch.io/farmer-base
- Tibia: https://otland.net/threads/new-tibia-outfitter-php.239183/ ,
  https://tibia.fandom.com/wiki/Ranger_Outfits
- Ragnarok Online: https://ragnarokresearchlab.github.io/file-formats/act
- MapleStory: https://deepwiki.com/crrio/maplestory.io/3.2-avatar-factory
- Chibi proportions: https://tips.clip-studio.com/en-us/articles/4863 ,
  https://pixeljoint.com/forum/printer_friendly_posts.asp?TID=26937
- ChatGPT image limits and workflow: https://developers.openai.com/api/reference/resources/images/methods/generate.md ,
  https://community.openai.com/t/developing-sprite-sheets-with-gpt-image-2/1379831 ,
  https://dev.to/jenissimo/how-to-tame-your-ai-pixel-art-3pk5
- Snapping tools: https://pypi.org/project/unfake/ , https://pypi.org/project/proper-pixel-art/
- Not verified: frame sizes of Sea of Stars, Eastward, Chained Echoes, CrossCode, Moonlighter, Children of
  Morta, Graveyard Keeper and Fairyland Online itself (none found).
