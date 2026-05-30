"""Tests for DDoS / rogue WiFi defense scripts."""

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


def test_ddos_defense_files_exist():
    assert (WIN / "Harden-DDoSRogueWifi.ps1").is_file()
    assert (KALI / "rogue-ap-guard.sh").is_file()
    assert (ROOT / "docs" / "DEFENSE_DDOS_ROGUE_WIFI.md").is_file()


def test_harden_ddos_rogue_wifi_ps1_parses():
    _parse_ps1(WIN / "Harden-DDoSRogueWifi.ps1")


def test_harden_ddos_script_content():
    text = (WIN / "Harden-DDoSRogueWifi.ps1").read_text(encoding="utf-8")
    for needle in (
        "DiagnoseOnly",
        "ApplyHardening",
        "StrictInbound",
        "Preserve-DuckDuckGoVpn",
        "AutoConnectOpenNetworks",
        "EnableMulticast",
        "harden-ddos-rogue.log",
        "firewall.log",
        "BlockInbound",
    ):
        assert needle in text, needle


def test_rogue_ap_guard_bash_content():
    text = (KALI / "rogue-ap-guard.sh").read_text(encoding="utf-8")
    assert "nmcli" in text
    assert "evil twin" in text.lower() or "evil-twin" in text
    assert "deauth" not in text.lower() or "do not" in text.lower()
    assert "CTG_KNOWN_SSIDS" in text


def test_defense_doc_links():
    doc = (ROOT / "docs" / "DEFENSE_DDOS_ROGUE_WIFI.md").read_text(encoding="utf-8")
    assert "IPHONE_HARDENING.md" in doc
    assert "Harden-DDoSRogueWifi.ps1" in doc
    assert "rogue-ap-guard.sh" in doc
    assert "ISP" in doc


def test_readme_and_harden_windows_reference_ddos():
    readme = (WIN / "README_WINDOWS_SOC.md").read_text(encoding="utf-8")
    harden = (WIN / "harden_windows.ps1").read_text(encoding="utf-8")
    assert "Harden-DDoSRogueWifi.ps1" in readme
    assert "DEFENSE_DDOS_ROGUE_WIFI.md" in readme
    assert "DDoSRogueWifiDiagnose" in harden
