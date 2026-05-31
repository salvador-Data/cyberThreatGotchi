"""CTG event bus — emit, dedupe, persist (authorized defensive lab use only).

Events land under ``~/Backups/ctg-events/``; dedupe state in gitignored
``~/Backups/.vault/ctg-event-state.json``. No secrets in repo.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import threading
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Optional
from urllib.parse import urlparse

DEDUPE_WINDOW_SEC = 300
STATE_VERSION = 1
DEFAULT_BACKUPS = Path.home() / "Backups"
DEFAULT_STATE_PATH = DEFAULT_BACKUPS / ".vault" / "ctg-event-state.json"
DEFAULT_EVENTS_DIR = DEFAULT_BACKUPS / "ctg-events"
DEFAULT_INBOX = DEFAULT_EVENTS_DIR / "inbox"
DEFAULT_PROCESSED = DEFAULT_EVENTS_DIR / "processed"

VALID_SEVERITIES = frozenset({"info", "warn", "high", "critical"})
VALID_TYPES_PREFIX = (
    "wifi.",
    "utms.",
    "ids.",
    "email.",
    "system.",
)


@dataclass
class CTGEvent:
    """CTG event schema v1."""

    type: str
    source: str
    severity: str
    message: str
    id: str = ""
    bssid: str = ""
    ssid: str = ""
    message_id: str = ""
    timestamp: str = ""
    analyst_summary: str = ""

    def __post_init__(self) -> None:
        if not self.timestamp:
            self.timestamp = _utc_now_iso()
        if not self.id:
            self.id = str(uuid.uuid4())
        self.severity = (self.severity or "info").lower()
        self.type = (self.type or "system.unknown").strip()
        self.source = (self.source or "unknown").strip()
        if self.severity not in VALID_SEVERITIES:
            self.severity = "info"

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "CTGEvent":
        known = {f.name for f in cls.__dataclass_fields__.values()}  # type: ignore[attr-defined]
        filtered = {k: v for k, v in data.items() if k in known}
        for req in ("type", "source", "severity", "message"):
            filtered.setdefault(req, data.get(req, ""))
        return cls(**filtered)


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def _parse_ts(ts: str) -> datetime:
    if ts.endswith("Z"):
        ts = ts[:-1] + "+00:00"
    return datetime.fromisoformat(ts)


def wifi_fingerprint(event: CTGEvent) -> str:
    """SHA256 dedupe key for WiFi events (type + ssid + bssid)."""
    raw = f"{event.type}|{event.ssid}|{event.bssid}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def is_wifi_event(event: CTGEvent) -> bool:
    return event.type.startswith("wifi.")


class EventBus:
    """File-backed CTG event bus with dedupe."""

    def __init__(
        self,
        state_path: Path | None = None,
        events_dir: Path | None = None,
    ) -> None:
        self.state_path = state_path or DEFAULT_STATE_PATH
        self.events_dir = events_dir or DEFAULT_EVENTS_DIR
        self.inbox = self.events_dir / "inbox"
        self.processed = self.events_dir / "processed"
        self._lock = threading.Lock()

    def _ensure_dirs(self) -> None:
        self.inbox.mkdir(parents=True, exist_ok=True)
        self.processed.mkdir(parents=True, exist_ok=True)
        self.state_path.parent.mkdir(parents=True, exist_ok=True)

    def load_state(self) -> dict[str, Any]:
        self._ensure_dirs()
        if not self.state_path.exists():
            return {"version": STATE_VERSION, "message_ids": {}, "fingerprints": {}, "recent": []}
        try:
            data = json.loads(self.state_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return {"version": STATE_VERSION, "message_ids": {}, "fingerprints": {}, "recent": []}
        data.setdefault("version", STATE_VERSION)
        data.setdefault("message_ids", {})
        data.setdefault("fingerprints", {})
        data.setdefault("recent", [])
        return data

    def save_state(self, state: dict[str, Any]) -> None:
        self._ensure_dirs()
        tmp = self.state_path.with_suffix(".tmp")
        tmp.write_text(json.dumps(state, indent=2), encoding="utf-8")
        tmp.replace(self.state_path)

    def _prune_old(self, mapping: dict[str, str], now: datetime) -> dict[str, str]:
        kept: dict[str, str] = {}
        for key, ts in mapping.items():
            try:
                if (now - _parse_ts(ts)).total_seconds() <= DEDUPE_WINDOW_SEC * 2:
                    kept[key] = ts
            except ValueError:
                continue
        return kept

    def is_duplicate(self, event: CTGEvent, state: dict[str, Any] | None = None) -> bool:
        """Return True if event should be suppressed (dedupe hit)."""
        state = state or self.load_state()
        now = datetime.now(timezone.utc)
        if event.message_id:
            mid = event.message_id.strip()
            if mid and mid in state.get("message_ids", {}):
                last = _parse_ts(state["message_ids"][mid])
                if (now - last).total_seconds() < DEDUPE_WINDOW_SEC:
                    return True
        if is_wifi_event(event) and (event.ssid or event.bssid):
            fp = wifi_fingerprint(event)
            if fp in state.get("fingerprints", {}):
                last = _parse_ts(state["fingerprints"][fp])
                if (now - last).total_seconds() < DEDUPE_WINDOW_SEC:
                    return True
        return False

    def record_dedupe(self, event: CTGEvent, state: dict[str, Any]) -> None:
        now_iso = _utc_now_iso()
        if event.message_id:
            state.setdefault("message_ids", {})[event.message_id.strip()] = now_iso
        if is_wifi_event(event) and (event.ssid or event.bssid):
            state.setdefault("fingerprints", {})[wifi_fingerprint(event)] = now_iso
        now = datetime.now(timezone.utc)
        state["message_ids"] = self._prune_old(state.get("message_ids", {}), now)
        state["fingerprints"] = self._prune_old(state.get("fingerprints", {}), now)

    def emit(
        self,
        event: CTGEvent | dict[str, Any],
        *,
        skip_dedupe: bool = False,
        enrich_summary: bool = True,
    ) -> tuple[CTGEvent, bool]:
        """Emit event. Returns (event, accepted). accepted=False when deduped."""
        if isinstance(event, dict):
            event = CTGEvent.from_dict(event)
        with self._lock:
            state = self.load_state()
            if not skip_dedupe and self.is_duplicate(event, state):
                return event, False
            if enrich_summary and not event.analyst_summary:
                try:
                    from core.ctg_event_summarize import summarize_event

                    event.analyst_summary = summarize_event(event.to_dict())
                except ImportError:
                    pass
            self.record_dedupe(event, state)
            recent = state.get("recent", [])
            recent.insert(0, event.to_dict())
            state["recent"] = recent[:100]
            self.save_state(state)
            out_path = self.inbox / f"{event.id}.json"
            out_path.write_text(json.dumps(event.to_dict(), indent=2), encoding="utf-8")
            processed_path = self.processed / f"{event.id}.json"
            processed_path.write_text(json.dumps(event.to_dict(), indent=2), encoding="utf-8")
            return event, True

    def list_recent(self, limit: int = 20) -> list[dict[str, Any]]:
        state = self.load_state()
        return list(state.get("recent", [])[:limit])

    def poll_inbox(self, move: bool = True) -> list[dict[str, Any]]:
        self._ensure_dirs()
        events: list[dict[str, Any]] = []
        for path in sorted(self.inbox.glob("*.json")):
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
                events.append(data)
                if move:
                    dest = self.processed / path.name
                    if not dest.exists():
                        dest.write_text(json.dumps(data, indent=2), encoding="utf-8")
                    path.unlink(missing_ok=True)
            except (json.JSONDecodeError, OSError):
                continue
        return events


def validate_event_payload(data: dict[str, Any]) -> Optional[str]:
    """Return error string or None if valid."""
    for req in ("type", "source", "severity", "message"):
        if not str(data.get(req, "")).strip():
            return f"missing required field: {req}"
    etype = str(data["type"])
    if not any(etype.startswith(p) for p in VALID_TYPES_PREFIX):
        return f"unsupported event type prefix: {etype}"
    return None


class _EventHandler(BaseHTTPRequestHandler):
    bus: EventBus

    def log_message(self, fmt: str, *args: Any) -> None:
        return

    def _json_response(self, code: int, body: dict[str, Any]) -> None:
        raw = json.dumps(body).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path in ("/events", "/api/events"):
            limit = 20
            self._json_response(200, {"events": self.bus.list_recent(limit=limit)})
            return
        if parsed.path in ("/health", "/api/health"):
            self._json_response(200, {"status": "ok", "service": "ctg-event-bus"})
            return
        self._json_response(404, {"error": "not found"})

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path not in ("/events", "/api/events"):
            self._json_response(404, {"error": "not found"})
            return
        length = int(self.headers.get("Content-Length", 0))
        try:
            data = json.loads(self.rfile.read(length).decode("utf-8"))
        except json.JSONDecodeError:
            self._json_response(400, {"error": "invalid json"})
            return
        err = validate_event_payload(data)
        if err:
            self._json_response(400, {"error": err})
            return
        event, accepted = self.bus.emit(data)
        code = 201 if accepted else 200
        self._json_response(code, {"accepted": accepted, "event": event.to_dict()})


def run_http_server(host: str = "127.0.0.1", port: int = 8766, bus: EventBus | None = None) -> None:
    bus = bus or EventBus()
    handler = type("Handler", (_EventHandler,), {"bus": bus})
    server = ThreadingHTTPServer((host, port), handler)
    print(f"CTG event bus listening on http://{host}:{port}/events")
    server.serve_forever()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="CTG event bus CLI")
    sub = parser.add_subparsers(dest="cmd")

    emit_p = sub.add_parser("emit", help="Emit one event from JSON file or stdin")
    emit_p.add_argument("--file", "-f", type=Path, help="JSON file")
    emit_p.add_argument("--json", help="Inline JSON string")
    emit_p.add_argument("--skip-dedupe", action="store_true")

    sub.add_parser("list", help="List recent events")
    sub.add_parser("poll", help="Poll inbox directory")

    serve_p = sub.add_parser("serve", help="Run local HTTP event bus")
    serve_p.add_argument("--host", default="127.0.0.1")
    serve_p.add_argument("--port", type=int, default=8766)

    args = parser.parse_args(argv)
    bus = EventBus()

    if args.cmd == "emit":
        raw: str
        if args.file:
            raw = args.file.read_text(encoding="utf-8")
        elif args.json:
            raw = args.json
        else:
            import sys

            raw = sys.stdin.read()
        data = json.loads(raw)
        err = validate_event_payload(data)
        if err:
            print(err)
            return 1
        event, accepted = bus.emit(data, skip_dedupe=args.skip_dedupe)
        print(json.dumps({"accepted": accepted, "event": event.to_dict()}, indent=2))
        return 0

    if args.cmd == "list":
        print(json.dumps(bus.list_recent(), indent=2))
        return 0

    if args.cmd == "poll":
        print(json.dumps(bus.poll_inbox(), indent=2))
        return 0

    if args.cmd == "serve":
        run_http_server(args.host, args.port, bus)
        return 0

    parser.print_help()
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
