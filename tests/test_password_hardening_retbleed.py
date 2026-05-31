"""Password hardening and RETBleed script asset tests."""

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


def test_harden_password_policy_ps1():
    script = WIN / "Harden-PasswordPolicy.ps1"
    assert script.is_file()
    text = script.read_text(encoding="utf-8")
    assert "DiagnoseOnly" in text
    assert "ApplyPolicy" in text
    assert "120" in text
    assert "lockoutthreshold" in text.lower() or "LockoutThreshold" in text
    assert "harden-password-policy.log" in text
    assert "DuckDuckGo" in text
    _parse_ps1(script)


def test_audit_autorun_integrates_password_policy():
    audit = WIN / "CTG-AuditAutorun.ps1"
    text = audit.read_text(encoding="utf-8")
    assert "Harden-PasswordPolicy.ps1" in text


def test_kali_retbleed_script():
    script = KALI / "fix-retbleed-mitigation.sh"
    assert script.is_file()
    body = script.read_text(encoding="utf-8")
    assert "authorized" in body.lower()
    assert "ctg-retbleed.log" in body
    assert "intel-microcode" in body
    assert "amd64-microcode" in body
    assert "mitigations=off" in body
    assert "--diagnose-only" in body
    assert "--apply" in body
    # Guest script must read the retbleed verdict and recommend the host spec-ctrl fix
    assert "analyze_and_recommend" in body
    assert "system/cpu/vulnerabilities" in body
    assert "--spec-ctrl on" in body


def test_harden_kali_vm_cpu_ps1():
    script = WIN / "Harden-KaliVmCpu.ps1"
    assert script.is_file()
    text = script.read_text(encoding="utf-8")
    assert "--spec-ctrl" in text
    assert "ibpb-on-vm-exit" in text
    assert "StopVmIfRunning" in text
    assert "DiagnoseOnly" in text
    # Must never force-poweroff; graceful ACPI only
    assert "acpipowerbutton" in text
    assert "harden-kali-vm-cpu.log" in text
    assert "SpectreControl" in text
    _parse_ps1(script)


def test_deploy_autopatch_applies_spec_ctrl():
    deploy = WIN / "Deploy-KaliBootAutopatch.ps1"
    text = deploy.read_text(encoding="utf-8")
    assert "Set-CtgSpecCtrlHardening" in text
    assert "--spec-ctrl" in text
    assert "NoSpecCtrlHardening" in text
    _parse_ps1(deploy)


def test_retbleed_docs_spec_ctrl():
    ret = ROOT / "docs" / "KALI_RETBLEED.md"
    text = ret.read_text(encoding="utf-8")
    assert "--spec-ctrl on" in text
    assert "Harden-KaliVmCpu.ps1" in text
    assert "IA32_SPEC_CTRL" in text
    assert "i9-8950HK" in text or "Coffee Lake" in text


def test_kali_password_policy_script():
    script = KALI / "harden-password-policy.sh"
    assert script.is_file()
    body = script.read_text(encoding="utf-8")
    assert "faillock" in body
    assert "deny = 10" in body or "deny=${DENY}" in body
    assert "unlock_time = 1800" in body or "UNLOCK_TIME=1800" in body
    assert "chage" in body
    assert "PasswordAuthentication" in body
    assert "ctg-password-policy.log" in body


def test_kali_boot_autopatch_retbleed_integration():
    autopatch = KALI / "kali-boot-autopatch.sh"
    body = autopatch.read_text(encoding="utf-8")
    assert "fix-retbleed-mitigation.sh" in body
    assert "--retbleed" in body
    assert "run_retbleed_mitigation" in body


def test_kali_bootstrap_password_policy():
    bootstrap = KALI / "kali-lab-bootstrap.sh"
    assert "harden-password-policy.sh" in bootstrap.read_text(encoding="utf-8")


def test_password_hardening_docs():
    pwd = ROOT / "docs" / "PASSWORD_HARDENING.md"
    ret = ROOT / "docs" / "KALI_RETBLEED.md"
    assert pwd.is_file()
    assert ret.is_file()
    pwd_text = pwd.read_text(encoding="utf-8")
    assert "DuckDuckGo Password Manager" in pwd_text
    assert "IPHONE_HARDENING.md" in pwd_text
    assert "120" in pwd_text
    assert "Harden-PasswordPolicy.ps1" in pwd_text
    assert "harden-password-policy.sh" in pwd_text
    ret_text = ret.read_text(encoding="utf-8")
    assert "VirtualBox" in ret_text
    assert "mitigations=off" in ret_text
    assert "ctg-retbleed.log" in ret_text


def test_professor_cybersec_rule():
    rule = ROOT / ".cursor" / "rules" / "andy-professor-cybersec.mdc"
    assert rule.is_file()
    text = rule.read_text(encoding="utf-8")
    assert "professor" in text.lower()
    assert "authorized" in text.lower()
    assert "DuckDuckGo" in text
