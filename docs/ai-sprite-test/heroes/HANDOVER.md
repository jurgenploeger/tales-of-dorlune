# Hero sprites v2: 64-pixel bodies drawn by ChatGPT

Goal: redraw the nine hero bodies (Human, Elf, Dwarf × Male, Female, Other) at a size where armour, gloves,
boots, necklaces, belts, hair and held weapons read, with idle, walk, run and attack in eight directions.
First as a blank canvas: a smooth doll body in plain underwear, nothing else. Everything a hero wears or
holds is a layer drawn over it later.

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
| Human Male / Female / Other | 46 / 44 / 45 | 19 | 12 / 11 / 12 | 4 | 11 / 10 / 11 | 6 / 5 / 6 |
| Elf Male / Female / Other (ears extra) | 46 / 44 / 45 | 19 | 11 / 10 / 11 | 4 | 12 / 11 / 11 | 5 |
| Dwarf Male / Female / Other | 38 / 36 / 37 | 17 / 16 / 17 | 14 / 13 / 13 | 5 | 7 | 7 |

Legs are from the shorts' hem to the soles. `tools/hero_template.py` `SPEC` holds these; the guides draw them (blue: head top, cyan: chin, violet ticks: the chest's width, orange: the shorts' hem, green: feet).

## The sheets
One PNG per body per animation. Columns are frames, rows are **eight directions, clockwise from up**: up,
up-right, right, down-right, down, down-left, left, up-left (the user, 2026-11-23). The world is isometric, so
walking along a row of cells moves diagonally on screen: the diagonals are the views seen most.

| Animation | Frames | Sheet | Notes |
|---|---|---|---|
| idle | 4 | 256 × 512 | a breath: chest and head down a pixel and back, arms settle; blinks stay in code |
| walk | 8 | 512 × 512 | after the user's reference video: contact, lift, pass, reach, twice; 83 ms a frame; the planted foot on row 60 |
| run | 6 | 384 × 512 | leaning forward, longer stride, one airborne frame a pixel or two up |
| attack | 6 | 384 × 512 | ready, wind-up, strike, follow-through, recover, ready; empty hand closed as a grip |

File names: `hero64_<race>_<gender>_<anim>.png`, for example `hero64_human_male_walk.png`.

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
`GearArt.posed` keeps today). This avoids asking ChatGPT for every weapon in every frame (9 bodies × 22
frames × 8 directions). Draw the 0°, 45° and 90° views; 135° to 315° are those turned in whole quarter
turns or mirrored where the weapon is symmetric, and drawn by hand where it isn't (a bow, a curved blade).

## The workflow
Pilot **Human Male** end to end before the other eight. Don't start a second body until the pilot passes.

1. **Set up a ChatGPT project** with `PROMPTS.md` § Project instructions as its instructions and these files:
   `docs/ai-sprite-test/style-reference.png`, `templates/compare_48_64.png`, the body's guide
   (`templates/guide_<body>_8x.png`).
2. **Master frame:** prompt § Master base body for the body. Down-facing, standing, frame 1. Iterate until it
   passes the checks below and you like it. This frame is the character from now on: attach it to every
   later prompt in this body's chat.
3. **Turnaround:** the same pose facing down-right, right, up-right and up (§ Turnaround). Check they match the master in
   height, proportions, underwear and colours before any animation.
4. **Animations, one direction row per prompt:** § Animation row, with `templates/row_<body>_<anim>_8x.png`
   attached. Order: idle, walk, run, attack; each in down, down-right, right, up-right, up.
5. **Snap and check** every PNG that comes back, even when ChatGPT says it checked:
   `python3 tools/ai_sprite_eval.py <frame.png> --canvas 64 --height <body height> --colours 32 --kind creature --out <out>`
   (frames are snapped one at a time and centred, not yet on row 60; a sheet mode that cuts a row into
   frames and keeps the feet row is a follow-up). Anything off: § Fix prompts, one or two
   fixes at a time, quoting the failing rule.
6. **Assemble** the rows into `hero64_<body>_<anim>.png` (mirror right into left) and look at it at 1× and
   4× beside today's body on grass and on the dark battle field.
7. **Then the other eight bodies**, each in its own chat, each starting from its own master frame. Attach the
   approved Human Male master as the style reference so all nine look like one family.
8. **Then layers:** hair (each of the nine styles in `appearance.json`), then one armour set, gloves,
   boots, necklace, belt, cape, hat; then weapons.

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
- Underwear plain and fitted: shorts on every body, a simple band top on Female and Other, one flat neutral
  colour (warm grey). No anatomy detail.
- Dwarves clearly shorter and broader than humans (the RD lesson: "big head" pulled them to human height).
- Elves: the ears are what sets them apart; same body as the human otherwise.

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
8. **Try 8, the master** (approved by the user, 2026-11-23: "Now this looks great"; `hero64_human_male_master.png`):
   ChatGPT sampled its own painting with code again, our evened copy attached as the target, and drew the smile
   back. 46 × 21, feet on row 60, columns 22 to 42, 20 colours, alpha clean, the 8× exact, and
   `hero_symmetry.py check` finds no difference. What worked, for every view after it: ChatGPT paints, makes
   the 1× from its painting with code ("sample, don't redraw"), we check it, and its fixes are asked for with a
   corrected file attached as the target.
   Its brows then read as a bow (the user): arches 4 pixels wide. Three variants were drawn in code (flat,
   a soft slope, a short dash); the user picked flat, 3 pixels on row 23, columns 28 to 30 and 34 to 36
   (`tries/master_brows_a.png`, the target for ChatGPT's change).
9. **Try 9, the master with flat brows** (`hero64_human_male_master.png` since 2026-11-23): ChatGPT's change, sampled
   with code, matches the target pixel for pixel; symmetric, 46 px, 20 colours.
10. **Down-right** (`hero64_human_male_down-right.png`, approved by the user): the first turnaround view, first try.
    46 px, feet on row 60, the master's box (columns 22 to 42), only the master's 20 colours. Down-left is it
    mirrored (`hero_template.py` `approved()` mirrors any left view with no file of its own).
11. **Right** (`hero64_human_male_right.png`, approved by the user, first try): 46 px, feet on row 60, columns
    23 to 41, the master's 20 colours. The near arm hangs at the back edge of the torso, so from the side the
    body reads slim (about 9 px); kept as drawn. Left is it mirrored.
12. **Up-right** (`hero64_human_male_up-right.png`, approved by the user, first try): 46 px, feet on row 60,
    columns 23 to 41, the master's 20 colours; the ear's inside and a blush pixel show at the face's edge, no
    eye. Up-left is it mirrored.
13. **Up** (`hero64_human_male_up.png`, first try): symmetric (`hero_symmetry.py check` 0), the master's own
    silhouette pixel for pixel, its 20 colours. The standing turnaround is complete: all eight directions,
    five drawn and three mirrored (`hero64_human_male_turnaround.png`). Each view took one try once the master
    and the earlier views were attached and ChatGPT made the 1× from its painting with code.
14. **Idle** (`hero64_human_male_idle.png`): ChatGPT drew the down row (`hero64_human_male_idle_down.png`: frames 1
    and 4 the master exactly, 2 and 3 the upper body and the hands a pixel lower, symmetric). The other rows
    were first made in code by shifting the approved views (`tools/hero_idle.py` `breathe`), but that left
    chopped pixels where moved and still columns met (the user): every row is drawn by ChatGPT instead, the
    tool only assembles them (a left row its right twin mirrored). Done 2026-11-23: down, down-right, right, up-right
    and up drawn (each frames 1 and 4 the approved view exactly, 2 and 3 a pixel lower above the legs, feet on
    row 60, the master's colours; up symmetric), the left three mirrored (`hero64_human_male_idle.gif`).
15. **Walk down** (`hero64_human_male_walk_down.png`, third try). Try 1 was paintings only, with mitts for
    hands, elbows bent and the knee lifted like a march. Try 2 (`tries/walk_down_try2.png`) had straight arms
    and clean hands, but the legs merged (4 px each, no gap), the lifted leg stopped in a flat bar with no
    foot, and it held only two poses. Try 3 passed: the master's own legs (frames 1 and 4 are the master from
    row 50 down), the foot up 2 then 1 px with its whole shape, a 1 px bob, the opposite hand 1 px lower, the
    head the master's in every frame, the master's colours. What made it work: naming the cycle frame by frame
    and saying "the master's own legs". `tools/hero_idle.py human_male walk --gif` assembles the sheet and
    `hero64_human_male_walk.gif`.
16. **Walk down-right** (`hero64_human_male_walk_down-right.png`, after tries 1 to 9 in `tries/`). ChatGPT kept
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
    user preferred the first (`tries/walk8_down-right_try1_*`), now `hero64_human_male_walk_down-right.png`. The
    6-frame walk down and down-right went to `tries/walk6_*_approved.png`; walk down is to be redone the new way.

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
- Swift: the `?? 48` defaults in `ArtLibrary.swift` and `GearOverlay.swift`, the `/ 48` in `GearArt.swift`
  and `BattleScene.swift`; play idle, run and attack frames in `Walker` and `BattleActor`.
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
