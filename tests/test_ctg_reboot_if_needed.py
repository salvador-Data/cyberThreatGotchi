"""CTG reboot helper — repo asset contract tests (no Kali VM required)."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_ctg_reboot_if_needed_script():
    script = ROOT / "scripts" / "kali" / "ctg-reboot-if-needed.sh"
    body = script.read_text(encoding="utf-8")
    assert script.is_file()
    assert "authorized" in body.lower()
    assert "--mark" in body
    assert "--mark-gdm" in body
    assert "--check" in body
    assert "--reboot" in body
    assert "--auto-reboot" in body
    assert "--no-reboot" in body
    assert "/var/run/ctg-reboot-required" in body
    assert "/var/run/reboot-required" in body
    assert "/var/log/ctg-reboot.log" in body
    assert "CTG_NO_REBOOT" in body
    assert 'shutdown -r +1' in body
    assert "CTG lab autorun complete" in body


def test_lab_autorun_auto_reboot_wiring():
    autorun = ROOT / "scripts" / "kali" / "ctg-lab-autorun.sh"
    body = autorun.read_text(encoding="utf-8")
    assert "ctg-reboot-if-needed" in body
    assert "--auto-reboot" in body
    assert "CTG_NO_REBOOT" in body
    assert "CTG_SKIP_AUTO_REBOOT=1" in body


def test_boot_autopatch_reboot_wiring():
    autopatch = ROOT / "scripts" / "kali" / "kali-boot-autopatch.sh"
    body = autopatch.read_text(encoding="utf-8")
    assert "ctg-reboot-if-needed" in body
    assert "--mark-gdm" in body
    assert "--auto-reboot" in body
    assert "CTG_SKIP_AUTO_REBOOT" in body


def test_wifi_lab_marks_reboot_after_dkms():
    wifi = ROOT / "scripts" / "kali" / "ctg-wifi-lab-autorun.sh"
    body = wifi.read_text(encoding="utf-8")
    assert "ctg_reboot_helper" in body
    assert "dkms_install" in body
    assert "--mark" in body


def test_deploy_and_start_stage_reboot_helper():
    deploy = ROOT / "scripts" / "windows" / "Deploy-KaliLab.ps1"
    start = ROOT / "scripts" / "windows" / "Start-CTGLab.ps1"
    assert "ctg-reboot-if-needed.sh" in deploy.read_text(encoding="utf-8")
    assert "ctg-reboot-if-needed.sh" in start.read_text(encoding="utf-8")


def test_ctg_lab_autorun_doc_reboot_section():
    doc = ROOT / "docs" / "CTG_LAB_AUTORUN.md"
    text = doc.read_text(encoding="utf-8")
    assert "ctg-reboot-if-needed.sh" in text
    assert "CTG_NO_REBOOT" in text
    assert "/var/log/ctg-reboot.log" in text


def test_wifi_promisc_doc_reboot():
    doc = ROOT / "docs" / "KALI_WIFI_ETH_PROMISC.md"
    text = doc.read_text(encoding="utf-8")
    assert "ctg-reboot-if-needed" in text
    assert "CTG_NO_REBOOT" in text
