"""Display backend factory."""

from __future__ import annotations

from config.settings import DISPLAY_BACKEND
from display.base import DisplayBackend
from display.eink import EInkDisplay
from display.lcd import LCDDisplay
from display.terminal import TerminalDisplay


def create_display(backend: str | None = None) -> DisplayBackend:
    name = (backend or DISPLAY_BACKEND).lower()
    if name == "eink":
        return EInkDisplay()
    if name == "lcd":
        return LCDDisplay()
    return TerminalDisplay()
