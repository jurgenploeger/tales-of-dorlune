Monsters with full animation, by ChatGPT (2026-11-28).

57 companion monsters in six batches (batch01 to batch06) and the 16 bosses in two (batch07, batch08). Colour variants
(61 of them: Frost Puff, Sakura Bunny...) aren't drawn: the game recolours each from its base, as it does now.

Companions: one sheet each, 3 directions (down, right, up; left is right mirrored) x 9 frames:
idle 2, walk 4 (also played faster as the run), attack 3.
Bosses: one direction, 9 frames: idle 4, attack 5.

For each batch: a new chat; attach the batch's sheet_today.png and its NN_<id>_today_8x.png pictures; paste its
PROMPT.txt as it is. Ten monsters is a lot for one chat: if it starts to drift (sizes change, the monster turns into
something else), start a new chat for the rest of the batch with the same prompt and the remaining pictures.

Run batch01 first and check it before the rest: the first monster's sheet sets the frame size, the foot row and the
look for all of them. If it's right, attach that sheet to the later batches with: "This approved sheet is the
format and style: match its frame size, layout, foot row and finish exactly."

Back in the repo, each sheet is checked frame by frame (size, foot row, nothing jumping), at game size on the map and in
battle, and the game learns to play them (today a monster is one picture that squishes or hops): a Swift change made
once the sheets are in.

Results (2026-11-28): all 73 in (57 companions, 16 bosses), as EIGHT directions, not three: rows down, right, up,
left, down-right, down-left, up-right, up-left; columns idle 2, walk 4, attack 3 (the bosses too, 8 directions, the
same 9 columns). art-variants/monster_sheets/ (40-pixel frames 360 x 320, 64-pixel 576 x 512; ChatGPT's
asset_checks per batch). Plus 7 colour variants drawn as their own sheets (variants/: sakura_bunny, mud_slime,
fire_crab, light_mouse, mining_lizard, moonlamp_sprite, dragonfruit_sprout = monsters.json `dragonfruit`).
Checked: hard alpha, no empty frame, every frame's feet within 2 pixels of its sheet's row; each keeps who it is
(results_identity.png: today's beside the new one facing you).
Issues: (1) monsters drawn sitting (flame wolf, earth wolf, earth lion, werewolf, red bull) stay sitting in their walk
frames, shuffling, not walking (results_right_rows.png); (2) frames that touch their cell's edge, so the monster is
cut: puppet_king 72, red_bull 62, mud_eagle 13, a few in wisp, treefrog, flame_sheep, jelly, golden_hamster.
