"""Tests for CTG email notification dedup (core/ctg_email_notify.py)."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from core import ctg_email_notify as notify


def test_normalize_message_id_strips_brackets():
    assert notify.normalize_message_id("<ABC@example.com>") == "abc@example.com"
    assert notify.normalize_message_id("  ") is None


def test_content_fingerprint_stable():
    a = notify.content_fingerprint("a@b.com", "Mon, 1 Jan 2024", "Hi", "body")
    b = notify.content_fingerprint("a@b.com", "Mon, 1 Jan 2024", "Hi", "body")
    c = notify.content_fingerprint("a@b.com", "Mon, 1 Jan 2024", "Hi", "other")
    assert a == b
    assert a != c
    assert len(a) == 64


def test_dedup_message_id_primary():
    state = notify.EmailNotifyState(path=Path("/tmp/unused.json"))
    mid, chash = notify.dedup_keys_from_headers(
        "<same@example.com>",
        "from@example.com",
        "date",
        "subject",
        "body",
    )
    assert mid == "same@example.com"
    state.mark_seen(mid, chash)
    assert state.is_duplicate(mid, chash)
    assert state.is_duplicate(None, chash)


def test_dedup_in_reply_to_chain():
    state = notify.EmailNotifyState(path=Path("/tmp/unused2.json"))
    parent_mid = "parent-msg-id@example.com"
    state.mark_seen(parent_mid, "hash-parent")
    assert state.is_duplicate(None, "hash-child", in_reply_to=f"<{parent_mid}>")


def test_dedup_forward_duplicate_same_content_hash():
    """Duck forward + Proton direct often share Message-ID; fallback catches rewrites."""
    state = notify.EmailNotifyState(path=Path("/tmp/unused3.json"))
    _, chash = notify.dedup_keys_from_headers(
        None,
        "alerts@example.com",
        "Mon, 1 Jan 2024 12:00:00 +0000",
        "IDS alert",
        "Snort SID 1000001 triggered",
    )
    state.mark_seen(None, chash)
    _, chash2 = notify.dedup_keys_from_headers(
        "<different-id@forwarder.example>",
        "alerts@example.com",
        "Mon, 1 Jan 2024 12:00:00 +0000",
        "IDS alert",
        "Snort SID 1000001 triggered",
    )
    assert state.is_duplicate(None, chash2)


def test_state_save_load_roundtrip(tmp_path: Path):
    path = tmp_path / "email-notify-state.json"
    state = notify.EmailNotifyState(path=path)
    state.mark_seen("mid@example.com", "abc123")
    state.save()
    loaded = notify.EmailNotifyState.load(path)
    assert "mid@example.com" in loaded.message_ids
    assert "abc123" in loaded.content_hashes


def test_parse_imap_message_extracts_headers():
    raw = (
        b"From: sender@example.com\r\n"
        b"To: lab@example.com\r\n"
        b"Subject: Test\r\n"
        b"Message-ID: <msg-1@example.com>\r\n"
        b"Date: Mon, 1 Jan 2024 00:00:00 +0000\r\n"
        b"\r\n"
        b"Hello CTG lab\r\n"
    )
    parsed = notify.parse_imap_message(b"1", raw)
    assert parsed.message_id_key == "msg-1@example.com"
    assert parsed.subject == "Test"
    assert "Hello" in parsed.body_prefix


def test_is_high_priority_subject():
    assert notify.is_high_priority_subject("Wazuh alert: agent disconnected")
    assert not notify.is_high_priority_subject("Newsletter weekly digest")


def test_cli_dedup_test_subprocess():
    import subprocess
    import sys

    root = Path(__file__).resolve().parent.parent
    proc = subprocess.run(
        [
            sys.executable,
            str(root / "scripts" / "ctg_email_notify_cli.py"),
            "dedup-test",
            "--message-id",
            "<x@test>",
            "--subject",
            "Alert",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    assert proc.returncode == 0
    data = json.loads(proc.stdout)
    assert data["ok"] is True
    assert data["message_id_key"] == "x@test"
