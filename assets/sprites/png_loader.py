"""Load mood-based PNG sprites for web UI and e-ink."""

from __future__ import annotations

from pathlib import Path

PNG_DIR = Path(__file__).resolve().parent / "png"
MOODS = ("idle", "happy", "alert", "attack", "sleep", "feed", "defend")


def sprite_path(mood: str) -> Path | None:
    key = mood.lower() if mood.lower() in MOODS else "idle"
    path = PNG_DIR / f"{key}.png"
    return path if path.is_file() else None


def list_sprites() -> list[str]:
    if not PNG_DIR.is_dir():
        return []
    return sorted(p.stem for p in PNG_DIR.glob("*.png"))
