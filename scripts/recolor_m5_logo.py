"""Recolor M5 OS logo to Hacker Planet site palette (--accent / hover teal)."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

SRC = Path(
    r"C:\Users\Owner\.cursor\projects\c-Users-Owner-Projects-cyberThreatGotchi\assets\m5-os-logo.png"
)
OUT = Path(__file__).resolve().parents[1] / "website" / "images" / "m5-os-logo.png"

# From website/css/style.css :root
ACCENT = np.array([0, 180, 140], dtype=np.float32)  # #00b48c
ACCENT_HOVER = np.array([51, 212, 176], dtype=np.float32)  # #33d4b0
BG = np.array([10, 14, 20], dtype=np.float32)  # #0a0e14


def _luminance(rgb: np.ndarray) -> np.ndarray:
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114


def recolor_logo(src: Path, out: Path) -> None:
    img = Image.open(src).convert("RGBA")
    arr = np.array(img, dtype=np.float32)
    rgb = arr[..., :3]
    alpha = arr[..., 3]

    lum = _luminance(rgb)
    colored = lum > 35

    pink = colored & (rgb[..., 0] > rgb[..., 1] + 20) & (rgb[..., 0] > rgb[..., 2] - 10)
    cyan = colored & (rgb[..., 2] > rgb[..., 0] + 15) & (rgb[..., 1] > rgb[..., 0])
    other_colored = colored & ~pink & ~cyan

    out_rgb = rgb.copy()
    for mask, target in (
        (pink, ACCENT),
        (cyan, ACCENT_HOVER),
        (other_colored, ACCENT),
    ):
        if not mask.any():
            continue
        src_lum = np.clip(lum[mask], 1.0, 255.0)
        target_lum = np.clip(_luminance(target.reshape(1, 3)), 1.0, 255.0)
        scale = (src_lum / target_lum).reshape(-1, 1)
        shifted = np.clip(target.reshape(1, 3) * scale, 0, 255)
        out_rgb[mask] = shifted

    # Dark background: blend toward site bg; transparent at edges for nav overlay
    dark = ~colored
    bg_strength = np.clip(1.0 - lum / 35.0, 0.0, 1.0)
    out_rgb[dark] = rgb[dark] * (1.0 - bg_strength[dark, None]) + BG * bg_strength[dark, None]

    result = np.zeros_like(arr)
    result[..., :3] = np.clip(out_rgb, 0, 255)
    result[..., 3] = alpha
    # Slight transparency on near-black pixels so nav backdrop shows through
    result[..., 3] = np.where(lum < 12, 0, result[..., 3])

    out.parent.mkdir(parents=True, exist_ok=True)
    logo = Image.fromarray(result.astype(np.uint8), "RGBA")

    # Web nav size + 2x for retina
    nav_h = 56
    aspect = logo.width / logo.height
    nav_w = max(1, int(nav_h * aspect))
    nav_size = logo.resize((nav_w, nav_h), Image.Resampling.LANCZOS)
    nav_size.save(out, optimize=True)

    # Also save full-size themed variant for hero/product use
    full_out = out.with_name("m5-os-logo-full.png")
    logo.save(full_out, optimize=True)
    print(f"Wrote {out} ({nav_w}x{nav_h}) and {full_out} ({logo.width}x{logo.height})")


if __name__ == "__main__":
    recolor_logo(SRC, OUT)
