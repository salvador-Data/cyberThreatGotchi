"""Export portfolio markdown to standalone HTML (stdlib + optional markdown pip)."""
from __future__ import annotations

import html
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = [
    "PORTFOLIO_FIRMWARE_OS.md",
    "PORTFOLIO_FIRMWARE_OS_SUMMARY.md",
    "PORTFOLIO_SYSTEM_HARDENING.md",
    "PORTFOLIO_SYSTEM_HARDENING_SUMMARY.md",
]

CSS = """
body { font-family: Georgia, 'Times New Roman', serif; max-width: 52rem; margin: 2rem auto; padding: 0 1.25rem; line-height: 1.55; color: #1a1a1a; }
h1,h2,h3 { font-family: 'Segoe UI', system-ui, sans-serif; color: #0d3b66; }
pre, code { font-family: Consolas, monospace; background: #f4f4f4; }
pre { padding: 1rem; overflow-x: auto; border-left: 4px solid #0d3b66; }
a { color: #1565c0; }
header { border-bottom: 2px solid #0d3b66; margin-bottom: 1.5rem; padding-bottom: 0.5rem; }
footer { margin-top: 2rem; font-size: 0.9rem; color: #555; }
"""


def render_body(text: str) -> str:
    try:
        import markdown  # type: ignore

        return markdown.markdown(
            text,
            extensions=["extra", "tables", "fenced_code", "nl2br"],
        )
    except ImportError:
        return f"<pre>{html.escape(text)}</pre>"


def main() -> int:
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs" / "portfolio_export"
    out_dir.mkdir(parents=True, exist_ok=True)
    for name in DOCS:
        src = ROOT / "docs" / name
        if not src.is_file():
            print(f"skip missing: {src}", file=sys.stderr)
            continue
        body = render_body(src.read_text(encoding="utf-8"))
        out = out_dir / name.replace(".md", ".html")
        page = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(name)}</title>
<style>{CSS}</style>
</head>
<body>
<header><p>Hacker Planet LLC — Andy Kowal · salvador-Data</p></header>
<article>{body}</article>
<footer><p>Authorized defensive use only. Source: cyberThreatGotchi/docs/{html.escape(name)}</p></footer>
</body>
</html>
"""
        out.write_text(page, encoding="utf-8")
        print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
