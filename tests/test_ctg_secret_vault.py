"""Tests for CTG DPAPI secret vault scripts (fake secrets in temp dir only)."""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
WIN = ROOT / "scripts" / "windows"

VAULT_SCRIPTS = (
    "Protect-CtgSecrets.ps1",
    "Redact-CtgPiiInText.ps1",
    "Register-CtgSecretRotationReminder.ps1",
    "Invoke-CtgSecretRotationSms.ps1",
)

FAKE_USER = "ctg_test_user"
FAKE_PASSWORD = "ctg_fake_password_for_pytest_only"
FAKE_PHONE = "+15555550123"
FAKE_EMAIL = "ctg.fake.lab@example.com"
FAKE_NAME = "CTG Lab Test User"
FAKE_SECRET_NAMES = ("KALI_SSH_USER", "KALI_SSH_PASSWORD")
PII_NAMES = (
    "CTG_PII_FULL_NAME",
    "CTG_PII_EMAIL",
    "CTG_PII_PHONE",
    "CTG_PII_ADDRESS",
    "CTG_PII_SSN_LAST4",
)


def _normalize_pii_phone(value: str) -> str:
    digits = re.sub(r"\D", "", value)
    if value.strip().startswith("+") and digits:
        return f"+{digits}"
    return digits


def _pii_hash_hex(name: str, value: str) -> str:
    if name == "CTG_PII_PHONE":
        normalized = _normalize_pii_phone(value)
    elif name in ("CTG_PII_FULL_NAME", "CTG_PII_ADDRESS"):
        normalized = re.sub(r"\s+", " ", value.strip()).lower()
    elif name == "CTG_PII_EMAIL":
        normalized = value.strip().lower()
    elif name == "CTG_PII_SSN_LAST4":
        normalized = re.sub(r"\D", "", value)[-4:]
    else:
        normalized = value.strip()
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


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


def _run_vault_ps1(vault_path: Path, *args: str) -> subprocess.CompletedProcess[str]:
    script = WIN / "Protect-CtgSecrets.ps1"
    cmd = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(script),
        "-VaultPath",
        str(vault_path),
        *args,
    ]
    return subprocess.run(cmd, capture_output=True, text=True, timeout=60)


def _run_redact_ps1(vault_path: Path, text: str) -> subprocess.CompletedProcess[str]:
    script = WIN / "Redact-CtgPiiInText.ps1"
    cmd = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(script),
        "-VaultPath",
        str(vault_path),
        "-Text",
        text,
    ]
    return subprocess.run(cmd, capture_output=True, text=True, timeout=60)


@pytest.fixture
def temp_vault_file() -> Path:
    with tempfile.TemporaryDirectory() as tmp:
        yield Path(tmp) / "secrets.dpapi"


def test_vault_scripts_exist():
    for name in VAULT_SCRIPTS:
        assert (WIN / name).is_file(), name


def test_vault_scripts_parse():
    for name in VAULT_SCRIPTS:
        _parse_ps1(WIN / name)


def test_repo_scripts_contain_no_real_lab_passwords():
    """Static scan: no pasted chat credentials in tracked script/doc content."""
    patterns = (
        r"(?i)password\s*[:=]\s*['\"][^'\"]{6,}['\"]",
        r"-pw\s+['\"][^'\"]+['\"]",
    )
    scan_paths = [
        WIN / "Protect-CtgSecrets.ps1",
        WIN / "Deploy-KaliLab.ps1",
        WIN / "Invoke-CtgSecretRotationSms.ps1",
        ROOT / "docs" / "SECRET_VAULT.md",
    ]
    for path in scan_paths:
        text = path.read_text(encoding="utf-8")
        for pat in patterns:
            assert not re.search(pat, text), f"suspicious credential pattern in {path.name}"


def test_gitignore_excludes_vault():
    gi = (ROOT / ".gitignore").read_text(encoding="utf-8")
    assert ".vault/" in gi
    assert "*.hash" in gi


def test_secret_vault_doc_documents_pii_keys():
    doc = (ROOT / "docs" / "SECRET_VAULT.md").read_text(encoding="utf-8")
    for name in PII_NAMES:
        assert name in doc
    assert "Redact-CtgPiiInText.ps1" in doc
    assert "UseSecretVault" in doc


def test_protect_script_declares_pii_commands():
    script = (WIN / "Protect-CtgSecrets.ps1").read_text(encoding="utf-8")
    for flag in ("SetPii", "GetPii", "SetPiiHash", "Get-CtgPiiForScript", "Redact-CtgPiiInText"):
        assert flag in script


def test_send_sms_supports_secret_vault():
    sms = (WIN / "Send-CtgSmsAlert.ps1").read_text(encoding="utf-8")
    assert "UseSecretVault" in sms
    assert "Get-CtgPiiForScript" in sms
    assert "CTG_PII_PHONE" in sms


def test_no_pii_rule_exists():
    rule = ROOT / ".cursor" / "rules" / "no-pii-in-repo.mdc"
    assert rule.is_file()
    text = rule.read_text(encoding="utf-8")
    assert "CTG_PII_PHONE" in text
    assert "gitignored" in text.lower()


def test_deploy_kali_supports_secret_vault():
    deploy = (WIN / "Deploy-KaliLab.ps1").read_text(encoding="utf-8")
    assert "UseSecretVault" in deploy
    assert "Protect-CtgSecrets.ps1" in deploy
    assert "Get-CtgKaliCredentialsFromVault" in deploy
    assert "'sal'" not in deploy


def test_rotation_sms_message_has_no_secret_placeholders():
    runner = (WIN / "Invoke-CtgSecretRotationSms.ps1").read_text(encoding="utf-8")
    assert "CTG: rotate lab passwords" in runner
    assert "KALI_SSH_PASSWORD" not in runner
    assert "-GetSecret" not in runner


def test_secret_vault_doc_links_password_hardening():
    doc = (ROOT / "docs" / "SECRET_VAULT.md").read_text(encoding="utf-8")
    assert "PASSWORD_HARDENING.md" in doc
    assert "DuckDuckGo Password Manager" in doc
    assert "never SMS secrets" in doc.lower() or "never sms secrets" in doc.lower()
    assert "Why not hash passwords" in doc
    assert "SetSecretHash" in doc


def test_cpu_performance_doc_no_embedded_secrets():
    doc = (ROOT / "docs" / "CPU_PERFORMANCE.md").read_text(encoding="utf-8")
    assert "Why not hash" in doc
    assert "Interactive" in doc
    assert "Register-CtgCpuOptimizeTask.ps1" in doc
    assert "Run-AsAdmin.ps1" in doc
    for pat in (r"(?i)password\s*[:=]\s*['\"][^'\"]{6,}['\"]", r"sha256\s*[:=]\s*['\"][a-f0-9]{32,}['\"]"):
        assert not re.search(pat, doc), "suspicious credential/hash in CPU_PERFORMANCE.md"


def test_register_cpu_task_uses_interactive_not_password():
    reg = (WIN / "Register-CtgCpuOptimizeTask.ps1").read_text(encoding="utf-8")
    assert "LogonType Interactive" in reg
    assert "SetSecretHash" not in reg
    assert "SHA256" not in reg.upper()
    assert "Protect-CtgSecrets" not in reg or "does NOT require" in reg


@pytest.mark.skipif(shutil.which("powershell") is None, reason="powershell not available")
def test_secret_hash_roundtrip_in_temp_vault(temp_vault_file: Path):
    vault = temp_vault_file
    r1 = _run_vault_ps1(
        vault,
        "-SetSecretHash",
        "-Name",
        "KALI_SSH_PASSWORD",
        "-Value",
        FAKE_PASSWORD,
    )
    assert r1.returncode == 0, r1.stderr or r1.stdout

    r2 = _run_vault_ps1(
        vault,
        "-TestSecretHash",
        "-Name",
        "KALI_SSH_PASSWORD",
        "-Value",
        FAKE_PASSWORD,
    )
    assert r2.returncode == 0, r2.stderr or r2.stdout

    r3 = _run_vault_ps1(
        vault,
        "-TestSecretHash",
        "-Name",
        "KALI_SSH_PASSWORD",
        "-Value",
        "wrong_password_for_pytest",
    )
    assert r3.returncode != 0

    raw = vault.read_bytes()
    assert FAKE_PASSWORD.encode() not in raw
    assert b"KALI_SSH_PASSWORD_HASH" not in raw

    r4 = _run_vault_ps1(vault, "-ListSecrets")
    assert r4.returncode == 0
    assert "KALI_SSH_PASSWORD_HASH" in r4.stdout


@pytest.mark.skipif(shutil.which("powershell") is None, reason="powershell not available")
def test_dpapi_roundtrip_in_temp_vault(temp_vault_file: Path):
    vault = temp_vault_file
    r1 = _run_vault_ps1(
        vault,
        "-SetSecret",
        "-Name",
        "KALI_SSH_USER",
        "-Value",
        FAKE_USER,
    )
    assert r1.returncode == 0, r1.stderr or r1.stdout

    r2 = _run_vault_ps1(
        vault,
        "-SetSecret",
        "-Name",
        "KALI_SSH_PASSWORD",
        "-Value",
        FAKE_PASSWORD,
    )
    assert r2.returncode == 0, r2.stderr or r2.stdout

    r3 = _run_vault_ps1(vault, "-GetSecret", "-Name", "KALI_SSH_USER")
    assert r3.returncode == 0
    assert r3.stdout.strip() == FAKE_USER

    r4 = _run_vault_ps1(vault, "-GetSecret", "-Name", "KALI_SSH_PASSWORD")
    assert r4.returncode == 0
    assert r4.stdout.strip() == FAKE_PASSWORD

    assert vault.is_file()
    raw = vault.read_bytes()
    assert FAKE_USER.encode() not in raw
    assert FAKE_PASSWORD.encode() not in raw

    r5 = _run_vault_ps1(vault, "-ListSecrets")
    assert r5.returncode == 0
    for name in FAKE_SECRET_NAMES:
        assert name in r5.stdout

    r6 = _run_vault_ps1(vault, "-RemoveSecret", "-Name", "KALI_SSH_PASSWORD")
    assert r6.returncode == 0

    r7 = _run_vault_ps1(vault, "-GetSecret", "-Name", "KALI_SSH_PASSWORD")
    assert r7.returncode != 0


@pytest.mark.skipif(shutil.which("powershell") is None, reason="powershell not available")
def test_pii_roundtrip_and_hash_sidecar(temp_vault_file: Path):
    vault = temp_vault_file
    vault_dir = vault.parent

    r1 = _run_vault_ps1(
        vault,
        "-SetPii",
        "-Name",
        "CTG_PII_PHONE",
        "-Value",
        FAKE_PHONE,
    )
    assert r1.returncode == 0, r1.stderr or r1.stdout

    r2 = _run_vault_ps1(vault, "-GetPii", "-Name", "CTG_PII_PHONE")
    assert r2.returncode == 0
    assert r2.stdout.strip() == FAKE_PHONE

    sidecar = vault_dir / "CTG_PII_PHONE.hash"
    assert sidecar.is_file()
    assert sidecar.read_text(encoding="utf-8").strip() == _pii_hash_hex(
        "CTG_PII_PHONE", FAKE_PHONE
    )

    index_path = vault_dir / "pii-index.json"
    assert index_path.is_file()
    index = json.loads(index_path.read_text(encoding="utf-8"))
    assert index["CTG_PII_PHONE"]["tag"] == "phone"
    index_blob = index_path.read_text(encoding="utf-8")
    assert FAKE_PHONE not in index_blob

    raw = vault.read_bytes()
    assert FAKE_PHONE.encode() not in raw


@pytest.mark.skipif(shutil.which("powershell") is None, reason="powershell not available")
def test_pii_redaction_helper(temp_vault_file: Path):
    vault = temp_vault_file
    r_set = _run_vault_ps1(
        vault,
        "-SetPii",
        "-Name",
        "CTG_PII_EMAIL",
        "-Value",
        FAKE_EMAIL,
    )
    assert r_set.returncode == 0, r_set.stderr or r_set.stdout

    sample = f"Contact {FAKE_EMAIL} for SOC alert"
    r_redact = _run_redact_ps1(vault, sample)
    assert r_redact.returncode == 0, r_redact.stderr or r_redact.stdout
    assert FAKE_EMAIL not in r_redact.stdout
    assert "[REDACTED:email]" in r_redact.stdout


@pytest.mark.skipif(shutil.which("powershell") is None, reason="powershell not available")
def test_set_pii_hash_sidecar_without_plaintext_in_index(temp_vault_file: Path):
    vault = temp_vault_file
    vault_dir = vault.parent
    r = _run_vault_ps1(
        vault,
        "-SetPiiHash",
        "-Name",
        "CTG_PII_FULL_NAME",
        "-Value",
        FAKE_NAME,
    )
    assert r.returncode == 0, r.stderr or r.stdout
    sidecar = vault_dir / "CTG_PII_FULL_NAME.hash"
    assert sidecar.is_file()
    index_path = vault_dir / "pii-index.json"
    assert index_path.is_file()
    assert FAKE_NAME not in index_path.read_text(encoding="utf-8")
