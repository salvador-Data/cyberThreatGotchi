"""Small color LCD (ILI9341 SPI) — smoother animation on portable unit."""

from __future__ import annotations

import platform

from display.base import DisplayBackend
from display.sprite_renderer import compose_sprite_canvas
from display.terminal import TerminalDisplay


class LCDDisplay(DisplayBackend):
    def __init__(self) -> None:
        self._device = None
        self._fallback = TerminalDisplay()

    def initialize(self) -> bool:
        if platform.system() != "Linux":
            return self._fallback.initialize()
        try:
            from luma.core.interface.serial import spi
            from luma.lcd.device import ili9341

            serial = spi(port=0, device=0, gpio_DC=24, gpio_RST=25)
            self._device = ili9341(serial, width=240, height=320, rotate=2)
            return True
        except Exception:
            return self._fallback.initialize()

    def render_sprite(self, mood: str, title: str = "", frame: int = 0) -> None:
        if not self._device:
            self._fallback.render_text(f"[{mood}] {title}", title="LCD")
            return
        try:
            img = compose_sprite_canvas(
                mood,
                frame,
                self._device.size,
                mono=False,
                title=title or "CyberThreatGotchi",
            )
            if img is None:
                self.render_text("", title=title)
                return
            self._device.display(img)
        except Exception:
            self.render_text("", title=title)

    def render_text(self, text: str, title: str = "") -> None:
        if not self._device:
            self._fallback.render_text(text, title=title)
            return
        try:
            from PIL import Image, ImageDraw, ImageFont

            img = Image.new("RGB", self._device.size, (10, 10, 30))
            draw = ImageDraw.Draw(img)
            font = ImageFont.load_default()
            draw.text((4, 4), title or "CyberThreatGotchi", fill=(0, 255, 180), font=font)
            y = 20
            for line in text.split("\n")[:18]:
                draw.text((4, y), line[:40], fill=(220, 220, 255), font=font)
                y += 12
            self._device.display(img)
        except Exception:
            self._fallback.render_text(text, title=title)

    def clear(self) -> None:
        if self._device:
            try:
                self._device.clear()
            except Exception:
                pass

    def shutdown(self) -> None:
        self.clear()
