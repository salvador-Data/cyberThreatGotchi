"""CTG Kali ctg-display-scale.sh — flag wiring and param checks (no VM required)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCALE = ROOT / "scripts" / "kali" / "ctg-display-scale.sh"
CURSOR_ASSETS = ROOT / "scripts" / "kali" / "assets" / "ctg-neon-cursor"


def _body() -> str:
    return SCALE.read_text(encoding="utf-8")


def test_display_scale_script_exists():
    assert SCALE.is_file()
    body = _body()
    assert "Hacker Planet" in body
    assert "--fit-window" in body
    assert "--text-medium" in body
    assert "--text-plus15" in body
    assert "--text-large" in body
    assert "--fonts-only" in body
    assert "--reset" in body
    assert "--aggressive" in body
    assert "--diagnose-only" in body
    assert "--login-scale" in body
    assert "--cursor-neon" in body


def test_medium_preset_constants():
    body = _body()
    assert "CTG_TEXT_MEDIUM_DPI=108" in body
    assert 'CTG_TEXT_MEDIUM_GTK="Sans 11"' in body
    assert 'CTG_TEXT_MEDIUM_TERM="Monospace 12"' in body
    assert "CTG_TEXT_MEDIUM_PANEL=30" in body
    assert "23258d4" in body


def test_login_greeter_scale_gdm_and_dm_detect():
    body = _body()
    assert "fix_login_greeter_scale" in body
    assert "detect_ctg_display_manager" in body
    assert "greeter.dconf-defaults" in body
    assert 'CTG_LOGIN_TEXT_SCALE="${CTG_LOGIN_TEXT_SCALE:-1.0}"' in body
    assert 'CTG_LIGHTDM_GREETER_FONT="${CTG_LIGHTDM_GREETER_FONT:-$CTG_TEXT_MEDIUM_GTK}"' in body
    assert "CTG_LOGIN_CURSOR_SIZE" in body
    assert "gdm_greeter_set_key" in body
    assert "font-name" in body
    assert "50-ctg-login-scale.conf" in body
    assert "compile_gdm_greeter_dconf" in body
    assert "/etc/dconf/db/gdm.d" in body
    assert "dconf update" in body
    assert "gdm3/Init/Default" in body
    assert "gdm3/PostSession/Default" in body
    assert "--greeter-session" in body
    assert "CTG_GREETER_REFRESH" in body
    assert "run_greeter_session_refresh" in body


def test_neon_cursor_assets_and_wiring():
    body = _body()
    assert "apply_cursor_neon" in body
    assert "CTG-Neon-Lemon" in body
    assert 'CTG_CURSOR_SIZE="${CTG_CURSOR_SIZE:-26}"' in body
    assert (CURSOR_ASSETS / "build-cursor-theme.sh").is_file()
    assert (CURSOR_ASSETS / "index.theme").is_file()
    assert (CURSOR_ASSETS / "gen-neon-cursor-png.py").is_file()


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
    assert "--cursor-neon" in body
    assert "ctg-display-scale.desktop" in body

    seamless = (ROOT / "scripts" / "kali" / "ctg-seamless-guest.sh").read_text(encoding="utf-8")
    assert "ctg-display-scale" in seamless
    assert "--fit-window" in seamless

    first_login = (ROOT / "scripts" / "kali" / "ctg-first-login-autorun.sh").read_text(encoding="utf-8")
    assert "--fit-window" in first_login
    assert "--cursor-neon" in first_login

    autopatch = (ROOT / "scripts" / "kali" / "kali-boot-autopatch.sh").read_text(encoding="utf-8")
    assert "--fit-window" in autopatch
    assert "--cursor-neon" in autopatch
    assert "fix_login_greeter_scale" in autopatch
    assert "--login-scale" in autopatch
    assert "/etc/xdg/autostart/ctg-display-scale.desktop" in autopatch

    flash = (ROOT / "scripts" / "windows" / "Invoke-CtgKaliGuestFlash.ps1").read_text(encoding="utf-8")
    assert "--fit-window" in flash


def test_medium_text_defaults():
    body = _body()
    assert "apply_medium_text()" in body
    assert re.search(
        r"apply_medium_text\(\) \{.*?TARGET_DPI=\"\$CTG_TEXT_MEDIUM_DPI\".*?GTK_FONT=\"\$CTG_TEXT_MEDIUM_GTK\".*?TERM_FONT=\"\$CTG_TEXT_MEDIUM_TERM\"",
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
    assert "TARGET_DPI=110" not in block


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
        "--text-plus15",
        "--text-large",
        "--fonts-only",
        "--reset",
        "--aggressive",
        "--diagnose-only",
        "--login-scale",
        "--cursor-neon",
    ):
        assert flag in body
