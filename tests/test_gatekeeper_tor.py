"""Gatekeeper.TOR — core logic and repo assets (no live Tor required)."""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from core import gatekeeper_tor as gk  # noqa: E402


@pytest.fixture
def isolated_state(tmp_path, monkeypatch):
    state_file = tmp_path / "state.json"
    monkeypatch.setenv("CTG_GATEKEEPER_STATE_FILE", str(state_file))
    return state_file


def test_gatekeeper_assets_exist():
    base = ROOT / "scripts" / "gatekeeper-tor"
    for name in (
        "gatekeeper-daemon.sh",
        "templates/gatekeeper.conf",
        "kali/install-gatekeeper-kali.sh",
        "kali/gatekeeper-tray.py",
        "windows/Start-GatekeeperTorTray.ps1",
        "windows/Install-GatekeeperTorWindows.ps1",
    ):
        p = base / name
        assert p.is_file(), name
        text = p.read_text(encoding="utf-8")
        assert "Hacker Planet" in text or "authorized" in text.lower()
        assert "jammer" not in text.lower()


def test_logo_and_docs():
    assets = ROOT / "assets" / "gatekeeper-tor"
    assert (assets / "logo.svg").is_file()
    for name in (
        "logo-tor-on.png",
        "logo-tor-off.png",
        "logo-https-on.png",
        "logo-https-off.png",
    ):
        assert (assets / name).is_file(), f"missing lit icon {name}"
    doc = ROOT / "docs" / "GATEKEEPER_TOR.md"
    assert doc.is_file()
    body = doc.read_text(encoding="utf-8")
    assert "DuckDuckGo" in body
    assert "TLS 1.3" in body
    assert "lit" in body.lower()
    assert "illegal" in body.lower() or "authorized" in body.lower()


def test_icon_helpers():
    assert gk.icon_filename("tor", lit=True) == "logo-tor-on.png"
    assert gk.icon_filename("https", lit=False) == "logo-https-off.png"
    assert "(lit)" in gk.tray_tooltip("tor")
    assert "●" in gk.panel_tooltip("tor")


def test_torrc_template_client_only():
    conf = ROOT / "scripts" / "gatekeeper-tor" / "templates" / "gatekeeper.conf"
    text = conf.read_text(encoding="utf-8")
    assert "ExitPolicy reject *:*" in text
    assert "SocksPort 127.0.0.1:9050" in text
    assert "Password" not in text or "hash-password" in text


def test_normalize_and_scrambler_mapping():
    assert gk.normalize_mode("https") == gk.GatekeeperMode.HTTPS
    assert gk.normalize_mode("http") == gk.GatekeeperMode.HTTPS
    assert gk.normalize_mode("tor") == gk.GatekeeperMode.TOR
    assert gk.scrambler_mode_for_gatekeeper(gk.GatekeeperMode.HTTPS) == "http"
    assert gk.scrambler_mode_for_gatekeeper(gk.GatekeeperMode.TOR) == "tor"


def test_state_roundtrip(isolated_state):
    st = gk.set_mode("tor")
    assert st.mode == "tor"
    assert st.tor_enabled is True
    loaded = gk.load_state()
    assert loaded.mode == "tor"
    data = json.loads(isolated_state.read_text(encoding="utf-8"))
    assert "ddg_coexistence_note" in data


def test_set_https_mode(isolated_state):
    st = gk.set_mode("https")
    assert st.mode == "https"
    assert gk.load_state().mode == "https"


def test_daemon_sh_syntax():
    sh = ROOT / "scripts" / "gatekeeper-tor" / "gatekeeper-daemon.sh"
    text = sh.read_text(encoding="utf-8")
    assert "set-mode" in text
    assert "https" in text
    assert "#!/usr/bin/env bash" in text


def test_tray_py_syntax():
    import ast

    path = ROOT / "scripts" / "gatekeeper-tor" / "kali" / "gatekeeper-tray.py"
    body = path.read_text(encoding="utf-8")
    ast.parse(body)
    assert "lit" in body.lower()
    assert "pystray" in body


def test_sync_script_exists():
    sync = ROOT / "scripts" / "publish" / "Sync-CtgGatekeeperTorRepo.ps1"
    assert sync.is_file()
    assert "ctg-gatekeeper-tor" in sync.read_text(encoding="utf-8")
