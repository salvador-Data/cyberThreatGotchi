"""Tests for device hardening scripts (iPhone checklist, exploit mitigations, CVE feeds, private repos)."""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
WIN = ROOT / "scripts" / "windows"
IPHONE = ROOT / "scripts" / "iphone"
KALI = ROOT / "scripts" / "kali"
PUBLISH = ROOT / "scripts" / "publish"

PHONE_PATTERN = re.compile(r"2677730449|267[\-\.\s]?773[\-\.\s]?0449")
REAL_PHONE = re.compile(r"\+1[2-9]\d{9}")


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


NEW_PS1 = [
    IPHONE / "iphone_tethering_privacy_checklist.ps1",
    WIN / "Update-CtgExploitMitigations.ps1",
    WIN / "Sync-CtgVulnerabilityFeeds.ps1",
    PUBLISH / "Set-CtgPrivateRepos.ps1",
]


@pytest.mark.parametrize("path", NEW_PS1, ids=lambda p: p.name)
def test_device_hardening_ps1_parse(path: Path):
    assert path.is_file(), path
    _parse_ps1(path)


@pytest.mark.parametrize("path", NEW_PS1, ids=lambda p: p.name)
def test_no_pii_or_secrets_in_device_hardening_ps1(path: Path):
    text = path.read_text(encoding="utf-8")
    assert not PHONE_PATTERN.search(text), f"PII phone in {path.name}"
    assert not REAL_PHONE.search(text), f"E.164 phone in {path.name}"
    assert "TWILIO_AUTH_TOKEN=" not in text
    assert "CTG_PII_PHONE" not in text


def test_iphone_checklist_honest_scope():
    text = (IPHONE / "iphone_tethering_privacy_checklist.ps1").read_text(encoding="utf-8")
    for needle in (
        "ReadOnly",
        "DuckDuckGo",
        "Windows cannot rewrite iPhone MAC",
        "IPHONE_LAPTOP_CONNECTION",
        "DetectUsb",
        "VID_05AC",
    ):
        assert needle.lower() in text.lower() or needle in text, needle


def test_exploit_mitigations_windows_script():
    text = (WIN / "Update-CtgExploitMitigations.ps1").read_text(encoding="utf-8")
    assert "DiagnoseOnly" in text
    assert "ApplySafe" in text
    assert "USOClient" in text
    assert "Harden-KaliVmCpu" in text
    assert "Snort" in text or "IDS" in text
    assert "Send-CtgIdsAlert" not in text
    assert "Send-CtgSignalAlert" not in text


def test_kali_exploit_mitigations_shell():
    script = KALI / "ctg-exploit-mitigations-check.sh"
    assert script.is_file()
    body = script.read_text(encoding="utf-8")
    assert "authorized" in body.lower()
    assert "vulnerabilities" in body
    assert "retbleed" in body
    assert "--apply-safe" in body
    assert "Snort" in body or "Suricata" in body


def test_vulnerability_feeds_script():
    text = (WIN / "Sync-CtgVulnerabilityFeeds.ps1").read_text(encoding="utf-8")
    assert "cisa.gov" in text
    assert "ctg-cve-cache" in text
    assert "DiagnoseOnly" in text
    assert "auto-install" in text.lower() or "no auto-install" in text.lower()


def test_private_repos_allowlist_pattern():
    text = (PUBLISH / "Set-CtgPrivateRepos.ps1").read_text(encoding="utf-8")
    assert "CtgPrivateRepoAllowlist" in text
    assert "ctg-kali-lab" in text
    assert "ctg-windows-soc" in text
    assert "cyberThreatGotchi" in text
    assert "M5_OS-Cardputer" in text
    assert "DiagnoseOnly" in text


def test_iphone_laptop_connection_doc():
    doc = ROOT / "docs" / "IPHONE_LAPTOP_CONNECTION.md"
    assert doc.is_file()
    body = doc.read_text(encoding="utf-8")
    assert "cannot" in body.lower()
    assert "MAC" in body
    assert "DuckDuckGo" in body
    assert "Private Wi" in body
    assert not PHONE_PATTERN.search(body)


def test_security_hardening_ids_ram_section():
    doc = ROOT / "docs" / "SECURITY_HARDENING.md"
    body = doc.read_text(encoding="utf-8")
    assert "IDS vs CPU side-channel" in body
    assert "RETBleed" in body
    assert "Update-CtgExploitMitigations" in body
