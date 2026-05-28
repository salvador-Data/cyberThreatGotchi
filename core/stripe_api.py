"""Minimal Stripe REST client (stdlib only — no stripe package)."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

STRIPE_API = "https://api.stripe.com/v1"

DIGITAL_KEYS = frozenset({"digital", "codStlPack"})
SUBSCRIPTION_KEYS = frozenset({"proMonthly", "proYearly", "mspMonitor", "mspDefend", "mspHarden"})
DIRECT_SHIP_KEYS = frozenset(
    {
        "coreKit",
        "fieldPack",
        "cydStandard",
        "cydFieldCustom",
        "crackbotBench",
        "remotePossibility",
        "bleBot",
        "boostFormulaCod",
    }
)


def secret_key_from_env() -> str:
    return os.environ.get("CTG_STRIPE_SECRET_KEY", "").strip() or os.environ.get("STRIPE_SECRET_KEY", "").strip()


def stripe_request(
    method: str,
    path: str,
    *,
    secret: str,
    params: dict[str, Any] | None = None,
    form: dict[str, Any] | None = None,
    timeout: float = 60.0,
) -> dict[str, Any]:
    if not secret.startswith("sk_"):
        raise ValueError("Stripe secret key must start with sk_")

    url = f"{STRIPE_API}{path}"
    if params:
        query = urllib.parse.urlencode(_flatten_params(params), doseq=True)
        url = f"{url}?{query}"

    data = None
    headers = {"Authorization": f"Bearer {secret}"}
    if form is not None:
        data = urllib.parse.urlencode(_flatten_params(form), doseq=True).encode()
        headers["Content-Type"] = "application/x-www-form-urlencoded"

    req = urllib.request.Request(url, data=data, method=method.upper(), headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        body = exc.read().decode() if exc.fp else str(exc)
        raise RuntimeError(f"Stripe API {exc.code}: {body}") from exc


def _flatten_params(data: dict[str, Any], prefix: str = "") -> list[tuple[str, str]]:
    out: list[tuple[str, str]] = []
    for key, value in data.items():
        full = f"{prefix}[{key}]" if prefix else key
        if isinstance(value, dict):
            out.extend(_flatten_params(value, full))
        elif isinstance(value, list):
            for idx, item in enumerate(value):
                if isinstance(item, dict):
                    out.extend(_flatten_params(item, f"{full}[{idx}]"))
                else:
                    out.append((f"{full}[{idx}]", _stringify(item)))
        elif value is not None and value != "":
            out.append((full, _stringify(value)))
    return out


def _stringify(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def list_checkout_sessions(
    secret: str,
    *,
    limit: int = 25,
    created_gte: int | None = None,
    status: str = "complete",
) -> list[dict[str, Any]]:
    params: dict[str, Any] = {"limit": min(limit, 100), "status": status}
    if created_gte is not None:
        params["created"] = {"gte": created_gte}
    data = stripe_request("GET", "/checkout/sessions", secret=secret, params=params)
    return list(data.get("data") or [])


def retrieve_checkout_session(secret: str, session_id: str) -> dict[str, Any]:
    return stripe_request(
        "GET",
        f"/checkout/sessions/{session_id}",
        secret=secret,
        params={"expand[]": "line_items"},
    )


def needs_shipping(stripe_key: str) -> bool:
    if stripe_key in DIGITAL_KEYS or stripe_key in SUBSCRIPTION_KEYS:
        return False
    return stripe_key.startswith("ds") or stripe_key in DIRECT_SHIP_KEYS


def is_recurring(stripe_key: str, period: str) -> bool:
    return stripe_key in SUBSCRIPTION_KEYS or period in ("/month", "/year")


def recurring_interval(stripe_key: str, period: str) -> str:
    if period == "/year" or stripe_key == "proYearly":
        return "year"
    return "month"


def price_cents(price: float) -> int:
    return int(round(price * 100))
