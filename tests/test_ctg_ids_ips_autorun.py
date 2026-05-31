"""CTG IDS/IPS + ClamAV autorun — repo asset contract tests (no Kali VM required)."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_ctg_ids_ips_autorun_script():
    script = ROOT / "scripts" / "kali" / "ctg-ids-ips-autorun.sh"
    body = script.read_text(encoding="utf-8")
    assert script.is_file()
    assert "authorized" in body.lower()
    assert "snort" in body.lower()
    assert "suricata" in body.lower()
    assert "clamav" in body.lower()
    assert "/etc/ctg/snort" in body
    assert "/var/log/ctg-snort" in body
    assert "ctg-ids-ips.service" in body
    assert "ctg-suricata.service" in body
    assert "--EnableIPS" in body
    assert "--optimize" in body
    assert "--skip-snort" in body
    assert "siem-hook" in body
    assert "ctg-clamav-scan.timer" in body
    assert "suricata-update" in body
    assert "ctg-hardening.conf" in body


def test_ctg_siem_autorun_script():
    script = ROOT / "scripts" / "kali" / "ctg-siem-autorun.sh"
    body = script.read_text(encoding="utf-8")
    assert script.is_file()
    assert "authorized" in body.lower()
    assert "ctg-siem-export.timer" in body
    assert "CTG_WAZUH_MANAGER" in body
    assert "ctg-siem-latest.json" in body
    assert "suricata_eve_tail" in body


def test_kali_siem_stack_doc():
    doc = ROOT / "docs" / "KALI_SIEM_STACK.md"
    text = doc.read_text(encoding="utf-8")
    assert doc.is_file()
    assert "Wazuh" in text
    assert "Suricata" in text
    assert "Splunk" in text
    assert "8 GB" in text or "8GB" in text
    assert "authorized" in text.lower()


def test_kali_ids_ips_clamav_doc():
    doc = ROOT / "docs" / "KALI_IDS_IPS_CLAMAV.md"
    text = doc.read_text(encoding="utf-8")
    assert doc.is_file()
    assert "IDS vs IPS" in text or "IDS" in text
    assert "ClamAV" in text
    assert "ctg-ids-ips-autorun.sh" in text
    assert "KALI_SIEM_STACK" in text
    assert "authorized" in text.lower()


def test_boot_autopatch_ids_ips_and_siem_flags():
    autopatch = ROOT / "scripts" / "kali" / "kali-boot-autopatch.sh"
    body = autopatch.read_text(encoding="utf-8")
    assert "--ids-ips" in body
    assert "--siem" in body
    assert "ctg-ids-ips-autorun" in body
    assert "ctg-siem-autorun" in body


def test_lab_autorun_calls_ids_ips_and_siem():
    autorun = ROOT / "scripts" / "kali" / "ctg-lab-autorun.sh"
    body = autorun.read_text(encoding="utf-8")
    assert "ctg-ids-ips-autorun" in body
    assert "ctg-siem-autorun" in body
    assert "--optimize" in body
    assert "KALI_IDS_IPS_CLAMAV" in body
    assert "KALI_SIEM_STACK" in body


def test_wifi_lab_chains_ids_ips():
    wifi = ROOT / "scripts" / "kali" / "ctg-wifi-lab-autorun.sh"
    body = wifi.read_text(encoding="utf-8")
    assert "ctg-ids-ips-autorun" in body


def test_bootstrap_clamav_timer_and_ids():
    bootstrap = ROOT / "scripts" / "kali" / "kali-lab-bootstrap.sh"
    body = bootstrap.read_text(encoding="utf-8")
    assert "clamav-freshclam" in body
    assert "ctg-clamav-home-scan.timer" in body
    assert "ctg-ids-ips-autorun" in body


def test_deploy_stages_ids_ips_and_siem():
    deploy = ROOT / "scripts" / "windows" / "Deploy-KaliLab.ps1"
    text = deploy.read_text(encoding="utf-8")
    assert "ctg-ids-ips-autorun.sh" in text
    assert "ctg-siem-autorun.sh" in text
    assert "KALI_SIEM_STACK.md" in text


def test_wireshark_optimize_capture():
    ps1 = ROOT / "scripts" / "windows" / "Start-CTGWiresharkIDS.ps1"
    body = ps1.read_text(encoding="utf-8")
    assert "OptimizeCapture" in body
    assert "1600" in body


def test_siem_hook_ctg_snort_and_clamav_paths():
    siem = ROOT / "scripts" / "kali" / "tor-http-scrambler" / "siem-hook.sh"
    body = siem.read_text(encoding="utf-8")
    assert "/var/log/ctg-snort" in body
    assert "/var/log/ctg-clamav" in body
