"""Tests for Windows Suricata IDS scripts (no real SMS or phone numbers in repo)."""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
WIN = ROOT / "scripts" / "windows"
KALI = ROOT / "scripts" / "kali"

SURICATA_SCRIPTS = [
    "CTG-SuricataCommon.ps1",
    "Install-CtgSuricataWindows.ps1",
    "Start-CtgSuricataIDS.ps1",
    "Start-CtgKaliSuricataSmsBridge.ps1",
    "ctg_suricata_ids_loop.ps1",
    "Register-CtgSuricataIdsTask.ps1",
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


def test_suricata_ids_files_exist():
    for name in SURICATA_SCRIPTS:
        assert (WIN / name).is_file(), name
    assert (ROOT / "docs" / "FREE_IPS_SURICATA.md").is_file()
    assert (KALI / "ctg-suricata-ips-sms.sh").is_file()


@pytest.mark.parametrize("name", SURICATA_SCRIPTS)
def test_suricata_ps1_parse(name: str):
    _parse_ps1(WIN / name)


def test_no_phone_or_twilio_secrets_in_suricata_scripts():
    for name in SURICATA_SCRIPTS + ["Send-CtgSmsAlert.ps1"]:
        text = (WIN / name).read_text(encoding="utf-8")
        assert not PHONE_PATTERN.search(text), f"PII phone found in {name}"
        assert "TWILIO_AUTH_TOKEN=" not in text
        assert "2677730449" not in text


def test_install_script_flags():
    text = (WIN / "Install-CtgSuricataWindows.ps1").read_text(encoding="utf-8")
    for needle in (
        "DiagnoseOnly",
        "InstallViaWinget",
        "ctg-suricata",
        "suricata.io",
        "Start-CtgKaliSuricataSmsBridge.ps1",
    ):
        assert needle in text, needle


def test_start_script_flags_and_sms_format():
    text = (WIN / "Start-CtgSuricataIDS.ps1").read_text(encoding="utf-8")
    for needle in (
        "DiagnoseOnly",
        "ApplyRules",
        "TestAlert",
        "CTG Suricata:",
        "Send-CtgSmsAlert.ps1",
        "suricata-sid-",
        "UseKaliBridge",
        "BlockRepeatOffender",
        "logs\\suricata",
    ):
        assert needle in text, needle


def test_kali_bridge_script():
    text = (WIN / "Start-CtgKaliSuricataSmsBridge.ps1").read_text(encoding="utf-8")
    assert "kali-suricata" in text
    assert "suricata_eve_tail" in text
    assert "CTG Suricata/Kali:" in text


def test_register_task_interactive_highest():
    text = (WIN / "Register-CtgSuricataIdsTask.ps1").read_text(encoding="utf-8")
    assert "Interactive" in text
    assert "Highest" in text
    assert "AtLogOn" in text
    assert "HackerPlanet-CTG-Suricata-IDS" in text
    assert "Password" not in text or "no password" in text.lower()


def test_suricata_common_eve_parser():
    text = (WIN / "CTG-SuricataCommon.ps1").read_text(encoding="utf-8")
    assert "Parse-CtgSuricataEveLine" in text
    assert "ctg-suricata" in text
    assert "CTG_ALERT_SMS_TO" not in text


def test_doc_links_and_no_pii():
    doc = (ROOT / "docs" / "FREE_IPS_SURICATA.md").read_text(encoding="utf-8")
    assert "Start-CtgSuricataIDS.ps1" in doc
    assert "CTG_ALERT_SMS_TO" in doc
    assert "+1XXXXXXXXXX" in doc
    assert "Suricata" in doc
    assert "OPNsense" in doc
    assert not PHONE_PATTERN.search(doc)
    assert "2677730449" not in doc


def test_kali_stage_script_no_secrets():
    text = (KALI / "ctg-suricata-ips-sms.sh").read_text(encoding="utf-8")
    assert "suricata-eve.json" in text
    assert "Twilio" not in text or "never stage secrets" in text
    assert not PHONE_PATTERN.search(text)


def test_security_hardening_references_suricata():
    sec = (ROOT / "docs" / "SECURITY_HARDENING.md").read_text(encoding="utf-8")
    assert "FREE_IPS_SURICATA.md" in sec


def test_free_ips_doc_comparison_table():
    doc = (ROOT / "docs" / "FREE_IPS_SURICATA.md").read_text(encoding="utf-8")
    assert "Snort" in doc
    assert "Suricata" in doc
    assert "OPNsense" in doc
