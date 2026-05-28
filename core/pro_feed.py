"""Pro threat intelligence feed — signatures, YARA, hashes for subscribers."""

from __future__ import annotations

import hashlib
import os
from datetime import datetime, timezone
from pathlib import Path

from config.settings import HASH_DB_PATH, PROJECT_ROOT, RULES_DIR
from rules.signatures import SIGNATURES

PRO_RULES_DIR = RULES_DIR / "pro"
PRO_YARA = PRO_RULES_DIR / "pro_rules.yar"


def _feed_version() -> str:
    parts = [
        str(PRO_YARA.stat().st_mtime if PRO_YARA.is_file() else 0),
        str(HASH_DB_PATH.stat().st_mtime if HASH_DB_PATH.is_file() else 0),
    ]
    return hashlib.sha256("".join(parts).encode()).hexdigest()[:12]


def build_signatures_payload() -> dict:
    return {
        "feed": "ctg-pro-signatures",
        "version": _feed_version(),
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "signatures": [
            {
                "sid": s.sid,
                "name": s.name,
                "category": s.category,
                "severity": s.severity,
                "score": s.score,
                "description": s.description,
                "pattern": s.pattern.pattern,
            }
            for s in SIGNATURES
        ],
        "pro_signatures": _load_pro_signatures(),
    }


def _load_pro_signatures() -> list[dict]:
    path = PRO_RULES_DIR / "extra_signatures.json"
    if not path.is_file():
        return []
    import json

    return json.loads(path.read_text(encoding="utf-8"))


def build_yara_payload() -> dict:
    chunks: dict[str, str] = {}
    for path in (RULES_DIR / "custom_rules.yar", PRO_YARA):
        if path.is_file():
            chunks[path.name] = path.read_text(encoding="utf-8")
    return {
        "feed": "ctg-pro-yara",
        "version": _feed_version(),
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "rules": chunks,
    }


def build_hashes_payload() -> dict:
    lines: list[str] = []
    if HASH_DB_PATH.is_file():
        for line in HASH_DB_PATH.read_text(encoding="utf-8").splitlines():
            h = line.strip().split("#")[0].strip()
            if len(h) >= 32:
                lines.append(h)
    pro_path = PRO_RULES_DIR / "pro_hashes.txt"
    if pro_path.is_file():
        for line in pro_path.read_text(encoding="utf-8").splitlines():
            h = line.strip().split("#")[0].strip()
            if len(h) >= 32:
                lines.append(h)
    return {
        "feed": "ctg-pro-hashes",
        "version": _feed_version(),
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "sha256_deny_list": sorted(set(lines)),
    }


def validate_pro_key(provided: str) -> bool:
    expected = os.environ.get("CTG_PRO_API_KEY", "").strip()
    if not expected:
        # Demo mode — accept key "demo" when no key configured
        return provided == "demo"
    return provided == expected
