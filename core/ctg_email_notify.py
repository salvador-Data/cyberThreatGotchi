"""CTG email notification dedup and IMAP poll helpers (authorized lab use only)."""

from __future__ import annotations

import hashlib
import imaplib
import json
import re
import ssl
from dataclasses import dataclass, field
from datetime import datetime, timezone
from email import message_from_bytes
from email.header import decode_header, make_header
from email.utils import parsedate_to_datetime
from pathlib import Path
from typing import Any


MAX_BODY_PREFIX = 1024
STATE_VERSION = 1


def normalize_message_id(value: str | None) -> str | None:
    """Normalize RFC Message-ID for dedup primary key."""
    if not value:
        return None
    cleaned = value.strip().strip("<>").lower()
    if not cleaned:
        return None
    return cleaned


def decode_mime_header(value: str | None) -> str:
    if not value:
        return ""
    try:
        return str(make_header(decode_header(value)))
    except (TypeError, ValueError, UnicodeError):
        return value.strip()


def extract_body_prefix(msg: Any, limit: int = MAX_BODY_PREFIX) -> str:
    parts: list[str] = []
    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_maintype() == "multipart":
                continue
            if part.get_content_type() not in ("text/plain", "text/html"):
                continue
            payload = part.get_payload(decode=True)
            if payload is None:
                continue
            charset = part.get_content_charset() or "utf-8"
            try:
                parts.append(payload.decode(charset, errors="replace"))
            except LookupError:
                parts.append(payload.decode("utf-8", errors="replace"))
            if sum(len(p) for p in parts) >= limit:
                break
    else:
        payload = msg.get_payload(decode=True)
        if payload:
            charset = msg.get_content_charset() or "utf-8"
            try:
                parts.append(payload.decode(charset, errors="replace"))
            except LookupError:
                parts.append(payload.decode("utf-8", errors="replace"))
    text = "\n".join(parts)
    return text[:limit]


def content_fingerprint(
    from_addr: str,
    date_header: str,
    subject: str,
    body_prefix: str,
) -> str:
    """Fallback dedup key when Message-ID is missing or unstable."""
    canonical = "|".join(
        [
            (from_addr or "").strip().lower(),
            (date_header or "").strip(),
            (subject or "").strip(),
            (body_prefix or "")[:MAX_BODY_PREFIX],
        ]
    )
    return hashlib.sha256(canonical.encode("utf-8", errors="replace")).hexdigest()


def dedup_keys_from_headers(
    message_id: str | None,
    from_addr: str,
    date_header: str,
    subject: str,
    body_prefix: str,
) -> tuple[str | None, str]:
    """Return (message_id_key, content_hash)."""
    mid = normalize_message_id(message_id)
    chash = content_fingerprint(from_addr, date_header, subject, body_prefix)
    return mid, chash


@dataclass
class ParsedEmail:
    uid: str
    message_id: str | None
    in_reply_to: str | None
    from_addr: str
    date_header: str
    subject: str
    body_prefix: str
    content_hash: str
    message_id_key: str | None

    def dedup_keys(self) -> tuple[str | None, str]:
        return self.message_id_key, self.content_hash

    def to_notification_dict(self, *, labels: list[str] | None = None) -> dict[str, Any]:
        payload = {
            "uid": self.uid,
            "message_id": self.message_id,
            "in_reply_to": self.in_reply_to,
            "from": self.from_addr,
            "date": self.date_header,
            "subject": self.subject,
            "body_preview": self.body_prefix[:200],
            "content_hash": self.content_hash,
            "notified_at": datetime.now(timezone.utc).isoformat(),
        }
        if labels:
            payload["labels"] = labels
        return payload


@dataclass
class EmailNotifyState:
    path: Path
    message_ids: set[str] = field(default_factory=set)
    content_hashes: set[str] = field(default_factory=set)
    version: int = STATE_VERSION

    def is_duplicate(
        self,
        message_id_key: str | None,
        content_hash: str,
        in_reply_to: str | None = None,
    ) -> bool:
        if message_id_key and message_id_key in self.message_ids:
            return True
        reply_key = normalize_message_id(in_reply_to)
        if reply_key and reply_key in self.message_ids:
            return True
        if content_hash in self.content_hashes:
            return True
        return False

    def mark_seen(
        self,
        message_id_key: str | None,
        content_hash: str,
        in_reply_to: str | None = None,
    ) -> None:
        if message_id_key:
            self.message_ids.add(message_id_key)
        reply_key = normalize_message_id(in_reply_to)
        if reply_key:
            self.message_ids.add(reply_key)
        self.content_hashes.add(content_hash)

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "version": self.version,
            "message_ids": sorted(self.message_ids),
            "content_hashes": sorted(self.content_hashes),
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        tmp.replace(self.path)

    @classmethod
    def load(cls, path: Path) -> EmailNotifyState:
        if not path.is_file():
            return cls(path=path)
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return cls(path=path)
        return cls(
            path=path,
            message_ids=set(data.get("message_ids") or []),
            content_hashes=set(data.get("content_hashes") or []),
            version=int(data.get("version") or STATE_VERSION),
        )


def parse_imap_message(uid: bytes | str, raw: bytes) -> ParsedEmail:
    msg = message_from_bytes(raw)
    message_id = decode_mime_header(msg.get("Message-ID"))
    in_reply_to = decode_mime_header(msg.get("In-Reply-To"))
    from_addr = decode_mime_header(msg.get("From"))
    date_header = decode_mime_header(msg.get("Date"))
    subject = decode_mime_header(msg.get("Subject"))
    body_prefix = extract_body_prefix(msg)
    mid_key, chash = dedup_keys_from_headers(
        message_id, from_addr, date_header, subject, body_prefix
    )
    return ParsedEmail(
        uid=str(uid, "ascii") if isinstance(uid, bytes) else str(uid),
        message_id=message_id or None,
        in_reply_to=in_reply_to or None,
        from_addr=from_addr,
        date_header=date_header,
        subject=subject,
        body_prefix=body_prefix,
        content_hash=chash,
        message_id_key=mid_key,
    )


def is_high_priority_subject(subject: str, patterns: list[str] | None = None) -> bool:
    """Match urgent lab alert subjects (no PII in patterns)."""
    defaults = [
        r"\b(urgent|critical|alert|security|breach|compromise|ids|wazuh|fail2ban)\b",
    ]
    combined = "|".join(f"(?:{p})" for p in (patterns or defaults))
    return bool(re.search(combined, subject or "", re.IGNORECASE))


def is_github_ctg_email(
    from_addr: str,
    subject: str,
    *,
    repo_name: str = "cyberThreatGotchi",
) -> bool:
    """True when email looks like GitHub Actions/CI for the CTG monorepo."""
    from_lower = (from_addr or "").lower()
    subj = subject or ""
    if "github.com" not in from_lower and "notifications@github.com" not in from_lower:
        return False
    if repo_name.lower() not in subj.lower():
        return False
    return bool(
        re.search(
            r"(?i)(workflow run|action|failed|ci\b|github actions)",
            subj,
        )
    )


@dataclass
class ImapSettings:
    host: str = "127.0.0.1"
    port: int = 1143
    username: str = ""
    password: str = ""
    mailbox: str = "INBOX"
    use_ssl: bool = False
    mark_read: bool = True
    move_folder: str = ""


def poll_imap_once(
    settings: ImapSettings,
    state: EmailNotifyState,
    *,
    max_messages: int = 50,
    github_only: bool = False,
    github_repo: str = "cyberThreatGotchi",
) -> tuple[list[ParsedEmail], list[ParsedEmail]]:
    """
    Poll unread IMAP messages. Returns (new_messages, skipped_duplicates).
    Marks read or moves per settings after successful parse.
    """
    if not settings.username or not settings.password:
        raise ValueError("IMAP username and password required")

    if settings.use_ssl:
        client: imaplib.IMAP4 = imaplib.IMAP4_SSL(
            settings.host, settings.port, ssl_context=ssl.create_default_context()
        )
    else:
        client = imaplib.IMAP4(settings.host, settings.port)

    new_msgs: list[ParsedEmail] = []
    skipped: list[ParsedEmail] = []

    try:
        client.login(settings.username, settings.password)
        typ, _ = client.select(settings.mailbox, readonly=False)
        if typ != "OK":
            raise RuntimeError(f"IMAP select failed: {settings.mailbox}")

        typ, data = client.search(None, "UNSEEN")
        if typ != "OK" or not data or not data[0]:
            return [], []

        uids = data[0].split()[:max_messages]
        for uid in uids:
            typ, msg_data = client.fetch(uid, "(RFC822)")
            if typ != "OK" or not msg_data or not msg_data[0]:
                continue
            raw = msg_data[0][1]
            if not isinstance(raw, bytes):
                continue
            parsed = parse_imap_message(uid, raw)
            if github_only and not is_github_ctg_email(
                parsed.from_addr, parsed.subject, repo_name=github_repo
            ):
                continue
            mid_key, chash = parsed.dedup_keys()
            if state.is_duplicate(mid_key, chash, parsed.in_reply_to):
                skipped.append(parsed)
                continue
            state.mark_seen(mid_key, chash, parsed.in_reply_to)
            new_msgs.append(parsed)

            if settings.move_folder:
                client.copy(uid, settings.move_folder)
                client.store(uid, "+FLAGS", "\\Deleted")
            elif settings.mark_read:
                client.store(uid, "+FLAGS", "\\Seen")
    finally:
        try:
            client.logout()
        except Exception:
            pass

    if new_msgs or skipped:
        state.save()

    return new_msgs, skipped
