"""Flask web dashboard — live gotchi + threat feed."""

from __future__ import annotations

import json
import threading
import time
from pathlib import Path
from typing import TYPE_CHECKING, Callable, Optional

from flask import Flask, Response, jsonify, request, send_from_directory

from assets.sprites.png_loader import sprite_path
from core.state_bus import GotchiSnapshot, StateBus

if TYPE_CHECKING:
    from core.gotchi import CyberGotchi

STATIC = Path(__file__).resolve().parent / "static"


def create_web_app(
    bus: StateBus,
    on_feed: Optional[Callable[[], None]] = None,
    on_pet: Optional[Callable[[], None]] = None,
) -> Flask:
    app = Flask(__name__, static_folder=str(STATIC), static_url_path="/static")

    @app.route("/")
    def index() -> Response:
        return Response((STATIC / "index.html").read_text(encoding="utf-8"), mimetype="text/html")

    @app.get("/api/status")
    def api_status() -> Response:
        return jsonify(bus.snapshot())

    @app.get("/api/sprite/<mood>.png")
    def api_sprite(mood: str) -> Response:
        path = sprite_path(mood)
        if path is None:
            path = sprite_path("idle")
        if path is None:
            return Response(status=404)
        return send_from_directory(path.parent, path.name, mimetype="image/png")

    @app.post("/api/feed")
    def api_feed() -> Response:
        if on_feed:
            on_feed()
        return jsonify({"ok": True})

    @app.post("/api/pet")
    def api_pet() -> Response:
        if on_pet:
            on_pet()
        return jsonify({"ok": True})

    @app.get("/api/stream")
    def api_stream() -> Response:
        def generate() -> str:
            while True:
                payload = json.dumps(bus.snapshot())
                yield f"data: {payload}\n\n"
                time.sleep(1.0)

        return Response(generate(), mimetype="text/event-stream")

    return app


class WebDashboard:
    def __init__(
        self,
        bus: StateBus,
        gotchi: "CyberGotchi",
        host: str = "0.0.0.0",
        port: int = 8765,
    ) -> None:
        self.bus = bus
        self.gotchi = gotchi
        self.host = host
        self.port = port
        self._thread: Optional[threading.Thread] = None
        self.app = create_web_app(
            bus,
            on_feed=self.gotchi.feed,
            on_pet=self.gotchi.pet,
        )

    def sync_from_gotchi(self) -> None:
        s = self.gotchi.state
        self.bus.update_gotchi(
            GotchiSnapshot(
                name=s.name,
                mood=s.mood.value,
                hunger=s.hunger,
                happiness=s.happiness,
                security_xp=s.security_xp,
                level=s.level,
                threats_blocked=s.threats_blocked,
                threats_seen=s.threats_seen,
                status_line=s.status_line,
                sprite_ascii=self.gotchi.render_sprite(),
            )
        )

    def start(self) -> None:
        if self._thread and self._thread.is_alive():
            return

        def _run() -> None:
            self.app.run(host=self.host, port=self.port, threaded=True, use_reloader=False)

        self._thread = threading.Thread(target=_run, name="ctg-web", daemon=True)
        self._thread.start()
