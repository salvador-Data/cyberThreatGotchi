"""Tests for Windows Snort IDS scripts (no real SMS or phone numbers in repo)."""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
WIN = ROOT / "scripts" / "windows"

SNORT_SCRIPTS = [
    "CTG-SnortCommon.ps1",
    "Install-CtgSnortWindows.ps1",
    "Start-CtgSnortIDS.ps1",
    "ctg_snort_ids_loop.ps1",
    "Register-CtgSnortIdsTask.ps1",
]

PHONE_PATTERN = re.compile(r"2677730449|267[\-\.\s]?773[\-\.\s]?0449")


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


def test_snort_ids_files_exist():
    for name in SNORT_SCRIPTS:
        assert (WIN / name).is_file(), name
    assert (ROOT / "docs" / "WINDOWS_SNORT_IDS_SMS.md").is_file()


@pytest.mark.parametrize("name", SNORT_SCRIPTS)
def test_snort_ps1_parse(name: str):
    _parse_ps1(WIN / name)


def test_no_phone_or_twilio_secrets_in_snort_scripts():
    for name in SNORT_SCRIPTS + ["Send-CtgSmsAlert.ps1"]:
        text = (WIN / name).read_text(encoding="utf-8")
        assert not PHONE_PATTERN.search(text), f"PII phone found in {name}"
        assert "TWILIO_AUTH_TOKEN=" not in text
        assert "2677730449" not in text


def test_install_script_flags():
    text = (WIN / "Install-CtgSnortWindows.ps1").read_text(encoding="utf-8")
    for needle in (
        "DiagnoseOnly",
        "InstallViaChocolatey",
        "ctg-snort",
        "Install-WiresharkNpcap.ps1",
        "UseWiresharkFallback",
        "snort.org",
    ):
        assert needle in text, needle


def test_start_script_flags_and_sms_format():
    text = (WIN / "Start-CtgSnortIDS.ps1").read_text(encoding="utf-8")
    for needle in (
        "DiagnoseOnly",
        "ApplyRules",
        "TestAlert",
        "CTG Snort:",
        "Send-CtgSmsAlert.ps1",
        "snort-sid-",
        "UseWiresharkFallback",
        "logs\\snort",
    ):
        assert needle in text, needle


def test_register_task_interactive_highest():
    text = (WIN / "Register-CtgSnortIdsTask.ps1").read_text(encoding="utf-8")
    assert "Interactive" in text
    assert "Highest" in text
    assert "AtLogOn" in text
    assert "HackerPlanet-CTG-Snort-IDS" in text
    assert "Password" not in text or "no password" in text.lower() or "no password in" in text.lower()


def test_snort_common_paths():
    text = (WIN / "CTG-SnortCommon.ps1").read_text(encoding="utf-8")
    assert "ctg-snort" in text
    assert "Parse-CtgSnortAlertLine" in text
    assert "CTG_ALERT_SMS_TO" not in text  # env only in Start/Send scripts


def test_doc_links_and_no_pii():
    doc = (ROOT / "docs" / "WINDOWS_SNORT_IDS_SMS.md").read_text(encoding="utf-8")
    assert "Start-CtgSnortIDS.ps1" in doc
    assert "CTG_ALERT_SMS_TO" in doc
    assert "+1XXXXXXXXXX" in doc
    assert not PHONE_PATTERN.search(doc)
    assert "2677730449" not in doc


def test_security_hardening_references_snort():
    sec = (ROOT / "docs" / "SECURITY_HARDENING.md").read_text(encoding="utf-8")
    assert "WINDOWS_SNORT_IDS_SMS.md" in sec


def test_parse_snort_alert_line_powershell_logic_matches_python():
    from scripts.wireshark_ids.analyze_traffic import parse_snort_log_text

    sample = (
        "** [1:1000001:1] ET SCAN NMAP SYN scan [**] "
        "[Classification: Attempted Information Leak] [Priority: 2] "
        "{TCP} 10.0.0.5:45678 -> 192.168.1.10:22"
    )
    alerts = parse_snort_log_text(sample)
    assert len(alerts) == 1
    assert alerts[0].severity in ("high", "critical")
    assert alerts[0].evidence["sid"] == "1000001"
