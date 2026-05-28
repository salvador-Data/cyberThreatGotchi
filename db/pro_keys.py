"""Provisioned CTG Pro API keys (Stripe customers, manual grants)."""

from __future__ import annotations

import secrets
import sqlite3
import threading
from contextlib import contextmanager
from pathlib import Path
from typing import Generator, Optional


class ProKeyStore:
    def __init__(self, db_path: Path) -> None:
        self.db_path = Path(db_path)
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
                CREATE TABLE IF NOT EXISTS pro_keys (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    api_key TEXT NOT NULL UNIQUE,
                    customer_id TEXT NOT NULL,
                    email TEXT,
                    active INTEGER NOT NULL DEFAULT 1,
                    created_at TEXT NOT NULL,
                    revoked_at TEXT
                );
                CREATE INDEX IF NOT EXISTS idx_pro_keys_key ON pro_keys(api_key);
                CREATE INDEX IF NOT EXISTS idx_pro_keys_customer ON pro_keys(customer_id);
                """
            )

    @staticmethod
    def generate_key() -> str:
        return "ctg_pro_" + secrets.token_urlsafe(24)

    def provision(self, customer_id: str, email: str = "") -> str:
        key = self.generate_key()
        from db.logger import ThreatLogger

        ts = ThreatLogger.utc_now()
        with self._lock, self._conn() as conn:
            conn.execute(
                """
                INSERT INTO pro_keys (api_key, customer_id, email, active, created_at)
                VALUES (?, ?, ?, 1, ?)
                """,
                (key, customer_id, email, ts),
            )
        return key

    def is_active(self, api_key: str) -> bool:
        with self._lock, self._conn() as conn:
            row = conn.execute(
                "SELECT active FROM pro_keys WHERE api_key = ?", (api_key,)
            ).fetchone()
        return bool(row and row["active"])

    def revoke(self, api_key: str) -> bool:
        from db.logger import ThreatLogger

        ts = ThreatLogger.utc_now()
        with self._lock, self._conn() as conn:
            cur = conn.execute(
                "UPDATE pro_keys SET active = 0, revoked_at = ? WHERE api_key = ?",
                (ts, api_key),
            )
        return cur.rowcount > 0

    def find_by_customer(self, customer_id: str) -> Optional[str]:
        with self._lock, self._conn() as conn:
            row = conn.execute(
                """
                SELECT api_key FROM pro_keys
                WHERE customer_id = ? AND active = 1
                ORDER BY id DESC LIMIT 1
                """,
                (customer_id,),
            ).fetchone()
        return row["api_key"] if row else None
