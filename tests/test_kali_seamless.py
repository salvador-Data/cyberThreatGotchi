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
    assert "MiniToolBarAutoHide" in text
    assert "MiniToolBarAlignment" in text
    assert "AutoresizeGuest" in text
    assert "DisplayMode" in text
    assert "Get-CtgGuiExtradataSnapshot" in text
    assert "Set-CtgMiniToolbarExtradata" in text
    assert "Wait-CtgSeamlessFacilityStable" in text
    assert "Write-CtgGlitchRevertFix" in text
    assert "GUI/Scale' -Value 'false'" in text or "GUI/Scale', 'false'" in text
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
    assert "Scaled" in mode_body
    assert "AutoresizeGuest" in mode_body

    guest = KALI / "ctg-seamless-guest.sh"
    assert guest.is_file()
    guest_body = guest.read_text(encoding="utf-8")
    assert "VBoxClient" in guest_body
    assert "--vmsvga" in guest_body
    assert "autohide" in guest_body
    assert "gsettings" in guest_body or "gnome" in guest_body.lower()
    # Glitch-and-revert fixes: Wayland detection + clean VBoxClient restart + verify
    assert "XDG_SESSION_TYPE" in guest_body
    assert "wayland" in guest_body.lower()
    assert "WaylandEnable=false" in guest_body
    assert "restart_vboxclient" in guest_body
    assert "pkill" in guest_body
    assert "verify_seamless" in guest_body


def test_seamless_script_detects_glitch_revert():
    text = (WIN / "Start-KaliSeamless.ps1").read_text(encoding="utf-8")
    assert "GLITCH-REVERT" in text
    assert "ctg-seamless-guest.sh" in text


def test_stage_script_normalizes_sh_to_lf():
    stage = (WIN / "Stage-KaliLabToBackups.ps1").read_text(encoding="utf-8")
    assert "Copy-CtgGuestFile" in stage
    assert "`r`n" in stage or "\\r\\n" in stage

    autopatch = (KALI / "kali-boot-autopatch.sh").read_text(encoding="utf-8")
    assert "virtualbox-guest-x11" in autopatch
    assert "fix_virtualbox_seamless_guest" in autopatch
    assert "VBoxClient" in autopatch
    assert "ctg-seamless-guest" in autopatch

    autorun = (KALI / "ctg-lab-autorun.sh").read_text(encoding="utf-8")
    assert "Start-KaliSeamless.ps1" in autorun or "Host+L" in autorun


def test_display_scale_script_and_wiring():
    scale = KALI / "ctg-display-scale.sh"
    assert scale.is_file()
    body = scale.read_text(encoding="utf-8")
    assert "VBoxClient" in body
    assert "--vmsvga" in body or "--display" in body
    assert "xfconf-query" in body
    assert "/Xft/DPI" in body
    assert "xfce4-terminal" in body
    assert "--diagnose-only" in body
    assert "--fonts-only" in body
    assert "--fit-window" in body
    assert "--reset" in body
    assert "--aggressive" in body
    assert "Gtk/FontName" in body
    assert "gsettings" in body

    seamless = (KALI / "ctg-seamless-guest.sh").read_text(encoding="utf-8")
    assert "ctg-display-scale" in seamless

    autopatch = (KALI / "kali-boot-autopatch.sh").read_text(encoding="utf-8")
    assert "ctg-display-scale" in autopatch
    assert "--fit-window" in autopatch

    ps1 = (WIN / "Start-KaliSeamless.ps1").read_text(encoding="utf-8")
    assert "Clear-CtgBadGuestSizeHint" in ps1
    assert "LastGuestSizeHint" in ps1
    assert "AutoresizeGuest" in ps1
    assert "--fit-window" in ps1
    assert "setvideomodehint" in ps1
    assert "DisplayMode Gui" in ps1 or "-DisplayMode Gui" in ps1

    doc = ROOT / "docs" / "KALI_DISPLAY_SCALING.md"
    assert doc.is_file()
    doc_body = doc.read_text(encoding="utf-8")
    assert "ctg-display-scale.sh" in doc_body
    assert "--fit-window" in doc_body
    assert "--fonts-only" in doc_body
    assert "kali-boot-autopatch.sh" in doc_body
    assert "Symptom" in doc_body
    assert "pipeline" in doc_body.lower()

    stage = (WIN / "Stage-KaliLabToBackups.ps1").read_text(encoding="utf-8")
    assert "KALI_DISPLAY_SCALING.md" in stage
