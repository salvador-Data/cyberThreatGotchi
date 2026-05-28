"""Phase 5 — Pro feed, audit chain, Bjorn bridge, PlatformIO skeleton."""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from core.pro_feed import (
    build_hashes_payload,
    build_signatures_payload,
    build_yara_payload,
    validate_pro_key,
)
from dashboard.web_server import create_web_app
from db.audit_chain import AuditChain
from core.state_bus import StateBus


def test_pro_feed_payloads():
    sig = build_signatures_payload()
    assert sig["feed"] == "ctg-pro-signatures"
    assert len(sig["signatures"]) >= 1
    assert len(sig["pro_signatures"]) >= 1

    yara = build_yara_payload()
    assert "custom_rules.yar" in yara["rules"]
    assert "pro_rules.yar" in yara["rules"]

    hashes = build_hashes_payload()
    assert hashes["feed"] == "ctg-pro-hashes"
    assert isinstance(hashes["sha256_deny_list"], list)


def test_pro_key_demo_mode(monkeypatch):
    monkeypatch.delenv("CTG_PRO_API_KEY", raising=False)
    assert validate_pro_key("demo") is True
    assert validate_pro_key("wrong") is False


def test_pro_key_configured(monkeypatch):
    monkeypatch.setenv("CTG_PRO_API_KEY", "secret-key")
    assert validate_pro_key("secret-key") is True
    assert validate_pro_key("demo") is False


def test_audit_chain_integrity(tmp_path):
    db = tmp_path / "audit.db"
    chain = AuditChain(db, secret="test-secret")
    chain.append("threat", {"source_ip": "1.2.3.4", "score": 5}, "2026-01-01T00:00:00Z")
    chain.append("threat", {"source_ip": "5.6.7.8", "score": 9}, "2026-01-01T00:00:01Z")
    ok, msg = chain.verify_chain()
    assert ok, msg
    export = chain.export_chain()
    assert export["count"] == 2
    assert "hmac_sha256" in export


def test_audit_export_endpoint(tmp_path):
    audit = AuditChain(tmp_path / "a.db", secret="s")
    audit.append("threat", {"x": 1}, "t1")
    app = create_web_app(StateBus(), audit=audit)
    resp = app.test_client().get("/api/export/audit.json")
    data = json.loads(resp.data)
    assert data["verified"] is True
    assert data["count"] == 1


def test_pro_api_endpoints(monkeypatch):
    monkeypatch.delenv("CTG_PRO_API_KEY", raising=False)
    app = create_web_app(StateBus())
    client = app.test_client()

    denied = client.get("/api/pro/feed/signatures")
    assert denied.status_code == 401

    ok = client.get("/api/pro/feed/signatures", headers={"X-CTG-Pro-Key": "demo"})
    assert ok.status_code == 200
    body = json.loads(ok.data)
    assert body["feed"] == "ctg-pro-signatures"


def test_bjorn_bridge_format():
    spec = importlib.util.spec_from_file_location("bjorn_bridge", ROOT / "scripts" / "bjorn_bridge.py")
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader
    spec.loader.exec_module(mod)
    line = mod.format_epaper_line(
        {
            "gotchi": {"mood": "alert"},
            "threat": {"source_ip": "10.0.0.1", "severity": "high", "action_taken": "blocked"},
        }
    )
    assert "10.0.0.1" in line
    assert "ALERT" in line


def test_platformio_files_exist():
    base = ROOT / "scripts" / "cardputer" / "platformio"
    assert (base / "platformio.ini").is_file()
    assert (base / "src" / "main.cpp").is_file()
    ini = (base / "platformio.ini").read_text(encoding="utf-8")
    assert "CTG_HOST" in ini
