"""Tests for Stripe API helpers and fulfillment import/sync scripts."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from core.stripe_api import (  # noqa: E402
    DIGITAL_KEYS,
    DIRECT_SHIP_KEYS,
    needs_shipping,
    price_cents,
    recurring_interval,
)


def test_needs_shipping_classification():
    assert needs_shipping("dsMeshtasticHeltec") is True
    assert needs_shipping("coreKit") is True
    assert needs_shipping("digital") is False
    assert needs_shipping("proMonthly") is False


def test_price_cents():
    assert price_cents(89.99) == 8999
    assert price_cents(15) == 1500


def test_recurring_interval():
    assert recurring_interval("proMonthly", "/month") == "month"
    assert recurring_interval("proYearly", "/year") == "year"


def test_digital_and_direct_sets():
    assert "digital" in DIGITAL_KEYS
    assert "cydStandard" in DIRECT_SHIP_KEYS


def test_stripe_import_batch_dry_run(tmp_path):
    import subprocess

    sample = {
        "type": "checkout.session.completed",
        "data": {
            "object": {
                "id": "cs_batch_1",
                "metadata": {"stripe_key": "dsMeshtasticHeltec"},
                "customer_details": {"email": "batch@example.com"},
            }
        },
    }
    f1 = tmp_path / "evt1.json"
    f1.write_text(json.dumps(sample), encoding="utf-8")
    r = subprocess.run(
        [
            sys.executable,
            str(ROOT / "scripts" / "stripe_fulfillment_import.py"),
            "--batch",
            str(tmp_path),
            "--dry-run",
        ],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
    )
    assert r.returncode == 0, r.stderr
    data = json.loads(r.stdout)
    assert data["batch"] is True
    assert data["count"] == 1
    assert data["results"][0]["order"]["stripe_key"] == "dsMeshtasticHeltec"


def test_stripe_bootstrap_dry_run():
    import subprocess

    r = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "stripe_bootstrap_payment_links.py"), "--dry-run"],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
    )
    assert r.returncode == 1  # no secret key
    assert "CTG_STRIPE_SECRET_KEY" in r.stderr


def test_fulfillment_dashboard_import_ui():
    html = (ROOT / "website" / "operator" / "fulfillment.html").read_text(encoding="utf-8")
    js = (ROOT / "website" / "js" / "fulfillment-dashboard.js").read_text(encoding="utf-8")
    assert "stripe-import" in html
    assert "Import into queue" in html
    assert "enqueueStripePayload" in js


def test_partner_fulfillment_operator_script_exists():
    ps1 = ROOT / "scripts" / "partner_fulfillment_operator.ps1"
    assert ps1.is_file()
    text = ps1.read_text(encoding="utf-8")
    assert "stripe_fulfillment_sync.py" in text
    assert "operator/fulfillment" in text
    assert "partner fulfillment" in text.lower()
