#!/usr/bin/env python3
"""Create release zip bundles (cross-platform, used by GitHub Actions)."""

from __future__ import annotations

import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / "dist"

BUNDLES = {
    "marketing-graphics.zip": ROOT / "docs" / "images",
    "sprites.zip": ROOT / "assets" / "sprites" / "png",
    "enclosure-stl-eink.zip": ROOT / "hardware" / "stl" / "eink",
    "enclosure-stl-lcd.zip": ROOT / "hardware" / "stl" / "lcd",
}


def zip_dir(src: Path, dest: Path) -> None:
    if not src.is_dir():
        raise FileNotFoundError(f"Missing directory to zip: {src}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for path in src.rglob("*"):
            if path.is_file():
                zf.write(path, path.relative_to(src).as_posix())
    print(f"Created {dest} ({dest.stat().st_size} bytes)")


def main() -> int:
    for name, folder in BUNDLES.items():
        zip_dir(folder, DIST / name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
