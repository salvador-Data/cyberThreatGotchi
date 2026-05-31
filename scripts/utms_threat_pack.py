#!/usr/bin/env python3
"""UTMS threat pack builder and OTA broadcast manifest (authorized lab only).

Extends pack JSON with signed broadcast metadata for Cardputer/Kali pull from
Windows Backups share. Signature is a placeholder until Pro signing keys are
configured off-repo.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

PACK_VERSION = 2
BROADCAST_SCHEMA = "ctg-utms-broadcast-v1"
SIGNATURE_PLACEHOLDER = "UNSIGNED-LAB-PLACEHOLDER"


def _utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def load_pack(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def pack_digest(pack: dict) -> str:
    canonical = json.dumps(pack, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(canonical).hexdigest()


def build_broadcast_manifest(pack_path: Path, *, channel: str = "lab") -> dict:
    pack = load_pack(pack_path)
    digest = pack_digest(pack)
    return {
        "schema": BROADCAST_SCHEMA,
        "version": PACK_VERSION,
        "channel": channel,
        "generated_at": _utc_now(),
        "pack_file": pack_path.name,
        "pack_sha256": digest,
        "signature": SIGNATURE_PLACEHOLDER,
        "signature_alg": "ed25519-placeholder",
        "pro_feed_hook": "optional:CTG_PRO_API_KEY off-repo",
        "notes": "Authorized Hacker Planet lab OTA only. Verify signature before flash.",
        "entries_count": len(pack.get("indicators", [])),
    }


def write_broadcast(out_dir: Path, pack_path: Path, channel: str) -> tuple[Path, Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest = build_broadcast_manifest(pack_path, channel=channel)
    manifest_path = out_dir / "utms-broadcast-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    pack_copy = out_dir / pack_path.name
    if pack_path.resolve() != pack_copy.resolve():
        pack_copy.write_text(pack_path.read_text(encoding="utf-8"), encoding="utf-8")
    return manifest_path, pack_copy


def main(argv: list[str] | None = None) -> int:
    root = Path(__file__).resolve().parent.parent
    default_pack = root / "scripts" / "utms" / "threat_pack.example.json"
    default_out = Path.home() / "Backups" / "ctg-utms-broadcast"

    parser = argparse.ArgumentParser(description="UTMS threat pack OTA broadcast")
    parser.add_argument("--pack", type=Path, default=default_pack, help="Source threat pack JSON")
    parser.add_argument("--out", type=Path, default=default_out, help="Broadcast output directory")
    parser.add_argument("--channel", default="lab", choices=("lab", "pro", "dev"))
    parser.add_argument("--print-digest", action="store_true")
    args = parser.parse_args(argv)

    if not args.pack.is_file():
        print(f"Pack not found: {args.pack}", file=sys.stderr)
        return 1

    if args.print_digest:
        pack = load_pack(args.pack)
        print(pack_digest(pack))
        return 0

    manifest_path, pack_copy = write_broadcast(args.out, args.pack, args.channel)
    print(json.dumps({"manifest": str(manifest_path), "pack": str(pack_copy)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
