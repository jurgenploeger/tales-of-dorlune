#!/usr/bin/env python3
"""Vendors the website's icons from Iconaut (MIT, https://github.com/iconaut-design/icons), at the
commit the game's own icons are pinned to (tools/icons.py), into src/icons/<name>.svg.
`src/components/Icon.astro` draws them inline, in the text's colour.

    python3 website/tools/icons.py
"""
import pathlib, urllib.request

COMMIT = "178077725739aa39b321527e4c704d460bb2383f"
RAW = f"https://raw.githubusercontent.com/iconaut-design/icons/{COMMIT}/icons"
OUT = pathlib.Path(__file__).resolve().parent.parent / "src" / "icons"
# site name → Iconaut category/name (its 24 px solid drawing)
ICONS = {
    "search": "essential/search", "close": "essential/close", "moon": "weather/moon", "sun": "weather/sun",
    "arrow-left": "arrows/arrow-left", "arrow-right": "arrows/arrow-right", "chevron-right": "arrows/chevron-right",
    "start": "navigation/signpost", "walkthrough": "navigation/route", "leveling": "awards/trophy",
    "monsters": "nature/paw", "bosses": "gaming/ghost", "lands": "navigation/map", "quests": "navigation/flag",
    "items": "education/backpack", "classes": "security/shield", "skills": "ai/sparkles", "elements": "weather/wind",
    "book": "education/book", "sword": "gaming/sword", "compass": "navigation/compass",
}

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, path in ICONS.items():
        with urllib.request.urlopen(f"{RAW}/{path}/24/solid.svg") as r:
            (OUT / f"{name}.svg").write_bytes(r.read())
        print(name, "←", path)
