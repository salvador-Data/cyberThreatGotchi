#!/usr/bin/env python3
"""Apply GitHub Pages DNS records to Cloudflare via API.

Requires environment variable:
  CF_API_TOKEN — Zone.DNS Edit + Zone.Read (zone hackerplanet.dev)

Optional:
  CF_ZONE_ID — defaults to Hacker Planet zone id below

Usage:
  set CF_API_TOKEN=your_token
  python scripts/cloudflare_apply_dns.py
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

ZONE_ID = os.environ.get("CF_ZONE_ID", "c81e69edbf957423a22392798309fc35")
ZONE_NAME = "hackerplanet.dev"
GITHUB_A = [
    "185.199.108.153",
    "185.199.109.153",
    "185.199.110.153",
    "185.199.111.153",
]
WWW_CNAME = "salvador-Data.github.io"


def _api(method: str, path: str, body: dict | None = None) -> dict:
    token = os.environ.get("CF_API_TOKEN", "").strip()
    if not token:
        print("Set CF_API_TOKEN (Zone.DNS Edit + Zone.Read).", file=sys.stderr)
        print("Create at: https://dash.cloudflare.com/profile/api-tokens", file=sys.stderr)
        return {"success": False, "errors": [{"message": "missing CF_API_TOKEN"}]}

    url = f"https://api.cloudflare.com/client/v4{path}"
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        payload = e.read().decode("utf-8", errors="replace")
        try:
            return json.loads(payload)
        except json.JSONDecodeError:
            return {"success": False, "errors": [{"message": payload}]}


def main() -> int:
    zone = _api("GET", f"/zones/{ZONE_ID}")
    if not zone.get("success"):
        print(json.dumps(zone, indent=2), file=sys.stderr)
        return 1

    status = zone["result"]["status"]
    print(f"Zone {ZONE_NAME}: status={status}")
    if status != "active":
        print(
            "Zone is not active yet — finish domain registration in Cloudflare Registrar first.",
            file=sys.stderr,
        )
        return 1

    existing = _api("GET", f"/zones/{ZONE_ID}/dns_records?per_page=100")
    records = existing.get("result") or []
    by_key = {(r["type"], r["name"], r["content"]): r for r in records}

    for ip in GITHUB_A:
        key = ("A", ZONE_NAME, ip)
        body = {"type": "A", "name": "@", "content": ip, "proxied": False, "ttl": 1}
        if key in by_key:
            rid = by_key[key]["id"]
            r = _api("PATCH", f"/zones/{ZONE_ID}/dns_records/{rid}", body)
            print(f"PATCH A @ -> {ip}: {r.get('success')}")
        else:
            r = _api("POST", f"/zones/{ZONE_ID}/dns_records", body)
            print(f"POST A @ -> {ip}: {r.get('success')}")
        if not r.get("success"):
            print(json.dumps(r, indent=2), file=sys.stderr)
            return 1

    # Demote any other proxied apex A records
    for r in records:
        if r["type"] == "A" and r["name"] == ZONE_NAME and r.get("proxied"):
            if r["content"] not in GITHUB_A:
                continue
            patch = _api(
                "PATCH",
                f"/zones/{ZONE_ID}/dns_records/{r['id']}",
                {"proxied": False},
            )
            print(f"Grey-cloud A {r['content']}: {patch.get('success')}")

    www_key = ("CNAME", f"www.{ZONE_NAME}", WWW_CNAME)
    www_body = {
        "type": "CNAME",
        "name": "www",
        "content": WWW_CNAME,
        "proxied": False,
        "ttl": 1,
    }
    if www_key in by_key:
        r = _api("PATCH", f"/zones/{ZONE_ID}/dns_records/{by_key[www_key]['id']}", www_body)
        print(f"PATCH CNAME www: {r.get('success')}")
    else:
        r = _api("POST", f"/zones/{ZONE_ID}/dns_records", www_body)
        print(f"POST CNAME www: {r.get('success')}")
    if not r.get("success"):
        print(json.dumps(r, indent=2), file=sys.stderr)
        return 1

    print("DNS applied (DNS only / grey cloud). Next: GitHub Pages Enforce HTTPS.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
