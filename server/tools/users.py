#!/usr/bin/env python3
"""Manage AGB users from the server machine.

    python server/tools/users.py add --name "User 2" --role member --projects-root ~/projects
    python server/tools/users.py list
    python server/tools/users.py rotate --id 2
    python server/tools/users.py deactivate --id 2
    python server/tools/users.py set-root --id 2 --path ~/projects
    python server/tools/users.py assign-app --app-id 7 --user-id 2

`add` and `rotate` print the new API key ONCE (only its SHA-256 is stored),
plus a pairing code (base64 of {api_key, worker_url}) that the phone app
accepts from its "Scan QR to pair" flow. Pass --qr to also draw the QR in the
terminal (needs the `qrcode` package). Hand the key over privately.

Safe while the server runs: the users schema change is additive, and the
server reads users per request.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import sys

SERVER_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, SERVER_DIR)

from config.settings_loader import get_settings  # noqa: E402
from core import users as users_core  # noqa: E402
from database.db_manager import DBManager  # noqa: E402

DEFAULT_DB = os.path.join(SERVER_DIR, "app_manager.db")


def pairing_code(api_key: str, worker_url: str) -> str:
    payload = json.dumps({"api_key": api_key, "worker_url": worker_url})
    return base64.b64encode(payload.encode()).decode()


def _print_key(user, key: str, qr: bool, worker_url: str) -> None:
    print(f"User   : #{user.id} {user.name} ({user.role})")
    if user.projects_root:
        print(f"Root   : {user.projects_root}")
    print("API key (shown once, store it now):")
    print(key)
    code = pairing_code(key, worker_url)
    print("Pairing code (paste or QR):")
    print(code)
    if qr:
        try:
            import qrcode
        except ImportError:
            print("(qrcode package missing: no QR drawn)")
            return
        q = qrcode.QRCode(border=1)
        q.add_data(code)
        q.make(fit=True)
        q.print_ascii(invert=True)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Manage AGB users")
    ap.add_argument("--db", default=DEFAULT_DB, help="SQLite database path")
    sub = ap.add_subparsers(dest="cmd", required=True)

    a = sub.add_parser("add", help="create a user and print its key once")
    a.add_argument("--name", required=True)
    a.add_argument("--role", choices=users_core.ROLES, default=users_core.ROLE_MEMBER)
    a.add_argument("--projects-root", default="", help="folder for this user's new apps")
    a.add_argument("--qr", action="store_true")

    sub.add_parser("list", help="list users (never shows keys)")

    r = sub.add_parser("rotate", help="new key for a user, printed once")
    r.add_argument("--id", type=int, required=True)
    r.add_argument("--qr", action="store_true")

    d = sub.add_parser("deactivate", help="turn a user's key off")
    d.add_argument("--id", type=int, required=True)

    sr = sub.add_parser("set-root", help="set a user's projects root")
    sr.add_argument("--id", type=int, required=True)
    sr.add_argument("--path", required=True)

    aa = sub.add_parser("assign-app", help="give an app to a user")
    aa.add_argument("--app-id", type=int, required=True)
    aa.add_argument("--user-id", type=int, required=True)

    args = ap.parse_args(argv)
    db = DBManager(args.db)
    worker_url = get_settings().get("worker_url", "") if args.cmd in ("add", "rotate") else ""

    try:
        if args.cmd == "add":
            if args.role == users_core.ROLE_MEMBER and not args.projects_root:
                print("note: no --projects-root; this member can't create apps until one is set")
            user, key = users_core.create_user(db, args.name, args.role, args.projects_root)
            _print_key(user, key, args.qr, worker_url)
        elif args.cmd == "list":
            for u in db.list_users():
                state = "active" if u.active else "inactive"
                print(f"#{u.id}\t{u.role}\t{state}\t{u.name}\t{u.projects_root}")
        elif args.cmd == "rotate":
            key = users_core.rotate_key(db, args.id)
            _print_key(db.get_user(args.id), key, args.qr, worker_url)
        elif args.cmd == "deactivate":
            users_core.deactivate(db, args.id)
            print(f"user #{args.id} deactivated")
        elif args.cmd == "set-root":
            if db.get_user(args.id) is None:
                raise LookupError("user not found")
            db.update_user(args.id, projects_root=users_core.normalize_root(args.path))
            print(f"user #{args.id} root: {db.get_user(args.id).projects_root}")
        elif args.cmd == "assign-app":
            if db.get_user(args.user_id) is None:
                raise LookupError("user not found")
            if db.get_app(args.app_id) is None:
                raise LookupError("app not found")
            db.update_app(args.app_id, owner_user_id=args.user_id)
            print(f"app #{args.app_id} -> user #{args.user_id}")
    except (LookupError, ValueError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
