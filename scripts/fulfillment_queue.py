#!/usr/bin/env python3
"""
CLI for HPL partner fulfillment queue (local JSON at data/fulfillment_queue.json).

PCI / ToS safe — queues orders for operator dashboard; never automates marketplace checkout.
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
    QUEUE_PATH,
    add_order,
    build_order,
    list_orders,
    load_queue,
    notify_fulfillment_event,
    order_from_stripe_event,
    update_order,
)


def _cmd_list(args: argparse.Namespace) -> int:
    orders = list_orders(status=args.status, pending_only=args.pending)
    if args.json:
        print(json.dumps({"orders": orders, "count": len(orders)}, indent=2))
    else:
        for o in orders:
            print(f"{o.get('id')}\t{o.get('status')}\t{o.get('stripe_key')}\t{o.get('product_name')}")
    return 0


def _cmd_add(args: argparse.Namespace) -> int:
    if args.from_json:
        raw = Path(args.from_json).read_text(encoding="utf-8")
        payload = json.loads(raw)
        if payload.get("type"):
            order = order_from_stripe_event(payload)
        else:
            order = build_order(
                stripe_key=str(payload.get("stripe_key") or args.stripe_key),
                ship_to=payload.get("ship_to") or payload.get("ship_to_text") or args.ship_to,
                customer_email=str(payload.get("customer_email") or args.email or ""),
                stripe_session_id=str(payload.get("stripe_session_id") or ""),
                notes=str(payload.get("notes") or ""),
            )
    else:
        if not args.stripe_key:
            print("error: --stripe-key required (or --from-json)", file=sys.stderr)
            return 2
        order = build_order(
            stripe_key=args.stripe_key,
            ship_to=args.ship_to,
            customer_email=args.email or "",
            stripe_session_id=args.session_id or "",
            notes=args.notes or "",
        )
    saved = add_order(order, path=args.queue)
    webhook = os.environ.get("CTG_FULFILLMENT_WEBHOOK_URL", "").strip()
    notify_fulfillment_event("fulfillment.queued", saved, webhook)
    print(json.dumps({"ok": True, "order": saved}, indent=2))
    return 0


def _cmd_update(args: argparse.Namespace) -> int:
    updates: dict = {}
    if args.status:
        updates["status"] = args.status
    if args.tracking_url:
        updates["tracking_url"] = args.tracking_url
        updates["tracking_number"] = args.tracking_url.rstrip("/").split("/")[-1]
    if args.supplier_order_id:
        updates["supplier_order_id"] = args.supplier_order_id
    if args.notes is not None:
        updates["notes"] = args.notes
    updated = update_order(args.order_id, updates, path=args.queue)
    if updated is None:
        print("error: order not found", file=sys.stderr)
        return 1
    webhook = os.environ.get("CTG_FULFILLMENT_WEBHOOK_URL", "").strip()
    if args.status:
        notify_fulfillment_event(f"fulfillment.{args.status}", updated, webhook)
    print(json.dumps({"ok": True, "order": updated}, indent=2))
    return 0


def _cmd_show(args: argparse.Namespace) -> int:
    data = load_queue(args.queue)
    print(json.dumps(data, indent=2))
    return 0


def _cmd_import(args: argparse.Namespace) -> int:
    import subprocess

    cmd = [sys.executable, str(ROOT / "scripts" / "stripe_fulfillment_import.py")]
    if args.path.is_dir():
        cmd.extend(["--batch", str(args.path)])
    else:
        cmd.append(str(args.path))
    if args.dry_run:
        cmd.append("--dry-run")
    if args.stripe_key:
        cmd.extend(["--stripe-key", args.stripe_key])
    r = subprocess.run(cmd, cwd=str(ROOT))
    return r.returncode


def main() -> int:
    ap = argparse.ArgumentParser(description="HPL partner fulfillment queue CLI")
    ap.add_argument("--queue", type=Path, default=QUEUE_PATH, help="Queue JSON path")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_list = sub.add_parser("list", help="List queued orders")
    p_list.add_argument("--pending", action="store_true", help="pending + ordered only")
    p_list.add_argument("--status", help="Filter by status")
    p_list.add_argument("--json", action="store_true")
    p_list.set_defaults(func=_cmd_list)

    p_add = sub.add_parser("add", help="Enqueue a partner fulfillment order")
    p_add.add_argument("--stripe-key", help="partner SKU stripeKey (e.g. dsMeshtasticHeltec)")
    p_add.add_argument("--ship-to", default="", help='Ship-to one-liner or JSON object string')
    p_add.add_argument("--email", default="")
    p_add.add_argument("--session-id", default="", help="Stripe checkout session id")
    p_add.add_argument("--notes", default="")
    p_add.add_argument("--from-json", type=Path, help="Stripe event or order JSON file")
    p_add.set_defaults(func=_cmd_add)

    p_up = sub.add_parser("update", help="Update order status / tracking")
    p_up.add_argument("order_id")
    p_up.add_argument("--status", choices=["pending", "ordered", "shipped", "delivered", "exception"])
    p_up.add_argument("--tracking-url", default="")
    p_up.add_argument("--supplier-order-id", default="")
    p_up.add_argument("--notes", default=None)
    p_up.set_defaults(func=_cmd_update)

    p_show = sub.add_parser("show", help="Dump full queue file")
    p_show.set_defaults(func=_cmd_show)

    p_import = sub.add_parser("import", help="Import Stripe JSON file or directory")
    p_import.add_argument("path", type=Path, help="Stripe event/session JSON or directory")
    p_import.add_argument("--dry-run", action="store_true")
    p_import.add_argument("--stripe-key", help="Override stripe_key when metadata missing")
    p_import.set_defaults(func=_cmd_import)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
