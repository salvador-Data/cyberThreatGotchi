#!/usr/bin/env python3
"""
Sync recent Stripe checkout sessions into the partner fulfillment queue.

Pulls completed sessions from the Stripe API (metadata stripe_key=ds*), imports any
not already queued by session id.

  $env:CTG_STRIPE_SECRET_KEY = "sk_test_..."
  python scripts/stripe_fulfillment_sync.py --hours 48
  python scripts/stripe_fulfillment_sync.py --dry-run
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.fulfillment_queue import (  # noqa: E402
    add_order,
    list_orders,
    notify_fulfillment_event,
    order_from_stripe_session,
)
from core.stripe_api import (  # noqa: E402
    list_checkout_sessions,
    retrieve_checkout_session,
    secret_key_from_env,
)


def _queued_session_ids(path: Path | None) -> set[str]:
    return {str(o.get("stripe_session_id") or "") for o in list_orders(path=path) if o.get("stripe_session_id")}


def _is_partner_fulfillment_session(session: dict) -> bool:
    meta = session.get("metadata") or {}
    for field in ("stripe_key", "stripeKey", "product_key", "sku"):
        val = str(meta.get(field) or "")
        if val.startswith("ds"):
            return True
    client_ref = str(session.get("client_reference_id") or "")
    return client_ref.startswith("ds")


def sync_recent(
    *,
    hours: int,
    limit: int,
    dry_run: bool,
    queue_path: Path | None,
    webhook_url: str,
) -> dict:
    secret = secret_key_from_env()
    if not secret.startswith("sk_"):
        raise ValueError("Set CTG_STRIPE_SECRET_KEY (sk_test_ or sk_live_)")

    created_gte = int(time.time()) - max(hours, 1) * 3600
    sessions = list_checkout_sessions(secret, limit=limit, created_gte=created_gte)
    known = _queued_session_ids(queue_path)

    imported: list[dict] = []
    skipped: list[str] = []
    non_partner = 0

    for summary in sessions:
        sid = str(summary.get("id") or "")
        if not sid:
            continue
        if sid in known:
            skipped.append(sid)
            continue

        session = retrieve_checkout_session(secret, sid)
        if not _is_partner_fulfillment_session(session):
            non_partner += 1
            continue

        order = order_from_stripe_session(session)
        if dry_run:
            imported.append({"dry_run": True, "order": order})
            continue

        saved = add_order(order, path=queue_path)
        notify_fulfillment_event("fulfillment.queued", saved, webhook_url)
        imported.append(saved)
        known.add(sid)

    return {
        "scanned": len(sessions),
        "imported": len(imported),
        "skipped_duplicate": len(skipped),
        "non_partner_fulfillment": non_partner,
        "orders": imported,
    }


def main() -> int:
    import os

    from config.settings import DATA_DIR

    ap = argparse.ArgumentParser(description="Sync Stripe checkouts into partner fulfillment queue")
    ap.add_argument("--hours", type=int, default=72, help="Look back N hours (default 72)")
    ap.add_argument("--limit", type=int, default=50, help="Max sessions to scan")
    ap.add_argument("--dry-run", action="store_true", help="Parse only; do not write queue")
    ap.add_argument(
        "--queue",
        type=Path,
        default=Path(DATA_DIR) / "fulfillment_queue.json",
        help="Queue JSON path",
    )
    args = ap.parse_args()

    webhook = os.environ.get("CTG_FULFILLMENT_WEBHOOK_URL", "").strip()

    try:
        result = sync_recent(
            hours=args.hours,
            limit=args.limit,
            dry_run=args.dry_run,
            queue_path=args.queue,
            webhook_url=webhook,
        )
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    except RuntimeError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
