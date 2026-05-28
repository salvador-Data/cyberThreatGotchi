#!/usr/bin/env python3
"""
Bjorn bridge — ingest CyberThreatGotchi webhooks for Bjorn e-paper status.

Run on the Raspberry Pi (or any host) that displays Bjorn:

  python scripts/bjorn_bridge.py --port 9090 --out data/bjorn_inbox.jsonl

Point CTG at this listener:

  CTG_WEBHOOK_URL=http://<bjorn-pi-ip>:9090/ctg
"""

from __future__ import annotations

import argparse
import json
import sys
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def format_epaper_line(payload: dict) -> str:
    """One-line summary suitable for Bjorn e-paper footer."""
    g = payload.get("gotchi") or {}
    t = payload.get("threat") or {}
    mood = g.get("mood", "idle")
    src = t.get("source_ip", "?")
    action = t.get("action_taken", "logged")
    sev = t.get("severity", "?")
    return f"CTG {mood.upper()} | {src} {sev} {action}"[:42]


class BjornBridgeHandler(BaseHTTPRequestHandler):
    out_path: Path = Path("data/bjorn_inbox.jsonl")
    status_path: Path = Path("data/bjorn_status.txt")
    secret: str = ""
    lock = threading.Lock()

    def log_message(self, format: str, *args: object) -> None:
        pass

    def _read_body(self) -> bytes:
        length = int(self.headers.get("Content-Length", 0))
        return self.rfile.read(length) if length else b""

    def _auth_ok(self) -> bool:
        if not self.secret:
            return True
        return self.headers.get("X-CTG-Secret", "") == self.secret

    def do_GET(self) -> None:
        if self.path.rstrip("/") == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"ok":true,"service":"bjorn-bridge"}')
            return
        if self.path.rstrip("/") == "/status":
            line = ""
            if self.status_path.is_file():
                line = self.status_path.read_text(encoding="utf-8").strip()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.end_headers()
            self.wfile.write((line or "CTG idle").encode())
            return
        self.send_response(404)
        self.end_headers()

    def do_POST(self) -> None:
        if self.path.rstrip("/") not in ("/ctg", "/webhook"):
            self.send_response(404)
            self.end_headers()
            return
        if not self._auth_ok():
            self.send_response(401)
            self.end_headers()
            return
        try:
            payload = json.loads(self._read_body().decode("utf-8") or "{}")
        except json.JSONDecodeError:
            self.send_response(400)
            self.end_headers()
            return

        record = {
            "received_at": datetime.now(timezone.utc).isoformat(),
            "payload": payload,
            "epaper_line": format_epaper_line(payload),
        }
        with self.lock:
            self.out_path.parent.mkdir(parents=True, exist_ok=True)
            with self.out_path.open("a", encoding="utf-8") as fh:
                fh.write(json.dumps(record) + "\n")
            self.status_path.write_text(record["epaper_line"] + "\n", encoding="utf-8")

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"ok":true}')


def main() -> int:
    p = argparse.ArgumentParser(description="Bjorn webhook bridge for CyberThreatGotchi")
    p.add_argument("--host", default="0.0.0.0")
    p.add_argument("--port", type=int, default=9090)
    p.add_argument("--out", type=Path, default=ROOT / "data" / "bjorn_inbox.jsonl")
    p.add_argument("--status", type=Path, default=ROOT / "data" / "bjorn_status.txt")
    p.add_argument("--secret", default="", help="Match CTG_WEBHOOK_SECRET")
    args = p.parse_args()

    BjornBridgeHandler.out_path = args.out
    BjornBridgeHandler.status_path = args.status
    BjornBridgeHandler.secret = args.secret

    server = ThreadingHTTPServer((args.host, args.port), BjornBridgeHandler)
    print(f"Bjorn bridge listening on http://{args.host}:{args.port}/ctg")
    print(f"Inbox: {args.out}")
    print(f"E-paper line: {args.status}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
