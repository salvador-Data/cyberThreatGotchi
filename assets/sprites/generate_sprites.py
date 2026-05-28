#!/usr/bin/env python3
"""Generate 1-bit friendly PNG sprites — unicorn CISO + mask + suit + cats."""

from __future__ import annotations

from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    raise SystemExit("Install Pillow: pip install pillow")

OUT = Path(__file__).resolve().parent / "png"
W, H = 128, 128
MOODS = ("idle", "happy", "alert", "attack", "sleep", "feed", "defend")

# Palette (RGB) — e-ink dithers to 1-bit on device
BG = (245, 245, 250)
INK = (20, 20, 40)
ACCENT = (0, 180, 140)
WARN = (220, 60, 60)
SUIT = (40, 40, 55)
MASK = (30, 30, 30)
HORN = (180, 160, 255)
CAT = (80, 80, 100)


def _cat(draw: ImageDraw.ImageDraw, x: int, y: int, scale: int = 1) -> None:
    s = scale
    draw.polygon([(x, y), (x + 4 * s, y - 6 * s), (x + 8 * s, y)], fill=CAT)
    draw.ellipse([x + 1 * s, y, x + 7 * s, y + 6 * s], fill=CAT)
    draw.ellipse([x + 2 * s, y + 2 * s, x + 3 * s, y + 3 * s], fill=INK)
    draw.ellipse([x + 5 * s, y + 2 * s, x + 6 * s, y + 3 * s], fill=INK)


def _unicorn(draw: ImageDraw.ImageDraw, mood: str, bob: int = 0) -> None:
    cx, cy = 64, 72 + bob
    # Horn
    draw.polygon([(cx, cy - 38), (cx - 6, cy - 18), (cx + 6, cy - 18)], fill=HORN)
    # Head
    draw.ellipse([cx - 22, cy - 28, cx + 22, cy + 8], fill=(255, 250, 255), outline=INK)
    # Guy Fawkes mask band
    draw.rectangle([cx - 18, cy - 12, cx + 18, cy + 2], fill=MASK)
    eye_y = cy - 6
    if mood == "sleep":
        draw.line([(cx - 12, eye_y), (cx - 4, eye_y)], fill=ACCENT, width=2)
        draw.line([(cx + 4, eye_y), (cx + 12, eye_y)], fill=ACCENT, width=2)
    elif mood in ("alert", "attack"):
        draw.ellipse([cx - 14, eye_y - 3, cx - 6, eye_y + 5], fill=WARN if mood == "attack" else ACCENT)
        draw.ellipse([cx + 6, eye_y - 3, cx + 14, eye_y + 5], fill=WARN if mood == "attack" else ACCENT)
    else:
        draw.ellipse([cx - 14, eye_y - 2, cx - 6, eye_y + 4], fill=ACCENT)
        draw.ellipse([cx + 6, eye_y - 2, cx + 14, eye_y + 4], fill=ACCENT)
    if mood == "happy":
        draw.arc([cx - 8, cy + 2, cx + 8, cy + 12], 0, 180, fill=ACCENT, width=2)
    # Business suit torso
    draw.rectangle([cx - 20, cy + 8, cx + 20, cy + 36], fill=SUIT, outline=INK)
    draw.line([(cx, cy + 8), (cx, cy + 36)], fill=INK, width=1)
    # Tie
    draw.polygon([(cx - 4, cy + 10), (cx + 4, cy + 10), (cx, cy + 28)], fill=ACCENT)
    # Arms
    draw.rectangle([cx - 32, cy + 12, cx - 20, cy + 28], fill=SUIT)
    draw.rectangle([cx + 20, cy + 12, cx + 32, cy + 28], fill=SUIT)
    if mood == "attack":
        draw.rectangle([cx - 38, cy + 8, cx - 28, cy + 24], fill=WARN, outline=INK)
        draw.rectangle([cx + 28, cy + 8, cx + 38, cy + 24], fill=WARN, outline=INK)
    # Legs
    draw.rectangle([cx - 14, cy + 36, cx - 4, cy + 48], fill=INK)
    draw.rectangle([cx + 4, cy + 36, cx + 14, cy + 48], fill=INK)


def _frame(mood: str, anim: int = 0) -> Image.Image:
    bob = 2 if anim % 2 else 0
    cat_bob = 1 if anim % 2 else 0
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    _cat(draw, 8, 20 + cat_bob, 2)
    _cat(draw, 96, 18 + cat_bob, 2)
    _cat(draw, 14, 96 - cat_bob, 2)
    _cat(draw, 100, 94 - cat_bob, 2)
    if mood == "feed":
        draw.ellipse([52, 100, 76, 112], fill=ACCENT)
        draw.text((56, 102), "PCAP", fill=INK)
    _unicorn(draw, mood, bob=bob)
    label = mood.upper()[:8]
    draw.text((4, 4), label, fill=INK)
    if mood == "defend":
        draw.text((4, H - 14), "CISO", fill=ACCENT)
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    count = 0
    for mood in MOODS:
        for anim in (0, 1):
            path = OUT / f"{mood}_{anim}.png"
            _frame(mood, anim).save(path, optimize=True)
            print(f"Wrote {path}")
            count += 1
        legacy = OUT / f"{mood}.png"
        _frame(mood, 0).save(legacy, optimize=True)
        count += 1
    print(f"Done — {count} sprites in {OUT}")


if __name__ == "__main__":
    main()
