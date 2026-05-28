"""Antivirus layer — ClamAV daemon, YARA rules, and hash deny-list."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from config.settings import CLAMAV_HOST, CLAMAV_PORT, HASH_DB_PATH, YARA_RULES_PATH


@dataclass
class AVResult:
    engine: str
    hit: bool
    detail: str
    score: int = 0


class AntivirusEngine:
    def __init__(
        self,
        yara_path: Path = YARA_RULES_PATH,
        hash_db_path: Path = HASH_DB_PATH,
    ) -> None:
        self.yara_path = Path(yara_path)
        self.hash_db_path = Path(hash_db_path)
        self._hash_db: set[str] = set()
        self._yara = None
        self._clam = None
        self._load_hash_db()
        self._init_yara()
        self._init_clamav()

    def _load_hash_db(self) -> None:
        self._hash_db.clear()
        if not self.hash_db_path.exists():
            self._seed_demo_hashes()
            return
        for line in self.hash_db_path.read_text(encoding="utf-8").splitlines():
            line = line.strip().split("#")[0].strip().lower()
            if line and len(line) >= 32:
                self._hash_db.add(line)

    def _seed_demo_hashes(self) -> None:
        """Demo known-bad hashes for simulation."""
        samples = [
            b"EICAR-STANDARD-ANTIVIRUS-TEST-FILE",
            b"CTG-DEMO-MALWARE-PAYLOAD",
        ]
        self.hash_db_path.parent.mkdir(parents=True, exist_ok=True)
        lines = []
        for sample in samples:
            h = hashlib.sha256(sample).hexdigest()
            self._hash_db.add(h)
            lines.append(f"{h}  # demo:{sample[:20].decode(errors='ignore')}")
        self.hash_db_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    def _init_yara(self) -> None:
        if not self.yara_path.exists():
            return
        try:
            import yara  # type: ignore

            self._yara = yara.compile(filepath=str(self.yara_path))
        except Exception:
            self._yara = None

    def _init_clamav(self) -> None:
        try:
            import pyclamd  # type: ignore

            self._clam = pyclamd.ClamdNetworkSocket(CLAMAV_HOST, CLAMAV_PORT)
            if not self._clam.ping():
                self._clam = None
        except Exception:
            self._clam = None

    def reload(self) -> None:
        self._load_hash_db()
        self._init_yara()
        self._init_clamav()

    def scan_payload(self, data: bytes) -> list[AVResult]:
        results: list[AVResult] = []
        if not data:
            return results

        sha = hashlib.sha256(data).hexdigest()
        if sha in self._hash_db:
            results.append(
                AVResult(
                    engine="hash_db",
                    hit=True,
                    detail=f"SHA256 deny-list match: {sha[:16]}...",
                    score=10,
                )
            )

        if self._yara:
            try:
                matches = self._yara.match(data=data)
                for m in matches:
                    results.append(
                        AVResult(
                            engine="yara",
                            hit=True,
                            detail=f"YARA:{m.rule}",
                            score=8,
                        )
                    )
            except Exception:
                pass

        if self._clam:
            try:
                scan = self._clam.scan_stream(data)
                if scan and scan.get("stream") == ("FOUND",):
                    sig = scan.get("stream", ("", "unknown"))[1] if isinstance(scan, dict) else "malware"
                    results.append(
                        AVResult(
                            engine="clamav",
                            hit=True,
                            detail=f"ClamAV:{sig}",
                            score=10,
                        )
                    )
            except Exception:
                pass
        else:
            # Offline heuristic when ClamAV unavailable
            text = data.decode("utf-8", errors="ignore").lower()
            if "eicar" in text or "ctg-demo-malware" in text:
                results.append(
                    AVResult(
                        engine="heuristic",
                        hit=True,
                        detail="Heuristic malware string",
                        score=7,
                    )
                )

        return results

    def status(self) -> dict[str, bool]:
        return {
            "hash_db": len(self._hash_db) > 0,
            "yara": self._yara is not None,
            "clamav": self._clam is not None,
        }
