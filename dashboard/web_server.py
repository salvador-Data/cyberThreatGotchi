"""Flask web dashboard — live gotchi + threat feed."""

from __future__ import annotations

import json
import threading
import time
from pathlib import Path
from typing import TYPE_CHECKING, Callable, Optional

from flask import Flask, Response, jsonify, request, send_from_directory

from assets.sprites.png_loader import sprite_path
from core.pro_feed import (
    build_hashes_payload,
    build_signatures_payload,
    build_yara_payload,
    validate_pro_key,
)
from core.security import (
    RateLimiter,
    apply_security_headers,
    require_api_token,
    sanitize_mood,
)
from core.state_bus import GotchiSnapshot, StateBus
from db.audit_chain import AuditChain
from db.logger import ThreatLogger

if TYPE_CHECKING:
    from core.gotchi import CyberGotchi
    from db.pro_keys import ProKeyStore

STATIC = Path(__file__).resolve().parent / "static"


def create_web_app(
    bus: StateBus,
    logger: Optional[ThreatLogger] = None,
    audit: Optional[AuditChain] = None,
    pro_keys: Optional["ProKeyStore"] = None,
    api_token: str = "",
    on_feed: Optional[Callable[[], None]] = None,
    on_pet: Optional[Callable[[], None]] = None,
) -> Flask:
    app = Flask(__name__, static_folder=str(STATIC), static_url_path="/static")
    limiter = RateLimiter(max_calls=120, window_sec=60.0)
    write_limiter = RateLimiter(max_calls=30, window_sec=60.0)
    token_guard = require_api_token(api_token)
    app.config["JSON_SORT_KEYS"] = False

    @app.after_request
    def _secure_headers(response: Response) -> Response:
        return apply_security_headers(response)

    @app.errorhandler(429)
    def _rate_limited(_exc: Exception) -> tuple[Response, int]:
        return jsonify({"error": "rate limit exceeded"}), 429

    @app.before_request
    def _global_rate_limit() -> Optional[tuple[Response, int]]:
        if request.path.startswith("/api/") and not limiter.allow():
            return jsonify({"error": "rate limit exceeded"}), 429
        return None

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
        safe_mood = sanitize_mood(mood)
        if safe_mood is None:
            return Response(status=400)
        frame = min(max(int(request.args.get("frame", 0)), 0), 1)
        path = sprite_path(safe_mood, frame)
        if path is None:
            path = sprite_path("idle", frame)
        if path is None:
            return Response(status=404)
        return send_from_directory(path.parent, path.name, mimetype="image/png")

    @app.get("/api/threats")
    def api_threats() -> Response:
        limit = min(max(int(request.args.get("limit", 50)), 1), 200)
        if logger is None:
            return jsonify({"threats": [], "count": 0})
        rows = logger.recent_threats(limit)
        return jsonify({"threats": rows, "count": logger.threat_count()})

    @app.get("/api/export/threats.csv")
    def api_export_csv() -> Response:
        if logger is None:
            return Response("no data\n", mimetype="text/csv")
        limit = min(max(int(request.args.get("limit", 500)), 1), 5000)
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

    @app.get("/api/export/audit.json")
    def api_export_audit() -> Response:
        if audit is None:
            return jsonify({"error": "audit chain disabled"}), 503
        limit = min(max(int(request.args.get("limit", 500)), 1), 5000)
        body = audit.export_chain(limit=limit)
        ok, msg = audit.verify_chain()
        body["verified"] = ok
        body["verify_message"] = msg
        return jsonify(body)

    def _pro_auth() -> Optional[Response]:
        key = request.headers.get("X-CTG-Pro-Key", "")
        if not validate_pro_key(key, store=pro_keys):
            return jsonify({"error": "invalid or missing X-CTG-Pro-Key"}), 401
        return None

    @app.get("/api/pro/feed/signatures")
    def api_pro_signatures() -> Response:
        denied = _pro_auth()
        if denied:
            return denied
        return jsonify(build_signatures_payload())

    @app.get("/api/pro/feed/yara")
    def api_pro_yara() -> Response:
        denied = _pro_auth()
        if denied:
            return denied
        return jsonify(build_yara_payload())

    @app.get("/api/pro/feed/hashes")
    def api_pro_hashes() -> Response:
        denied = _pro_auth()
        if denied:
            return denied
        return jsonify(build_hashes_payload())

    @app.post("/api/feed")
    @token_guard
    def api_feed() -> Response:
        if not write_limiter.allow():
            return jsonify({"error": "rate limit exceeded"}), 429
        if on_feed:
            on_feed()
        return jsonify({"ok": True})

    @app.post("/api/pet")
    @token_guard
    def api_pet() -> Response:
        if not write_limiter.allow():
            return jsonify({"error": "rate limit exceeded"}), 429
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
        audit: Optional[AuditChain] = None,
        pro_keys: Optional["ProKeyStore"] = None,
        api_token: str = "",
        host: str = "0.0.0.0",
        port: int = 8765,
    ) -> None:
        self.bus = bus
        self.gotchi = gotchi
        self.logger = logger
        self.audit = audit
        self.host = host
        self.port = port
        self._thread: Optional[threading.Thread] = None
        self.app = create_web_app(
            bus,
            logger=logger,
            audit=audit,
            pro_keys=pro_keys,
            api_token=api_token,
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
