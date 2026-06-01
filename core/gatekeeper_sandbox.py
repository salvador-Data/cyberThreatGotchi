"""
Gatekeeper sandbox helpers — HTTP allowlist, mode validation (Kali + Windows).

HTTPS = TLS on the wire; sandbox = process/filesystem isolation — complementary.
HTTP clearnet only for lab allowlist hosts; never for banking or credentials.

Hacker Planet LLC · CyberThreatGotchi · authorized defensive lab only
"""
from __future__ import annotations

import json
import os
import platform
import sys
from pathlib import Path
from urllib.parse import urlparse

_ROOT = Path(__file__).resolve().parent.parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

from core.gatekeeper_tor import GatekeeperMode, load_state, normalize_mode

DEFAULT_ALLOWLIST_HEADER = """# CTG HTTP allowlist — lab captive/legacy clearnet only (authorized lab)
# Never use HTTP for banking, credentials, or payments.
# One host per line; # comments allowed.
# lab-ap.local
# captive.portal.example
"""


def default_sandbox_dir() -> Path:
    if platform.system() == "Windows":
        base = Path(os.environ.get("USERPROFILE", Path.home())) / "Backups" / "ctg-sandbox"
    else:
        base = Path("/tmp/ctg-sandbox")
    return base


def http_allowlist_path() -> Path:
    override = os.environ.get("CTG_SANDBOX_ALLOWLIST", "").strip()
    if override:
        return Path(override)
    return default_sandbox_dir() / "http-allowlist.txt"


def ensure_allowlist_file() -> Path:
    path = http_allowlist_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.is_file():
        path.write_text(DEFAULT_ALLOWLIST_HEADER, encoding="utf-8")
    return path


def parse_allowlist(path: Path | None = None) -> set[str]:
    p = path or http_allowlist_path()
    if not p.is_file():
        return set()
    hosts: set[str] = set()
    for line in p.read_text(encoding="utf-8-sig").splitlines():
        line = line.strip().lstrip("\ufeff")
        if not line or line.startswith("#"):
            continue
        host = line.split()[0].lower().rstrip(".")
        if host:
            hosts.add(host)
    return hosts


def normalize_host(url_or_host: str) -> str:
    raw = (url_or_host or "").strip()
    if "://" in raw:
        parsed = urlparse(raw)
        host = parsed.hostname or ""
    else:
        host = raw.split("/")[0].split(":")[0]
    return host.lower().rstrip(".")


def is_http_url(url: str) -> bool:
    return (url or "").strip().lower().startswith("http://")


def is_https_url(url: str) -> bool:
    return (url or "").strip().lower().startswith("https://")


def host_on_allowlist(url_or_host: str, path: Path | None = None) -> bool:
    host = normalize_host(url_or_host)
    if not host:
        return False
    allowlist = parse_allowlist(path)
    if host in allowlist:
        return True
    for entry in allowlist:
        if entry.startswith(".") and host.endswith(entry):
            return True
        if host.endswith("." + entry):
            return True
    return False


def validate_http_lab_url(url: str, path: Path | None = None) -> tuple[bool, str]:
    if not url.strip():
        return False, "URL required"
    if not is_http_url(url):
        return False, "LaunchHttpLabOnly requires http:// URL"
    if not host_on_allowlist(url, path):
        return False, f"Host not on HTTP allowlist ({http_allowlist_path()})"
    return True, "ok"


def sandbox_mode_allowed(mode: str | None = None) -> tuple[bool, str]:
    """Sandbox browser launch requires HTTPS/clearnet mode (not TOR)."""
    gm = normalize_mode(mode or load_state().mode)
    if gm == GatekeeperMode.HTTPS:
        return True, gm.value
    return False, "HTTPS mode required for sandbox lane (not TOR)"


def validate_launch_url(
    url: str | None,
    *,
    http_lab: bool = False,
    allowlist_path: Path | None = None,
) -> tuple[bool, str, str]:
    """Return (ok, message, normalized_url)."""
    target = (url or "about:blank").strip()
    if target in ("", "about:blank"):
        return True, "ok", "about:blank"
    if http_lab or is_http_url(target):
        ok, msg = validate_http_lab_url(target, allowlist_path)
        return (ok, msg, target) if ok else (False, msg, target)
    if not (is_https_url(target) or target.startswith("about:")):
        return False, "URL must be https:// or allowlisted http://", target
    return True, "ok", target


def diagnose_summary() -> dict[str, object]:
    mode_ok, mode_msg = sandbox_mode_allowed()
    allowlist = http_allowlist_path()
    return {
        "platform": platform.system(),
        "sandbox_dir": str(default_sandbox_dir()),
        "http_allowlist": str(allowlist),
        "allowlist_exists": allowlist.is_file(),
        "allowlist_hosts": sorted(parse_allowlist()),
        "https_mode_active": mode_ok,
        "mode_message": mode_msg,
        "ctg_sandbox_env": os.environ.get("CTG_SANDBOX", ""),
        "ddg_coexistence": (
            "Windows Sandbox is an optional lane; DuckDuckGo VPN/DNS/PM stay primary on host."
        ),
    }


def cli_main(argv: list[str] | None = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(
            "gatekeeper_sandbox.py {diagnose|check-url|check-mode} [url]\n"
            "Allowlist: CTG_SANDBOX_ALLOWLIST or Backups/ctg-sandbox/http-allowlist.txt"
        )
        return 0
    cmd = args[0]
    if cmd == "diagnose":
        print(json.dumps(diagnose_summary(), indent=2))
        return 0
    if cmd == "check-mode":
        ok, msg = sandbox_mode_allowed()
        print(json.dumps({"ok": ok, "message": msg}, indent=2))
        return 0 if ok else 1
    if cmd == "check-url":
        url = args[1] if len(args) > 1 else ""
        http_lab = "--http-lab" in args
        ok, msg, normalized = validate_launch_url(url, http_lab=http_lab)
        print(json.dumps({"ok": ok, "message": msg, "url": normalized}, indent=2))
        return 0 if ok else 1
    print(f"Unknown command: {cmd}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(cli_main())
