"""CTG Kali ctg-display-scale.sh — flag wiring and param checks (no VM required)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCALE = ROOT / "scripts" / "kali" / "ctg-display-scale.sh"


def _body() -> str:
    return SCALE.read_text(encoding="utf-8")


def test_display_scale_script_exists():
    assert SCALE.is_file()
    body = _body()
    assert "Hacker Planet" in body
    assert "--fit-window" in body
    assert "--text-medium" in body
    assert "--text-large" in body
    assert "--fonts-only" in body
    assert "--reset" in body
    assert "--aggressive" in body
    assert "--diagnose-only" in body
    assert "--login-scale" in body


def test_login_greeter_scale_gdm_and_dm_detect():
    body = _body()
    assert "fix_login_greeter_scale" in body
    assert "detect_ctg_display_manager" in body
    assert "greeter.dconf-defaults" in body
    assert "text-scaling-factor=1.25" in body or 'text-scaling-factor=${scale}' in body
    assert "CTG_LOGIN_TEXT_SCALE" in body
    assert "50-ctg-login-scale.conf" in body


def test_fit_window_is_default_mode():
    body = _body()
    assert re.search(r"FIT_WINDOW=true", body)
    assert 'APPLY_MODE="fit-window"' in body
    assert "apply_medium_text" in body


def test_never_force_oversized_resolution():
    body = _body()
    assert "downscale_oversized_xrandr" in body
    assert "2560" in body
    assert "1600" in body
    assert "largest" not in body.lower() or "never largest" in body.lower()


def test_fit_window_in_autostart_and_wiring():
    body = _body()
    assert "--fit-window" in body
    assert "ctg-display-scale.desktop" in body

    seamless = (ROOT / "scripts" / "kali" / "ctg-seamless-guest.sh").read_text(encoding="utf-8")
    assert "ctg-display-scale" in seamless
    assert "--fit-window" in seamless

    first_login = (ROOT / "scripts" / "kali" / "ctg-first-login-autorun.sh").read_text(encoding="utf-8")
    assert "--fit-window" in first_login

    autopatch = (ROOT / "scripts" / "kali" / "kali-boot-autopatch.sh").read_text(encoding="utf-8")
    assert "--fit-window" in autopatch
    assert "fix_login_greeter_scale" in autopatch
    assert "--login-scale" in autopatch
    assert "/etc/xdg/autostart/ctg-display-scale.desktop" in autopatch

    flash = (ROOT / "scripts" / "windows" / "Invoke-CtgKaliGuestFlash.ps1").read_text(encoding="utf-8")
    assert "--fit-window" in flash


def test_medium_text_defaults():
    body = _body()
    assert "apply_medium_text()" in body
    assert re.search(
        r"apply_medium_text\(\) \{.*?TARGET_DPI=108.*?GTK_FONT=\"Sans 11\".*?Monospace 12",
        body,
        re.DOTALL,
    )


def test_fit_window_uses_medium_no_narrow_bump():
    body = _body()
    fit = re.search(
        r"# fit-window \(default\):.*?log \"Fit-window",
        body,
        re.DOTALL,
    )
    assert fit
    block = fit.group(0)
    assert "apply_medium_text" in block
    assert "1400" not in block
    assert "TARGET_DPI=112" not in block
    assert "TARGET_DPI=120" not in block


def test_text_medium_mode_values():
    body = _body()
    assert "TEXT_MEDIUM=true" in body
    assert 'APPLY_MODE="text-medium"' in body
    assert re.search(
        r'if \$TEXT_MEDIUM.*?apply_medium_text',
        body,
        re.DOTALL,
    )


def test_text_large_mode_values():
    body = _body()
    assert re.search(
        r'if \$TEXT_LARGE.*?TARGET_DPI=120.*?GTK_FONT="Sans 13".*?Monospace 15',
        body,
        re.DOTALL,
    )


def test_system_autostart_when_root():
    body = _body()
    assert "/etc/xdg/autostart/ctg-display-scale.desktop" in body


def test_help_documents_all_flags():
    body = _body()
    for flag in (
        "--fit-window",
        "--text-medium",
        "--text-large",
        "--fonts-only",
        "--reset",
        "--aggressive",
        "--diagnose-only",
        "--login-scale",
    ):
        assert flag in body
