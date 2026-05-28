"""Security module tests."""

from __future__ import annotations

import hmac
import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from core.security import (
    constant_time_equal,
    sanitize_mood,
    verify_bearer_or_header,
    verify_stripe_webhook,
)
from dashboard.web_server import create_web_app
from core.state_bus import StateBus
from db.pro_keys import ProKeyStore
from core.pro_feed import validate_pro_key


def test_constant_time_equal():
    assert constant_time_equal("abc", "abc") is True
    assert constant_time_equal("abc", "abd") is False


def test_sanitize_mood_blocks_traversal():
    assert sanitize_mood("alert") == "alert"
    assert sanitize_mood("../etc/passwd") is None
    assert sanitize_mood("ALERT") == "alert"


def test_verify_bearer():
    assert verify_bearer_or_header("Bearer tok123", "tok123") is True
    assert verify_bearer_or_header("wrong", "tok123") is False


def test_stripe_webhook_signature():
    secret = "whsec_test"
    payload = b'{"id":"evt_test"}'
    ts = "1234567890"
    signed = f"{ts}.".encode() + payload
    sig = hmac.new(secret.encode(), signed, "sha256").hexdigest()
    header = f"t={ts},v1={sig}"
    assert verify_stripe_webhook(payload, header, secret) is True
    assert verify_stripe_webhook(payload, header, "wrong") is False


def test_api_token_required():
    app = create_web_app(StateBus(), api_token="secret-token")
    client = app.test_client()
    denied = client.post("/api/feed")
    assert denied.status_code == 401
    ok = client.post("/api/feed", headers={"Authorization": "Bearer secret-token"})
    assert ok.status_code == 200


def test_sprite_bad_mood_400():
    app = create_web_app(StateBus())
    client = app.test_client()
    resp = client.get("/api/sprite/../../etc.png")
    assert resp.status_code in (400, 404)


def test_pro_key_store_and_validate(tmp_path):
    store = ProKeyStore(tmp_path / "pk.db")
    key = store.provision("cus_123", email="a@example.com")
    assert store.is_active(key) is True
    assert validate_pro_key(key, store=store) is True
    store.revoke(key)
    assert validate_pro_key(key, store=store) is False


def test_stripe_provision_script_import():
    import importlib.util

    path = ROOT / "scripts" / "stripe_provision.py"
    spec = importlib.util.spec_from_file_location("stripe_provision", path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader
    spec.loader.exec_module(mod)
    assert hasattr(mod, "main")


def test_check_payments_script():
    import subprocess

    r = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "check_payments.py")],
        capture_output=True,
        text=True,
    )
    assert r.returncode in (0, 1, 2)
    data = json.loads(r.stdout)
    assert "stripe_links" in data
