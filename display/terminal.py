"""Terminal display — default for dev and SSH."""

from __future__ import annotations

from display.base import DisplayBackend


class TerminalDisplay(DisplayBackend):
    def __init__(self) -> None:
        self._ready = False

    def initialize(self) -> bool:
        self._ready = True
        return True

    def render_text(self, text: str, title: str = "") -> None:
        if title:
            print(f"\n=== {title} ===")
        print(text)

    def clear(self) -> None:
        print("\033[2J\033[H", end="")

    def shutdown(self) -> None:
        self._ready = False
