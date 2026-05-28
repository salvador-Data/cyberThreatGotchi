#!/usr/bin/env python3
"""Normalize public website copy to ASCII-only user-visible punctuation."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "website"

# Mojibake from UTF-8 misread as Latin-1/Windows-1252.
MOJIBAKE = {
    "â˜°": "&#9776;",
    "Â·": " | ",
    "â€”": " - ",
    "â€“": "-",
    "â€‘": "-",
    "Wiâ€‘Fi": "Wi-Fi",
    "Wiâ€Fi": "Wi-Fi",
    "â†’": "->",
    "â†—": "->",
    "Â©": "&copy;",
    "Ã—": "x",
    "â€³": '"',
    "â€¦": "...",
    "â€œ": '"',
    "â€\x9d": '"',
    "â€": '"',
    "ï»¿": "",
}

UNICODE_TO_ASCII = {
    "\u2014": " - ",
    "\u2013": "-",
    "\u00b7": " | ",
    "\u2192": "->",
    "\u2197": "->",
    "\u00a9": "&copy;",
    "\u2026": "...",
    "\u2018": "'",
    "\u2019": "'",
    "\u201c": '"',
    "\u201d": '"',
    "\u00d7": "x",
    "\u2033": '"',
    "\u2011": "-",
    "\u2190": "<-",
    "\u25c6": "*",
    "\u2713": "OK ",
    "\u2605": "*",
    "\u2022": "*",
    "\u2193": "v",
    "\u2191": "^",
}

CARD_ICON_LABELS = {
    "card-accent-ctg": "CTG",
    "card-accent-bj": "BJ",
    "card-accent-cb": "CB",
    "card-accent-m5": "M5",
}

CONTACT_HEADINGS = {
    "?? Email  -  reach us now": "Email - reach us now",
    "?? Email — reach us now": "Email - reach us now",
    "?? Business phone": "Business phone",
    "??? Blue Team": "Blue Team",
    "?? Red Team": "Red Team",
    "?? OSINT": "OSINT",
    "?? MSP &amp; retainers": "MSP &amp; retainers",
    "?? Shop &amp; platform": "Shop &amp; platform",
    "?? GitHub": "GitHub",
    "?? Reddit": "Reddit",
    "?? Facebook": "Facebook",
    "??? 2600 / meetups": "2600 / meetups",
    "?? Resources": "Resources",
}

JS_STRING_REPLACEMENTS = {
    "Repo access, STL zip, sprites, release assets": "GitHub bundle, STL zip, sprites, release assets",
    "Full repo assets, STL zip, sprites, marketing graphics — instant link.": (
        "Full GitHub bundle, STL zip, sprites, marketing graphics - instant link."
    ),
    "Full repo assets, STL zip, sprites, marketing graphics  -  instant link.": (
        "Full GitHub bundle, STL zip, sprites, marketing graphics - instant link."
    ),
    "Repo bundle": "GitHub bundle",
}

EMOJI_TO_ASCII = {
    "\U0001f4b3": "",
    "\U0001f17f\ufe0f": "",
    "\U0001f4f1": "",
    "\U0001f4b5": "",
    "\U0001f6cd\ufe0f": "Shop",
    "\U0001f4e6": "Box",
    "\U0001f527": "Kit",
    "\U0001f4bb": "Code",
    "\U0001f5a8\ufe0f": "Print",
    "\U0001fa90": "HPL",
    "\U0001f4cd": "Ship",
    "\U0001f4ec": "Partner",
    "\u2328\ufe0f": "Code",
    "\u2630": "&#9776;",
}

CARD_ICON_MOJIBAKE = {
    "ðŸ›¡ï¸\x8f": "BT",
    "ðŸ›¡ï¸": "BT",
    "ðŸŽ¯": "RT",
    'ðŸ"\x8d': "OS",
    'ðŸ"': "OS",
}


def _tidy_spacing(text: str) -> str:
    text = re.sub(r"  \|  ", " | ", text)
    text = re.sub(r"  -  ", " - ", text)
    text = re.sub(r"  - \s*\n", " -\n", text)
    text = re.sub(r"  - $", " -", text, flags=re.M)
    return text


def normalize_text(text: str) -> str:
    if text.startswith("\ufeff"):
        text = text.lstrip("\ufeff")
    for bad, good in MOJIBAKE.items():
        text = text.replace(bad, good)
    for bad, good in CARD_ICON_MOJIBAKE.items():
        text = text.replace(bad, good)
    for bad, good in UNICODE_TO_ASCII.items():
        text = text.replace(bad, good)
    for bad, good in CONTACT_HEADINGS.items():
        text = text.replace(f"<h3>{bad}</h3>", f"<h3>{good}</h3>")
    for cls, label in CARD_ICON_LABELS.items():
        text = text.replace(f'class="card-icon {cls}">??</div>', f'class="card-icon {cls}">{label}</div>')
        text = text.replace(f'class="card-icon {cls}">?</div>', f'class="card-icon {cls}">{label}</div>')
    text = re.sub(r" \?</a>", " -></a>", text)
    text = re.sub(
        r'(<button class="nav-toggle"[^>]*>)\?(</button>)',
        r"\1&#9776;\2",
        text,
    )
    text = text.replace("? Star on GitHub", "Star on GitHub")
    text = text.replace("# ? http", "# -> http")
    text = text.replace("Enable Pages once ? salvador", "Enable Pages once -> salvador")
    text = re.sub(
        r'(<button class="nav-toggle"[^>]*>)☰(</button>)',
        r"\1&#9776;\2",
        text,
    )
    return _tidy_spacing(text)


def normalize_js(text: str) -> str:
    for bad, good in MOJIBAKE.items():
        text = text.replace(bad, good)
    for bad, good in UNICODE_TO_ASCII.items():
        text = text.replace(bad, good)
    for bad, good in JS_STRING_REPLACEMENTS.items():
        text = text.replace(bad, good)
    for bad, good in EMOJI_TO_ASCII.items():
        text = text.replace(bad, good)
    text = re.sub(r',\s*""', "", text)
    text = re.sub(r'icon:\s*""', 'icon: ""', text)
    text = re.sub(r'icon:\s*"↗"', 'icon: "->"', text)
    return _tidy_spacing(text)


def normalize_css(text: str) -> str:
    for bad, good in MOJIBAKE.items():
        text = text.replace(bad, good)
    for bad, good in UNICODE_TO_ASCII.items():
        text = text.replace(bad, good)
    text = text.replace('content: "◆";', 'content: "*";')
    text = text.replace('content: "✓ ";', 'content: "OK ";')
    return text


def process_file(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    if path.suffix == ".css":
        updated = normalize_css(original)
    elif path.suffix == ".js":
        updated = normalize_js(original)
    else:
        updated = normalize_text(original)
    if updated != original:
        path.write_text(updated, encoding="utf-8", newline="\n")
        return True
    return False


def main() -> int:
    changed = 0
    targets: list[Path] = []
    targets.extend(sorted(WEB.glob("*.html")))
    targets.extend(sorted((WEB / "js").glob("*.js")))
    targets.append(WEB / "css" / "style.css")
    for path in targets:
        if process_file(path):
            changed += 1
            print(f"updated {path.relative_to(ROOT)}")
    print(f"done: {changed} file(s) updated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
