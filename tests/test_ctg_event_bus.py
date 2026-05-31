"""Tests for CTG event bus (core/ctg_event_bus.py)."""

from __future__ import annotations

import json
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

from core.ctg_event_bus import (
    CTGEvent,
    EventBus,
    validate_event_payload,
    wifi_fingerprint,
)


@pytest.fixture
def bus(tmp_path: Path) -> EventBus:
    state = tmp_path / "state.json"
    events = tmp_path / "events"
    return EventBus(state_path=state, events_dir=events)


def test_ctg_event_schema_roundtrip():
    ev = CTGEvent(
        id="test-id",
        type="wifi.deauth",
        source="kali",
        severity="warn",
        message="Deauth threshold exceeded",
        ssid="YourLabSSID",
        bssid="aa:bb:cc:dd:ee:ff",
        message_id="",
        timestamp="2026-05-31T12:00:00+00:00",
    )
    data = ev.to_dict()
    restored = CTGEvent.from_dict(data)
    assert restored.type == "wifi.deauth"
    assert restored.ssid == "YourLabSSID"


def test_wifi_fingerprint_stable():
    ev = CTGEvent(
        id="1",
        type="wifi.rogue_ap",
        source="kali",
        severity="high",
        message="dup ssid",
        ssid="LabNet",
        bssid="11:22:33:44:55:66",
    )
    assert wifi_fingerprint(ev) == wifi_fingerprint(ev)


def test_emit_writes_inbox_and_processed(bus: EventBus):
    payload = {
        "type": "wifi.rogue_ap",
        "source": "kali",
        "severity": "warn",
        "message": "Duplicate SSID detected",
        "ssid": "YourLabSSID",
        "bssid": "aa:bb:cc:dd:ee:01",
    }
    event, accepted = bus.emit(payload)
    assert accepted is True
    assert (bus.inbox / f"{event.id}.json").exists() or not list(bus.inbox.glob("*.json"))
    assert (bus.processed / f"{event.id}.json").exists()
    assert event.analyst_summary


def test_dedupe_wifi_within_window(bus: EventBus):
    payload = {
        "type": "wifi.deauth",
        "source": "windows",
        "severity": "warn",
        "message": "Disconnect storm",
        "ssid": "YourLabSSID",
        "bssid": "aa:bb:cc:dd:ee:02",
    }
    _, ok1 = bus.emit(payload)
    _, ok2 = bus.emit(payload)
    assert ok1 is True
    assert ok2 is False


def test_dedupe_message_id(bus: EventBus):
    payload = {
        "type": "email.ids_alert",
        "source": "email-bridge",
        "severity": "info",
        "message": "IDS digest",
        "message_id": "<pytest-123@ctg.local>",
    }
    _, ok1 = bus.emit(payload)
    _, ok2 = bus.emit(payload)
    assert ok1 is True
    assert ok2 is False


def test_validate_event_payload():
    assert validate_event_payload({"type": "wifi.jam", "source": "x", "severity": "warn", "message": "m"}) is None
    assert validate_event_payload({"type": "bad.type", "source": "x", "severity": "warn", "message": "m"})
    assert validate_event_payload({"type": "wifi.jam", "source": "", "severity": "warn", "message": "m"})


def test_prune_old_fingerprints(bus: EventBus):
    state = bus.load_state()
    old = (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat()
    state["fingerprints"] = {"deadbeef": old}
    bus.save_state(state)
    payload = {
        "type": "wifi.deauth",
        "source": "kali",
        "severity": "warn",
        "message": "fresh",
        "ssid": "NewSSID",
        "bssid": "00:11:22:33:44:55",
    }
    _, accepted = bus.emit(payload, skip_dedupe=False)
    assert accepted is True


def test_list_recent(bus: EventBus):
    bus.emit(
        {
            "type": "system.test",
            "source": "pytest",
            "severity": "info",
            "message": "one",
        }
    )
    recent = bus.list_recent(limit=5)
    assert len(recent) >= 1
    assert recent[0]["message"] == "one"
