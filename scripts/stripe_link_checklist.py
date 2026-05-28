#!/usr/bin/env python3
"""Print empty stripePaymentLinks keys with expected USD amounts from payments.js."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "website" / "js" / "payments.config.js"
PAYMENTS_JS = ROOT / "website" / "js" / "payments.js"


def _parse_products(js_text: str) -> dict[str, dict[str, str | float]]:
    start = js_text.find("var PRODUCTS = {")
    if start < 0:
        return {}
    body = js_text[start + len("var PRODUCTS = {") :]
    end = body.rfind("};")
    if end < 0:
        return {}
    body = body[:end]

    products: dict[str, dict[str, str | float]] = {}
    for mobj in re.finditer(
        r"(\w+):\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}",
        body,
        re.S,
    ):
        block = mobj.group(2)
        sk = re.search(r'stripeKey:\s*"(\w+)"', block)
        if not sk:
            continue
        key = sk.group(1)
        name_m = re.search(r'name:\s*"([^"]+)"', block)
        price_m = re.search(r"price:\s*([\d.]+)", block)
        period_m = re.search(r'period:\s*"([^"]+)"', block)
        products[key] = {
            "id": mobj.group(1),
            "name": name_m.group(1) if name_m else key,
            "price": float(price_m.group(1)) if price_m else 0.0,
            "period": period_m.group(1) if period_m else "one-time",
        }
    return products


def _extract_links(text: str) -> dict[str, str]:
    block = re.search(r"stripePaymentLinks\s*:\s*\{([^}]+)\}", text, re.S)
    if not block:
        return {}
    links: dict[str, str] = {}
    for m in re.finditer(r"(\w+)\s*:\s*\"([^\"]*)\"", block.group(1)):
        links[m.group(1)] = m.group(2).strip()
    return links


def _format_amount(price: float, period: str) -> str:
    if period == "/month":
        return f"${price:,.2f}/mo"
    if period == "/year":
        return f"${price:,.2f}/yr"
    if price == int(price):
        return f"${int(price)}"
    return f"${price:.2f}"


def main() -> int:
    if not PAYMENTS_JS.is_file():
        print(f"Missing {PAYMENTS_JS}", file=sys.stderr)
        return 1
    if not CONFIG.is_file():
        print(f"Missing {CONFIG}", file=sys.stderr)
        return 1

    products = _parse_products(PAYMENTS_JS.read_text(encoding="utf-8"))
    links = _extract_links(CONFIG.read_text(encoding="utf-8"))

    empty = [(k, products[k]) for k in sorted(products) if not links.get(k)]
    filled = [(k, products[k]) for k in sorted(products) if links.get(k)]

    print(f"Stripe Payment Link checklist ({len(products)} SKUs)")
    print(f"  Filled: {len(filled)}")
    print(f"  Empty:  {len(empty)}")
    print()

    if empty:
        print("EMPTY — create in Stripe Dashboard, then paste URL into payments.config.js:")
        print(f"{'Key':<22} {'Amount':<14} Product name")
        print("-" * 72)
        for key, info in empty:
            amount = _format_amount(float(info["price"]), str(info["period"]))
            print(f"{key:<22} {amount:<14} {info['name']}")
        print()
        print("Runbook: docs/STRIPE_ADD_LINKS.md")
    else:
        print("All stripePaymentLinks keys have URLs.")

    missing_in_config = sorted(set(products) - set(links))
    if missing_in_config:
        print("\nMissing keys in payments.config.js:", ", ".join(missing_in_config))
        return 1

    extra = sorted(set(links) - set(products))
    if extra:
        print("\nExtra keys in config (not in payments.js):", ", ".join(extra))

    return 0 if not empty else 2


if __name__ == "__main__":
    raise SystemExit(main())
