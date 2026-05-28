"""Render PNG sprites to PIL images for e-ink / LCD."""

from __future__ import annotations

from pathlib import Path
from typing import Optional

from assets.sprites.png_loader import sprite_path


def load_sprite_image(mood: str, size: Optional[tuple[int, int]] = None):
    path = sprite_path(mood) or sprite_path("idle")
    if path is None:
        return None
    try:
        from PIL import Image

        img = Image.open(path).convert("RGB")
        if size:
            img = img.resize(size)
        return img
    except Exception:
        return None
