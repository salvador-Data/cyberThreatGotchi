#!/usr/bin/env python3
"""HTTP-check all public GitHub Pages URLs for the Hacker Planet site."""

from __future__ import annotations

import socket
import sys
import urllib.error
import urllib.request

GITHUB_IO_BASE = "https://salvador-Data.github.io/cyberThreatGotchi/"
CUSTOM_DOMAIN = "hackerplanet.dev"
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
    "cardputer.html",
)


def domain_resolves(hostname: str) -> bool:
    try:
        socket.getaddrinfo(hostname, 443, type=socket.SOCK_STREAM)
        return True
    except OSError:
        return False


def check(url: str) -> tuple[int | None, str]:
    req = urllib.request.Request(url, method="HEAD")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status, ""
    except urllib.error.HTTPError as e:
        return e.code, str(e.reason)
    except urllib.error.URLError as e:
        return None, str(e.reason)


def check_base(label: str, base: str) -> int:
    failed = 0
    for page in PAGES:
        url = base if not page else base + page
        code, err = check(url)
        if code == 200:
            print(f"OK  {code}  [{label}] {url}")
        else:
            failed += 1
            print(f"FAIL {code or '?'}  [{label}] {url}  {err}", file=sys.stderr)
    return failed


def main() -> int:
    failed = check_base("github.io", GITHUB_IO_BASE)

    if domain_resolves(CUSTOM_DOMAIN):
        print(f"\n{CUSTOM_DOMAIN} resolves — checking custom domain")
        failed += check_base(CUSTOM_DOMAIN, f"https://{CUSTOM_DOMAIN}/")
    else:
        print(f"\nSKIP  {CUSTOM_DOMAIN} (DNS not propagated yet)")

    if failed:
        print(f"\n{failed} page(s) failed", file=sys.stderr)
        return 1
    checked = len(PAGES) * (2 if domain_resolves(CUSTOM_DOMAIN) else 1)
    print(f"\nAll checked URLs returned HTTP 200 ({checked} total)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
