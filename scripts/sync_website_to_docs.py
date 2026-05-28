#!/usr/bin/env python3
"""Copy website/ → docs/web/ so the site is browsable in the GitHub repo tree."""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "website"
DEST = ROOT / "docs" / "web"


def sync() -> int:
    if not SRC.is_dir():
        print("Missing website/ folder", file=sys.stderr)
        return 1
    if DEST.exists():
        shutil.rmtree(DEST)
    shutil.copytree(SRC, DEST)
    print(f"Synced {SRC} -> {DEST} ({sum(1 for _ in DEST.rglob('*') if _.is_file())} files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(sync())
