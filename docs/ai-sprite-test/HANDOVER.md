# Can ChatGPT or Nano Banana replace Retro Diffusion? Test 1 (easy)

The question: can a general image model (ChatGPT's image generation, Google's Nano Banana in Gemini) draw
sprites that sit in Tales of Dorlune beside Retro Diffusion's, so we stop paying RD? Start with the easiest
thing RD does for us, one 40 × 40 monster, and climb only if it passes.

## The test

**Draw the pineapple monster.** RD already drew it (`monster_pineapple`, prompt: "cute little walking
pineapple creature with leafy hair and tiny feet, chibi"), so we have an answer key. Don't show the models
RD's pineapple: they get four *other* RD monsters as the style reference, and we compare blind.

Why this one: it's colourful (a white subject breaks the colour checks), simple in shape, and it has the
bits that show whether a model gets our look: a leafy crown, a textured body, big eyes, tiny feet.

## What to attach

`docs/ai-sprite-test/style-reference.png`: RD's jelly, bun, hedgehog and fire rat, each 40 × 40, scaled up
10× so every art pixel is a 10 × 10 block. Attach it to the first message in both tools.

## The prompt (same for both, paste as is)

> I'm making a cute pixel-art RPG for iPhone. The attached image shows four monsters from the game, each
> drawn on a 40 × 40 pixel grid and shown scaled up 10× (every square block is one pixel). Match their style
> exactly.
>
> Draw a new monster in the same style: **a cute little walking pineapple creature with leafy hair and tiny
> feet, chibi.** A round golden-yellow pineapple body with a diamond skin texture, a crown of spiky green
> leaves on top, big dark eyes with a white catchlight, rosy cheeks, a small happy mouth, two tiny stubby
> feet. Facing the viewer, standing.
>
> Style rules, all of them matter:
> - Real pixel art on a **40 × 40 grid**. The monster fills about 35 pixels of the height.
> - Show it scaled up **16× with nearest-neighbour** (a 640 × 640 image), so every pixel is a perfectly
>   square, equal-sized, hard-edged block that lines up with one grid. No pixel of a different size anywhere.
> - **No anti-aliasing, no blur, no gradients, no soft glow, no dithering noise.** Flat colour per pixel.
> - About **20 to 30 colours** in total. Each colour has a ramp of 4 to 5 shades.
> - **Hue-shifted shading:** shadows lean warmer/redder (orange-brown under the yellow, blue-green under the
>   green), highlights lean paler and warmer. Not just darker and lighter versions of one colour.
> - **Lit from the top left.** Highlights top left, shade bottom right.
> - **Outline:** one pixel wide, all round, a deep shade of the colour it borders (dark brown round the body,
>   dark green round the leaves), **not pure black**.
> - Chibi and cute, like the reference: big head-to-body ratio, big eyes.
> - **Plain flat pure white background** (or transparent if you can). No ground, no shadow under it, no
>   text, no border, no grid lines drawn on the image.

Ask for **three tries** in each tool (a new chat, or "make another, different from the first" each time).
RD gets one in four wrong too; judge the best of three.

### If it drifts

Send one of these as a follow-up, not a new prompt:
- Blurry or uneven pixels: "The pixels aren't square and equal. Redraw it on a strict 40 × 40 grid,
  scaled up exactly 16×, every pixel a hard-edged 16 × 16 block."
- Too detailed or too smooth: "Too much detail for 40 × 40. Fewer pixels, fewer colours, chunkier, like the
  reference."
- Black outline: "Make the outline a deep shade of each colour it borders, not black."
- Wrong style (3D, vector, painterly): "This isn't pixel art. Match the attached reference's style."

Note which tool needed which nudges: that's part of the result.

## Bring them back here

Save each picture (the full-size download, not a screenshot) and put them in this session, or commit them to
`docs/ai-sprite-test/results/` named `chatgpt_1.png`, `nanobanana_1.png` and so on. Then I run, for each:

```
python3 tools/ai_sprite_eval.py docs/ai-sprite-test/results/chatgpt_1.png \
    --rd monster_pineapple --out docs/ai-sprite-test/results/chatgpt_1_40
```

It clears the background, brings the picture back to the game's grid (each art pixel the colour covering
most of its block), cuts it to 28 colours, places it where RD's pineapple stands, and:
- writes `chatgpt_1_40.png`, the sprite exactly as the game would load it;
- writes `chatgpt_1_40_sheet.png`: RD's pineapple on the top row, the candidate below, at 1× and 8×, on the
  map's grass and on the dark battle field;
- scores both with `tools/pixel_style.py check --kind creature` (the bands every RD sprite we ship sets) and
  the outline, inner-line and saturation marks from `docs/sprite-acceptance.md`.

The round trip is checked: RD's own pineapple, blown up blurry to 1024 pixels on white with noise and run
back through it, still passes (92%).

## How we judge it

It passes Test 1 if the best of three, **after** the grid round trip:
1. passes `pixel_style.py check --kind creature` (RD's pineapple passes at 92%; our art usually lands
   80 to 95%);
2. at 1× on grass you can tell it's a pineapple monster, and it reads as the same game as RD's (outline
   weight, detail, colour families);
3. at 8× its pixels are clean: no mush where the model's grid drifted, no stray single pixels, eyes intact;
4. you'd put it in the game without fixing anything by hand.

Then a blind pick: I put RD's and each tool's best side by side, sides shuffled, the key held back
(`tools/blind_review.py` does this), and you pick the one you'd ship.

Honest expectations: general models are good at the *idea* of pixel art and bad at a *real* grid. The usual
failure is pixels of uneven size that smear when brought back to 40 × 40, and too much detail for the size.
The round trip will show that plainly. Hue-shifting and a coloured outline are the second most likely misses.

## The ladder, if Test 1 passes

RD earns its money on the hard ones, so the switch is decided further up, not here:
1. **The pineapple** (this test): one front-facing 40 × 40 monster with references.
2. **Something RD never drew** (a mossy turtle, say): same style without an answer key to lean on.
3. **A 64 × 64 boss** with more parts (wings, a crown, a weapon).
4. **A 64 × 64 item icon** in the clean look (docs/pixel-style.md *Item icons*): smooth ramps, no grain,
   lit top left.
5. **A 4-direction walk sheet** (192 × 192, four 48 × 48 frames a row: up, right, down, left) that keeps
   the same character in every frame. This is the real test: RD has a model trained for exactly this
   (`rd_animation__four_angle_walking`), and the hero, armour and townsfolk all hang on it. If the general
   models can't hold a character across 16 frames on a grid, we keep RD for sheets and could still drop it
   for single sprites.
6. **A building at 96 × 96** (`rd_tile__tile_object`'s job).

For reference, RD costs about $0.04 a monster, $0.05 a boss, $0.07 a walk sheet (references/rd-prompts.md
in the sprite-creation skill; $43.66 over 411 runs to 2026-10-29). Saving money matters less than the
art: a sprite we'd have to fix by hand costs more than RD's few cents.

## Results (2026-11-21)

`results/`: each try as sent, `*_40` squeezed to the game's size beside RD's, `*_native` snapped at the
grid the model actually drew on. `compare_native.png` and `compare_40.png` line them all up.

RD's own pineapple, for the record: passes at 92%, with 14 shades in its yellow ramp, and it misses
"lit from the top left" too (so that one isn't held against anyone).

| | ChatGPT 1 | ChatGPT 2 | ChatGPT 3 | Gemini 2 | Gemini 3 |
|---|---|---|---|---|---|
| sent as | 1254 PNG, **transparent** | 1254 PNG | 1254 PNG | 1024 JPEG | 1024 JPEG |
| grid it drew on (sprite height) | 44 | 48 | 44 | 45 | 46 |
| squeezed to 40 × 40 | fail 75% | fail 75% | pass 83% | pass 83% | fail 58% |
| at its own grid | fail 75% | fail 75% | pass 83% | pass 83% | fail 67% |
| shades per ramp (RD: 14) | 2 | 1.5 | 4 | 3 | 3 |

(Gemini's try 1 was a mix-up: it's the same file as ChatGPT's try 3, so it's scored as ChatGPT's.)

- **Neither drew at the size asked.** All five are 44 to 48 art pixels tall; RD's stands 35 on a 40
  canvas. Squeezed to fit, the faces break (eyes run together, catchlights lost).
- **ChatGPT draws the cleaner grid:** square, even pixels, a crisp outline in a deep shade of each colour,
  big readable faces, and once a truly transparent background. But it's **flat**: one or two shades per
  colour where RD has fourteen, big plain fills, a simple diamond pattern. It reads as clip-art pixel art,
  not as RD's textured, many-shaded look.
- **Gemini's shading is closer to RD's** (more texture in the skin, more variation), but its grid drifts:
  noisy pixels, near-black outlines, try 3 muddy round the eyes. The JPEGs don't help.
- **Beside RD's at game size, none of them belongs yet.** They're bigger, flatter (ChatGPT) or noisier
  (Gemini), and their outlines are heavier than RD's.

Verdict: **neither passes Test 1.** Both get the idea and miss the two things that make it our game's art:
the size (one art pixel, one size) and RD's dense, many-shaded texture. Fixable by prompt? Size maybe; the
shading depth is the harder one. One more round decides it:

Follow-up, in the same chat as each tool's best try (ChatGPT 3, Gemini 2):

> Close, but too big and too flat. Your pixel blocks make the pineapple about 45 pixels tall. Redraw the
> same pineapple on a 40 × 40 grid where the whole monster, crown to feet, is exactly 35 blocks tall and
> about 24 wide. Output 640 × 640, every block exactly 16 × 16 image pixels. Shade it like the reference:
> each colour in 6 to 8 shades, the skin textured with many small pixel clusters of different shades, not
> big flat areas. Eyes 3 blocks tall with a 1-block white catchlight. Transparent background, PNG.
