"""CTG Shield + SIEM assets — repo checks (no Kali VM required)."""
from __future__ import annotations

import ast
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRAM = ROOT / "scripts" / "kali" / "tor-http-scrambler"


def test_ctg_shield_rotate_script_present():
    path = SCRAM / "ctg-shield-rotate.sh"
    text = path.read_text(encoding="utf-8")
    assert "preserve-ddg-dns" in text
    assert "usb" in text.lower()
    assert "authorized" in text.lower()


def test_siem_hook_calls_shield():
    text = (SCRAM / "siem-hook.sh").read_text(encoding="utf-8")
    assert "ctg-shield-rotate.sh" in text or "SHIELD" in text
    assert "y|yes" in text


def test_ctg_shield_status_ps1():
    ps1 = ROOT / "scripts" / "windows" / "CTG-Shield-Status.ps1"
    body = ps1.read_text(encoding="utf-8")
    assert "DuckDuckGo" in body
    assert "read-only" in body.lower() or "Read-only" in body


def test_shield_playbook_doc():
    doc = ROOT / "docs" / "CTG_SHIELD_SIEM_PLAYBOOK.md"
    text = doc.read_text(encoding="utf-8")
    assert "v1" in text
    assert "94.140.14.14" in text


def test_ctg_shield_bash_syntax_if_bash_available():
    bash = shutil.which("bash")
    if not bash:
        return
    for name in ("ctg-shield-rotate.sh", "siem-hook.sh"):
        path = SCRAM / name
        try:
            subprocess.run([bash, "-n", str(path)], check=True, timeout=10)
        except subprocess.CalledProcessError as exc:
            if exc.returncode == 127:
                return
            raise


def test_install_scrambler_installs_shield():
    text = (SCRAM / "install-scrambler.sh").read_text(encoding="utf-8")
    assert "ctg-shield-rotate.sh" in text


def test_scrambler_gui_ast():
    path = SCRAM / "ctg-scrambler-gui.py"
    ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    assert "SHIELD" in path.read_text(encoding="utf-8")
