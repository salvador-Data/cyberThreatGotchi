#!/usr/bin/env python3
"""Copy website/ → docs/web/ so the site is browsable in the GitHub repo tree."""

from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "website"
DEST = ROOT / "docs" / "web"

SECURITY_HEAD = """
  <meta http-equiv="X-Content-Type-Options" content="nosniff"/>
  <meta name="referrer" content="strict-origin-when-cross-origin"/>
  <meta http-equiv="Permissions-Policy" content="geolocation=(), microphone=(), camera=()"/>
  <meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self' https://www.paypal.com https://www.paypalobjects.com 'unsafe-inline'; style-src 'self' https://fonts.googleapis.com 'unsafe-inline'; font-src https://fonts.gstatic.com; img-src 'self' https: data:; connect-src 'self' https://www.paypal.com; frame-src https://www.paypal.com; base-uri 'self'; form-action 'self' https://www.paypal.com https://buy.stripe.com https://cash.app https://account.venmo.com;"/>
""".strip()


def _inject_security(html_path: Path) -> None:
    text = html_path.read_text(encoding="utf-8")
    if "Content-Security-Policy" in text:
        return
    text = re.sub(r"(<head>\s*)", r"\1\n" + SECURITY_HEAD + "\n", text, count=1, flags=re.I)
    html_path.write_text(text, encoding="utf-8")


def sync() -> int:
    if not SRC.is_dir():
        print("Missing website/ folder", file=sys.stderr)
        return 1
    for html in SRC.glob("*.html"):
        _inject_security(html)
    if DEST.exists():
        shutil.rmtree(DEST)
    shutil.copytree(SRC, DEST)
    count = sum(1 for _ in DEST.rglob("*") if _.is_file())
    print(f"Synced {SRC} -> {DEST} ({count} files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(sync())
