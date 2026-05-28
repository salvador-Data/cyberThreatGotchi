#!/usr/bin/env python3
"""Minimal webhook receiver for testing CTG integrations.

Example:
  python scripts/webhook_receiver.py --port 9090 --secret mysharedsecret
  CTG_WEBHOOK_URL=http://127.0.0.1:9090/ctg CTG_WEBHOOK_SECRET=mysharedsecret python main.py --simulation
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.security import constant_time_equal


class Handler(BaseHTTPRequestHandler):
    secret: str = ""

    def do_POST(self) -> None:  # noqa: N802
        if self.secret:
            provided = self.headers.get("X-CTG-Secret", "")
            if not constant_time_equal(provided, self.secret):
                self.send_response(401)
                self.end_headers()
                return
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b""
        try:
            payload = json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            payload = {"raw": raw.decode("utf-8", errors="replace")}
        print(f"[webhook] {self.path} -> {json.dumps(payload, indent=2)}")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"ok":true}')

    def log_message(self, fmt: str, *args: object) -> None:
        return


def main() -> int:
    p = argparse.ArgumentParser(description="CyberThreatGotchi webhook test receiver")
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=9090)
    p.add_argument("--secret", default=os.environ.get("CTG_WEBHOOK_SECRET", ""))
    args = p.parse_args()
    Handler.secret = args.secret.strip()
    server = HTTPServer((args.host, args.port), Handler)
    print(f"Listening on http://{args.host}:{args.port}/ (POST any path)")
    if Handler.secret:
        print("Requiring X-CTG-Secret header")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
