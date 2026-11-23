"""Users, roles and API keys (multi-user AGB).

Two roles:

* ``admin``  - sees and does everything. User id 1 is the implicit admin: the
  single key in ``settings.json -> security.api_key`` always resolves to it, so
  a server that never created a user keeps working exactly as before.
* ``member`` - sees and acts only on the apps it owns (``apps.owner_user_id``);
  server-wide tools are refused (see ``core/access.py``).

Keys are random tokens shown ONCE at creation/rotation. Only their SHA-256 is
stored (``users.api_key_hash``); a lost key is rotated, never recovered.
"""
from __future__ import annotations

import hashlib
import os
import secrets
from dataclasses import dataclass
from typing import Optional

ROLE_ADMIN = "admin"
ROLE_MEMBER = "member"
ROLES = (ROLE_ADMIN, ROLE_MEMBER)

# Row created by migration 16. The settings.json key maps to this user.
IMPLICIT_ADMIN_ID = 1


@dataclass
class User:
    id: int = 0
    name: str = ""
    role: str = ROLE_MEMBER
    active: bool = True
    projects_root: str = ""
    created_at: str = ""

    @property
    def is_admin(self) -> bool:
        return self.role == ROLE_ADMIN

    def public_dict(self) -> dict:
        """Safe to send to clients: never contains the key or its hash."""
        return {
            "id": self.id,
            "name": self.name,
            "role": self.role,
            "active": self.active,
            "projects_root": self.projects_root,
            "created_at": self.created_at,
        }


def implicit_admin() -> User:
    return User(id=IMPLICIT_ADMIN_ID, name="admin", role=ROLE_ADMIN, active=True)


def hash_key(key: str) -> str:
    return hashlib.sha256(key.encode("utf-8")).hexdigest()


def generate_key() -> str:
    # 32 random bytes, URL-safe: fits in a header, a QR code and a text field.
    return secrets.token_urlsafe(32)


def resolve_user(db, provided_key: str, settings_key: str) -> Optional[User]:
    """Map an X-API-Key value to a user, or None when it matches nobody.

    The settings key is compared first (constant time) so the owner's requests
    never touch the users table. Member keys are looked up by hash; inactive
    users resolve to None.
    """
    if not provided_key:
        return None
    if settings_key and secrets.compare_digest(provided_key, settings_key):
        row = db.get_user(IMPLICIT_ADMIN_ID) if db is not None else None
        return row if row is not None else implicit_admin()
    if db is None:
        return None
    user = db.get_user_by_key_hash(hash_key(provided_key))
    if user is None or not user.active:
        return None
    return user


def create_user(db, name: str, role: str = ROLE_MEMBER, projects_root: str = "") -> tuple[User, str]:
    """Create a user and return (user, plain_key). The plain key is not stored."""
    name = (name or "").strip()
    if not name:
        raise ValueError("name is required")
    if role not in ROLES:
        raise ValueError(f"role must be one of {ROLES}")
    projects_root = normalize_root(projects_root) if projects_root else ""
    key = generate_key()
    uid = db.create_user(name=name, role=role, api_key_hash=hash_key(key),
                         projects_root=projects_root)
    return db.get_user(uid), key


def rotate_key(db, user_id: int) -> str:
    """Give a user a fresh key; the old one stops working at once."""
    if user_id == IMPLICIT_ADMIN_ID:
        raise ValueError("the main admin key lives in settings.json (security.api_key)")
    if db.get_user(user_id) is None:
        raise LookupError("user not found")
    key = generate_key()
    db.update_user(user_id, api_key_hash=hash_key(key))
    return key


def deactivate(db, user_id: int) -> None:
    if user_id == IMPLICIT_ADMIN_ID:
        raise ValueError("the main admin cannot be deactivated")
    if db.get_user(user_id) is None:
        raise LookupError("user not found")
    db.update_user(user_id, active=0)


# ── Paths ───────────────────────────────────────────────────

def normalize_root(path: str) -> str:
    return os.path.abspath(os.path.expanduser(path.strip()))


def path_within(root: str, path: str) -> bool:
    """True when ``path`` is strictly inside ``root`` after resolving ``..``,
    ``~`` and symlinks. The root itself does not count (an app needs its own
    folder)."""
    if not root or not path:
        return False
    r = os.path.realpath(normalize_root(root))
    p = os.path.realpath(normalize_root(path))
    try:
        return p != r and os.path.commonpath([r, p]) == r
    except ValueError:  # different drives on Windows
        return False


def projects_root_for(user: User, settings: dict) -> str:
    """Where this user's new apps are created.

    Admins use their own root if one is set, otherwise the server-wide
    ``projects_root``. Members MUST have their own root; the server root is
    never handed to them.
    """
    if user.projects_root:
        return user.projects_root
    if user.is_admin:
        return settings.get("projects_root", "") or os.path.join(os.path.expanduser("~"), "Projects")
    return ""


# ── Play service accounts ───────────────────────────────────

def play_service_account_path(settings: dict, account: Optional[str]) -> str:
    """Service-account JSON used for an app's Play upload.

    ``account`` None/'' -> the default ``service_account_key``. A name is looked
    up in ``play_accounts`` (``{"name": "/path/key.json"}``, put it under the
    ``paths`` section of settings.json). An unknown name is an error, never a
    silent fall back to the default account.
    """
    if not account:
        return settings.get("service_account_key", "") or ""
    accounts = settings.get("play_accounts") or {}
    if not isinstance(accounts, dict) or account not in accounts:
        raise ValueError(f"Unknown play_account '{account}' (not in settings play_accounts)")
    path = accounts.get(account) or ""
    return os.path.expanduser(path) if path else ""


def play_account_names(settings: dict) -> list[str]:
    accounts = settings.get("play_accounts") or {}
    return sorted(accounts) if isinstance(accounts, dict) else []
