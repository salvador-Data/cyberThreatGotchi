#!/usr/bin/env python3
"""Generate CTG neon-lemon cursor PNGs (authorized lab use only)."""
from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("PIL/Pillow required: apt install python3-pil", file=sys.stderr)
    sys.exit(1)

# Neon lemon yellow fill + black outline ring
FILL = (255, 255, 0, 255)
RING = (0, 0, 0, 255)
SIZES = (24, 32, 48, 56, 64)
NAMES = ("left_ptr", "default", "pointer", "hand1", "hand2", "ibeam", "xterm")


def draw_pointer(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    margin = max(2, size // 16)
    ring = max(2, size // 12)
    bbox = (margin, margin, size - margin - 1, size - margin - 1)
    draw.ellipse(bbox, fill=FILL, outline=RING, width=ring)
    # Arrow tip (top-left) for left_ptr hotspot feel
    tip = max(3, size // 8)
    tri = [(margin, margin), (margin + tip * 2, margin), (margin, margin + tip * 2)]
    draw.polygon(tri, fill=FILL, outline=RING)
    return img


def main() -> int:
    out_dir = Path(__file__).resolve().parent / "png"
    out_dir.mkdir(parents=True, exist_ok=True)
    for size in SIZES:
        img = draw_pointer(size)
        path = out_dir / f"left_ptr-{size}.png"
        img.save(path)
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
