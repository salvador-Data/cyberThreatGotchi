"""SQLite threat and gotchi event logger."""

from __future__ import annotations

import json
import sqlite3
import threading
from contextlib import contextmanager
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Generator, Iterable, Optional


@dataclass
class ThreatRecord:
    timestamp: str
    severity: str
    category: str
    source_ip: str
    dest_ip: str
    description: str
    score: int
    action_taken: str
    metadata: dict[str, Any]


@dataclass
class GotchiRecord:
    timestamp: str
    mood: str
    hunger: int
    happiness: int
    security_xp: int
    threats_blocked: int
    note: str


class ThreatLogger:
    def __init__(self, db_path: Path) -> None:
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
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
                CREATE TABLE IF NOT EXISTS threats (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    severity TEXT NOT NULL,
                    category TEXT NOT NULL,
                    source_ip TEXT,
                    dest_ip TEXT,
                    description TEXT,
                    score INTEGER,
                    action_taken TEXT,
                    metadata TEXT
                );
                CREATE TABLE IF NOT EXISTS gotchi_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    mood TEXT,
                    hunger INTEGER,
                    happiness INTEGER,
                    security_xp INTEGER,
                    threats_blocked INTEGER,
                    note TEXT
                );
                CREATE INDEX IF NOT EXISTS idx_threats_ts ON threats(timestamp);
                """
            )

    def log_threat(self, record: ThreatRecord) -> int:
        with self._lock, self._conn() as conn:
            cur = conn.execute(
                """
                INSERT INTO threats
                (timestamp, severity, category, source_ip, dest_ip,
                 description, score, action_taken, metadata)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    record.timestamp,
                    record.severity,
                    record.category,
                    record.source_ip,
                    record.dest_ip,
                    record.description,
                    record.score,
                    record.action_taken,
                    json.dumps(record.metadata),
                ),
            )
            return int(cur.lastrowid)

    def log_gotchi(self, record: GotchiRecord) -> int:
        with self._lock, self._conn() as conn:
            cur = conn.execute(
                """
                INSERT INTO gotchi_events
                (timestamp, mood, hunger, happiness, security_xp, threats_blocked, note)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    record.timestamp,
                    record.mood,
                    record.hunger,
                    record.happiness,
                    record.security_xp,
                    record.threats_blocked,
                    record.note,
                ),
            )
            return int(cur.lastrowid)

    def recent_threats(self, limit: int = 20) -> list[dict[str, Any]]:
        with self._lock, self._conn() as conn:
            rows = conn.execute(
                "SELECT * FROM threats ORDER BY id DESC LIMIT ?", (limit,)
            ).fetchall()
        return [dict(r) for r in rows]

    def threat_count(self) -> int:
        with self._lock, self._conn() as conn:
            row = conn.execute("SELECT COUNT(*) AS c FROM threats").fetchone()
        return int(row["c"]) if row else 0

    @staticmethod
    def utc_now() -> str:
        return datetime.now(timezone.utc).isoformat()
