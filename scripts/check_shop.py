#!/usr/bin/env python3
"""Validate shop configs: payments keys, shipping metadata, catalog alignment."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "website" / "js"


def _read(name: str) -> str:
    path = WEB / name
    if not path.is_file():
        raise FileNotFoundError(path)
    return path.read_text(encoding="utf-8")


def _stripe_keys_from_payments_js(text: str) -> set[str]:
    return set(re.findall(r'stripeKey:\s*"(\w+)"', text))


def _stripe_keys_from_config(text: str) -> set[str]:
    block = re.search(r"stripePaymentLinks\s*:\s*\{([^}]+)\}", text, re.S)
    if not block:
        return set()
    return set(re.findall(r"(\w+)\s*:", block.group(1)))


def _shipping_products(text: str) -> dict[str, str]:
    """Return {productId: fulfillment} from shipping.config.js."""
    products: dict[str, str] = {}
    for m in re.finditer(
        r"(\w+):\s*\{\s*fulfillment:\s*\"(\w+)\"",
        text,
    ):
        products[m.group(1)] = m.group(2)
    return products


def _catalog_stripe_keys(text: str) -> set[str]:
    return set(re.findall(r'stripeKey:\s*"(\w+)"', text))


def _direct_stripe_keys(text: str) -> set[str]:
    return set(re.findall(r'stripeKey:\s*"(\w+)"', text))


def main() -> int:
    payments_js = _read("payments.js")
    payments_cfg = _read("payments.config.js")
    shipping_cfg = _read("shipping.config.js")
    catalog_cfg = _read("catalog.config.js")
    direct_cfg = _read("direct.config.js")

    pay_products = _stripe_keys_from_payments_js(payments_js)
    config_keys = _stripe_keys_from_config(payments_cfg)
    shipping_meta = _shipping_products(shipping_cfg)
    catalog_keys = _catalog_stripe_keys(catalog_cfg)
    direct_keys = _direct_stripe_keys(direct_cfg)

    errors: list[str] = []
    warnings: list[str] = []

    missing_config = sorted(pay_products - config_keys)
    extra_config = sorted(config_keys - pay_products)
    if missing_config:
        errors.append(f"payments.config.js missing keys: {', '.join(missing_config)}")
    if extra_config:
        warnings.append(f"payments.config.js extra keys (not in payments.js): {', '.join(extra_config)}")

    missing_shipping = sorted(pay_products - set(shipping_meta))
    if missing_shipping:
        warnings.append(f"shipping.config.js missing product metadata: {', '.join(missing_shipping)}")

    catalog_orphan = sorted(catalog_keys - pay_products)
    if catalog_orphan:
        errors.append(f"catalog.config.js stripeKey not in payments.js: {', '.join(catalog_orphan)}")

    direct_orphan = sorted(direct_keys - pay_products)
    if direct_orphan:
        errors.append(f"direct.config.js stripeKey not in payments.js: {', '.join(direct_orphan)}")

    direct_expected = {k for k, v in shipping_meta.items() if v == "direct"}
    digital_expected = {k for k, v in shipping_meta.items() if v == "digital"}
    dropship_expected = {k for k, v in shipping_meta.items() if v == "dropship"}

    report = {
        "product_count": len(pay_products),
        "stripe_config_keys": len(config_keys),
        "fulfillment": {
            "direct_philly": sorted(direct_expected),
            "digital": sorted(digital_expected),
            "partner_dropship": sorted(dropship_expected),
        },
        "errors": errors,
        "warnings": warnings,
        "aligned": len(errors) == 0,
    }
    print(json.dumps(report, indent=2))

    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
