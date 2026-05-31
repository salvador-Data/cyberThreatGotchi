"""
Gatekeeper.TOR — mode state and health checks (authorized lab / defensive privacy only).

Modes:
  tor   — client Tor via SOCKS 127.0.0.1:9050 (Tor Project crypto stack)
  https — clearnet; Gatekeeper health probe prefers TLS 1.3 / AES-256-GCM (curl only)

State JSON lives under Backups (gitignored), never in the repo.
Hacker Planet LLC · CyberThreatGotchi
"""
from __future__ import annotations

import json
import os
import platform
import shutil
import subprocess
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path
from typing import Any


class GatekeeperMode(str, Enum):
    TOR = "tor"
    HTTPS = "https"


@dataclass
class GatekeeperState:
    mode: str = GatekeeperMode.TOR.value
    tor_enabled: bool = True
    updated_at: str = ""
    last_health: dict[str, Any] | None = None
    ddg_coexistence_note: str = (
        "Preserve DuckDuckGo VPN/DNS/PM on Windows; Gatekeeper does not replace DDG."
    )

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> GatekeeperState:
        mode = str(data.get("mode", GatekeeperMode.TOR.value)).lower()
        if mode not in (GatekeeperMode.TOR.value, GatekeeperMode.HTTPS.value):
            mode = GatekeeperMode.TOR.value
        return cls(
            mode=mode,
            tor_enabled=bool(data.get("tor_enabled", mode == GatekeeperMode.TOR.value)),
            updated_at=str(data.get("updated_at", "")),
            last_health=data.get("last_health"),
            ddg_coexistence_note=str(
                data.get("ddg_coexistence_note", cls.ddg_coexistence_note)
            ),
        )


def _default_state_dir() -> Path:
    if platform.system() == "Windows":
        base = Path(os.environ.get("USERPROFILE", Path.home())) / "Backups" / "gatekeeper-tor"
    else:
        base = Path("/var/lib/ctg/gatekeeper-tor")
    return base


def state_file_path() -> Path:
    override = os.environ.get("CTG_GATEKEEPER_STATE_FILE", "").strip()
    if override:
        return Path(override)
    return _default_state_dir() / "state.json"


def load_state() -> GatekeeperState:
    path = state_file_path()
    if not path.is_file():
        return GatekeeperState(
            updated_at=datetime.now(timezone.utc).isoformat(),
        )
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return GatekeeperState.from_dict(data)
    except (OSError, json.JSONDecodeError, TypeError):
        return GatekeeperState(updated_at=datetime.now(timezone.utc).isoformat())


def save_state(state: GatekeeperState) -> Path:
    path = state_file_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    state.updated_at = datetime.now(timezone.utc).isoformat()
    path.write_text(json.dumps(state.to_dict(), indent=2), encoding="utf-8")
    return path


def normalize_mode(mode: str) -> GatekeeperMode:
    m = (mode or "").strip().lower()
    if m in ("http", "https", "clearnet"):
        return GatekeeperMode.HTTPS
    return GatekeeperMode.TOR


def scrambler_mode_for_gatekeeper(mode: GatekeeperMode) -> str:
    """Map Gatekeeper mode to legacy scrambler-daemon mode names."""
    if mode == GatekeeperMode.HTTPS:
        return "http"
    return "tor"


def repo_assets_dir() -> Path:
    """Monorepo assets/gatekeeper-tor (works from checkout or /opt/ctg)."""
    here = Path(__file__).resolve().parent
    for candidate in (
        here.parent / "assets" / "gatekeeper-tor",
        Path("/opt/ctg/gatekeeper-tor/assets"),
        Path("/opt/ctg/assets/gatekeeper-tor"),
    ):
        if candidate.is_dir():
            return candidate
    return here.parent / "assets" / "gatekeeper-tor"


def icon_filename(mode: str, *, lit: bool) -> str:
    gm = normalize_mode(mode)
    suffix = "on" if lit else "off"
    if gm == GatekeeperMode.HTTPS:
        return f"logo-https-{suffix}.png"
    return f"logo-tor-{suffix}.png"


def icon_path_for_mode(mode: str, *, lit: bool | None = None) -> Path:
    """Return tray icon PNG for active (lit) or inactive (dim) mode."""
    state = load_state()
    active = normalize_mode(mode or state.mode)
    if lit is None:
        lit = active == normalize_mode(state.mode)
    assets = repo_assets_dir()
    return assets / icon_filename(active.value, lit=lit)


def tray_tooltip(mode: str | None = None) -> str:
    """Human-readable tray tooltip with lit indicator."""
    gm = normalize_mode(mode or load_state().mode)
    label = "TOR" if gm == GatekeeperMode.TOR else "HTTPS"
    return f"Gatekeeper.TOR — {label} (lit)"


def panel_tooltip(mode: str | None = None) -> str:
    """Xfce systray tooltip: filled dot = active mode."""
    gm = normalize_mode(mode or load_state().mode)
    if gm == GatekeeperMode.TOR:
        return "● TOR active"
    return "○ HTTPS active"


def set_mode(mode: str, *, tor_enabled: bool | None = None) -> GatekeeperState:
    gm = normalize_mode(mode)
    state = load_state()
    state.mode = gm.value
    if tor_enabled is None:
        state.tor_enabled = gm == GatekeeperMode.TOR
    else:
        state.tor_enabled = tor_enabled
    save_state(state)
    return state


def _curl_base() -> list[str]:
    curl = shutil.which("curl") or shutil.which("curl.exe")
    if not curl:
        return []
    return [curl]


def health_check_https(timeout: int = 15) -> dict[str, Any]:
    """
    Clearnet probe: request TLS 1.3 where curl supports --tlsv1.3.
    Documents honest crypto — not a system-wide VPN or fake product claims.
    """
    curl = _curl_base()
    if not curl:
        return {"ok": False, "error": "curl not found", "tls": "unknown"}
    url = os.environ.get(
        "CTG_GATEKEEPER_HTTPS_PROBE_URL",
        "https://www.cloudflare.com/cdn-cgi/trace",
    )
    cmd = [
        curl,
        "-sS",
        "--max-time",
        str(timeout),
        "--tlsv1.3",
        "-w",
        "%{http_code}|%{ssl_verify_result}|%{time_total}",
        "-o",
        "/dev/null" if platform.system() != "Windows" else "NUL",
        url,
    ]
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout + 5,
            check=False,
        )
        tail = (proc.stdout or proc.stderr or "").strip().split("|")
        ok = proc.returncode == 0 and len(tail) >= 1 and tail[0].startswith("2")
        return {
            "ok": ok,
            "http_code": tail[0] if tail else "",
            "ssl_verify": tail[1] if len(tail) > 1 else "",
            "time_total": tail[2] if len(tail) > 2 else "",
            "tls_preference": "TLS 1.3 (curl --tlsv1.3); cipher suite negotiated by OS (often AES-256-GCM)",
            "url": url,
        }
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"ok": False, "error": str(exc), "tls_preference": "TLS 1.3"}


def health_check_tor(timeout: int = 20) -> dict[str, Any]:
    """Probe check.torproject.org API via SOCKS5 127.0.0.1:9050."""
    curl = _curl_base()
    socks = os.environ.get("CTG_GATEKEEPER_SOCKS", "127.0.0.1:9050")
    api = os.environ.get(
        "CTG_GATEKEEPER_TOR_CHECK_URL",
        "https://check.torproject.org/api/ip",
    )
    if not curl:
        return {"ok": False, "error": "curl not found", "IsTor": False}
    cmd = [
        curl,
        "-sS",
        "--max-time",
        str(timeout),
        "--socks5-hostname",
        socks,
        api,
    ]
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout + 5,
            check=False,
        )
        body = (proc.stdout or "").strip()
        is_tor = False
        if proc.returncode == 0 and body:
            try:
                payload = json.loads(body)
                is_tor = bool(payload.get("IsTor"))
            except json.JSONDecodeError:
                is_tor = "IsTor" in body and "true" in body.lower()
        return {
            "ok": proc.returncode == 0 and is_tor,
            "IsTor": is_tor,
            "socks": socks,
            "raw_preview": body[:200] if body else "",
        }
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"ok": False, "error": str(exc), "IsTor": False}


def run_health_for_mode(mode: str | None = None) -> dict[str, Any]:
    gm = normalize_mode(mode or load_state().mode)
    if gm == GatekeeperMode.TOR:
        result = health_check_tor()
        result["mode"] = gm.value
    else:
        result = health_check_https()
        result["mode"] = gm.value
    state = load_state()
    state.last_health = result
    save_state(state)
    return result


def fetch_tor_check_json_no_proxy(timeout: int = 10) -> dict[str, Any]:
    """Direct urllib fallback when curl missing (clearnet only — not via Tor)."""
    url = "https://check.torproject.org/api/ip"
    try:
        with urllib.request.urlopen(url, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, json.JSONDecodeError, TimeoutError) as exc:
        return {"error": str(exc), "IsTor": False}


def cli_main(argv: list[str] | None = None) -> int:
    import sys

    args = argv if argv is not None else sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(
            "gatekeeper_tor.py {status|set-mode|health} [tor|https]\n"
            "State: CTG_GATEKEEPER_STATE_FILE or default Backups/gatekeeper-tor/state.json"
        )
        return 0
    cmd = args[0]
    if cmd == "status":
        st = load_state()
        print(json.dumps(st.to_dict(), indent=2))
        return 0
    if cmd == "set-mode" and len(args) > 1:
        st = set_mode(args[1])
        print(json.dumps(st.to_dict(), indent=2))
        return 0
    if cmd == "health":
        mode = args[1] if len(args) > 1 else None
        print(json.dumps(run_health_for_mode(mode), indent=2))
        return 0
    print(f"Unknown command: {cmd}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(cli_main())
