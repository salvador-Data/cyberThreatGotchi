#!/usr/bin/env python3
"""HTTP-check all public GitHub Pages URLs for the Hacker Planet site."""

from __future__ import annotations

import sys
import urllib.error
import urllib.request

BASE = "https://salvador-Data.github.io/cyberThreatGotchi/"
PAGES = (
    "",
    "index.html",
    "about.html",
    "services.html",
    "shop.html",
    "contact.html",
    "cyberthreatgotchi.html",
    "ecosystem.html",
    "github.html",
    "crackbot.html",
)


def check(url: str) -> tuple[int | None, str]:
    req = urllib.request.Request(url, method="HEAD")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status, ""
    except urllib.error.HTTPError as e:
        return e.code, str(e.reason)
    except urllib.error.URLError as e:
        return None, str(e.reason)


def main() -> int:
    failed = 0
    for page in PAGES:
        url = BASE if not page else BASE + page
        code, err = check(url)
        if code == 200:
            print(f"OK  {code}  {url}")
        else:
            failed += 1
            print(f"FAIL {code or '?'}  {url}  {err}", file=sys.stderr)
    if failed:
        print(f"\n{failed} page(s) failed", file=sys.stderr)
        return 1
    print(f"\nAll {len(PAGES)} URLs returned HTTP 200")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
