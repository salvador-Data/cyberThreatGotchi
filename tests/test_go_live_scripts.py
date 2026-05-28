#!/usr/bin/env python3
"""Tests for go-live helper scripts (no network required for token check)."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_go_live_scripts_exist():
    for name in (
        "scripts/go_live_all.ps1",
        "scripts/cloudflare_apply_dns.py",
        "scripts/github_pages_https.py",
        "scripts/cloudflare/dns-github-pages.bind",
        "docs/GO_LIVE_NOW.md",
    ):
        assert (ROOT / name).is_file(), name


def test_cloudflare_apply_dns_requires_token():
    env = {**dict(**{k: v for k, v in __import__("os").environ.items()}), "CF_API_TOKEN": ""}
    env.pop("CF_API_TOKEN", None)
    r = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "cloudflare_apply_dns.py")],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
        env={k: v for k, v in env.items() if k != "CF_API_TOKEN"},
    )
    assert r.returncode == 1
    assert "CF_API_TOKEN" in r.stderr
