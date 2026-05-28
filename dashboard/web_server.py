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
from db.logger import ThreatLogger

if TYPE_CHECKING:
    from core.gotchi import CyberGotchi

STATIC = Path(__file__).resolve().parent / "static"


def create_web_app(
    bus: StateBus,
    logger: Optional[ThreatLogger] = None,
    on_feed: Optional[Callable[[], None]] = None,
    on_pet: Optional[Callable[[], None]] = None,
) -> Flask:
    app = Flask(__name__, static_folder=str(STATIC), static_url_path="/static")

    @app.route("/")
    def index() -> Response:
        return Response((STATIC / "index.html").read_text(encoding="utf-8"), mimetype="text/html")

    @app.get("/api/health")
    def api_health() -> Response:
        return jsonify({"ok": True, "service": "cyberthreatgotchi"})

    @app.get("/api/status")
    def api_status() -> Response:
        return jsonify(bus.snapshot())

    @app.get("/api/sprite/<mood>.png")
    def api_sprite(mood: str) -> Response:
        frame = int(request.args.get("frame", 0))
        path = sprite_path(mood, frame)
        if path is None:
            path = sprite_path("idle", frame)
        if path is None:
            return Response(status=404)
        return send_from_directory(path.parent, path.name, mimetype="image/png")

    @app.get("/api/threats")
    def api_threats() -> Response:
        limit = min(int(request.args.get("limit", 50)), 200)
        if logger is None:
            return jsonify({"threats": [], "count": 0})
        rows = logger.recent_threats(limit)
        return jsonify({"threats": rows, "count": logger.threat_count()})

    @app.get("/api/export/threats.csv")
    def api_export_csv() -> Response:
        if logger is None:
            return Response("no data\n", mimetype="text/csv")
        limit = min(int(request.args.get("limit", 500)), 5000)
        body = logger.export_csv(limit)
        return Response(
            body,
            mimetype="text/csv",
            headers={"Content-Disposition": "attachment; filename=ctg_threats.csv"},
        )

    @app.get("/api/export/report.json")
    def api_export_report() -> Response:
        snap = bus.snapshot()
        stats = logger.threat_stats() if logger else {}
        report = {
            "generated_at": ThreatLogger.utc_now(),
            "gotchi": snap.get("gotchi"),
            "runtime": snap.get("runtime"),
            "active_blocks": snap.get("blocks"),
            "statistics": stats,
            "recent_threats": snap.get("threats", [])[:20],
        }
        return jsonify(report)

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
        logger: Optional[ThreatLogger] = None,
        host: str = "0.0.0.0",
        port: int = 8765,
    ) -> None:
        self.bus = bus
        self.gotchi = gotchi
        self.logger = logger
        self.host = host
        self.port = port
        self._thread: Optional[threading.Thread] = None
        self.app = create_web_app(
            bus,
            logger=logger,
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
                frame_index=s.frame_index,
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
