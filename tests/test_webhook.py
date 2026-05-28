"""Webhook dispatcher tests."""

from __future__ import annotations

import json
import sys
from io import BytesIO
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from core.webhook import WebhookDispatcher


def test_webhook_disabled_no_op():
    hook = WebhookDispatcher("")
    hook.notify({"event": "threat"})
    assert hook.enabled is False


@patch("core.webhook.urllib.request.urlopen")
def test_webhook_posts_json(mock_urlopen: MagicMock):
    mock_urlopen.return_value.__enter__.return_value = BytesIO(b"ok")
    hook = WebhookDispatcher("http://127.0.0.1:9090/hook", secret="test-secret")
    payload = hook.build_threat_payload(
        timestamp="2026-05-28T00:00:00Z",
        event={"severity": "high", "source_ip": "1.2.3.4"},
        gotchi={"mood": "alert"},
    )
    hook.notify(payload)
    hook._queue.join()

    assert mock_urlopen.called
    req = mock_urlopen.call_args[0][0]
    assert req.full_url == "http://127.0.0.1:9090/hook"
    assert req.get_header("Content-type") == "application/json"
    assert req.get_header("X-ctg-secret") == "test-secret" or req.get_header("X-CTG-Secret") == "test-secret"
    body = json.loads(req.data.decode())
    assert body["event"] == "threat"
    assert body["threat"]["source_ip"] == "1.2.3.4"
