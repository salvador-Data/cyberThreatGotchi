"""Intrusion Prevention — block/quarantine suspicious sources."""

from __future__ import annotations

import platform
import subprocess
import time
from dataclasses import dataclass, field
from typing import Optional

from config.settings import IPS_AUTO_BLOCK_THRESHOLD, IPS_BLOCK_DURATION_SEC, IPS_ENABLED
from core.detector import ThreatEvent


@dataclass
class BlockEntry:
    ip: str
    reason: str
    blocked_at: float
    expires_at: float
    score: int


class IntrusionPreventionSystem:
    def __init__(
        self,
        enabled: bool = IPS_ENABLED,
        block_duration: int = IPS_BLOCK_DURATION_SEC,
        threshold: int = IPS_AUTO_BLOCK_THRESHOLD,
    ) -> None:
        self.enabled = enabled
        self.block_duration = block_duration
        self.threshold = threshold
        self._blocks: dict[str, BlockEntry] = {}
        self._scores: dict[str, int] = {}
        self.actions_taken = 0

    def process_threat(self, event: ThreatEvent) -> str:
        if not self.enabled:
            return "monitor_only"

        self._scores[event.source_ip] = self._scores.get(event.source_ip, 0) + event.score
        cumulative = self._scores[event.source_ip]

        if cumulative >= self.threshold:
            if self.block_ip(event.source_ip, event.description, event.score):
                return "blocked"
            return "block_failed"

        if event.severity in ("critical", "high"):
            return "alert_escalated"
        return "logged"

    def block_ip(self, ip: str, reason: str, score: int) -> bool:
        now = time.time()
        entry = BlockEntry(
            ip=ip,
            reason=reason,
            blocked_at=now,
            expires_at=now + self.block_duration,
            score=score,
        )
        self._blocks[ip] = entry
        self.actions_taken += 1
        return self._apply_firewall_rule(ip, add=True)

    def unblock_ip(self, ip: str) -> bool:
        self._blocks.pop(ip, None)
        self._scores.pop(ip, None)
        return self._apply_firewall_rule(ip, add=False)

    def is_blocked(self, ip: str) -> bool:
        entry = self._blocks.get(ip)
        if not entry:
            return False
        if time.time() > entry.expires_at:
            self.unblock_ip(ip)
            return False
        return True

    def active_blocks(self) -> list[BlockEntry]:
        self._purge_expired()
        return list(self._blocks.values())

    def _purge_expired(self) -> None:
        now = time.time()
        expired = [ip for ip, e in self._blocks.items() if now > e.expires_at]
        for ip in expired:
            self.unblock_ip(ip)

    def _apply_firewall_rule(self, ip: str, add: bool) -> bool:
        if platform.system() == "Linux":
            cmd = ["iptables", "-D" if not add else "-I", "INPUT", "-s", ip, "-j", "DROP"]
            if not add:
                cmd = ["iptables", "-D", "INPUT", "-s", ip, "-j", "DROP"]
            try:
                subprocess.run(cmd, check=False, capture_output=True, timeout=10)
                return True
            except (FileNotFoundError, subprocess.TimeoutExpired):
                pass
        # Simulation / Windows — track logically only
        return True
