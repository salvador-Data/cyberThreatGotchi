"""Tests for CTG encrypted credential vault (core/ctg_vault.py)."""

from __future__ import annotations

import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
WIN = ROOT / "scripts" / "windows"

FAKE_MASTER = "ctg_fake_master_password_pytest_only"
FAKE_MASTER_WRONG = "wrong_master_password_pytest"
FAKE_USER = "ctg_lab_user"
FAKE_PASSWORD = "ctg_fake_entry_password_pytest"
FAKE_TITLE = "Kali SSH Pytest"


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


def test_vault_cli_script_exists():
    assert (ROOT / "scripts" / "ctg_vault_cli.py").is_file()
    assert (WIN / "Ctg-CredentialVault.ps1").is_file()


def test_gitignore_excludes_credential_vault_files():
    gi = (ROOT / ".gitignore").read_text(encoding="utf-8")
    assert "*.vault" in gi or "credentials.vault" in gi
    assert ".vault/" in gi


def test_requirements_include_crypto_deps():
    req = (ROOT / "requirements.txt").read_text(encoding="utf-8")
    assert "cryptography" in req
    assert "argon2-cffi" in req


def test_init_unlock_add_get_roundtrip(temp_vault_path: Path, vault_module):
    vault_module.init_vault(FAKE_MASTER, temp_vault_path)
    assert temp_vault_path.is_file()
    raw = temp_vault_path.read_text(encoding="utf-8")
    assert FAKE_MASTER not in raw
    assert FAKE_PASSWORD not in raw

    vault_module.unlock_vault(FAKE_MASTER, temp_vault_path)
    entry = vault_module.add_credential(
        FAKE_TITLE,
        FAKE_USER,
        FAKE_PASSWORD,
        url="ssh://127.0.0.1:2222",
        tags=["lab", "kali"],
    )
    assert entry.title == FAKE_TITLE

    fetched = vault_module.get_credential(FAKE_TITLE)
    assert fetched.username == FAKE_USER
    assert fetched.password == FAKE_PASSWORD
    assert "kali" in fetched.tags

    titles = [item["title"] for item in vault_module.list_credentials()]
    assert FAKE_TITLE in titles


def test_wrong_master_password_fails(temp_vault_path: Path, vault_module):
    vault_module.init_vault(FAKE_MASTER, temp_vault_path)
    vault_module.lock_session()
    with pytest.raises(vault_module.VaultAuthError):
        vault_module.unlock_vault(FAKE_MASTER_WRONG, temp_vault_path)


def test_verify_master_password_constant_time_path(temp_vault_path: Path, vault_module):
    vault_module.init_vault(FAKE_MASTER, temp_vault_path)
    assert vault_module.verify_master_password(FAKE_MASTER, temp_vault_path) is True
    assert vault_module.verify_master_password(FAKE_MASTER_WRONG, temp_vault_path) is False


def test_constant_time_equal_helper(vault_module):
    assert vault_module.constant_time_equal("same", "same") is True
    assert vault_module.constant_time_equal("same", "diff") is False
    assert vault_module.constant_time_equal("", "") is True


def test_session_lock_and_expiry(temp_vault_path: Path, vault_module, monkeypatch):
    vault_module.init_vault(FAKE_MASTER, temp_vault_path)
    vault_module.unlock_vault(FAKE_MASTER, temp_vault_path)
    vault_module.add_credential(FAKE_TITLE, FAKE_USER, FAKE_PASSWORD)

    session = vault_module.get_active_session()
    session.unlocked_at = 0
    monkeypatch.setattr(vault_module, "SESSION_TIMEOUT_SEC", 1)

    with pytest.raises(vault_module.VaultLockedError):
        vault_module.get_active_session(timeout_sec=1)


def test_remove_and_set_credential(temp_vault_path: Path, vault_module):
    vault_module.init_vault(FAKE_MASTER, temp_vault_path)
    vault_module.unlock_vault(FAKE_MASTER, temp_vault_path)
    vault_module.add_credential(FAKE_TITLE, FAKE_USER, FAKE_PASSWORD)
    vault_module.set_credential(FAKE_TITLE, username="updated_user")
    updated = vault_module.get_credential(FAKE_TITLE)
    assert updated.username == "updated_user"
    vault_module.remove_credential(FAKE_TITLE)
    with pytest.raises(vault_module.CredentialNotFoundError):
        vault_module.get_credential(FAKE_TITLE)


def test_export_backup(temp_vault_path: Path, vault_module):
    vault_module.init_vault(FAKE_MASTER, temp_vault_path)
    backup_dir = temp_vault_path.parent / "backups"
    dest = vault_module.export_vault_backup(backup_dir, temp_vault_path)
    assert dest.is_file()
    assert dest.read_text(encoding="utf-8") == temp_vault_path.read_text(encoding="utf-8")


def test_import_from_csv(temp_vault_path: Path, vault_module):
    vault_module.init_vault(FAKE_MASTER, temp_vault_path)
    vault_module.unlock_vault(FAKE_MASTER, temp_vault_path)
    csv_path = temp_vault_path.parent / "import.csv"
    csv_path.write_text(
        "title,username,password,url,notes\n"
        "Router Admin,admin,local-only-pass,https://192.168.1.1,lab\n",
        encoding="utf-8",
    )
    added = vault_module.import_from_csv(csv_path)
    assert added == 1
    entry = vault_module.get_credential("Router Admin")
    assert entry.username == "admin"
    assert "local-only-pass" not in temp_vault_path.read_text(encoding="utf-8")


def test_vault_document_structure(temp_vault_path: Path, vault_module):
    vault_module.init_vault(FAKE_MASTER, temp_vault_path)
    doc = json.loads(temp_vault_path.read_text(encoding="utf-8"))
    assert doc["version"] == 1
    assert doc["kdf"]["name"] in ("argon2id", "scrypt")
    assert doc["cipher"]["name"] == "aes-256-gcm"
    assert "ciphertext" in doc


def test_cli_init_and_get(temp_vault_path: Path):
    cli = ROOT / "scripts" / "ctg_vault_cli.py"
    run_env = {**os.environ, "PYTHONPATH": str(ROOT)}
    init = subprocess.run(
        [sys.executable, str(cli), "init", "--vault-path", str(temp_vault_path)],
        input=FAKE_MASTER + "\n",
        capture_output=True,
        text=True,
        timeout=60,
        env=run_env,
    )
    assert init.returncode == 0, init.stderr
    unlock = subprocess.run(
        [sys.executable, str(cli), "unlock", "--vault-path", str(temp_vault_path)],
        input=FAKE_MASTER + "\n",
        capture_output=True,
        text=True,
        timeout=60,
        env=run_env,
    )
    assert unlock.returncode == 0, unlock.stderr
    add = subprocess.run(
        [
            sys.executable,
            str(cli),
            "add",
            "--vault-path",
            str(temp_vault_path),
            "--master-password",
            FAKE_MASTER,
            "--title",
            FAKE_TITLE,
            "--username",
            FAKE_USER,
        ],
        input=FAKE_PASSWORD + "\n",
        capture_output=True,
        text=True,
        timeout=60,
        env=run_env,
    )
    assert add.returncode == 0, add.stderr or add.stdout
    get = subprocess.run(
        [
            sys.executable,
            str(cli),
            "get",
            "--vault-path",
            str(temp_vault_path),
            "--master-password",
            FAKE_MASTER,
            "--title",
            FAKE_TITLE,
        ],
        capture_output=True,
        text=True,
        timeout=60,
        env=run_env,
    )
    assert get.returncode == 0, get.stderr
    payload = json.loads(get.stdout)
    assert payload["ok"] is True
    assert payload["credential"]["password"] == FAKE_PASSWORD


@pytest.mark.skipif(shutil.which("powershell") is None, reason="powershell not available")
def test_credential_vault_ps1_parses():
    script = WIN / "Ctg-CredentialVault.ps1"
    cmd = (
        f"$e=$null; $null=[System.Management.Automation.Language.Parser]::ParseFile("
        f"'{script}', [ref]$null, [ref]$e); if($e){{$e|ForEach-Object{{$_.ToString()}}; exit 1}}"
    )
    r = subprocess.run(
        ["powershell", "-NoProfile", "-Command", cmd],
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert r.returncode == 0, r.stdout + r.stderr


def test_secret_vault_doc_mentions_credential_vault():
    doc = (ROOT / "docs" / "SECRET_VAULT.md").read_text(encoding="utf-8")
    assert "Ctg-CredentialVault.ps1" in doc
    assert "Argon2id" in doc or "argon2id" in doc
    assert "AES-256-GCM" in doc


def test_repo_has_no_embedded_vault_passwords():
    patterns = (
        r"(?i)master.?password\s*[:=]\s*['\"][^'\"]{6,}['\"]",
    )
    scan_paths = [
        ROOT / "core" / "ctg_vault.py",
        WIN / "Ctg-CredentialVault.ps1",
        ROOT / "docs" / "SECRET_VAULT.md",
    ]
    for path in scan_paths:
        text = path.read_text(encoding="utf-8")
        for pat in patterns:
            assert not re.search(pat, text), f"suspicious pattern in {path.name}"
