"""Fulfillment queue, API auth, and operator dashboard tests."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from core.fulfillment_queue import (
    QUEUE_VERSION,
    VALID_STATUSES,
    add_order,
    build_order,
    enrich_stripe_key,
    format_ship_to_text,
    list_orders,
    load_queue,
    order_from_stripe_session,
    update_order,
)
from core.security import verify_bearer_or_header
from core.state_bus import StateBus
from dashboard.web_server import create_web_app


@pytest.fixture
def queue_path(tmp_path):
    return tmp_path / "fulfillment_queue.json"


def test_queue_schema_build_and_roundtrip(queue_path):
    order = build_order(
        stripe_key="dsMeshtasticHeltec",
        ship_to={"name": "Test User", "line1": "1 Main", "city": "Philly", "state": "PA", "postal_code": "19107"},
        customer_email="test@example.com",
    )
    assert order["status"] == "pending"
    assert order["stripe_key"] == "dsMeshtasticHeltec"
    assert "LayerFabUK" in order["supplier"]
    assert order["checklist"]
    assert order["ship_to_text"]

    add_order(order, path=queue_path)
    data = load_queue(queue_path)
    assert data["version"] == QUEUE_VERSION
    assert len(data["orders"]) == 1
    assert data["orders"][0]["id"] == order["id"]


def test_enrich_stripe_key_unknown():
    with pytest.raises(ValueError):
        build_order(stripe_key="dsNotARealSku", ship_to="")


def test_enrich_known_sku():
    meta = enrich_stripe_key("dsMeshtasticHeltec")
    assert meta["product_name"]
    assert meta["supplier_url"]


def test_status_update(queue_path):
    order = build_order(stripe_key="dsMeshtasticHeltec", ship_to="A, B, C")
    add_order(order, path=queue_path)
    updated = update_order(order["id"], {"status": "ordered", "supplier_order_id": "etsy-123"}, path=queue_path)
    assert updated is not None
    assert updated["status"] == "ordered"
    assert updated["supplier_order_id"] == "etsy-123"


def test_invalid_status_rejected(queue_path):
    order = build_order(stripe_key="dsMeshtasticHeltec", ship_to="")
    add_order(order, path=queue_path)
    with pytest.raises(ValueError):
        update_order(order["id"], {"status": "invalid"}, path=queue_path)


def test_stripe_session_import():
    session = {
        "id": "cs_test_abc",
        "payment_intent": "pi_test",
        "metadata": {"stripe_key": "dsMeshtasticHeltec"},
        "customer_details": {
            "email": "buyer@example.com",
            "name": "Buyer Name",
            "address": {
                "line1": "100 Chestnut",
                "city": "Philadelphia",
                "state": "PA",
                "postal_code": "19106",
                "country": "US",
            },
        },
    }
    order = order_from_stripe_session(session)
    assert order["stripe_key"] == "dsMeshtasticHeltec"
    assert order["customer_email"] == "buyer@example.com"
    assert "Chestnut" in order["ship_to_text"]


def test_dedupe_stripe_session(queue_path):
    session = {
        "id": "cs_dup",
        "metadata": {"stripe_key": "dsMeshtasticHeltec"},
        "customer_details": {"email": "a@b.com"},
    }
    o1 = order_from_stripe_session(session)
    o2 = order_from_stripe_session(session)
    add_order(o1, path=queue_path)
    saved = add_order(o2, path=queue_path)
    assert saved["id"] == o1["id"]
    assert len(list_orders(path=queue_path)) == 1


def test_format_ship_to_text():
    text = format_ship_to_text(
        {"name": "N", "line1": "1 St", "city": "Philly", "state": "PA", "postal_code": "19107", "country": "US"}
    )
    assert "Philly" in text
    assert "N" in text


def test_valid_statuses_set():
    assert "pending" in VALID_STATUSES
    assert "shipped" in VALID_STATUSES


def test_operator_token_prefers_operator_env(monkeypatch):
    monkeypatch.setenv("CTG_OPERATOR_TOKEN", "op-secret")
    monkeypatch.setenv("CTG_WEB_API_TOKEN", "api-secret")
    from core.fulfillment_queue import operator_token_from_env

    assert operator_token_from_env() == "op-secret"


def test_operator_token_falls_back_to_api(monkeypatch):
    monkeypatch.delenv("CTG_OPERATOR_TOKEN", raising=False)
    monkeypatch.setenv("CTG_WEB_API_TOKEN", "api-secret")
    from core.fulfillment_queue import operator_token_from_env

    assert operator_token_from_env() == "api-secret"


def test_fulfillment_api_auth():
    app = create_web_app(StateBus(), api_token="api-tok", operator_token="op-tok")
    client = app.test_client()

    denied = client.get("/api/fulfillment/queue")
    assert denied.status_code == 401

    ok_op = client.get("/api/fulfillment/queue", headers={"Authorization": "Bearer op-tok"})
    assert ok_op.status_code == 200

    denied_api = client.get("/api/fulfillment/queue", headers={"Authorization": "Bearer api-tok"})
    assert denied_api.status_code == 401

    app_fallback = create_web_app(StateBus(), api_token="api-tok")
    ok_api = app_fallback.test_client().get(
        "/api/fulfillment/queue", headers={"Authorization": "Bearer api-tok"}
    )
    assert ok_api.status_code == 200


def test_fulfillment_api_enqueue_and_patch(tmp_path):
    queue_file = tmp_path / "q.json"
    import core.fulfillment_queue as fq

    original = fq.QUEUE_PATH
    fq.QUEUE_PATH = queue_file
    try:
        app = create_web_app(StateBus(), operator_token="secret")
        client = app.test_client()
        headers = {"Authorization": "Bearer secret", "Content-Type": "application/json"}

        resp = client.post(
            "/api/fulfillment/queue",
            headers=headers,
            data=json.dumps({"stripe_key": "dsMeshtasticHeltec", "ship_to": "Name, 1 St, Philly PA 19107"}),
        )
        assert resp.status_code == 201
        body = resp.get_json()
        order_id = body["order"]["id"]

        patch = client.patch(
            f"/api/fulfillment/queue/{order_id}",
            headers=headers,
            data=json.dumps({"status": "ordered"}),
        )
        assert patch.status_code == 200
        assert patch.get_json()["order"]["status"] == "ordered"
    finally:
        fq.QUEUE_PATH = original


def test_fulfillment_dashboard_js_helpers():
    text = (ROOT / "website" / "js" / "fulfillment-dashboard.js").read_text(encoding="utf-8")
    assert "HPLFulfillmentDashboard" in text
    assert "copyToClipboard" in text
    assert "renderOrderCard" in text
    assert "marketplace checkout" in text.lower() or "pci" in text.lower()


def test_operator_fulfillment_page_served():
    app = create_web_app(StateBus())
    client = app.test_client()
    resp = client.get("/operator/fulfillment")
    assert resp.status_code == 200
    assert b"Fulfillment dashboard" in resp.data


def test_fulfillment_queue_cli_add(tmp_path, queue_path):
    import subprocess

    r = subprocess.run(
        [
            sys.executable,
            str(ROOT / "scripts" / "fulfillment_queue.py"),
            "--queue",
            str(queue_path),
            "add",
            "--stripe-key",
            "dsMeshtasticHeltec",
            "--ship-to",
            "Test, 1 St, Philly PA 19107",
        ],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
    )
    assert r.returncode == 0, r.stderr
    data = json.loads(r.stdout)
    assert data["order"]["stripe_key"] == "dsMeshtasticHeltec"


def test_stripe_import_dry_run():
    import subprocess

    sample = {
        "type": "checkout.session.completed",
        "data": {
            "object": {
                "id": "cs_test",
                "metadata": {"stripe_key": "dsMeshtasticHeltec"},
                "customer_details": {"email": "x@y.com"},
            }
        },
    }
    r = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "stripe_fulfillment_import.py"), "--stdin", "--dry-run"],
        input=json.dumps(sample),
        capture_output=True,
        text=True,
        cwd=str(ROOT),
    )
    assert r.returncode == 0, r.stderr
    data = json.loads(r.stdout)
    assert data["dry_run"] is True
    assert data["order"]["stripe_key"] == "dsMeshtasticHeltec"


def test_require_operator_token_header():
    assert verify_bearer_or_header("Bearer op", "op") is True
