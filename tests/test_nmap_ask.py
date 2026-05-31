"""CTG ctg-nmap-ask.sh — parse, scope gate, state schema (no live nmap)."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASK = ROOT / "scripts" / "kali" / "ctg-nmap-ask.sh"
NSE = ROOT / "scripts" / "kali" / "nse" / "ctg-ask-recon.nse"
AUTOPATCH = ROOT / "scripts" / "kali" / "kali-boot-autopatch.sh"
PLAYGROUND = ROOT / "scripts" / "kali" / "ctg-lab-playground.sh"
DOC = ROOT / "docs" / "NMAP_ASK_ANALYSIS.md"
STAGE = ROOT / "scripts" / "windows" / "Stage-KaliLabToBackups.ps1"

STATE_KEYS = {
    "target",
    "ip",
    "mac",
    "hostname",
    "vendor",
    "os_guess",
    "open_ports",
    "last_scan_iso",
    "interface_used",
    "scan_xml",
}


def _body(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_nmap_ask_script_exists():
    body = _body(ASK)
    assert ASK.is_file()
    assert "Hacker Planet" in body
    assert "--help" in body
    assert "--dump" in body
    assert "--list" in body
    assert "--reconnect" in body
    assert "-i" in body
    assert "lab-targets.conf" in body


def test_no_secrets_in_nmap_ask():
    body = _body(ASK)
    assert "password" not in body.lower() or "NOPASSWD" not in body
    assert "CTG_PII" not in body
    assert re.search(r"psk\s*=", body, re.I) is None


def test_state_json_schema_in_script():
    body = _body(ASK)
    for key in STATE_KEYS:
        assert f'"{key}"' in body


def test_state_root_paths():
    body = _body(ASK)
    assert "/var/log/ctg/nmap-ask" in body
    assert ".config/ctg/nmap-ask" in body


def test_adaptive_phases_present():
    body = _body(ASK)
    assert "-sn" in body
    assert "--top-ports" in body
    assert "-sV" in body
    assert "-O" in body
    assert "default,safe,vuln" in body
    assert "-PR" in body


def test_nse_helper_exists():
    body = _body(NSE)
    assert NSE.is_file()
    assert "authorized lab" in body.lower()
    assert "safe" in body
    assert "discovery" in body


def test_autopatch_installs_nmap_ask():
    body = _body(AUTOPATCH)
    assert "install_nmap_ask" in body
    assert "verify_nmap_ask" in body
    assert "/opt/ctg/nmap-ask" in body
    assert "/usr/local/bin/a\\$k" in body or '/usr/local/bin/a\\$k' in body
    assert "ctg-nmap-ask.sh" in body
    assert "--help" in body


def test_playground_menu_wiring():
    body = _body(PLAYGROUND)
    assert "play_nmap_ask" in body
    assert "nmap-ask" in body.lower() or "a$k" in body


def test_docs_exist():
    assert DOC.is_file()
    body = _body(DOC)
    assert "NIST CSF" in body
    assert "/var/log/ctg/nmap-ask" in body
    assert "a$k" in body


def test_stage_script_includes_nse_and_doc():
    body = _body(STAGE)
    assert "'nse'" in body
    assert "NMAP_ASK_ANALYSIS.md" in body


def test_write_state_json_produces_valid_shape():
    """Static check: embedded Python defines all required JSON keys."""
    body = _body(ASK)
    match = re.search(r'data = \{([^}]+)\}', body, re.DOTALL)
    assert match
    block = match.group(1)
    for key in STATE_KEYS:
        assert f'"{key}"' in block
