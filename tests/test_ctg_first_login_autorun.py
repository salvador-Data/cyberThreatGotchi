"""CTG Kali first-login zero-touch autorun — repo asset checks (no VM required)."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KALI = ROOT / "scripts" / "kali"
WIN = ROOT / "scripts" / "windows"


def test_first_login_autorun_scripts_exist():
    for name in (
        "ctg-first-login-autorun.sh",
        "ctg-first-login-autorun.desktop",
        "ctg-watch-trigger.sh",
        "ctg-enable-ssh.sh",
    ):
        p = KALI / name
        assert p.is_file(), name
        body = p.read_text(encoding="utf-8")
        assert "authorized" in body.lower() or "Hacker Planet" in body


def test_first_login_idempotent_flag_and_log():
    sh = (KALI / "ctg-first-login-autorun.sh").read_text(encoding="utf-8")
    assert "first-run-done" in sh
    assert "/var/log/ctg-first-login.log" in sh
    assert "CTG_FORCE_AUTORUN" in sh
    assert "--fit-window" in sh
    assert "RUN-KALI-LAB-NOW" in sh
    assert "ctg-retbleed-check" in sh


def test_watch_trigger_share_names():
    body = (KALI / "ctg-watch-trigger.sh").read_text(encoding="utf-8")
    assert "CTG_TRIGGER_AUTORUN" in body
    assert "CTG_RUN_AUTORUN_NOW" in body
    assert "/media/sf_ctg-backups" in body


def test_boot_autopatch_installs_first_login():
    body = (KALI / "kali-boot-autopatch.sh").read_text(encoding="utf-8")
    assert "install_first_login_autostart" in body
    assert "install_ctg_sudoers" in body
    assert "enable_openssh_server" in body
    assert "ctg-first-login-autorun.desktop" in body


def test_run_kali_lab_now_enables_ssh():
    body = (KALI / "RUN-KALI-LAB-NOW.sh").read_text(encoding="utf-8")
    assert "ctg-enable-ssh.sh" in body


def test_invoke_guest_flash_trigger_and_logged_in():
    ps1 = (WIN / "Invoke-CtgKaliGuestFlash.ps1").read_text(encoding="utf-8")
    assert "LoggedInUsers" in ps1
    assert "CTG_TRIGGER_AUTORUN" in ps1
    assert "TriggerOnly" in ps1
    assert "ctg-enable-ssh" in ps1
    assert "--fit-window" in ps1
    assert "guestcontrol probe" in ps1.lower() or "guestcontrol probe user" in ps1.lower()
    assert "'sal', 'kali'" in ps1 or "@('sal', 'kali'" in ps1


def test_enable_ssh_no_secrets_in_log():
    body = (KALI / "ctg-enable-ssh.sh").read_text(encoding="utf-8")
    assert "Password" not in body or "kali-vm-credentials" in body
    assert "openssh-server" in body
