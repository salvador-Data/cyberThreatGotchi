"""E-ink SPI display driver (Waveshare 2.13\" / 2.9\" class).

Requires Linux + spidev on BPI-R3 Mini. Falls back to terminal if unavailable.
"""

from __future__ import annotations

import platform

from display.base import DisplayBackend
from display.sprite_renderer import compose_sprite_canvas
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

    def render_sprite(self, mood: str, title: str = "", frame: int = 0) -> None:
        if self._epd is None:
            self._fallback.render_text(f"[{mood}] {title}", title="e-ink")
            return
        try:
            image = compose_sprite_canvas(
                mood,
                frame,
                (self._epd.width, self._epd.height),
                mono=True,
                title=title,
            )
            if image is None:
                self.render_text("", title=title)
                return
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
