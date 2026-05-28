"""Security utilities — headers, rate limits, constant-time auth, input validation."""

from __future__ import annotations

import hmac
import ipaddress
import re
import threading
import time
from collections import defaultdict
from functools import wraps
from typing import Any, Callable, Optional

from flask import Response, jsonify, request

# Allowed sprite mood path segments (path traversal guard)
ALLOWED_MOODS = frozenset(
    {"idle", "happy", "alert", "attack", "sleep", "feed", "defend", "sad", "critical"}
)

SECURITY_HEADERS = {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "Permissions-Policy": "geolocation=(), microphone=(), camera=()",
    "Content-Security-Policy": (
        "default-src 'self'; "
        "script-src 'self' 'unsafe-inline'; "
        "style-src 'self' 'unsafe-inline'; "
        "img-src 'self' data:; "
        "connect-src 'self'; "
        "frame-ancestors 'none'; "
        "base-uri 'self'; "
        "form-action 'self'"
    ),
}


def constant_time_equal(a: str, b: str) -> bool:
    return hmac.compare_digest(a.encode("utf-8"), b.encode("utf-8"))


def verify_bearer_or_header(provided: str, expected: str) -> bool:
    if not expected:
        return True
    if not provided:
        return False
    token = provided
    if provided.lower().startswith("bearer "):
        token = provided[7:].strip()
    return constant_time_equal(token, expected)


def sanitize_mood(mood: str) -> Optional[str]:
    cleaned = re.sub(r"[^a-zA-Z0-9_-]", "", mood or "")[:32].lower()
    return cleaned if cleaned in ALLOWED_MOODS else None


def sanitize_ip(value: str) -> str:
    try:
        return str(ipaddress.ip_address(value.strip()))
    except ValueError:
        return ""


class RateLimiter:
    """Simple in-memory sliding window rate limiter (per client IP)."""

    def __init__(self, max_calls: int = 60, window_sec: float = 60.0) -> None:
        self.max_calls = max_calls
        self.window_sec = window_sec
        self._hits: dict[str, list[float]] = defaultdict(list)
        self._lock = threading.Lock()

    def _client_key(self) -> str:
        forwarded = request.headers.get("X-Forwarded-For", "")
        if forwarded:
            return forwarded.split(",")[0].strip()
        return request.remote_addr or "unknown"

    def allow(self) -> bool:
        now = time.time()
        key = self._client_key()
        with self._lock:
            window = [t for t in self._hits[key] if now - t < self.window_sec]
            if len(window) >= self.max_calls:
                self._hits[key] = window
                return False
            window.append(now)
            self._hits[key] = window
            return True

    def retry_after(self) -> int:
        return int(self.window_sec)


def apply_security_headers(response: Response) -> Response:
    for name, value in SECURITY_HEADERS.items():
        response.headers[name] = value
    return response


def rate_limit(limiter: RateLimiter) -> Callable[..., Any]:
    def decorator(fn: Callable[..., Any]) -> Callable[..., Any]:
        @wraps(fn)
        def wrapper(*args: Any, **kwargs: Any) -> Any:
            if not limiter.allow():
                return jsonify({"error": "rate limit exceeded"}), 429
            return fn(*args, **kwargs)

        return wrapper

    return decorator


def require_api_token(expected: str) -> Callable[..., Any]:
    """Protect mutating routes when CTG_WEB_API_TOKEN is set."""

    def decorator(fn: Callable[..., Any]) -> Callable[..., Any]:
        @wraps(fn)
        def wrapper(*args: Any, **kwargs: Any) -> Any:
            if not expected:
                return fn(*args, **kwargs)
            header = request.headers.get("Authorization", "") or request.headers.get(
                "X-CTG-Api-Token", ""
            )
            if not verify_bearer_or_header(header, expected):
                return jsonify({"error": "unauthorized"}), 401
            return fn(*args, **kwargs)

        return wrapper

    return decorator


def verify_stripe_webhook(payload: bytes, sig_header: str, secret: str) -> bool:
    """Verify Stripe-Signature header (t=timestamp,v1=hex)."""
    if not secret or not sig_header:
        return False
    parts: dict[str, str] = {}
    for item in sig_header.split(","):
        if "=" in item:
            k, v = item.split("=", 1)
            parts[k.strip()] = v.strip()
    timestamp = parts.get("t", "")
    v1 = parts.get("v1", "")
    if not timestamp or not v1:
        return False
    signed = f"{timestamp}.".encode() + payload
    expected = hmac.new(secret.encode(), signed, "sha256").hexdigest()
    return constant_time_equal(v1, expected)
