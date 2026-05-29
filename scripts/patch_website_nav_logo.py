#!/usr/bin/env python3
"""Patch public website HTML: logo nav, cart scripts, hero copy."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "website"

LOGO_OLD = re.compile(
    r'<a class="logo" href="index\.html">\s*'
    r'<img class="logo-img" src="images/hacker-planet-logo\.png" width="134" height="32" '
    r'alt="Hacker Planet LLC" decoding="async" />\s*'
    r'<span class="logo-text">\s*'
    r'<span class="logo-brand">Hacker Planet</span>\s*'
    r'<span class="logo-tagline">Security that doesn\'t hide behind glass</span>\s*'
    r"</span>\s*</a>",
    re.S,
)

LOGO_NEW = (
    '<a class="logo" href="index.html" aria-label="Hacker Planet LLC home">\n'
    '        <img class="logo-img" src="images/hacker-planet-logo.png" width="134" height="32" '
    'alt="Hacker Planet LLC" decoding="async" />\n'
    '        <span class="logo-brand">Hacker Planet LLC</span>\n'
    "      </a>"
)

CART_SCRIPTS = (
    '  <script src="js/payments.config.js"></script>\n'
    '  <script src="js/cart.js"></script>\n'
    '  <script src="js/payments.js"></script>\n'
)


def patch_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    original = text

    text = LOGO_OLD.sub(LOGO_NEW, text)

    text = text.replace(
        "<span class=\"title-stack-layer\">Security that doesn't hide behind glass</span>",
        '<span class="title-stack-layer">Philadelphia cybersecurity lab</span>',
    )

    if "js/cart.js" not in text:
        text = text.replace(
            '  <script src="js/main.js"></script>',
            CART_SCRIPTS + '  <script src="js/main.js"></script>',
            1,
        )

    text = text.replace(
        '  <script src="js/payments.config.js"></script>\n'
        '  <script src="js/payments.js"></script>\n'
        '  <script src="js/cart.js"></script>\n',
        CART_SCRIPTS,
    )

    if text != original:
        path.write_text(text, encoding="utf-8")
        return True
    return False


def main() -> None:
    changed = []
    for html in sorted(WEB.glob("*.html")):
        if patch_file(html):
            changed.append(html.name)
    print("Patched:", ", ".join(changed) if changed else "(none)")


if __name__ == "__main__":
    main()
