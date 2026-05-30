"""Pure path/date helpers for CTG nightly 4 AM automation (testable without PowerShell)."""

from __future__ import annotations

from datetime import date
from pathlib import Path

SSD_DISK_NUMBER = 1
SSD_DRIVE = "D:"
MIN_FREE_GB = 5


def nightly_log_filename(when: date | None = None) -> str:
    d = when or date.today()
    return f"nightly-{d.isoformat()}.log"


def local_logs_dir(home: Path | None = None) -> Path:
    root = home or Path.home()
    return root / "Backups" / "logs"


def local_nightly_log_path(when: date | None = None, home: Path | None = None) -> Path:
    return local_logs_dir(home) / nightly_log_filename(when)


def ssd_logs_dir() -> Path:
    return Path(f"{SSD_DRIVE}/Backups/logs")


def ssd_backup_root(when: date | None = None) -> Path:
    d = when or date.today()
    return Path(f"{SSD_DRIVE}/Backups/Andy-PC-{d.isoformat()}")


def fallback_backup_root(when: date | None = None, home: Path | None = None) -> Path:
    d = when or date.today()
    root = home or Path.home()
    return root / "Backups" / f"Andy-PC-{d.isoformat()}"


SITE_PRIMARY_URL = "https://hackerplanet.dev/"
SITE_GITHUB_PAGES_URL = "https://salvador-Data.github.io/cyberThreatGotchi/"


def onedrive_backup_day(when: date | None = None, od_root: Path | None = None) -> Path:
    d = when or date.today()
    root = od_root or Path.home() / "OneDrive"
    return root / "Backups" / f"Andy-PC-{d.isoformat()}"


def onedrive_logs_dir(od_root: Path | None = None) -> Path:
    root = od_root or Path.home() / "OneDrive"
    return root / "Backups" / "logs"


def website_backup_dir(backup_root: Path) -> Path:
    return backup_root / "website"


def docs_web_backup_dir(backup_root: Path) -> Path:
    return backup_root / "docs-web"


def portfolio_backup_dir(backup_root: Path) -> Path:
    return backup_root / "portfolio"


def portfolio_export_dir(backup_root: Path) -> Path:
    return backup_root / "portfolio_export"


def desktop_soc_log(home: Path | None = None) -> Path:
    root = home or Path.home()
    return root / "Desktop" / "ctg-soc-run-log.txt"
