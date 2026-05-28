#!/usr/bin/env python3
"""Validate website payment configuration before go-live."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "website" / "js" / "payments.config.js"


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


def _extract_links(text: str) -> dict[str, str]:
    block = re.search(r"stripePaymentLinks\s*:\s*\{([^}]+)\}", text, re.S)
    if not block:
        return {}
    links: dict[str, str] = {}
    for m in re.finditer(r"(\w+)\s*:\s*\"([^\"]*)\"", block.group(1)):
        links[m.group(1)] = m.group(2).strip()
    return links


def main() -> int:
    text = _load_config_text()
    demo = _extract_bool(text, "demoMode")
    links = _extract_links(text)

    errors: list[str] = []
    warnings: list[str] = []

    if demo is not False:
        warnings.append("demoMode is not false — shop shows demo placeholders")

    for name, url in links.items():
        if not url:
            errors.append(f"stripePaymentLinks.{name} is empty")
        elif not url.startswith("https://buy.stripe.com/"):
            warnings.append(f"stripePaymentLinks.{name} is not a Stripe Payment Link URL")

    has_paypal = "clientId:" in text and re.search(r'clientId:\s*"([^"]+)"', text)
    if has_paypal:
        cid = re.search(r'clientId:\s*"([^"]+)"', text)
        if cid and not cid.group(1):
            warnings.append("paypal.clientId is empty")

    report = {
        "config": str(CONFIG),
        "demoMode": demo,
        "stripe_links": links,
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
