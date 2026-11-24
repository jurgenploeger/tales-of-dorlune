# talesofdorlune.com

The game's website: a landing page for the app and a guide to everything in it (monsters, lands,
quests, items, classes and skills, a beginner's guide, a walkthrough and where to level). A static
site built with [Astro](https://astro.build); every guide page is generated from the game's own
`content/*.json`, so it can't drift from the game.

## Run it

```bash
cd website
npm install
npm run dev        # http://localhost:4321
npm run build      # the static site, in dist/
```

## After the game's content or art changes

```bash
python3 website/tools/export.py     # needs pillow + numpy
```

It rewrites `src/data/game.json` (everything, cross-linked: where a monster lives, what drops an
item, which quest opens a road) and `public/sprites/` (each sprite the site shows; a derived one is
recoloured as the game does at load time) and `public/world.png` (the continent, from
`content/world.json`), and `public/scenes/` (`tools/scenes.py`: each land from the side, its own scenery
graded with its palette on a strip of its ground, which the homepage walks through and each guide page
opens with). Its output is committed, so Vercel builds with Node alone.

URLs come from the names players see (`/lands/prismhaven/`), never from content ids: some ids keep
old names.

## Icons

Iconaut's (MIT), as in the game: `python3 website/tools/icons.py` vendors them into `src/icons/`, and
`<Icon name="…" />` draws one inline. Add a name to the tool's `ICONS` for another.

## Vercel

Project settings → Build and Deployment → Root Directory: `website`. Astro is detected by itself.

Vercel builds only when something under `website/` changed (`vercel.json` `ignoreCommand`: the diff since
the last deployed commit, `VERCEL_GIT_PREVIOUS_SHA`, else the commit before), so an app-only push doesn't
redeploy the site (the user, 2026-11-24). The app's TestFlight build likewise ignores `website/`
(`.github/workflows/testflight.yml` `paths`).

## Still to fill in (`src/lib/site.ts`)

- `appStoreUrl` and `appStoreId`: until then the buttons say "Coming soon to the App Store".
- `supportEmail`: the Support page needs a real address before App Review sees it.

## Look and words

The Figma brand guidelines (file `521ECWenGbx2IP3rLgtIWo`): the sky, gold, cream and midnight
(`src/styles/global.css` holds the colour variables' values), Luckiest Guy in capitals for a few
big words, Allo for the rest (the user's pick over Fredoka, 2026-11-18: rounded everywhere didn't feel
premium; `public/fonts/Allo-Dorlune.woff2` is its variable font pinned to roundness 25 and cut to Latin
with fonttools, OFL), and the voice of page 09: warm, plain, brief and true. British
English, with the tagline's American "cozy". The game's glossy windows stay in the game. Only claims
the game keeps: no prices, no online play, never Fairyland Online's names. The screenshots in
`public/img/` are the `store_land_*` scenes from the `screenshots` branch, cropped clear of the
Dynamic Island.
