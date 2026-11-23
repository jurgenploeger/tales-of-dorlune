# Hero sprites v2: 64-pixel bodies drawn by ChatGPT

Goal: redraw the nine hero bodies (Human, Elf, Dwarf × Male, Female, Other) at a size where armour, gloves,
boots, necklaces, belts, hair and held weapons read, with idle, walk, run and attack in all four directions.
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

## Size decision: 64 × 64 frames, body about 46 px tall
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

Chosen (the user, 2026-11-23):
- Frame 64 × 64. The lowest foot pixel on **row 60**, the body centred on **x 32**.
- **One art pixel stays one point.** The hero gets about 40% taller on screen next to the world, and the
  camera zoom is rebalanced when the engine moves to 64.
- Heights, head about 2.5 heads:

| Body | Height | Head |
|---|---|---|
| Human Male / Female / Other | 46 / 44 / 45 px | 18 px |
| Elf Male / Female / Other | 47 / 45 / 46 px (ears extra) | 18 px |
| Dwarf Male / Female / Other | 38 / 36 / 37 px, broader | 17 / 16 / 17 px |

`tools/hero_template.py` `SPEC` holds these; the guides draw them (blue: head top, cyan: chin, green: feet).

## The sheets
One PNG per body per animation. Columns are frames, rows are directions in the engine's order:
**up, right, down, left**.

| Animation | Frames | Sheet | Notes |
|---|---|---|---|
| idle | 4 | 256 × 256 | a breath: chest and head down a pixel and back, arms settle; blinks stay in code |
| walk | 6 | 384 × 256 | contact, down, pass, contact, down, pass; feet on row 60 at contact |
| run | 6 | 384 × 256 | leaning forward, longer stride, one airborne frame a pixel or two up |
| attack | 6 | 384 × 256 | ready, wind-up, strike, follow-through, recover, ready; empty hand closed as a grip |

File names: `hero64_<race>_<gender>_<anim>.png`, for example `hero64_human_male_walk.png`.

- ChatGPT draws **down, up and right**. **Left is the right row mirrored** for the base body and hair. Only
  layers that differ per side (a weapon hand, a one-shouldered cape) get a left row of their own.
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
frames × 4 directions). Draw the 0°, 45° and 90° views; 135° to 315° are those turned in whole quarter
turns or mirrored where the weapon is symmetric, and drawn by hand where it isn't (a bow, a curved blade).

## The workflow
Pilot **Human Male** end to end before the other eight. Don't start a second body until the pilot passes.

1. **Set up a ChatGPT project** with `PROMPTS.md` § Project instructions as its instructions and these files:
   `docs/ai-sprite-test/style-reference.png`, `templates/compare_48_64.png`, the body's guide
   (`templates/guide_<body>_8x.png`).
2. **Master frame:** prompt § Master base body for the body. Down-facing, standing, frame 1. Iterate until it
   passes the checks below and you like it. This frame is the character from now on: attach it to every
   later prompt in this body's chat.
3. **Turnaround:** the same pose facing up and facing right (§ Turnaround). Check they match the master in
   height, proportions, underwear and colours before any animation.
4. **Animations, one direction row per prompt:** § Animation row, with `templates/row_<body>_<anim>_8x.png`
   attached. Order: idle, walk, run, attack; down first, then up, then right.
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
- Chibi: head about 2/5 of the height, big eyes with a white catchlight. Two eyes from the front, one from
  the side, none from behind.
- The same character in every frame: height within 1 px, head within 1 to 2 px, underwear the same shape
  and colour, skin the same ramp. Side and back views match the front.
- Underwear plain and fitted: shorts on every body, a simple band top on Female and Other, one flat neutral
  colour (warm grey). No anatomy detail.
- Dwarves clearly shorter and broader than humans (the RD lesson: "big head" pulled them to human height).
- Elves: the ears are what sets them apart; same body as the human otherwise.

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
