"""Drop-ship fulfillment queue — local JSON store, Stripe ingestion, operator API backing."""

from __future__ import annotations

import importlib.util
import json
import re
import threading
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional
from urllib import error, request

from config.settings import DATA_DIR

QUEUE_VERSION = 1
QUEUE_PATH = Path(DATA_DIR) / "fulfillment_queue.json"
VALID_STATUSES = frozenset({"pending", "ordered", "shipped", "delivered", "exception"})

_lock = threading.Lock()
_catalog_cache: tuple[list[dict], dict[str, dict]] | None = None


def _utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _load_dropship_export():
    root = Path(__file__).resolve().parent.parent
    path = root / "scripts" / "dropship_order_export.py"
    spec = importlib.util.spec_from_file_location("dropship_order_export", path)
    if spec is None or spec.loader is None:
        raise ImportError("dropship_order_export.py not found")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _catalog_tracker() -> tuple[list[dict], dict[str, dict]]:
    global _catalog_cache
    if _catalog_cache is None:
        mod = _load_dropship_export()
        _catalog_cache = (mod.parse_catalog(), mod.parse_tracker())
    return _catalog_cache


def enrich_stripe_key(stripe_key: str) -> dict[str, Any]:
    """Merge catalog + tracker metadata for a dropship stripeKey."""
    catalog, tracker = _catalog_tracker()
    mod = _load_dropship_export()
    rows = mod.merge_rows(catalog, tracker, stripe_key=stripe_key)
    if not rows:
        return {}
    row = rows[0]
    checklist = str(row.get("order_checklist") or "").split(" | ")
    checklist = [c.strip() for c in checklist if c.strip()]
    return {
        "stripe_key": stripe_key,
        "product_id": row.get("product_id") or "",
        "product_name": row.get("product_name") or "",
        "retail_usd": row.get("retail_usd"),
        "supplier": row.get("supplier") or "",
        "supplier_url": row.get("supplier_url") or "",
        "channel": row.get("channel") or "",
        "build_type": row.get("build_type") or "",
        "lead_time": row.get("lead_time") or "",
        "supplier_cost_usd": row.get("supplier_cost_usd"),
        "checklist": checklist,
    }


def empty_queue() -> dict[str, Any]:
    return {"version": QUEUE_VERSION, "updated_at": _utc_now(), "orders": []}


def _validate_order(order: dict[str, Any]) -> None:
    if not isinstance(order.get("id"), str) or not order["id"]:
        raise ValueError("order id required")
    status = order.get("status", "pending")
    if status not in VALID_STATUSES:
        raise ValueError(f"invalid status: {status}")
    if not order.get("stripe_key"):
        raise ValueError("stripe_key required")


def load_queue(path: Path | None = None) -> dict[str, Any]:
    p = path or QUEUE_PATH
    if not p.is_file():
        return empty_queue()
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return empty_queue()
    if not isinstance(data, dict):
        return empty_queue()
    data.setdefault("version", QUEUE_VERSION)
    data.setdefault("orders", [])
    if not isinstance(data["orders"], list):
        data["orders"] = []
    return data


def save_queue(data: dict[str, Any], path: Path | None = None) -> None:
    p = path or QUEUE_PATH
    p.parent.mkdir(parents=True, exist_ok=True)
    data["version"] = QUEUE_VERSION
    data["updated_at"] = _utc_now()
    tmp = p.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    tmp.replace(p)


def format_ship_to_text(ship_to: dict[str, Any] | str) -> str:
    if isinstance(ship_to, str):
        return ship_to.strip()
    parts: list[str] = []
    name = str(ship_to.get("name") or "").strip()
    if name:
        parts.append(name)
    line1 = str(ship_to.get("line1") or ship_to.get("street") or "").strip()
    if line1:
        parts.append(line1)
    line2 = str(ship_to.get("line2") or "").strip()
    if line2:
        parts.append(line2)
    city = str(ship_to.get("city") or "").strip()
    state = str(ship_to.get("state") or ship_to.get("region") or "").strip()
    postal = str(ship_to.get("postal_code") or ship_to.get("zip") or "").strip()
    city_line = ", ".join(x for x in [city, f"{state} {postal}".strip()] if x)
    if city_line:
        parts.append(city_line)
    country = str(ship_to.get("country") or "").strip()
    if country and country.upper() not in ("US", "USA"):
        parts.append(country)
    return ", ".join(parts)


def _normalize_ship_to(raw: Any) -> dict[str, str]:
    if isinstance(raw, str):
        return {"name": "", "line1": raw.strip(), "line2": "", "city": "", "state": "", "postal_code": "", "country": "US"}
    if not isinstance(raw, dict):
        return {"name": "", "line1": "", "line2": "", "city": "", "state": "", "postal_code": "", "country": "US"}
    return {
        "name": str(raw.get("name") or "").strip(),
        "line1": str(raw.get("line1") or raw.get("street") or "").strip(),
        "line2": str(raw.get("line2") or "").strip(),
        "city": str(raw.get("city") or "").strip(),
        "state": str(raw.get("state") or raw.get("region") or "").strip(),
        "postal_code": str(raw.get("postal_code") or raw.get("zip") or "").strip(),
        "country": str(raw.get("country") or "US").strip() or "US",
    }


def _new_order_id() -> str:
    return f"ord_{uuid.uuid4().hex[:12]}"


def build_order(
    *,
    stripe_key: str,
    ship_to: Any = None,
    status: str = "pending",
    customer_email: str = "",
    stripe_session_id: str = "",
    stripe_payment_intent: str = "",
    notes: str = "",
    supplier_order_id: str = "",
    tracking_number: str = "",
    tracking_url: str = "",
) -> dict[str, Any]:
    if not re.fullmatch(r"ds\w+", stripe_key):
        raise ValueError(f"invalid dropship stripe_key: {stripe_key}")
    if status not in VALID_STATUSES:
        raise ValueError(f"invalid status: {status}")

    meta = enrich_stripe_key(stripe_key)
    if not meta:
        raise ValueError(f"unknown dropship stripe_key: {stripe_key}")

    ship = _normalize_ship_to(ship_to or {})
    now = _utc_now()
    order = {
        "id": _new_order_id(),
        "created_at": now,
        "updated_at": now,
        "status": status,
        "stripe_key": stripe_key,
        "stripe_session_id": stripe_session_id,
        "stripe_payment_intent": stripe_payment_intent,
        "customer_email": customer_email,
        "product_id": meta.get("product_id") or "",
        "product_name": meta.get("product_name") or "",
        "retail_usd": meta.get("retail_usd"),
        "supplier": meta.get("supplier") or "",
        "supplier_url": meta.get("supplier_url") or "",
        "channel": meta.get("channel") or "",
        "build_type": meta.get("build_type") or "",
        "lead_time": meta.get("lead_time") or "",
        "supplier_cost_usd": meta.get("supplier_cost_usd"),
        "checklist": meta.get("checklist") or [],
        "ship_to": ship,
        "ship_to_text": format_ship_to_text(ship),
        "supplier_order_id": supplier_order_id,
        "tracking_number": tracking_number,
        "tracking_url": tracking_url,
        "notes": notes,
    }
    _validate_order(order)
    return order


def add_order(order: dict[str, Any], path: Path | None = None) -> dict[str, Any]:
    _validate_order(order)
    with _lock:
        data = load_queue(path)
        for existing in data["orders"]:
            if existing.get("stripe_session_id") and existing.get("stripe_session_id") == order.get(
                "stripe_session_id"
            ):
                return existing
        data["orders"].append(order)
        save_queue(data, path)
    return order


def list_orders(
    *,
    status: str | None = None,
    pending_only: bool = False,
    path: Path | None = None,
) -> list[dict[str, Any]]:
    data = load_queue(path)
    orders = data.get("orders") or []
    if pending_only:
        orders = [o for o in orders if o.get("status") in ("pending", "ordered")]
    elif status:
        orders = [o for o in orders if o.get("status") == status]
    return sorted(orders, key=lambda o: o.get("created_at") or "", reverse=True)


def get_order(order_id: str, path: Path | None = None) -> Optional[dict[str, Any]]:
    data = load_queue(path)
    for order in data.get("orders") or []:
        if order.get("id") == order_id:
            return order
    return None


def update_order(
    order_id: str,
    updates: dict[str, Any],
    path: Path | None = None,
) -> Optional[dict[str, Any]]:
    allowed = {
        "status",
        "supplier_order_id",
        "tracking_number",
        "tracking_url",
        "notes",
        "ship_to",
        "ship_to_text",
    }
    with _lock:
        data = load_queue(path)
        for order in data.get("orders") or []:
            if order.get("id") != order_id:
                continue
            for key, value in updates.items():
                if key not in allowed:
                    continue
                if key == "status" and value not in VALID_STATUSES:
                    raise ValueError(f"invalid status: {value}")
                if key == "ship_to":
                    order["ship_to"] = _normalize_ship_to(value)
                    order["ship_to_text"] = format_ship_to_text(order["ship_to"])
                else:
                    order[key] = value
            order["updated_at"] = _utc_now()
            save_queue(data, path)
            return order
    return None


def _extract_stripe_key_from_session(session: dict[str, Any]) -> str:
    metadata = session.get("metadata") or {}
    for key in ("stripe_key", "stripeKey", "product_key", "sku"):
        val = str(metadata.get(key) or "").strip()
        if val.startswith("ds"):
            return val
    line_items = session.get("line_items") or {}
    if isinstance(line_items, dict):
        items = line_items.get("data") or []
    else:
        items = line_items if isinstance(line_items, list) else []
    for item in items:
        desc = str(item.get("description") or "").lower()
        price = item.get("price") or {}
        lookup = str(price.get("lookup_key") or "")
        if lookup.startswith("ds"):
            return lookup
        for match in re.findall(r"ds[A-Z]\w+", str(item.get("description") or "")):
            return match
    client_ref = str(session.get("client_reference_id") or "")
    if client_ref.startswith("ds"):
        return client_ref
    return ""


def _address_from_session(session: dict[str, Any]) -> dict[str, str]:
    details = session.get("customer_details") or {}
    shipping = session.get("shipping_details") or session.get("shipping") or {}
    addr = shipping.get("address") or details.get("address") or {}
    name = str(shipping.get("name") or details.get("name") or "").strip()
    return _normalize_ship_to(
        {
            "name": name,
            "line1": addr.get("line1"),
            "line2": addr.get("line2"),
            "city": addr.get("city"),
            "state": addr.get("state"),
            "postal_code": addr.get("postal_code"),
            "country": addr.get("country") or "US",
        }
    )


def order_from_stripe_session(session: dict[str, Any]) -> dict[str, Any]:
    stripe_key = _extract_stripe_key_from_session(session)
    if not stripe_key:
        raise ValueError("could not determine dropship stripe_key from Stripe session metadata")
    email = str((session.get("customer_details") or {}).get("email") or "").strip()
    return build_order(
        stripe_key=stripe_key,
        ship_to=_address_from_session(session),
        customer_email=email,
        stripe_session_id=str(session.get("id") or ""),
        stripe_payment_intent=str(session.get("payment_intent") or ""),
        notes=str((session.get("metadata") or {}).get("notes") or ""),
    )


def order_from_stripe_event(event: dict[str, Any]) -> dict[str, Any]:
    etype = str(event.get("type") or "")
    obj = (event.get("data") or {}).get("object") or {}
    if etype == "checkout.session.completed":
        return order_from_stripe_session(obj)
    if etype == "payment_intent.succeeded":
        metadata = obj.get("metadata") or {}
        stripe_key = str(metadata.get("stripe_key") or metadata.get("stripeKey") or "")
        if not stripe_key.startswith("ds"):
            raise ValueError("payment_intent missing dropship stripe_key metadata")
        return build_order(
            stripe_key=stripe_key,
            ship_to=_normalize_ship_to(metadata.get("ship_to") or metadata.get("ship_to_text") or ""),
            customer_email=str(metadata.get("email") or ""),
            stripe_payment_intent=str(obj.get("id") or ""),
            notes=str(metadata.get("notes") or ""),
        )
    raise ValueError(f"unsupported Stripe event type: {etype}")


def notify_fulfillment_event(
    event: str,
    order: dict[str, Any],
    webhook_url: str,
    *,
    timeout_sec: float = 5.0,
) -> bool:
    """POST minimal order summary to Discord/Slack/generic webhook. Never logs URL or payload."""
    url = (webhook_url or "").strip()
    if not url:
        return False
    payload = {
        "event": event,
        "order_id": order.get("id"),
        "product_name": order.get("product_name"),
        "stripe_key": order.get("stripe_key"),
        "status": order.get("status"),
        "supplier": order.get("supplier"),
        "retail_usd": order.get("retail_usd"),
    }
    body = json.dumps(payload).encode("utf-8")
    req = request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/json", "User-Agent": "CyberThreatGotchi-Fulfillment/1.0"},
        method="POST",
    )
    try:
        with request.urlopen(req, timeout=timeout_sec) as resp:
            return 200 <= resp.status < 300
    except (error.URLError, error.HTTPError, TimeoutError, OSError):
        return False


def operator_token_from_env(api_token: str = "") -> str:
    import os

    op = os.environ.get("CTG_OPERATOR_TOKEN", "").strip()
    if op:
        return op
    return api_token or os.environ.get("CTG_WEB_API_TOKEN", "").strip()
