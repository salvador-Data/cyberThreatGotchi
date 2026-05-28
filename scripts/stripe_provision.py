#!/usr/bin/env python3
"""
Stripe webhook → provision CTG Pro API keys.

Run alongside CTG web server or standalone:

  set CTG_STRIPE_WEBHOOK_SECRET=whsec_...
  python scripts/stripe_provision.py --port 9091

Point Stripe webhook to: https://your-host:9091/stripe/webhook
Events: checkout.session.completed, customer.subscription.created,
        customer.subscription.updated, customer.subscription.deleted,
        invoice.payment_failed
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from config.settings import DATA_DIR
from core.security import verify_stripe_webhook
from core.stripe_provisioning import handle_provision_event
from db.pro_keys import ProKeyStore


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

        result = handle_provision_event(event, self.store)
        etype = event.get("type", "")
        if result.get("api_key"):
            print(f"[stripe] provision event {etype} customer={result.get('customer_id', '')}")
        elif result.get("revoked"):
            print(f"[stripe] revoked key on {etype}")

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
        print("Warning: CTG_STRIPE_WEBHOOK_SECRET not set - signatures will fail", file=sys.stderr)

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
