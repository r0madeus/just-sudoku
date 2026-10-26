#!/usr/bin/env python3
"""Turns the shots of tools/capture_readme_screenshots.gd into the store screenshots in
fastlane/metadata/android/<locale>/images/, which the README shows too: phone shots scaled to
540x1170, tablet shots to 1280x800, as JPEG (the backdrop gradients make PNGs five times larger).
    python3 tools/screenshots_to_fastlane.py /tmp/shots      (needs Pillow)
"""
import os
import sys

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCALES = {"en": "en-US", "tr": "tr-TR"}
# Store order: the first one is the one stores show first
PHONE = ["menu", "game", "game_light", "game_amoled", "result", "statistics", "settings"]
TABLET = ["statistics", "game"]


def save(src, dst, size):
    Image.open(src).convert("RGB").resize(size, Image.LANCZOS).save(dst, quality=88, optimize=True, progressive=True)
    print(dst)


def main():
    shots = sys.argv[1]
    for loc, locale in LOCALES.items():
        base = os.path.join(REPO, "fastlane", "metadata", "android", locale, "images")
        for kind, names, prefix, size in [("phoneScreenshots", PHONE, "", (540, 1170)),
                                          ("tenInchScreenshots", TABLET, "tablet_", (1280, 800))]:
            os.makedirs(os.path.join(base, kind), exist_ok=True)
            for i, name in enumerate(names):
                save(os.path.join(shots, f"{prefix}{loc}_{name}.png"),
                     os.path.join(base, kind, f"{i + 1}_{name}.jpg"), size)


if __name__ == "__main__":
    main()
