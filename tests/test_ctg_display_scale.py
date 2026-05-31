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
    assert "--fonts-only" in body
    assert "--reset" in body
    assert "--aggressive" in body
    assert "--diagnose-only" in body


def test_fit_window_is_default_mode():
    body = _body()
    assert re.search(r"FIT_WINDOW=true", body)
    assert 'APPLY_MODE="fit-window"' in body
    assert "fit-to-window" in body.lower() or "fit-window" in body


def test_never_force_oversized_resolution():
    body = _body()
    assert "downscale_oversized_xrandr" in body
    assert "2560" in body
    assert "1600" in body
    assert "largest" not in body.lower() or "never largest" in body.lower()


def test_fit_window_in_autostart_and_wiring():
    body = _body()
    assert "--fit-window" in body
    assert "ctg-display-scale.desktop" in body or "autostart_dir/ctg-display-scale.desktop" in body

    seamless = (ROOT / "scripts" / "kali" / "ctg-seamless-guest.sh").read_text(encoding="utf-8")
    assert "ctg-display-scale" in seamless
    assert "--fit-window" in seamless
    assert "largest available mode" not in seamless

    first_login = (ROOT / "scripts" / "kali" / "ctg-first-login-autorun.sh").read_text(encoding="utf-8")
    assert "--fit-window" in first_login

    autopatch = (ROOT / "scripts" / "kali" / "kali-boot-autopatch.sh").read_text(encoding="utf-8")
    assert "--fit-window" in autopatch

    flash = (ROOT / "scripts" / "windows" / "Invoke-CtgKaliGuestFlash.ps1").read_text(encoding="utf-8")
    assert "--fit-window" in flash


def test_dpi_range_modest_not_aggressive_default():
    body = _body()
    assert "TARGET_DPI=105" in body
    fit = re.search(
        r'# fit-window \(default\): modest DPI after resolution fits VM window.*?'
        r'log "Fit-window \$\{w\}x\$\{h\} -> DPI=\$TARGET_DPI',
        body,
        re.DOTALL,
    )
    assert fit, "fit-window compute_target_dpi block not found"
    block = fit.group(0)
    assert "TARGET_DPI=112" in block
    assert "TARGET_DPI=144" not in block
    assert "TARGET_DPI=120" not in block


def test_help_documents_all_flags():
    body = _body()
    for flag in ("--fit-window", "--fonts-only", "--reset", "--aggressive", "--diagnose-only"):
        assert flag in body
