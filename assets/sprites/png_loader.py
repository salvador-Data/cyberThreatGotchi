"""Load mood-based PNG sprites for web UI and e-ink."""

from __future__ import annotations

from pathlib import Path

PNG_DIR = Path(__file__).resolve().parent / "png"
MOODS = ("idle", "happy", "alert", "attack", "sleep", "feed", "defend")


def sprite_path(mood: str, frame: int = 0) -> Path | None:
    key = mood.lower() if mood.lower() in MOODS else "idle"
    candidates = (
        PNG_DIR / f"{key}_{frame % 2}.png",
        PNG_DIR / f"{key}.png",
    )
    for path in candidates:
        if path.is_file():
            return path
    if key != "idle":
        return sprite_path("idle", frame)
    return None


def list_sprites() -> list[str]:
    if not PNG_DIR.is_dir():
        return []
    return sorted(p.stem for p in PNG_DIR.glob("*.png"))
