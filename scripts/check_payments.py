#!/usr/bin/env python3
"""Validate website payment configuration before go-live."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "website" / "js" / "payments.config.js"
PAYMENTS_JS = ROOT / "website" / "js" / "payments.js"

SUBSCRIPTION_KEYS = frozenset(
    {"proMonthly", "proYearly", "mspMonitor", "mspDefend", "mspHarden"}
)


def _load_config_text() -> str:
    if not CONFIG.is_file():
        print(f"Missing {CONFIG}", file=sys.stderr)
        sys.exit(1)
    return CONFIG.read_text(encoding="utf-8")


def _extract_bool(text: str, key: str) -> bool | None:
    m = re.search(rf"{key}\s*:\s*(true|false)", text, re.I)
    if not m:
        return None
    return m.group(1).lower() == "true"


def _extract_string(text: str, key: str) -> str:
    m = re.search(rf'{key}\s*:\s*"([^"]*)"', text)
    return m.group(1).strip() if m else ""


def _extract_links(text: str) -> dict[str, str]:
    block = re.search(r"stripePaymentLinks\s*:\s*\{([^}]+)\}", text, re.S)
    if not block:
        return {}
    links: dict[str, str] = {}
    for m in re.finditer(r"(\w+)\s*:\s*\"([^\"]*)\"", block.group(1)):
        links[m.group(1)] = m.group(2).strip()
    return links


def _product_keys_from_js() -> set[str]:
    if not PAYMENTS_JS.is_file():
        return set()
    text = PAYMENTS_JS.read_text(encoding="utf-8")
    return set(re.findall(r'stripeKey:\s*"(\w+)"', text))


def _paypal_plan_ids(text: str) -> dict[str, str]:
    block = re.search(r"paypalSubscriptions\s*:\s*\{([^}]+(?:\{[^}]+\}[^}]*)*)\}", text, re.S)
    if not block:
        return {}
    plans: dict[str, str] = {}
    for m in re.finditer(r"(\w+)\s*:\s*\{\s*planId:\s*\"([^\"]*)\"", block.group(1)):
        plans[m.group(1)] = m.group(2).strip()
    return plans


def main() -> int:
    text = _load_config_text()
    demo = _extract_bool(text, "demoMode")
    links = _extract_links(text)
    portal = _extract_string(text, "stripeCustomerPortal")
    paypal_plans = _paypal_plan_ids(text)
    product_keys = _product_keys_from_js()

    errors: list[str] = []
    warnings: list[str] = []

    if demo is not False:
        warnings.append("demoMode is not false — shop shows demo placeholders")

    missing_keys = sorted(product_keys - set(links))
    extra_keys = sorted(set(links) - product_keys)
    if missing_keys:
        errors.append(f"payments.config.js missing stripePaymentLinks keys: {', '.join(missing_keys)}")
    if extra_keys:
        warnings.append(f"payments.config.js extra stripePaymentLinks keys: {', '.join(extra_keys)}")

    for name, url in links.items():
        if not url:
            errors.append(f"stripePaymentLinks.{name} is empty")
        elif not url.startswith("https://buy.stripe.com/"):
            warnings.append(f"stripePaymentLinks.{name} is not a Stripe Payment Link URL")

    if not portal:
        warnings.append("stripeCustomerPortal is empty — returning customers cannot self-manage billing")
    elif not portal.startswith("https://billing.stripe.com/"):
        warnings.append("stripeCustomerPortal should be a billing.stripe.com portal URL")

    has_paypal = "clientId:" in text and re.search(r'clientId:\s*"([^"]+)"', text)
    if has_paypal:
        cid = re.search(r'clientId:\s*"([^"]+)"', text)
        if cid and not cid.group(1):
            warnings.append("paypal.clientId is empty")

    for key in SUBSCRIPTION_KEYS:
        if key in links and not links[key]:
            errors.append(f"subscription stripePaymentLinks.{key} is empty")
        plan = paypal_plans.get(key, "")
        if plan and not plan.startswith("P-"):
            warnings.append(f"paypalSubscriptions.{key}.planId may be invalid (expected P- prefix)")

    report = {
        "config": str(CONFIG),
        "demoMode": demo,
        "stripeCustomerPortal": bool(portal),
        "stripe_links": links,
        "subscription_keys": sorted(SUBSCRIPTION_KEYS & set(links)),
        "paypal_subscription_plans": paypal_plans,
        "errors": errors,
        "warnings": warnings,
        "ready": len(errors) == 0 and demo is False,
    }
    print(json.dumps(report, indent=2))

    if errors:
        return 1
    if demo is not False:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
