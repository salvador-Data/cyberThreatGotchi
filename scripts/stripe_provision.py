#!/usr/bin/env python3
"""
Stripe webhook → provision CTG Pro API keys.

Run alongside CTG web server or standalone:

  set CTG_STRIPE_WEBHOOK_SECRET=whsec_...
  python scripts/stripe_provision.py --port 9091

Point Stripe webhook to: https://your-host:9091/stripe/webhook
Events: checkout.session.completed, customer.subscription.deleted,
        customer.subscription.updated, invoice.payment_failed
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Optional

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from config.settings import DATA_DIR
from core.security import verify_stripe_webhook
from db.pro_keys import ProKeyStore

PRO_SUBSCRIPTION_KEYS = frozenset({"proMonthly", "proYearly"})


def _session_stripe_key(session: dict[str, Any]) -> str:
    meta = session.get("metadata") or {}
    if isinstance(meta, dict):
        key = str(meta.get("stripe_key") or "").strip()
        if key:
            return key
    return ""


def _is_pro_subscription_session(session: dict[str, Any]) -> bool:
    mode = str(session.get("mode") or "")
    if mode == "subscription":
        return True
    key = _session_stripe_key(session)
    return key in PRO_SUBSCRIPTION_KEYS


def handle_stripe_event(event: dict[str, Any], store: ProKeyStore | None) -> dict[str, Any]:
    """Process Stripe webhook event — testable without HTTP layer."""
    etype = str(event.get("type") or "")
    result: dict[str, Any] = {"ok": True, "type": etype}

    if etype == "checkout.session.completed" and store:
        session = event.get("data", {}).get("object", {})
        if not _is_pro_subscription_session(session):
            result["skipped"] = "not_pro_subscription"
            return result
        customer_id = str(session.get("customer") or session.get("id", ""))
        email = str(session.get("customer_details", {}).get("email", ""))
        existing = store.find_by_customer(customer_id)
        api_key = existing or store.provision(customer_id, email=email)
        result["api_key"] = api_key
        result["customer_id"] = customer_id
        print(f"[stripe] provisioned key for {customer_id} ({email})")

    elif etype == "customer.subscription.deleted" and store:
        sub = event.get("data", {}).get("object", {})
        customer_id = str(sub.get("customer", ""))
        existing = store.find_by_customer(customer_id)
        if existing:
            store.revoke(existing)
            result["revoked"] = existing
            print(f"[stripe] revoked key for customer {customer_id}")

    elif etype == "customer.subscription.updated" and store:
        sub = event.get("data", {}).get("object", {})
        status = str(sub.get("status") or "")
        customer_id = str(sub.get("customer", ""))
        result["subscription_status"] = status
        if status in ("canceled", "unpaid", "incomplete_expired"):
            existing = store.find_by_customer(customer_id)
            if existing:
                store.revoke(existing)
                result["revoked"] = existing
                print(f"[stripe] revoked key (status={status}) for {customer_id}")

    elif etype == "invoice.payment_failed":
        invoice = event.get("data", {}).get("object", {})
        result["customer_id"] = str(invoice.get("customer") or "")
        result["invoice_id"] = str(invoice.get("id") or "")
        print(f"[stripe] invoice payment failed for customer {result['customer_id']}")

    return result


class StripeWebhookHandler(BaseHTTPRequestHandler):
    webhook_secret: str = ""
    store: ProKeyStore | None = None

    def log_message(self, fmt: str, *args: object) -> None:
        pass

    def do_POST(self) -> None:
        if self.path.rstrip("/") != "/stripe/webhook":
            self.send_response(404)
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else b""
        sig = self.headers.get("Stripe-Signature", "")

        if not verify_stripe_webhook(body, sig, self.webhook_secret):
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b'{"error":"invalid signature"}')
            return

        try:
            event = json.loads(body.decode("utf-8"))
        except json.JSONDecodeError:
            self.send_response(400)
            self.end_headers()
            return

        result = handle_stripe_event(event, self.store)

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(result).encode())

    def do_GET(self) -> None:
        if self.path.rstrip("/") == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"ok":true,"service":"stripe-provision"}')
            return
        self.send_response(404)
        self.end_headers()


def main() -> int:
    p = argparse.ArgumentParser(description="Stripe webhook provisioner for CTG Pro keys")
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=9091)
    p.add_argument("--db", type=Path, default=DATA_DIR / "pro_keys.db")
    args = p.parse_args()

    secret = os.environ.get("CTG_STRIPE_WEBHOOK_SECRET", "").strip()
    if not secret:
        print("Warning: CTG_STRIPE_WEBHOOK_SECRET not set — signatures will fail", file=sys.stderr)

    StripeWebhookHandler.webhook_secret = secret
    StripeWebhookHandler.store = ProKeyStore(args.db)

    server = ThreadingHTTPServer((args.host, args.port), StripeWebhookHandler)
    print(f"Stripe provisioner on http://{args.host}:{args.port}/stripe/webhook")
    print(f"Pro keys DB: {args.db}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
