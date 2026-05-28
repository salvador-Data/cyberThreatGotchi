"""SEO config and injected head tags."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "website"
SEO_JSON = WEB / "seo" / "site.json"


def test_seo_config_valid():
    data = json.loads(SEO_JSON.read_text(encoding="utf-8"))
    assert data["canonicalBase"] == "https://hackerplanet.dev"
    assert "salvadorData@proton.me" in data["email"]
    assert len(data["pages"]) >= 10


def test_robots_and_sitemap():
    robots = (WEB / "robots.txt").read_text(encoding="utf-8")
    assert "Sitemap: https://hackerplanet.dev/sitemap.xml" in robots
    sitemap = (WEB / "sitemap.xml").read_text(encoding="utf-8")
    assert "https://hackerplanet.dev/shop.html" in sitemap
    assert "https://hackerplanet.dev/cardputer.html" in sitemap


def test_all_pages_have_seo_markers():
    pages = json.loads(SEO_JSON.read_text(encoding="utf-8"))["pages"]
    for name in pages:
        html = (WEB / name).read_text(encoding="utf-8")
        assert "<!-- hpl-seo:start -->" in html, name
        assert "<!-- hpl-seo:end -->" in html, name
        assert 'rel="canonical"' in html, name
        assert "application/ld+json" in html, name
        assert 'name="twitter:card"' in html, name
        assert 'property="og:image"' in html, name


def test_sync_seo_script():
    r = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "sync_seo.py")],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )
    assert r.returncode == 0, r.stderr
