"""Kali VirtualBox seamless mode — repo asset checks (no VM required)."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WIN = ROOT / "scripts" / "windows"
KALI = ROOT / "scripts" / "kali"


def test_start_kali_seamless_script_exists():
    p = WIN / "Start-KaliSeamless.ps1"
    text = p.read_text(encoding="utf-8")
    assert p.is_file()
    assert "Hacker Planet" in text
    assert "--type seamless" in text or "GUI/Seamless" in text
    assert "DiagnoseOnly" in text
    assert "Get-CtgSeamlessDiagnostics" in text
    assert "LoggedInUsers" in text
    assert "Host+L" in text
    assert "Host+Home" in text
    assert "ShowMiniToolBar" in text
    assert "DisplayMode" in text
    assert "Get-CtgGuiExtradataSnapshot" in text
    assert "kali-seamless.log" in text
    assert "kali-boot-autopatch.sh" in text
    assert "NoShowHostToolbar" in text


def test_seamless_wired_in_lab_scripts():
    deploy = (WIN / "Deploy-KaliLab.ps1").read_text(encoding="utf-8")
    start = (WIN / "Start-CTGLab.ps1").read_text(encoding="utf-8")
    playground = (WIN / "CTG-Lab-Playground.ps1").read_text(encoding="utf-8")
    boot_autopatch = (WIN / "Deploy-KaliBootAutopatch.ps1").read_text(encoding="utf-8")
    assert "Start-KaliSeamless.ps1" in deploy
    assert "Start-KaliSeamless.ps1" in start
    assert "Start-KaliSeamless.ps1" in playground
    assert "Start-KaliSeamless.ps1" in boot_autopatch


def test_seamless_doc_and_autopatch_note():
    doc = ROOT / "docs" / "KALI_VIRTUALBOX_SEAMLESS.md"
    assert doc.is_file()
    body = doc.read_text(encoding="utf-8")
    assert "Start-KaliSeamless.ps1" in body
    assert "Host + L" in body or "Host+L" in body
    assert "virtualbox-guest-x11" in body
    assert "DiagnoseOnly" in body
    assert "KALI_SEAMLESS_MODE" in body

    mode_doc = ROOT / "docs" / "KALI_SEAMLESS_MODE.md"
    assert mode_doc.is_file()
    mode_body = mode_doc.read_text(encoding="utf-8")
    assert "ShowMiniToolBar" in mode_body
    assert "Host+Home" in mode_body or "Host + Home" in mode_body

    guest = KALI / "ctg-seamless-guest.sh"
    assert guest.is_file()
    assert "VBoxClient" in guest.read_text(encoding="utf-8")

    autopatch = (KALI / "kali-boot-autopatch.sh").read_text(encoding="utf-8")
    assert "virtualbox-guest-x11" in autopatch
    assert "fix_virtualbox_seamless_guest" in autopatch
    assert "VBoxClient" in autopatch
    assert "ctg-seamless-guest" in autopatch

    autorun = (KALI / "ctg-lab-autorun.sh").read_text(encoding="utf-8")
    assert "Start-KaliSeamless.ps1" in autorun or "Host+L" in autorun
