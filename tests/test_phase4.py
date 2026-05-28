"""Phase 4 — LCD STLs, export API, Cardputer poller, stats."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from dashboard.web_server import create_web_app
from db.logger import ThreatLogger, ThreatRecord
from core.state_bus import StateBus


def test_lcd_stl_variant_exists():
    lcd_dir = ROOT / "hardware" / "stl" / "lcd"
    if not (lcd_dir / "ctg_front_shell.stl").is_file():
        subprocess.run(
            [sys.executable, str(ROOT / "hardware" / "generate_stl.py"), "--variant", "lcd", "--python-only"],
            check=True,
        )
    for name in ("ctg_front_shell.stl", "ctg_rear_shell.stl", "ctg_clip.stl"):
        assert (lcd_dir / name).is_file(), name


def test_export_csv_endpoint(tmp_path):
    db = tmp_path / "e.db"
    log = ThreatLogger(db)
    log.log_threat(
        ThreatRecord(
            timestamp="2026-01-01T00:00:00+00:00",
            severity="high",
            category="test",
            source_ip="1.2.3.4",
            dest_ip="5.6.7.8",
            description="export test",
            score=9,
            action_taken="blocked",
            metadata={},
        )
    )
    app = create_web_app(StateBus(), logger=log)
    resp = app.test_client().get("/api/export/threats.csv")
    assert resp.status_code == 200
    assert b"1.2.3.4" in resp.data
    assert b"severity" in resp.data


def test_export_report_json(tmp_path):
    db = tmp_path / "r.db"
    log = ThreatLogger(db)
    log.log_threat(
        ThreatRecord(
            timestamp="2026-01-01T00:00:00+00:00",
            severity="critical",
            category="malware",
            source_ip="9.9.9.9",
            dest_ip="8.8.8.8",
            description="report",
            score=15,
            action_taken="blocked",
            metadata={},
        )
    )
    app = create_web_app(StateBus(), logger=log)
    resp = app.test_client().get("/api/export/report.json")
    data = json.loads(resp.data)
    assert data["statistics"]["total"] == 1
    assert "gotchi" in data


def test_threat_stats(tmp_path):
    log = ThreatLogger(tmp_path / "s.db")
    for sev, ip in [("high", "1.1.1.1"), ("high", "1.1.1.1"), ("low", "2.2.2.2")]:
        log.log_threat(
            ThreatRecord(
                timestamp="t",
                severity=sev,
                category="c",
                source_ip=ip,
                dest_ip="x",
                description="d",
                score=5,
                action_taken="logged",
                metadata={},
            )
        )
    stats = log.threat_stats()
    assert stats["total"] == 3
    assert stats["by_severity"]["high"] == 2
    assert stats["top_sources"][0]["ip"] == "1.1.1.1"


def test_cardputer_status_script_runs():
    import importlib.util

    path = ROOT / "scripts" / "cardputer_status.py"
    spec = importlib.util.spec_from_file_location("cardputer_status", path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader
    spec.loader.exec_module(mod)
    out = mod.render_card({"gotchi": {"name": "X", "mood": "idle", "level": 1}, "threats": []})
    assert "CyberThreatGotchi" in out
