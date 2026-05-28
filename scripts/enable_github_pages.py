#!/usr/bin/env python3
"""Enable GitHub Pages from the gh-pages branch (requires gh CLI + auth)."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys

REPO = "salvador-Data/cyberThreatGotchi"
BRANCH = "gh-pages"
PATH = "/"


def main() -> int:
    if not shutil.which("gh"):
        print("Install GitHub CLI: https://cli.github.com/", file=sys.stderr)
        print("Then: gh auth login", file=sys.stderr)
        return 1

    payload = [
        "-f",
        f"build_type=legacy",
        "-f",
        f"source[branch]={BRANCH}",
        "-f",
        f"source[path]={PATH}",
    ]

    for method, args in (
        ("POST", ["api", f"repos/{REPO}/pages", *payload]),
        ("PUT", ["api", f"repos/{REPO}/pages", *payload]),
    ):
        r = subprocess.run(["gh", *args], capture_output=True, text=True)
        if r.returncode == 0:
            print(f"GitHub Pages enabled from {BRANCH}{PATH} via {method}")
            try:
                print(json.dumps(json.loads(r.stdout or "{}"), indent=2))
            except json.JSONDecodeError:
                print(r.stdout)
            print(f"\nSite: https://salvador-Data.github.io/cyberThreatGotchi/")
            return 0

    print("gh error:", r.stderr or r.stdout, file=sys.stderr)
    print(
        f"\nManual fix: https://github.com/{REPO}/settings/pages",
        file=sys.stderr,
    )
    print(f"  Branch: {BRANCH} · Folder: (root)", file=sys.stderr)
    return r.returncode or 1


if __name__ == "__main__":
    raise SystemExit(main())
