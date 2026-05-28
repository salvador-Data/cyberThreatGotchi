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
        "services.html",
        "cyberthreatgotchi.html",
        "crackbot.html",
        "cardputer.html",
        "cyd.html",
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
        "robots.txt",
        "sitemap.xml",
        "seo/site.json",
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
    assert "cydStandard" in text
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
    assert "cydStandard" in text
    assert "tagline:" in text
    assert "HPL signature profile" in text
    assert "crackbotBench" in text
    assert 'fulfillment: "direct"' in text


def test_catalog_config_structure():
    text = (WEB / "js" / "catalog.config.js").read_text(encoding="utf-8")
    assert "HPL_CATALOG" in text
    assert "gotchi-pods" in text
    assert "banner-gotchi-pods.png" in text
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
    assert "Verify domain" in html or "verify domain" in html.lower()
    assert "/cyberThreatGotchi/" in html
    assert "github.io/services.html" in html


def test_services_page_content():
    html = (WEB / "services.html").read_text(encoding="utf-8")
    assert "Blue Team" in html
    assert "Red Team" in html
    assert "OSINT" in html
    assert "UTM" in html
    assert "DDoS" in html
    assert "hello@hackerplanet.dev" in html
    assert "$1,500" in html
    assert "Dr. Eric" not in html
    assert "services.html" in (WEB / "index.html").read_text(encoding="utf-8")


def test_nav_includes_services_on_all_pages():
    for html_file in sorted(WEB.glob("*.html")):
        text = html_file.read_text(encoding="utf-8")
        assert 'href="services.html"' in text, html_file.name


def test_nav_includes_crackbot_on_all_pages():
    for html_file in sorted(WEB.glob("*.html")):
        text = html_file.read_text(encoding="utf-8")
        assert 'href="crackbot.html"' in text, html_file.name


def test_nav_includes_cardputer_on_all_pages():
    for html_file in sorted(WEB.glob("*.html")):
        text = html_file.read_text(encoding="utf-8")
        assert 'href="cardputer.html"' in text, html_file.name


def test_crackbot_page_content():
    html = (WEB / "crackbot.html").read_text(encoding="utf-8")
    assert "Mr. CrackBot AI Nano" in html
    assert "$449" in html
    assert "$149" not in html
    assert "simulation" in html.lower()
    assert "vlan" in html.lower() and "authorized" in html.lower()
    assert "Mr.-CrackBot-AI-Nano" in html
    assert "hardware/stl" in html
    assert "shop.html#crackbot-bench" in html
    assert "$0" in html
    assert "CYD" in html
    assert "Not a CYD product" in html or "not a CYD" in html.lower()


def test_cardputer_page_content():
    html = (WEB / "cardputer.html").read_text(encoding="utf-8")
    assert "Remote Possibility" in html
    assert "BLE Bot" in html
    assert "$89.99" in html
    assert "$79.99" in html
    assert "M5_OS-Cardputer" in html
    assert "shop.html#remote-possibility" in html
    assert "Firmware downloads" in html
    assert 'id="firmware"' in html
    assert "CARDPUTER_PRODUCTS.md" in html


def test_cyd_page_content():
    html = (WEB / "cyd.html").read_text(encoding="utf-8")
    assert "CYD Field Build" in html
    assert "Sabreto" not in html
    assert "Akachi" not in html
    assert "$79.99" in html
    assert "$174.99" in html
    assert "Firmware downloads" in html
    assert 'id="firmware"' in html
    assert "shop.html#cyd-standard" in html
    assert "Not" in html and "CrackBot" in html


def test_product_firmware_sections():
    for name in ("crackbot.html", "cyberthreatgotchi.html"):
        html = (WEB / name).read_text(encoding="utf-8")
        assert "Firmware downloads" in html, name
        assert 'id="firmware"' in html, name
    crackbot = (WEB / "crackbot.html").read_text(encoding="utf-8")
    assert "Mr.-CrackBot-AI-Nano/releases" in crackbot
    ctg = (WEB / "cyberthreatgotchi.html").read_text(encoding="utf-8")
    assert "releases/tag/v1.1.0" in ctg


def test_shop_product_lines_intro():
    html = (WEB / "shop.html").read_text(encoding="utf-8")
    assert "crackbot-build" in html
    assert "$449" in html
    assert "$79.99" in html
    assert "$174.99" in html
    assert "crackbot.html" in html
    assert "cardputer.html" in html


def test_ecosystem_crackbot_pricing():
    html = (WEB / "ecosystem.html").read_text(encoding="utf-8")
    assert "$449" in html
    assert "$79.99" in html
    assert "crackbot.html" in html
    assert "Remote Possibility" in html


def test_no_dr_eric_as_agent_on_public_html():
    forbidden = ("Dr. Eric", "Dr.Eric")
    for html_file in sorted(WEB.glob("*.html")):
        text = html_file.read_text(encoding="utf-8")
        for token in forbidden:
            assert token not in text, f"{token!r} in {html_file.name}"


def test_index_has_philly_and_branding():
    html = (WEB / "index.html").read_text(encoding="utf-8")
    assert "Philadelphia" in html
    assert "HackerPlanet" in html
    assert "Hacker Planet LLC" in html
    assert "CyberThreatGotchi" in html
    assert "CypherTek Rache kit" not in html
    assert "Cypertech" not in html
    assert "<h3>CyberThreatGotchi</h3>" in html
    assert "services.html" in html
    assert "Blue Team" in html or "OSINT" in html
    assert "shop.html" in html
    assert "featured-shop" in html
    assert "images/products/ds-netgotchi.jpg" in html
    assert "images/products/direct-cyd-standard.jpg" in html
    assert "$79.99" in html
    assert "$189" not in html
    assert "ThreatGachi" not in html
    assert ">ThreatGotchi" not in html
    assert "ThreatGotchi ·" not in html
    assert "🦄" not in html


def test_catalog_product_images():
    text = (WEB / "js" / "catalog.config.js").read_text(encoding="utf-8")
    assert 'image: "images/products/ds-netgotchi.jpg"' in text
    assert 'image: "images/products/ds-night-hunter.jpg"' in text
    assert 'image: "images/products/ds-rpi5-kit.jpg"' in text
    assert 'image: "images/products/ds-meshtastic-case.jpg"' in text
    assert (WEB / "images" / "products" / "ds-netgotchi.jpg").is_file()
    assert (WEB / "images" / "products" / "ds-night-hunter.jpg").is_file()
    assert (WEB / "images" / "products" / "ds-rpi5-kit.jpg").is_file()
    assert (WEB / "images" / "products" / "ds-meshtastic-case.jpg").is_file()


def test_direct_core_kit_product_name():
    text = (WEB / "js" / "direct.config.js").read_text(encoding="utf-8")
    assert 'id: "coreKit"' in text
    assert 'name: "CyberThreatGotchi"' in text
    assert "Cipherhorn Core Kit" not in text
    pay = (WEB / "js" / "payments.js").read_text(encoding="utf-8")
    assert 'name: "CyberThreatGotchi"' in pay
    assert "Cipherhorn Core Kit" not in pay


def test_direct_config_pricing_separation():
    text = (WEB / "js" / "direct.config.js").read_text(encoding="utf-8")
    assert 'id: "crackbotBench"' in text
    assert 'id: "cydFieldCustom"' in text
    assert "crackbotCyd" not in text
    assert "marauderCustom175" not in text
    assert 'retailPrice: 79.99' in text
    assert 'retailPrice: 174.99' in text
    assert 'retailPrice: 449' in text
    assert 'remotePossibility' in text
    assert 'bleBot' in text
    pay = (WEB / "js" / "payments.js").read_text(encoding="utf-8")
    assert "crackbotCyd" not in pay
    assert "crackbotBench" in pay


def test_direct_product_images():
    text = (WEB / "js" / "direct.config.js").read_text(encoding="utf-8")
    assert 'image: "images/products/direct-cyd-standard.jpg"' in text
    assert 'image: "images/products/direct-core-kit.jpg"' in text
    assert 'image: "images/products/mr-pac-bot-product.png"' in text
    assert (WEB / "images" / "products" / "direct-cyd-standard.jpg").is_file()
    assert (WEB / "images" / "products" / "direct-core-kit.jpg").is_file()
    assert (WEB / "images" / "products" / "mr-pac-bot-product.png").is_file()


def test_shop_flows_avoid_mascot_og_assets():
    """Shop, home featured, and checkout pages use hardware photos — not CTG cartoon OG."""
    forbidden = (
        "docs/images/hero.png",
        "docs/images/og-cyberthreatgotchi.png",
        "docs/images/og-ecosystem.png",
    )
    for name in ("index.html", "shop.html", "ecosystem.html", "about.html"):
        text = (WEB / name).read_text(encoding="utf-8")
        for token in forbidden:
            assert token not in text, f"{token!r} in website/{name}"
    shop_js = (WEB / "js" / "payments.js").read_text(encoding="utf-8")
    for token in forbidden:
        assert token not in shop_js


def test_cybertech_imagery_assets():
    for name in ("hero-cybertech.png", "og-cybertech.png", "banner-gotchi-pods.png"):
        assert (WEB / "images" / name).is_file(), name
    index = (WEB / "index.html").read_text(encoding="utf-8")
    assert "images/hero-cybertech.png" in index
    assert "og-cybertech.png" in index
    ctg = (WEB / "cyberthreatgotchi.html").read_text(encoding="utf-8")
    assert "images/products/cyphertek-rache-product.jpg" in ctg
    catalog = (WEB / "js" / "catalog.config.js").read_text(encoding="utf-8")
    assert "banner-gotchi-pods.png" in catalog
    assert "Cyber wardrive pods" in catalog


def test_shop_renderers_support_images():
    for name in ("catalog.js", "direct.js"):
        text = (WEB / "js" / name).read_text(encoding="utf-8")
        assert "shop-card-img" in text
        assert "shop-tagline" in text
    assert "catalog-section-banner" in (WEB / "js" / "catalog.js").read_text(encoding="utf-8")
    direct = (WEB / "js" / "direct.js").read_text(encoding="utf-8")
    assert "crackbot-bench" in direct
    assert "cyd-standard" in direct


def test_about_page_content():
    html = (WEB / "about.html").read_text(encoding="utf-8")
    assert "Cipherhorn" in html or "CypherTek" in html
    assert "Andy Klwal" in html
    assert "Pat" in html
    assert "Philadelphia" in html
    assert "Mr. CrackBot" in html or "CrackBot" in html
    assert "Hacker Planet LLC" in html
    assert "ecosystem.html" in html
    assert "shop.html" in html


def test_contact_page_content():
    html = (WEB / "contact.html").read_text(encoding="utf-8")
    assert "Salvador Data" in html
    assert "Hacker Planet LLC" in html
    assert "Philadelphia" in html
    assert "salvadorData@proton.me" in html
    assert "hello@hackerplanet.dev" in html
    assert "MSP" in html
    assert "tel:+12158398738" in html
    assert "(215) 839-8738" in html
    assert "CONTACT_AND_PHONE.md" in html
    assert "services.html" in html
    assert "shop.html" in html
    assert "salvador-Data" in html
    assert "Salvador_Data" in html
    assert "email routing" in html.lower() or "mx records" in html.lower()


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
    assert "shipFrom" in text
    assert 'street: "664 Walker Street"' in text
    assert "publicLabel" in text
    origin_block = text.split("origin:")[1].split("disclaimer:")[0]
    assert "664 Walker" not in origin_block


def test_product_pricing_doc_exists():
    doc = ROOT / "docs" / "PRODUCT_PRICING.md"
    assert doc.is_file()
    text = doc.read_text(encoding="utf-8")
    assert "$79.99" in text
    assert "$174.99" in text
    assert "$449" in text
    assert "Remote Possibility" in text
    assert "BLE Bot" in text
    assert "crackbotCyd" in text  # deprecated table


def test_sync_website_to_docs():
    subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "sync_website_to_docs.py")],
        check=True,
    )
    assert (DOCS_WEB / "shop.html").is_file()
    assert (DOCS_WEB / "js" / "payments.js").is_file()
    shop = (DOCS_WEB / "shop.html").read_text(encoding="utf-8")
    assert "HackerPlanet" in shop
