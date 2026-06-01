"""Gatekeeper HTTPS Firejail sandbox — repo files and script parse (no live firejail)."""
from __future__ import annotations

import ast
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
GK = ROOT / "scripts" / "gatekeeper-tor"


def test_sandbox_docs_honest_language():
    doc = ROOT / "docs" / "GATEKEEPER_SANDBOX.md"
    assert doc.is_file()
    body = doc.read_text(encoding="utf-8")
    assert "HTTPS" in body and "sandbox" in body.lower()
    assert "TLS" in body or "wire" in body.lower()
    assert "DuckDuckGo" in body or "DDG" in body
    assert "banking" in body.lower() or "credential" in body.lower()
    assert "Firejail" in body


def test_firejail_profile_exists_and_restrictions():
    prof = GK / "kali" / "ctg-https-sandbox.profile"
    assert prof.is_file()
    text = prof.read_text(encoding="utf-8")
    assert "noroot" in text
    assert "seccomp" in text
    assert "private-dev" in text
    assert "/tmp/ctg-sandbox" in text
    assert "CTG_SANDBOX=1" in text
    assert "authorized" in text.lower() or "lab" in text.lower()


def test_sandbox_launcher_script():
    sh = GK / "kali" / "ctg-https-sandbox.sh"
    assert sh.is_file()
    text = sh.read_text(encoding="utf-8")
    assert "#!/usr/bin/env bash" in text
    assert "-DiagnoseOnly" in text
    assert "-LaunchBrowser" in text
    assert "firejail" in text
    assert "firefox" in text
    assert "Hacker Planet" in text or "authorized" in text.lower()


def test_site_rules_gatekeeper_template():
    rules = GK / "templates" / "site-rules.gatekeeper.conf"
    assert rules.is_file()
    body = rules.read_text(encoding="utf-8")
    assert "allowlist" in body.lower() or "allow" in body.lower()
    assert "HTTP" in body
    assert ".onion" in body


def test_daemon_sets_ctg_sandbox_env():
    daemon = GK / "gatekeeper-daemon.sh"
    text = daemon.read_text(encoding="utf-8")
    assert "CTG_SANDBOX=1" in text
    assert "sandbox.env" in text


def test_install_script_with_sandbox_flag():
    inst = GK / "kali" / "install-gatekeeper-kali.sh"
    text = inst.read_text(encoding="utf-8")
    assert "--with-sandbox" in text
    assert "ctg-https-sandbox" in text
    assert "firejail" in text


def test_tray_sandbox_menu_item():
    tray = GK / "kali" / "gatekeeper-tray.py"
    body = tray.read_text(encoding="utf-8")
    ast.parse(body)
    assert "Open sandboxed browser (HTTPS mode)" in body
    assert "launch_sandbox_browser" in body
    assert "visible_sandbox" in body


def test_windows_diagnose_documents_tls_probe():
    ps1 = GK / "windows" / "Start-GatekeeperTorTray.ps1"
    text = ps1.read_text(encoding="utf-8")
    assert "TLS 1.3" in text
    assert "GATEKEEPER_SANDBOX" in text
    assert "Open HTTPS Sandbox Browser" in text


def test_windows_https_sandbox_script():
    ps1 = GK / "windows" / "Start-CtgHttpsSandbox.ps1"
    assert ps1.is_file()
    text = ps1.read_text(encoding="utf-8")
    assert "-DiagnoseOnly" in text
    assert "-EnableSandboxFeature" in text
    assert "LaunchSandboxBrowser" in text
    assert "LaunchHttpLabOnly" in text
    assert "Containers-DisposableClientVM" in text
    assert "CTG_SANDBOX" in text
    assert "DuckDuckGo" in text or "DDG" in text
    assert "InPrivate" in text
    assert "Hacker Planet" in text or "authorized" in text.lower()


def test_core_gatekeeper_sandbox_module():
    from core import gatekeeper_sandbox as gs

    assert gs.is_http_url("http://lab-ap.local/")
    assert gs.is_https_url("https://example.com/")
    assert not gs.host_on_allowlist("http://evil.example/", path=ROOT / "nope.txt")
    ok, msg = gs.validate_http_lab_url("http://lab-ap.local/")
    assert ok is False  # not on default empty allowlist file in test
    ok_mode, _ = gs.sandbox_mode_allowed("https")
    assert ok_mode is True
    ok_mode, _ = gs.sandbox_mode_allowed("tor")
    assert ok_mode is False
    ok, _, url = gs.validate_launch_url("https://example.com/")
    assert ok and url == "https://example.com/"


def test_tray_integrates_sandbox_launcher():
    tray = GK / "windows" / "Start-GatekeeperTorTray.ps1"
    body = tray.read_text(encoding="utf-8")
    assert "Start-CtgHttpsSandbox.ps1" in body
    assert "CTG_SANDBOX" in body
