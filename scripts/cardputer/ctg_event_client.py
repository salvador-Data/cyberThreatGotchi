#!/usr/bin/env python3
"""Cardputer host-side UTMS event client — poll CTG event bus / API.

MicroPython on-device firmware polls the same JSON endpoints; this script is the
desktop test harness. Edit CTG_HOST before flashing companion firmware in M5_OS-Cardputer.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8766
POLL_SEC = 4


def fetch_events(host: str, port: int) -> list[dict]:
    url = f"http://{host}:{port}/events"
    with urllib.request.urlopen(url, timeout=5) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return list(data.get("events", []))


def format_line(ev: dict) -> str:
    sev = ev.get("severity", "info")
    etype = ev.get("type", "?")
    summary = ev.get("analyst_summary") or ev.get("message", "")
    return f"[{sev}] {etype}: {summary}"


def watch(host: str, port: int, interval: int, once: bool) -> int:
    seen: set[str] = set()
    while True:
        try:
            events = fetch_events(host, port)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            print(f"CTG event bus offline: {exc}", file=sys.stderr)
            if once:
                return 2
            time.sleep(interval)
            continue
        for ev in events:
            eid = str(ev.get("id", ""))
            if eid and eid in seen:
                continue
            if eid:
                seen.add(eid)
            print(format_line(ev))
        if once:
            return 0
        time.sleep(interval)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Cardputer CTG event client (host test)")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--watch", action="store_true")
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--interval", type=int, default=POLL_SEC)
    args = parser.parse_args(argv)

    if args.watch or args.once:
        return watch(args.host, args.port, args.interval, args.once)

    events = fetch_events(args.host, args.port)
    print(json.dumps(events, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
