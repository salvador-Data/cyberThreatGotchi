"""Optional outbound webhooks for threat events (SOC, Bjorn log bridge, etc.)."""

from __future__ import annotations

import json
import logging
import queue
import threading
import urllib.error
import urllib.request
from typing import Any, Optional

logger = logging.getLogger(__name__)


class WebhookDispatcher:
    """Fire-and-forget JSON POSTs on a background thread."""

    def __init__(
        self,
        url: str,
        secret: str = "",
        timeout: float = 5.0,
        max_queue: int = 100,
    ) -> None:
        self.url = url.strip()
        self.secret = secret.strip()
        self.timeout = timeout
        self._queue: queue.Queue[Optional[dict[str, Any]]] = queue.Queue(maxsize=max_queue)
        self._thread: Optional[threading.Thread] = None
        if self.url:
            self._thread = threading.Thread(target=self._worker, name="ctg-webhook", daemon=True)
            self._thread.start()

    @property
    def enabled(self) -> bool:
        return bool(self.url)

    def _worker(self) -> None:
        while True:
            payload = self._queue.get()
            try:
                if payload is None:
                    return
                self._post(payload)
            finally:
                self._queue.task_done()

    def _post(self, payload: dict[str, Any]) -> None:
        data = json.dumps(payload, default=str).encode("utf-8")
        req = urllib.request.Request(self.url, data=data, method="POST")
        req.add_header("Content-Type", "application/json")
        req.add_header("User-Agent", "CyberThreatGotchi/1.0")
        if self.secret:
            req.add_header("X-CTG-Secret", self.secret)
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                resp.read()
        except urllib.error.URLError as exc:
            logger.warning("Webhook delivery failed: %s", exc)

    def notify(self, payload: dict[str, Any]) -> None:
        if not self.enabled:
            return
        try:
            self._queue.put_nowait(payload)
        except queue.Full:
            logger.warning("Webhook queue full; dropping event")

    def build_threat_payload(
        self,
        *,
        timestamp: str,
        event: dict[str, Any],
        gotchi: Optional[dict[str, Any]] = None,
    ) -> dict[str, Any]:
        body: dict[str, Any] = {
            "event": "threat",
            "source": "cyberthreatgotchi",
            "timestamp": timestamp,
            "threat": event,
        }
        if gotchi:
            body["gotchi"] = gotchi
        return body
