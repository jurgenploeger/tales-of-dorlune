Spell and skill effects in battle as pixel art, by ChatGPT (2026-11-28). Today they're light drawn in code
(SkillStyles.swift, ElementEffects.swift): glows that don't fit the pixel art.

53 skills in six batches of nine (blows, magic, heals, buffs, curses, the rest). Each skill one sheet of 64 x 64
frames, 8 columns: row 1 the cast at the user (6 frames), rows 2 and 3 the projectile flying right and up (4-frame
loops, only for what flies), row 4 the impact on the target (8 frames). Drawn with no character in them, so the
game plays them on any hero, monster or boss.

For each batch: a new chat; attach the batch's icon pictures (the skill's new pixel icon where batch 1 made one,
else today's) in order; paste its PROMPT.txt as it is.

Run batch1 first and look at a few in the game before the rest: whether 64 x 64 and 6/4/8 frames are enough is
something to see moving. Back in the repo the game learns to play them in place of the glows, skill by skill, keeping
each skill's timing, its sound and its hit moment (the white flash and knockback when a blow lands).

Results (2026-11-28): all 53 in, art-variants/spell_effects/effect_<id>.png (512 x 256, 64-pixel frames, hard alpha,
20 to 39 colours; 14 with a projectile, 39 cast and impact only). results_sample.png; ChatGPT's own motion preview
of batch 1 as batch1_motion_preview.gif. Real pixel art, each its own, a clean fade. Small in their frames (an impact
about 30 pixels across): right beside a 40-pixel monster, on the small side on a 64-pixel boss.
