#!/usr/bin/env python3
"""Minimal webhook receiver for testing CTG integrations.

Example:
  python scripts/webhook_receiver.py --port 9090
  CTG_WEBHOOK_URL=http://127.0.0.1:9090/ctg python main.py --simulation
"""

from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:  # noqa: N802
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
    args = p.parse_args()
    server = HTTPServer((args.host, args.port), Handler)
    print(f"Listening on http://{args.host}:{args.port}/ (POST any path)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
