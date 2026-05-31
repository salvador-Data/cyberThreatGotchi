"""Tests for unified memory protection (Windows scripts, vault TTL, Kali enforcer)."""

from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
WIN = ROOT / "scripts" / "windows"
KALI = ROOT / "scripts" / "kali"


@pytest.fixture
def temp_vault_path() -> Path:
    with tempfile.TemporaryDirectory() as tmp:
        yield Path(tmp) / "credentials.vault"


@pytest.fixture
def vault_module():
    from core import ctg_vault as mod

    mod.lock_session()
    yield mod
    mod.lock_session()


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


MEMORY_PS1 = [
    WIN / "Enforce-CtgMemoryProtection.ps1",
    WIN / "Register-CtgMemoryProtectionTask.ps1",
]


@pytest.mark.parametrize("path", MEMORY_PS1, ids=lambda p: p.name)
def test_memory_protection_ps1_parse(path: Path):
    assert path.is_file(), path
    _parse_ps1(path)


def test_memory_protection_wrapper_delegates():
    text = (WIN / "Enforce-CtgMemoryProtection.ps1").read_text(encoding="utf-8")
    assert "Enforce-CtgRamMitigations.ps1" in text
    assert "DiagnoseOnly" in text
    assert "ApplySafe" in text
    assert "Monitor" in text


def test_register_memory_protection_task_delegates():
    text = (WIN / "Register-CtgMemoryProtectionTask.ps1").read_text(encoding="utf-8")
    assert "Register-CtgRamMitigationTask.ps1" in text
    assert "HackerPlanet-CTG-Memory-Protection" in text


def test_ram_enforcer_extended_diagnose_keywords():
    text = (WIN / "Enforce-CtgRamMitigations.ps1").read_text(encoding="utf-8")
    for needle in (
        "Get-CtgDeviceGuardReport",
        "Get-CtgKernelDmaProtectionStatus",
        "Get-CtgHypervisorVBoxLabNotes",
        "Credential Guard",
        "NEVER disable",
        "CTG_VAULT_SESSION_TTL",
        "MEMORY_PROTECTION.md",
        "nestedpaging",
    ):
        assert needle in text, needle


def test_kali_ram_enforcer_cryptswap_and_mlock():
    body = (KALI / "ctg-ram-mitigation-enforcer.sh").read_text(encoding="utf-8")
    assert "--setup-cryptswap" in body
    assert "mlock" in body
    assert "MEMORY_PROTECTION.md" in body
    assert "find" in body and "vuln_dir" in body


def test_kali_boot_autopatch_memory_diagnose():
    body = (KALI / "kali-boot-autopatch.sh").read_text(encoding="utf-8")
    assert "run_memory_protection_diagnose" in body
    assert "ctg-ram-mitigation-enforcer.sh" in body


def test_memory_protection_doc_exists():
    doc = ROOT / "docs" / "MEMORY_PROTECTION.md"
    assert doc.is_file()
    body = doc.read_text(encoding="utf-8")
    assert "snake oil" in body.lower()
    assert "learn.microsoft.com" in body
    assert "SA-00702" in body
    assert "cryptsetup" in body


def test_vault_session_ttl_env(vault_module, monkeypatch):
    monkeypatch.setenv("CTG_VAULT_SESSION_TTL", "120")
    assert vault_module.get_session_timeout_sec() == 120
    monkeypatch.delenv("CTG_VAULT_SESSION_TTL", raising=False)
    assert vault_module.get_session_timeout_sec() == 900


def test_vault_zero_bytearray(vault_module):
    buf = bytearray(b"secret-bytes")
    vault_module.zero_bytearray_best_effort(buf)
    assert buf == bytearray(len(buf))


def test_vault_status_includes_session_timeout(temp_vault_path, vault_module, monkeypatch):
    monkeypatch.setenv("CTG_VAULT_SESSION_TTL", "600")
    vault_module.init_vault("ctg_fake_master_password_pytest_only", temp_vault_path)
    st = vault_module.vault_status(temp_vault_path)
    assert st["session_timeout_sec"] == 600


def test_vault_get_credential_dict_zeros_buffer(temp_vault_path, vault_module):
    vault_module.init_vault("ctg_fake_master_password_pytest_only", temp_vault_path)
    vault_module.unlock_vault("ctg_fake_master_password_pytest_only", temp_vault_path)
    vault_module.add_credential("T", "u", "p")
    cred = vault_module.get_credential_dict("T")
    assert cred["password"] == "p"
