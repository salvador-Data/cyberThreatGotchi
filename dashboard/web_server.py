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
from core.fulfillment_queue import (
    add_order,
    build_order,
    get_order,
    list_orders,
    notify_fulfillment_event,
    order_from_stripe_event,
    update_order,
)
from core.security import (
    RateLimiter,
    apply_security_headers,
    require_api_token,
    require_operator_token,
    sanitize_mood,
    verify_stripe_webhook,
)
from core.state_bus import GotchiSnapshot, StateBus
from db.audit_chain import AuditChain
from db.logger import ThreatLogger

if TYPE_CHECKING:
    from core.gotchi import CyberGotchi
    from db.pro_keys import ProKeyStore

STATIC = Path(__file__).resolve().parent / "static"
WEBSITE = Path(__file__).resolve().parent.parent / "website"


def create_web_app(
    bus: StateBus,
    logger: Optional[ThreatLogger] = None,
    audit: Optional[AuditChain] = None,
    pro_keys: Optional["ProKeyStore"] = None,
    api_token: str = "",
    operator_token: str = "",
    fulfillment_webhook_url: str = "",
    stripe_webhook_secret: str = "",
    on_feed: Optional[Callable[[], None]] = None,
    on_pet: Optional[Callable[[], None]] = None,
) -> Flask:
    app = Flask(__name__, static_folder=str(STATIC), static_url_path="/static")
    limiter = RateLimiter(max_calls=120, window_sec=60.0)
    write_limiter = RateLimiter(max_calls=30, window_sec=60.0)
    token_guard = require_api_token(api_token)
    operator_guard = require_operator_token(operator_token, api_token)
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

    @app.get("/operator/fulfillment")
    @app.get("/operator/fulfillment.html")
    def operator_fulfillment_page() -> Response:
        page = WEBSITE / "operator" / "fulfillment.html"
        if not page.is_file():
            return Response("operator fulfillment dashboard not found", status=404)
        return Response(page.read_text(encoding="utf-8"), mimetype="text/html")

    @app.get("/website/js/<path:filename>")
    def website_js(filename: str) -> Response:
        safe = Path(filename).name if "/" not in filename else filename
        if ".." in safe or safe.startswith("/"):
            return Response(status=400)
        base = WEBSITE / "js"
        path = (base / safe).resolve()
        if not str(path).startswith(str(base.resolve())):
            return Response(status=400)
        if not path.is_file():
            return Response(status=404)
        return send_from_directory(path.parent, path.name)

    @app.get("/website/css/<path:filename>")
    def website_css(filename: str) -> Response:
        if ".." in filename:
            return Response(status=400)
        base = WEBSITE / "css"
        path = (base / filename).resolve()
        if not str(path).startswith(str(base.resolve())):
            return Response(status=400)
        if not path.is_file():
            return Response(status=404)
        return send_from_directory(path.parent, path.name)

    @app.get("/api/fulfillment/queue")
    @operator_guard
    def api_fulfillment_list() -> Response:
        pending_only = request.args.get("pending", "").lower() in ("1", "true", "yes")
        status = request.args.get("status", "").strip() or None
        orders = list_orders(status=status, pending_only=pending_only)
        return jsonify({"orders": orders, "count": len(orders)})

    @app.post("/api/fulfillment/queue")
    @operator_guard
    def api_fulfillment_enqueue() -> Response:
        if not write_limiter.allow():
            return jsonify({"error": "rate limit exceeded"}), 429
        body = request.get_json(silent=True) or {}
        try:
            if body.get("type") and body.get("data"):
                order = order_from_stripe_event(body)
            elif body.get("object") and body.get("object", {}).get("object") == "checkout.session":
                order = order_from_stripe_event({"type": "checkout.session.completed", "data": {"object": body["object"]}})
            elif body.get("stripe_key"):
                order = build_order(
                    stripe_key=str(body["stripe_key"]),
                    ship_to=body.get("ship_to") or body.get("ship_to_text") or "",
                    customer_email=str(body.get("customer_email") or ""),
                    stripe_session_id=str(body.get("stripe_session_id") or ""),
                    stripe_payment_intent=str(body.get("stripe_payment_intent") or ""),
                    notes=str(body.get("notes") or ""),
                )
            else:
                return jsonify({"error": "stripe_key or Stripe event payload required"}), 400
            saved = add_order(order)
            notify_fulfillment_event("fulfillment.queued", saved, fulfillment_webhook_url)
            return jsonify({"ok": True, "order": saved}), 201
        except ValueError as exc:
            return jsonify({"error": str(exc)}), 400

    @app.post("/api/fulfillment/webhook")
    def api_fulfillment_stripe_webhook() -> Response:
        if not write_limiter.allow():
            return jsonify({"error": "rate limit exceeded"}), 429
        body = request.get_data()
        sig = request.headers.get("Stripe-Signature", "")
        if stripe_webhook_secret and not verify_stripe_webhook(body, sig, stripe_webhook_secret):
            return jsonify({"error": "invalid signature"}), 400
        try:
            event = json.loads(body.decode("utf-8"))
        except json.JSONDecodeError:
            return jsonify({"error": "invalid json"}), 400
        etype = str(event.get("type") or "")
        if etype not in ("checkout.session.completed", "payment_intent.succeeded"):
            return jsonify({"ok": True, "skipped": etype})
        try:
            order = order_from_stripe_event(event)
            saved = add_order(order)
            notify_fulfillment_event("fulfillment.queued", saved, fulfillment_webhook_url)
            return jsonify({"ok": True, "order_id": saved.get("id")})
        except ValueError as exc:
            return jsonify({"error": str(exc)}), 400

    @app.patch("/api/fulfillment/queue/<order_id>")
    @operator_guard
    def api_fulfillment_update(order_id: str) -> Response:
        if not write_limiter.allow():
            return jsonify({"error": "rate limit exceeded"}), 429
        body = request.get_json(silent=True) or {}
        try:
            updated = update_order(order_id, body)
        except ValueError as exc:
            return jsonify({"error": str(exc)}), 400
        if updated is None:
            return jsonify({"error": "not found"}), 404
        if body.get("status"):
            notify_fulfillment_event(f"fulfillment.{body['status']}", updated, fulfillment_webhook_url)
        return jsonify({"ok": True, "order": updated})

    @app.get("/api/fulfillment/queue/<order_id>")
    @operator_guard
    def api_fulfillment_get(order_id: str) -> Response:
        order = get_order(order_id)
        if order is None:
            return jsonify({"error": "not found"}), 404
        return jsonify(order)

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
        operator_token: str = "",
        fulfillment_webhook_url: str = "",
        stripe_webhook_secret: str = "",
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
            operator_token=operator_token,
            fulfillment_webhook_url=fulfillment_webhook_url,
            stripe_webhook_secret=stripe_webhook_secret,
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
