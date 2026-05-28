"""Drop-ship catalog, shipping tracker, and order export alignment."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "website" / "js"


def _read(name: str) -> str:
    return (WEB / name).read_text(encoding="utf-8")


def _stripe_keys(text: str) -> set[str]:
    return set(re.findall(r'stripeKey:\s*"(\w+)"', text))


def _tracker_keys(text: str) -> set[str]:
    return set(re.findall(r"(ds\w+):\s*\{", text.split("products:")[-1]))


@pytest.fixture
def catalog_text():
    return _read("catalog.config.js")


@pytest.fixture
def tracker_text():
    return _read("shipping-tracker.config.js")


def test_shipping_tracker_files_exist():
    assert (WEB / "shipping-tracker.js").is_file()
    assert (WEB / "shipping-tracker.config.js").is_file()


def test_shipping_tracker_structure(tracker_text):
    assert "HPL_SHIPPING_TRACKER" in tracker_text
    assert "fulfillmentStatuses" in tracker_text
    assert "trackingUrlTemplates" in tracker_text
    assert "dsMeshtasticHeltec" in tracker_text
    assert "fully_built" in tracker_text
    assert "LayerFabUK" in tracker_text


def test_meshtastic_v3_fully_built_catalog(catalog_text):
    assert "Heltec V3 fully built Meshtastic node" in catalog_text
    assert "LayerFabUK" in catalog_text
    assert "retailPrice: 129" in catalog_text
    assert "etsy.com/listing/1733234765" in catalog_text
    assert 'buildType: "fully_built"' in catalog_text


def test_banana_pi_r3_hidden_from_shop_catalog(catalog_text):
    pay = _read("payments.js")
    bpi_block = catalog_text.split('id: "ds-bpi-r3"')[1].split("},")[0]
    assert "Banana Pi BPI-R3 Mini router SBC" in catalog_text
    assert "catalogHidden: true" in bpi_block
    assert "retailPrice: 160" not in bpi_block
    assert "CTG component" in bpi_block
    pay_block = pay.split("dsBananaPiR3:")[1].split("},")[0]
    assert "price: 119" in pay_block
    assert "not standalone retail" in pay_block


def test_new_dropship_skus_in_payments():
    pay = _read("payments.js")
    cfg = _read("payments.config.js")
    ship = _read("shipping.config.js")
    for key in ("dsWiringLab", "dsKaliNetHunter"):
        assert key in pay
        assert f"{key}:" in cfg
        assert f"{key}:" in ship


def test_tracker_covers_catalog_dropship_keys(catalog_text, tracker_text):
    catalog_keys = _stripe_keys(catalog_text)
    tracker_keys = _tracker_keys(tracker_text)
    pay_keys = _stripe_keys(_read("payments.js"))
    dropship_catalog = {k for k in catalog_keys if k.startswith("ds")}
    missing = sorted(dropship_catalog - tracker_keys)
    assert not missing, f"shipping-tracker missing: {missing}"
    assert dropship_catalog <= pay_keys


def test_dropship_order_export_script():
    r = subprocess.run(
        [
            sys.executable,
            str(ROOT / "scripts" / "dropship_order_export.py"),
            "--stripe-key",
            "dsMeshtasticHeltec",
            "--json",
        ],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
    )
    assert r.returncode == 0, r.stderr
    rows = json.loads(r.stdout)
    assert len(rows) == 1
    assert rows[0]["stripe_key"] == "dsMeshtasticHeltec"
    assert "LayerFabUK" in str(rows[0]["supplier"]) or "layerfab" in str(rows[0]["supplier"]).lower()
    assert rows[0]["build_type"] == "fully_built"


def test_shipping_tracker_js_api():
    text = _read("shipping-tracker.js")
    assert "HPLShippingTracker" in text
    assert "buildTrackingUrl" in text
    assert "formatFulfillmentPacket" in text
    assert "does not call" in text.lower() or "pci" in text.lower() or "marketplace" in text.lower()
