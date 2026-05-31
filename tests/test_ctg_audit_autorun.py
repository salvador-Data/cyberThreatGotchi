"""CTG Audit Autorun — repo asset checks (no live audit run required)."""

from __future__ import annotations

import importlib.util
import shutil
import subprocess
from datetime import datetime
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
WIN = ROOT / "scripts" / "windows"


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


def _load_paths():
    spec = importlib.util.spec_from_file_location("ctg_audit_paths", WIN / "ctg_audit_paths.py")
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def test_audit_autorun_script_exists_and_parses():
    script = WIN / "CTG-AuditAutorun.ps1"
    assert script.is_file()
    text = script.read_text(encoding="utf-8")
    assert "windows-security" in text
    assert "network-ids" in text
    assert "soc-ctg" in text
    assert "kali-bridge" in text
    assert "manifest.json" in text
    assert "CTG_AUDIT_REMOTE" in text
    assert "selective_ssd_backup.ps1" in text
    assert "Harden-DDoSRogueWifi.ps1" in text
    assert "Harden-PasswordPolicy.ps1" in text
    assert "ctg-audit-autorun.log" in text
    _parse_ps1(script)


def test_ctg_audit_paths_helpers():
    mod = _load_paths()
    ts = datetime(2026, 5, 30, 4, 15, 0)
    home = Path("C:/Users/Owner")
    run = mod.audit_run_dir(ts, home)
    assert run == home / "Backups" / "audit" / "2026-05-30" / "run-041500"
    assert mod.compartment_dir("windows-security", ts, home) == run / "windows-security"
    assert mod.autorun_log_path(home) == home / "Backups" / "logs" / "ctg-audit-autorun.log"
    assert mod.manifest_path(ts, home) == run / "manifest.json"
    assert mod.ssd_audit_mirror_dir(ts) == Path("D:/Backups/audit/2026-05-30/run-041500")
    assert mod.wireshark_alerts_path(home).name == "wireshark-alerts.json"
    with pytest.raises(ValueError):
        mod.compartment_dir("invalid", ts, home)


def test_nightly_orchestrator_calls_audit_autorun():
    orch = (WIN / "ctg_nightly_4am.ps1").read_text(encoding="utf-8")
    assert "CTG-AuditAutorun.ps1" in orch
    assert "-AuditOnly" in orch
    assert "-SinkCloud" in orch


def test_audit_docs_exist():
    compartments = ROOT / "docs" / "AUDIT_COMPARTMENTS.md"
    sink = ROOT / "docs" / "AUDIT_CLOUD_SINK.md"
    assert compartments.is_file()
    assert sink.is_file()
    assert "windows-security" in compartments.read_text(encoding="utf-8")
    assert "CTG_AUDIT_REMOTE" in sink.read_text(encoding="utf-8")
    assert "CTG_WAZUH_MANAGER" in sink.read_text(encoding="utf-8")
    assert "filebeat-audit.yml.example" in sink.read_text(encoding="utf-8")


def test_filebeat_template_exists():
    fb = ROOT / "config" / "filebeat" / "filebeat-audit.yml.example"
    assert fb.is_file()
    body = fb.read_text(encoding="utf-8")
    assert "CTG_ELASTIC_HOST" in body
    assert "ctg-audit" in body
