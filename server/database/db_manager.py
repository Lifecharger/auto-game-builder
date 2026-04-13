"""Thread-safe SQLite database manager with CRUD for all tables."""

import sqlite3
import threading
from typing import Optional
from database.models import (
    App, Issue, AutofixSession, Build, VersionHistory, AppTemplate, AppGroup,
)
from database.migrations import MIGRATIONS, get_migration_count


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
            "SELECT table_name, record_id, app_id, deleted_at FROM deleted_records WHERE deleted_at > ?",
            (since,),
        ).fetchall()
        return [{"table": r["table_name"], "record_id": r["record_id"], "app_id": r["app_id"], "deleted_at": r["deleted_at"]} for r in rows]

    def get_apps_since(self, since: str) -> list[App]:
        conn = self._get_conn()
        rows = conn.execute(
            "SELECT * FROM apps WHERE updated_at > ? OR created_at > ?", (since, since)
        ).fetchall()
        return [self._row_to_app(r) for r in rows]

    def get_issues_since(self, since: str) -> list[Issue]:
        conn = self._get_conn()
        rows = conn.execute(
            "SELECT * FROM issues WHERE updated_at > ? OR created_at > ?", (since, since)
        ).fetchall()
        return [self._row_to_issue(r) for r in rows]

    def get_builds_since(self, since: str) -> list[Build]:
        conn = self._get_conn()
        rows = conn.execute(
            "SELECT * FROM builds WHERE updated_at > ? OR created_at > ?", (since, since)
        ).fetchall()
        return [self._row_to_build(r) for r in rows]

    def get_sessions_since(self, since: str) -> list[AutofixSession]:
        conn = self._get_conn()
        rows = conn.execute(
            "SELECT * FROM autofix_sessions WHERE updated_at > ? OR created_at > ?", (since, since)
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

    def update_app(self, app_id: int, **kwargs):
        conn = self._get_conn()
        sets = [f"{k}=?" for k in kwargs]
        vals = [kwargs[k] for k in kwargs]
        vals.append(app_id)
        conn.execute(
            f"UPDATE apps SET {','.join(sets)}, updated_at=datetime('now') WHERE id=?",
            vals,
        )
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
            created_at=row["created_at"] or "",
            updated_at=row["updated_at"] or "",
        )

    # ── Issues ───────────────────────────────────────────────

    def create_issue(self, **kwargs) -> int:
        conn = self._get_conn()
        cols = list(kwargs.keys())
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

    def update_issue(self, issue_id: int, **kwargs):
        conn = self._get_conn()
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

    # ── Autofix Sessions ─────────────────────────────────────

    def create_session(self, **kwargs) -> int:
        conn = self._get_conn()
        cols = list(kwargs.keys())
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
        )

    # ── Version History ──────────────────────────────────────

    def create_version_entry(self, **kwargs) -> int:
        conn = self._get_conn()
        cols = list(kwargs.keys())
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

