"""Traffic analysis — aggregates packets into inspectable summaries."""

from __future__ import annotations

import time
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Optional

from core.sniffer import RawPacket
from rules.signatures import SCAN_THRESHOLD_PACKETS, SCAN_WINDOW_SECONDS, is_suspicious_port


@dataclass
class PacketSummary:
    timestamp: float
    src_ip: str
    dst_ip: str
    src_port: Optional[int]
    dst_port: Optional[int]
    protocol: str
    payload_text: str
    payload_size: int
    flags: list[str] = field(default_factory=list)
    risk_hints: list[str] = field(default_factory=list)


class PacketAnalyzer:
    def __init__(self) -> None:
        self._src_counts: dict[str, list[float]] = defaultdict(list)

    def analyze(self, packet: RawPacket) -> PacketSummary:
        payload_text = self._safe_decode(packet.payload)
        flags: list[str] = []
        hints: list[str] = []

        if is_suspicious_port(packet.dst_port) or is_suspicious_port(packet.src_port):
            hints.append("suspicious_port")

        if packet.length > 1400:
            hints.append("large_frame")

        if self._detect_port_scan(packet.src_ip):
            flags.append("port_scan")
            hints.append("scan_behavior")

        if any(c in payload_text for c in ("<script", "javascript:", "onerror=")):
            hints.append("xss_hint")

        return PacketSummary(
            timestamp=packet.timestamp,
            src_ip=packet.src_ip,
            dst_ip=packet.dst_ip,
            src_port=packet.src_port,
            dst_port=packet.dst_port,
            protocol=packet.protocol,
            payload_text=payload_text,
            payload_size=len(packet.payload),
            flags=flags,
            risk_hints=hints,
        )

    def _detect_port_scan(self, src_ip: str) -> bool:
        now = time.time()
        window = self._src_counts[src_ip]
        window = [t for t in window if now - t < SCAN_WINDOW_SECONDS]
        window.append(now)
        self._src_counts[src_ip] = window
        return len(window) >= SCAN_THRESHOLD_PACKETS

    @staticmethod
    def _safe_decode(data: bytes, limit: int = 4096) -> str:
        if not data:
            return ""
        return data[:limit].decode("utf-8", errors="replace")
