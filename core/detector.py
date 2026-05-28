"""Threat detection orchestrator — signatures, AV, scoring."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable, Optional

from config.settings import Settings, load_settings
from core.analyzer import PacketAnalyzer, PacketSummary
from core.antivirus import AntivirusEngine
from core.sniffer import RawPacket
from rules.signatures import match_payload


@dataclass
class ThreatEvent:
    severity: str
    category: str
    source_ip: str
    dest_ip: str
    description: str
    score: int
    signatures: list[str] = field(default_factory=list)
    av_hits: list[str] = field(default_factory=list)
    metadata: dict = field(default_factory=dict)


class ThreatDetector:
    def __init__(
        self,
        settings: Optional[Settings] = None,
        on_threat: Optional[Callable[[ThreatEvent], None]] = None,
    ) -> None:
        self.settings = settings or load_settings()
        self.on_threat = on_threat
        self.analyzer = PacketAnalyzer()
        self.av = AntivirusEngine()
        self.total_scanned = 0
        self.total_threats = 0

    def inspect_packet(self, packet: RawPacket) -> Optional[ThreatEvent]:
        self.total_scanned += 1
        summary = self.analyzer.analyze(packet)
        score = 0
        sig_names: list[str] = []
        av_hits: list[str] = []
        categories: set[str] = set()

        for sig in match_payload(summary.payload_text):
            score += sig.score
            sig_names.append(sig.name)
            categories.add(sig.category)

        for av in self.av.scan_payload(packet.payload):
            if av.hit:
                score += av.score
                av_hits.append(av.detail)
                categories.add("malware")

        if "port_scan" in summary.flags:
            score += self.settings.weights.port_scan
            categories.add("recon")

        for hint in summary.risk_hints:
            if hint == "suspicious_port":
                score += 2
            elif hint == "xss_hint":
                score += 4
                categories.add("web_attack")

        if score < 5:
            return None

        severity = self._severity(score)
        event = ThreatEvent(
            severity=severity,
            category=",".join(sorted(categories)) or "unknown",
            source_ip=summary.src_ip,
            dest_ip=summary.dst_ip,
            description=self._build_description(sig_names, av_hits, summary),
            score=score,
            signatures=sig_names,
            av_hits=av_hits,
            metadata={
                "protocol": summary.protocol,
                "src_port": summary.src_port,
                "dst_port": summary.dst_port,
                "flags": summary.flags,
                "hints": summary.risk_hints,
            },
        )
        self.total_threats += 1
        if self.on_threat:
            self.on_threat(event)
        return event

    @staticmethod
    def _severity(score: int) -> str:
        if score >= 15:
            return "critical"
        if score >= 10:
            return "high"
        if score >= 7:
            return "medium"
        return "low"

    @staticmethod
    def _build_description(
        sigs: list[str],
        av: list[str],
        summary: PacketSummary,
    ) -> str:
        parts = []
        if sigs:
            parts.append("Signatures: " + ", ".join(sigs))
        if av:
            parts.append("AV: " + "; ".join(av))
        if summary.flags:
            parts.append("Flags: " + ", ".join(summary.flags))
        return " | ".join(parts) or "Anomalous traffic detected"
