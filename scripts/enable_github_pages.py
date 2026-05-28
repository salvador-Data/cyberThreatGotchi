#!/usr/bin/env python3
"""Enable GitHub Pages with build_type=workflow (requires gh CLI + auth)."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys

REPO = "salvador-Data/cyberThreatGotchi"


def main() -> int:
    if not shutil.which("gh"):
        print("Install GitHub CLI: https://cli.github.com/", file=sys.stderr)
        print("Then: gh auth login", file=sys.stderr)
        return 1

    # Create or update Pages site to use Actions
    for method, args in (
        ("POST", ["api", f"repos/{REPO}/pages", "-f", "build_type=workflow"]),
        ("PUT", ["api", f"repos/{REPO}/pages", "-f", "build_type=workflow"]),
    ):
        r = subprocess.run(["gh", *args], capture_output=True, text=True)
        if r.returncode == 0:
            print(f"GitHub Pages enabled (build_type=workflow) via {method}")
            try:
                print(json.dumps(json.loads(r.stdout or "{}"), indent=2))
            except json.JSONDecodeError:
                print(r.stdout)
            return 0
        if "already exists" in (r.stderr or "").lower() or r.returncode == 0:
            break

    print("gh error:", r.stderr or r.stdout, file=sys.stderr)
    print(
        f"\nManual fix: https://github.com/{REPO}/settings/pages → Source: GitHub Actions",
        file=sys.stderr,
    )
    return r.returncode or 1


if __name__ == "__main__":
    raise SystemExit(main())
