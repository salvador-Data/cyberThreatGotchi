"""Pure path/date helpers for CTG audit autorun (testable without PowerShell)."""

from __future__ import annotations

from datetime import date, datetime
from pathlib import Path

SSD_DRIVE = "D:"
AUDIT_ROOT_NAME = "audit"

COMPARTMENTS = (
    "windows-security",
    "network-ids",
    "soc-ctg",
    "kali-bridge",
)

MANIFEST_FILENAME = "manifest.json"
AUTORUN_LOG_NAME = "ctg-audit-autorun.log"


def audit_base_dir(home: Path | None = None) -> Path:
    root = home or Path.home()
    return root / "Backups" / AUDIT_ROOT_NAME


def audit_run_dir(when: datetime | None = None, home: Path | None = None) -> Path:
    ts = when or datetime.now()
    day = ts.date().isoformat()
    run_id = ts.strftime("run-%H%M%S")
    return audit_base_dir(home) / day / run_id


def compartment_dir(
    compartment: str,
    when: datetime | None = None,
    home: Path | None = None,
) -> Path:
    if compartment not in COMPARTMENTS:
        raise ValueError(f"unknown compartment: {compartment}")
    return audit_run_dir(when, home) / compartment


def autorun_log_path(home: Path | None = None) -> Path:
    root = home or Path.home()
    return root / "Backups" / "logs" / AUTORUN_LOG_NAME


def manifest_path(when: datetime | None = None, home: Path | None = None) -> Path:
    return audit_run_dir(when, home) / MANIFEST_FILENAME


def ssd_audit_mirror_dir(when: datetime | None = None) -> Path:
    ts = when or datetime.now()
    day = ts.date().isoformat()
    run_id = ts.strftime("run-%H%M%S")
    return Path(f"{SSD_DRIVE}/Backups/audit") / day / run_id


def wireshark_alerts_path(home: Path | None = None) -> Path:
    root = home or Path.home()
    return root / "Backups" / "logs" / "wireshark-alerts.json"


def firewall_log_path(home: Path | None = None) -> Path:
    root = home or Path.home()
    return root / "Backups" / "logs" / "firewall.log"


def kali_bridge_share(home: Path | None = None) -> Path:
    """Placeholder path when Kali logs are synced via SMB share."""
    root = home or Path.home()
    return root / "Backups" / "kali-bridge"


def ctg_api_audit_url(port: int = 8765) -> str:
    return f"http://127.0.0.1:{port}/api/export/audit.json"


def ctg_api_threats_url(port: int = 8765) -> str:
    return f"http://127.0.0.1:{port}/api/export/threats.json"
