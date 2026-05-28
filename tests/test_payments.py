"""Payment security and Stripe provisioning tests."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from core.stripe_provisioning import handle_provision_event
from core.fulfillment_queue import order_from_stripe_session
from db.pro_keys import ProKeyStore


def test_handle_provision_checkout_session(tmp_path: Path) -> None:
    store = ProKeyStore(tmp_path / "pk.db")
    event = {
        "type": "checkout.session.completed",
        "data": {
            "object": {
                "id": "cs_test_1",
                "mode": "subscription",
                "customer": "cus_abc",
                "customer_details": {"email": "buyer@example.com"},
            }
        },
    }
    result = handle_provision_event(event, store)
    assert result.get("api_key")
    assert result["customer_id"] == "cus_abc"
    assert store.find_by_customer("cus_abc") == result["api_key"]


def test_handle_provision_subscription_created(tmp_path: Path) -> None:
    store = ProKeyStore(tmp_path / "pk.db")
    event = {
        "type": "customer.subscription.created",
        "data": {
            "object": {
                "customer": "cus_sub",
                "status": "active",
            }
        },
    }
    result = handle_provision_event(event, store)
    assert result.get("api_key")
    assert result.get("action") == "provisioned"


def test_handle_provision_subscription_deleted_revokes(tmp_path: Path) -> None:
    store = ProKeyStore(tmp_path / "pk.db")
    key = store.provision("cus_del", email="x@y.com")
    event = {
        "type": "customer.subscription.deleted",
        "data": {"object": {"customer": "cus_del", "status": "canceled"}},
    }
    result = handle_provision_event(event, store)
    assert result.get("revoked") == key
    assert store.is_active(key) is False


def test_handle_provision_idempotent_checkout(tmp_path: Path) -> None:
    store = ProKeyStore(tmp_path / "pk.db")
    event = {
        "type": "checkout.session.completed",
        "data": {
            "object": {
                "customer": "cus_dup",
                "customer_details": {"email": "a@b.com"},
            }
        },
    }
    r1 = handle_provision_event(event, store)
    r2 = handle_provision_event(event, store)
    assert r1["api_key"] == r2["api_key"]


def test_order_from_stripe_session_includes_customer_id_only() -> None:
    session = {
        "id": "cs_test",
        "customer": "cus_ship",
        "metadata": {"stripe_key": "dsMeshtasticHeltec"},
        "customer_details": {
            "email": "ship@example.com",
            "address": {"line1": "1 Main", "city": "Philadelphia", "state": "PA", "postal_code": "19107"},
        },
    }
    order = order_from_stripe_session(session)
    assert order["stripe_customer_id"] == "cus_ship"
    assert order["customer_email"] == "ship@example.com"
    assert "payment_method" not in order
    assert "card" not in json.dumps(order).lower()


def test_check_payments_script_runs() -> None:
    import subprocess

    r = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "check_payments.py")],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
    )
    assert r.returncode in (0, 1, 2)
    data = json.loads(r.stdout)
    assert "stripe_links" in data
    subs = data.get("subscription_keys") or []
    links = data.get("stripe_links") or {}
    assert "mspMonitor" in subs or "mspMonitor" in links
