#!/usr/bin/env python3
"""Generate marketing graphics for Hacker Planet LLC ecosystem (GitHub + social)."""

from __future__ import annotations

from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    raise SystemExit("pip install pillow")

ROOT = Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "docs" / "images"
SOCIAL = OUT / "social"

BG = (13, 17, 23)
PANEL = (22, 27, 34)
ACCENT = (0, 180, 140)
MAGENTA = (210, 168, 255)
WARN = (248, 81, 73)
INK = (230, 237, 243)
MUTED = (139, 148, 158)

PROJECTS = [
    {
        "slug": "cyberthreatgotchi",
        "title": "CyberThreatGotchi",
        "tagline": "Defensive edge IPS + Tamagotchi UI",
        "hardware": "Banana Pi BPI-R3 Mini",
        "accent": ACCENT,
        "icon": "unicorn",
        "url": "github.com/salvador-Data/cyberThreatGotchi",
    },
    {
        "slug": "bjorn",
        "title": "Bjorn",
        "tagline": "Authorized network assessment (Pi)",
        "hardware": "Raspberry Pi + e-Paper",
        "accent": (100, 180, 255),
        "icon": "pi",
        "url": "github.com/salvador-Data/Bjorn",
    },
    {
        "slug": "crackbot",
        "title": "Mr. CrackBot AI Nano",
        "tagline": "Wordlist & password lab assistant",
        "hardware": "Jetson Nano / dev PC",
        "accent": (255, 166, 87),
        "icon": "bot",
        "url": "github.com/salvador-Data/Mr.-CrackBot-AI-Nano",
    },
    {
        "slug": "m5-cardputer",
        "title": "M5 OS Cardputer",
        "tagline": "Pocket launcher shell",
        "hardware": "M5Stack Cardputer ESP32-S3",
        "accent": (255, 100, 130),
        "icon": "pocket",
        "url": "github.com/salvador-Data/M5_OS-Cardputer",
    },
]


def _font(size: int, bold: bool = False):
    candidates = [
        "C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _grid(draw: ImageDraw.ImageDraw, w: int, h: int, step: int = 40) -> None:
    c = (30, 38, 48)
    for x in range(0, w, step):
        draw.line([(x, 0), (x, h)], fill=c, width=1)
    for y in range(0, h, step):
        draw.line([(0, y), (w, y)], fill=c, width=1)


def _draw_icon(draw: ImageDraw.ImageDraw, kind: str, cx: int, cy: int, color) -> None:
    if kind == "unicorn":
        draw.polygon([(cx, cy - 50), (cx - 12, cy - 20), (cx + 12, cy - 20)], fill=MAGENTA)
        draw.ellipse([cx - 35, cy - 35, cx + 35, cy + 25], fill=(255, 250, 255), outline=INK)
        draw.rectangle([cx - 28, cy - 8, cx + 28, cy + 8], fill=(30, 30, 30))
        draw.rectangle([cx - 30, cy + 20, cx + 30, cy + 55], fill=(40, 40, 55))
        for ox in (-55, 55):
            draw.ellipse([cx + ox - 12, cy - 30, cx + ox + 12, cy - 6], fill=color)
    elif kind == "pi":
        draw.ellipse([cx - 40, cy - 40, cx + 40, cy + 40], outline=color, width=4)
        draw.text((cx - 18, cy - 22), "Pi", fill=color, font=_font(28, True))
    elif kind == "bot":
        draw.rectangle([cx - 35, cy - 30, cx + 35, cy + 35], fill=color)
        draw.rectangle([cx - 25, cy - 20, cx - 10, cy - 5], fill=BG)
        draw.rectangle([cx + 10, cy - 20, cx + 25, cy - 5], fill=BG)
    else:
        draw.rounded_rectangle([cx - 45, cy - 30, cx + 45, cy + 40], radius=8, outline=color, width=4)
        draw.text((cx - 20, cy - 10), "M5", fill=color, font=_font(22, True))


def _card(project: dict, size: tuple[int, int]) -> Image.Image:
    w, h = size
    img = Image.new("RGB", (w, h), BG)
    draw = ImageDraw.Draw(img)
    _grid(draw, w, h, 48)
    draw.rounded_rectangle([24, 24, w - 24, h - 24], radius=16, fill=PANEL, outline=project["accent"], width=3)
    _draw_icon(draw, project["icon"], w // 2, h // 2 - 30, project["accent"])
    draw.text((40, 40), project["title"], fill=project["accent"], font=_font(36, True))
    draw.text((40, h - 110), project["tagline"], fill=INK, font=_font(22))
    draw.text((40, h - 75), project["hardware"], fill=MUTED, font=_font(18))
    draw.text((40, h - 45), project["url"], fill=MUTED, font=_font(16))
    return img


def _banner(title: str, subtitle: str, footer: str, accent, size: tuple[int, int]) -> Image.Image:
    w, h = size
    img = Image.new("RGB", (w, h), BG)
    draw = ImageDraw.Draw(img)
    _grid(draw, w, h, 56)
    draw.rectangle([0, h - 8, w, h], fill=accent)
    draw.text((48, 48), title, fill=accent, font=_font(52, True))
    draw.text((48, 120), subtitle, fill=INK, font=_font(28))
    draw.text((48, h - 72), footer, fill=MUTED, font=_font(20))
    draw.text((w - 320, 48), "Hacker Planet LLC", fill=MAGENTA, font=_font(22, True))
    return img


def _ecosystem_poster() -> Image.Image:
    w, h = 1200, 1200
    img = Image.new("RGB", (w, h), BG)
    draw = ImageDraw.Draw(img)
    draw.text((40, 30), "Hacker Planet LLC", fill=MAGENTA, font=_font(40, True))
    draw.text((40, 85), "Desk + Field Security Toolkit", fill=INK, font=_font(24))
    positions = [(60, 160), (620, 160), (60, 620), (620, 620)]
    for proj, (x, y) in zip(PROJECTS, positions):
        card = _card(proj, (520, 420))
        img.paste(card, (x, y))
    draw.text((40, h - 50), "salvador-Data on GitHub — defensive & lab use only", fill=MUTED, font=_font(18))
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    SOCIAL.mkdir(parents=True, exist_ok=True)

    _banner(
        "CyberThreatGotchi",
        "Portable network security Tamagotchi — Cipherhorn guards your edge.",
        "Open source · BPI-R3 Mini · e-ink / web / IPS",
        ACCENT,
        (1200, 630),
    ).save(OUT / "og-cyberthreatgotchi.png")

    for proj in PROJECTS:
        _card(proj, (1200, 630)).save(OUT / f"og-{proj['slug']}.png")
        _card(proj, (1080, 1080)).save(SOCIAL / f"square-{proj['slug']}.png")

    _ecosystem_poster().save(OUT / "og-ecosystem.png")
    _ecosystem_poster().resize((1080, 1080)).save(SOCIAL / "square-ecosystem.png")

    _banner(
        "Hacker Planet LLC",
        "CyberThreatGotchi · Bjorn · CrackBot · M5 OS Cardputer",
        "github.com/salvador-Data",
        MAGENTA,
        (820, 312),
    ).save(SOCIAL / "facebook-cover.png")

    _banner(
        "CyberThreatGotchi — open source release",
        "Defensive IPS + Tamagotchi UI for homelab & SOHO",
        "u/Salvador_Data · salvador-Data GitHub",
        ACCENT,
        (1920, 384),
    ).save(SOCIAL / "reddit-banner.png")

    if not (OUT / "hero.png").is_file():
        (OUT / "og-cyberthreatgotchi.png").save(OUT / "hero.png")

    print(f"Wrote graphics to {OUT} and {SOCIAL}")


if __name__ == "__main__":
    main()
