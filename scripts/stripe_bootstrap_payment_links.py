#!/usr/bin/env python3
"""
Create Stripe Products + Payment Links for every shop SKU and update payments.config.js.

Requires CTG_STRIPE_SECRET_KEY (sk_test_ or sk_live_). Idempotent: re-run skips keys
that already have buy.stripe.com URLs unless --force.

  $env:CTG_STRIPE_SECRET_KEY = "sk_test_..."
  python scripts/stripe_bootstrap_payment_links.py --dry-run
  python scripts/stripe_bootstrap_payment_links.py --write-config
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.stripe_api import (  # noqa: E402
    is_recurring,
    needs_shipping,
    price_cents,
    recurring_interval,
    secret_key_from_env,
    stripe_request,
)

CONFIG = ROOT / "website" / "js" / "payments.config.js"
PAYMENTS_JS = ROOT / "website" / "js" / "payments.js"


def _parse_products() -> dict[str, dict]:
    from scripts.stripe_link_checklist import _parse_products as parse  # noqa: WPS433

    return parse(PAYMENTS_JS.read_text(encoding="utf-8"))


def _extract_links(text: str) -> dict[str, str]:
    from scripts.stripe_link_checklist import _extract_links as extract  # noqa: WPS433

    return extract(text)


def _create_product_and_price(secret: str, key: str, info: dict) -> str:
    """Return Stripe price id."""
    name = str(info["name"])
    price = float(info["price"])
    period = str(info.get("period") or "one-time")

    product = stripe_request(
        "POST",
        "/products",
        secret=secret,
        form={
            "name": name,
            "metadata": {"stripe_key": key, "hpl_sku": key},
            "description": f"Hacker Planet LLC — {name} ({key})",
        },
    )
    product_id = product["id"]

    price_form: dict = {
        "product": product_id,
        "unit_amount": price_cents(price),
        "currency": "usd",
        "metadata": {"stripe_key": key},
    }
    if is_recurring(key, period):
        price_form["recurring"] = {"interval": recurring_interval(key, period)}

    price_obj = stripe_request("POST", "/prices", secret=secret, form=price_form)
    return str(price_obj["id"])


def _create_payment_link(secret: str, key: str, price_id: str) -> str:
    form: dict = {
        "line_items": [{"price": price_id, "quantity": 1}],
        "metadata": {"stripe_key": key},
        "allow_promotion_codes": "true",
    }
    if needs_shipping(key):
        form["shipping_address_collection"] = {"allowed_countries[]": "US"}
        form["automatic_tax"] = {"enabled": "true"}
    link = stripe_request("POST", "/payment_links", secret=secret, form=form)
    url = str(link.get("url") or "")
    if not url.startswith("https://buy.stripe.com/"):
        raise RuntimeError(f"unexpected payment link URL for {key}: {url}")
    return url


def _update_config(links: dict[str, str], *, demo_mode: bool | None) -> None:
    text = CONFIG.read_text(encoding="utf-8")
    for key, url in links.items():
        pattern = rf'({re.escape(key)}\s*:\s*")([^"]*)(")'
        if not re.search(pattern, text):
            print(f"warning: key {key} not found in config", file=sys.stderr)
            continue
        text = re.sub(pattern, rf"\1{url}\3", text, count=1)

    if demo_mode is False:
        text = re.sub(r"demoMode\s*:\s*true", "demoMode: false", text, count=1)
    elif demo_mode is True:
        text = re.sub(r"demoMode\s*:\s*false", "demoMode: true", text, count=1)

    CONFIG.write_text(text, encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description="Bootstrap Stripe Payment Links for HPL shop")
    ap.add_argument("--dry-run", action="store_true", help="Print actions only")
    ap.add_argument("--write-config", action="store_true", help="Write URLs into payments.config.js")
    ap.add_argument("--force", action="store_true", help="Recreate links even if URL already set")
    ap.add_argument("--keys", nargs="*", help="Only bootstrap these stripe keys")
    ap.add_argument(
        "--go-live",
        action="store_true",
        help="After all links filled, set demoMode: false (requires --write-config)",
    )
    args = ap.parse_args()

    secret = secret_key_from_env()
    if not secret.startswith("sk_"):
        print("Set CTG_STRIPE_SECRET_KEY (sk_test_ or sk_live_)", file=sys.stderr)
        print("Runbook: docs/STRIPE_ADD_LINKS.md", file=sys.stderr)
        return 1

    products = _parse_products()
    if not products:
        print("No products parsed from payments.js", file=sys.stderr)
        return 1

    existing = _extract_links(CONFIG.read_text(encoding="utf-8"))
    selected = args.keys or sorted(products)
    created: dict[str, str] = {}
    skipped = 0

    for key in selected:
        if key not in products:
            print(f"skip unknown key: {key}", file=sys.stderr)
            continue
        if existing.get(key) and not args.force:
            created[key] = existing[key]
            skipped += 1
            continue

        info = products[key]
        if args.dry_run:
            ship = "shipping+tax" if needs_shipping(key) else "digital/sub"
            print(f"would create: {key:<22} ${info['price']:<8} {ship}")
            continue

        print(f"creating: {key} ({info['name']})...")
        price_id = _create_product_and_price(secret, key, info)
        url = _create_payment_link(secret, key, price_id)
        created[key] = url
        print(f"  -> {url}")

    if args.dry_run:
        pending = sum(1 for k in selected if k in products and not existing.get(k))
        print(f"\n{pending} link(s) would be created ({skipped} already filled)")
        return 0

    if args.write_config:
        all_links = dict(existing)
        all_links.update(created)
        go_live = args.go_live and all(all_links.get(k) for k in products)
        _update_config(all_links, demo_mode=False if go_live else None)
        print(f"Updated {CONFIG}")
        if go_live:
            print("demoMode set to false — shop is live for checkout")
        elif args.go_live:
            print("demoMode unchanged — some keys still empty", file=sys.stderr)

    report = {
        "created": len([k for k in created if k not in existing or args.force]),
        "skipped_existing": skipped,
        "total_keys": len(products),
        "links": created,
    }
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
