---
name: game-ui
description: How Tales of Dorlune's interface looks and how to change it (every window, tab strip, list row, button, speech window, HUD panel, toast and the title and loading screens), the rules it keeps, where each piece lives in the code and in Figma, how to find references, and the review every UI change passes. Use it whenever someone asks to redesign, restyle, tidy, fix or "make better" any screen or modal (the menu windows and their tabs, the Bag, Character, Companions, Quests, Settings, a shop, the smith, the bank, the dye window, NPC conversations, chat, the world map, battle buttons, the title screen), when a window "looks off", is cramped or empty, clips, truncates, or doesn't fit a phone on its side, and whenever TalesOfDorlune/UI or Style.swift is edited, even if the word "UI" is never said.
---

# Game UI

Tales of Dorlune keeps **Fairyland Online's 2007 MMO look on purpose**: glossy light-blue bevels, deep-blue
glass windows, tan plates, gold headings, cream text and orange close buttons, done crisply. It isn't an iOS
app with a game inside, and it isn't a modern flat mobile game. A change is good when it reads as the same
game, only clearer.

## Sources of truth

Read these before changing anything. When they disagree, the code is what ships; fix the other.

1. **The code.** `TalesOfDorlune/UI/Style.swift` (`HUDStyle`: every colour, the window, the frame, the
   plates, fonts; `gameWindow()`, `WindowTitle`, `OrangeCloseButton`, `PixelButtonStyle`,
   `PixelSwitchStyle`, `FLIconButton`, `StatBar`, `GlossyBar`, `EmptyNote`, `FitOrScroll`, `Reveal`,
   `popIn()`, `menuWindowMargins()`), `MenuView.swift` (`PageTabs`, `SectionTitle`, `HowItWorks`),
   `NPCDialogView.swift` (the speech window), `TitleView.swift`, `BrandSky.swift` (`Brand`: the title and
   loading sky), `WorldHUD.swift` (`HUDMargins`), `GameIcon.swift` (`IconImage`).
2. **The brand guidelines in Figma**, file `521ECWenGbx2IP3rLgtIWo`, page **07 Game UI** (`132:353`): the
   components at 2x (`UI / Window` 156:48, `UI / Close button` 156:5, `UI / Pixel button` 156:16, `UI /
   Icon button` 156:9, `UI / Plate` 156:18, `UI / Bar` 156:42, `UI / Switch` 156:47), the window rules
   (156:264) and Keep / Avoid / Words (156:331). Its colours are variables named after the Swift ones
   (CLAUDE.md, Brand guidelines). Change Figma and `HUDStyle` together.
3. **What the user has asked for in playtesting** (below, and in the code's comments: grep the file for
   `playtesting`). Those are decisions, not suggestions: don't undo one without asking.

## The rules

From the Figma page, the code and playtesting. Every change keeps all of them.

**One window for everything.** Menus, shops, dialogue, the world map, cards over cards: the same deep-blue
glass (`HUDStyle.glass`) in the same glossy light-blue bevel (`HUDStyle.frame`), `windowRadius` 22
continuous corners (at 10 "everything felt too sharp", 2026-10-26), a soft shadow under it. Build every
modal with `.gameWindow()`, never a background of its own.

**Every window has a title bar** (`WindowBar`, since 0.9.74; the user, 2026-11-10: "We can have the title
bars with the tabs"): the frame's own bevel along the window's top, out to the frame, as Figma's `UI /
Window` has it. On it, the window's name in white with a hard dark shadow (`WindowTitle`), or its pages'
tabs (`PageTabs`). Put the title or tabs first in the window's `VStack(spacing: 0)`, flush to its top, with
no padding round them, or the bar stops short. Only a title laid over something else (the world map's,
over its atlas) goes without (`bar: false`, gold).

**The close button is always orange and always over the top-right corner** (`windowCloseButton`, or a
`WindowTitle` with `onClose`), hanging 9 pt past it (2026-10-25: "Put all the close buttons overlayed top
right of the modals"). Keep `OrangeCloseButton.room` clear along the top. Orange means closing, losses and
warnings, nothing else.

**Colour on glass.** Text cream (`HUDStyle.cream`); headings and the tab you're on gold (`gold`); minor text
`dim`; good news and bonuses `green`; dark ink (`ink`) only on light buttons, plates and the gold tab. The
brand's sky, its gold and midnight, and Luckiest Guy belong to the title and loading screens, **never inside
a game window**.

**Type.** SF Pro Rounded Heavy (`HUDStyle.font`) for every label, 10 to 17 pt in windows (18 for a window's
title, up to 18 for a primary button). Numbers that tick: `.monospacedDigit()`; `HUDStyle.mono` only for
numbers on their own. Nothing under 10 pt; body text 11 to 13.

**Buttons are glossy and bevelled, never flat.** `PixelButtonStyle` (a capsule with a shine, a dark rim and
a hard 3 pt shadow that presses down, and the tap sound), `primary: true` for a screen's main choice,
`compact` in tight rows; gold tint for the action that moves you on. `FLIconButton` for square icon
buttons. No borderless or outline-only buttons.

**Icons.** Pixel icons (`IconImage`, art/sprites/ui_*.png, tools/ui_icon_art.py) from 18 pt up; Iconaut's
vector glyphs below that.

**Tabs** (`PageTabs`): a window's pages' names and nothing else, in full, never truncated; the row scrolls
sideways when they don't fit (2026-10-26: "The tabs don't need icons and shouldn't get truncated. If it
doesn't fit, there should just be a horizontal scroll"). They're folder tabs standing on the title bar:
the one you're on is the window's own glass (`HUDStyle.glassTop`) with its name in gold, joined to the page
under it; the others are sunk into the bar, white. One with something waiting wears the gold dot. Each of Character, Companions, Friends, Bag, Quests and Settings is
a window of its own, opened from the HUD menu (2026-10-25: "The menu items hero etc should become their
own modal window"), so a window's tabs are its own pages, never the other windows.

**Rows sit on cards** (`rowCard()`): anything in a list you can tap or act on (a friend, something a shop
sells) is a row on its own slightly lighter card, so a long list reads as separate things. A control that
can't be used says why beside it, in orange (a price you can't pay: "Need 30 more gold"), never just grey.

**A window over a window hides what's under it** where both would show through each other (the dye window
over a speech window: its close button and Dye gear button showed round it, until 0.9.74). A card over a
menu window is fine: the menu is a backdrop.

**Fits a phone held either way.** Every window fits portrait and landscape; the part that scrolls gives way
first (`FitOrScroll`, a `ScrollView` under fixed tabs and title). Menu windows are as big as the HUD's
margins allow (`menuWindowMargins()`: 8 pt from the sides and top). Check both orientations, every time.

**Speech is Fairyland Online's** (`NPCDialogView`): the character stands big in the bottom-right corner, cut
off by the screen's edge, over a window running the screen's width; the window's content keeps clear of
them (`speakerRoom`). A narrow bubble beside them with a tail was tried and dropped (2026-10-26). Their
name is the window's title.

**Motion.** A window pops in from a touch smaller (`popIn()`); its backdrop only fades. What a tap opens
under a row unrolls (`.transition(.reveal)` with `Reveal.animation`). Respect Reduce Motion.

**Dark Mode.** Light surfaces (frames, plates, buttons, portraits) are `Color.adaptive(light:dark:)`; the
glass goes deeper; lettering keeps its colours. Check both looks (debug flag `dark` / `light`).

**Words.** Every visible string goes through `L("…")` and is translated into all ten other languages
(`tools/i18n.py missing <code>`, `merge`). Leave room: German and French run a third longer than English,
Russian too; Chinese, Japanese and Korean shorter but taller. Never fix a width to English text.

**Touch.** Every control at least 34 pt to tap, 44 where there's room (Apple's minimum); the close button's
34 pt tap area is the floor, not the target.

## Making a change

1. **Look at what's there first, as it is today.** Run the Screenshots workflow by hand for the scenes the
   change touches, on your branch (CLAUDE.md *Screenshots and tests*), and read them; never design from
   old shots (2026-11-10: a first mock-up was drawn from shots ten days and two redesigns old, and the user
   had to point it out). Add a scene to `tools/screenshots.txt` when none shows the screen. After the
   change, run the same scenes again and show both. On a Mac session, the Xcode plugin (`/plugin install
   xcode@claude-plugins-official`) builds, renders previews and drives a simulator: use it.
2. **Find references.** Fairyland Online itself first (docs/fairyland-online.md), then games of its kind
   (cosy MMOs and RPGs on iOS). Mobbin (`mobbin:search`) has real apps' screens but few games, and its
   search needs a paid Mobbin plan (on 2026-11-10 the account's was free: every search refused). Name what
   you take from a reference (a tab strip joined to the window, a row's layout), never copy a game's look.
3. **Propose before rebuilding.** For anything bigger than a spacing or colour fix, show the user a
   mock-up first: the current screen beside the proposal, at the phone's size, both orientations. An HTML
   page in the game's colours rendered with Playwright is quick (`HUDStyle`'s values; SF Pro Rounded isn't
   on Linux, so say the font is a stand-in). Wait for their pick.
4. **Build it from the pieces above.** Change a shared piece (`PageTabs`, `SectionTitle`, the frame) and
   every window follows; don't restyle one window by hand. New piece: put it in Style.swift (or the
   window's file if only it uses it), document it as the others are, and add it to Figma's 07 Game UI.
5. **Swift care.** Nothing compiles a `claude/**` branch; `.github/workflows/testflight.yml` builds `main`.
   Read every changed line for what the compiler would catch.
6. **Pass the review below**, then say plainly what wasn't seen running.

## The review

A UI change ships when every line holds, in portrait and landscape, light and dark, in English and the
longest translation (usually German):

- It uses `gameWindow()`, a title bar with `WindowTitle` or `PageTabs` flush at its top, the orange close
  button over the corner, `rowCard()` for list rows,
  `PixelButtonStyle` / `FLIconButton` for buttons, `SectionTitle` for sections, `EmptyNote` for nothing.
- Colours only from `HUDStyle`; no brand sky, midnight or Luckiest Guy inside a window.
- Text 10 pt or more, cream on glass, gold headings; dark ink only on light faces.
- Nothing truncated that matters (a name, a tab, a price); long text wraps (`fixedSize(horizontal: false,
  vertical: true)`), lists scroll, tabs scroll sideways.
- The window fits the screen held either way, the close button and tabs clear of the notch and corners.
- Every tap target 34 pt or more, the main one 44.
- An empty window says why and what to do (`EmptyNote`), not a sheet of empty glass.
- Every new string in `L("…")` and in all ten languages; `python3 tools/check_content.py` passes.
- Figma's 07 Game UI matches what changed.
- Seen running: on a Mac or TestFlight, or said plainly that it wasn't.

## Learned

Add what each UI change teaches, dated, with the case and what to do instead.

- 2026-11-10: the screenshots branch's scenes from before the workflow came back (the newest 2026-11-01)
  predate 0.9.72's bigger, cleaner windows and per-window menus: don't use them for how the game looks now.
