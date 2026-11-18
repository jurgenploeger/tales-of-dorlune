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
`content/world.json`). Its output is committed, so Vercel builds with Node alone.

URLs come from the names players see (`/lands/prismhaven/`), never from content ids: some ids keep
old names.

## Vercel

Project settings → Build and Deployment → Root Directory: `website`. Astro is detected by itself.

## Still to fill in (`src/lib/site.ts`)

- `appStoreUrl` and `appStoreId`: until then the buttons say "Coming soon to the App Store".
- `supportEmail`: the Support page needs a real address before App Review sees it.

## Look and words

The Figma brand guidelines (file `521ECWenGbx2IP3rLgtIWo`): the sky, gold, cream and midnight
(`src/styles/global.css` holds the colour variables' values), Luckiest Guy in capitals for a few
big words, Fredoka for the rest, and the voice of page 09: warm, plain, brief and true. British
English, with the tagline's American "cozy". The game's glossy windows stay in the game. Only claims
the game keeps: no prices, no online play, never Fairyland Online's names. The screenshots in
`public/img/` are the `store_land_*` scenes from the `screenshots` branch, cropped clear of the
Dynamic Island.
