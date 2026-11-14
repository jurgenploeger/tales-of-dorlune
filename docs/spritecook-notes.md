# SpriteCook's blog: what Tales of Dorlune can learn from it

Read 2026-11-14: every article on https://www.spritecook.ai/blog, 53 of them. The index has no further
pages, and the site's sitemap lists the same 53. Each was fetched in full and read. Dates are as the
articles give them: published, and updated where that's different.

Already taken before this read, so only what's new in them is noted here: the wind article
(`tools/wind_art.py`, `Wind.swift`), the shoreline article (`ContinentScene.shallows`,
`tools/shore_art.py`), the normal-map article (`LampLight.swift`, `tools/normal_art.py`) and the
inventory article (rarity on the slots, 0.9.86; the loot reveal, `LootGrid`, 2026-11-13).

Nothing here is built yet. The proposals at the end wait for the user's pick.

A note on fit. SpriteCook writes for Godot and Unity games, mostly platformers and top-down action
games, and sells AI art generation. Tales of Dorlune is a Fairyland Online tribute on SpriteKit with
turn-based battles and Retro Diffusion art. About a quarter of the articles carry something we can use.
The rest are product news, engine walkthroughs or advice for a kind of game this isn't. They're listed
anyway, briefly, so nobody has to read them again.

## Contents

1. [Game techniques](#game-techniques) (10)
2. [Already taken: what's new in them](#already-taken-whats-new-in-them) (4)
3. [Making art with AI](#making-art-with-ai) (23)
4. [Engine walkthroughs](#engine-walkthroughs) (4)
5. [Business, news and plugins](#business-news-and-plugins) (12)
6. [Proposals](#proposals): rules, skills, features ranked

## Game techniques

### Hit stop, hit flash, knockback and screen shake

https://www.spritecook.ai/blog/hit-stop-hit-flash-knockback-screen-shake (2026-11-12)

**Summary.** Eight small reactions make a hit feel heavy, all started from one call on the tick the
blow lands, each a counter in fixed ticks:

- **Hit stop:** both fighters freeze 5 ticks at 60 a second (0.08 s), 9 on a killing blow. Only the
  two fighters freeze; the flash, spark and shake run on. A freeze of everything reads as lag.
- **Hit flash:** the target is pure white for 2 frames, its shape kept. A tint can't do it: a
  multiply leaves dark pixels dark. It takes a shader that mixes toward white.
- **Knockback:** 12 px over the 8 ticks after the freeze, cubic ease-out, a third of it on the
  first tick. Never in one jump.
- **Screen shake:** 3 px settling over 10 ticks, whole pixels, side to side (3, -2, 2, -1, 1, -1, 0),
  added to the camera's offset and back to exactly 0.
- Particles out of the cut after the freeze, a four-ray impact spark, a slash trail along the last
  100 degrees of the swing, and a damage number that pops up with a hop and blinks out.
- **Killing blow:** a longer freeze, more particles, time at 0.3 for 12 ticks.
- Pitfalls: no squash and stretch by scaling (it breaks the pixel grid); a fast combo gets shorter
  freezes than a heavy blow; two hits in one freeze need a counter per fighter.

**Here.** Partly. `BattleScene.impact` already gives every hit a fireball and a damage number
(`Effects.damageBurst`), a red flash (`Nodes.flash`: `colorize` to red at 0.8, back over 0.15 s) and a
jiggle of 6 points; `attack` shakes the field only on a dwarf's blow (`shake(strength: 4)`). What's
missing is the hit stop: both fighters carry on through the blow. The flash leans the sprite red
through `colorize`, which may behave as the article's tint does (dark outlines stay dark); that needs a
look on a Mac. The jiggle is a jump of 6 points in 0.04 s and back, which the article calls the glitchy
version of knockback.

**What it would take.** A small change in `BattleScene.impact` and `attack`: hold both actors' actions
for 5 frames (`isPaused` on the two nodes, or `speed = 0`) while the effects run; a white flash as an
`SKShader` that mixes the texture toward white and keeps alpha; the jiggle as an eased push away from
the attacker and back; the shake on criticals and killing blows for everyone, not dwarves only, in
whole points. Time it against `setPace` (the battle speed setting) and turn the shake off under Reduce
Motion. **For players:** every hit lands with a beat of weight, the cheapest thing on this list that
changes how fights feel. It doesn't change Fairyland Online's turn-based system, only how a blow
looks. Worth doing.

### Keeping the player visible behind trees and walls

https://www.spritecook.ai/blog/2d-see-through-fade-dither-cutout-silhouette (2026-11-12)

**Summary.** Four fixes when a canopy hides the player: fade it (the only one that blends colours: over
3,000 colours in the test scene that are in no sprite), dither a window open round the player with a
4×4 Bayer pattern, cut a hard hole, or draw the player's silhouette in one flat colour over the
scenery, clipped to it. Switch on only when the feet are behind the tree's foot and 3 of 12 points on
the player are under its opaque pixels (a box test switches on half a second early), easing over 0.2 s.
Dither a window, never the whole sprite: a mesh over a whole tree flickers the player behind it.

**Here.** Differently, on purpose. `SeeThrough.swift` keeps everyone the game sets down out from behind
tall scenery, and the user ruled out fading: "The buildings/scenery shouldn't fade out when something
is behind it, I just meant that any characters in the game shouldn't be hidden by it, so their
placement should be different". You can still walk behind a house yourself and be hidden. Caves show a
name tag where a hidden walker is (`CaveWalls`).

**What it would take.** Only the silhouette fits that ruling, since it leaves the scenery alone: a
flat-colour copy of the hero, clipped to the building in front (an `SKCropNode` with the building's
texture as its mask). **For players:** you'd never lose your hero behind a house or a big tree. It's a
small comfort, and the user's word on scenery is recent, so it's a question for the user, not a plan.

### 2D shadowcasting for torchlight, fog of war and line of sight

https://www.spritecook.ai/blog/2d-shadowcasting-torchlight-fog-of-war (2026-11-07)

**Summary.** Recursive shadowcasting (Björn Bergström's, a stack in place of recursion) returns every
cell a point can see on a grid of walls. Times a falloff in 6 flat bands, it's a torch that stops at
walls; ORed into a second grid, it's fog of war (seen before: dim grey-blue; never seen: black); cast
from an enemy, it's line of sight. Cast per pixel when the art isn't on the tile grid, light the wall
tops a few pixels deep, move the light out of a wall before casting, and save the explored grid.

**Here.** Half of it. A cave's light (`Lantern.swift`) is a plain circle round the hero, 190 points
unless the map says otherwise (`ambience.darkness.radius`), and it shines through the rock. Fog of war
is there already: the cave's map fills in as you explore (`session.explored`, `WorldScene.fog`,
`MapOverlay`), but from a circle round the lantern (`lantern.radius * 0.85`), so it reveals rooms on
the far side of a wall. The cave's walls are a grid already (`CaveWalls`, cells of `WorldMap`), so the
walls array exists.

**What it would take.** Medium: shadowcast on the cave's cells (or at a finer grid matching
`CaveWalls`' cut corners) whenever the hero enters a new cell, and draw the veil from the result in
bands instead of the soft round hole, and fill the cave's map in from the same result instead of the
circle. **For players:** caves that feel like caves, where a turn round a corner hides what's
behind it. Fairyland Online's caves didn't do this as far as we know; the darkness is our own already,
so it's an improvement to our invention, not a departure. Mid-value, caves only.

### Atmospheric perspective for 2D parallax backgrounds

https://www.spritecook.ai/blog/2d-parallax-background-atmospheric-perspective (2026-11-08)

**Summary.** Each parallax layer blends toward the sky directly behind each pixel (the sky's colour on
that row), more the slower it scrolls (80% for far peaks, 4% for the trees right behind the player,
none for the ground), plus extra haze at the base of each range. A blend, never lower opacity (ghosts)
or a multiply (keeps the dark shadows). Prompt generated layers with "no haze, no fog, no blue tint"
and set the depth in the engine.

**Here.** Doesn't apply. The world is seen from above with no parallax layers. `Lighting` lays a
distance haze at the top of the screen, and the title and loading sky (`TalesOfDorluneSky`) is
painted. Nothing to do. One idea to keep: if a backdrop with depth is ever made (a story scene, a store
slide), blend toward the sky behind each pixel, not toward one colour.

### How to make pixel art look like it's on a CRT

https://www.spritecook.ai/blog/crt-shader-pixel-art (2026-11-10)

**Summary.** One-pass shader: sideways-only blur with colour blurred further than brightness (NTSC),
scanlines that fatten on bright pixels, a phosphor mask, glow and curvature. It needs the game drawn
at native size and scaled by a whole number, at least 4×. Explains why 90s artists dithered in
checkerboards (the blur melted them). On phones the mask mostly darkens; drop it first.

**Here.** Doesn't, and shouldn't. Fairyland Online was a 2007 PC game played on LCD monitors, so a CRT
look isn't faithful to it; the game doesn't render at a fixed native size either (pinch zoom). Skip.

### Coyote time, jump buffering and corner correction

https://www.spritecook.ai/blog/coyote-time-jump-buffering-corner-correction (2026-11-12)

**Summary.** Three forgiveness tricks for platformer jumps: still allow a jump 0.1 s after leaving a
ledge, remember a jump pressed 0.1 s early, and lift the body up to 4 px over a ledge it nearly
cleared (Celeste's numbers).

**Here.** Doesn't apply: there's no jumping. Nothing to do.

### How to set up a pixel art game so it renders pixel perfect

https://www.spritecook.ai/blog/pixel-perfect-pixel-art-game-settings (2026-11-12)

**Summary.** Three ways pixel art goes wrong on screen: blurry (linear filtering, mipmaps, lossy
compression), lumpy (a scale that isn't a whole number, so some pixels are 5 wide and some 6, and they
crawl when the camera moves) and pasted together (mixels: one sprite's pixels a different size from
its neighbours'). Five more rules: snap to whole pixels, no runtime rotation, pixel fonts at native
size, effects on the same grid. A `pixel_size` function finds how many image pixels one art pixel
covers (the gcd of every run of equal pixels).

**Here.** Partly, and differently by design.

- Snapping: the camera snaps to whole screen pixels (`WorldScene.updateCamera`). Sprites are nearest
  filtered; the deliberate exceptions are soft textures (glows, shadows, the shallows field) and art
  over 64 pixels shown smoothed (`IconTile`).
- Whole-number scale: no. Pinch zoom runs continuously from 0.85 to 2.2 (`WorldScene.zoomRange`), so
  art pixels are rarely a whole number of screen pixels. The art is small next to a 3× phone screen,
  so the lumps are a screen pixel at most; the crawl when the camera moves is what would show.
- Mixels: measured here. All 1,609 non-empty PNGs in `art/sprites/` are at their own size (the
  article's `pixel_size` is 1 for every one; the 9 that aren't are empty layers). But size on screen is
  set in code: ground tiles are 32 pixels in 44-point cells (1.375 points an art pixel), a walk sheet's
  48-pixel frame is 48 points times the asset's scale (1 point an art pixel unless scaled). So the
  ground's pixels are about a third bigger than the hero's. `docs/pixel-style.md` already caught this
  once (the butterflies, 3× everyone else's). Nobody has measured it across the game.

**What it would take.** A measuring tool first (small): for every sprite as the game draws it, points
per art pixel, grouped by kind, outliers listed. Then a decision on zoom: snapping the pinch to steps
where art pixels land on whole screen pixels would steady the picture. That one changes how the pinch
feels, so it's for the user to try. **For players:** a steadier, more coherent picture. Low drama,
real polish.

### Wang tiles for pixel art, explained

https://www.spritecook.ai/blog/wang-tiles-explained (2026-11-03)

**Summary.** One repeated tile shows a grid however good it is, and random variants help less than
expected: if any variant can sit beside any other, they all share the same pixels along their edges,
and that strip repeats along every tile edge. Edge Wang tiles: each edge is colour 0 or 1 (top/bottom
and left/right separately), 16 tiles cover every combination, exactly one fits any cell. Tile index =
top + 2·right + 4·bottom + 8·left. For a chunked world, hash each edge's colour from the world seed
and its position, so chunks agree without sharing data. Cut the 16 from one seamless texture: two
source spots per direction for the edge strips (from the plainest part), a different spot for each
middle, stitched along a minimum error boundary. Keep loud features out of tiles; place them as
decoration.

**Here.** Differently, and the article names our approach's weakness. `ArtLibrary.tileVariant` makes
four versions of each ground tile: the texture shifted and mirrored "inside a soft frame of the
original, so they share its edges", picked per cell by `GroundTiles`. That's the shared edge strip the
article describes, so the frame of the original repeats along every cell edge. The frame is also
cross-faded into the middle (`variantPixels`), which mixes colours, so the versions hold colours the
tile never had.

**What it would take.** Medium. In `ArtLibrary`, build 16 versions per ground tile instead of 4: each
edge strip cut from one of two spots of the (seamless, toroidal) tile, a middle from another, joined
along the least-difference path, no cross-fade. In `GroundTiles`, pick the version from four edge
colours hashed from the world seed and the edge's world position (the continent already streams in
chunks, which is exactly the article's case). Everything stays RD's own pixels, rearranged, as the
four versions already are; ask the user before treating that as within the rule. `tools/palette_preview.py`
can mirror it to judge without a Mac. **For players:** every field, desert and snowfield stops showing
its 44-point grid when you look at it zoomed out, on every screen of the game. High value for the
effort.

### Dual-grid tilesets, explained

https://www.spritecook.ai/blog/dual-grid-tilesets-explained (2026-06-12, updated 2026-11-03)

**Summary.** Draw the tiles on a second grid offset half a cell, so each tile covers four painted cells:
4 yes/no corners, 16 cases, 15 tiles (one is empty), and inner corners and diagonals come free, where
a single grid needs 47 blob tiles. One lookup table from the 4-bit mask to the atlas.

**Here.** Differently. Transitions between ground, roads, ponds and the land next door are drawn per
cell from its neighbours (`ArtLibrary.organicTile`: soft roads, shorelines, accent patches as blobs),
and cave walls by marching squares (`CaveWalls`), which is the dual grid's idea in another form.
Nothing to do; the current transitions are soft and organic, which a 15-piece hard-edged set wouldn't
be.

### The 15-piece autotile tileset, explained

https://www.spritecook.ai/blog/autotile-tilesets-explained (2026-06-11, updated 2026-11-03)

**Summary.** The short companion to the dual-grid post: why 15 pieces, what the 17- and 47-piece
sheets are, and that engines (Godot terrains, Unity rule tiles, Tiled terrain sets) pick the piece.

**Here.** Same as above. Nothing to do.

## Already taken: what's new in them

### How to make pixel art trees move in the wind

https://www.spritecook.ai/blog/pixel-art-trees-wind-animation (2026-11-10, updated 2026-11-13)

Updated since we took it. Checked against `tools/wind_art.py`: clumps, the inside layer, travelling
waves, gusts, pines by their branch layers (`kind="pine"`) and trunks that bend (`push`, springing
back) are all in. One pitfall worth writing down where the idle animations are (see Proposals): "a
small constant movement on every clump looks like jitter once the gust has gone. Let the loop shrink to
zero in still air."

### 2D water shorelines with a distance field

https://www.spritecook.ai/blog/2d-water-shoreline-distance-field (2026-11-05)

Nothing new beyond what's built: per pixel not per tile, noise so bands don't trace the coast, Nearest
sampling, and each chunk baked with its neighbours' land (`ContinentScene.shallowField`).

### Normal maps for pixel art from the sprite's outline

https://www.spritecook.ai/blog/pixel-art-normal-maps-from-outline (2026-11-08)

Nothing new: the 1-pixel pad, hard edges only, a smaller bevel for boxy things, the light well above
the bevel and stepped light are all in `LampLight.swift`'s notes.

### Pixel art inventory UI and loot window

https://www.spritecook.ai/blog/pixel-art-inventory-ui-loot-window (2026-11-10)

Taken twice now (rarity on slots, `LootGrid`). Left over: **the chest shakes once, then opens**. A
treasure chest on the map opens with a toast today (`GameCoordinator.openChest`); a one-shake wobble
before the lid goes up is a small, cheap touch (see Proposals). And from its pitfalls: never scale a
window open, fade it in at its real size with a few pixels of movement; a glow behind a window is an
ellipse from its centre, not a blurred rectangle. Worth checking `LootGrid`'s legendary glow against
the second.

## Making art with AI

Our art comes from Retro Diffusion and from code (CLAUDE.md, `.claude/skills/sprite-creation`).
SpriteCook's articles are about its own generator, but a few lessons carry over.

### Why AI sometimes can't match your sprite's resolution

https://www.spritecook.ai/blog/why-ai-cant-match-pixel-art-resolution (2026-08-26)

**Summary.** Image models draw pictures of pixels at about 1024 px; a pixel grid is detected and the
picture shrunk to it. A new pose (a back view for a walk) sometimes comes back on a coarser grid than
the sprite, and every animation frame inherits it. SpriteCook checks every prep pose's true grid against
the character's and fails the run rather than ship mushy frames. Retrying the same character rarely
helps; more internal detail pins the grid.

**Here.** The lesson matches what `docs/sprite-acceptance.md` found the hard way (the RD inpainting
pilot, 2026-10-19: faces muddy, side and back views not matching). **Proposal:** a pixel-size check in
`sprite_check.py check --new` (the gcd of runs, as the article gives it), so a sprite or frame that
came back upscaled, or on another grid than its neighbours, fails the gate. Every shipped sprite passes
it today, so it costs nothing to add.

### Turning Nano Banana 2 AI images into actual pixel art

https://www.spritecook.ai/blog/nanobanana-pixel-art-for-games (2026-03-19)

**Summary.** General image models paint pixel art off any grid (some "pixels" 6 wide, some 7); detect
the grid and resample. Prompt for the design, fix the grid after; ask for the view ("side view") or
the model picks 3/4.

**Here.** RD draws on a real grid, so this is SpriteCook's problem, not ours. The prompt tip (always
name the view) is worth checking against `.claude/skills/sprite-creation/references/`.

### Pixel art with Nano Banana 2 Lite

https://www.spritecook.ai/blog/nano-banana-2-lite-fast-pixel-art (2026-06-30, updated 2026-11-03)

Product news: a faster, cheaper model for first passes. Doesn't apply.

### GPT-Image-2 vs Nano Banana 2 for game art

https://www.spritecook.ai/blog/gpt-image-2-comparison (2026-04-22)

Comparison with one line worth keeping: a reasoning image model is the first the author trusts with UI
mockups (layout, counted objects). Our UI is SwiftUI drawn in code from the Figma brand file
(`game-ui` skill), so it doesn't apply.

### Pixel Engine Image, pixel art at the exact size you pick

https://www.spritecook.ai/blog/pixel-engine-image (2026-10-19)

**Summary.** A model that draws on a real grid at 16 to 128 px, background removed, 6 credits, text
only (no references, no edits).

**Here.** RD already gives us that. Text only means it couldn't match our style; no reason to add a
second paid source.

### Pixel Engine v1.5, a new model for sprite animation

https://www.spritecook.ai/blog/pixel-engine-v1-5-sprite-animation-model (2026-08-31)

**Summary.** Better at specific motions, any frame count 3 to 16; steadier but stiffer (it moves the
pancake, not the chef).

**Here.** Our animation is code on RD frames (walk sheets, `IdleMotion`, `EyeBlink`, wind). The
`sprite-idle-animation` skill already records why image-to-video models don't fit sprites this size.
Nothing to do.

### How to nail tiny pixel art animations

https://www.spritecook.ai/blog/tiny-pixel-art-animations (2026-04-14)

**Summary.** At 16 to 32 px, give the model a checkerboard at the target grid as a style reference; it
works as a ruler and the output snaps to it.

**Here.** Our tiny things (critters, butterflies) are drawn in code (`critter_art.py`). If RD is ever
asked for something that small with a reference image, the checkerboard is the trick to try, after a
dry run and the user's OK.

### Smart outline repair for AI pixel art sprites

https://www.spritecook.ai/blog/smart-outline-repair (2026-10-19)

**Summary.** Background removal eats outline pixels where a dark outline meets a light background;
repair puts them back in the sprite's own colours, closes small gaps, cleans leftover background off
the edge, and never adds an outline where there wasn't one or closes a gap that's part of the drawing.
Tested on about 2,000 sprites before it went on.

**Here.** `sprite_check.py` measures how dark an outline is (median and share), not whether it's
closed. `tools/rd_fixes.py` fixes known bad pixels one by one. **Proposal:** an outline-gap report
in `sprite_check.py`: an edge pixel that's light while the edge pixels either side of it are dark.
Report only, run over every shipped sprite first, as SpriteCook did, before it gates anything; any fix
goes through `rd_fixes.py` with the user's OK, as RD art is never redrawn.

### How to fix and recolor pixel art with an AI agent

https://www.spritecook.ai/blog/edit-pixel-art-with-ai (2026-10-08)

**Summary.** An agent that edits pixels by writing code, changing only what was asked and checking the
result against the original; good at outlines, recolours, every frame of an animation at once; bad at
anything new (a hat, a pose). One change per request.

**Here.** That's how this repo already works: `derive` recolours, `rd_fixes.py` (each fix lists the
pixels and the colours they must have first), `armour_views.py`, `dye_art.py`. It confirms the rule:
new shapes come from RD or a drawing, fixes from code. Nothing to do.

### The new SpriteCook Pixel Editor

https://www.spritecook.ai/blog/pixel-editor (2026-10-26)

Product news (layers, onion skin, Aseprite export). One feature to note: **align frames**, lining
every frame up by an anchor like the feet, because generated animations shift a pixel or two between
frames. Our walk sheets are RD's; worth a check that their feet sit on the same row in every frame
(`tools/gear_preview.py` would show it).

### How to keep your game art consistent with AI

https://www.spritecook.ai/blog/consistent-game-art-with-ai (2026-06-20)

**Summary.** Theme, style, reference images of your best results, and saved presets so art made months
later still matches; let a model check a scene for what's inconsistent.

**Here.** Done our way: `docs/pixel-style.md` (measured bands, `pixel_style.py check`), the
`sprite-creation` skill's review beside neighbours, and `art/assets.json`'s `request` keeping every RD
prompt. Nothing to do.

### How to make a game when you can't draw

https://www.spritecook.ai/blog/make-a-game-when-you-cant-draw (2026-06-16, updated 2026-11-03)

The founder's story and the same consistency system, plus store policy (also in the next section).
One line worth keeping: the check that separates good from slop is looking at it yourself, every
asset, against the rest of the game. That's the `review` step in `sprite-creation` already.

### Generate game UI with AI, from concept to components

https://www.spritecook.ai/blog/generate-game-ui-with-ai (2026-08-11)

**Summary.** Generate the whole screen as one concept first, then ask for every component with the
concept as reference, on transparent; never crop the concept itself. Nine-slice anything that stretches.
Hand the concept, the pieces and their nine-slice borders to a coding agent.

**Here.** Our UI is drawn in SwiftUI, in the brand's colours and type, designed in Figma (`game-ui`
skill); there are no generated panel images to nine-slice. The idea that carries over: design one
whole screen and take parts from it, rather than parts one at a time. The `game-ui` skill already
starts from references and the Figma file. Nothing to do.

### Slice sprite sheets and animations into separate assets

https://www.spritecook.ai/blog/slice-sprite-sheets-and-animations (2026-05-07, updated 2026-11-03)

**Summary.** Generate many sprites on one sheet: cheaper, and sprites made together share style, palette
and light better than separate runs. Slice by alpha, by grid or by hand.

**Here.** Worth testing once with RD: one generation of a set (say, three monsters of one family) could
cost less and match better than three. Only with a dry run and the user's OK.

### Save your generation setup as a preset

https://www.spritecook.ai/blog/presets (2026-04-26, updated 2026-11-03)

Product feature. Our equivalent is the `request` kept in `art/assets.json` for every RD asset. Nothing
to do.

### How to generate pixel art game assets with AI

https://www.spritecook.ai/blog/creating-pixel-art-assets (2026-03-23, updated 2026-11-03)

Walkthrough of SpriteCook's create page. Tips that carry over: name the view in every prompt, generate
at the game's own resolution rather than scaling later, use your best sprite as a reference. All
already in our RD practice.

### Make a top-down tileset that actually tiles

https://www.spritecook.ai/blog/top-down-tileset (2026-06-02, updated 2026-11-03)

Product walkthrough for 15-piece tilesets. Doesn't apply (see the dual-grid notes above).

### How to animate a custom pixel art sprite

https://www.spritecook.ai/blog/animate-custom-sprites (2026-03-16, updated 2026-11-03)

Product walkthrough. One point that holds anywhere: an animation inherits its sprite's view and won't
turn it. Doesn't apply.

### How to animate detailed and HD art with prompting

https://www.spritecook.ai/blog/animate-detailed-sprites (2026-03-22, updated 2026-11-03)

Product walkthrough for art over 256 px. Doesn't apply.

### Turn your pet into a playable pixel art character

https://www.spritecook.ai/blog/animate-your-pet (2026-03-20, updated 2026-11-03)

Photo to sprite to animation set. Doesn't apply.

### Prompt your character to do anything

https://www.spritecook.ai/blog/custom-character-animations (2026-05-26, updated 2026-11-03)

Product features (custom animations, a posed first frame, editable prompts, batch prices). Doesn't
apply.

### From prompt to animated character, step by step

https://www.spritecook.ai/blog/character-creator-flow (2026-04-19)

Product walkthrough. Pick the view first; changing it later means redoing the character. Doesn't apply.

### Free animated pixel art wallpapers

https://www.spritecook.ai/blog/free-animated-pixel-art-wallpapers (2026-10-19, updated 2026-11-03)

**Summary.** Generate a scene small (about 144×256), animate it, scale by 10 with nearest neighbour to
1440×2560. When a model moves the background too, animate only the subject over a still plate.

**Here.** A marketing idea, not a game one: phone wallpapers from the `store_land_*` scenes, scaled by
a whole number with nearest neighbour, would suit `tools/social_art.py` and the social accounts. Only
if the user wants it.

## Engine walkthroughs

### Unity pixel art import settings for crisp sprites

https://www.spritecook.ai/blog/unity-pixel-art-import-settings (2025-11-10, updated 2026-11-03)

Unity settings (point filter, no compression, no mipmaps, Pixel Perfect Camera). We're on SpriteKit;
the principles are covered under the pixel-perfect article above. Doesn't apply.

### Make a Godot autotile tileset with AI and paint a map

https://www.spritecook.ai/blog/godot-autotile-tileset (2026-06-03, updated 2026-11-03)

Godot walkthrough. Doesn't apply.

### Tiled autotile tilesets with AI and the Terrain Brush

https://www.spritecook.ai/blog/tiled-autotile-tileset (2026-06-03, updated 2026-11-03)

Tiled walkthrough. Doesn't apply.

### Make a Unity autotile tileset with AI and a Tile Palette

https://www.spritecook.ai/blog/unity-autotile-tileset (2026-06-03, updated 2026-11-03)

Unity walkthrough. Doesn't apply.

## Business, news and plugins

### Is it OK to use AI art in your indie game?

https://www.spritecook.ai/blog/is-ai-art-ok-in-indie-games (2026-06-18)

**Summary.** General information, not legal advice, as it says itself. Players resent generic,
inconsistent AI art more than AI art as such. In the US a purely AI-generated image can't be
copyright-registered; the parts a person meaningfully edits or arranges can be. Don't make anything
that looks like an existing protected character. Steam asks you to disclose AI content that ships;
Apple and Google, as of early 2026 by its account, focus on apps that send data to AI or generate
content, not on tagging art.

**Here.** Relevant to launch (`docs/launch-audit.md`). Our art is RD's, refined in code, plus a lot
drawn wholly in code. The protected-character point is already a rule (CLAUDE.md: no Fairyland Online
names; `docs/fairyland-online.md` → Names). App Store rules should be checked at the source before
launch, not taken from this article.

### AI game art vs hiring an artist: the real cost

https://www.spritecook.ai/blog/ai-game-art-vs-hiring-an-artist (2026-06-22)

Cost comparison (about 50 icons for ten cents, against hundreds commissioned). Nothing to do.

### Chroma Awards Season 2, game ideas and the SpriteCook Award

https://www.spritecook.ai/blog/chroma-awards-season-2 (2026-10-19, updated 2026-10-21)

A competition for games playable in a web browser, open until January 7. An iOS app doesn't qualify.
Nothing to do.

### SpriteCook rewards: levels, weekly quests and invites

https://www.spritecook.ai/blog/spritecook-rewards (2026-11-12)

**Summary.** XP for making things on different days, a card of one-time firsts, levels that pay
credits, three weekly quests with a chest you open yourself (and one that opens on its own next week
if you forget, so none is lost), invite links.

**Here.** The game has a daily gift and bounties (`content/rewards.json`) and Monster Book milestones.
Two ideas fit a game better than a tool: a **card of firsts** (first seal, first boss, first dye; a
small reward each) for new players, and **a reward that's never lost** (an unclaimed weekly chest opens
itself next week). Both are gamification ideas for `docs/launch-audit.md`, not SpriteCook techniques.

### November update: rewards, invites and new plan prices

https://www.spritecook.ai/blog/spritecook-november-2026-update (2026-11-12)

Product news and prices. Nothing to do.

### Generate game sprites in the Claude desktop app

https://www.spritecook.ai/blog/claude-desktop-spritecook-plugin (2026-06-10, updated 2026-11-03)

Plugin install guide. Its one idea, a skill that has the agent make one hero asset first and use it as
the reference for the rest, is in our `sprite-creation` skill as the review beside neighbours. Nothing
to do; we don't use SpriteCook.

### Generate game sprites in Codex with the SpriteCook plugin

https://www.spritecook.ai/blog/codex-spritecook-plugin (2026-06-13, updated 2026-10-27)

Plugin install guide. Nothing to do.

### Generate game sprites in Cursor with SpriteCook

https://www.spritecook.ai/blog/cursor-spritecook-plugin (2026-06-14, updated 2026-11-03)

Plugin install guide. Nothing to do.

### Generate game sprites in OpenCode with SpriteCook

https://www.spritecook.ai/blog/opencode-spritecook-plugin (2026-06-15, updated 2026-11-03)

Plugin install guide. Nothing to do.

### An AI assistant that helps you make game art

https://www.spritecook.ai/blog/ai-assistant-game-art (2026-10-08)

The in-app assistant. Nothing to do.

### Let your AI agent generate sprites and animations

https://www.spritecook.ai/blog/ai-agent-generate-sprites (2026-03-29, updated 2026-11-03)

MCP setup, and why the skill matters: it tells the agent to check the balance before a batch, make a
hero asset first and match the rest to it. Our RD rules (a dry run and the user's OK before any paid
run, `art/spend-log.jsonl`) are stricter. Nothing to do.

### How to vibe code a browser game with Phaser.js

https://www.spritecook.ai/blog/vibe-code-phaser-game (2026-04-06, updated 2026-11-03)

Beginner walkthrough with placeholder rectangles first, art later. Nothing to do.

## Proposals

Nothing below is built. Each waits for the user's yes.

### Rules to write down

**`docs/pixel-style.md`, a new section "Effects on the pixel grid":**

> - **A hit flashes by mixing, not tinting.** A sprite that flashes on a hit mixes its pixels toward
>   the flash's colour and keeps its alpha (a shader). A multiply tint leaves dark pixels dark, so the
>   outline never lights.
> - **Movement in whole pixels.** A screen shake moves in whole points, side to side, smaller each
>   step, and ends at exactly where it started. A push is eased over several frames, never one jump.
> - **No squash and stretch by scaling a sprite.** It changes the size of its pixels. Draw it as
>   frames, or move whole pixels as the idle motions do.

**`docs/pixel-style.md`, under the ground tiles (only once Wang tiles are built):**

> **Ground versions differ at their edges.** Variety in a ground tile comes from versions whose edges
> differ in a known pattern (edge Wang tiles: each edge one of two strips, picked by a hash of the
> world seed and the edge's position), never from versions that share one frame. A frame every
> version shares repeats along every cell edge and shows the grid. No cross-fades: a version holds only
> the tile's own colours.

**`docs/sprite-acceptance.md`, under what every sprite must pass:**

> **One art pixel, one size.** A new sprite's PNG is at its own size (`sprite_check.py`: every run of
> equal pixels a multiple of 1, so nothing upscaled), and in the game its art pixels are the same size
> on screen as those of what stands beside it. A sprite shown bigger than its neighbours' scale is a
> mixel, however well its colours match (the butterflies were three times everyone else's).

**`.claude/skills/sprite-idle-animation/SKILL.md`, under the acceptance criteria:**

> **Still air is still.** An idle motion that runs all the time (a sway, a bob) rests between beats or
> shrinks to nothing when there's nothing driving it. A small constant movement reads as jitter.
> Timed by where a thing stands, not at random, so neighbours move one after another.

**CLAUDE.md:** nothing new yet. If the hit feel is built, a line under Layout for where it lives
(`BattleScene.impact`, the flash shader), as every other system has.

### Skill additions

**`sprite-creation`: two checks in `scripts/sprite_check.py`.**

1. **Pixel size** (the gcd of every run of equal pixels, across and down): fails `--new` when a
   sprite or any frame of a sheet is upscaled. Today every shipped PNG passes, so it only guards
   what's new.
2. **Outline gaps**, report only at first: an edge pixel that's light while the edge pixels either side
   are dark. Run it over everything shipped and read the list before it gates anything; most hits on
   RD's art will be drawn on purpose (a highlight on a rim, the gap between a sword and a hand).
   Fixes, if any, go through `rd_fixes.py` with the user's OK.

**`sprite-creation`, in the RD section:** when a set of related sprites is wanted (a monster family,
a set of props), try one generation of the whole set on one sheet and slice it, as sprites made
together match better and may cost less. Dry run and the user's OK first.

**A tool, `tools/pixel_scale.py`** (or a mode of `pixel_style.py`): every sprite's points per art pixel
as the game draws it (tiles, walk sheets with their scale, scenery, buildings, effects), grouped by
kind, outliers listed. It would tell us how far apart the ground (1.375) and the walkers (1.0 unless
scaled) really are, and whether anything else is off.

### Features, ranked by value to players against effort

| # | Feature | Value | Effort | Where |
|---|---|---|---|---|
| 1 | **Hit feel in battle:** a 5-frame hit stop on attacker and target (9 on a killing blow), a white flash by shader, an eased push in place of the jiggle, a whole-point shake on criticals and killing blows for every race, all scaled by the battle pace and off under Reduce Motion | High: every fight, every hit | Small to medium; Swift only, needs a Mac or a Screenshots run to see | `BattleScene.impact`, `attack`, `Nodes.flash` |
| 2 | **Wang ground tiles:** 16 versions per ground tile with edges from two strips each way, picked by hashed edge colours, no cross-fade | High: every land, every screen | Medium; mirror it in `palette_preview.py` first, judged without a Mac | `ArtLibrary.tileVariant`, `GroundTiles` |
| 3 | **Pixel scale audit**, then a decision on pinch zoom steps | Medium: a steadier picture | Small for the tool; the zoom change is the user's call | new tool; `WorldScene.zoomRange` |
| 4 | **Shadowcast cave light:** the lantern stops at walls, in bands; the cave's map fills in only with what you've seen, not what's behind a wall | Medium: caves only | Medium to large | `Lantern`, `CaveWalls`, the minimap |
| 5 | **A chest shakes once before it opens** on the map | Low to medium | Small | `GameCoordinator.openChest`, the chest's node |
| 6 | **Card of firsts** for new players (first seal, first boss, first dye) | Medium for new players | Medium; content and UI | `content/rewards.json`, a new card |
| 7 | **Hero silhouette behind houses** (the scenery never changes) | Low | Small to medium | `SeeThrough`, the hero node |

Not recommended: the CRT look (not faithful to a 2007 PC game), parallax haze (no parallax here),
platformer forgiveness (no jumping), dual-grid or 15-piece tilesets (our transitions are softer), and
any new paid art source (RD covers it).

### Questions for the user

1. Which features to build, and in what order? My pick: 1 (hit feel) and 2 (Wang ground), then the
   audit (3).
2. Wang tiles rearrange RD's ground tiles into 16 versions, as the four versions do now. Is that
   within "never redraw RD art", or should it wait?
3. Which rules to write down now, and which only once the feature behind them is built?
4. The silhouette behind houses (7): you ruled out fading scenery. Is a flat-colour outline of your
   own hero, with the scenery left as it is, something you'd want, or keep it as it is?
