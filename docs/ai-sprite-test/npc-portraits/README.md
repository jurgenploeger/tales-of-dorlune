# NPC portraits for the speech window (ChatGPT, weekend run)

The user, 2026-11-27: a detailed portrait of every NPC, in the app icon's style, shown big in the speech
window's bottom-right corner while you talk to them, in a few emotions so it can change as the conversation
goes. 87 portraits cover every NPC you can talk to (quest givers, healers, bankers, shopkeepers, barbers, smiths,
guild masters, the weaver). Several NPCs share one look in the game (the four healers, the five bankers...), so
they share one portrait; their LIST line says so.

## What's in here

| Path | What |
| --- | --- |
| `style/app_icon_style_reference.png` | The look to match: the app icon. |
| `batchNN/` | One batch: `LIST.txt` (each NPC: its portrait id, name, what they do, where, what they say, their quests), `batchNN_sprites_sheet.png` (their game sprites side by side with names), and each NPC's sprite at 8× (`NN_<id>_sprite_8x.png`), the character to draw. |
| `batch00/` | **Run first**: Elder Oak and Mother Sheep, a person and a creature, to set the style. |
| `PROMPT.txt` | The prompt, the same for every batch. |

## How to run it

1. New chat (in the ChatGPT project). Attach `style/app_icon_style_reference.png`, the batch's sheet and its
   `_sprite_8x.png` files. Paste `PROMPT.txt`, with the batch's `LIST.txt` in place of `[LIST]`.
2. Batch 00 first. Look at the two characters' four faces; redo until they're right. Those become the **style
   anchors**: from batch 01 on, also attach Elder Oak's and Mother Sheep's picked neutral portraits, and add to
   the prompt: "The attached portrait_elder_neutral and portrait_mother_sheep_neutral are approved: match their
   size, framing, outline, shading and level of detail exactly."
3. Batches 01 to 09, ten characters each (the last five). Send "next" between characters if it stops.
4. Save each batch's zip (not screenshots) and bring them to a Claude session in the repo.

## When they come back

Each is checked at the speech window's size (the speaker about 130 points across, cut off by the screen's edge),
light and dark, beside its walking sprite; then wired in: a portrait per NPC art, and a mood per speech line
(neutral by default) so a line can switch the face. That's a small content and Swift change, made once the
portraits are in.
