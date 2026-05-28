#!/usr/bin/env python3
"""One-shot branding patch: logo, title-stack heroes, user-friendly GitHub copy."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "website"

LOGO_OLD = re.compile(
    r'<a class="logo" href="index\.html">\s*'
    r'<span class="logo-mark"[^>]*>.*?</span>\s*'
    r'Hacker Planet\s*'
    r"</a>",
    re.DOTALL,
)
LOGO_NEW = """<a class="logo" href="index.html">
        <span class="logo-brand">Hacker Planet</span>
        <span class="logo-tagline">Security that doesn't hide behind glass</span>
      </a>"""

H1_REPLACEMENTS: dict[str, tuple[str, str]] = {
    "index.html": (
        r'<h1 class="reveal">Hacker Planet[^<]*(?:<br\s*/>)?[^<]*</h1>',
        """<h1 class="title-stack reveal">
        <span class="title-stack-main">Hacker Planet</span>
        <span class="title-stack-layer">Security that doesn't hide behind glass</span>
      </h1>""",
    ),
    "hacker-planet.html": (
        r"<h1>Hacker Planet[^<]*</h1>",
        """<h1 class="title-stack">
        <span class="title-stack-main">Hacker Planet</span>
        <span class="title-stack-layer">Official site of Hacker Planet LLC</span>
      </h1>""",
    ),
    "about.html": (
        r"<h1>Defensive security with a human face</h1>",
        """<h1 class="title-stack">
        <span class="title-stack-main">Defensive security</span>
        <span class="title-stack-layer">with a human face</span>
      </h1>""",
    ),
    "services.html": (
        r"<h1>Professional security services</h1>",
        """<h1 class="title-stack">
        <span class="title-stack-main">Professional security</span>
        <span class="title-stack-layer">services for labs &amp; MSPs</span>
      </h1>""",
    ),
    "cybersecurity-philadelphia.html": (
        r"<h1>Hacker Planet[^<]*</h1>",
        """<h1 class="title-stack">
        <span class="title-stack-main">Hacker Planet</span>
        <span class="title-stack-layer">Cybersecurity for Philadelphia &amp; remote US clients</span>
      </h1>""",
    ),
    "cyberthreatgotchi.html": (
        r"<h1>CyberThreatGotchi</h1>",
        """<h1 class="title-stack">
        <span class="title-stack-main">CyberThreatGotchi</span>
        <span class="title-stack-layer">Edge IPS with a Tamagotchi soul</span>
      </h1>""",
    ),
    "crackbot.html": (
        r"<h1>Mr\. CrackBot AI Nano</h1>",
        """<h1 class="title-stack">
        <span class="title-stack-main">Mr. CrackBot AI Nano</span>
        <span class="title-stack-layer">Jetson bench lab assistant</span>
      </h1>""",
    ),
    "cardputer.html": (
        r"<h1>Remote Possibility &amp; BLE Bot</h1>",
        """<h1 class="title-stack">
        <span class="title-stack-main">Remote Possibility &amp; BLE Bot</span>
        <span class="title-stack-layer">M5 Cardputer field tools</span>
      </h1>""",
    ),
    "ecosystem.html": (
        r"<h1>Desk & field toolkit</h1>",
        """<h1 class="title-stack">
        <span class="title-stack-main">Desk &amp; field toolkit</span>
        <span class="title-stack-layer">Four open-source GitHub projects</span>
      </h1>""",
    ),
    "shop.html": (
        r"<h1>Support open defense</h1>",
        """<h1 class="title-stack">
        <span class="title-stack-main">Support open defense</span>
        <span class="title-stack-layer">Kits, Pro feed, STLs</span>
      </h1>""",
    ),
    "github.html": (
        r"<h1>On GitHub</h1>",
        """<h1 class="title-stack">
        <span class="title-stack-main">On GitHub</span>
        <span class="title-stack-layer">Open source, releases &amp; firmware</span>
      </h1>""",
    ),
    "contact.html": (
        r"<h1>Salvador Data</h1>",
        """<h1 class="title-stack">
        <span class="title-stack-main">Salvador Data</span>
        <span class="title-stack-layer">Hacker Planet LLC · Philadelphia</span>
      </h1>""",
    ),
    "kickstarter.html": (
        r"<h1>CyberThreatGotchi<br\s*/>Edge IPS with a Tamagotchi soul</h1>",
        """<h1 class="title-stack">
        <span class="title-stack-main">CyberThreatGotchi</span>
        <span class="title-stack-layer">Edge IPS with a Tamagotchi soul</span>
      </h1>""",
    ),
    "cyd.html": (
        r"<h1>CYD Field Build</h1>",
        """<h1 class="title-stack">
        <span class="title-stack-main">CYD Field Build</span>
        <span class="title-stack-layer">Pocket lab hardware</span>
      </h1>""",
    ),
}

COPY_REPLACEMENTS = [
    (re.compile(r'(class="nav-cta"[^>]*>)Repo[^<]*(</a>)', re.I), r"\1GitHub ↗\2"),
    (re.compile(r">Repo\s*↗?</a>", re.I), ">GitHub ↗</a>"),
    (re.compile(r">Repo\s*â†—</a>", re.I), ">GitHub ↗</a>"),
    (r">View repo ?</a>", ">View on GitHub ↗</a>"),
    (r">View repo ↗</a>", ">View on GitHub ↗</a>"),
    (r"MIT core, public repo", "MIT core, open source on GitHub"),
    (r"Four open-source repos from", "Four open-source GitHub projects from"),
    (r"between repos —", "between projects —"),
    (r"Open-source repo and STLs", "Open source on GitHub and STLs"),
    (r"Clone the repo,", "Clone from GitHub,"),
    (r">GitHub repo ↗</a>", ">GitHub project ↗</a>"),
    (r">GitHub repo â†—</a>", ">GitHub project ↗</a>"),
    (r"Clone the repo to run", "Clone from GitHub to run"),
    (r"repository ↗</a>", "on GitHub ↗</a>"),
    (r"repository ?</a>", "on GitHub ↗</a>"),
    (r"<h3>Main repository</h3>", "<h3>Main GitHub project</h3>"),
    (r"Star the repo,", "Star on GitHub,"),
    (r"mirrored in the repo at", "mirrored in the open-source tree at"),
    (r"documented in our open repo", "documented in our open-source docs"),
    (r"Full campaign copy in repo:", "Full campaign copy on GitHub:"),
    (r"Clone the repo and use", "Clone from GitHub and use"),
    (r"all ecosystem repos", "all ecosystem GitHub projects"),
    (r"document everything in the repo,", "document everything on GitHub,"),
    (r"Separate repo,", "Separate GitHub project,"),
    (r"ship in the repo", "ship on GitHub"),
    (r"Issues, PRs, and releases for all ecosystem repos", "Issues, PRs, and releases for all ecosystem GitHub projects"),
]


def patch_file(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    orig = text
    text = LOGO_OLD.sub(LOGO_NEW, text)
    name = path.name
    if name in H1_REPLACEMENTS:
        pattern, repl = H1_REPLACEMENTS[name]
        text, n = re.subn(pattern, repl, text, count=1, flags=re.DOTALL | re.IGNORECASE)
        if n == 0:
            raise SystemExit(f"{name}: h1 pattern not found")
    for old, new in COPY_REPLACEMENTS:
        if isinstance(old, re.Pattern):
            text = old.sub(new, text)
        else:
            text = text.replace(old, new)
    if text != orig:
        path.write_text(text, encoding="utf-8")
        print(f"patched {path.name}")


def main() -> None:
    for html in sorted(WEB.glob("*.html")):
        patch_file(html)
    print("done")


if __name__ == "__main__":
    main()
