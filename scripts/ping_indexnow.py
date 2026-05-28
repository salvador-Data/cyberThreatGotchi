#!/usr/bin/env python3
"""Ping Bing IndexNow after deploy (optional — run when site content changes)."""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEO_JSON = ROOT / "website" / "seo" / "site.json"
INDEXNOW_ENDPOINT = "https://api.indexnow.org/indexnow"


def _load_config() -> dict:
    return json.loads(SEO_JSON.read_text(encoding="utf-8"))


def _page_urls(cfg: dict) -> list[str]:
    base = cfg["canonicalBase"].rstrip("/")
    urls: list[str] = []
    for filename in cfg.get("pages", {}):
        loc = base + "/" if filename == "index.html" else f"{base}/{filename}"
        urls.append(loc)
    return urls


def ping(urls: list[str] | None = None, *, dry_run: bool = False) -> int:
    cfg = _load_config()
    key = (cfg.get("indexNowKey") or "").strip()
    host = cfg["canonicalBase"].replace("https://", "").replace("http://", "").rstrip("/")
    if not key:
        print("indexNowKey not set in site.json", file=sys.stderr)
        return 1

    url_list = urls if urls is not None else _page_urls(cfg)
    key_location = f"{cfg['canonicalBase'].rstrip('/')}/{key}.txt"
    payload = {
        "host": host,
        "key": key,
        "keyLocation": key_location,
        "urlList": url_list,
    }

    if dry_run:
        print(json.dumps(payload, indent=2))
        return 0

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        INDEXNOW_ENDPOINT,
        data=data,
        headers={"Content-Type": "application/json; charset=utf-8"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            print(f"IndexNow OK ({resp.status}) — {len(url_list)} URL(s)")
            return 0
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        print(f"IndexNow HTTP {exc.code}: {body}", file=sys.stderr)
        return 1
    except urllib.error.URLError as exc:
        print(f"IndexNow failed: {exc.reason}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    dry = "--dry-run" in sys.argv
    raise SystemExit(ping(dry_run=dry))
