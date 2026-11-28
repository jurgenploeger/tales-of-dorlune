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
