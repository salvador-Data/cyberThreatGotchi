#!/usr/bin/env python3
"""
Create a Stripe Billing Portal session (server-side only).

Requires CTG_STRIPE_SECRET_KEY — never commit or expose on the static website.

  python scripts/stripe_portal_session.py --customer cus_xxxxxxxx
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


def main() -> int:
    p = argparse.ArgumentParser(description="Create Stripe Customer Portal session URL")
    p.add_argument("--customer", required=True, help="Stripe customer id (cus_...)")
    p.add_argument("--return-url", default="https://hackerplanet.dev/shop.html")
    args = p.parse_args()

    secret = os.environ.get("CTG_STRIPE_SECRET_KEY", "").strip()
    if not secret.startswith("sk_"):
        print("Set CTG_STRIPE_SECRET_KEY (sk_live_ or sk_test_)", file=sys.stderr)
        return 1

    body = urllib.parse.urlencode(
        {
            "customer": args.customer,
            "return_url": args.return_url,
        }
    ).encode()
    req = urllib.request.Request(
        "https://api.stripe.com/v1/billing_portal/sessions",
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {secret}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        err = exc.read().decode() if exc.fp else str(exc)
        print(err, file=sys.stderr)
        return 1

    url = data.get("url", "")
    if not url:
        print(json.dumps(data, indent=2), file=sys.stderr)
        return 1
    print(url)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
