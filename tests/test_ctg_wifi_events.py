"""Tests for UTMS Wi-Fi event scripts and docs."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
WIN = ROOT / "scripts" / "windows"
KALI = ROOT / "scripts" / "kali"


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


def test_utms_wifi_docs_exist():
    for name in (
        "UTMS_WIFI_AI.md",
        "LAB_AP_UTMS.md",
        "CARDPUTER_UTMS_WIFI.md",
    ):
        assert (ROOT / "docs" / name).is_file(), name


def test_event_bus_modules_exist():
    assert (ROOT / "core" / "ctg_event_bus.py").is_file()
    assert (ROOT / "core" / "ctg_event_summarize.py").is_file()
    assert (ROOT / "scripts" / "utms_threat_pack.py").is_file()
    assert (ROOT / "scripts" / "utms" / "threat_pack.example.json").is_file()


@pytest.mark.parametrize(
    "name",
    [
        "Start-CtgEventBus.ps1",
        "Detect-CtgWifiJam.ps1",
        "Start-CtgUtmsThreatBroadcast.ps1",
    ],
)
def test_windows_event_scripts_parse(name: str):
    _parse_ps1(WIN / name)


def test_detect_wifi_jam_content():
    text = (WIN / "Detect-CtgWifiJam.ps1").read_text(encoding="utf-8")
    for needle in ("DiagnoseOnly", "Watch", "wifi.jam", "Send-CtgIdsAlert", "counter-jam"):
        assert needle in text, needle


def test_kali_wifi_event_scripts_content():
    deauth = (KALI / "ctg-deauth-watch.sh").read_text(encoding="utf-8")
    assert "wifi.deauth" in deauth
    assert "counter-jam" in deauth or "does not" in deauth.lower() or "detection" in deauth.lower()

    emit = (KALI / "ctg-wifi-event-emit.sh").read_text(encoding="utf-8")
    assert "rogue-ap-guard" in emit
    assert "wifi.rogue_ap" in emit

    lab_ap = (KALI / "ctg-lab-ap-setup.sh").read_text(encoding="utf-8")
    assert "i-understand-lab-only" in lab_ap
    assert "evil twin" in lab_ap.lower() or "NEVER" in lab_ap


def test_utms_threat_pack_cli():
    r = subprocess.run(
        ["python", str(ROOT / "scripts" / "utms_threat_pack.py"), "--print-digest"],
        capture_output=True,
        text=True,
        timeout=30,
        cwd=str(ROOT),
    )
    assert r.returncode == 0
    assert len(r.stdout.strip()) == 64


def test_defense_doc_links_utms():
    doc = (ROOT / "docs" / "DEFENSE_DDOS_ROGUE_WIFI.md").read_text(encoding="utf-8")
    assert "UTMS_WIFI_AI.md" in doc
    assert "Detect-CtgWifiJam.ps1" in doc
