"""Hardware STL artifacts exist and are valid."""

from __future__ import annotations

import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GEN = ROOT / "hardware" / "generate_stl.py"

EINK_PARTS = ROOT / "hardware" / "stl" / "eink"
LEGACY = ROOT / "hardware" / "stl"
PART_NAMES = (
    "ctg_front_shell.stl",
    "ctg_rear_shell.stl",
    "ctg_clip.stl",
)


def _ensure_stls():
    if not (EINK_PARTS / "ctg_front_shell.stl").is_file():
        subprocess.run([sys.executable, str(GEN), "--variant", "all", "--python-only"], check=True)


def _read_stl_tri_count(path: Path) -> int:
    data = path.read_bytes()
    assert len(data) >= 84
    return struct.unpack("<I", data[80:84])[0]


def test_eink_stl_files_exist():
    _ensure_stls()
    for name in PART_NAMES:
        assert (EINK_PARTS / name).is_file(), name
        assert (LEGACY / name).is_file(), f"legacy {name}"


def test_lcd_stl_files_exist():
    _ensure_stls()
    lcd = ROOT / "hardware" / "stl" / "lcd"
    for name in PART_NAMES:
        assert (lcd / name).is_file(), name


def test_stl_binary_header():
    _ensure_stls()
    for name in PART_NAMES:
        path = EINK_PARTS / name
        header = path.read_bytes()[:80]
        assert b"CyberThreatGotchi" in header
        assert _read_stl_tri_count(path) > 10
