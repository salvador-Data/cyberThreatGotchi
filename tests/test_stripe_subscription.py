"""Stripe subscription webhook handler tests (core.stripe_provisioning)."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from core.stripe_provisioning import handle_provision_event
from db.pro_keys import ProKeyStore


def test_checkout_session_provisions_pro_key(tmp_path):
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
    result = handle_provision_event(event, store)
    assert "api_key" in result
    assert store.is_active(result["api_key"]) is True


def test_subscription_created_provisions_key(tmp_path):
    store = ProKeyStore(tmp_path / "pk.db")
    event = {
        "type": "customer.subscription.created",
        "data": {"object": {"customer": "cus_sub", "status": "active"}},
    }
    result = handle_provision_event(event, store)
    assert result.get("api_key")
    assert result.get("action") == "provisioned"


def test_subscription_deleted_revokes_key(tmp_path):
    store = ProKeyStore(tmp_path / "pk.db")
    key = store.provision("cus_del", email="a@example.com")
    event = {
        "type": "customer.subscription.deleted",
        "data": {"object": {"customer": "cus_del"}},
    }
    result = handle_provision_event(event, store)
    assert result.get("revoked") == key
    assert store.is_active(key) is False


def test_subscription_updated_inactive_skips(tmp_path):
    store = ProKeyStore(tmp_path / "pk.db")
    key = store.provision("cus_upd", email="b@example.com")
    event = {
        "type": "customer.subscription.updated",
        "data": {"object": {"customer": "cus_upd", "status": "canceled"}},
    }
    result = handle_provision_event(event, store)
    assert result.get("skipped") == "status_canceled"
    assert store.is_active(key) is True


def test_invoice_payment_failed_skips(tmp_path):
    store = ProKeyStore(tmp_path / "pk.db")
    key = store.provision("cus_fail", email="c@example.com")
    event = {
        "type": "invoice.payment_failed",
        "data": {"object": {"customer": "cus_fail", "subscription": "sub_123"}},
    }
    result = handle_provision_event(event, store)
    assert result.get("skipped") == "invoice_handled_by_stripe_dunning"
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
