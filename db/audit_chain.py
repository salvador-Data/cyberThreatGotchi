"""Tamper-evident hash chain for threat audit exports."""

from __future__ import annotations

import hashlib
import hmac
import json
import sqlite3
import threading
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Generator

GENESIS = "CTG-GENESIS-HACKER-PLANET-LLC"


class AuditChain:
    def __init__(self, db_path: Path, secret: str = "") -> None:
        self.db_path = Path(db_path)
        self.secret = secret.strip()
        self._lock = threading.Lock()
        self._init_schema()

    @contextmanager
    def _conn(self) -> Generator[sqlite3.Connection, None, None]:
        conn = sqlite3.connect(self.db_path, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
            conn.commit()
        finally:
            conn.close()

    def _init_schema(self) -> None:
        with self._lock, self._conn() as conn:
            conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS audit_chain (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    event_type TEXT NOT NULL,
                    payload TEXT NOT NULL,
                    prev_hash TEXT NOT NULL,
                    record_hash TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS idx_audit_id ON audit_chain(id);
                """
            )

    def _last_hash(self, conn: sqlite3.Connection) -> str:
        row = conn.execute(
            "SELECT record_hash FROM audit_chain ORDER BY id DESC LIMIT 1"
        ).fetchone()
        return row["record_hash"] if row else GENESIS

    @staticmethod
    def _compute(prev: str, payload: dict[str, Any]) -> str:
        blob = prev + "|" + json.dumps(payload, sort_keys=True, default=str)
        return hashlib.sha256(blob.encode()).hexdigest()

    def append(self, event_type: str, payload: dict[str, Any], timestamp: str) -> str:
        with self._lock, self._conn() as conn:
            prev = self._last_hash(conn)
            record_hash = self._compute(prev, payload)
            conn.execute(
                """
                INSERT INTO audit_chain (timestamp, event_type, payload, prev_hash, record_hash)
                VALUES (?, ?, ?, ?, ?)
                """,
                (timestamp, event_type, json.dumps(payload), prev, record_hash),
            )
            return record_hash

    def export_chain(self, limit: int = 500) -> dict[str, Any]:
        with self._lock, self._conn() as conn:
            rows = conn.execute(
                "SELECT * FROM audit_chain ORDER BY id DESC LIMIT ?", (limit,)
            ).fetchall()
        chain = [dict(r) for r in reversed(rows)]
        body = {"genesis": GENESIS, "chain": chain, "count": len(chain)}
        if self.secret:
            sig = hmac.new(
                self.secret.encode(),
                json.dumps(body, sort_keys=True).encode(),
                hashlib.sha256,
            ).hexdigest()
            body["hmac_sha256"] = sig
        return body

    def verify_chain(self) -> tuple[bool, str]:
        with self._lock, self._conn() as conn:
            rows = conn.execute("SELECT * FROM audit_chain ORDER BY id ASC").fetchall()
        prev = GENESIS
        for row in rows:
            payload = json.loads(row["payload"])
            expected = self._compute(prev, payload)
            if row["prev_hash"] != prev or row["record_hash"] != expected:
                return False, f"break at id={row['id']}"
            prev = row["record_hash"]
        return True, "ok"
