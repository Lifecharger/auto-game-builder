"""Database schema migrations."""

MIGRATIONS = [
    # Version 1: Initial schema
    """
    CREATE TABLE IF NOT EXISTS schema_version (
        version INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS apps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        slug TEXT NOT NULL UNIQUE,
        project_path TEXT NOT NULL,
        app_type TEXT NOT NULL DEFAULT 'flutter',
        current_version TEXT DEFAULT '',
        package_name TEXT DEFAULT '',
        build_command TEXT DEFAULT '',
        build_output_path TEXT DEFAULT '',
        claude_md_path TEXT DEFAULT '',
        fix_strategy TEXT DEFAULT 'claude',
        status TEXT DEFAULT 'idle',
        last_build_at TEXT,
        last_fix_at TEXT,
        notes TEXT DEFAULT '',
        tech_stack TEXT DEFAULT '{}',
        mcp_config_path TEXT DEFAULT '',
        automation_script_path TEXT DEFAULT '',
        is_archived INTEGER DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS issues (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        app_id INTEGER NOT NULL REFERENCES apps(id),
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT 'bug',
        priority INTEGER DEFAULT 3,
        status TEXT DEFAULT 'open',
        source TEXT DEFAULT 'manual',
        raw_data TEXT DEFAULT '',
        fix_prompt TEXT DEFAULT '',
        fix_result TEXT DEFAULT '',
        fix_session_id INTEGER,
        assigned_ai TEXT DEFAULT '',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS autofix_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        app_id INTEGER NOT NULL REFERENCES apps(id),
        issue_id INTEGER,
        ai_tool TEXT NOT NULL DEFAULT 'claude',
        prompt_used TEXT NOT NULL DEFAULT '',
        status TEXT DEFAULT 'pending',
        exit_code INTEGER,
        log_file_path TEXT DEFAULT '',
        duration_seconds INTEGER,
        error_message TEXT DEFAULT '',
        files_changed TEXT DEFAULT '[]',
        started_at TEXT,
        completed_at TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS builds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        app_id INTEGER NOT NULL REFERENCES apps(id),
        build_type TEXT NOT NULL DEFAULT 'appbundle',
        version TEXT DEFAULT '',
        status TEXT DEFAULT 'pending',
        output_path TEXT DEFAULT '',
        log_output TEXT DEFAULT '',
        duration_seconds INTEGER,
        started_at TEXT,
        completed_at TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS version_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        app_id INTEGER NOT NULL REFERENCES apps(id),
        old_version TEXT NOT NULL,
        new_version TEXT NOT NULL,
        bump_type TEXT DEFAULT '',
        changed_by TEXT DEFAULT 'manual',
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS app_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        app_type TEXT NOT NULL DEFAULT 'flutter',
        description TEXT DEFAULT '',
        default_build_command TEXT DEFAULT '',
        default_build_output TEXT DEFAULT '',
        default_prompt_template TEXT DEFAULT '',
        tech_stack TEXT DEFAULT '{}',
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE INDEX IF NOT EXISTS idx_issues_app_id ON issues(app_id);
    CREATE INDEX IF NOT EXISTS idx_issues_status ON issues(status);
    CREATE INDEX IF NOT EXISTS idx_issues_category ON issues(category);
    CREATE INDEX IF NOT EXISTS idx_autofix_sessions_app_id ON autofix_sessions(app_id);
    CREATE INDEX IF NOT EXISTS idx_autofix_sessions_status ON autofix_sessions(status);
    CREATE INDEX IF NOT EXISTS idx_builds_app_id ON builds(app_id);
    CREATE INDEX IF NOT EXISTS idx_builds_status ON builds(status);
    """,
    # Version 2: App groups + icon paths
    """
    ALTER TABLE apps ADD COLUMN group_name TEXT DEFAULT '';
    ALTER TABLE apps ADD COLUMN icon_path TEXT DEFAULT '';

    CREATE TABLE IF NOT EXISTS app_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT DEFAULT '',
        color TEXT DEFAULT '#3498db',
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
    """,
    # Version 3: Publish status
    """
    ALTER TABLE apps ADD COLUMN publish_status TEXT DEFAULT 'development';
    """,
    # Version 4: Build targets per app (JSON)
    """
    ALTER TABLE apps ADD COLUMN build_targets TEXT DEFAULT '{}';
    """,
    # Version 5: App link URLs
    """
    ALTER TABLE apps ADD COLUMN github_url TEXT DEFAULT '';
    ALTER TABLE apps ADD COLUMN play_store_url TEXT DEFAULT '';
    ALTER TABLE apps ADD COLUMN website_url TEXT DEFAULT '';
    ALTER TABLE apps ADD COLUMN console_url TEXT DEFAULT '';
    """,
    # Version 6: Asset Pipeline tables
    """
    CREATE TABLE IF NOT EXISTS pipeline_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rating TEXT NOT NULL DEFAULT 'teen',
        phase TEXT NOT NULL DEFAULT 'idle',
        message TEXT DEFAULT '',
        source_folder TEXT DEFAULT '',
        total_assets INTEGER DEFAULT 0,
        processed_assets INTEGER DEFAULT 0,
        tagged_count INTEGER DEFAULT 0,
        matched_count INTEGER DEFAULT 0,
        failed_count INTEGER DEFAULT 0,
        started_at TEXT,
        completed_at TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS pipeline_assets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER REFERENCES pipeline_sessions(id),
        filename TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_type TEXT NOT NULL DEFAULT 'image',
        rating TEXT DEFAULT '',
        collection TEXT DEFAULT '',
        status TEXT NOT NULL DEFAULT 'pending',
        tags TEXT DEFAULT '',
        description TEXT DEFAULT '',
        adult_score INTEGER DEFAULT 0,
        racy_score INTEGER DEFAULT 0,
        violence_score INTEGER DEFAULT 0,
        safety_level TEXT DEFAULT '',
        voyeur_risk TEXT DEFAULT '',
        context_flag TEXT DEFAULT '',
        skin_exposure TEXT DEFAULT '',
        pose_type TEXT DEFAULT '',
        framing TEXT DEFAULT '',
        clothing_coverage TEXT DEFAULT '',
        paired_asset_id INTEGER,
        thumbnail_path TEXT DEFAULT '',
        metadata_json TEXT DEFAULT '{}',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS pipeline_collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        rating TEXT NOT NULL DEFAULT 'teen',
        folder_path TEXT DEFAULT '',
        asset_count INTEGER DEFAULT 0,
        max_items INTEGER,
        is_pushed INTEGER DEFAULT 0,
        pushed_at TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE INDEX IF NOT EXISTS idx_pipeline_assets_session ON pipeline_assets(session_id);
    CREATE INDEX IF NOT EXISTS idx_pipeline_assets_status ON pipeline_assets(status);
    CREATE INDEX IF NOT EXISTS idx_pipeline_assets_rating ON pipeline_assets(rating);
    CREATE INDEX IF NOT EXISTS idx_pipeline_collections_rating ON pipeline_collections(rating);
    """,
    # Version 7: Asset catalog table
    """
    CREATE TABLE IF NOT EXISTS asset_catalog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filename TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_type TEXT NOT NULL DEFAULT 'image',
        rating TEXT NOT NULL DEFAULT 'teen',
        collection TEXT NOT NULL DEFAULT '',
        slot_number INTEGER NOT NULL DEFAULT 0,
        tags TEXT DEFAULT '',
        description TEXT DEFAULT '',
        adult_score INTEGER DEFAULT 0,
        racy_score INTEGER DEFAULT 0,
        violence_score INTEGER DEFAULT 0,
        safety_level TEXT DEFAULT '',
        voyeur_risk TEXT DEFAULT '',
        context_flag TEXT DEFAULT '',
        skin_exposure TEXT DEFAULT '',
        pose_type TEXT DEFAULT '',
        framing TEXT DEFAULT '',
        clothing_coverage TEXT DEFAULT '',
        metadata_json TEXT DEFAULT '{}',
        is_pushed INTEGER DEFAULT 0,
        pushed_at TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE UNIQUE INDEX IF NOT EXISTS idx_catalog_unique ON asset_catalog(rating, collection, slot_number, file_type);
    CREATE INDEX IF NOT EXISTS idx_catalog_rating ON asset_catalog(rating);
    CREATE INDEX IF NOT EXISTS idx_catalog_collection ON asset_catalog(rating, collection);
    CREATE INDEX IF NOT EXISTS idx_catalog_tags ON asset_catalog(tags);
    """,
    # Version 8: Add updated_at to builds and autofix_sessions for delta sync
    """
    ALTER TABLE builds ADD COLUMN updated_at TEXT NOT NULL DEFAULT '';
    ALTER TABLE autofix_sessions ADD COLUMN updated_at TEXT NOT NULL DEFAULT '';
    UPDATE builds SET updated_at = created_at WHERE updated_at = '';
    UPDATE autofix_sessions SET updated_at = created_at WHERE updated_at = '';
    """,
    # Version 9: Deletion tracking for delta sync
    """
    CREATE TABLE IF NOT EXISTS deleted_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        app_id INTEGER,
        deleted_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE INDEX IF NOT EXISTS idx_deleted_records_time ON deleted_records(deleted_at);
    """,
]


def get_migration_count() -> int:
    return len(MIGRATIONS)
