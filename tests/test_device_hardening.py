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
    WIN / "Enforce-CtgRamMitigations.ps1",
    WIN / "Enforce-CtgMemoryProtection.ps1",
    WIN / "Register-CtgRamMitigationTask.ps1",
    WIN / "Register-CtgMemoryProtectionTask.ps1",
    WIN / "Sync-CtgVulnerabilityFeeds.ps1",
    WIN / "Start-CtgIphoneTetherIds.ps1",
    WIN / "Invoke-CtgPreserveStackAudit.ps1",
    WIN / "Invoke-CtgPrintAllAudit.ps1",
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
    assert "Enforce-CtgRamMitigations" in text
    assert "Snort" in text or "IDS" in text
    assert "Send-CtgIdsAlert" not in text
    assert "Send-CtgSignalAlert" not in text


def test_ram_mitigation_enforcer_windows_script():
    text = (WIN / "Enforce-CtgRamMitigations.ps1").read_text(encoding="utf-8")
    for needle in (
        "DiagnoseOnly",
        "ApplySafe",
        "Monitor",
        "SpeculationControl",
        "RETBleed",
        "Memory integrity",
        "Credential Guard",
        "Kernel DMA",
        "Send-CtgIdsAlert",
        "Update-CtgExploitMitigations",
        "Harden-KaliVmCpu",
        "NOT network IPS",
        "NEVER disable",
    ):
        assert needle in text, needle
    assert "CTG_PII_PHONE" not in text


def test_register_ram_mitigation_task():
    text = (WIN / "Register-CtgRamMitigationTask.ps1").read_text(encoding="utf-8")
    assert "Enforce-CtgRamMitigations" in text
    assert "Interactive" in text
    assert "Highest" in text
    assert "-Monitor" in text


def test_kali_ram_mitigation_enforcer_shell():
    script = KALI / "ctg-ram-mitigation-enforcer.sh"
    assert script.is_file()
    body = script.read_text(encoding="utf-8")
    assert "authorized" in body.lower()
    assert "vulnerabilities" in body
    assert "retbleed" in body.lower() or "RETBleed" in body or "KALI_RETBLEED" in body
    assert "--apply-safe" in body
    assert "mitigations=auto" in body
    assert "--setup-cryptswap" in body
    assert "Snort" in body or "Suricata" in body
    assert "Vulnerable" in body


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
    assert "IPHONE_TETHER_MONITORING" in body
    assert not PHONE_PATTERN.search(body)


def test_iphone_tether_monitoring_doc():
    doc = ROOT / "docs" / "IPHONE_TETHER_MONITORING.md"
    assert doc.is_file()
    body = doc.read_text(encoding="utf-8")
    for needle in (
        "monitor tether egress",
        "YourHotspotSSID",
        "DuckDuckGo",
        "172.20.10",
        "BLE",
        "Cellular",
        "Start-CtgIphoneTetherIds",
    ):
        assert needle in body, needle
    assert "emulate" not in body.lower()
    assert "emulation" not in body.lower()
    assert not PHONE_PATTERN.search(body)


def test_iphone_tether_ids_script_honest_scope():
    script = WIN / "Start-CtgIphoneTetherIds.ps1"
    assert script.is_file()
    text = script.read_text(encoding="utf-8")
    for needle in (
        "DiagnoseOnly",
        "RunMinutes",
        "monitor tether egress",
        "iphone_tethering_privacy_checklist",
        "Start-CtgSuricataIDS",
        "Start-CtgSnortIDS",
        "HotspotSsidPattern",
        "172.20.10",
    ):
        assert needle in text, needle
    assert "emulate" not in text.lower()
    assert "Sal" not in text


def test_kali_tether_bridge_shell():
    script = KALI / "ctg-tether-bridge-ids.sh"
    assert script.is_file()
    body = script.read_text(encoding="utf-8")
    assert "authorized" in body.lower()
    assert "172.20.10" in body
    assert "emulate" in body.lower()
    assert "IPHONE_TETHER_MONITORING" in body


def test_sync_device_hardening_includes_tether():
    text = (PUBLISH / "Sync-CtgDeviceHardeningRepo.ps1").read_text(encoding="utf-8")
    assert "IPHONE_TETHER_MONITORING.md" in text
    assert "IPHONE_AUDIT_PRINT.md" in text
    assert "Start-CtgIphoneTetherIds.ps1" in text
    assert "ctg-tether-bridge-ids.sh" in text


def test_preserve_stack_audit_ddg_policy():
    text = (WIN / "Invoke-CtgPreserveStackAudit.ps1").read_text(encoding="utf-8")
    for needle in (
        "Preserve-DuckDuckGoVpn",
        "DdgBefore",
        "DdgAfter",
        "Repair-WindowsWifi",
        "DiagnoseOnly",
        "ctg-stack-audit",
    ):
        assert needle in text, needle
    assert "Cloudflare" not in text or "NOT install" in text or "no competing" in text.lower()


PRINT_ALL_DOCS = [
    "docs/print/README_PRINT_ALL.md",
    "docs/print/DUCKDUCKGO_PRESERVE_PRINT.md",
    "docs/print/KALI_LAB_AUDIT_PRINT.md",
    "docs/print/MEMORY_PROTECTION_AUDIT_PRINT.md",
    "docs/print/UTMS_WIFI_AUDIT_PRINT.md",
    "docs/print/LAB_MATURITY_AUDIT_PRINT.md",
    "docs/print/VAULT_SECRETS_AUDIT_PRINT.md",
    "docs/print/GITHUB_EMAIL_AUDIT_PRINT.md",
    "docs/print/PRINT_ALL_COMBINED.md",
    "docs/print/PRINT_ALL.html",
]


@pytest.mark.parametrize("rel_path", PRINT_ALL_DOCS)
def test_print_all_docs_exist_and_no_pii(rel_path: str):
    path = ROOT / rel_path.replace("/", "\\")
    assert path.is_file(), rel_path
    body = path.read_text(encoding="utf-8")
    assert not PHONE_PATTERN.search(body), f"PII phone in {rel_path}"
    assert not REAL_PHONE.search(body), f"E.164 phone in {rel_path}"
    assert "DuckDuckGo" in body or "DDG" in body or rel_path.endswith(".html")


def test_print_all_audit_script():
    text = (WIN / "Invoke-CtgPrintAllAudit.ps1").read_text(encoding="utf-8")
    for needle in (
        "Invoke-CtgPreserveStackAudit",
        "ctg-print-all-audit",
        "README_PRINT_ALL",
        "DUCKDUCKGO_PRESERVE_PRINT",
        "OpenPrintFolder",
    ):
        assert needle in text, needle
    assert "preserve DuckDuckGo" in text.lower() or "DuckDuckGo VPN/DNS" in text


def test_sync_device_hardening_includes_print_all():
    text = (PUBLISH / "Sync-CtgDeviceHardeningRepo.ps1").read_text(encoding="utf-8")
    assert "docs\\print\\README_PRINT_ALL.md" in text or "docs/print/README_PRINT_ALL.md" in text


def test_security_hardening_ids_ram_section():
    doc = ROOT / "docs" / "SECURITY_HARDENING.md"
    body = doc.read_text(encoding="utf-8")
    assert "IDS vs CPU side-channel" in body
    assert "RETBleed" in body
    assert "Update-CtgExploitMitigations" in body
    assert "Enforce-CtgRamMitigations" in body


def test_ram_mitigation_ips_doc():
    doc = ROOT / "docs" / "RAM_MITIGATION_IPS.md"
    assert doc.is_file()
    body = doc.read_text(encoding="utf-8")
    assert "cannot block" in body.lower() or "Not blocked" in body
    assert "RETBleed" in body
    assert "NIST CSF" in body
    assert "Intel SA-00702" in body or "SA-00702" in body
    assert "CIS Control 7" in body
    assert "ctg-device-hardening" in body
    assert "Enforce-CtgRamMitigations" in body
    assert not PHONE_PATTERN.search(body)
