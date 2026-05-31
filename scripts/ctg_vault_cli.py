#!/usr/bin/env python3
"""CLI for CTG credential vault — invoked from Ctg-CredentialVault.ps1."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core import ctg_vault as vault  # noqa: E402


def _read_password_stdin() -> str:
    data = sys.stdin.read()
    return data.rstrip("\r\n")


def _emit(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload, separators=(",", ":")))
    sys.stdout.flush()


def _fail(message: str, code: int = 1) -> int:
    _emit({"ok": False, "error": message})
    return code


def cmd_init(args: argparse.Namespace) -> int:
    password = args.master_password or _read_password_stdin()
    try:
        path = vault.init_vault(
            password,
            args.vault_path,
            enable_dpapi_wrap=args.enable_dpapi_wrap,
        )
    except vault.VaultExistsError as exc:
        return _fail(str(exc), 2)
    except vault.VaultError as exc:
        return _fail(str(exc))
    _emit({"ok": True, "vault_path": str(path), "dpapi_wrapped": args.enable_dpapi_wrap})
    return 0


def cmd_unlock(args: argparse.Namespace) -> int:
    password = ""
    if not args.use_dpapi:
        password = args.master_password or _read_password_stdin()
    try:
        session = vault.unlock_vault(
            master_password=password,
            vault_path=args.vault_path,
            use_dpapi=args.use_dpapi,
        )
    except vault.VaultAuthError:
        return _fail("Unlock failed", 3)
    except vault.VaultError as exc:
        return _fail(str(exc))
    _emit({"ok": True, "entry_count": len(session.entries), "vault_path": str(session.vault_path)})
    return 0


def cmd_lock(args: argparse.Namespace) -> int:
    vault.lock_session(vault_path=args.vault_path)
    _emit({"ok": True})
    return 0


def cmd_status(args: argparse.Namespace) -> int:
    _emit({"ok": True, **vault.vault_status(args.vault_path)})
    return 0


def cmd_list(args: argparse.Namespace) -> int:
    try:
        items = vault.list_credentials(vault_path=args.vault_path)
    except vault.VaultLockedError as exc:
        return _fail(str(exc), 4)
    _emit({"ok": True, "credentials": items})
    return 0


def cmd_get(args: argparse.Namespace) -> int:
    try:
        cred = vault.get_credential_dict(args.title, vault_path=args.vault_path)
    except vault.VaultLockedError as exc:
        return _fail(str(exc), 4)
    except vault.CredentialNotFoundError as exc:
        return _fail(str(exc), 5)
    _emit({"ok": True, "credential": cred})
    return 0


def cmd_add(args: argparse.Namespace) -> int:
    password = args.password or _read_password_stdin()
    try:
        entry = vault.add_credential(
            args.title,
            args.username,
            password,
            url=args.url,
            notes=args.notes,
            tags=[t.strip() for t in (args.tags or "").split(",") if t.strip()],
            vault_path=args.vault_path,
        )
    except vault.VaultLockedError as exc:
        return _fail(str(exc), 4)
    except vault.VaultError as exc:
        return _fail(str(exc))
    _emit({"ok": True, "credential": {k: entry.to_dict()[k] for k in ("id", "title", "username", "created")}})
    return 0


def cmd_set(args: argparse.Namespace) -> int:
    password = args.password
    if args.password_from_stdin:
        password = _read_password_stdin()
    try:
        entry = vault.set_credential(
            args.title,
            username=args.username,
            password=password,
            url=args.url,
            notes=args.notes,
            vault_path=args.vault_path,
        )
    except vault.VaultLockedError as exc:
        return _fail(str(exc), 4)
    except vault.CredentialNotFoundError as exc:
        return _fail(str(exc), 5)
    _emit({"ok": True, "credential": {"id": entry.id, "title": entry.title, "updated": entry.updated}})
    return 0


def cmd_remove(args: argparse.Namespace) -> int:
    try:
        vault.remove_credential(args.title, vault_path=args.vault_path)
    except vault.VaultLockedError as exc:
        return _fail(str(exc), 4)
    except vault.CredentialNotFoundError as exc:
        return _fail(str(exc), 5)
    _emit({"ok": True})
    return 0


def cmd_export(args: argparse.Namespace) -> int:
    try:
        dest = vault.export_vault_backup(args.destination, args.vault_path)
    except vault.VaultError as exc:
        return _fail(str(exc))
    _emit({"ok": True, "backup_path": str(dest)})
    return 0


def cmd_import_csv(args: argparse.Namespace) -> int:
    try:
        added = vault.import_from_csv(args.csv_path, vault_path=args.vault_path)
    except vault.VaultLockedError as exc:
        return _fail(str(exc), 4)
    except vault.VaultError as exc:
        return _fail(str(exc))
    _emit({"ok": True, "imported": added})
    return 0


def cmd_enable_dpapi(args: argparse.Namespace) -> int:
    try:
        vault.enable_dpapi_wrap(args.vault_path)
    except vault.VaultLockedError as exc:
        return _fail(str(exc), 4)
    except vault.VaultError as exc:
        return _fail(str(exc))
    _emit({"ok": True})
    return 0


def cmd_verify(args: argparse.Namespace) -> int:
    password = args.master_password or _read_password_stdin()
    ok = vault.verify_master_password(password, args.vault_path)
    _emit({"ok": ok})
    return 0 if ok else 3


def build_parser() -> argparse.ArgumentParser:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument(
        "--vault-path",
        default=str(vault.DEFAULT_VAULT_PATH),
        help="Path to credentials.vault file",
    )

    parser = argparse.ArgumentParser(description="CTG encrypted credential vault CLI")
    sub = parser.add_subparsers(dest="command", required=True)

    p_init = sub.add_parser("init", parents=[common])
    p_init.add_argument("--master-password", default="")
    p_init.add_argument("--enable-dpapi-wrap", action="store_true")
    p_init.set_defaults(func=cmd_init)

    p_unlock = sub.add_parser("unlock", parents=[common])
    p_unlock.add_argument("--master-password", default="")
    p_unlock.add_argument("--use-dpapi", action="store_true")
    p_unlock.set_defaults(func=cmd_unlock)

    p_lock = sub.add_parser("lock", parents=[common])
    p_lock.set_defaults(func=cmd_lock)

    p_status = sub.add_parser("status", parents=[common])
    p_status.set_defaults(func=cmd_status)

    p_list = sub.add_parser("list", parents=[common])
    p_list.set_defaults(func=cmd_list)

    p_get = sub.add_parser("get", parents=[common])
    p_get.add_argument("--title", required=True)
    p_get.set_defaults(func=cmd_get)

    p_add = sub.add_parser("add", parents=[common])
    p_add.add_argument("--title", required=True)
    p_add.add_argument("--username", default="")
    p_add.add_argument("--password", default="")
    p_add.add_argument("--url", default="")
    p_add.add_argument("--notes", default="")
    p_add.add_argument("--tags", default="")
    p_add.set_defaults(func=cmd_add)

    p_set = sub.add_parser("set", parents=[common])
    p_set.add_argument("--title", required=True)
    p_set.add_argument("--username", default="")
    p_set.add_argument("--password", default="")
    p_set.add_argument("--password-from-stdin", action="store_true")
    p_set.add_argument("--url", default="")
    p_set.add_argument("--notes", default="")
    p_set.set_defaults(func=cmd_set)

    p_remove = sub.add_parser("remove", parents=[common])
    p_remove.add_argument("--title", required=True)
    p_remove.set_defaults(func=cmd_remove)

    p_export = sub.add_parser("export", parents=[common])
    p_export.add_argument("--destination", required=True)
    p_export.set_defaults(func=cmd_export)

    p_import = sub.add_parser("import-csv", parents=[common])
    p_import.add_argument("--csv-path", required=True)
    p_import.set_defaults(func=cmd_import_csv)

    p_dpapi = sub.add_parser("enable-dpapi", parents=[common])
    p_dpapi.set_defaults(func=cmd_enable_dpapi)

    p_verify = sub.add_parser("verify", parents=[common])
    p_verify.add_argument("--master-password", default="")
    p_verify.set_defaults(func=cmd_verify)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
