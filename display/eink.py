"""E-ink SPI display driver (Waveshare 2.13\" / 2.9\" class).

Requires Linux + spidev on BPI-R3 Mini. Falls back to terminal if unavailable.
"""

from __future__ import annotations

import platform

from display.base import DisplayBackend
from display.terminal import TerminalDisplay


class EInkDisplay(DisplayBackend):
    def __init__(self, width: int = 250, height: int = 122) -> None:
        self.width = width
        self.height = height
        self._epd = None
        self._fallback = TerminalDisplay()

    def initialize(self) -> bool:
        if platform.system() != "Linux":
            return self._fallback.initialize()
        try:
            from PIL import Image, ImageDraw, ImageFont  # noqa: F401

            # Waveshare epd2in13 or compatible — import varies by install
            try:
                from waveshare_epd import epd2in13_v4  # type: ignore

                self._epd = epd2in13_v4.EPD()
            except ImportError:
                return self._fallback.initialize()
            self._epd.init()
            self._epd.clear(0xFF)
            return True
        except Exception:
            return self._fallback.initialize()

    def render_sprite(self, mood: str, title: str = "") -> None:
        """Draw PNG mascot frame when available."""
        from display.sprite_display import load_sprite_image

        sprite = load_sprite_image(mood, size=(min(self.width, 122), 80))
        if sprite is None:
            self.render_text("", title=title)
            return
        if self._epd is None:
            self._fallback.render_text(f"[{mood}] {title}", title="e-ink")
            return
        try:
            from PIL import Image, ImageDraw, ImageFont

            image = Image.new("1", (self._epd.width, self._epd.height), 255)
            gray = sprite.convert("L")
            mono = gray.point(lambda x: 0 if x < 140 else 255, "1")
            image.paste(mono, ((self._epd.width - mono.width) // 2, 4))
            if title:
                draw = ImageDraw.Draw(image)
                try:
                    font = ImageFont.truetype(
                        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 9
                    )
                except OSError:
                    font = ImageFont.load_default()
                draw.text((0, self._epd.height - 14), title[:28], font=font, fill=0)
            self._epd.display(self._epd.getbuffer(image))
        except Exception:
            self.render_text("", title=title)

    def render_text(self, text: str, title: str = "") -> None:
        if self._epd is None:
            self._fallback.render_text(text, title=title)
            return
        try:
            from PIL import Image, ImageDraw, ImageFont

            image = Image.new("1", (self._epd.width, self._epd.height), 255)
            draw = ImageDraw.Draw(image)
            try:
                font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 10)
            except OSError:
                font = ImageFont.load_default()
            y = 0
            if title:
                draw.text((0, y), title[:32], font=font, fill=0)
                y += 12
            for line in text.split("\n")[:10]:
                draw.text((0, y), line[:38], font=font, fill=0)
                y += 11
            self._epd.display(self._epd.getbuffer(image))
        except Exception:
            self._fallback.render_text(text, title=title)

    def clear(self) -> None:
        if self._epd:
            try:
                self._epd.clear(0xFF)
            except Exception:
                pass

    def shutdown(self) -> None:
        if self._epd:
            try:
                self._epd.sleep()
            except Exception:
                pass
