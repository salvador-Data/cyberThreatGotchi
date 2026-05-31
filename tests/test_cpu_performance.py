"""Tests for CPU performance scripts — parse, no secrets in repo."""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
WIN = ROOT / "scripts" / "windows"

CPU_SCRIPTS = (
    "Optimize-CpuPerformance.ps1",
    "Register-CtgCpuOptimizeTask.ps1",
)

FORBIDDEN_PATTERNS = (
    r"(?i)password\s*[:=]\s*['\"][^'\"]{6,}['\"]",
    r"-pw\s+['\"][^'\"]+['\"]",
    r"ConvertTo-SecureString.*-AsPlainText",
    r"\$env:PASSWORD",
    r"Andy['\"]?\s*,\s*['\"][^'\"]+['\"]",
)


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


def test_cpu_scripts_exist():
    for name in CPU_SCRIPTS:
        assert (WIN / name).is_file(), name


def test_cpu_scripts_parse():
    for name in CPU_SCRIPTS:
        _parse_ps1(WIN / name)


def test_optimize_cpu_diagnose_only_runs():
    if shutil.which("powershell") is None:
        pytest.skip("powershell not available on this runner")
    script = WIN / "Optimize-CpuPerformance.ps1"
    r = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(script),
            "-DiagnoseOnly",
        ],
        capture_output=True,
        text=True,
        timeout=120,
    )
    assert r.returncode == 0, f"DiagnoseOnly failed:\n{r.stdout}\n{r.stderr}"
    combined = r.stdout + r.stderr
    assert "CPU performance diagnose" in combined or "Optimize-CpuPerformance" in combined


def test_cpu_scripts_contain_no_embedded_credentials():
    paths = [WIN / n for n in CPU_SCRIPTS]
    paths.append(ROOT / "docs" / "CPU_PERFORMANCE.md")
    for path in paths:
        text = path.read_text(encoding="utf-8")
        for pat in FORBIDDEN_PATTERNS:
            assert not re.search(pat, text), f"{path.name} matched forbidden pattern: {pat}"


def test_cpu_docs_exist():
    doc = ROOT / "docs" / "CPU_PERFORMANCE.md"
    assert doc.is_file()
    body = doc.read_text(encoding="utf-8")
    assert "Optimize-CpuPerformance.ps1" in body
    assert "ApplyUnsafe" in body
    assert (
        "no password in git" in body.lower()
        or "no password in repo" in body.lower()
        or "no password in xml" in body.lower()
        or "no secrets in git" in body.lower()
    )
    assert "Register-CtgCpuOptimizeTask.ps1" in body


def test_audit_autorun_cpu_optimize_flag():
    script = WIN / "CTG-AuditAutorun.ps1"
    text = script.read_text(encoding="utf-8")
    assert "CpuOptimize" in text
    assert "Optimize-CpuPerformance.ps1" in text
    assert "cpu-optimize.txt" in text


def test_register_task_uses_interactive_logon():
    text = (WIN / "Register-CtgCpuOptimizeTask.ps1").read_text(encoding="utf-8")
    assert "LogonType Interactive" in text
    assert "RunLevel Highest" in text
    assert "NOT stored" in text or "no password" in text.lower()


def test_apply_unsafe_not_implemented():
    if shutil.which("powershell") is None:
        pytest.skip("powershell not available on this runner")
    script = WIN / "Optimize-CpuPerformance.ps1"
    r = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(script),
            "-ApplyUnsafe",
        ],
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert r.returncode == 2
    assert "NOT implemented" in r.stdout or "NOT implemented" in r.stderr
