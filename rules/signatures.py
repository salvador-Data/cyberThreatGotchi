"""Network and payload threat signatures."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class Signature:
    sid: str
    name: str
    category: str
    severity: str
    pattern: re.Pattern[str]
    score: int
    description: str


SIGNATURES: list[Signature] = [
    Signature(
        sid="SIG-001",
        name="SQL Injection Probe",
        category="web_attack",
        severity="high",
        pattern=re.compile(
            r"(union\s+select|or\s+1\s*=\s*1|drop\s+table|';--)",
            re.IGNORECASE,
        ),
        score=8,
        description="Possible SQL injection attempt in payload",
    ),
    Signature(
        sid="SIG-002",
        name="Shell Command Injection",
        category="rce",
        severity="critical",
        pattern=re.compile(
            r"(/bin/sh|/bin/bash|cmd\.exe|powershell\s+-)",
            re.IGNORECASE,
        ),
        score=9,
        description="Possible remote command execution payload",
    ),
    Signature(
        sid="SIG-003",
        name="Directory Traversal",
        category="path_traversal",
        severity="high",
        pattern=re.compile(r"(\.\./|\.\.\\|%2e%2e)", re.IGNORECASE),
        score=7,
        description="Path traversal pattern detected",
    ),
    Signature(
        sid="SIG-004",
        name="Cryptominer Stratum",
        category="malware",
        severity="medium",
        pattern=re.compile(r"(stratum\+tcp|xmrig|minergate)", re.IGNORECASE),
        score=6,
        description="Possible cryptomining C2 traffic",
    ),
    Signature(
        sid="SIG-005",
        name="Reverse Shell Beacon",
        category="c2",
        severity="critical",
        pattern=re.compile(
            r"(nc\s+-e|/dev/tcp/|bash\s+-i\s+>&)",
            re.IGNORECASE,
        ),
        score=10,
        description="Possible reverse shell establishment",
    ),
]

# Suspicious ports often used in scans and C2
SUSPICIOUS_PORTS = frozenset(
    {
        4444,
        5555,
        6666,
        6667,
        31337,
        12345,
        27374,
        1337,
        9001,
        3389,
        23,
        445,
        135,
        139,
    }
)

SCAN_THRESHOLD_PACKETS = 40
SCAN_WINDOW_SECONDS = 10


def match_payload(payload: str) -> list[Signature]:
    hits: list[Signature] = []
    for sig in SIGNATURES:
        if sig.pattern.search(payload):
            hits.append(sig)
    return hits


def is_suspicious_port(port: Optional[int]) -> bool:
    return port is not None and port in SUSPICIOUS_PORTS
