#!/usr/bin/env python3
"""Enable GitHub Pages HTTPS once custom domain DNS is verified."""

from __future__ import annotations

import json
import os
import shutil
import ssl
import subprocess
import sys


def _gh_executable() -> str:
    env = os.environ.get("GH_PATH", "").strip()
    if env:
        return env
    found = shutil.which("gh")
    if found:
        return found
    for candidate in (
        r"C:\Program Files\GitHub CLI\gh.exe",
        r"C:\Program Files (x86)\GitHub CLI\gh.exe",
    ):
        if os.path.isfile(candidate):
            return candidate
    return "gh"


def _pages_get(gh: str, repo: str) -> tuple[int, dict | None, str]:
    status = subprocess.run(
        [gh, "api", f"repos/{repo}/pages"],
        capture_output=True,
        text=True,
    )
    if status.returncode != 0:
        return status.returncode, None, status.stderr
    return 0, json.loads(status.stdout), ""


def _cert_hint(cname: str | None) -> str | None:
    if not cname:
        return None
    try:
        pem = ssl.get_server_certificate((cname, 443), timeout=10)
    except OSError:
        return None
    if cname in pem:
        return None
    if "github.io" in pem or "github.com" in pem:
        return (
            f"Live TLS still presents GitHub's default cert (not {cname}). "
            "Browsers show ERR_CERT_COMMON_NAME_INVALID until GitHub issues "
            "the custom-domain certificate."
        )
    return None


def _explain_https_failure(pages: dict, stderr: str) -> None:
    cert = pages.get("https_certificate") or {}
    state = cert.get("state")
    desc = cert.get("description")
    if state or desc:
        print(f"https_certificate.state={state!r}", file=sys.stderr)
        if desc:
            print(f"https_certificate.description={desc}", file=sys.stderr)

    err = stderr.strip()
    if "certificate has not yet been issued" in err or "certificate does not exist yet" in err:
        print(
            "\nGitHub has not finished Let's Encrypt for this custom domain yet. "
            "Keep Cloudflare A/CNAME records on DNS only (grey cloud), wait up to "
            "24h, then re-run this script.",
            file=sys.stderr,
        )
        print(
            "While waiting, HTTPS may fail with ERR_CERT_COMMON_NAME_INVALID "
            "(cert CN is *.github.io, not your domain). HTTP should work.",
            file=sys.stderr,
        )
        return

    if "DNS" in err or "verified" in err.lower():
        print(
            "\nEnsure apex has four GitHub Pages A records (185.199.108–111.153) "
            "and www CNAME -> salvador-Data.github.io, all grey-cloud in Cloudflare.",
            file=sys.stderr,
        )


def main() -> int:
    gh = _gh_executable()
    repo = "salvador-Data/cyberThreatGotchi"
    code, pages, err = _pages_get(gh, repo)
    if code != 0 or pages is None:
        print(err, file=sys.stderr)
        return 1

    cname = pages.get("cname")
    enforced = pages.get("https_enforced")
    print(f"cname={cname} https_enforced={enforced}")

    cert = pages.get("https_certificate") or {}
    if cert:
        print(
            f"https_certificate.state={cert.get('state')} "
            f"domains={cert.get('domains')}"
        )

    hint = _cert_hint(cname if isinstance(cname, str) else None)
    if hint:
        print(f"note: {hint}")

    if enforced:
        print("HTTPS already enforced.")
        return 0

    put = subprocess.run(
        [
            gh,
            "api",
            "-X",
            "PUT",
            f"repos/{repo}/pages",
            "--input",
            "-",
        ],
        input=json.dumps(
            {
                "cname": cname,
                "https_enforced": True,
                "build_type": "legacy",
            }
        ),
        capture_output=True,
        text=True,
    )
    if put.returncode != 0:
        print("GitHub rejected Enforce HTTPS.", file=sys.stderr)
        _explain_https_failure(pages, put.stderr)
        if put.stderr.strip():
            print(put.stderr, file=sys.stderr)
        return 1
    if put.stdout.strip():
        print(json.dumps(json.loads(put.stdout), indent=2))
    print("Enforce HTTPS requested.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
