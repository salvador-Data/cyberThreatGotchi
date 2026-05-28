#!/usr/bin/env python3
"""
Import Stripe checkout events into the HPL fulfillment queue.

Reads:
  - Stripe CLI JSON export (``stripe events retrieve evt_... --stripe-key ...``)
  - Manual JSON paste file (checkout.session.completed event or session object)
  - stdin when ``--stdin`` is passed

Set ``metadata.stripe_key`` on Stripe Payment Links for automatic SKU mapping.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.fulfillment_queue import (  # noqa: E402
    add_order,
    notify_fulfillment_event,
    order_from_stripe_event,
    order_from_stripe_session,
)


def _load_payload(path: Path | None, use_stdin: bool) -> dict:
    if use_stdin:
        raw = sys.stdin.read()
    elif path:
        raw = path.read_text(encoding="utf-8")
    else:
        raise ValueError("input file or --stdin required")
    data = json.loads(raw)
    if not isinstance(data, dict):
        raise ValueError("expected JSON object")
    return data


def _normalize_event(data: dict) -> dict:
    if data.get("type") and data.get("data"):
        return data
    if data.get("object") == "checkout.session":
        return {"type": "checkout.session.completed", "data": {"object": data}}
    if data.get("object") == "event" and data.get("type"):
        return data
    raise ValueError("unrecognized Stripe JSON — need event or checkout.session object")


def main() -> int:
    ap = argparse.ArgumentParser(description="Import Stripe payment into fulfillment queue")
    ap.add_argument("input", nargs="?", type=Path, help="Stripe event or session JSON file")
    ap.add_argument("--stdin", action="store_true", help="Read JSON from stdin")
    ap.add_argument("--dry-run", action="store_true", help="Parse only; do not write queue")
    ap.add_argument(
        "--stripe-key",
        help="Override stripe_key when session metadata is missing (e.g. dsMeshtasticHeltec)",
    )
    args = ap.parse_args()

    try:
        payload = _load_payload(args.input, args.stdin)
        if args.stripe_key and payload.get("object") == "checkout.session":
            payload.setdefault("metadata", {})["stripe_key"] = args.stripe_key
            order = order_from_stripe_session(payload)
        else:
            event = _normalize_event(payload)
            if args.stripe_key:
                obj = event.setdefault("data", {}).setdefault("object", {})
                obj.setdefault("metadata", {})["stripe_key"] = args.stripe_key
            order = order_from_stripe_event(event)
    except (ValueError, json.JSONDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if args.dry_run:
        print(json.dumps({"dry_run": True, "order": order}, indent=2))
        return 0

    saved = add_order(order)
    webhook = os.environ.get("CTG_FULFILLMENT_WEBHOOK_URL", "").strip()
    notify_fulfillment_event("fulfillment.queued", saved, webhook)
    print(json.dumps({"ok": True, "order": saved}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
