"""Tests for GPU performance scripts — parse, no secrets in repo."""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
WIN = ROOT / "scripts" / "windows"

GPU_SCRIPT = "Optimize-GpuPerformance.ps1"

FORBIDDEN_PATTERNS = (
    r"(?i)password\s*[:=]\s*['\"][^'\"]{6,}['\"]",
    r"-pw\s+['\"][^'\"]+['\"]",
    r"ConvertTo-SecureString.*-AsPlainText",
    r"\$env:PASSWORD",
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


def test_gpu_script_exists():
    assert (WIN / GPU_SCRIPT).is_file()


def test_gpu_script_parse():
    _parse_ps1(WIN / GPU_SCRIPT)


def test_optimize_gpu_diagnose_only_runs():
    if shutil.which("powershell") is None:
        pytest.skip("powershell not available on this runner")
    script = WIN / GPU_SCRIPT
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
    assert "GPU performance diagnose" in combined or "Optimize-GpuPerformance" in combined


def test_gpu_script_no_embedded_credentials():
    paths = [WIN / GPU_SCRIPT, ROOT / "docs" / "CPU_PERFORMANCE.md"]
    for path in paths:
        text = path.read_text(encoding="utf-8")
        for pat in FORBIDDEN_PATTERNS:
            assert not re.search(pat, text), f"{path.name} matched forbidden pattern: {pat}"


def test_cpu_docs_mention_gpu():
    doc = ROOT / "docs" / "CPU_PERFORMANCE.md"
    body = doc.read_text(encoding="utf-8")
    assert "Optimize-GpuPerformance.ps1" in body
    assert "GPU" in body
