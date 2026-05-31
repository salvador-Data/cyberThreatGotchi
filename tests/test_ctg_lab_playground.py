"""CTG Lab Playground — repo asset checks (no VM required)."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_kali_playground_script():
    p = ROOT / "scripts" / "kali" / "ctg-lab-playground.sh"
    text = p.read_text(encoding="utf-8")
    assert p.is_file()
    assert "authorized" in text.lower()
    assert "play_wifi_status" in text
    assert "play_tor_check" in text
    assert "rogue-ap-guard" in text


def test_windows_playground_script():
    p = ROOT / "scripts" / "windows" / "CTG-Lab-Playground.ps1"
    text = p.read_text(encoding="utf-8")
    assert p.is_file()
    assert "Start-CTGWiresharkIDS.ps1" in text
    assert "ctg-lab-playground.sh" in text
    assert "Hacker Planet" in text


def test_playground_doc_and_autorun_link():
    doc = ROOT / "docs" / "CTG_LAB_PLAYGROUND.md"
    assert doc.is_file()
    body = doc.read_text(encoding="utf-8")
    assert "CTG-Lab-Playground.ps1" in body
    assert "ctg-lab-playground.sh" in body
    assert "15-minute" in body.lower() or "15 minute" in body.lower()

    autorun = ROOT / "docs" / "CTG_LAB_AUTORUN.md"
    assert "CTG_LAB_PLAYGROUND.md" in autorun.read_text(encoding="utf-8")


def test_playground_staged_in_deploy_scripts():
    start = (ROOT / "scripts" / "windows" / "Start-CTGLab.ps1").read_text(encoding="utf-8")
    deploy = (ROOT / "scripts" / "windows" / "Deploy-KaliLab.ps1").read_text(encoding="utf-8")
    assert "ctg-lab-playground.sh" in start
    assert "CTG-Lab-Playground.ps1" in start
    assert "ctg-lab-playground.sh" in deploy
    assert "CTG-Lab-Playground.ps1" in deploy
