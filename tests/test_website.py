"""Website static files, shop checkout, and docs/web mirror."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "website"
DOCS_WEB = ROOT / "docs" / "web"


def test_website_structure():
    for name in (
        "index.html",
        "about.html",
        "cyberthreatgotchi.html",
        "ecosystem.html",
        "contact.html",
        "shop.html",
        "github.html",
        "css/style.css",
        "js/main.js",
        "js/payments.js",
        "js/payments.config.js",
        "js/catalog.js",
        "js/catalog.config.js",
        "js/direct.js",
        "js/direct.config.js",
        "js/shipping.js",
        "js/shipping.config.js",
        "README.md",
    ):
        assert (WEB / name).is_file(), name


def test_shop_page_payments():
    html = (WEB / "shop.html").read_text(encoding="utf-8")
    assert "product-checkout" in html
    assert "payments.config.js" in html
    assert "catalog.config.js" in html
    assert "dropship-catalog" in html
    assert "direct-catalog" in html
    assert "shipping-calculator" in html
    assert "data-estimate" in html
    assert "shipping.config.js" in html
    assert "direct-catalog" in html
    assert "Apple Pay" in html
    assert "Venmo" in html
    assert "Cash App" in html
    assert "AliExpress" in html or "Meshtastic" in html
    assert "Netgotchi" in html
    assert "Pwnagotchi" in html or "dropship-catalog" in html


def test_shipping_config_structure():
    text = (WEB / "js" / "shipping.config.js").read_text(encoding="utf-8")
    assert "HPL_SHIPPING" in text
    assert "sabretoAkachi" in text
    assert "fulfillment: \"direct\"" in text or '"direct"' in text
    assert "nexusStates" in text


def test_direct_config_structure():
    text = (WEB / "js" / "direct.config.js").read_text(encoding="utf-8")
    assert "HPL_DIRECT" in text
    assert "Sabreto Akachi" in text
    assert "CrackBot" in text
    assert 'fulfillment: "direct"' in text


def test_catalog_config_structure():
    text = (WEB / "js" / "catalog.config.js").read_text(encoding="utf-8")
    assert "HPL_CATALOG" in text
    assert "gotchi-pods" in text
    assert "meshtastic" in text
    assert "hackberry" in text
    assert "dsPwnagotchi" in text
    assert "fulfillment: \"dropship\"" in text
    assert "dsMeshtasticTBeam" in text
    assert "dsHackberryZero" in text


def test_github_repo_page():
    html = (WEB / "github.html").read_text(encoding="utf-8")
    assert "docs/web" in html
    assert "salvador-Data/cyberThreatGotchi" in html


def test_index_has_philly_and_branding():
    html = (WEB / "index.html").read_text(encoding="utf-8")
    assert "Philadelphia" in html
    assert "Hacker Planet LLC" in html
    assert "CyberThreatGotchi" in html
    assert "shop.html" in html


def test_about_page_content():
    html = (WEB / "about.html").read_text(encoding="utf-8")
    assert "Cipherhorn" in html
    assert "Andy Klwal" in html


def test_sync_website_to_docs():
    subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "sync_website_to_docs.py")],
        check=True,
    )
    assert (DOCS_WEB / "shop.html").is_file()
    assert (DOCS_WEB / "js" / "payments.js").is_file()
    shop = (DOCS_WEB / "shop.html").read_text(encoding="utf-8")
    assert "Hacker Planet LLC" in shop
