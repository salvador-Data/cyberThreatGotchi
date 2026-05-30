"""Tests for CTG Windows nightly 4 AM scripts (parse + path helpers)."""

from __future__ import annotations

import importlib.util
import subprocess
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WIN = ROOT / "scripts" / "windows"

NIGHTLY_PS1 = (
    "ctg_nightly_4am.ps1",
    "ctg_website_nightly.ps1",
    "Register-CtgNightlyTask.ps1",
    "ctg_nightly_install.ps1",
)


def _parse_ps1(path: Path) -> None:
    cmd = (
        f"$e=$null; $null=[System.Management.Automation.Language.Parser]::ParseFile("
        f"'{path}', [ref]$null, [ref]$e); if($e){{$e|ForEach-Object{{$_.ToString()}}; exit 1}}"
    )
    r = subprocess.run(
        ["powershell", "-NoProfile", "-Command", cmd],
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert r.returncode == 0, f"{path.name} parse errors:\n{r.stdout}\n{r.stderr}"


def _load_paths():
    spec = importlib.util.spec_from_file_location("ctg_nightly_paths", WIN / "ctg_nightly_paths.py")
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def test_nightly_scripts_exist():
    for name in NIGHTLY_PS1:
        assert (WIN / name).is_file(), name


def test_nightly_scripts_parse():
    for name in NIGHTLY_PS1:
        _parse_ps1(WIN / name)


def test_ctg_nightly_paths_helpers():
    mod = _load_paths()
    d = date(2026, 5, 30)
    home = Path("C:/Users/Owner")
    backup = Path("D:/Backups/Andy-PC-2026-05-30")
    assert mod.nightly_log_filename(d) == "nightly-2026-05-30.log"
    assert mod.local_nightly_log_path(d, home) == home / "Backups" / "logs" / "nightly-2026-05-30.log"
    assert mod.ssd_backup_root(d) == Path("D:/Backups/Andy-PC-2026-05-30")
    assert mod.fallback_backup_root(d, home) == home / "Backups" / "Andy-PC-2026-05-30"
    assert mod.ssd_logs_dir() == Path("D:/Backups/logs")
    assert mod.website_backup_dir(backup) == backup / "website"
    assert mod.docs_web_backup_dir(backup) == backup / "docs-web"
    assert mod.SITE_PRIMARY_URL == "https://hackerplanet.dev/"


def test_nightly_orchestrator_backup_and_domain():
    orch = (WIN / "ctg_nightly_4am.ps1").read_text(encoding="utf-8")
    website = (WIN / "ctg_website_nightly.ps1").read_text(encoding="utf-8")
    assert "SSD: {0}" in orch or "SSD: online" in orch
    assert "mount_ssd_d.ps1" in orch
    assert "ctg_website_nightly.ps1" in orch
    assert "Copy-SocLogsToSsd" in orch
    assert "docs-web" in website
    assert "https://hackerplanet.dev/" in website
    assert "hackerplant" not in orch.lower()
    assert "hackerplant" not in website.lower()


def test_readme_documents_backup_matrix():
    readme = (WIN / "README_WINDOWS_SOC.md").read_text(encoding="utf-8")
    assert "Backup matrix" in readme
    assert "hackerplanet.dev" in readme
    assert "docs-web" in readme
