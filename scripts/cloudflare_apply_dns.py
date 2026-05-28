#!/usr/bin/env python3
"""Apply GitHub Pages and/or Email Routing DNS records to Cloudflare via API.

Requires environment variable:
  CF_API_TOKEN — Zone.DNS Edit + Zone.Read (zone hackerplanet.dev)

Optional:
  CF_ZONE_ID — defaults to Hacker Planet zone id below

Usage:
  set CF_API_TOKEN=your_token
  python scripts/cloudflare_apply_dns.py              # GitHub Pages only
  python scripts/cloudflare_apply_dns.py --email      # Email Routing only
  python scripts/cloudflare_apply_dns.py --all        # both
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

GITHUB_A = [
    "185.199.108.153",
    "185.199.109.153",
    "185.199.110.153",
    "185.199.111.153",
]
WWW_CNAME = "salvador-Data.github.io"

EMAIL_MX = [
    (82, "route1.mx.cloudflare.net"),
    (83, "route2.mx.cloudflare.net"),
    (84, "route3.mx.cloudflare.net"),
]
EMAIL_SPF = "v=spf1 include:_spf.mx.cloudflare.net ~all"
EMAIL_DMARC = "v=DMARC1; p=none; rua=mailto:salvadorData@proton.me"
EMAIL_DKIM_SELECTOR = "cf2024-1._domainkey"


def _name_apex(name: str) -> bool:
    n = name.rstrip(".").lower()
    return n in ("@", ZONE_NAME.lower())


def _name_www(name: str) -> bool:
    n = name.rstrip(".").lower()
    return n in ("www", f"www.{ZONE_NAME}".lower())


def _lookup_name(name: str) -> str:
    """Cloudflare returns apex as FQDN; API accepts @ on write."""
    return ZONE_NAME if _name_apex(name) else name


def _record_key(rtype: str, name: str, content: str) -> tuple[str, str, str]:
    return (rtype, _lookup_name(name), content)


def _records_by_key(records: list[dict]) -> dict[tuple[str, str, str], dict]:
    return {_record_key(r["type"], r["name"], r["content"]): r for r in records}


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
    except urllib.error.HTTPError as e:
        payload = e.read().decode("utf-8", errors="replace")
        try:
            return json.loads(payload)
        except json.JSONDecodeError:
            return {"success": False, "errors": [{"message": payload}]}


def _print_manual_steps(pages: bool, email: bool) -> None:
    print("CF_API_TOKEN not set — apply via Cloudflare dashboard:\n")
    print(f"  Account ID: {CF_ACCOUNT_ID}")
    print(f"  Zone ID:    {ZONE_ID}")
    print(f"  DNS:        https://dash.cloudflare.com/{CF_ACCOUNT_ID}/{ZONE_NAME}/dns/records\n")

    if pages:
        dns_url = f"https://dash.cloudflare.com/{CF_ACCOUNT_ID}/{ZONE_NAME}/dns/records"
        print("GitHub Pages (~60s in dashboard):")
        print(f"  1. Open {dns_url}")
        print("  2. Delete orange-cloud @ A/AAAA/CNAME that are NOT GitHub (104.x / 172.x = proxied wrong).")
        print("  3. Add four A @ records (grey cloud / DNS only):")
        for ip in GITHUB_A:
            print(f"       {ip}")
        print(f"  4. Add CNAME www -> {WWW_CNAME} (grey cloud).")
        print("  5. On each GitHub row: click record -> Proxy status -> DNS only (grey cloud).")
        print("  Or import scripts/cloudflare/dns-github-pages.bind then grey-cloud every A/CNAME.\n")

    if email:
        print("Email Routing:")
        print(f"  Import: scripts/cloudflare/dns-email-routing.bind")
        print(f"  Or enable: https://dash.cloudflare.com/{CF_ACCOUNT_ID}/{ZONE_NAME}/email/routing")
        print("  Records:")
        for pri, host in EMAIL_MX:
            print(f"    MX   @      {host}  priority {pri}")
        print(f'    TXT  @      "{EMAIL_SPF}"')
        print(f'    TXT  _dmarc "{EMAIL_DMARC}"')
        print(f"    TXT  {EMAIL_DKIM_SELECTOR}  (from Email Routing dashboard — click Get started)")
        print("  Routing rule: hello@hackerplanet.dev -> salvadorData@proton.me\n")

    print("Create API token: https://dash.cloudflare.com/profile/api-tokens")
    print("  Template: Edit zone DNS | Zone: hackerplanet.dev")
    print("  Permissions: Zone -> DNS -> Edit, Zone -> Zone -> Read")
    print('  Then: $env:CF_API_TOKEN = "your_token"; python scripts/cloudflare_apply_dns.py --all')


def _upsert_record(
    records: list[dict],
    *,
    rtype: str,
    name: str,
    content: str,
    extra: dict | None = None,
) -> tuple[bool, dict]:
    by_key = _records_by_key(records)
    key = _record_key(rtype, name, content)
    body: dict = {
        "type": rtype,
        "name": "@" if _name_apex(name) or name == "@" else name,
        "content": content,
        "ttl": 1,
    }
    if rtype in ("A", "AAAA", "CNAME"):
        body["proxied"] = False
    if extra:
        body.update(extra)

    if key in by_key:
        rid = by_key[key]["id"]
        r = _api("PATCH", f"/zones/{ZONE_ID}/dns_records/{rid}", body)
        action = f"PATCH {rtype} {name}"
    else:
        r = _api("POST", f"/zones/{ZONE_ID}/dns_records", body)
        action = f"POST {rtype} {name}"

    print(f"{action} -> {content[:60]}{'...' if len(content) > 60 else ''}: {r.get('success')}")
    return bool(r.get("success")), r


def _find_txt(records: list[dict], name: str, prefix: str) -> list[dict]:
    return [
        r
        for r in records
        if r["type"] == "TXT" and r["name"] == name and r["content"].startswith(prefix)
    ]


def apply_github_pages(records: list[dict]) -> int:
    by_key = _records_by_key(records)

    for ip in GITHUB_A:
        key = _record_key("A", "@", ip)
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

    for r in records:
        if r["type"] == "A" and _name_apex(r["name"]) and r.get("proxied"):
            if r["content"] not in GITHUB_A:
                continue
            patch = _api(
                "PATCH",
                f"/zones/{ZONE_ID}/dns_records/{r['id']}",
                {"proxied": False},
            )
            print(f"Grey-cloud A {r['content']}: {patch.get('success')}")

    for r in records:
        if r["type"] == "AAAA" and _name_apex(r["name"]) and r.get("proxied"):
            patch = _api(
                "PATCH",
                f"/zones/{ZONE_ID}/dns_records/{r['id']}",
                {"proxied": False},
            )
            print(f"Grey-cloud AAAA apex {r['content']}: {patch.get('success')}")

    www_key = _record_key("CNAME", "www", WWW_CNAME)
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

    github_cname = WWW_CNAME.rstrip(".").lower()
    for r in records:
        if r["type"] != "CNAME":
            continue
        if not _name_www(r["name"]):
            continue
        if r.get("content", "").rstrip(".").lower() != github_cname:
            continue
        if not r.get("proxied"):
            continue
        patch = _api(
            "PATCH",
            f"/zones/{ZONE_ID}/dns_records/{r['id']}",
            {"proxied": False},
        )
        print(f"Grey-cloud CNAME www -> {WWW_CNAME}: {patch.get('success')}")

    print("GitHub Pages DNS applied (DNS only / grey cloud).")
    return 0


def apply_email_routing(records: list[dict]) -> int:
    for pri, host in EMAIL_MX:
        ok, r = _upsert_record(
            records,
            rtype="MX",
            name="@",
            content=host,
            extra={"priority": pri},
        )
        if not ok:
            print(json.dumps(r, indent=2), file=sys.stderr)
            return 1

    spf_records = _find_txt(records, ZONE_NAME, "v=spf1")
    if spf_records:
        existing = spf_records[0]["content"]
        if "_spf.mx.cloudflare.net" in existing:
            print(f"SPF already includes Cloudflare Email Routing: {existing}")
        else:
            print(
                "WARNING: existing SPF record does not include _spf.mx.cloudflare.net.",
                file=sys.stderr,
            )
            print(f"  Current: {existing}", file=sys.stderr)
            print(
                f'  Merge manually: v=spf1 include:_spf.mx.cloudflare.net ... ~all',
                file=sys.stderr,
            )
            return 1
    else:
        ok, r = _upsert_record(
            records,
            rtype="TXT",
            name="@",
            content=EMAIL_SPF,
        )
        if not ok:
            print(json.dumps(r, indent=2), file=sys.stderr)
            return 1

    dmarc_name = f"_dmarc.{ZONE_NAME}"
    dmarc_records = _find_txt(records, dmarc_name, "v=DMARC1")
    if dmarc_records:
        print(f"DMARC already present: {dmarc_records[0]['content']}")
    else:
        ok, r = _upsert_record(
            records,
            rtype="TXT",
            name="_dmarc",
            content=EMAIL_DMARC,
        )
        if not ok:
            print(json.dumps(r, indent=2), file=sys.stderr)
            return 1

    dkim_name = f"{EMAIL_DKIM_SELECTOR}.{ZONE_NAME}"
    dkim_records = [r for r in records if r["type"] == "TXT" and r["name"] == dkim_name]
    if dkim_records:
        print(f"DKIM record present at {EMAIL_DKIM_SELECTOR} (verify in Email Routing dashboard).")
    else:
        print(
            "DKIM not in DNS yet — enable Email Routing in dashboard (Get started) "
            f"to create {EMAIL_DKIM_SELECTOR} TXT automatically."
        )
        print(
            f"  https://dash.cloudflare.com/{CF_ACCOUNT_ID}/{ZONE_NAME}/email/routing"
        )

    print("Email Routing DNS applied (MX + SPF + DMARC). Add routing rule: hello@ -> salvadorData@proton.me")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Apply Cloudflare DNS for hackerplanet.dev")
    parser.add_argument(
        "--email",
        action="store_true",
        help="Apply Email Routing records (MX, SPF, DMARC)",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Apply GitHub Pages and Email Routing records",
    )
    args = parser.parse_args()

    do_pages = args.all or not args.email
    do_email = args.all or args.email

    token = os.environ.get("CF_API_TOKEN", "").strip()
    if not token:
        print("Set CF_API_TOKEN (Zone.DNS Edit + Zone.Read).", file=sys.stderr)
        _print_manual_steps(do_pages, do_email)
        return 1

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
        _print_manual_steps(do_pages, do_email)
        return 1

    existing = _api("GET", f"/zones/{ZONE_ID}/dns_records?per_page=100")
    records = existing.get("result") or []

    rc = 0
    if do_pages:
        rc = apply_github_pages(records)
        if rc != 0:
            return rc
        existing = _api("GET", f"/zones/{ZONE_ID}/dns_records?per_page=100")
        records = existing.get("result") or []

    if do_email:
        rc = apply_email_routing(records)
        if rc != 0:
            return rc

    if do_pages and not do_email:
        print("Next: GitHub Pages Enforce HTTPS (scripts/github_pages_https.py)")
    elif do_email and not do_pages:
        print("Next: Email Routing rule + test hello@hackerplanet.dev")
    else:
        print("Next: github_pages_https.py + Email Routing hello@ rule + test email")

    return rc


if __name__ == "__main__":
    raise SystemExit(main())
