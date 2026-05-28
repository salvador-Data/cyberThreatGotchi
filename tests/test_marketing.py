"""Marketing graphics exist for GitHub and social."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GEN = ROOT / "assets" / "marketing" / "generate_graphics.py"
IMAGES = ROOT / "docs" / "images"


def test_marketing_images_exist():
    if not (IMAGES / "og-cyberthreatgotchi.png").is_file():
        subprocess.run([sys.executable, str(GEN)], check=True)
    required = [
        "hero.png",
        "og-cyberthreatgotchi.png",
        "og-ecosystem.png",
        "og-bjorn.png",
        "og-crackbot.png",
        "og-m5-cardputer.png",
        "social/facebook-cover.png",
        "social/reddit-banner.png",
        "social/square-cyberthreatgotchi.png",
    ]
    for name in required:
        assert (IMAGES / name).is_file(), name
