#!/usr/bin/env python3
"""Generate Gatekeeper.TOR tray PNG icons from SVG sources (dev/build helper)."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets" / "gatekeeper-tor"

PAIRS = (
    ("logo-tor-on.svg", "logo-tor-on.png"),
    ("logo-tor-off.svg", "logo-tor-off.png"),
    ("logo-https-on.svg", "logo-https-on.png"),
    ("logo-https-off.svg", "logo-https-off.png"),
)


def _via_pillow(svg: Path, png: Path) -> bool:
    try:
        from PIL import Image, ImageDraw  # type: ignore[import-untyped]
    except ImportError:
        return False

    name = svg.stem
    lit = "on" in name
    https = "https" in name
    size = 64
    img = Image.new("RGBA", (size, size), (13, 17, 23, 255))
    draw = ImageDraw.Draw(img)

    if lit:
        shield = (184, 255, 0, 255) if not https else (0, 180, 255, 255)
        letter = (232, 255, 102, 255) if not https else (102, 224, 255, 255)
        dot = (184, 255, 0, 255) if not https else (0, 180, 255, 255)
    else:
        shield = (61, 68, 80, 255)
        letter = (92, 99, 112, 255)
        dot = None

    pts = [(32, 8), (50, 15), (50, 30), (32, 56), (14, 30), (14, 15)]
    draw.polygon(pts, fill=shield)
    inner = [(32, 16), (42, 20), (42, 29), (32, 46), (22, 29), (22, 20)]
    draw.polygon(inner, fill=(13, 17, 23, 255))
    draw.text((32, 28), "G", fill=letter, anchor="mm")
    if dot:
        draw.ellipse((47, 7, 57, 17), fill=dot)
    img.save(png, format="PNG")
    return True


def _via_inkscape(svg: Path, png: Path) -> bool:
    for cmd in ("inkscape", "magick", "convert"):
        exe = __import__("shutil").which(cmd)
        if not exe:
            continue
        try:
            if cmd == "inkscape":
                subprocess.run(
                    [exe, str(svg), "-o", str(png), "-w", "64", "-h", "64"],
                    check=True,
                    timeout=30,
                    capture_output=True,
                )
            else:
                subprocess.run(
                    [exe, str(svg), "-resize", "64x64", str(png)],
                    check=True,
                    timeout=30,
                    capture_output=True,
                )
            return png.is_file()
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
            continue
    return False


def main() -> int:
    ASSETS.mkdir(parents=True, exist_ok=True)
    for svg_name, png_name in PAIRS:
        svg = ASSETS / svg_name
        png = ASSETS / png_name
        if not svg.is_file():
            print(f"Missing SVG: {svg}", file=sys.stderr)
            return 1
        if _via_pillow(svg, png) or _via_inkscape(svg, png):
            print(f"Wrote {png}")
        else:
            print(
                "Install Pillow to generate PNGs: pip install Pillow",
                file=sys.stderr,
            )
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
