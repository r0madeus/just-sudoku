#!/usr/bin/env python3
"""The pictures at the top of the README, composed from the shots of tools/capture_readme_screenshots.gd:
phones with rounded corners and soft shadows on the app's own dark blue, a strip of the themes and
a pair of wide windows. One set per language, in docs/images/.
    python3 tools/make_readme_images.py /tmp/shots      (needs Pillow)
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "docs", "images")
FONT = os.path.join(REPO, "assets", "fonts", "Inter[opsz,wght].ttf")
BG_FROM = (14, 17, 23)
BG_TO = (23, 41, 74)
GLOW = (37, 99, 235)
THEME_NAMES = {"en": ["Dark", "Light", "AMOLED"], "tr": ["Koyu", "Açık", "AMOLED"]}


def backdrop(w, h):
    """The icon's dark blue, from the top left to the bottom right, with a soft glow in the middle."""
    base = Image.new("RGB", (w, h))
    px = base.load()
    for y in range(h):
        for x in range(w):
            t = (x / w * 0.6 + y / h * 0.4)
            px[x, y] = tuple(round(BG_FROM[i] + (BG_TO[i] - BG_FROM[i]) * t) for i in range(3))
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse((w * 0.2, h * 0.15, w * 0.8, h * 0.95), fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(min(w, h) * 0.18))
    return Image.composite(Image.new("RGB", (w, h), GLOW), base, glow)


def rounded(img, radius):
    img = img.convert("RGBA")
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.width - 1, img.height - 1), radius, fill=255)
    img.putalpha(mask)
    edge = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle((0, 0, img.width - 1, img.height - 1), radius, outline=(255, 255, 255, 38), width=3)
    return Image.alpha_composite(img, edge)


def place(canvas, shot, x, y, height, radius):
    w = round(shot.width * height / shot.height)
    card = rounded(shot.resize((w, height), Image.LANCZOS), radius)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 120), (x, y + 18), card.split()[3])
    shadow = shadow.filter(ImageFilter.GaussianBlur(26))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(card, (x, y))
    return w


def phones(shots, loc, names, height, gap, stagger, caption_names=None):
    widths = [round(s.width * height / s.height) for s in shots]
    margin = 90
    cap = 90 if caption_names else 0
    w = sum(widths) + gap * (len(shots) - 1) + 2 * margin
    h = height + max(stagger) + 2 * 40 + cap
    canvas = backdrop(w, h).convert("RGBA")
    x = margin
    font = ImageFont.truetype(FONT, 40) if caption_names else None
    for i, shot in enumerate(shots):
        place(canvas, shot, x, 40 + stagger[i], height, 60)
        if caption_names:
            d = ImageDraw.Draw(canvas)
            tw = d.textlength(caption_names[i], font=font)
            d.text((x + (widths[i] - tw) / 2, 40 + height + max(stagger) + 22), caption_names[i], font=font, fill=(226, 232, 240))
        x += widths[i] + gap
    return canvas.convert("RGB")


def windows(shots, height, gap):
    widths = [round(s.width * height / s.height) for s in shots]
    margin = 90
    w = sum(widths) + gap * (len(shots) - 1) + 2 * margin
    canvas = backdrop(w, height + 2 * 70).convert("RGBA")
    x = margin
    for i, shot in enumerate(shots):
        place(canvas, shot, x, 70, height, 28)
        x += widths[i] + gap
    return canvas.convert("RGB")


def main():
    shots_dir = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)

    def shot(name):
        return Image.open(os.path.join(shots_dir, name + ".png")).convert("RGB")

    for loc in ("en", "tr"):
        hero = phones([shot(f"{loc}_menu"), shot(f"{loc}_game"), shot(f"{loc}_game_amoled"), shot(f"{loc}_settings")],
                      loc, None, 980, 52, [64, 0, 64, 0])
        hero.save(os.path.join(OUT, f"hero_{loc}.jpg"), quality=90, optimize=True, progressive=True)
        themes = phones([shot(f"{loc}_game"), shot(f"{loc}_game_light"), shot(f"{loc}_game_amoled")],
                        loc, None, 860, 64, [0, 0, 0], THEME_NAMES[loc])
        themes.save(os.path.join(OUT, f"themes_{loc}.jpg"), quality=90, optimize=True, progressive=True)
        wide = windows([shot(f"tablet_{loc}_statistics"), shot(f"tablet_{loc}_game")], 560, 64)
        wide.save(os.path.join(OUT, f"wide_{loc}.jpg"), quality=90, optimize=True, progressive=True)
        print("made the pictures for", loc)


if __name__ == "__main__":
    main()
