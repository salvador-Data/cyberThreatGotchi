"""Tests for Wireshark IDS scripts and alert parsing (no real SMS in CI)."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
WIN = ROOT / "scripts" / "windows"
IDS = ROOT / "scripts" / "wireshark_ids"


def _parse_ps1(path: Path) -> None:
    if shutil.which("powershell") is None:
        pytest.skip("powershell not available on this runner")
    cmd = (
        f"$e=$null; $null=[System.Management.Automation.Language.Parser]::ParseFile("
        f"'{path}', [ref]$null, [ref]$e); if($e){{$e|ForEach-Object{{$_.ToString()}}; exit 1}}"
    )
    r = subprocess.run(
        ["powershell", "-NoProfile", "-Command", cmd],
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert r.returncode == 0, f"{path.name} parse errors:\n{r.stdout}\n{r.stderr}"


def test_wireshark_ids_files_exist():
    assert (WIN / "Start-CTGWiresharkIDS.ps1").is_file()
    assert (WIN / "Send-CtgSmsAlert.ps1").is_file()
    assert (WIN / "ctg_wireshark_ids_loop.ps1").is_file()
    assert (WIN / "CTG-WiresharkCommon.ps1").is_file()
    assert (IDS / "analyze_traffic.py").is_file()
    assert (ROOT / "docs" / "WIRESHARK_IDS_SMS.md").is_file()


@pytest.mark.parametrize(
    "name",
    [
        "Start-CTGWiresharkIDS.ps1",
        "Send-CtgSmsAlert.ps1",
        "ctg_wireshark_ids_loop.ps1",
        "CTG-WiresharkCommon.ps1",
    ],
)
def test_wireshark_ps1_parse(name: str):
    _parse_ps1(WIN / name)


def test_no_phone_or_twilio_secrets_in_repo_scripts():
    for rel in (
        "Start-CTGWiresharkIDS.ps1",
        "Send-CtgSmsAlert.ps1",
        "CTG-WiresharkCommon.ps1",
        "ctg_wireshark_ids_loop.ps1",
    ):
        text = (WIN / rel).read_text(encoding="utf-8")
        assert "2767730449" not in text
        assert "AC" + "a" * 32 not in text  # placeholder Twilio SID pattern
        assert "TWILIO_AUTH_TOKEN=" not in text


def test_start_script_flags_and_paths():
    text = (WIN / "Start-CTGWiresharkIDS.ps1").read_text(encoding="utf-8")
    for needle in (
        "DiagnoseOnly",
        "CaptureMinutes",
        "Interface",
        "BlockRepeatOffenders",
        "wireshark-ids.log",
        "wireshark-alerts.json",
        "analyze_traffic.py",
        "Install-WiresharkNpcap.ps1",
    ):
        assert needle in text, needle


def test_sms_script_rate_limit_and_env():
    text = (WIN / "Send-CtgSmsAlert.ps1").read_text(encoding="utf-8")
    assert "CTG_ALERT_SMS_TO" in text
    assert "TWILIO_ACCOUNT_SID" in text
    assert "TestMessage" in text
    assert "15" in text
    assert "sms-rate-limit.json" in text


def test_port_scan_detection():
    from scripts.wireshark_ids.analyze_traffic import analyze_flow_rows, parse_tshark_csv_text

    lines = []
    for port in range(1, 25):
        lines.append(f"1.0\t10.0.0.5\t192.168.1.1\t50000\t{port}\t\t\tTCP\t60\tsyn\t\t\t\t")
    csv_text = "\n".join(lines)
    alerts = analyze_flow_rows(parse_tshark_csv_text(csv_text))
    types = {a["alert_type"] for a in alerts}
    assert "port_scan" in types


def test_dns_tunnel_hint():
    from scripts.wireshark_ids.analyze_traffic import analyze_flow_rows, parse_tshark_csv_text

    long_name = "a" * 90 + ".example.com"
    csv_text = f"1.0\t10.0.0.9\t8.8.8.8\t\t\t\t53\tUDP\t80\t\t{long_name}\t\t\t"
    alerts = analyze_flow_rows(parse_tshark_csv_text(csv_text))
    assert any(a["alert_type"] == "dns_tunnel_hint" for a in alerts)


def test_arp_spoof_hint():
    from scripts.wireshark_ids.analyze_traffic import analyze_flow_rows, parse_tshark_csv_text

    csv_text = "\n".join(
        [
            "1.0\t\t\t\t\t\t\tARP\t60\t\t\t192.168.1.50\taa:bb:cc:dd:ee:01\t",
            "2.0\t\t\t\t\t\t\tARP\t60\t\t\t192.168.1.50\taa:bb:cc:dd:ee:02\t",
        ]
    )
    alerts = analyze_flow_rows(parse_tshark_csv_text(csv_text))
    assert any(a["alert_type"] == "arp_spoof_hint" for a in alerts)


def test_snort_alert_parse():
    from scripts.wireshark_ids.analyze_traffic import parse_snort_log_text

    sample = (
        "** [1:1000001:1] ET SCAN NMAP SYN scan [**] "
        "[Classification: Attempted Information Leak] [Priority: 2] "
        "{TCP} 10.0.0.5:45678 -> 192.168.1.10:22"
    )
    alerts = parse_snort_log_text(sample)
    assert len(alerts) == 1
    assert alerts[0].source == "snort"
    assert alerts[0].src_ip == "10.0.0.5"


def test_analyzer_cli_json_out(tmp_path: Path):
    csv_file = tmp_path / "export.csv"
    json_out = tmp_path / "alerts.json"
    lines = [f"1.0\t10.0.0.5\t192.168.1.1\t50000\t{p}\t\t\tTCP\t60\tsyn\t\t\t\t" for p in range(1, 30)]
    csv_file.write_text("\n".join(lines), encoding="utf-8")
    r = subprocess.run(
        [
            sys.executable,
            str(IDS / "analyze_traffic.py"),
            "--csv",
            str(csv_file),
            "--json-out",
            str(json_out),
        ],
        capture_output=True,
        text=True,
        timeout=30,
        cwd=str(ROOT),
    )
    assert r.returncode == 0, r.stderr
    data = json.loads(json_out.read_text(encoding="utf-8"))
    assert isinstance(data, list)
    assert any(item.get("alert_type") == "port_scan" for item in data)


def test_doc_links():
    doc = (ROOT / "docs" / "WIRESHARK_IDS_SMS.md").read_text(encoding="utf-8")
    assert "Start-CTGWiresharkIDS.ps1" in doc
    assert "CTG_ALERT_SMS_TO" in doc
    assert "OPNsense" in doc or "Suricata" in doc
    assert "2767730449" not in doc


def test_readme_and_security_doc_reference_wireshark_ids():
    readme = (WIN / "README_WINDOWS_SOC.md").read_text(encoding="utf-8")
    sec = (ROOT / "docs" / "SECURITY_HARDENING.md").read_text(encoding="utf-8")
    assert "Start-CTGWiresharkIDS.ps1" in readme
    assert "WIRESHARK_IDS_SMS.md" in readme
    assert "TWILIO_ACCOUNT_SID" in sec
    assert "CTG_ALERT_SMS_TO" in sec
