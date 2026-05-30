"""CTG Lab Autorun — repo asset checks (no Kali VM required)."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_start_ctg_lab_ps1_exists():
    p = ROOT / "scripts" / "windows" / "Start-CTGLab.ps1"
    text = p.read_text(encoding="utf-8")
    assert p.is_file()
    assert "Deploy-KaliLab.ps1" in text
    assert "Hacker Planet" in text


def test_kali_autorun_and_scrambler_assets():
    autorun = ROOT / "scripts" / "kali" / "ctg-lab-autorun.sh"
    assert autorun.is_file()
    assert "authorized" in autorun.read_text(encoding="utf-8").lower()

    scram = ROOT / "scripts" / "kali" / "tor-http-scrambler"
    for name in (
        "scrambler-daemon.sh",
        "install-scrambler.sh",
        "ctg-scrambler-gui.py",
        "siem-hook.sh",
        "site-rules.example",
    ):
        f = scram / name
        assert f.is_file(), name
        body = f.read_text(encoding="utf-8")
        assert "Hacker Planet" in body or "authorized" in body.lower()


def test_ctg_lab_autorun_doc():
    doc = ROOT / "docs" / "CTG_LAB_AUTORUN.md"
    text = doc.read_text(encoding="utf-8")
    assert "Start-CTGLab.ps1" in text
    assert "ctg-lab-autorun.sh" in text
