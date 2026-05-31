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
        "ctg-shield-rotate.sh",
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
    assert "ctg-shield-rotate.sh" in text
    assert "CTG_SHIELD_SIEM_PLAYBOOK" in text
    assert "kali-boot-autopatch.sh" in text
    assert "ctg-kali-autopatch.service" in text
    assert "KALI_WIFI_ETH_PROMISC" in text
    assert "ctg-wifi-lab-autorun" in text
    assert "KALI_IDS_IPS_CLAMAV" in text or "ctg-ids-ips" in text
    assert "KALI_SIEM_STACK" in text or "ctg-siem" in text


def test_kali_boot_autopatch_assets():
    autopatch = ROOT / "scripts" / "kali" / "kali-boot-autopatch.sh"
    deploy = ROOT / "scripts" / "windows" / "Deploy-KaliBootAutopatch.ps1"
    assert autopatch.is_file()
    body = autopatch.read_text(encoding="utf-8")
    assert "authorized" in body.lower()
    assert "94.140.14.14" in body
    assert "WaylandEnable=false" in body
    assert deploy.is_file()
    assert "OpenSSH" in deploy.read_text(encoding="utf-8")
