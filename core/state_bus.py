"""Thread-safe shared state for CLI, web dashboard, and displays."""

from __future__ import annotations

import threading
from dataclasses import asdict, dataclass, field
from typing import Any


@dataclass
class GotchiSnapshot:
    name: str
    mood: str
    hunger: int
    happiness: int
    security_xp: int
    level: int
    threats_blocked: int
    threats_seen: int
    status_line: str
    sprite_ascii: str = ""


class StateBus:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._gotchi = GotchiSnapshot(
            name="Cipherhorn",
            mood="idle",
            hunger=80,
            happiness=80,
            security_xp=0,
            level=1,
            threats_blocked=0,
            threats_seen=0,
            status_line="Initializing",
        )
        self._threats: list[dict[str, Any]] = []
        self._blocks: list[dict[str, Any]] = []
        self._mode = "simulation"
        self._interface = ""
        self._av_status: dict[str, bool] = {}
        self._scanned = 0
        self._detector_threats = 0

    def update_gotchi(self, snap: GotchiSnapshot) -> None:
        with self._lock:
            self._gotchi = snap

    def push_threat(self, row: dict[str, Any]) -> None:
        with self._lock:
            self._threats.insert(0, row)
            self._threats = self._threats[:30]

    def set_blocks(self, blocks: list[dict[str, Any]]) -> None:
        with self._lock:
            self._blocks = blocks

    def set_runtime(
        self,
        mode: str,
        interface: str,
        av_status: dict[str, bool],
        scanned: int,
        threats: int,
    ) -> None:
        with self._lock:
            self._mode = mode
            self._interface = interface
            self._av_status = av_status
            self._scanned = scanned
            self._detector_threats = threats

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            return {
                "gotchi": asdict(self._gotchi),
                "threats": list(self._threats),
                "blocks": list(self._blocks),
                "runtime": {
                    "mode": self._mode,
                    "interface": self._interface,
                    "av": dict(self._av_status),
                    "packets_scanned": self._scanned,
                    "threats_detected": self._detector_threats,
                },
            }
