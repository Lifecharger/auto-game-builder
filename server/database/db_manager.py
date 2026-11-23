"""Thread-safe SQLite database manager with CRUD for all tables."""

import json
import re
import sqlite3
import threading
from typing import Optional
from database.models import (
    App, Issue, AutofixSession, Build, VersionHistory, AppTemplate, AppGroup,
)
from database.migrations import MIGRATIONS, get_migration_count
from core.users import User

_SAFE_COLUMN_RE = re.compile(r"^[a-zA-Z_][a-zA-Z0-9_]*$")


def _validate_columns(cols: list[str]):
    for c in cols:
        if not _SAFE_COLUMN_RE.match(c):
            raise ValueError(f"Invalid column name: {c!r}")


def _normalize_since(since: str) -> str:
    """Normalise a client-supplied ISO timestamp to the SQLite `datetime('now')`
    format ('YYYY-MM-DD HH:MM:SS', no fractional seconds, no timezone, space
    separator) so plain string comparison against `updated_at`/`created_at`
    works.

    Why this exists: SQLite stores `datetime('now')` as
    '2026-04-14 09:01:59' (space, no microseconds, no TZ), but the FastAPI
    layer hands clients `datetime.now().isoformat()` which produces
    '2026-04-14T09:01:59.123456' (T, microseconds). Doing
    `WHERE updated_at > ?` with a raw isoformat string compares 'space' (0x20)
    against 'T' (0x54) at index 10 — every DB row is "less than" any client
    timestamp, so the delta sync silently returns zero rows and the cache
    on the device freezes forever. Normalising the input here makes the
    comparison meaningful again without forcing every caller to format dates
    the same way.
    """
    if not since:
        return since
    s = since.strip()
    if s.endswith("Z"):
        s = s[:-1]
    # Replace ISO 'T' separator with the space SQLite uses.
    if "T" in s:
        s = s.replace("T", " ", 1)
    # Strip any trailing timezone offset like '+03:00' or '-05:30' that would
    # make string comparison meaningless. Look for +/- after the time portion.
    for sign in ("+", "-"):
        idx = s.find(sign, 11)  # skip leading '-' in date
        if idx != -1:
            s = s[:idx]
            break
    # Cut off microseconds at the dot — SQLite's datetime('now') has none.
    if "." in s:
        s = s.split(".", 1)[0]
    return s


class DBManager:
    def __init__(self, db_path: str):
        self.db_path = db_path
        self._local = threading.local()
        self.run_migrations()

    def _get_conn(self) -> sqlite3.Connection:
        if not hasattr(self._local, "conn") or self._local.conn is None:
            self._local.conn = sqlite3.connect(self.db_path)
            self._local.conn.row_factory = sqlite3.Row
            self._local.conn.execute("PRAGMA journal_mode=WAL")
            self._local.conn.execute("PRAGMA foreign_keys=ON")
        return self._local.conn

    def run_migrations(self):
        conn = self._get_conn()
        conn.execute(
            "CREATE TABLE IF NOT EXISTS schema_version "
            "(version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL DEFAULT (datetime('now')))"
        )
        cur = conn.execute("SELECT MAX(version) FROM schema_version")
        row = cur.fetchone()
        current = row[0] if row[0] is not None else 0

        for i in range(current, get_migration_count()):
            conn.executescript(MIGRATIONS[i])
            conn.execute("INSERT INTO schema_version (version) VALUES (?)", (i + 1,))
            conn.commit()

    # ── Deletion Tracking ────────────────────────────────────

    def _log_deletion(self, table_name: str, record_id: int, app_id: int | None = None):
        conn = self._get_conn()
        conn.execute(
            "INSERT INTO deleted_records (table_name, record_id, app_id) VALUES (?, ?, ?)",
            (table_name, record_id, app_id),
        )

    def get_deleted_since(self, since: str) -> list[dict]:
        conn = self._get_conn()
        rows = conn.execute(
            "SELECT table_name, record_id, app_id, deleted_at FROM deleted_records WHERE deleted_at >= ?",
            (_normalize_since(since),),
        ).fetchall()
        return [{"table": r["table_name"], "record_id": r["record_id"], "app_id": r["app_id"], "deleted_at": r["deleted_at"]} for r in rows]

    def get_apps_since(self, since: str) -> list[App]:
        conn = self._get_conn()
        s = _normalize_since(since)
        rows = conn.execute(
            "SELECT * FROM apps WHERE updated_at >= ? OR created_at >= ?", (s, s)
        ).fetchall()
        return [self._row_to_app(r) for r in rows]

    def get_issues_since(self, since: str) -> list[Issue]:
        conn = self._get_conn()
        s = _normalize_since(since)
        rows = conn.execute(
            "SELECT * FROM issues WHERE updated_at >= ? OR created_at >= ?", (s, s)
        ).fetchall()
        return [self._row_to_issue(r) for r in rows]

    def get_builds_since(self, since: str) -> list[Build]:
        conn = self._get_conn()
        s = _normalize_since(since)
        rows = conn.execute(
            "SELECT * FROM builds WHERE updated_at >= ? OR created_at >= ?", (s, s)
        ).fetchall()
        return [self._row_to_build(r) for r in rows]

    def get_sessions_since(self, since: str) -> list[AutofixSession]:
        conn = self._get_conn()
        s = _normalize_since(since)
        rows = conn.execute(
            "SELECT * FROM autofix_sessions WHERE updated_at >= ? OR created_at >= ?", (s, s)
        ).fetchall()
        return [self._row_to_session(r) for r in rows]

    def get_all_issues(self) -> list[Issue]:
        conn = self._get_conn()
        rows = conn.execute("SELECT * FROM issues ORDER BY id").fetchall()
        return [self._row_to_issue(r) for r in rows]

    def get_all_builds(self) -> list[Build]:
        conn = self._get_conn()
        rows = conn.execute("SELECT * FROM builds ORDER BY id").fetchall()
        return [self._row_to_build(r) for r in rows]

    def get_all_sessions(self) -> list[AutofixSession]:
        conn = self._get_conn()
        rows = conn.execute("SELECT * FROM autofix_sessions ORDER BY id").fetchall()
        return [self._row_to_session(r) for r in rows]

    # ── Apps ─────────────────────────────────────────────────

    def create_app(self, **kwargs) -> int:
        conn = self._get_conn()
        cols = [k for k in kwargs]
        _validate_columns(cols)
        placeholders = ["?" for _ in cols]
        vals = [kwargs[k] for k in cols]
        cur = conn.execute(
            f"INSERT INTO apps ({','.join(cols)}) VALUES ({','.join(placeholders)})",
            vals,
        )
        conn.commit()
        return cur.lastrowid

    def get_app(self, app_id: int) -> Optional[App]:
        conn = self._get_conn()
        row = conn.execute("SELECT * FROM apps WHERE id=?", (app_id,)).fetchone()
        return self._row_to_app(row) if row else None

    def get_app_by_slug(self, slug: str) -> Optional[App]:
        conn = self._get_conn()
        row = conn.execute("SELECT * FROM apps WHERE slug=?", (slug,)).fetchone()
        return self._row_to_app(row) if row else None

    def get_all_apps(self, include_archived: bool = False) -> list[App]:
        conn = self._get_conn()
        if include_archived:
            rows = conn.execute("SELECT * FROM apps ORDER BY name").fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM apps WHERE is_archived=0 ORDER BY name"
            ).fetchall()
        return [self._row_to_app(r) for r in rows]

    def get_app_ids_for_owner(self, owner_user_id: int) -> set[int]:
        conn = self._get_conn()
        rows = conn.execute("SELECT id FROM apps WHERE owner_user_id=?", (owner_user_id,)).fetchall()
        return {r["id"] for r in rows}

    def update_app(self, app_id: int, **kwargs):
        conn = self._get_conn()
        if not kwargs:
            conn.execute("UPDATE apps SET updated_at=datetime('now') WHERE id=?", (app_id,))
            conn.commit()
            return
        _validate_columns(list(kwargs.keys()))
        sets = [f"{k}=?" for k in kwargs]
        vals = [kwargs[k] for k in kwargs]
        vals.append(app_id)
        conn.execute(
            f"UPDATE apps SET {','.join(sets)}, updated_at=datetime('now') WHERE id=?",
            vals,
        )
        conn.commit()

    def touch_app(self, app_id: int):
        """Bump updated_at so delta sync picks up out-of-band changes (tasklist.json, etc.)."""
        conn = self._get_conn()
        conn.execute("UPDATE apps SET updated_at=datetime('now') WHERE id=?", (app_id,))
        conn.commit()

    def delete_app(self, app_id: int):
        conn = self._get_conn()
        for row in conn.execute("SELECT id FROM issues WHERE app_id=?", (app_id,)).fetchall():
            self._log_deletion("issues", row["id"], app_id)
        for row in conn.execute("SELECT id FROM autofix_sessions WHERE app_id=?", (app_id,)).fetchall():
            self._log_deletion("autofix_sessions", row["id"], app_id)
        for row in conn.execute("SELECT id FROM builds WHERE app_id=?", (app_id,)).fetchall():
            self._log_deletion("builds", row["id"], app_id)
        conn.execute("DELETE FROM issues WHERE app_id=?", (app_id,))
        conn.execute("DELETE FROM autofix_sessions WHERE app_id=?", (app_id,))
        conn.execute("DELETE FROM builds WHERE app_id=?", (app_id,))
        conn.execute("DELETE FROM version_history WHERE app_id=?", (app_id,))
        self._log_deletion("apps", app_id, app_id)
        conn.execute("DELETE FROM apps WHERE id=?", (app_id,))
        conn.commit()

    def _row_to_app(self, row) -> App:
        return App(
            id=row["id"],
            name=row["name"],
            slug=row["slug"],
            project_path=row["project_path"],
            app_type=row["app_type"],
            current_version=row["current_version"] or "",
            package_name=row["package_name"] or "",
            build_command=row["build_command"] or "",
            build_output_path=row["build_output_path"] or "",
            claude_md_path=row["claude_md_path"] or "",
            fix_strategy=row["fix_strategy"] or "claude",
            status=row["status"] or "idle",
            publish_status=row["publish_status"] or "development",
            last_build_at=row["last_build_at"],
            last_fix_at=row["last_fix_at"],
            notes=row["notes"] or "",
            tech_stack=row["tech_stack"] or "{}",
            mcp_config_path=row["mcp_config_path"] or "",
            automation_script_path=row["automation_script_path"] or "",
            is_archived=bool(row["is_archived"]),
            build_targets=row["build_targets"] or "{}",
            group_name=row["group_name"] or "",
            icon_path=row["icon_path"] or "",
            github_url=row["github_url"] or "",
            play_store_url=row["play_store_url"] or "",
            website_url=row["website_url"] or "",
            console_url=row["console_url"] or "",
            last_upload_track=row["last_upload_track"] or "",
            last_upload_at=row["last_upload_at"],
            last_ios_upload_track=(row["last_ios_upload_track"] if "last_ios_upload_track" in row.keys() else "") or "",
            last_ios_upload_at=(row["last_ios_upload_at"] if "last_ios_upload_at" in row.keys() else None),
            last_ios_build_status=(row["last_ios_build_status"] if "last_ios_build_status" in row.keys() else "") or "",
            apple_app_id=(row["apple_app_id"] if "apple_app_id" in row.keys() else "") or "",
            app_store_url=(row["app_store_url"] if "app_store_url" in row.keys() else "") or "",
            owner_user_id=(row["owner_user_id"] if "owner_user_id" in row.keys() else 1) or 1,
            play_account=(row["play_account"] if "play_account" in row.keys() else None) or None,
            git_ssh_key_path=(row["git_ssh_key_path"] if "git_ssh_key_path" in row.keys() else "") or "",
            created_at=row["created_at"] or "",
            updated_at=row["updated_at"] or "",
        )

    # ── Users ────────────────────────────────────────────────
    # The key hash is written here but never read back out: lookups go by
    # hash, and every user object handed upward is built without it.

    _USER_COLS = "id, name, role, projects_root, created_at, active"

    def _row_to_user(self, row) -> User:
        return User(
            id=row["id"], name=row["name"] or "", role=row["role"] or "member",
            active=bool(row["active"]), projects_root=row["projects_root"] or "",
            created_at=row["created_at"] or "",
        )

    def create_user(self, name: str, role: str, api_key_hash: str, projects_root: str = "") -> int:
        conn = self._get_conn()
        cur = conn.execute(
            "INSERT INTO users (name, role, api_key_hash, projects_root) VALUES (?,?,?,?)",
            (name, role, api_key_hash, projects_root or ""),
        )
        conn.commit()
        return cur.lastrowid

    def get_user(self, user_id: int) -> Optional[User]:
        conn = self._get_conn()
        row = conn.execute(f"SELECT {self._USER_COLS} FROM users WHERE id=?", (user_id,)).fetchone()
        return self._row_to_user(row) if row else None

    def get_user_by_key_hash(self, key_hash: str) -> Optional[User]:
        if not key_hash:
            return None
        conn = self._get_conn()
        row = conn.execute(
            f"SELECT {self._USER_COLS} FROM users WHERE api_key_hash=?", (key_hash,)
        ).fetchone()
        return self._row_to_user(row) if row else None

    def list_users(self) -> list[User]:
        conn = self._get_conn()
        rows = conn.execute(f"SELECT {self._USER_COLS} FROM users ORDER BY id").fetchall()
        return [self._row_to_user(r) for r in rows]

    def update_user(self, user_id: int, **kwargs):
        allowed = {"name", "role", "api_key_hash", "projects_root", "active"}
        bad = set(kwargs) - allowed
        if bad:
            raise ValueError(f"Invalid user columns: {sorted(bad)}")
        if not kwargs:
            return
        conn = self._get_conn()
        sets = [f"{k}=?" for k in kwargs]
        conn.execute(f"UPDATE users SET {','.join(sets)} WHERE id=?", [*kwargs.values(), user_id])
        conn.commit()

    def user_names(self) -> dict[int, str]:
        conn = self._get_conn()
        return {r["id"]: r["name"] for r in conn.execute("SELECT id, name FROM users").fetchall()}

    # ── Issues ───────────────────────────────────────────────

    def create_issue(self, **kwargs) -> int:
        conn = self._get_conn()
        cols = list(kwargs.keys())
        _validate_columns(cols)
        cur = conn.execute(
            f"INSERT INTO issues ({','.join(cols)}) VALUES ({','.join('?' for _ in cols)})",
            list(kwargs.values()),
        )
        conn.commit()
        return cur.lastrowid

    def get_issue(self, issue_id: int) -> Optional[Issue]:
        conn = self._get_conn()
        row = conn.execute("SELECT * FROM issues WHERE id=?", (issue_id,)).fetchone()
        return self._row_to_issue(row) if row else None

    def get_issues(
        self,
        app_id: Optional[int] = None,
        status: Optional[str] = None,
        category: Optional[str] = None,
        priority: Optional[int] = None,
    ) -> list[Issue]:
        conn = self._get_conn()
        query = "SELECT * FROM issues WHERE 1=1"
        params = []
        if app_id is not None:
            query += " AND app_id=?"
            params.append(app_id)
        if status:
            query += " AND status=?"
            params.append(status)
        if category:
            query += " AND category=?"
            params.append(category)
        if priority is not None:
            query += " AND priority=?"
            params.append(priority)
        query += " ORDER BY created_at DESC"
        return [self._row_to_issue(r) for r in conn.execute(query, params).fetchall()]

    def count_issues(self, app_id: int, status: Optional[str] = None) -> int:
        conn = self._get_conn()
        if status:
            row = conn.execute(
                "SELECT COUNT(*) FROM issues WHERE app_id=? AND status=?",
                (app_id, status),
            ).fetchone()
        else:
            row = conn.execute(
                "SELECT COUNT(*) FROM issues WHERE app_id=?", (app_id,)
            ).fetchone()
        return row[0]

    def count_issues_by_app(self, status: Optional[str] = None) -> dict[int, int]:
        conn = self._get_conn()
        if status:
            rows = conn.execute(
                "SELECT app_id, COUNT(*) as cnt FROM issues WHERE status=? GROUP BY app_id",
                (status,),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT app_id, COUNT(*) as cnt FROM issues GROUP BY app_id"
            ).fetchall()
        return {r["app_id"]: r["cnt"] for r in rows}

    def update_issue(self, issue_id: int, **kwargs):
        conn = self._get_conn()
        _validate_columns(list(kwargs.keys()))
        sets = [f"{k}=?" for k in kwargs]
        vals = list(kwargs.values())
        vals.append(issue_id)
        conn.execute(
            f"UPDATE issues SET {','.join(sets)}, updated_at=datetime('now') WHERE id=?",
            vals,
        )
        conn.commit()

    def delete_issue(self, issue_id: int):
        conn = self._get_conn()
        row = conn.execute("SELECT app_id FROM issues WHERE id=?", (issue_id,)).fetchone()
        self._log_deletion("issues", issue_id, row["app_id"] if row else None)
        conn.execute("DELETE FROM issues WHERE id=?", (issue_id,))
        conn.commit()

    def _row_to_issue(self, row) -> Issue:
        return Issue(
            id=row["id"],
            app_id=row["app_id"],
            title=row["title"],
            description=row["description"] or "",
            category=row["category"] or "bug",
            priority=row["priority"] or 3,
            status=row["status"] or "open",
            source=row["source"] or "manual",
            raw_data=row["raw_data"] or "",
            fix_prompt=row["fix_prompt"] or "",
            fix_result=row["fix_result"] or "",
            fix_session_id=row["fix_session_id"],
            assigned_ai=row["assigned_ai"] or "",
            created_at=row["created_at"] or "",
            updated_at=row["updated_at"] or "",
        )

    # ── Reports (in-game bug reports / suggestions) ──────────

    def create_report(self, **kwargs):
        """Insert a pulled report. Idempotent: INSERT OR IGNORE on the worker's
        uuid primary key, so re-pulling the same report is a no-op."""
        conn = self._get_conn()
        cols = list(kwargs.keys())
        _validate_columns(cols)
        conn.execute(
            f"INSERT OR IGNORE INTO reports ({','.join(cols)}) VALUES ({','.join('?' for _ in cols)})",
            list(kwargs.values()),
        )
        conn.commit()

    def report_exists(self, report_id: str) -> bool:
        conn = self._get_conn()
        return conn.execute("SELECT 1 FROM reports WHERE id=?", (report_id,)).fetchone() is not None

    def get_reports(self, status: Optional[str] = None, owner_user_id: Optional[int] = None) -> list[dict]:
        """`owner_user_id` limits the list to reports of that user's apps."""
        conn = self._get_conn()
        query = (
            "SELECT r.*, a.name AS app_name FROM reports r "
            "LEFT JOIN apps a ON r.app_id = a.id WHERE 1=1"
        )
        params: list = []
        if status and status != "all":
            query += " AND r.status=?"
            params.append(status)
        if owner_user_id is not None:
            query += " AND a.owner_user_id=?"
            params.append(owner_user_id)
        query += " ORDER BY r.pulled_at DESC, r.rowid DESC"
        return [dict(row) for row in conn.execute(query, params).fetchall()]

    def get_report(self, report_id: str) -> Optional[dict]:
        conn = self._get_conn()
        row = conn.execute(
            "SELECT r.*, a.name AS app_name FROM reports r "
            "LEFT JOIN apps a ON r.app_id = a.id WHERE r.id=?",
            (report_id,),
        ).fetchone()
        return dict(row) if row else None

    def update_report(self, report_id: str, **kwargs):
        conn = self._get_conn()
        _validate_columns(list(kwargs.keys()))
        sets = [f"{k}=?" for k in kwargs]
        vals = list(kwargs.values())
        vals.append(report_id)
        conn.execute(f"UPDATE reports SET {','.join(sets)} WHERE id=?", vals)
        conn.commit()

    def delete_report(self, report_id: str):
        conn = self._get_conn()
        conn.execute("DELETE FROM reports WHERE id=?", (report_id,))
        conn.commit()

    def count_reports(self, status: Optional[str] = None, owner_user_id: Optional[int] = None) -> int:
        conn = self._get_conn()
        query = "SELECT COUNT(*) FROM reports r LEFT JOIN apps a ON r.app_id = a.id WHERE 1=1"
        params: list = []
        if status and status != "all":
            query += " AND r.status=?"
            params.append(status)
        if owner_user_id is not None:
            query += " AND a.owner_user_id=?"
            params.append(owner_user_id)
        return conn.execute(query, params).fetchone()[0]

    # ── Notices (notes for the owner from automations) ───────

    def upsert_notice(self, source: str, title: str, body: str, note_key: Optional[str] = None,
                      user_id: Optional[int] = None) -> int:
        """Add a notice. With a `note_key` a rerun replaces its earlier notice
        (and marks it unread again) instead of adding a second one.
        `user_id` None = a server/admin notice; a member's notice carries its id
        and only ever replaces its own notices (its keys are stored as
        "u<id>:<key>" because note_key is unique across the table)."""
        conn = self._get_conn()
        if note_key and user_id is not None:
            note_key = f"u{user_id}:{note_key}"
        if note_key:
            row = conn.execute("SELECT id FROM notices WHERE note_key=? AND user_id IS ?",
                               (note_key, user_id)).fetchone()
            if row:
                conn.execute(
                    "UPDATE notices SET source=?, title=?, body=?, is_read=0, updated_at=datetime('now') WHERE id=?",
                    (source, title, body, row["id"]),
                )
                conn.commit()
                return row["id"]
        cur = conn.execute(
            "INSERT INTO notices (source, title, body, note_key, user_id) VALUES (?,?,?,?,?)",
            (source, title, body, note_key or None, user_id),
        )
        conn.commit()
        return cur.lastrowid

    def get_notices(self, unread_only: bool = False, limit: int = 200,
                    user_id: Optional[int] = None) -> list[dict]:
        """`user_id` given -> only that user's notices (a member's view)."""
        conn = self._get_conn()
        query = "SELECT * FROM notices WHERE 1=1"
        params: list = []
        if unread_only:
            query += " AND is_read=0"
        if user_id is not None:
            query += " AND user_id=?"
            params.append(user_id)
        query += " ORDER BY updated_at DESC, id DESC LIMIT ?"
        params.append(limit)
        return [dict(row) for row in conn.execute(query, params).fetchall()]

    def get_notice(self, notice_id: int) -> Optional[dict]:
        conn = self._get_conn()
        row = conn.execute("SELECT * FROM notices WHERE id=?", (notice_id,)).fetchone()
        return dict(row) if row else None

    def set_notice_read(self, notice_id: int, read: bool):
        conn = self._get_conn()
        conn.execute("UPDATE notices SET is_read=? WHERE id=?", (1 if read else 0, notice_id))
        conn.commit()

    def delete_notice(self, notice_id: int):
        conn = self._get_conn()
        conn.execute("DELETE FROM notices WHERE id=?", (notice_id,))
        conn.commit()

    def count_notices(self, unread_only: bool = False, user_id: Optional[int] = None) -> int:
        conn = self._get_conn()
        q = "SELECT COUNT(*) FROM notices WHERE 1=1"
        params: list = []
        if unread_only:
            q += " AND is_read=0"
        if user_id is not None:
            q += " AND user_id=?"
            params.append(user_id)
        return conn.execute(q, params).fetchone()[0]

    # ── Autofix Sessions ─────────────────────────────────────

    def create_session(self, **kwargs) -> int:
        conn = self._get_conn()
        cols = list(kwargs.keys())
        _validate_columns(cols)
        cur = conn.execute(
            f"INSERT INTO autofix_sessions ({','.join(cols)}) VALUES ({','.join('?' for _ in cols)})",
            list(kwargs.values()),
        )
        conn.commit()
        return cur.lastrowid

    def get_session(self, session_id: int) -> Optional[AutofixSession]:
        conn = self._get_conn()
        row = conn.execute(
            "SELECT * FROM autofix_sessions WHERE id=?", (session_id,)
        ).fetchone()
        return self._row_to_session(row) if row else None

    def get_sessions(
        self,
        app_id: Optional[int] = None,
        status: Optional[str] = None,
        limit: int = 50,
    ) -> list[AutofixSession]:
        conn = self._get_conn()
        query = "SELECT * FROM autofix_sessions WHERE 1=1"
        params: list = []
        if app_id is not None:
            query += " AND app_id=?"
            params.append(app_id)
        if status:
            query += " AND status=?"
            params.append(status)
        query += " ORDER BY created_at DESC LIMIT ?"
        params.append(limit)
        return [self._row_to_session(r) for r in conn.execute(query, params).fetchall()]

    def update_session(self, session_id: int, **kwargs):
        conn = self._get_conn()
        _validate_columns(list(kwargs.keys()))
        sets = [f"{k}=?" for k in kwargs]
        vals = list(kwargs.values())
        vals.append(session_id)
        conn.execute(
            f"UPDATE autofix_sessions SET {','.join(sets)}, updated_at=datetime('now') WHERE id=?",
            vals,
        )
        conn.commit()

    def _row_to_session(self, row) -> AutofixSession:
        return AutofixSession(
            id=row["id"],
            app_id=row["app_id"],
            issue_id=row["issue_id"],
            ai_tool=row["ai_tool"] or "claude",
            prompt_used=row["prompt_used"] or "",
            status=row["status"] or "pending",
            exit_code=row["exit_code"],
            log_file_path=row["log_file_path"] or "",
            duration_seconds=row["duration_seconds"],
            error_message=row["error_message"] or "",
            files_changed=row["files_changed"] or "[]",
            started_at=row["started_at"],
            completed_at=row["completed_at"],
            created_at=row["created_at"] or "",
            updated_at=row["updated_at"] or "",
        )

    # ── Builds ───────────────────────────────────────────────

    def create_build(self, **kwargs) -> int:
        conn = self._get_conn()
        cols = list(kwargs.keys())
        _validate_columns(cols)
        cur = conn.execute(
            f"INSERT INTO builds ({','.join(cols)}) VALUES ({','.join('?' for _ in cols)})",
            list(kwargs.values()),
        )
        conn.commit()
        return cur.lastrowid

    def get_build(self, build_id: int) -> Optional[Build]:
        conn = self._get_conn()
        row = conn.execute("SELECT * FROM builds WHERE id=?", (build_id,)).fetchone()
        return self._row_to_build(row) if row else None

    def get_builds(self, app_id: Optional[int] = None, limit: int = 20) -> list[Build]:
        conn = self._get_conn()
        if app_id is not None:
            rows = conn.execute(
                "SELECT * FROM builds WHERE app_id=? ORDER BY created_at DESC LIMIT ?",
                (app_id, limit),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM builds ORDER BY created_at DESC LIMIT ?", (limit,)
            ).fetchall()
        return [self._row_to_build(r) for r in rows]

    def update_build(self, build_id: int, **kwargs):
        conn = self._get_conn()
        _validate_columns(list(kwargs.keys()))
        sets = [f"{k}=?" for k in kwargs]
        vals = list(kwargs.values())
        vals.append(build_id)
        conn.execute(
            f"UPDATE builds SET {','.join(sets)}, updated_at=datetime('now') WHERE id=?",
            vals,
        )
        conn.commit()

    def _row_to_build(self, row) -> Build:
        return Build(
            id=row["id"],
            app_id=row["app_id"],
            build_type=row["build_type"] or "appbundle",
            version=row["version"] or "",
            status=row["status"] or "pending",
            output_path=row["output_path"] or "",
            log_output=row["log_output"] or "",
            duration_seconds=row["duration_seconds"],
            started_at=row["started_at"],
            completed_at=row["completed_at"],
            created_at=row["created_at"] or "",
            updated_at=row["updated_at"] or "",
            started_by_user_id=(row["started_by_user_id"] if "started_by_user_id" in row.keys() else None),
        )

    # ── Version History ──────────────────────────────────────

    # ── Store status (Google Play / App Store Connect memory) ──

    def get_store_status(self, app_id: int) -> dict[str, dict]:
        """{store: {data, refreshed_at, error, error_at}} for one app."""
        rows = self._get_conn().execute(
            "SELECT store, data, refreshed_at, error, error_at FROM store_status WHERE app_id=?",
            (app_id,),
        ).fetchall()
        out = {}
        for r in rows:
            try:
                data = json.loads(r["data"] or "{}")
            except ValueError:
                data = {}
            out[r["store"]] = {
                "data": data, "refreshed_at": r["refreshed_at"],
                "error": r["error"] or "", "error_at": r["error_at"],
            }
        return out

    def save_store_status(self, app_id: int, store: str, data: dict, refreshed_at: str):
        """A successful refresh: new data, error cleared."""
        conn = self._get_conn()
        conn.execute(
            "INSERT INTO store_status (app_id, store, data, refreshed_at, error, error_at) "
            "VALUES (?, ?, ?, ?, '', NULL) "
            "ON CONFLICT(app_id, store) DO UPDATE SET data=excluded.data, "
            "refreshed_at=excluded.refreshed_at, error='', error_at=NULL",
            (app_id, store, json.dumps(data, sort_keys=True), refreshed_at),
        )
        conn.commit()

    def save_store_status_error(self, app_id: int, store: str, error: str, error_at: str):
        """A failed refresh: the last known data stays, the error is kept beside it."""
        conn = self._get_conn()
        conn.execute(
            "INSERT INTO store_status (app_id, store, error, error_at) VALUES (?, ?, ?, ?) "
            "ON CONFLICT(app_id, store) DO UPDATE SET error=excluded.error, error_at=excluded.error_at",
            (app_id, store, error[:1000], error_at),
        )
        conn.commit()

    def add_store_promotion(self, **kwargs) -> int:
        cols = list(kwargs.keys())
        _validate_columns(cols)
        conn = self._get_conn()
        cur = conn.execute(
            f"INSERT INTO store_promotions ({','.join(cols)}) VALUES ({','.join('?' * len(cols))})",
            [kwargs[c] for c in cols],
        )
        conn.commit()
        return cur.lastrowid

    def get_store_promotions(self, app_id: int, limit: int = 50) -> list[dict]:
        rows = self._get_conn().execute(
            "SELECT * FROM store_promotions WHERE app_id=? ORDER BY id DESC LIMIT ?",
            (app_id, limit),
        ).fetchall()
        return [dict(r) for r in rows]

    def create_version_entry(self, **kwargs) -> int:
        conn = self._get_conn()
        cols = list(kwargs.keys())
        _validate_columns(cols)
        cur = conn.execute(
            f"INSERT INTO version_history ({','.join(cols)}) VALUES ({','.join('?' for _ in cols)})",
            list(kwargs.values()),
        )
        conn.commit()
        return cur.lastrowid

    def get_version_history(self, app_id: int, limit: int = 20) -> list[VersionHistory]:
        conn = self._get_conn()
        rows = conn.execute(
            "SELECT * FROM version_history WHERE app_id=? ORDER BY created_at DESC LIMIT ?",
            (app_id, limit),
        ).fetchall()
        return [
            VersionHistory(
                id=r["id"],
                app_id=r["app_id"],
                old_version=r["old_version"],
                new_version=r["new_version"],
                bump_type=r["bump_type"] or "",
                changed_by=r["changed_by"] or "manual",
                created_at=r["created_at"] or "",
            )
            for r in rows
        ]

    # ── App Templates ────────────────────────────────────────

    def create_template(self, **kwargs) -> int:
        conn = self._get_conn()
        cols = list(kwargs.keys())
        _validate_columns(cols)
        cur = conn.execute(
            f"INSERT INTO app_templates ({','.join(cols)}) VALUES ({','.join('?' for _ in cols)})",
            list(kwargs.values()),
        )
        conn.commit()
        return cur.lastrowid

    def get_templates(self) -> list[AppTemplate]:
        conn = self._get_conn()
        rows = conn.execute(
            "SELECT * FROM app_templates ORDER BY name"
        ).fetchall()
        return [
            AppTemplate(
                id=r["id"],
                name=r["name"],
                app_type=r["app_type"] or "flutter",
                description=r["description"] or "",
                default_build_command=r["default_build_command"] or "",
                default_build_output=r["default_build_output"] or "",
                default_prompt_template=r["default_prompt_template"] or "",
                tech_stack=r["tech_stack"] or "{}",
                created_at=r["created_at"] or "",
            )
            for r in rows
        ]

    def delete_template(self, template_id: int):
        conn = self._get_conn()
        self._log_deletion("app_templates", template_id, None)
        conn.execute("DELETE FROM app_templates WHERE id=?", (template_id,))
        conn.commit()

    # ── Settings ─────────────────────────────────────────────

    def get_setting(self, key: str, default: str = "") -> str:
        conn = self._get_conn()
        row = conn.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
        return row["value"] if row else default

    def set_setting(self, key: str, value: str):
        conn = self._get_conn()
        conn.execute(
            "INSERT INTO settings (key, value, updated_at) VALUES (?, ?, datetime('now')) "
            "ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=datetime('now')",
            (key, value),
        )
        conn.commit()

    def get_all_settings(self) -> dict[str, str]:
        conn = self._get_conn()
        rows = conn.execute("SELECT key, value FROM settings").fetchall()
        return {r["key"]: r["value"] for r in rows}

    # ── App Groups ────────────────────────────────────────────

    def create_group(self, name: str, description: str = "", color: str = "#3498db") -> int:
        conn = self._get_conn()
        cur = conn.execute(
            "INSERT INTO app_groups (name, description, color) VALUES (?, ?, ?)",
            (name, description, color),
        )
        conn.commit()
        return cur.lastrowid

    def get_groups(self) -> list[AppGroup]:
        conn = self._get_conn()
        rows = conn.execute("SELECT * FROM app_groups ORDER BY name").fetchall()
        return [
            AppGroup(
                id=r["id"], name=r["name"],
                description=r["description"] or "",
                color=r["color"] or "#3498db",
                created_at=r["created_at"] or "",
            )
            for r in rows
        ]

    def get_group(self, group_id: int) -> Optional[AppGroup]:
        conn = self._get_conn()
        row = conn.execute("SELECT * FROM app_groups WHERE id=?", (group_id,)).fetchone()
        if not row:
            return None
        return AppGroup(
            id=row["id"], name=row["name"],
            description=row["description"] or "",
            color=row["color"] or "#3498db",
            created_at=row["created_at"] or "",
        )

    def get_group_by_name(self, name: str) -> Optional[AppGroup]:
        conn = self._get_conn()
        row = conn.execute("SELECT * FROM app_groups WHERE name=?", (name,)).fetchone()
        if not row:
            return None
        return AppGroup(
            id=row["id"], name=row["name"],
            description=row["description"] or "",
            color=row["color"] or "#3498db",
            created_at=row["created_at"] or "",
        )

    def update_group(self, group_id: int, **kwargs):
        conn = self._get_conn()
        _validate_columns(list(kwargs.keys()))
        sets = [f"{k}=?" for k in kwargs]
        vals = list(kwargs.values())
        vals.append(group_id)
        conn.execute(f"UPDATE app_groups SET {','.join(sets)} WHERE id=?", vals)
        conn.commit()

    def delete_group(self, group_id: int):
        conn = self._get_conn()
        group = self.get_group(group_id)
        if group:
            conn.execute(
                "UPDATE apps SET group_name='' WHERE group_name=?", (group.name,)
            )
        self._log_deletion("app_groups", group_id, None)
        conn.execute("DELETE FROM app_groups WHERE id=?", (group_id,))
        conn.commit()

    def get_apps_by_group(self, group_name: str) -> list[App]:
        conn = self._get_conn()
        rows = conn.execute(
            "SELECT * FROM apps WHERE group_name=? AND is_archived=0 ORDER BY name",
            (group_name,),
        ).fetchall()
        return [self._row_to_app(r) for r in rows]

    def get_ungrouped_apps(self) -> list[App]:
        conn = self._get_conn()
        rows = conn.execute(
            "SELECT * FROM apps WHERE (group_name='' OR group_name IS NULL) AND is_archived=0 ORDER BY name"
        ).fetchall()
        return [self._row_to_app(r) for r in rows]

