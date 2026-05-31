"""CTG encrypted credential vault — Argon2id/scrypt KDF + AES-256-GCM.

Authorized Hacker Planet LLC lab use only. Vault files are gitignored; never commit secrets.
"""

from __future__ import annotations

import base64
import csv
import hashlib
import hmac
import json
import os
import secrets
import shutil
import subprocess
import sys
import tempfile
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from io import StringIO
from pathlib import Path
from typing import Any, Optional

VAULT_VERSION = 1
DEFAULT_VAULT_DIR = Path.home() / "Backups" / ".vault"
DEFAULT_VAULT_PATH = DEFAULT_VAULT_DIR / "credentials.vault"
SESSION_TIMEOUT_SEC = 900
DEFAULT_SESSION_TIMEOUT_SEC = SESSION_TIMEOUT_SEC
ARGON2_TIME_COST = 3
ARGON2_MEMORY_KIB = 65536
ARGON2_PARALLELISM = 2
SCRYPT_N = 2**15
SCRYPT_R = 8
SCRYPT_P = 1

_SESSION: Optional["VaultSession"] = None
SESSION_FILE_NAME = "credentials.session.dpapi"


class VaultError(Exception):
    """Base vault error."""


class VaultLockedError(VaultError):
    """Vault is locked or session expired."""


class VaultExistsError(VaultError):
    """Vault file already exists."""


class VaultNotFoundError(VaultError):
    """Vault file missing."""


class VaultAuthError(VaultError):
    """Wrong master password or corrupt ciphertext."""


class CredentialNotFoundError(VaultError):
    """No matching credential entry."""


def get_session_timeout_sec() -> int:
    """Session idle TTL in seconds. Override with env CTG_VAULT_SESSION_TTL (default 900)."""
    raw = os.environ.get("CTG_VAULT_SESSION_TTL", "").strip()
    if raw:
        try:
            val = int(raw)
            if val > 0:
                return val
        except ValueError:
            pass
    return DEFAULT_SESSION_TIMEOUT_SEC


def zero_bytearray_best_effort(buf: bytearray) -> None:
    """Best-effort in-place zero of mutable byte buffers."""
    for i in range(len(buf)):
        buf[i] = 0


def zero_sensitive_best_effort(value: str | bytes | bytearray | None) -> None:
    """Best-effort cleanup after credential reads.

    Python ``str`` objects are immutable — this cannot guarantee RAM is cleared.
    On Windows, ``VirtualLock`` / ``SecureZeroMemory`` require native code; CTG
    relies on session lock + short TTL instead. See docs/SECRET_VAULT.md.
    """
    if value is None:
        return
    if isinstance(value, bytearray):
        zero_bytearray_best_effort(value)
        return
    if isinstance(value, bytes):
        zero_bytearray_best_effort(bytearray(value))


def session_seconds_remaining(session: "VaultSession", timeout_sec: int | None = None) -> int:
    import time

    ttl = timeout_sec if timeout_sec is not None else get_session_timeout_sec()
    elapsed = time.time() - session.unlocked_at
    return max(0, int(ttl - elapsed))


def constant_time_equal(a: str, b: str) -> bool:
    return hmac.compare_digest(a.encode("utf-8"), b.encode("utf-8"))


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def _b64e(data: bytes) -> str:
    return base64.b64encode(data).decode("ascii")


def _b64d(text: str) -> bytes:
    return base64.b64decode(text.encode("ascii"))


def _default_kdf_params(salt: bytes, name: str = "argon2id") -> dict[str, Any]:
    return {
        "name": name,
        "salt": _b64e(salt),
        "time_cost": ARGON2_TIME_COST,
        "memory_cost_kib": ARGON2_MEMORY_KIB,
        "parallelism": ARGON2_PARALLELISM,
        "length": 32,
    }


def _derive_key_argon2id(password: str, params: dict[str, Any]) -> bytes:
    from argon2 import low_level

    salt = _b64d(str(params["salt"]))
    length = int(params.get("length", 32))
    time_cost = int(params.get("time_cost", ARGON2_TIME_COST))
    memory_cost = int(params.get("memory_cost_kib", ARGON2_MEMORY_KIB))
    parallelism = int(params.get("parallelism", ARGON2_PARALLELISM))
    return low_level.hash_secret_raw(
        secret=password.encode("utf-8"),
        salt=salt,
        time_cost=time_cost,
        memory_cost=memory_cost,
        parallelism=parallelism,
        hash_len=length,
        type=low_level.Type.ID,
    )


def _derive_key_scrypt(password: str, params: dict[str, Any]) -> bytes:
    salt = _b64d(str(params["salt"]))
    length = int(params.get("length", 32))
    n = int(params.get("n", SCRYPT_N))
    r = int(params.get("r", SCRYPT_R))
    p = int(params.get("p", SCRYPT_P))
    return hashlib.scrypt(
        password.encode("utf-8"),
        salt=salt,
        n=n,
        r=r,
        p=p,
        dklen=length,
    )


def derive_key(password: str, params: dict[str, Any]) -> bytes:
    name = str(params.get("name", "argon2id")).lower()
    if name == "argon2id":
        try:
            return _derive_key_argon2id(password, params)
        except ImportError:
            fallback = dict(params)
            fallback["name"] = "scrypt"
            fallback.setdefault("n", SCRYPT_N)
            fallback.setdefault("r", SCRYPT_R)
            fallback.setdefault("p", SCRYPT_P)
            return _derive_key_scrypt(password, fallback)
    if name == "scrypt":
        return _derive_key_scrypt(password, params)
    raise VaultError(f"Unsupported KDF: {name}")


def _encrypt_payload(key: bytes, payload: dict[str, Any]) -> tuple[bytes, dict[str, str]]:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM

    nonce = os.urandom(12)
    plaintext = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
    ciphertext = AESGCM(key).encrypt(nonce, plaintext, None)
    return ciphertext, {"name": "aes-256-gcm", "nonce": _b64e(nonce)}


def _decrypt_payload(key: bytes, cipher_meta: dict[str, str], ciphertext: bytes) -> dict[str, Any]:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM

    if str(cipher_meta.get("name")) != "aes-256-gcm":
        raise VaultError("Unsupported cipher")
    nonce = _b64d(str(cipher_meta["nonce"]))
    try:
        plaintext = AESGCM(key).decrypt(nonce, ciphertext, None)
    except Exception as exc:
        raise VaultAuthError("Unlock failed — wrong master password or corrupt vault") from exc
    return json.loads(plaintext.decode("utf-8"))


def _load_vault_document(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise VaultNotFoundError(f"Vault not found: {path}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise VaultError("Vault file is not valid JSON") from exc


def _save_vault_document(path: Path, document: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(path)


def dpapi_protect_bytes(data: bytes) -> bytes:
    if sys.platform != "win32":
        raise VaultError("DPAPI wrap is Windows-only")
    b64 = _b64e(data)
    ps = (
        "Add-Type -AssemblyName System.Security; "
        f"$b=[Convert]::FromBase64String('{b64}'); "
        "$p=[Security.Cryptography.ProtectedData]::Protect($b,$null,"
        "[Security.Cryptography.DataProtectionScope]::CurrentUser); "
        "[Convert]::ToBase64String($p)"
    )
    result = subprocess.run(
        ["powershell", "-NoProfile", "-Command", ps],
        capture_output=True,
        text=True,
        check=False,
        timeout=30,
    )
    if result.returncode != 0:
        raise VaultError("DPAPI protect failed")
    return _b64d(result.stdout.strip())


def dpapi_unprotect_bytes(protected_b64: str) -> bytes:
    if sys.platform != "win32":
        raise VaultError("DPAPI unwrap is Windows-only")
    ps = (
        "Add-Type -AssemblyName System.Security; "
        f"$p=[Convert]::FromBase64String('{protected_b64}'); "
        "$b=[Security.Cryptography.ProtectedData]::Unprotect($p,$null,"
        "[Security.Cryptography.DataProtectionScope]::CurrentUser); "
        "[Convert]::ToBase64String($b)"
    )
    result = subprocess.run(
        ["powershell", "-NoProfile", "-Command", ps],
        capture_output=True,
        text=True,
        check=False,
        timeout=30,
    )
    if result.returncode != 0:
        raise VaultAuthError("DPAPI unwrap failed — wrong Windows user or vault moved")
    return _b64d(result.stdout.strip())


@dataclass
class CredentialEntry:
    id: str
    title: str
    username: str
    password: str
    url: str = ""
    notes: str = ""
    tags: list[str] = field(default_factory=list)
    created: str = ""
    updated: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "username": self.username,
            "password": self.password,
            "url": self.url,
            "notes": self.notes,
            "tags": list(self.tags),
            "created": self.created,
            "updated": self.updated,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "CredentialEntry":
        return cls(
            id=str(data.get("id") or uuid.uuid4()),
            title=str(data.get("title") or ""),
            username=str(data.get("username") or ""),
            password=str(data.get("password") or ""),
            url=str(data.get("url") or ""),
            notes=str(data.get("notes") or ""),
            tags=[str(t) for t in (data.get("tags") or [])],
            created=str(data.get("created") or _utc_now_iso()),
            updated=str(data.get("updated") or _utc_now_iso()),
        )


@dataclass
class VaultSession:
    vault_path: Path
    content_key: bytes
    entries: list[CredentialEntry]
    unlocked_at: float
    kdf_params: dict[str, Any]
    cipher_meta: dict[str, str]
    dpapi_wrapped_key: Optional[str] = None

    def is_expired(self, timeout_sec: int | None = None) -> bool:
        import time

        ttl = timeout_sec if timeout_sec is not None else get_session_timeout_sec()
        return (time.time() - self.unlocked_at) >= ttl

    def touch(self) -> None:
        import time

        self.unlocked_at = time.time()

    def save(self) -> None:
        payload = {"entries": [e.to_dict() for e in self.entries]}
        ciphertext, cipher_meta = _encrypt_payload(self.content_key, payload)
        document = _load_vault_document(self.vault_path)
        document["cipher"] = cipher_meta
        document["ciphertext"] = _b64e(ciphertext)
        if self.dpapi_wrapped_key:
            document["dpapi_wrapped_key"] = self.dpapi_wrapped_key
        _save_vault_document(self.vault_path, document)
        self.cipher_meta = cipher_meta


def get_session_file_path(vault_path: Path | str = DEFAULT_VAULT_PATH) -> Path:
    return Path(vault_path).parent / SESSION_FILE_NAME


def _save_session_sidecar(session: VaultSession) -> None:
    if sys.platform != "win32":
        return
    sidecar = get_session_file_path(session.vault_path)
    sidecar.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "vault_path": str(session.vault_path.resolve()),
        "unlocked_at": session.unlocked_at,
        "wrapped_key": _b64e(dpapi_protect_bytes(session.content_key)),
    }
    sidecar.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")


def _load_session_sidecar(vault_path: Path, timeout_sec: int | None = None) -> Optional[VaultSession]:
    if sys.platform != "win32":
        return None
    ttl = timeout_sec if timeout_sec is not None else get_session_timeout_sec()
    sidecar = get_session_file_path(vault_path)
    if not sidecar.is_file():
        return None
    try:
        payload = json.loads(sidecar.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    if str(payload.get("vault_path", "")) != str(vault_path.resolve()):
        return None
    import time

    unlocked_at = float(payload.get("unlocked_at", 0))
    if (time.time() - unlocked_at) >= ttl:
        _clear_session_sidecar(vault_path)
        return None
    try:
        content_key = dpapi_unprotect_bytes(str(payload["wrapped_key"]))
    except VaultAuthError:
        return None
    document = _load_vault_document(vault_path)
    cipher_meta = dict(document["cipher"])
    ciphertext = _b64d(str(document["ciphertext"]))
    try:
        inner = _decrypt_payload(content_key, cipher_meta, ciphertext)
    except VaultAuthError:
        return None
    entries = [CredentialEntry.from_dict(item) for item in inner.get("entries", [])]
    return VaultSession(
        vault_path=vault_path,
        content_key=content_key,
        entries=entries,
        unlocked_at=unlocked_at,
        kdf_params=dict(document["kdf"]),
        cipher_meta=cipher_meta,
        dpapi_wrapped_key=document.get("dpapi_wrapped_key"),
    )


def _clear_session_sidecar(vault_path: Path | str) -> None:
    sidecar = get_session_file_path(vault_path)
    if sidecar.is_file():
        sidecar.unlink()


def _set_session(session: VaultSession) -> VaultSession:
    global _SESSION
    _SESSION = session
    _save_session_sidecar(session)
    return session


def get_active_session(
    timeout_sec: int | None = None,
    vault_path: Path | str | None = None,
) -> VaultSession:
    global _SESSION
    ttl = timeout_sec if timeout_sec is not None else get_session_timeout_sec()
    if _SESSION is not None and not _SESSION.is_expired(ttl):
        _SESSION.touch()
        _save_session_sidecar(_SESSION)
        return _SESSION
    _SESSION = None
    paths_to_try: list[Path] = []
    if vault_path is not None:
        paths_to_try.append(Path(vault_path))
    elif DEFAULT_VAULT_PATH.is_file():
        paths_to_try.append(DEFAULT_VAULT_PATH)
    for path in paths_to_try:
        candidate = _load_session_sidecar(path, ttl)
        if candidate is not None:
            candidate.touch()
            _SESSION = candidate
            _save_session_sidecar(_SESSION)
            return _SESSION
    raise VaultLockedError("Vault is locked")


def lock_session(vault_path: Path | str | None = None) -> None:
    global _SESSION
    if _SESSION is not None:
        _clear_session_sidecar(_SESSION.vault_path)
    elif vault_path is not None:
        _clear_session_sidecar(vault_path)
    _SESSION = None


def init_vault(
    master_password: str,
    vault_path: Path | str = DEFAULT_VAULT_PATH,
    *,
    enable_dpapi_wrap: bool = False,
    kdf_name: str = "argon2id",
) -> Path:
    path = Path(vault_path)
    if path.exists():
        raise VaultExistsError(f"Vault already exists: {path}")
    if not master_password:
        raise VaultError("Master password required")

    salt = os.urandom(16)
    try:
        if kdf_name == "argon2id":
            import argon2  # noqa: F401

            params = _default_kdf_params(salt, "argon2id")
        else:
            raise ImportError
    except ImportError:
        params = {
            "name": "scrypt",
            "salt": _b64e(salt),
            "n": SCRYPT_N,
            "r": SCRYPT_R,
            "p": SCRYPT_P,
            "length": 32,
        }

    content_key = derive_key(master_password, params)
    payload = {"entries": []}
    ciphertext, cipher_meta = _encrypt_payload(content_key, payload)
    document: dict[str, Any] = {
        "version": VAULT_VERSION,
        "kdf": params,
        "cipher": cipher_meta,
        "ciphertext": _b64e(ciphertext),
    }
    if enable_dpapi_wrap and sys.platform == "win32":
        document["dpapi_wrapped_key"] = _b64e(dpapi_protect_bytes(content_key))
    _save_vault_document(path, document)
    return path


def unlock_vault(
    master_password: str = "",
    vault_path: Path | str = DEFAULT_VAULT_PATH,
    *,
    use_dpapi: bool = False,
) -> VaultSession:
    path = Path(vault_path)
    document = _load_vault_document(path)
    kdf_params = dict(document["kdf"])
    cipher_meta = dict(document["cipher"])
    ciphertext = _b64d(str(document["ciphertext"]))

    content_key: bytes
    if use_dpapi:
        wrapped = document.get("dpapi_wrapped_key")
        if not wrapped:
            raise VaultError("Vault has no DPAPI-wrapped key — init with enable_dpapi_wrap")
        content_key = dpapi_unprotect_bytes(str(wrapped))
    else:
        if not master_password:
            raise VaultError("Master password required")
        content_key = derive_key(master_password, kdf_params)

    payload = _decrypt_payload(content_key, cipher_meta, ciphertext)
    entries = [CredentialEntry.from_dict(item) for item in payload.get("entries", [])]
    session = VaultSession(
        vault_path=path,
        content_key=content_key,
        entries=entries,
        unlocked_at=__import__("time").time(),
        kdf_params=kdf_params,
        cipher_meta=cipher_meta,
        dpapi_wrapped_key=document.get("dpapi_wrapped_key"),
    )
    return _set_session(session)


def enable_dpapi_wrap(vault_path: Path | str = DEFAULT_VAULT_PATH) -> None:
    session = get_active_session(vault_path=vault_path)
    if Path(vault_path) != session.vault_path:
        raise VaultError("Active session vault path mismatch")
    if sys.platform != "win32":
        raise VaultError("DPAPI wrap is Windows-only")
    session.dpapi_wrapped_key = _b64e(dpapi_protect_bytes(session.content_key))
    session.save()


def _find_entry_index(session: VaultSession, title: str) -> int:
    title_norm = title.strip().lower()
    for idx, entry in enumerate(session.entries):
        if entry.title.strip().lower() == title_norm:
            return idx
    return -1


def list_credentials(
    session: Optional[VaultSession] = None,
    vault_path: Path | str | None = None,
) -> list[dict[str, Any]]:
    sess = session or get_active_session(vault_path=vault_path)
    return [
        {
            "id": e.id,
            "title": e.title,
            "username": e.username,
            "url": e.url,
            "tags": list(e.tags),
            "created": e.created,
            "updated": e.updated,
        }
        for e in sorted(sess.entries, key=lambda x: x.title.lower())
    ]


def get_credential(
    title: str,
    session: Optional[VaultSession] = None,
    vault_path: Path | str | None = None,
) -> CredentialEntry:
    sess = session or get_active_session(vault_path=vault_path)
    idx = _find_entry_index(sess, title)
    if idx < 0:
        raise CredentialNotFoundError(f"Credential not found: {title}")
    return sess.entries[idx]


def get_credential_dict(
    title: str,
    session: Optional[VaultSession] = None,
    vault_path: Path | str | None = None,
) -> dict[str, Any]:
    """Return credential dict; best-effort zero password byte buffer after building response."""
    entry = get_credential(title, session=session, vault_path=vault_path)
    payload = entry.to_dict()
    pwd_buf = bytearray(str(payload.get("password", "")).encode("utf-8"))
    try:
        return payload
    finally:
        zero_bytearray_best_effort(pwd_buf)


def add_credential(
    title: str,
    username: str,
    password: str,
    *,
    url: str = "",
    notes: str = "",
    tags: Optional[list[str]] = None,
    session: Optional[VaultSession] = None,
    vault_path: Path | str | None = None,
) -> CredentialEntry:
    sess = session or get_active_session(vault_path=vault_path)
    if _find_entry_index(sess, title) >= 0:
        raise VaultError(f"Credential already exists: {title}")
    now = _utc_now_iso()
    entry = CredentialEntry(
        id=str(uuid.uuid4()),
        title=title.strip(),
        username=username,
        password=password,
        url=url,
        notes=notes,
        tags=list(tags or []),
        created=now,
        updated=now,
    )
    sess.entries.append(entry)
    sess.save()
    return entry


def set_credential(
    title: str,
    *,
    username: Optional[str] = None,
    password: Optional[str] = None,
    url: Optional[str] = None,
    notes: Optional[str] = None,
    tags: Optional[list[str]] = None,
    session: Optional[VaultSession] = None,
    vault_path: Path | str | None = None,
) -> CredentialEntry:
    sess = session or get_active_session(vault_path=vault_path)
    idx = _find_entry_index(sess, title)
    if idx < 0:
        raise CredentialNotFoundError(f"Credential not found: {title}")
    entry = sess.entries[idx]
    if username is not None:
        entry.username = username
    if password is not None:
        entry.password = password
    if url is not None:
        entry.url = url
    if notes is not None:
        entry.notes = notes
    if tags is not None:
        entry.tags = list(tags)
    entry.updated = _utc_now_iso()
    sess.save()
    return entry


def remove_credential(
    title: str,
    session: Optional[VaultSession] = None,
    vault_path: Path | str | None = None,
) -> None:
    sess = session or get_active_session(vault_path=vault_path)
    idx = _find_entry_index(sess, title)
    if idx < 0:
        raise CredentialNotFoundError(f"Credential not found: {title}")
    del sess.entries[idx]
    sess.save()


def export_vault_backup(
    destination: Path | str,
    vault_path: Path | str = DEFAULT_VAULT_PATH,
) -> Path:
    src = Path(vault_path)
    if not src.is_file():
        raise VaultNotFoundError(f"Vault not found: {src}")
    dest = Path(destination)
    dest.parent.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    if dest.is_dir():
        dest = dest / f"credentials-{stamp}.vault.backup"
    shutil.copy2(src, dest)
    return dest


def import_from_csv(
    csv_path: Path | str,
    *,
    title_column: str = "title",
    username_column: str = "username",
    password_column: str = "password",
    url_column: str = "url",
    notes_column: str = "notes",
    session: Optional[VaultSession] = None,
    vault_path: Path | str | None = None,
) -> int:
    sess = session or get_active_session(vault_path=vault_path)
    path = Path(csv_path)
    if not path.is_file():
        raise VaultError(f"CSV not found: {path}")
    added = 0
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            title = (row.get(title_column) or "").strip()
            if not title:
                continue
            if _find_entry_index(sess, title) >= 0:
                continue
            add_credential(
                title=title,
                username=(row.get(username_column) or "").strip(),
                password=(row.get(password_column) or "").strip(),
                url=(row.get(url_column) or "").strip(),
                notes=(row.get(notes_column) or "").strip(),
                session=sess,
            )
            added += 1
    return added


def verify_master_password(master_password: str, vault_path: Path | str = DEFAULT_VAULT_PATH) -> bool:
    try:
        unlock_vault(master_password=master_password, vault_path=vault_path)
        lock_session()
        return True
    except VaultAuthError:
        lock_session()
        return False


def vault_status(vault_path: Path | str = DEFAULT_VAULT_PATH) -> dict[str, Any]:
    path = Path(vault_path)
    ttl = get_session_timeout_sec()
    sidecar_active = False
    entry_count = 0
    seconds_remaining = 0
    if path.is_file() and sys.platform == "win32":
        try:
            sidecar_session = _load_session_sidecar(path, ttl)
            if sidecar_session is not None:
                sidecar_active = True
                entry_count = len(sidecar_session.entries)
                seconds_remaining = session_seconds_remaining(sidecar_session, ttl)
        except VaultError:
            sidecar_active = False
    status: dict[str, Any] = {
        "vault_path": str(path),
        "exists": path.is_file(),
        "locked": not sidecar_active and (_SESSION is None or (_SESSION is not None and _SESSION.is_expired())),
        "session_active": sidecar_active or (_SESSION is not None and not _SESSION.is_expired()),
        "session_timeout_sec": ttl,
        "session_seconds_remaining": seconds_remaining,
        "entry_count": entry_count,
        "kdf": None,
        "dpapi_wrapped": False,
    }
    if _SESSION is not None and not _SESSION.is_expired() and _SESSION.vault_path == path:
        status["entry_count"] = len(_SESSION.entries)
        status["locked"] = False
        status["session_seconds_remaining"] = session_seconds_remaining(_SESSION, ttl)
    if path.is_file():
        doc = _load_vault_document(path)
        status["kdf"] = doc.get("kdf", {}).get("name")
        status["dpapi_wrapped"] = bool(doc.get("dpapi_wrapped_key"))
    return status
