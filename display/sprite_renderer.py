"""Shared PNG sprite rendering for e-ink and LCD backends."""

from __future__ import annotations

from typing import Optional, Tuple

from assets.sprites.png_loader import sprite_path


def load_sprite_image(
    mood: str,
    frame: int = 0,
    size: Optional[tuple[int, int]] = None,
):
    path = sprite_path(mood, frame) or sprite_path("idle", frame) or sprite_path("idle", 0)
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


def compose_sprite_canvas(
    mood: str,
    frame: int,
    canvas_size: Tuple[int, int],
    *,
    mono: bool = True,
    title: str = "",
    bg_mono: int = 255,
    bg_rgb: Tuple[int, int, int] = (10, 10, 30),
):
    """Build a PIL image with centered sprite and optional title bar."""
    from PIL import Image, ImageDraw, ImageFont

    sprite = load_sprite_image(mood, frame)
    if sprite is None:
        return None

    w, h = canvas_size
    if mono:
        image = Image.new("1", (w, h), bg_mono)
    else:
        image = Image.new("RGB", (w, h), bg_rgb)

    gray = sprite.convert("L")
    if mono:
        mono_sprite = gray.point(lambda x: 0 if x < 140 else 255, "1")
        x = (w - mono_sprite.width) // 2
        y = max(2, (h - mono_sprite.height) // 2 - 6)
        image.paste(mono_sprite, (x, y))
    else:
        scaled = sprite.resize((min(w - 8, 128), min(h - 24, 128)))
        x = (w - scaled.width) // 2
        y = 4
        image.paste(scaled, (x, y))

    if title:
        draw = ImageDraw.Draw(image)
        try:
            font = ImageFont.truetype(
                "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 9
            )
        except OSError:
            font = ImageFont.load_default()
        fill = 0 if mono else (0, 255, 180)
        draw.text((2, h - 14), title[:32], font=font, fill=fill)

    return image
