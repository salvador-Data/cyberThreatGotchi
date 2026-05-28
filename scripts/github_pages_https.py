#!/usr/bin/env python3
"""Enable GitHub Pages HTTPS once custom domain DNS is verified."""

from __future__ import annotations

import json
import subprocess
import sys


def main() -> int:
    repo = "salvador-Data/cyberThreatGotchi"
    status = subprocess.run(
        ["gh", "api", f"repos/{repo}/pages"],
        capture_output=True,
        text=True,
    )
    if status.returncode != 0:
        print(status.stderr, file=sys.stderr)
        return 1
    pages = json.loads(status.stdout)
    cname = pages.get("cname")
    enforced = pages.get("https_enforced")
    print(f"cname={cname} https_enforced={enforced}")
    if enforced:
        print("HTTPS already enforced.")
        return 0
    put = subprocess.run(
        [
            "gh",
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
        print("GitHub rejected HTTPS — DNS may not be verified yet.", file=sys.stderr)
        print(put.stderr, file=sys.stderr)
        return 1
    print(json.dumps(json.loads(put.stdout), indent=2))
    print("Enforce HTTPS requested.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
