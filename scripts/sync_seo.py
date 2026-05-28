#!/usr/bin/env python3
"""Inject SEO meta tags, JSON-LD, robots.txt, sitemap.xml, and IndexNow key into website/."""

from __future__ import annotations

import json
import re
import sys
from html import escape
from pathlib import Path
from typing import Any
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "website"
SEO_JSON = WEB / "seo" / "site.json"
MARKER_START = "<!-- hpl-seo:start -->"
MARKER_END = "<!-- hpl-seo:end -->"

SEARCH_BOTS = (
    "Googlebot",
    "Bingbot",
    "DuckDuckBot",
    "Slurp",
    "facebot",
    "Yandex",
)


def _load_config() -> dict[str, Any]:
    return json.loads(SEO_JSON.read_text(encoding="utf-8"))


def _abs(base: str, path: str) -> str:
    if path.startswith("http://") or path.startswith("https://"):
        return path
    return base.rstrip("/") + "/" + path.lstrip("/")


def _page_label(filename: str) -> str:
    return Path(filename).stem.replace("-", " ").title()


def _city_address(cfg: dict[str, Any]) -> dict[str, Any]:
    return {
        "@type": "PostalAddress",
        "addressLocality": cfg["addressLocality"],
        "addressRegion": cfg["addressRegion"],
        "addressCountry": cfg["addressCountry"],
    }


def _area_served(cfg: dict[str, Any]) -> list[dict[str, Any]]:
    areas: list[dict[str, Any]] = [
        {
            "@type": "City",
            "name": cfg["addressLocality"],
            "containedInPlace": {
                "@type": "State",
                "name": cfg["addressRegion"],
                "containedInPlace": {"@type": "Country", "name": "United States"},
            },
        }
    ]
    for name in cfg.get("serviceAreaLocal", []):
        if name == cfg["addressLocality"]:
            continue
        areas.append({"@type": "AdministrativeArea", "name": name})
    for name in cfg.get("serviceAreaRemote", []):
        areas.append({"@type": "Country" if name == "United States" else "AdministrativeArea", "name": name})
    return areas


def _breadcrumb_ld(base: str, filename: str, site_name: str) -> dict[str, Any]:
    path = "" if filename == "index.html" else filename
    url = _abs(base, path)
    items = [
        {
            "@type": "ListItem",
            "position": 1,
            "name": site_name,
            "item": base.rstrip("/") + "/",
        }
    ]
    if filename != "index.html":
        items.append(
            {
                "@type": "ListItem",
                "position": 2,
                "name": _page_label(filename),
                "item": url,
            }
        )
    return {
        "@context": "https://schema.org",
        "@type": "BreadcrumbList",
        "itemListElement": items,
    }


def _local_business_ld(cfg: dict[str, Any], base: str) -> dict[str, Any]:
    return {
        "@context": "https://schema.org",
        "@type": ["LocalBusiness", "Organization"],
        "name": cfg["legalName"],
        "alternateName": cfg["siteName"],
        "url": base.rstrip("/") + "/",
        "logo": _abs(base, cfg["defaultOgImage"]),
        "email": cfg["email"],
        "telephone": cfg["phone"],
        "address": _city_address(cfg),
        "areaServed": _area_served(cfg),
        "sameAs": cfg.get("sameAs", []),
        "description": (
            "Philadelphia cybersecurity firm — Blue Team, Red Team, OSINT, remote US consulting, "
            "and authorized ethical hacking lab hardware. City-only public address; no walk-in retail."
        ),
    }


def _organization_ld(cfg: dict[str, Any], base: str) -> dict[str, Any]:
    return _local_business_ld(cfg, base)


def _website_ld(cfg: dict[str, Any], base: str) -> dict[str, Any]:
    return {
        "@context": "https://schema.org",
        "@type": "WebSite",
        "name": cfg["siteName"],
        "url": base.rstrip("/") + "/",
        "publisher": {"@type": "Organization", "name": cfg["legalName"]},
    }


def _professional_service_ld(cfg: dict[str, Any], base: str) -> dict[str, Any]:
    return {
        "@context": "https://schema.org",
        "@type": "ProfessionalService",
        "name": cfg["legalName"],
        "url": base.rstrip("/") + "/",
        "email": cfg["email"],
        "telephone": cfg["phone"],
        "areaServed": _area_served(cfg),
        "address": _city_address(cfg),
        "serviceType": [
            "Cybersecurity consulting",
            "Managed Blue Team",
            "Authorized Red Team assessment",
            "OSINT investigation",
            "Ethical hacking lab hardware",
            "Remote cybersecurity consulting",
        ],
    }


def _contact_page_ld(cfg: dict[str, Any], base: str) -> dict[str, Any]:
    return {
        "@context": "https://schema.org",
        "@type": "ContactPage",
        "name": "Contact Hacker Planet LLC",
        "url": _abs(base, "contact.html"),
    }


def _product_ld(page: dict[str, Any], cfg: dict[str, Any], base: str, filename: str) -> dict[str, Any]:
    return {
        "@context": "https://schema.org",
        "@type": "Product",
        "name": page["title"].split("·")[0].strip(),
        "description": page["description"],
        "brand": {"@type": "Brand", "name": cfg["siteName"]},
        "url": _abs(base, filename if filename != "index.html" else ""),
    }


def _json_ld_blocks(
    cfg: dict[str, Any], page: dict[str, Any], base: str, filename: str
) -> list[dict[str, Any]]:
    blocks: list[dict[str, Any]] = []
    for kind in page.get("jsonLd", []):
        if kind in ("organization", "localBusiness"):
            blocks.append(_local_business_ld(cfg, base))
        elif kind == "website":
            blocks.append(_website_ld(cfg, base))
        elif kind == "professionalService":
            blocks.append(_professional_service_ld(cfg, base))
        elif kind == "contactPage":
            blocks.append(_contact_page_ld(cfg, base))
        elif kind == "product":
            blocks.append(_product_ld(page, cfg, base, filename))
        elif kind == "breadcrumb":
            blocks.append(_breadcrumb_ld(base, filename, cfg["siteName"]))
    return blocks


def _seo_block(cfg: dict[str, Any], page: dict[str, Any], filename: str) -> str:
    base = cfg["canonicalBase"]
    path = "" if filename == "index.html" else filename
    canonical = _abs(base, path)
    gh_alt = _abs(cfg["githubPagesBase"], path)
    og_image = _abs(base, page.get("ogImage", cfg["defaultOgImage"]))
    title = page["title"]
    desc = page["description"]
    keywords = page.get("keywords", "")
    og_type = page.get("ogType", "website")

    lines = [
        MARKER_START,
        f"  <title>{escape(title)}</title>",
        f'  <meta name="description" content="{escape(desc)}"/>',
        f'  <meta name="keywords" content="{escape(keywords)}"/>',
        f'  <meta name="author" content="{escape(cfg["author"])}"/>',
        '  <meta name="robots" content="index, follow, max-image-preview:large"/>',
        f'  <meta name="geo.region" content="{escape(cfg["region"])}"/>',
        f'  <meta name="geo.placename" content="{escape(cfg.get("geoPlacename", cfg["addressLocality"]))}"/>',
        f'  <link rel="canonical" href="{escape(canonical)}"/>',
        f'  <link rel="alternate" hreflang="en-us" href="{escape(canonical)}"/>',
        f'  <link rel="alternate" href="{escape(gh_alt)}"/>',
        f'  <meta property="og:site_name" content="{escape(cfg["siteName"])}"/>',
        f'  <meta property="og:locale" content="{escape(cfg["locale"])}"/>',
        f'  <meta property="og:type" content="{escape(og_type)}"/>',
        f'  <meta property="og:title" content="{escape(title)}"/>',
        f'  <meta property="og:description" content="{escape(desc)}"/>',
        f'  <meta property="og:url" content="{escape(canonical)}"/>',
        f'  <meta property="og:image" content="{escape(og_image)}"/>',
        '  <meta name="twitter:card" content="summary_large_image"/>',
        f'  <meta name="twitter:title" content="{escape(title)}"/>',
        f'  <meta name="twitter:description" content="{escape(desc)}"/>',
        f'  <meta name="twitter:image" content="{escape(og_image)}"/>',
    ]

    bing_code = (cfg.get("bingSiteVerification") or "").strip()
    if bing_code:
        lines.append(f'  <meta name="msvalidate.01" content="{escape(bing_code)}"/>')

    for block in _json_ld_blocks(cfg, page, base, filename):
        payload = json.dumps(block, ensure_ascii=False, separators=(",", ":"))
        lines.append(f'  <script type="application/ld+json">{payload}</script>')

    lines.append(f"  {MARKER_END}")
    return "\n".join(lines)


def _strip_legacy_seo(text: str) -> str:
    """Remove pre-SEO title/description/og tags outside hpl-seo markers."""
    if MARKER_START in text:
        before, rest = text.split(MARKER_START, 1)
        block, after = rest.split(MARKER_END, 1)
        before = re.sub(r"\n\s*<title>.*?</title>\s*", "\n", before, flags=re.S)
        before = re.sub(
            r'\n\s*<meta name="description" content="[^"]*"/>\s*',
            "\n",
            before,
        )
        before = re.sub(
            r'\n\s*<meta property="og:[^"]+" content="[^"]*"/>\s*',
            "\n",
            before,
        )
        after = re.sub(r"\n\s*<title>.*?</title>\s*", "\n", after, flags=re.S)
        after = re.sub(
            r'\n\s*<meta name="description" content="[^"]*"/>\s*',
            "\n",
            after,
        )
        after = re.sub(
            r'\n\s*<meta property="og:[^"]+" content="[^"]*"/>\s*',
            "\n",
            after,
        )
        return before + MARKER_START + block + MARKER_END + after

    text = re.sub(r"\n\s*<title>.*?</title>\s*", "\n", text, flags=re.S)
    text = re.sub(
        r'\n\s*<meta name="description" content="[^"]*"/>\s*',
        "\n",
        text,
    )
    text = re.sub(
        r'\n\s*<meta property="og:[^"]+" content="[^"]*"/>\s*',
        "\n",
        text,
    )
    return text


def _inject_page(html_path: Path, block: str) -> None:
    text = html_path.read_text(encoding="utf-8")
    pattern = re.compile(
        rf"{re.escape(MARKER_START)}.*?{re.escape(MARKER_END)}",
        re.S,
    )
    if pattern.search(text):
        text = pattern.sub(block, text, count=1)
    else:
        text = re.sub(
            r'(<meta charset="UTF-8"/>\s*)',
            r"\1" + block + "\n",
            text,
            count=1,
        )
    text = _strip_legacy_seo(text)
    html_path.write_text(text, encoding="utf-8")


def _write_robots(base: str) -> None:
    lines: list[str] = []
    for bot in SEARCH_BOTS:
        lines.extend([f"User-agent: {bot}", "Allow: /", ""])
    lines.extend(
        [
            "User-agent: *",
            "Allow: /",
            "Disallow: /js/payments.config.js",
            "",
            f"Sitemap: {base.rstrip('/')}/sitemap.xml",
            "",
        ]
    )
    (WEB / "robots.txt").write_text("\n".join(lines), encoding="utf-8")


def _write_sitemap(cfg: dict[str, Any]) -> None:
    base = cfg["canonicalBase"].rstrip("/")
    urlset = ET.Element(
        "urlset",
        xmlns="http://www.sitemaps.org/schemas/sitemap/0.9",
    )
    for filename, page in cfg["pages"].items():
        loc = base + "/" if filename == "index.html" else f"{base}/{filename}"
        url = ET.SubElement(urlset, "url")
        ET.SubElement(url, "loc").text = loc
        ET.SubElement(url, "changefreq").text = "weekly"
        priority = page.get("sitemapPriority", "0.8")
        ET.SubElement(url, "priority").text = priority
    tree = ET.ElementTree(urlset)
    ET.indent(tree, space="  ")
    tree.write(WEB / "sitemap.xml", encoding="utf-8", xml_declaration=True)


def _write_indexnow_key(cfg: dict[str, Any]) -> None:
    key = (cfg.get("indexNowKey") or "").strip()
    if not key:
        return
    key_path = WEB / f"{key}.txt"
    key_path.write_text(key + "\n", encoding="utf-8")


def sync() -> int:
    if not SEO_JSON.is_file():
        print(f"Missing {SEO_JSON}", file=sys.stderr)
        return 1
    cfg = _load_config()
    pages = cfg.get("pages", {})
    for filename, page in pages.items():
        html_path = WEB / filename
        if not html_path.is_file():
            print(f"Skip missing page: {filename}", file=sys.stderr)
            continue
        block = _seo_block(cfg, page, filename)
        _inject_page(html_path, block)
    _write_robots(cfg["canonicalBase"])
    _write_sitemap(cfg)
    _write_indexnow_key(cfg)
    print(f"SEO synced for {len(pages)} pages + robots.txt + sitemap.xml")
    return 0


if __name__ == "__main__":
    raise SystemExit(sync())
