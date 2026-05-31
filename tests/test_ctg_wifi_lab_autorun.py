"""CTG WiFi lab autorun — repo asset contract tests (no Kali VM required)."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_ctg_wifi_lab_autorun_script():
    script = ROOT / "scripts" / "kali" / "ctg-wifi-lab-autorun.sh"
    body = script.read_text(encoding="utf-8")
    assert script.is_file()
    assert "authorized" in body.lower()
    assert "/etc/ctg/lab-wifi.conf" in body
    assert "airmon-ng" in body
    assert "promisc" in body
    assert "94.140.14.14" in body
    assert "ctg-wifi-lab.service" in body
    assert "/var/log/ctg-wifi-lab.log" in body
    assert "rtl8812au" in body or "rtl88xxau" in body


def test_lab_wifi_conf_example():
    example = ROOT / "scripts" / "kali" / "lab-wifi.conf.example"
    body = example.read_text(encoding="utf-8")
    assert example.is_file()
    assert "CTG_LAB_WIFI_SSID" in body
    assert "CTG_LAB_WIFI_PSK" in body
    assert "YourLabSSID" in body


def test_kali_wifi_eth_promisc_doc():
    doc = ROOT / "docs" / "KALI_WIFI_ETH_PROMISC.md"
    text = doc.read_text(encoding="utf-8")
    assert doc.is_file()
    assert "monitor mode" in text.lower()
    assert "promiscuous" in text.lower()
    assert "airmon-ng" in text
    assert "eth0" in text or "Ethernet" in text
    assert "authorized" in text.lower()


def test_boot_autopatch_wifi_lab_flag():
    autopatch = ROOT / "scripts" / "kali" / "kali-boot-autopatch.sh"
    body = autopatch.read_text(encoding="utf-8")
    assert "--wifi-lab" in body
    assert "ctg-wifi-lab-autorun" in body


def test_lab_autorun_calls_wifi():
    autorun = ROOT / "scripts" / "kali" / "ctg-lab-autorun.sh"
    body = autorun.read_text(encoding="utf-8")
    assert "ctg-wifi-lab-autorun" in body
    assert "--wifi-lab" in body


def test_deploy_kali_lab_stages_wifi():
    deploy = ROOT / "scripts" / "windows" / "Deploy-KaliLab.ps1"
    text = deploy.read_text(encoding="utf-8")
    assert "ctg-wifi-lab-autorun.sh" in text
    assert "lab-wifi.conf.example" in text
