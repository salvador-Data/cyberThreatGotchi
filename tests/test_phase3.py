"""Phase 3 — animation frames, YAML config, threat history API."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from assets.sprites.png_loader import sprite_path
from config.settings import load_settings
from core.state_bus import GotchiSnapshot, StateBus
from dashboard.web_server import create_web_app
from db.logger import ThreatLogger, ThreatRecord


def test_sprite_animation_frames():
    png_dir = ROOT / "assets" / "sprites" / "png"
    if not (png_dir / "idle_0.png").is_file():
        import subprocess

        subprocess.run([sys.executable, str(ROOT / "assets" / "sprites" / "generate_sprites.py")], check=True)
    assert sprite_path("idle", 0) is not None
    assert sprite_path("idle", 1) is not None
    assert sprite_path("idle", 0) != sprite_path("idle", 1)


def test_yaml_config_loads(tmp_path):
    cfg = tmp_path / "test.yaml"
    cfg.write_text(
        "simulation: true\ngotchi:\n  name: Testicorn\nweb:\n  port: 9999\n",
        encoding="utf-8",
    )
    s = load_settings(cfg)
    assert s.simulation is True
    assert s.gotchi_name == "Testicorn"
    assert s.web_port == 9999


def test_api_threats_history(tmp_path):
    db = tmp_path / "h.db"
    log = ThreatLogger(db)
    log.log_threat(
        ThreatRecord(
            timestamp="2026-01-01T00:00:00+00:00",
            severity="high",
            category="test",
            source_ip="9.9.9.9",
            dest_ip="1.1.1.1",
            description="history test",
            score=7,
            action_taken="logged",
            metadata={},
        )
    )
    bus = StateBus()
    app = create_web_app(bus, logger=log)
    client = app.test_client()
    resp = client.get("/api/threats?limit=5")
    data = resp.get_json()
    assert resp.status_code == 200
    assert data["count"] == 1
    assert data["threats"][0]["source_ip"] == "9.9.9.9"


def test_sprite_frame_query_param():
    png_dir = ROOT / "assets" / "sprites" / "png"
    if not (png_dir / "happy_1.png").is_file():
        import subprocess

        subprocess.run([sys.executable, str(ROOT / "assets" / "sprites" / "generate_sprites.py")], check=True)
    bus = StateBus()
    app = create_web_app(bus)
    client = app.test_client()
    r0 = client.get("/api/sprite/happy.png?frame=0")
    r1 = client.get("/api/sprite/happy.png?frame=1")
    assert r0.status_code == 200
    assert r1.status_code == 200
    assert r0.data != r1.data


def test_gotchi_snapshot_frame_index():
    bus = StateBus()
    bus.update_gotchi(
        GotchiSnapshot(
            name="X",
            mood="idle",
            hunger=50,
            happiness=50,
            security_xp=0,
            level=1,
            threats_blocked=0,
            threats_seen=0,
            status_line="ok",
            frame_index=3,
        )
    )
    assert bus.snapshot()["gotchi"]["frame_index"] == 3
