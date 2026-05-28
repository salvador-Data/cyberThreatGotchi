"""Website static files exist and key pages load."""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "website"


def test_website_structure():
    for name in (
        "index.html",
        "about.html",
        "cyberthreatgotchi.html",
        "ecosystem.html",
        "contact.html",
        "css/style.css",
        "js/main.js",
        "README.md",
    ):
        assert (WEB / name).is_file(), name


def test_index_has_philly_and_branding():
    html = (WEB / "index.html").read_text(encoding="utf-8")
    assert "Philadelphia" in html
    assert "Hacker Planet LLC" in html
    assert "CyberThreatGotchi" in html
    assert "css/style.css" in html


def test_about_page_content():
    html = (WEB / "about.html").read_text(encoding="utf-8")
    assert "Cipherhorn" in html
    assert "Andy Klwal" in html
