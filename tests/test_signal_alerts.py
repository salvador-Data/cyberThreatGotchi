"""Tests for CTG Signal alert scripts (no real phone numbers or secrets in repo)."""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
WIN = ROOT / "scripts" / "windows"

SIGNAL_SCRIPTS = [
    "CTG-SignalCommon.ps1",
    "Send-CtgSignalAlert.ps1",
    "Send-CtgIdsAlert.ps1",
    "Install-CtgSignalCli.ps1",
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


def test_signal_alert_files_exist():
    for name in SIGNAL_SCRIPTS:
        assert (WIN / name).is_file(), name
    assert (ROOT / "docs" / "SIGNAL_ALERTS.md").is_file()


@pytest.mark.parametrize("name", SIGNAL_SCRIPTS)
def test_signal_ps1_parse(name: str):
    _parse_ps1(WIN / name)


def test_no_phone_or_secrets_in_signal_scripts():
    ids_scripts = [
        "Start-CtgSnortIDS.ps1",
        "Start-CtgSuricataIDS.ps1",
        "Start-CtgKaliSuricataSmsBridge.ps1",
    ]
    for name in SIGNAL_SCRIPTS + ids_scripts:
        text = (WIN / name).read_text(encoding="utf-8")
        assert not PHONE_PATTERN.search(text), f"PII phone found in {name}"
        assert "2677730449" not in text
        assert "TWILIO_AUTH_TOKEN=" not in text


def test_send_signal_alert_flags():
    text = (WIN / "Send-CtgSignalAlert.ps1").read_text(encoding="utf-8")
    for needle in (
        "TestMessage",
        "CTG_ALERT_SIGNAL_TO",
        "CTG_SIGNAL_CLI_PATH",
        "CTG: test alert",
        "UseSecretVault",
        "CTG_PII_PHONE",
        "15 min",
    ):
        assert needle in text, needle


def test_ids_alert_dispatcher_routes_signal():
    text = (WIN / "Send-CtgIdsAlert.ps1").read_text(encoding="utf-8")
    for needle in (
        "Send-CtgSignalAlert.ps1",
        "Send-CtgSmsAlert.ps1",
        "CTG_USE_TWILIO",
        "UseSignal",
        "UseTwilio",
        "Test-CtgSignalConfigured",
    ):
        assert needle in text, needle


def test_install_signal_cli_diagnose():
    text = (WIN / "Install-CtgSignalCli.ps1").read_text(encoding="utf-8")
    assert "DiagnoseOnly" in text
    assert "link" in text.lower()
    assert "CTG_ALERT_SIGNAL_TO" in text
    assert "+1XXXXXXXXXX" in text
    assert not PHONE_PATTERN.search(text)


def test_signal_common_helpers():
    text = (WIN / "CTG-SignalCommon.ps1").read_text(encoding="utf-8")
    for needle in (
        "Get-CtgSignalCliPath",
        "Get-CtgSignalConfigDir",
        "Test-CtgSignalConfigured",
        "Test-CtgUseTwilioPreferred",
        "Get-CtgAlertRatePath",
    ):
        assert needle in text, needle


def test_snort_ids_uses_ids_alert_dispatcher():
    text = (WIN / "Start-CtgSnortIDS.ps1").read_text(encoding="utf-8")
    assert "Send-CtgIdsAlert.ps1" in text
    assert "UseSignal" in text
    assert "sid" in text


def test_suricata_ids_uses_ids_alert_dispatcher():
    text = (WIN / "Start-CtgSuricataIDS.ps1").read_text(encoding="utf-8")
    assert "Send-CtgIdsAlert.ps1" in text
    assert "Test-CtgSignalConfigured" in text


def test_signal_alerts_doc_no_pii():
    doc = (ROOT / "docs" / "SIGNAL_ALERTS.md").read_text(encoding="utf-8")
    assert "Send-CtgSignalAlert.ps1" in doc
    assert "+1XXXXXXXXXX" in doc
    assert not PHONE_PATTERN.search(doc)
    assert "2677730449" not in doc


def test_windows_snort_doc_mentions_signal():
    doc = (ROOT / "docs" / "WINDOWS_SNORT_IDS_SMS.md").read_text(encoding="utf-8")
    assert "SIGNAL_ALERTS.md" in doc
    assert "Signal" in doc
