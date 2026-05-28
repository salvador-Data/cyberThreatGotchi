"""Partner fulfillment catalog, export scripts, and shop alignment."""

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


def test_market_pricing_internet_doc():
    doc = ROOT / "docs" / "MARKET_PRICING_INTERNET.md"
    assert doc.is_file()
    text = doc.read_text(encoding="utf-8")
    assert "RTL-SDR" in text
    assert "Flipper Zero (reference)" in text
    assert "authorized" in text.lower()
    assert "never" in text.lower() and "dropship" in text.lower()


def test_partner_fulfillment_runbook():
    doc = ROOT / "docs" / "PARTNER_FULFILLMENT_RUNBOOK.md"
    assert doc.is_file()
    text = doc.read_text(encoding="utf-8")
    assert "partner_fulfillment_export.py" in text
    assert "Amazon" in text
    assert "never" in text.lower() and "dropship" in text.lower()


def test_rf_network_lab_catalog_skus(catalog_text):
    for key in (
        "dsRtlSdrKit",
        "dsNesdrSmart",
        "dsLanTap",
        "dsThrowingStarKit",
        "dsEsp32WifiLab",
        "dsUsbRubberDucky",
        "dsHak5WifiPineapple",
    ):
        assert key in catalog_text
    assert "rf-network-lab" in catalog_text
    assert "Partner fulfillment" in catalog_text or "partner fulfillment" in catalog_text.lower()


def test_new_skus_in_payments_and_shipping():
    pay = _read("payments.js")
    ship = _read("shipping.config.js")
    cfg = _read("payments.config.js")
    for key in (
        "dsRtlSdrKit",
        "dsLanTap",
        "dsUsbRubberDucky",
        "dsHak5WifiPineapple",
    ):
        assert key in pay
        assert f"{key}:" in ship
        assert f"{key}:" in cfg


def test_tracker_covers_new_dropship_keys(catalog_text, tracker_text):
    catalog_keys = {k for k in _stripe_keys(catalog_text) if k.startswith("ds")}
    tracker_keys = _tracker_keys(tracker_text)
    missing = sorted(catalog_keys - tracker_keys)
    assert not missing, f"shipping-tracker missing: {missing}"


def test_partner_fulfillment_export_json():
    r = subprocess.run(
        [
            sys.executable,
            str(ROOT / "scripts" / "partner_fulfillment_export.py"),
            "--stripe-key",
            "dsRtlSdrKit",
            "--json",
        ],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
    )
    assert r.returncode == 0, r.stderr
    rows = json.loads(r.stdout)
    assert len(rows) == 1
    assert rows[0]["stripe_key"] == "dsRtlSdrKit"
    assert rows[0]["fulfillment_channel"] == "amazon"
    assert "amazon.com" in rows[0]["amazon_search_url"]


def test_ebay_fulfillment_export_wrapper():
    r = subprocess.run(
        [
            sys.executable,
            str(ROOT / "scripts" / "ebay_fulfillment_export.py"),
            "--stripe-key",
            "dsEsp32Cyd",
            "--json",
        ],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
    )
    assert r.returncode == 0, r.stderr
    rows = json.loads(r.stdout)
    assert rows[0]["stripe_key"] == "dsEsp32Cyd"
    assert rows[0]["ebay_search_url"]


def test_upsell_config_corekit_cross_sells():
    text = _read("upsell.config.js")
    assert "when: \"coreKit\"" in text
    assert "dsRtlSdrKit" in text
    assert "dsLanTap" in text


def test_upsell_shop_scripts_wired():
    shop = (ROOT / "website" / "shop.html").read_text(encoding="utf-8")
    assert "upsell.config.js" in shop
    assert "upsell.js" in shop


def test_bpi_r3_hidden_and_2gb_copy(catalog_text):
    bpi_block = catalog_text.split('id: "ds-bpi-r3"')[1].split("},")[0]
    assert "catalogHidden: true" in bpi_block
    assert "2 GB" in _read("direct.config.js") or "2 GB RAM" in _read("direct.config.js")
    ctg = (ROOT / "website" / "cyberthreatgotchi.html").read_text(encoding="utf-8")
    assert "2 GB RAM" in ctg
