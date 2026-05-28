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


def test_shop_config_alignment():
    import subprocess

    r = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "check_shop.py")],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )
    assert r.returncode == 0, r.stdout + r.stderr


def test_shipping_config_structure():
    text = (WEB / "js" / "shipping.config.js").read_text(encoding="utf-8")
    assert "HPL_SHIPPING" in text
    assert "shipFrom" in text
    assert "664 Walker Street" in text
    assert "11135" in text
    assert "publicLabel" in text
    assert "sabretoAkachi" in text
    assert "fulfillment: \"direct\"" in text or '"direct"' in text
    assert "nexusStates" in text


def test_no_street_address_on_public_site():
    for html_file in WEB.glob("*.html"):
        text = html_file.read_text(encoding="utf-8")
        assert "664 Walker" not in text, html_file.name
        assert "Walker Street" not in text, html_file.name
        assert "11135" not in text, html_file.name


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
    assert "HackerPlanet" in html
    assert "Hacker Planet LLC" in html
    assert "CyberThreatGotchi" in html
    assert "shop.html" in html
    assert "featured-shop" in html
    assert "images/products/ds-netgotchi.jpg" in html
    assert "ThreatGachi" not in html
    assert ">ThreatGotchi" not in html
    assert "ThreatGotchi ·" not in html


def test_catalog_product_images():
    text = (WEB / "js" / "catalog.config.js").read_text(encoding="utf-8")
    assert 'image: "images/products/ds-netgotchi.jpg"' in text
    assert 'image: "images/products/ds-night-hunter.jpg"' in text
    assert (WEB / "images" / "products" / "ds-netgotchi.jpg").is_file()
    assert (WEB / "images" / "products" / "ds-night-hunter.jpg").is_file()


def test_direct_product_images():
    text = (WEB / "js" / "direct.config.js").read_text(encoding="utf-8")
    assert 'image: "images/products/direct-sabreto-akachi.jpg"' in text
    assert (WEB / "images" / "products" / "direct-sabreto-akachi.jpg").is_file()


def test_shop_renderers_support_images():
    for name in ("catalog.js", "direct.js"):
        text = (WEB / "js" / name).read_text(encoding="utf-8")
        assert "shop-card-img" in text


def test_about_page_content():
    html = (WEB / "about.html").read_text(encoding="utf-8")
    assert "Cipherhorn" in html or "CypherTek" in html
    assert "Andy Klwal" in html
    assert "Pat" in html
    assert "Philadelphia" in html
    assert "Mr. CrackBot" in html or "CrackBot" in html
    assert "Hacker Planet LLC" in html


def test_no_warehouse_address_in_public_html():
    forbidden = ("664 Walker", "664 Walker Street", "11135")
    for html_file in sorted(WEB.glob("*.html")):
        text = html_file.read_text(encoding="utf-8")
        for token in forbidden:
            assert token not in text, f"{token!r} found in website/{html_file.name}"


def test_shipping_config_has_internal_warehouse():
    text = (WEB / "js" / "shipping.config.js").read_text(encoding="utf-8")
    assert "664 Walker Street" in text
    assert "11135" in text
    assert "line1:" in text
    assert "Pat" in html
    assert "Philadelphia" in html
    assert "Hacker Planet LLC" in html
    assert "ecosystem.html" in html
    assert "shop.html" in html


def test_sync_website_to_docs():
    subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "sync_website_to_docs.py")],
        check=True,
    )
    assert (DOCS_WEB / "shop.html").is_file()
    assert (DOCS_WEB / "js" / "payments.js").is_file()
    shop = (DOCS_WEB / "shop.html").read_text(encoding="utf-8")
    assert "HackerPlanet" in shop
