#!/usr/bin/env python3
"""Backward-compatible wrapper — eBay channel filter for partner_fulfillment_export.py."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PARTNER = ROOT / "scripts" / "partner_fulfillment_export.py"


def main() -> int:
    argv = [sys.executable, str(PARTNER)]
    argv.extend(sys.argv[1:])
    if "--channel" not in argv:
        argv.extend(["--channel", "ebay"])
    if "-o" not in argv and "--output-dir" not in argv:
        argv.extend(["-o", str(ROOT / "data" / "ebay_exports")])
    result = subprocess.run(argv, cwd=str(ROOT))
    return int(result.returncode)


if __name__ == "__main__":
    raise SystemExit(main())
