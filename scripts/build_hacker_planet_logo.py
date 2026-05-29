#!/usr/bin/env python3
"""Build compact Hacker Planet LLC nav wordmark (horizontal, dark-nav palette)."""

from __future__ import annotations

import colorsys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ASSETS_CURSOR = (
    Path.home() / ".cursor" / "projects" / "c-Users-Owner-Projects-cyberThreatGotchi" / "assets"
)
ASSETS_REPO = ROOT / "assets"
SRC_MASK = ASSETS_CURSOR / "hacker-planet-llc-logo-mask.png"
SRC_FALLBACK = ASSETS_CURSOR / "hacker-planet-llc-logo.png"
if not SRC_MASK.is_file():
    SRC_MASK = ASSETS_REPO / "hacker-planet-llc-logo-mask.png"
if not SRC_FALLBACK.is_file():
    SRC_FALLBACK = ASSETS_REPO / "hacker-planet-llc-logo.png"
OUT = ROOT / "website" / "images" / "hacker-planet-logo.png"

# website/css/style.css :root + .logo-img max-height: 52px
ACCENT = (0, 200, 158)
ACCENT_HI = (64, 232, 192)
INK = (248, 252, 255)
LABEL = "Hacker Planet LLC"
LABEL_FILL = (0, 217, 168)

NAV_HEIGHT = 44
NAV_MAX_WIDTH = 140
EMBLEM_HEIGHT = 36
GAP = 6


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
        mix = min(1.0, 0.55 + 0.45 * v)
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


def crop_emblem(im: Image.Image) -> Image.Image:
    """Center badge (mask + ring), drop bar scene and curved bottom tagline area."""
    w, h = im.size
    fw = int(w * 0.40)
    fh = int(h * 0.56)
    x0 = (w - fw) // 2
    y0 = int(h * 0.10)
    emblem = im.crop((x0, y0, x0 + fw, y0 + fh))
    ew, eh = emblem.size
    px = emblem.load()
    cut = int(eh * 0.80)
    for y in range(cut, eh):
        for x in range(ew):
            px[x, y] = (0, 0, 0, 0)
    return emblem


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


def _load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for name in ("segoeui.ttf", "arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _scale_emblem(emblem: Image.Image, height: int) -> Image.Image:
    w, h = emblem.size
    scale = height / h
    new_w = max(1, int(w * scale))
    return emblem.resize((new_w, height), Image.Resampling.LANCZOS)


def compose_nav_wordmark(emblem: Image.Image) -> Image.Image:
    """Horizontal lockup: compact mask emblem + company name (no slogan)."""
    emblem = _scale_emblem(emblem, EMBLEM_HEIGHT)

    font_size = 13
    font = _load_font(font_size)
    draw_probe = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    bbox = draw_probe.textbbox((0, 0), LABEL, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]

    total_w = emblem.width + GAP + tw
    total_h = max(emblem.height, th)
    if total_w > NAV_MAX_WIDTH:
        scale = NAV_MAX_WIDTH / total_w
        emblem = _scale_emblem(emblem, max(24, int(EMBLEM_HEIGHT * scale)))
        font_size = max(10, int(font_size * scale))
        font = _load_font(font_size)
        bbox = draw_probe.textbbox((0, 0), LABEL, font=font)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        total_w = emblem.width + GAP + tw
        total_h = max(emblem.height, th)

    out_h = min(NAV_HEIGHT, total_h)
    out = Image.new("RGBA", (total_w, out_h), (0, 0, 0, 0))
    ey = (out_h - emblem.height) // 2
    out.paste(emblem, (0, ey), emblem)
    draw = ImageDraw.Draw(out)
    tx = emblem.width + GAP
    ty = (out_h - th) // 2 - bbox[1]
    draw.text((tx, ty), LABEL, font=font, fill=(*LABEL_FILL, 255))
    return out


def main() -> None:
    src = SRC_MASK if SRC_MASK.is_file() else SRC_FALLBACK
    if not src.is_file():
        raise SystemExit(f"Logo source not found: {src}")

    im = recolor(src)
    emblem = crop_logo(crop_emblem(im))
    im = compose_nav_wordmark(emblem)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    im.save(OUT, format="PNG", optimize=True)
    print(f"Wrote {OUT} ({im.size[0]}x{im.size[1]}, {OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
