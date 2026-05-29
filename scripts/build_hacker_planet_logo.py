#!/usr/bin/env python3
"""Tint Hacker Planet LLC logo for website nav (--accent teal palette)."""

from __future__ import annotations

import colorsys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ASSETS = Path.home() / ".cursor" / "projects" / "c-Users-Owner-Projects-cyberThreatGotchi" / "assets"
SRC_MASK = ASSETS / "hacker-planet-llc-logo-mask.png"
SRC_FALLBACK = ASSETS / "hacker-planet-llc-logo.png"
OUT = ROOT / "website" / "images" / "hacker-planet-logo.png"

# website/css/style.css :root
ACCENT = (0, 180, 140)  # #00b48c
ACCENT_HI = (0, 217, 168)  # brighter teal for former cyan neon
INK = (230, 237, 243)  # #e6edf3 highlights on mask/face


def _recolor_pixel(r: int, g: int, b: int) -> tuple[int, int, int, int]:
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b

    if v < 0.08 or (s < 0.12 and lum < 40):
        return (0, 0, 0, 0)

    if s > 0.45 and v > 0.25:
        if h >= 0.78 or h <= 0.08:
            base = ACCENT
        elif 0.42 <= h <= 0.62:
            base = ACCENT_HI
        else:
            base = ACCENT
        mix = min(1.0, 0.35 + 0.65 * v)
        nr = int(base[0] * mix + r * (1 - mix))
        ng = int(base[1] * mix + g * (1 - mix))
        nb = int(base[2] * mix + b * (1 - mix))
        alpha = int(min(255, 80 + 175 * s * v))
        return (nr, ng, nb, alpha)

    if lum > 200 and s < 0.15:
        return (*INK, int(min(255, lum)))

    alpha = int(min(255, max(0, (lum - 18) * 1.1)))
    return (r, g, b, alpha)


def recolor(src: Path) -> Image.Image:
    im = Image.open(src).convert("RGB")
    w, h = im.size
    out = Image.new("RGBA", (w, h))
    px_in = im.load()
    px_out = out.load()
    for y in range(h):
        for x in range(w):
            px_out[x, y] = _recolor_pixel(*px_in[x, y][:3])
    return out


def crop_logo(im: Image.Image) -> Image.Image:
    bbox = im.getbbox()
    if not bbox:
        return im
    x0, y0, x1, y1 = bbox
    pad = int(max(x1 - x0, y1 - y0) * 0.04)
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(im.width, x1 + pad)
    y1 = min(im.height, y1 + pad)
    return im.crop((x0, y0, x1, y1))


def resize_nav(im: Image.Image, height: int = 96) -> Image.Image:
    w, h = im.size
    scale = height / h
    new_w = max(1, int(w * scale))
    return im.resize((new_w, height), Image.Resampling.LANCZOS)


def main() -> None:
    src = SRC_MASK if SRC_MASK.is_file() else SRC_FALLBACK
    if not src.is_file():
        raise SystemExit(f"Logo source not found: {src}")

    im = recolor(src)
    im = crop_logo(im)
    im = resize_nav(im, height=96)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    im.save(OUT, format="PNG", optimize=True)
    print(f"Wrote {OUT} ({im.size[0]}x{im.size[1]}, {OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
