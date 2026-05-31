#!/usr/bin/env python3
"""
Gatekeeper.TOR — Xfce systray toggle (Tor | HTTPS).
Active mode shows lit neon icon; inactive menu items are dim gray.
Authorized defensive lab use only · Hacker Planet LLC
"""
from __future__ import annotations

import os
import subprocess
import sys
import threading
from pathlib import Path

GK_ROOT = Path(os.environ.get("CTG_GATEKEEPER_ROOT", "/opt/ctg/gatekeeper-tor"))
DAEMON = GK_ROOT / "gatekeeper-daemon.sh"
ASSETS = GK_ROOT / "assets"
MODE_FILE = Path(os.environ.get("CTG_GATEKEEPER_MODE_FILE", "/var/lib/ctg/gatekeeper-mode"))


def run_cmd(args: list[str], timeout: int = 20) -> str:
    try:
        proc = subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        return (proc.stdout or proc.stderr or "").strip()
    except (OSError, subprocess.TimeoutExpired) as exc:
        return str(exc)


def read_mode() -> str:
    if MODE_FILE.is_file():
        raw = MODE_FILE.read_text(encoding="utf-8").strip().lower()
        if raw in ("https", "http", "clearnet"):
            return "https"
        return "tor"
    return "tor"


def set_mode(mode: str) -> None:
    normalized = "https" if mode.lower() in ("https", "http", "clearnet") else "tor"
    if DAEMON.is_file():
        run_cmd(["sudo", str(DAEMON), "set-mode", normalized])
    else:
        MODE_FILE.parent.mkdir(parents=True, exist_ok=True)
        MODE_FILE.write_text(normalized, encoding="utf-8")
    _sync_python_state(normalized)


def _sync_python_state(mode: str) -> None:
    for candidate in (
        Path("/opt/ctg/core/gatekeeper_tor.py"),
        GK_ROOT / "core" / "gatekeeper_tor.py",
    ):
        if candidate.is_file():
            run_cmd([sys.executable, str(candidate), "set-mode", mode])
            break


def icon_path(mode: str) -> Path:
    lit = read_mode() == mode
    suffix = "on" if lit else "off"
    if mode == "https":
        name = f"logo-https-{suffix}.png"
    else:
        name = f"logo-tor-{suffix}.png"
    path = ASSETS / name
    if path.is_file():
        return path
    fallback = GK_ROOT / "logo.svg"
    return fallback if fallback.is_file() else path


def tooltip_text() -> str:
    mode = read_mode()
    try:
        repo = GK_ROOT.parent.parent
        if (repo / "core" / "gatekeeper_tor.py").is_file():
            sys.path.insert(0, str(repo))
        sys.path.insert(0, "/opt/ctg")
        from core.gatekeeper_tor import panel_tooltip  # noqa: WPS433

        return panel_tooltip(mode)
    except ImportError:
        return "● TOR active" if mode == "tor" else "○ HTTPS active"


def run_health() -> None:
    if DAEMON.is_file():
        run_cmd(["sudo", str(DAEMON), "health"], timeout=45)


def _load_pystray():
    try:
        import pystray
        from PIL import Image
    except ImportError:
        return None, None
    return pystray, Image


def _load_image(mode: str, Image):
    path = icon_path(mode)
    if path.is_file() and path.suffix.lower() == ".png":
        return Image.open(path).convert("RGBA")
    if path.is_file():
        return Image.open(path).convert("RGBA")
    lit = read_mode() == mode
    color = (184, 255, 0, 255) if lit and mode == "tor" else (
        (0, 180, 255, 255) if lit else (120, 120, 120, 255)
    )
    img = Image.new("RGBA", (64, 64), (13, 17, 23, 255))
    from PIL import ImageDraw

    draw = ImageDraw.Draw(img)
    draw.polygon([(32, 8), (52, 18), (52, 38), (32, 56), (12, 38), (12, 18)], fill=color)
    draw.text((26, 20), "G", fill=(13, 17, 23, 255) if lit else (200, 200, 200, 255))
    return img


def main() -> int:
    pystray, Image = _load_pystray()
    if pystray is None or Image is None:
        print(
            "pystray/PIL not installed. Install: sudo apt install -y python3-pil python3-pystray",
            file=sys.stderr,
        )
        print(f"Current mode: {read_mode()} — use: sudo {DAEMON} set-mode tor|https")
        return 1

    icon_holder: dict = {"icon": None}

    def refresh(_icon=None, _item=None):
        mode = read_mode()
        if icon_holder["icon"]:
            icon_holder["icon"].title = tooltip_text()
            icon_holder["icon"].icon = _load_image(mode, Image)
            icon_holder["icon"].update_menu()

    def on_tor(_icon, _item):
        set_mode("tor")
        refresh()

    def on_https(_icon, _item):
        set_mode("https")
        refresh()

    def on_health(_icon, _item):
        threading.Thread(target=run_health, daemon=True).start()

    def on_quit(icon, _item):
        icon.stop()

    def checked_tor(_item):
        return read_mode() == "tor"

    def checked_https(_item):
        return read_mode() == "https"

    def label_tor(_item):
        return "✓ TOR (lit)" if read_mode() == "tor" else "  TOR"

    def label_https(_item):
        return "✓ HTTPS (lit)" if read_mode() == "https" else "  HTTPS"

    menu = pystray.Menu(
        pystray.MenuItem(label_tor, on_tor, checked=checked_tor),
        pystray.MenuItem(label_https, on_https, checked=checked_https),
        pystray.MenuItem("Health check", on_health),
        pystray.MenuItem("Quit", on_quit),
    )

    mode = read_mode()
    icon = pystray.Icon(
        "gatekeeper-tor",
        _load_image(mode, Image),
        tooltip_text(),
        menu,
    )
    icon_holder["icon"] = icon
    icon.run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
