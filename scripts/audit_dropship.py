#!/usr/bin/env python3
"""Audit dropship catalog entries for required fields."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CAT = (ROOT / "website" / "js" / "catalog.config.js").read_text(encoding="utf-8")
WEB = ROOT / "website"

REQUIRED = ("id", "name", "description", "retailPrice", "stripeKey", "supplierUrl", "supplier", "fulfillment", "image", "includes")


def main() -> None:
    blocks = re.findall(r"\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}", CAT)
    for block in blocks:
        if "fulfillment: \"dropship\"" not in block:
            continue
        pid = re.search(r'id:\s*"([^"]+)"', block)
        if not pid:
            continue
        pid = pid.group(1)
        gaps = []
        for field in REQUIRED:
            if field == "includes":
                if "includes:" not in block:
                    gaps.append("includes[]")
                continue
            if not re.search(rf'{field}:\s*"', block) and not re.search(rf"{field}:\s*\d", block):
                gaps.append(field)
        img = re.search(r'image:\s*"([^"]+)"', block)
        if img and not (WEB / img.group(1)).is_file():
            gaps.append(f"missing file: {img.group(1)}")
        if not img:
            gaps.append("image")
        print(f"{pid}: {'OK' if not gaps else gaps}")


if __name__ == "__main__":
    main()
