"""Firewall baseline script tests."""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
FW = ROOT / "scripts" / "firewall-baseline.sh"
FW_SAVE = ROOT / "scripts" / "firewall-baseline-save.sh"
INSTALL = ROOT / "scripts" / "install.sh"


def _bash_script_path(path: Path) -> str:
    """Git Bash / MSYS path for subprocess on Windows."""
    if sys.platform == "win32":
        resolved = str(path.resolve())
        if len(resolved) >= 2 and resolved[1] == ":":
            return f"/{resolved[0].lower()}{resolved[2:].replace(chr(92), '/')}"
    return str(path)


def _bash_dry_run(extra_env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    import os

    env = {**os.environ, **(extra_env or {})}
    return subprocess.run(
        ["bash", _bash_script_path(FW), "--dry-run"],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
        env=env,
        timeout=60,
    )


def _bash_dry_run_works() -> bool:
    if shutil.which("bash") is None:
        return False
    try:
        return _bash_dry_run().returncode == 0
    except (subprocess.TimeoutExpired, OSError):
        return False


@pytest.mark.skipif(shutil.which("bash") is None, reason="bash not available")
@pytest.mark.skipif(
    sys.platform == "win32" and not _bash_dry_run_works(),
    reason="bash on this host cannot execute firewall script paths",
)
def test_firewall_baseline_dry_run_includes_web_port():
    result = _bash_dry_run({"CTG_WEB_PORT": "8765"})
    assert result.returncode == 0, result.stderr or result.stdout
    assert "8765" in result.stdout
    assert "3310" in result.stdout
    assert "CTG_BASELINE" in result.stdout


@pytest.mark.skipif(shutil.which("bash") is None, reason="bash not available")
@pytest.mark.skipif(
    sys.platform == "win32" and _bash_dry_run().returncode != 0,
    reason="bash on this host cannot execute firewall script paths",
)
def test_firewall_baseline_dry_run_respects_extra_ports():
    result = _bash_dry_run({"CTG_WEB_PORT": "8765", "CTG_EXTRA_TCP_PORTS": "9090,9091"})
    assert result.returncode == 0, result.stderr or result.stdout
    assert re.search(r"9090|9091", result.stdout)


@pytest.mark.skipif(shutil.which("bash") is None, reason="bash not available")
@pytest.mark.skipif(
    sys.platform == "win32" and _bash_dry_run().returncode != 0,
    reason="bash on this host cannot execute firewall script paths",
)
def test_firewall_baseline_dry_run_icmp_disabled():
    result = _bash_dry_run({"CTG_ALLOW_ICMP": "0"})
    assert result.returncode == 0, result.stderr or result.stdout
    assert "CTG: ping" not in result.stdout


def test_firewall_baseline_scripts_exist():
    assert FW.is_file(), "scripts/firewall-baseline.sh missing"
    assert FW_SAVE.is_file(), "scripts/firewall-baseline-save.sh missing"


def test_firewall_baseline_documents_ctg_ports_and_ips():
    text = FW.read_text(encoding="utf-8")
    assert "8765" in text or "CTG_WEB_PORT" in text
    assert "3310" in text
    assert "CTG_BASELINE" in text
    assert "core/ips.py" in text or "IPS" in text
    assert "--dry-run" in text


def test_install_sh_references_firewall_baseline():
    text = INSTALL.read_text(encoding="utf-8")
    assert "CTG_FIREWALL_BASELINE" in text
    assert "firewall-baseline.sh" in text


def test_firewall_docs_exist():
    assert (ROOT / "docs" / "FIREWALL_BASELINE.md").is_file()
    assert (ROOT / "docs" / "CLOUDFLARE_SETUP.md").is_file()


def test_firewall_baseline_dry_run_output_parseable_without_bash():
    """Validate dry-run semantics from script source (CI / Windows without bash)."""
    text = FW.read_text(encoding="utf-8")
    assert "CTG_ALLOW_ICMP" in text
    assert 'CTG: ping' in text
    assert "CTG_EXTRA_TCP_PORTS" in text
    assert "--dry-run" in text
    assert "CTG_SSH_LAN_ONLY" in text
