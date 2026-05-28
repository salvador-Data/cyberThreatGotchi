"""Phase 2 — web, sprites, state bus."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from assets.sprites.png_loader import sprite_path
from core.state_bus import GotchiSnapshot, StateBus
from dashboard.web_server import create_web_app


def test_state_bus_snapshot():
    bus = StateBus()
    bus.update_gotchi(
        GotchiSnapshot(
            name="Test",
            mood="alert",
            hunger=50,
            happiness=60,
            security_xp=10,
            level=2,
            threats_blocked=1,
            threats_seen=3,
            status_line="ok",
        )
    )
    snap = bus.snapshot()
    assert snap["gotchi"]["mood"] == "alert"


def test_flask_status_endpoint():
    bus = StateBus()
    app = create_web_app(bus)
    client = app.test_client()
    resp = client.get("/api/status")
    assert resp.status_code == 200
    assert "gotchi" in resp.get_json()


def test_sprite_png_exist():
    # Generate if missing
    png_dir = ROOT / "assets" / "sprites" / "png"
    if not (png_dir / "idle.png").is_file():
        import subprocess

        subprocess.run([sys.executable, str(ROOT / "assets" / "sprites" / "generate_sprites.py")], check=True)
    assert sprite_path("idle") is not None
    assert sprite_path("attack") is not None
