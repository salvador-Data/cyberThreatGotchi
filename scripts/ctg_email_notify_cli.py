#!/usr/bin/env python3
"""CLI for CTG email notify bridge — invoked from Start-CtgEmailNotifyBridge.ps1."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core import ctg_email_notify as notify  # noqa: E402


def _emit(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload, separators=(",", ":")))
    sys.stdout.flush()


def _fail(message: str, code: int = 1) -> int:
    _emit({"ok": False, "error": message})
    return code


def cmd_poll(args: argparse.Namespace) -> int:
    state_path = Path(args.state_path)
    state = notify.EmailNotifyState.load(state_path)
    settings = notify.ImapSettings(
        host=args.host,
        port=args.port,
        username=args.username,
        password=args.password,
        mailbox=args.mailbox,
        use_ssl=args.use_ssl,
        mark_read=not args.no_mark_read,
        move_folder=args.move_folder or "",
    )
    try:
        new_msgs, skipped = notify.poll_imap_once(
            settings, state, max_messages=args.max_messages
        )
    except Exception as exc:
        return _fail(str(exc))

    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    written: list[str] = []
    for msg in new_msgs:
        note = msg.to_notification_dict()
        fname = f"email-{msg.content_hash[:16]}.json"
        target = out_dir / fname
        target.write_text(json.dumps(note, indent=2), encoding="utf-8")
        written.append(str(target))

    _emit(
        {
            "ok": True,
            "new_count": len(new_msgs),
            "skipped_duplicate_count": len(skipped),
            "written": written,
            "state_path": str(state_path),
        }
    )
    return 0


def cmd_dedup_test(args: argparse.Namespace) -> int:
    """Self-test dedup keys without IMAP."""
    mid, chash = notify.dedup_keys_from_headers(
        args.message_id,
        args.from_addr,
        args.date,
        args.subject,
        args.body,
    )
    _emit(
        {
            "ok": True,
            "message_id_key": mid,
            "content_hash": chash,
        }
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="CTG email notify CLI")
    sub = parser.add_subparsers(dest="command", required=True)

    poll = sub.add_parser("poll", help="Poll IMAP once and write new notifications")
    poll.add_argument("--host", default=os.environ.get("CTG_IMAP_HOST", "127.0.0.1"))
    poll.add_argument("--port", type=int, default=int(os.environ.get("CTG_IMAP_PORT", "1143")))
    poll.add_argument("--username", default=os.environ.get("CTG_IMAP_USER", ""))
    poll.add_argument("--password", default=os.environ.get("CTG_IMAP_PASSWORD", ""))
    poll.add_argument("--mailbox", default=os.environ.get("CTG_IMAP_MAILBOX", "INBOX"))
    poll.add_argument("--use-ssl", action="store_true")
    poll.add_argument("--no-mark-read", action="store_true")
    poll.add_argument("--move-folder", default=os.environ.get("CTG_IMAP_MOVE_FOLDER", ""))
    poll.add_argument(
        "--state-path",
        default=os.environ.get(
            "CTG_EMAIL_NOTIFY_STATE",
            str(Path.home() / "Backups" / ".vault" / "email-notify-state.json"),
        ),
    )
    poll.add_argument(
        "--output-dir",
        default=os.environ.get(
            "CTG_EMAIL_NOTIFY_OUT",
            str(Path.home() / "Backups" / "ctg-email-notify"),
        ),
    )
    poll.add_argument("--max-messages", type=int, default=50)
    poll.set_defaults(func=cmd_poll)

    dedup = sub.add_parser("dedup-test", help="Compute dedup keys (tests)")
    dedup.add_argument("--message-id", default="")
    dedup.add_argument("--from-addr", default="sender@example.com")
    dedup.add_argument("--date", default="Mon, 1 Jan 2024 00:00:00 +0000")
    dedup.add_argument("--subject", default="Test subject")
    dedup.add_argument("--body", default="Hello lab")
    dedup.set_defaults(func=cmd_dedup_test)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
