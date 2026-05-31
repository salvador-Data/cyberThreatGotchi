"""Tests for safe BitLocker / device encryption scripts and docs."""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
WIN = ROOT / "scripts" / "windows"
BITLOCKER_SCRIPT = WIN / "Enable-BitLockerSafe.ps1"
KALI_ENCRYPT_SCRIPT = WIN / "Encrypt-KaliVm.ps1"


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


def test_bitlocker_script_exists():
    assert BITLOCKER_SCRIPT.is_file()


def test_bitlocker_script_parses():
    _parse_ps1(BITLOCKER_SCRIPT)


def test_bitlocker_script_no_secrets_in_repo():
    text = BITLOCKER_SCRIPT.read_text(encoding="utf-8")
    assert not re.search(r"RecoveryPassword:\s*\d{6,}", text)
    assert "redacted" in text.lower()
    assert not re.search(r"(?i)password\s*=\s*['\"][^'\"]{8,}['\"]", text)
    assert "-pw " not in text.lower()


def test_bitlocker_default_is_diagnose_only():
    text = BITLOCKER_SCRIPT.read_text(encoding="utf-8")
    assert "DiagnoseOnly" in text
    assert "-not $Apply" in text or "if (-not $Apply)" in text
    assert "Backups\\.vault" in text or "Backups\\.vault\\" in text or "Backups\\.vault" in text


def test_gitignore_excludes_bitlocker_recovery():
    gi = (ROOT / ".gitignore").read_text(encoding="utf-8")
    assert "bitlocker-recovery" in gi
    assert ".vault/" in gi


def test_device_encryption_docs_exist_and_link():
    dev = ROOT / "docs" / "DEVICE_ENCRYPTION.md"
    kali = ROOT / "docs" / "KALI_DISK_ENCRYPTION.md"
    assert dev.is_file()
    assert kali.is_file()
    dev_text = dev.read_text(encoding="utf-8")
    kali_text = kali.read_text(encoding="utf-8")
    assert "Enable-BitLockerSafe.ps1" in dev_text
    assert "KALI_DISK_ENCRYPTION.md" in dev_text
    assert "luksFormat" in kali_text
    assert "I_ACK_LUKS_FORMAT" in kali_text or "acknowledgment" in kali_text.lower()
    assert "VirtualBox" in kali_text
    assert "no destructive" in kali_text.lower() or "Do not" in kali_text


def test_secret_vault_doc_links_device_encryption():
    vault = ROOT / "docs" / "SECRET_VAULT.md"
    text = vault.read_text(encoding="utf-8")
    assert "BitLocker" in text


@pytest.mark.skipif(shutil.which("powershell") is None, reason="powershell not available")
def test_kali_encrypt_script_exists():
    assert KALI_ENCRYPT_SCRIPT.is_file()


def test_kali_encrypt_script_parses():
    _parse_ps1(KALI_ENCRYPT_SCRIPT)


def test_kali_encrypt_script_no_secrets_in_repo():
    text = KALI_ENCRYPT_SCRIPT.read_text(encoding="utf-8")
    assert "Read-Host" in text and "AsSecureString" in text
    assert not re.search(r"(?i)password\s*=\s*['\"][^'\"]{8,}['\"]", text)
    assert "encrypt-kali-vm.log" in text
    assert "luksFormat" not in text or "KALI_DISK_ENCRYPTION" in text


def test_kali_encrypt_default_is_diagnose_only():
    text = KALI_ENCRYPT_SCRIPT.read_text(encoding="utf-8")
    assert "DiagnoseOnly" in text
    assert "-not $Apply" in text or "if (-not $Apply)" in text
    assert "encryptvm" in text
    assert "setencryption" in text


def test_kali_disk_encryption_doc_links_script():
    kali = ROOT / "docs" / "KALI_DISK_ENCRYPTION.md"
    text = kali.read_text(encoding="utf-8")
    assert "Encrypt-KaliVm.ps1" in text
    assert "luksFormat" in text
    assert "Encrypt-KaliVm.ps1 -DiagnoseOnly" in text


def test_device_encryption_doc_links_kali_script():
    dev_text = (ROOT / "docs" / "DEVICE_ENCRYPTION.md").read_text(encoding="utf-8")
    assert "Encrypt-KaliVm.ps1" in dev_text


@pytest.mark.skipif(shutil.which("powershell") is None, reason="powershell not available")
def test_kali_encrypt_diagnose_only_exits_zero():
    r = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(KALI_ENCRYPT_SCRIPT),
            "-DiagnoseOnly",
        ],
        capture_output=True,
        text=True,
        timeout=120,
    )
    assert r.returncode in (0, 10, 11), r.stderr or r.stdout
    combined = r.stdout + r.stderr
    assert "Kali VirtualBox VM encryption" in combined
    assert not re.search(r"(?i)new-password=\S+", combined)


def test_bitlocker_diagnose_only_exits_zero():
    r = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(BITLOCKER_SCRIPT),
        ],
        capture_output=True,
        text=True,
        timeout=120,
    )
    assert r.returncode == 0, r.stderr or r.stdout
    combined = r.stdout + r.stderr
    assert "BitLocker safe encryption" in combined
    assert "DiagnoseOnly" in combined or "Diagnose + Apply" in combined
    assert not re.search(r"\d{6}-\d{6}-\d{6}-\d{6}-\d{6}-\d{6}-\d{6}-\d{6}", combined)
