"""Abstract display backend."""

from __future__ import annotations

from abc import ABC, abstractmethod


class DisplayBackend(ABC):
    @abstractmethod
    def initialize(self) -> bool:
        ...

    @abstractmethod
    def render_text(self, text: str, title: str = "") -> None:
        ...

    @abstractmethod
    def clear(self) -> None:
        ...

    @abstractmethod
    def shutdown(self) -> None:
        ...
