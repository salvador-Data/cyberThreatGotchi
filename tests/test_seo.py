"""SEO config and injected head tags."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "website"
SEO_JSON = WEB / "seo" / "site.json"


def _load_pages() -> dict:
    return json.loads(SEO_JSON.read_text(encoding="utf-8"))["pages"]


def test_seo_config_valid():
    data = json.loads(SEO_JSON.read_text(encoding="utf-8"))
    assert data["canonicalBase"] == "https://hackerplanet.dev"
    assert data["siteName"] == "Hacker Planet"
    assert "Hacker Planet LLC" in data.get("alternateNames", [])
    assert "https://hackerplanet.dev" in data.get("sameAs", [])
    assert "salvadorData@proton.me" in data["email"]
    assert len(data["pages"]) >= 12
    assert "cybersecurity-philadelphia.html" in data["pages"]
    assert "hacker-planet.html" in data["pages"]
    assert data.get("indexNowKey")


def test_robots_and_sitemap():
    robots = (WEB / "robots.txt").read_text(encoding="utf-8")
    assert "Sitemap: https://hackerplanet.dev/sitemap.xml" in robots
    for bot in (
        "Googlebot",
        "Bingbot",
        "DuckDuckBot",
        "Slurp",
        "Yandex",
        "Applebot",
        "Baiduspider",
        "Brave",
        "facebot",
    ):
        assert f"User-agent: {bot}" in robots, bot
        assert "Allow: /" in robots
    assert "Disallow: /js/payments.config.js" in robots
    sitemap = (WEB / "sitemap.xml").read_text(encoding="utf-8")
    assert "https://hackerplanet.dev/shop.html" in sitemap
    assert "https://hackerplanet.dev/cardputer.html" in sitemap
    assert "https://hackerplanet.dev/cyd.html" in sitemap
    assert "https://hackerplanet.dev/cybersecurity-philadelphia.html" in sitemap
    assert "https://hackerplanet.dev/kickstarter.html" in sitemap
    assert "https://hackerplanet.dev/hacker-planet.html" in sitemap


def test_faq_schema_on_key_pages():
    for name in ("index.html", "cybersecurity-philadelphia.html"):
        html = (WEB / name).read_text(encoding="utf-8")
        assert "FAQPage" in html, name
        assert "Question" in html, name


def test_brand_page_and_home_links():
    brand = (WEB / "hacker-planet.html").read_text(encoding="utf-8")
    assert "<h1" in brand
    assert "Hacker Planet" in brand
    assert "official" in brand.lower()
    for name in _load_pages():
        if name == "hacker-planet.html":
            continue
        html = (WEB / name).read_text(encoding="utf-8")
        assert 'href="index.html">Hacker Planet</a>' in html, name


def test_index_brand_in_h1_and_lead():
    html = (WEB / "index.html").read_text(encoding="utf-8")
    assert "<h1" in html
    assert "Hacker Planet" in html
    assert "official site" in html.lower() or "Official site" in html


def test_all_pages_have_seo_markers():
    pages = _load_pages()
    for name in pages:
        html = (WEB / name).read_text(encoding="utf-8")
        assert "<!-- hpl-seo:start -->" in html, name
        assert "<!-- hpl-seo:end -->" in html, name
        assert 'rel="canonical"' in html, name
        assert "application/ld+json" in html, name
        assert 'name="twitter:card"' in html, name
        assert 'property="og:image"' in html, name
        assert 'name="geo.placename"' in html, name


def test_no_duplicate_titles():
    pages = _load_pages()
    titles = [meta["title"] for meta in pages.values()]
    assert len(titles) == len(set(titles)), "duplicate titles in site.json"


def test_brand_in_all_titles():
    pages = _load_pages()
    for name, meta in pages.items():
        title = meta["title"]
        assert title.startswith("Hacker Planet |"), f"{name}: {title!r}"


def test_brand_in_injected_head_tags():
    pages = _load_pages()
    for name in pages:
        html = (WEB / name).read_text(encoding="utf-8")
        assert 'property="og:site_name" content="Hacker Planet"' in html, name
        assert "Hacker Planet |" in html, name


def test_organization_schema_brand_name():
    html = (WEB / "index.html").read_text(encoding="utf-8")
    assert '"name": "Hacker Planet"' in html or '"name":"Hacker Planet"' in html
    assert "alternateName" in html
    assert "WebSite" in html
    assert "Organization" in html or "LocalBusiness" in html


def test_json_ld_valid_on_all_pages():
    pages = _load_pages()
    pattern = re.compile(
        r'<script type="application/ld\+json">(.*?)</script>',
        re.S,
    )
    for name in pages:
        html = (WEB / name).read_text(encoding="utf-8")
        blocks = pattern.findall(html)
        assert blocks, f"no JSON-LD in {name}"
        for raw in blocks:
            parsed = json.loads(raw.strip())
            assert parsed.get("@context") == "https://schema.org"
            assert "@type" in parsed


def test_local_business_schema_city_only():
    html = (WEB / "cybersecurity-philadelphia.html").read_text(encoding="utf-8")
    assert "LocalBusiness" in html or "localBusiness" in (WEB / "seo" / "site.json").read_text()
    assert "664 Walker" not in html
    assert "addressLocality" in html or '"Philadelphia"' in html


def test_indexnow_key_file():
    cfg = json.loads(SEO_JSON.read_text(encoding="utf-8"))
    key = cfg["indexNowKey"]
    key_path = WEB / f"{key}.txt"
    assert key_path.is_file(), key_path.name
    assert key_path.read_text(encoding="utf-8").strip() == key


def test_cybersecurity_philadelphia_page_content():
    html = (WEB / "cybersecurity-philadelphia.html").read_text(encoding="utf-8")
    assert "<h1" in html
    assert "ethical hacking" in html.lower()
    assert "authorized" in html.lower()
    assert "remote" in html.lower()
    assert "Philadelphia" in html
    assert "salvadorData@proton.me" in html
    assert "cybersecurity-philadelphia.html" in (WEB / "index.html").read_text(encoding="utf-8")
    index = (WEB / "index.html").read_text(encoding="utf-8")
    assert "kickstarter.html" in index


def test_sync_seo_script():
    r = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "sync_seo.py")],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )
    assert r.returncode == 0, r.stderr


def test_seo_verification_dns_doc_mode():
    r = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "seo_verification_dns.py"), "--doc"],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )
    assert r.returncode == 0, r.stderr
    assert "google-site-verification=" in r.stdout
    assert "verify.bing.com" in r.stdout


def test_ping_indexnow_dry_run():
    r = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "ping_indexnow.py"), "--dry-run"],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )
    assert r.returncode == 0, r.stderr + r.stdout
    assert "hackerplanet.dev" in r.stdout
