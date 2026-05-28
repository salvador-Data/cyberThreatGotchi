"""Release packaging script."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_package_release_creates_zips(tmp_path, monkeypatch):
    # Use temp dist dir
    import scripts.package_release as pkg

    monkeypatch.setattr(pkg, "DIST", tmp_path / "dist")
    monkeypatch.setattr(
        pkg,
        "BUNDLES",
        {
            "marketing-graphics.zip": ROOT / "docs" / "images",
            "sprites.zip": ROOT / "assets" / "sprites" / "png",
        },
    )
    if not (ROOT / "docs" / "images" / "hero.png").is_file():
        subprocess.run([sys.executable, str(ROOT / "assets" / "marketing" / "generate_graphics.py")], check=True)
    assert pkg.main() == 0
    assert (tmp_path / "dist" / "marketing-graphics.zip").is_file()
    assert (tmp_path / "dist" / "sprites.zip").is_file()
