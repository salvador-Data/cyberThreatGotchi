"""Tests for CTG daily UTMS alert and iPhone timezone sync (no PII in repo)."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
WIN = ROOT / "scripts" / "windows"
IPHONE = ROOT / "scripts" / "iphone"

DAILY_UTMS_SCRIPTS = [
    "CTG-IphoneTimezoneCommon.ps1",
    "Update-CtgTimezoneFromIphone.ps1",
    "Send-CtgDailyUtmsAlert.ps1",
    "Invoke-CtgDailyUtmsAlertIfLocal6Am.ps1",
    "Register-CtgDailyUtmsAlertTask.ps1",
]

PHONE_PATTERN = re.compile(r"2677730449|267[\-\.\s]?773[\-\.\s]?0449")
IANA_PATTERN = re.compile(r"^[A-Za-z_]+(/[A-Za-z0-9_+\-]+)+$")


def _parse_ps1(path: Path) -> None:
    if shutil.which("powershell") is None:
        pytest.skip("powershell not available on this runner")
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


def test_daily_utms_script_files_exist():
    for name in DAILY_UTMS_SCRIPTS:
        assert (WIN / name).is_file(), name
    assert (ROOT / "docs" / "IPHONE_TIMEZONE_SYNC.md").is_file()
    assert (IPHONE / "shortcut-timezone-export.example.json").is_file()


@pytest.mark.parametrize("name", DAILY_UTMS_SCRIPTS)
def test_daily_utms_ps1_parse(name: str):
    _parse_ps1(WIN / name)


def test_no_pii_in_daily_utms_scripts():
    for name in DAILY_UTMS_SCRIPTS + ["Send-CtgIdsAlert.ps1"]:
        text = (WIN / name).read_text(encoding="utf-8")
        assert not PHONE_PATTERN.search(text), f"PII phone found in {name}"
        assert "2677730449" not in text
        assert "CTG_ALERT_SIGNAL_TO=+1" not in text


def test_timezone_json_example_valid_shape():
    data = json.loads((IPHONE / "shortcut-timezone-export.example.json").read_text(encoding="utf-8"))
    assert "shortcut_steps" in data
    assert "America/New_York" in data["example_timezone_values"]
    template = next(s for s in data["shortcut_steps"] if s["action"] == "Text")["template"]
    assert "timezone" in template
    assert "updated" in template


@pytest.mark.parametrize(
    "tz,valid",
    [
        ("America/New_York", True),
        ("Europe/London", True),
        ("Invalid Zone", False),
        ("", False),
        ("America", False),
    ],
)
def test_iana_timezone_pattern(tz: str, valid: bool):
    assert bool(IANA_PATTERN.match(tz)) is valid


def test_send_daily_utms_alert_flags():
    text = (WIN / "Send-CtgDailyUtmsAlert.ps1").read_text(encoding="utf-8")
    for needle in (
        "Send-CtgIdsAlert.ps1",
        "DiagnoseOnly",
        "WhatIf",
        "Update-CtgTimezoneFromIphone.ps1",
        "Gatekeeper",
        "Lab:target8-9",
        "daily-utms",
    ):
        assert needle in text, needle


def test_hourly_checker_uses_timezone_common():
    text = (WIN / "Invoke-CtgDailyUtmsAlertIfLocal6Am.ps1").read_text(encoding="utf-8")
    assert "CTG-IphoneTimezoneCommon.ps1" in text
    assert "Test-CtgIsLocalSixAmWindow" in text
    assert "Send-CtgDailyUtmsAlert.ps1" in text


def test_register_daily_utms_task_pattern():
    text = (WIN / "Register-CtgDailyUtmsAlertTask.ps1").read_text(encoding="utf-8")
    assert "HackerPlanet-CTG-Daily-Utms-6AM" in text
    assert "Interactive" in text
    assert "Highest" in text
    assert "Invoke-CtgDailyUtmsAlertIfLocal6Am.ps1" in text
    assert "RepetitionInterval" in text


def test_iphone_timezone_sync_doc_no_pii():
    doc = (ROOT / "docs" / "IPHONE_TIMEZONE_SYNC.md").read_text(encoding="utf-8")
    assert "IPHONE_TIMEZONE_SYNC" in doc or "timezone.json" in doc
    assert "Find My" in doc
    assert "cannot" in doc.lower() or "Cannot" in doc
    assert not PHONE_PATTERN.search(doc)


def test_one_working_mentions_daily_utms():
    text = (WIN / "Invoke-CtgOneWorking.ps1").read_text(encoding="utf-8")
    assert "Update-CtgTimezoneFromIphone.ps1" in text
    assert "daily UTMS" in text.lower() or "Daily UTMS" in text
