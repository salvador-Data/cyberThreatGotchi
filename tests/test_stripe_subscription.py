"""Stripe subscription webhook handler tests."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from db.pro_keys import ProKeyStore


def _load_stripe_provision():
    path = ROOT / "scripts" / "stripe_provision.py"
    spec = importlib.util.spec_from_file_location("stripe_provision", path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader
    spec.loader.exec_module(mod)
    return mod


def test_checkout_session_provisions_pro_key(tmp_path):
    mod = _load_stripe_provision()
    store = ProKeyStore(tmp_path / "pk.db")
    event = {
        "type": "checkout.session.completed",
        "data": {
            "object": {
                "mode": "subscription",
                "customer": "cus_pro_1",
                "customer_details": {"email": "buyer@example.com"},
                "metadata": {"stripe_key": "proMonthly"},
            }
        },
    }
    result = mod.handle_stripe_event(event, store)
    assert "api_key" in result
    assert store.is_active(result["api_key"]) is True


def test_checkout_session_skips_hardware(tmp_path):
    mod = _load_stripe_provision()
    store = ProKeyStore(tmp_path / "pk.db")
    event = {
        "type": "checkout.session.completed",
        "data": {
            "object": {
                "mode": "payment",
                "customer": "cus_hw_1",
                "metadata": {"stripe_key": "coreKit"},
            }
        },
    }
    result = mod.handle_stripe_event(event, store)
    assert result.get("skipped") == "not_pro_subscription"


def test_subscription_deleted_revokes_key(tmp_path):
    mod = _load_stripe_provision()
    store = ProKeyStore(tmp_path / "pk.db")
    key = store.provision("cus_del", email="a@example.com")
    event = {
        "type": "customer.subscription.deleted",
        "data": {"object": {"customer": "cus_del"}},
    }
    result = mod.handle_stripe_event(event, store)
    assert result.get("revoked") == key
    assert store.is_active(key) is False


def test_subscription_updated_canceled_revokes(tmp_path):
    mod = _load_stripe_provision()
    store = ProKeyStore(tmp_path / "pk.db")
    key = store.provision("cus_upd", email="b@example.com")
    event = {
        "type": "customer.subscription.updated",
        "data": {"object": {"customer": "cus_upd", "status": "canceled"}},
    }
    result = mod.handle_stripe_event(event, store)
    assert result.get("revoked") == key


def test_invoice_payment_failed_logs_only(tmp_path):
    mod = _load_stripe_provision()
    store = ProKeyStore(tmp_path / "pk.db")
    key = store.provision("cus_fail", email="c@example.com")
    event = {
        "type": "invoice.payment_failed",
        "data": {"object": {"customer": "cus_fail", "id": "in_123"}},
    }
    result = mod.handle_stripe_event(event, store)
    assert result.get("invoice_id") == "in_123"
    assert store.is_active(key) is True


def test_check_payments_reports_subscription_keys():
    import subprocess

    r = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "check_payments.py")],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
    )
    assert r.returncode in (1, 2)
    import json

    data = json.loads(r.stdout)
    assert "mspMonitor" in data.get("subscription_keys", [])
    assert "stripeCustomerPortal" in data


def test_check_shop_aligned():
    import subprocess

    r = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "check_shop.py")],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
    )
    assert r.returncode == 0, r.stdout + r.stderr
