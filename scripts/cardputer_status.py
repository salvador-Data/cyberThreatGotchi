#!/usr/bin/env python3
"""
Poll CyberThreatGotchi /api/status from a pocket device or laptop.

Use on M5Stack Cardputer (MicroPython with urequests) or any Python host.
Desktop test:
  python scripts/cardputer_status.py --host 127.0.0.1 --watch
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request

MOOD_ICONS = {
    "idle": "(~)",
    "happy": "(^)",
    "alert": "(!)",
    "attack": "(X)",
    "sleep": "(z)",
    "feed": "(o)",
    "defend": "[=]",
}


def fetch_status(host: str, port: int, timeout: float = 5.0) -> dict:
    url = f"http://{host}:{port}/api/status"
    req = urllib.request.Request(url, headers={"User-Agent": "CTG-Cardputer/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def render_card(data: dict) -> str:
    g = data.get("gotchi", {})
    mood = g.get("mood", "idle")
    icon = MOOD_ICONS.get(mood, "(?")
    threats = data.get("threats") or []
    last = threats[0] if threats else {}
    rt = data.get("runtime", {})
    lines = [
        "=== CyberThreatGotchi ===",
        f" {icon} {g.get('name', 'Cipherhorn')}  Lv.{g.get('level', 1)}",
        f" Mood: {mood.upper()}  XP:{g.get('security_xp', 0)}",
        f" Blocked:{g.get('threats_blocked', 0)}  Seen:{g.get('threats_seen', 0)}",
        f" {g.get('status_line', '')[:40]}",
        "--- last threat ---",
    ]
    if last:
        lines.append(
            f" {last.get('severity','?')} {last.get('source_ip','?')} "
            f"{last.get('action_taken','?')}"
        )
        lines.append(f" {str(last.get('description',''))[:38]}")
    else:
        lines.append(" (none yet)")
    lines.append(f" Mode:{rt.get('mode','?')}  IF:{rt.get('interface','?')}")
    return "\n".join(lines)


def main() -> int:
    p = argparse.ArgumentParser(description="Cardputer-style CTG status poller")
    p.add_argument("--host", default="127.0.0.1", help="CTG device IP")
    p.add_argument("--port", type=int, default=8765)
    p.add_argument("--watch", action="store_true", help="Refresh every 3s")
    p.add_argument("--interval", type=float, default=3.0)
    args = p.parse_args()
    while True:
        try:
            data = fetch_status(args.host, args.port)
            if args.watch:
                print("\033[2J\033[H", end="")
            print(render_card(data))
        except urllib.error.URLError as exc:
            print(f"CTG unreachable at {args.host}:{args.port} — {exc}", file=sys.stderr)
            if not args.watch:
                return 1
        if not args.watch:
            return 0
        time.sleep(args.interval)


if __name__ == "__main__":
    raise SystemExit(main())
