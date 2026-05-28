#!/usr/bin/env python3
"""Apply Google Search Console and Bing Webmaster DNS verification records via Cloudflare API.

Requires environment variable:
  CF_API_TOKEN — Zone.DNS Edit + Zone.Read (zone hackerplanet.dev)

Usage:
  python scripts/seo_verification_dns.py --doc
  python scripts/seo_verification_dns.py --google-txt "google-site-verification=ABC123"
  python scripts/seo_verification_dns.py --bing-cname HOST TARGET
  python scripts/seo_verification_dns.py --google-txt "..." --bing-cname abc123 verify.bing.com

Never commit API tokens. Copy verification values from GSC / Bing dashboards only.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request

ZONE_ID = os.environ.get("CF_ZONE_ID", "c81e69edbf957423a22392798309fc35")
ZONE_NAME = "hackerplanet.dev"
CF_ACCOUNT_ID = "a819200afa7f246ea8bdb770f634ab84"
DNS_DASHBOARD = f"https://dash.cloudflare.com/{CF_ACCOUNT_ID}/{ZONE_NAME}/dns/records"


def _api(method: str, path: str, body: dict | None = None) -> dict:
    token = os.environ.get("CF_API_TOKEN", "").strip()
    if not token:
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
    except urllib.error.HTTPError as exc:
        payload = exc.read().decode("utf-8", errors="replace")
        try:
            return json.loads(payload)
        except json.JSONDecodeError:
            return {"success": False, "errors": [{"message": payload}]}


def print_doc() -> None:
    print("Search-engine DNS verification - hackerplanet.dev (Cloudflare)\n")
    print(f"Dashboard: {DNS_DASHBOARD}\n")

    print("Google Search Console (domain property - recommended)")
    print("  1. https://search.google.com/search-console -> Add property -> Domain")
    print("  2. Enter: hackerplanet.dev")
    print("  3. GSC shows a TXT record - copy the FULL value, e.g.:")
    print("       google-site-verification=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
    print("  4. Cloudflare DNS:")
    print("       Type: TXT")
    print("       Name: @   (apex - Cloudflare shows as hackerplanet.dev)")
    print("       Content: paste exact value from GSC (quotes optional in dashboard)")
    print("  5. Apply via API:")
    print('       $env:CF_API_TOKEN = "your_token"')
    print('       python scripts/seo_verification_dns.py --google-txt "google-site-verification=..."')
    print("  6. GSC -> Verify (may take a few minutes for DNS propagation)\n")

    print("Bing Webmaster Tools")
    print("  1. https://www.bing.com/webmasters -> Add a site -> https://hackerplanet.dev")
    print("  2. Choose DNS verification - Bing shows a CNAME pair, e.g.:")
    print("       Host / Name:  abc123def456   (subdomain label only, not FQDN)")
    print("       Target:       verify.bing.com  (exact target Bing provides)")
    print("  3. Cloudflare DNS:")
    print("       Type: CNAME")
    print("       Name: abc123def456   (Cloudflare appends .hackerplanet.dev)")
    print("       Target: verify.bing.com")
    print("       Proxy: DNS only (grey cloud)")
    print("  4. Apply via API:")
    print('       python scripts/seo_verification_dns.py --bing-cname abc123def456 verify.bing.com')
    print("  Alternate: meta tag - set bingSiteVerification in website/seo/site.json,")
    print("             run python scripts/sync_seo.py, deploy, verify in Bing dashboard.\n")

    print("After verification")
    print("  - Submit sitemap: https://hackerplanet.dev/sitemap.xml (GSC + Bing)")
    print("  - Run: python scripts/ping_indexnow.py")
    print("  - Run: .\\scripts\\seo_go_live_checklist.ps1")
    print("\nCreate API token: https://dash.cloudflare.com/profile/api-tokens")
    print("  Template: Edit zone DNS | Zone: hackerplanet.dev")


def _list_records() -> list[dict]:
    result = _api("GET", f"/zones/{ZONE_ID}/dns_records?per_page=100")
    return result.get("result") or []


def apply_google_txt(value: str, records: list[dict]) -> int:
    value = value.strip()
    if not value.startswith("google-site-verification="):
        print(
            'WARNING: expected value like google-site-verification=... - using as-is.',
            file=sys.stderr,
        )

    for record in records:
        if record["type"] != "TXT":
            continue
        if record["name"] not in (ZONE_NAME, f"{ZONE_NAME}."):
            continue
        if record["content"].strip('"') == value or record["content"] == value:
            print(f"Google TXT already present at @: {value[:48]}...")
            return 0

    body = {
        "type": "TXT",
        "name": "@",
        "content": value,
        "ttl": 1,
    }
    result = _api("POST", f"/zones/{ZONE_ID}/dns_records", body)
    ok = bool(result.get("success"))
    print(f"POST TXT @ Google verification: {ok}")
    if not ok:
        print(json.dumps(result, indent=2), file=sys.stderr)
        return 1
    return 0


def apply_bing_cname(host: str, target: str, records: list[dict]) -> int:
    host = host.strip().rstrip(".")
    if host.endswith(f".{ZONE_NAME}"):
        host = host[: -(len(ZONE_NAME) + 1)]
    target = target.strip().rstrip(".")

    fqdn = f"{host}.{ZONE_NAME}"
    for record in records:
        if record["type"] != "CNAME":
            continue
        if record["name"] not in (fqdn, host):
            continue
        if record["content"].rstrip(".").lower() == target.lower():
            print(f"Bing CNAME already present: {host} -> {target}")
            return 0

    body = {
        "type": "CNAME",
        "name": host,
        "content": target,
        "proxied": False,
        "ttl": 1,
    }
    result = _api("POST", f"/zones/{ZONE_ID}/dns_records", body)
    ok = bool(result.get("success"))
    print(f"POST CNAME {host} -> {target}: {ok}")
    if not ok:
        print(json.dumps(result, indent=2), file=sys.stderr)
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Apply GSC/Bing DNS verification records for hackerplanet.dev",
    )
    parser.add_argument(
        "--doc",
        action="store_true",
        help="Print manual steps and exact record shapes (no API call)",
    )
    parser.add_argument(
        "--google-txt",
        metavar="VALUE",
        help='GSC TXT value, e.g. google-site-verification=ABC123',
    )
    parser.add_argument(
        "--bing-cname",
        nargs=2,
        metavar=("HOST", "TARGET"),
        help="Bing CNAME host label and target, e.g. abc123 verify.bing.com",
    )
    args = parser.parse_args()

    if args.doc or (not args.google_txt and not args.bing_cname):
        print_doc()
        if not args.google_txt and not args.bing_cname:
            return 0

    token = os.environ.get("CF_API_TOKEN", "").strip()
    if not token:
        print("Set CF_API_TOKEN (Zone.DNS Edit + Zone.Read).", file=sys.stderr)
        print_doc()
        return 1

    zone = _api("GET", f"/zones/{ZONE_ID}")
    if not zone.get("success"):
        print(json.dumps(zone, indent=2), file=sys.stderr)
        return 1

    records = _list_records()
    rc = 0
    if args.google_txt:
        rc = apply_google_txt(args.google_txt, records) or rc
        records = _list_records()
    if args.bing_cname:
        host, target = args.bing_cname
        rc = apply_bing_cname(host, target, records) or rc

    if rc == 0:
        print("\nDNS records applied. Wait 1-5 minutes, then verify in GSC / Bing dashboards.")
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
