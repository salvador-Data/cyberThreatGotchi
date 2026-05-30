"""Syntax check for Kali-only CTG scrambler GUI (no Tk display required)."""
from __future__ import annotations

import ast
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_ctg_scrambler_gui_ast_parse():
    path = ROOT / "scripts" / "kali" / "tor-http-scrambler" / "ctg-scrambler-gui.py"
    ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
