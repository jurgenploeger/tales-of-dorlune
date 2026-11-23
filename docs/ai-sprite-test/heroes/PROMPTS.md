# Prompts for the 64-pixel hero sheets

Copy-paste prompts for ChatGPT (image generation). Read [`HANDOVER.md`](HANDOVER.md) first. Fill in the
`{placeholders}` from the body table below. One body per chat; one direction row per message.

The LPC paper-doll standard's 64 × 64 frame and body size (about 48 px), in a sturdy chibi build. Legs are
measured from the shorts' hem to the soles; the guide's orange line is the hem, the violet ticks the chest's width.

| Body id | Race | Gender | Height | Head | Chest | Arms, legs | Legs | Feet | Build |
|---|---|---|---|---|---|---|---|---|---|
| human_male | Human | Male | 48 | 20 | 16 | 6 | 10 | 6 | sturdy, straight shoulders |
| human_female | Human | Female | 46 | 20 | 15 | 5 | 10 | 6 | sturdy, a little narrower shoulders, a little wider hips |
| human_other | Human | Other | 47 | 20 | 15 | 6 | 10 | 6 | sturdy, androgynous, between the two |
| elf_male | Elf | Male | 48 | 20 | 15 | 5 | 11 | 5 | a touch slimmer, long pointed ears |
| elf_female | Elf | Female | 46 | 20 | 14 | 5 | 11 | 5 | a touch slimmer, long pointed ears |
| elf_other | Elf | Other | 47 | 20 | 14 | 5 | 11 | 5 | a touch slimmer, androgynous, long pointed ears |
| dwarf_male | Dwarf | Male | 40 | 19 | 18 | 7 | 7 | 7 | short and broad, thick arms and legs |
| dwarf_female | Dwarf | Female | 38 | 18 | 17 | 6 | 7 | 7 | short and broad, strong arms |
| dwarf_other | Dwarf | Other | 39 | 19 | 17 | 7 | 7 | 7 | short and broad, androgynous |

All bodies: bald (hair is its own layer), no beard, no eyebrows drawn thicker than one pixel, plain
fitted underwear in warm grey: shorts on every body, a simple band top on Female and Other.

---

## 1. Project instructions (paste into the ChatGPT project's instructions)

> You draw pixel-art hero sprites for Tales of Dorlune, a cute fairytale pixel-art RPG for iPhone (a
> tribute to Fairyland Online). The reference sheets in this project's files are the look to match: round,
> soft, cute and chibi, rich hue-shifted shading.
>
> **Grid.** Every hero frame is a **64 × 64 pixel** canvas. The lowest foot pixel stands on **row 60**
> (counting from 0 at the top). The body is centred on **column 32**. I'll give each body's height in
> pixels; the head is about 2/5 of it. The attached guide (shown at 8×) marks the head top (blue), the chin
> (cyan) and the feet row (green); the guide lines are never part of the drawing.
>
> **Always deliver two files, every time.**
> 1. The sprite at real size (1×): a PNG, fully transparent background, exactly the canvas I ask for
>    (64 × 64 for one frame, 64·n × 64 for a row of n frames).
> 2. The same scaled up 8× with nearest-neighbour, as a preview.
> Never only the big picture. The 1× PNG goes in the game.
>
> **Check with code before replying**, fix and re-check until all pass, then report the numbers in one
> line: canvas size; the body's height within 1 pixel of what I asked and its feet on row 60; alpha only 0
> or 255; colour count 20 to 40; the 8× preview exactly the 1× scaled up. In a row: every frame the same
> height within 1 pixel, the head within 2 pixels of the same place.
>
> **Pixel rules.**
> - A real pixel grid: every pixel a hard square, all the same size. No anti-aliasing, blur, gradients,
>   glow, dithering noise or half-transparent pixels.
> - Lit from the top left: highlights top left, shade bottom right. Shade forms as forms (the far arm and
>   leg a step darker than the near ones, a shadow under the chin and the head).
> - Hue-shifted shading: skin shadows lean warm rose-brown, highlights pale and warm. 5 or more shades per
>   colour family, in clusters of 3 to 6 pixels of one shade; few single stray pixels.
> - A one-pixel outline all round, tinted: a deep shade of each colour it borders (deep warm brown round
>   skin, deep grey-brown round the underwear), about half as bright as the pixel inside it. Never pure
>   black, never one dark line round everything.
> - Chibi: big head, big eyes with a white catchlight, small rounded body, short limbs, hands as small
>   rounded mitts with a 1-pixel thumb.
> - Nothing else in the picture: no ground, no shadow under the feet, no text, no border, no grid lines.
>
> **The same character in every frame.** When I attach the approved master frame, copy it exactly: the
> same head, face, proportions, skin colours and underwear. Only the pose changes.
>
> **Directions** (eight; you draw five, the other three are mirrored in code):
> - "down" faces the viewer.
> - "down-right" is a three-quarter front view turned to the viewer's right: both eyes, the far one a pixel
>   narrower, the nose a 1-pixel bump toward the right, the near (left) shoulder a little forward.
> - "right" is a side view facing right: one eye, one ear, the near arm in front of the body.
> - "up-right" is a three-quarter back view turned right: the back of the head, the near ear and the edge
>   of the cheek, no eyes.
> - "up" faces away: the back of the head, no face.
>
> **Several in one chat:** one image at a time, named as I ask. If unsure, ask one short question; say
> plainly what you didn't manage.

---

## 2. Master base body (one per body, first message of its chat)

Attach: `templates/guide_{body}_8x.png`, `templates/compare_48_64.png`, `docs/ai-sprite-test/style-reference.png`
(for bodies after the pilot, also the approved Human Male master).

> Draw the master frame for a **{race} {gender}** hero: the blank base body the game dresses later.
>
> - One 64 × 64 frame, standing, **facing down (toward the viewer)**, arms relaxed a little away from the
>   body, feet slightly apart, weight even. Feet on row 60, centred on column 32.
> - **{height} pixels tall**, the head about {head} pixels. A sturdy cute chibi, a young adventurer, not a
>   baby and not a stick figure: chest and shoulders {chest} pixels wide, arms and legs {limbs} pixels thick,
>   legs {legs} pixels from the shorts' hem to the soles, feet {feet} pixels wide. Build: {build}.
> - Neck about 6 to 8 pixels wide, so a collar or necklace fits.
> - Arms relaxed, hanging with a 1 to 2 pixel gap from the body, open hands (not fists).
> - A smooth, doll-like body: no anatomy detail, no nipples, no navel line, no muscles drawn. Bald (hair is
>   added later), no beard. {Elf: long pointed ears reaching out past the head's sides.} {Dwarf: clearly
>   shorter and broader than a human, a round sturdy body; not human height.}
> - Plain fitted underwear in warm grey: snug shorts{Female/Other: and a simple band top}. One flat colour
>   family with its own shading, no trim, no pattern.
> - Bare hands and bare feet, drawn clearly (2 × 3 pixels or more each), so gloves and boots can go on.
> - A friendly face: eyes about 3 wide and 4 tall, set just below the middle of the head (a dark lash line
>   on top, a brown iris, one white catchlight pixel), thin 1-pixel brows, a small neutral smile, light rosy
>   cheeks. Human ears small, sticking out at most 1 pixel.
> - The shorts outlined in their own deep grey-brown, not the skin's outline colour.
> - Skin: a warm light peach ramp (it is recoloured in the game for every skin tone).
>
> Save as `hero64_{body}_master.png` and `hero64_{body}_master_8x.png`.

If it sends a big painted picture instead (about 1254 pixels, each "pixel" a 12 to 13 pixel block: try 2
was about 70 pixels tall), keep it as the design and ask: "I like this design. Redraw this exact character on
the 64 × 64 grid at {height} pixels tall, feet on row 60, pixel by pixel at that size; don't shrink the
picture. Keep the build numbers from my first message."

Follow-up if it comes back too tall or too short: "Measure it: it's {measured} pixels tall. Redraw it
{height} pixels tall on the same 64 × 64 canvas, feet still on row 60. Don't shrink the picture, redraw it."

---

## 3. Turnaround (second message)

Attach the approved master.

> Same character, same standing pose, as four more 64 × 64 frames, one at a time:
> 1. **down-right** (three-quarter front, turned to the viewer's right: both eyes, the far one a pixel
>    narrower, the nose a 1-pixel bump toward the right, the near shoulder a little forward);
> 2. **right** (side view: one eye, the nose a 1-pixel bump, the near arm in front of the body, the far arm
>    a step darker behind it);
> 3. **up-right** (three-quarter back, turned right: the back of the bald head, the near ear and cheek edge,
>    no eyes);
> 4. **up** (seen from behind: the back of the bald head, no face, the ears still showing if an elf).
>
> Exactly the same height, head size, skin colours and underwear as the master; feet on row 60. Save as
> `hero64_{body}_{direction}.png` (`down-right`, `right`, `up-right`, `up`), each with an `_8x` preview.

The left-facing views (down-left, left, up-left) are these mirrored in code: don't ask for them.

---

## 4. Animation rows (one direction per message)

Attach the master, the turnaround frame for that direction, and `templates/row_{body}_{anim}_8x.png`.
Five messages per animation, one per drawn direction: down, down-right, right, up-right, up.

Common opening for every row:

> Draw the **{anim}** animation of this character facing **{direction}**, as one row of **{n} frames**, each
> 64 × 64, side by side (a {64·n} × 64 PNG). The same character in every frame: same height, head size,
> colours and underwear as the master; only the pose changes. Feet on row 60 whenever a foot is on the
> ground. Save as `hero64_{body}_{anim}_{direction}.png` with its `_8x` preview.

Then the animation's own lines:

**idle (4 frames)**
> A slow breath while standing: frame 1 the master pose; frame 2 the shoulders and head down 1 pixel, the
> arms settling; frame 3 like frame 2; frame 4 back up, as frame 1. Nothing else moves; the feet stay put.

**walk (6 frames)**
> A relaxed walk cycle, loops from frame 6 back to 1: 1 contact (left foot forward, heel down), 2 down (body
> 1 pixel lower, weight on the left foot), 3 passing (right leg passes the left, body 1 pixel higher), 4
> contact (right foot forward), 5 down, 6 passing. The arms swing opposite the legs. {right: the near leg and
> arm one shade lighter than the far ones; the far ones never hidden completely.} {down/up: the legs move
> up and down in the view, not sideways; the arms swing slightly out.}

**run (6 frames)**
> A run cycle, loops: the body leaning forward a little, longer strides than the walk, arms bent and
> pumping. 1 contact, 2 push off, 3 airborne (both feet off the ground, body 2 pixels higher), 4 contact on
> the other foot, 5 push off, 6 airborne. Feet on row 60 at contact.

**attack (6 frames)**
> An empty-handed sword attack (the weapon is drawn separately and placed in the hand later), the right
> hand a closed fist as if gripping a hilt: 1 ready stance (feet apart, fist forward at waist height), 2
> wind-up (fist raised up and back over the shoulder, body twisting back), 3 strike (fist swept forward and
> down, body leaning in, front foot stepping forward), 4 follow-through (fist low and across), 5 recover
> (straightening), 6 ready stance as frame 1. The feet stay on row 60. Keep the fist one clear 3 × 3 block
> in every frame.

---

## 5. Fix prompts (one or two at a time)

- Size: "It's {measured} pixels tall; redraw it {height} tall on the same canvas, feet on row 60. Redraw,
  don't shrink."
- Drift: "Frame {k} doesn't match the master: {the head is 2 px bigger / the skin is pinker / the shorts
  are longer}. Redraw frame {k} only, copying the master exactly."
- Outline: "The outline is one dark line all round. Make it a deep shade of each colour it borders: deep
  warm brown round the skin, deep grey-brown round the shorts; the pixels just inside it a mid shade."
- Flat: "The shading is too flat: give the skin 5 or more hue-shifted shades, lit from the top left, the far
  arm and leg a step darker."
- Grid: "Some pixels aren't on the 64 grid (blurred or half-sized). Redraw on the grid, every pixel one
  hard square, alpha only 0 or 255."
- Limbs: "In frame {k} the arms and legs swing the same side; the arm opposite the forward leg swings
  forward."
- Missing 1×: "Send the 1× PNG file too, exactly {w} × {h}, transparent."

---

## 6. Hairstyle layer (after the base passes)

Attach the base sheet row (or master) and today's hairstyle for reference (`art/sprites/hair_<style>_<race>.png`).

> Draw only the **{style}** hairstyle for this character, facing **{direction}** (one of down, down-right, right, up-right, up), for every frame of the
> attached row ({n} frames, a {64·n} × 64 PNG). Nothing but the hair: the rest transparent, so it sits
> exactly over the body. The hair in **one warm brown ramp** (from a deep red-brown outline to a pale ginger
> highlight, 6 or more shades): the game recolours it to every hair colour. It hugs the bald head from the
> master, moves with the head (1 pixel down when the head is), and long hair sways a pixel with the walk.
> From behind ("up") the hair covers the back of the head. Keep the ears showing if an elf.

---

## 7. Wearable layer (armour, gloves, boots, necklace, belt, cape, hat)

Attach the base row and, for armour, a picture of the item (its icon at 8×).

> Draw only the **{item}** worn by this character, facing **{direction}** (one of down, down-right, right, up-right, up; for an item that differs by side, also down-left, left and up-left), for every frame of the attached
> row ({n} frames, a {64·n} × 64 PNG). Nothing but the item, the rest transparent, so it sits exactly over
> the body in every frame and moves with it. {item description, colours by name}. Its main material in
> {main colour} with 5 or more hue-shifted shades; its trim in {trim colour}, a colour nothing else in it
> uses. It follows the body's outline: no wider than 2 pixels past it (a cape or a big pauldron may go
> further), and never covering the face. One-pixel tinted outline as the body has.

Item lines to drop in:
- Gloves: "covering each hand and 2 pixels up the wrist, a cuff in the trim colour; at least 3 × 3 pixels
  a hand."
- Boots: "covering each foot and up the shin to 4 pixels below the knee, a turned-down cuff in the trim
  colour; the sole a darker band on row 60."
- Necklace: "a thin chain 1 pixel wide round the neck, a pendant 3 × 3 pixels on the chest, the gem in the
  trim colour with a 1-pixel highlight."
- Belt: "a 2-pixel band at the waist with a 3 × 2 buckle in the trim colour."
- Cape: "hanging from the shoulders to the knees; from behind it covers the back; from the side it trails
  behind. Two layers: the part behind the body and the part in front of it, as two PNGs."
- Hat: "sitting on the bald head, its band on the head's widest row just above the eyes; never covering
  the eyes."
- Armour: "a {chest piece / robe / tunic} covering the torso{ and the upper legs}, the arms' sleeves to the
  elbow; the shoulders 1 to 2 pixels wider than the body."

---

## 8. Weapon, 8 angles

Attach `templates/weapon_wheel_8x.png` and the weapon's icon at 8×.

> Draw the **{weapon}** as it's held in a hand, as one 128 × 128 PNG per angle. The grip (where the fist
> closes) is always on the middle pixel (64, 64). Angle 0 points the blade straight up; then 45 (up-right)
> and 90 (pointing right). About {length} pixels long from pommel to tip. Lit from the top left at every
> angle (don't rotate the light with the weapon). Every pixel a hard square: draw each angle on the grid,
> never rotate a picture (rotating blurs and jags it). One-pixel tinted outline. Save as
> `held64_{weapon}_0.png`, `_45.png`, `_90.png`, each with an `_8x` preview.

Lengths, for a 48-pixel hero: dagger 14, sword 25, greatsword 33, staff 42, spear 46, bow 29 tall,
wand 12, axe 23, hammer 23, whip 19 coiled (hanging to the feet when held).
