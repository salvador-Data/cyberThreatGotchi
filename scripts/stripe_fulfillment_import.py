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


def _import_payload(payload: dict, *, stripe_key: str | None, dry_run: bool) -> dict:
    if stripe_key and payload.get("object") == "checkout.session":
        payload.setdefault("metadata", {})["stripe_key"] = stripe_key
        order = order_from_stripe_session(payload)
    else:
        event = _normalize_event(payload)
        if stripe_key:
            obj = event.setdefault("data", {}).setdefault("object", {})
            obj.setdefault("metadata", {})["stripe_key"] = stripe_key
        order = order_from_stripe_event(event)

    if dry_run:
        return {"dry_run": True, "order": order}

    saved = add_order(order)
    webhook = os.environ.get("CTG_FULFILLMENT_WEBHOOK_URL", "").strip()
    notify_fulfillment_event("fulfillment.queued", saved, webhook)
    return {"ok": True, "order": saved}


def _iter_input_files(path: Path) -> list[Path]:
    if path.is_dir():
        return sorted(p for p in path.glob("*.json") if p.is_file())
    return [path]


def main() -> int:
    ap = argparse.ArgumentParser(description="Import Stripe payment into fulfillment queue")
    ap.add_argument("input", nargs="?", type=Path, help="Stripe event or session JSON file (or directory of .json)")
    ap.add_argument("--stdin", action="store_true", help="Read JSON from stdin")
    ap.add_argument("--batch", type=Path, help="Import every .json file in directory")
    ap.add_argument("--dry-run", action="store_true", help="Parse only; do not write queue")
    ap.add_argument(
        "--stripe-key",
        help="Override stripe_key when session metadata is missing (e.g. dsMeshtasticHeltec)",
    )
    args = ap.parse_args()

    if args.batch:
        files = _iter_input_files(args.batch)
        if not files:
            print(f"error: no .json files in {args.batch}", file=sys.stderr)
            return 1
        results = []
        errors = 0
        for fp in files:
            try:
                payload = _load_payload(fp, use_stdin=False)
                results.append({"file": str(fp.name), **_import_payload(payload, stripe_key=args.stripe_key, dry_run=args.dry_run)})
            except (ValueError, json.JSONDecodeError) as exc:
                errors += 1
                results.append({"file": str(fp.name), "error": str(exc)})
        print(json.dumps({"batch": True, "count": len(results), "errors": errors, "results": results}, indent=2))
        return 1 if errors else 0

    try:
        payload = _load_payload(args.input, args.stdin)
        result = _import_payload(payload, stripe_key=args.stripe_key, dry_run=args.dry_run)
    except (ValueError, json.JSONDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
