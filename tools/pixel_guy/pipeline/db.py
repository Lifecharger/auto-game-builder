"""Standalone SQLite database manager for the asset pipeline."""

import sqlite3
import threading
from typing import Optional
from models import PipelineSession, PipelineAsset, PipelineCollection, CatalogAsset

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL DEFAULT 0);

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

CREATE INDEX IF NOT EXISTS idx_pipeline_assets_session ON pipeline_assets(session_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_assets_status ON pipeline_assets(status);
CREATE INDEX IF NOT EXISTS idx_pipeline_assets_rating ON pipeline_assets(rating);
CREATE INDEX IF NOT EXISTS idx_pipeline_collections_rating ON pipeline_collections(rating);
CREATE UNIQUE INDEX IF NOT EXISTS idx_catalog_unique ON asset_catalog(rating, collection, slot_number, file_type);
CREATE INDEX IF NOT EXISTS idx_catalog_rating ON asset_catalog(rating);
CREATE INDEX IF NOT EXISTS idx_catalog_collection ON asset_catalog(rating, collection);
CREATE INDEX IF NOT EXISTS idx_catalog_tags ON asset_catalog(tags);
"""


class PipelineDB:
    def __init__(self, db_path: str):
        self.db_path = db_path
        self._local = threading.local()
        self._init_schema()

    def _get_conn(self) -> sqlite3.Connection:
        if not hasattr(self._local, "conn") or self._local.conn is None:
            self._local.conn = sqlite3.connect(self.db_path)
            self._local.conn.row_factory = sqlite3.Row
            self._local.conn.execute("PRAGMA journal_mode=WAL")
            self._local.conn.execute("PRAGMA foreign_keys=ON")
        return self._local.conn

    def _init_schema(self):
        conn = self._get_conn()
        conn.executescript(SCHEMA_SQL)
        conn.commit()

    # ── Pipeline Sessions ────────────────────────────────────

    def create_pipeline_session(self, **kwargs) -> int:
        conn = self._get_conn()
        cols = list(kwargs.keys())
        cur = conn.execute(
            f"INSERT INTO pipeline_sessions ({','.join(cols)}) VALUES ({','.join('?' for _ in cols)})",
            list(kwargs.values()),
        )
        conn.commit()
        return cur.lastrowid

    def get_pipeline_session(self, session_id: int) -> Optional[PipelineSession]:
        conn = self._get_conn()
        row = conn.execute("SELECT * FROM pipeline_sessions WHERE id=?", (session_id,)).fetchone()
        return self._row_to_pipeline_session(row) if row else None

    def get_pipeline_sessions(self, limit: int = 20) -> list[PipelineSession]:
        conn = self._get_conn()
        rows = conn.execute(
            "SELECT * FROM pipeline_sessions ORDER BY created_at DESC LIMIT ?", (limit,)
        ).fetchall()
        return [self._row_to_pipeline_session(r) for r in rows]

    def update_pipeline_session(self, session_id: int, **kwargs):
        conn = self._get_conn()
        sets = [f"{k}=?" for k in kwargs]
        vals = list(kwargs.values())
        vals.append(session_id)
        conn.execute(f"UPDATE pipeline_sessions SET {','.join(sets)} WHERE id=?", vals)
        conn.commit()

    def _row_to_pipeline_session(self, row) -> PipelineSession:
        return PipelineSession(
            id=row["id"], rating=row["rating"] or "teen", phase=row["phase"] or "idle",
            message=row["message"] or "", source_folder=row["source_folder"] or "",
            total_assets=row["total_assets"] or 0, processed_assets=row["processed_assets"] or 0,
            tagged_count=row["tagged_count"] or 0, matched_count=row["matched_count"] or 0,
            failed_count=row["failed_count"] or 0, started_at=row["started_at"] or "",
            completed_at=row["completed_at"] or "", created_at=row["created_at"] or "",
        )

    # ── Pipeline Assets ──────────────────────────────────────

    def create_pipeline_asset(self, **kwargs) -> int:
        conn = self._get_conn()
        cols = list(kwargs.keys())
        cur = conn.execute(
            f"INSERT INTO pipeline_assets ({','.join(cols)}) VALUES ({','.join('?' for _ in cols)})",
            list(kwargs.values()),
        )
        conn.commit()
        return cur.lastrowid

    def get_pipeline_asset(self, asset_id: int) -> Optional[PipelineAsset]:
        conn = self._get_conn()
        row = conn.execute("SELECT * FROM pipeline_assets WHERE id=?", (asset_id,)).fetchone()
        return self._row_to_pipeline_asset(row) if row else None

    def get_pipeline_assets(self, session_id=None, status=None, rating=None, collection=None, offset=0, limit=500) -> list[PipelineAsset]:
        conn = self._get_conn()
        query = "SELECT * FROM pipeline_assets WHERE 1=1"
        params: list = []
        if session_id is not None:
            query += " AND session_id=?"; params.append(session_id)
        if status:
            query += " AND status=?"; params.append(status)
        if rating:
            query += " AND rating=?"; params.append(rating)
        if collection:
            query += " AND collection=?"; params.append(collection)
        query += " ORDER BY created_at DESC LIMIT ? OFFSET ?"
        params.extend([limit, offset])
        return [self._row_to_pipeline_asset(r) for r in conn.execute(query, params).fetchall()]

    def update_pipeline_asset(self, asset_id: int, **kwargs):
        conn = self._get_conn()
        sets = [f"{k}=?" for k in kwargs]
        vals = list(kwargs.values())
        vals.append(asset_id)
        conn.execute(f"UPDATE pipeline_assets SET {','.join(sets)}, updated_at=datetime('now') WHERE id=?", vals)
        conn.commit()

    def delete_pipeline_asset(self, asset_id: int):
        conn = self._get_conn()
        conn.execute("DELETE FROM pipeline_assets WHERE id=?", (asset_id,))
        conn.commit()

    def count_pipeline_assets(self, session_id=None, status=None) -> int:
        conn = self._get_conn()
        query = "SELECT COUNT(*) FROM pipeline_assets WHERE 1=1"
        params: list = []
        if session_id is not None:
            query += " AND session_id=?"; params.append(session_id)
        if status:
            query += " AND status=?"; params.append(status)
        return conn.execute(query, params).fetchone()[0]

    def _row_to_pipeline_asset(self, row) -> PipelineAsset:
        return PipelineAsset(
            id=row["id"], session_id=row["session_id"] or 0,
            filename=row["filename"] or "", file_path=row["file_path"] or "",
            file_type=row["file_type"] or "image", rating=row["rating"] or "",
            collection=row["collection"] or "", status=row["status"] or "pending",
            tags=row["tags"] or "", description=row["description"] or "",
            adult_score=row["adult_score"] or 0, racy_score=row["racy_score"] or 0,
            violence_score=row["violence_score"] or 0, safety_level=row["safety_level"] or "",
            voyeur_risk=row["voyeur_risk"] or "", context_flag=row["context_flag"] or "",
            skin_exposure=row["skin_exposure"] or "", pose_type=row["pose_type"] or "",
            framing=row["framing"] or "", clothing_coverage=row["clothing_coverage"] or "",
            paired_asset_id=row["paired_asset_id"] or 0, thumbnail_path=row["thumbnail_path"] or "",
            metadata_json=row["metadata_json"] or "{}", created_at=row["created_at"] or "",
            updated_at=row["updated_at"] or "",
        )

    # ── Pipeline Collections ─────────────────────────────────

    def create_pipeline_collection(self, **kwargs) -> int:
        conn = self._get_conn()
        cols = list(kwargs.keys())
        cur = conn.execute(
            f"INSERT INTO pipeline_collections ({','.join(cols)}) VALUES ({','.join('?' for _ in cols)})",
            list(kwargs.values()),
        )
        conn.commit()
        return cur.lastrowid

    def get_pipeline_collection(self, collection_id: int) -> Optional[PipelineCollection]:
        conn = self._get_conn()
        row = conn.execute("SELECT * FROM pipeline_collections WHERE id=?", (collection_id,)).fetchone()
        return self._row_to_pipeline_collection(row) if row else None

    def get_pipeline_collections(self, rating: Optional[str] = None) -> list[PipelineCollection]:
        conn = self._get_conn()
        if rating:
            rows = conn.execute("SELECT * FROM pipeline_collections WHERE rating=? ORDER BY name", (rating,)).fetchall()
        else:
            rows = conn.execute("SELECT * FROM pipeline_collections ORDER BY name").fetchall()
        return [self._row_to_pipeline_collection(r) for r in rows]

    def update_pipeline_collection(self, collection_id: int, **kwargs):
        conn = self._get_conn()
        sets = [f"{k}=?" for k in kwargs]
        vals = list(kwargs.values())
        vals.append(collection_id)
        conn.execute(f"UPDATE pipeline_collections SET {','.join(sets)} WHERE id=?", vals)
        conn.commit()

    def _row_to_pipeline_collection(self, row) -> PipelineCollection:
        return PipelineCollection(
            id=row["id"], name=row["name"] or "", rating=row["rating"] or "teen",
            folder_path=row["folder_path"] or "", asset_count=row["asset_count"] or 0,
            max_items=row["max_items"] or 0, is_pushed=bool(row["is_pushed"]),
            pushed_at=row["pushed_at"] or "", created_at=row["created_at"] or "",
        )

    # ── Asset Catalog ─────────────────────────────────────────

    def create_catalog_asset(self, **kwargs) -> int:
        conn = self._get_conn()
        cols = list(kwargs.keys())
        cur = conn.execute(
            f"INSERT INTO asset_catalog ({','.join(cols)}) VALUES ({','.join('?' for _ in cols)})",
            list(kwargs.values()),
        )
        conn.commit()
        return cur.lastrowid

    def get_catalog_asset(self, asset_id: int) -> Optional[CatalogAsset]:
        conn = self._get_conn()
        row = conn.execute("SELECT * FROM asset_catalog WHERE id=?", (asset_id,)).fetchone()
        return self._row_to_catalog_asset(row) if row else None

    def get_catalog_assets(self, rating=None, collection=None, offset=0, limit=500) -> list[CatalogAsset]:
        conn = self._get_conn()
        query = "SELECT * FROM asset_catalog WHERE 1=1"
        params: list = []
        if rating:
            query += " AND rating=?"; params.append(rating)
        if collection:
            query += " AND collection=?"; params.append(collection)
        query += " ORDER BY rating, collection, slot_number LIMIT ? OFFSET ?"
        params.extend([limit, offset])
        return [self._row_to_catalog_asset(r) for r in conn.execute(query, params).fetchall()]

    def update_catalog_asset(self, asset_id: int, **kwargs):
        conn = self._get_conn()
        sets = [f"{k}=?" for k in kwargs]
        vals = list(kwargs.values())
        vals.append(asset_id)
        conn.execute(f"UPDATE asset_catalog SET {','.join(sets)}, updated_at=datetime('now') WHERE id=?", vals)
        conn.commit()

    def delete_catalog_asset(self, asset_id: int):
        conn = self._get_conn()
        conn.execute("DELETE FROM asset_catalog WHERE id=?", (asset_id,))
        conn.commit()

    def count_catalog_assets(self, rating=None, collection=None) -> int:
        conn = self._get_conn()
        query = "SELECT COUNT(*) FROM asset_catalog WHERE 1=1"
        params: list = []
        if rating:
            query += " AND rating=?"; params.append(rating)
        if collection:
            query += " AND collection=?"; params.append(collection)
        return conn.execute(query, params).fetchone()[0]

    def get_catalog_collections(self, rating: Optional[str] = None) -> list[dict]:
        conn = self._get_conn()
        query = (
            "SELECT rating, collection, COUNT(*) as count, "
            "SUM(CASE WHEN file_type='image' THEN 1 ELSE 0 END) as images, "
            "SUM(CASE WHEN file_type='video' THEN 1 ELSE 0 END) as videos "
            "FROM asset_catalog WHERE 1=1"
        )
        params: list = []
        if rating:
            query += " AND rating=?"; params.append(rating)
        query += " GROUP BY rating, collection ORDER BY rating, collection"
        rows = conn.execute(query, params).fetchall()
        return [{"rating": r["rating"], "collection": r["collection"], "count": r["count"],
                 "images": r["images"], "videos": r["videos"]} for r in rows]

    def get_next_slot(self, rating: str, collection: str) -> int:
        conn = self._get_conn()
        row = conn.execute(
            "SELECT MAX(slot_number) FROM asset_catalog WHERE rating=? AND collection=?",
            (rating, collection),
        ).fetchone()
        return (row[0] if row[0] is not None else 0) + 1

    def _row_to_catalog_asset(self, row) -> CatalogAsset:
        return CatalogAsset(
            id=row["id"], filename=row["filename"] or "", file_path=row["file_path"] or "",
            file_type=row["file_type"] or "image", rating=row["rating"] or "teen",
            collection=row["collection"] or "", slot_number=row["slot_number"] or 0,
            tags=row["tags"] or "", description=row["description"] or "",
            adult_score=row["adult_score"] or 0, racy_score=row["racy_score"] or 0,
            violence_score=row["violence_score"] or 0, safety_level=row["safety_level"] or "",
            voyeur_risk=row["voyeur_risk"] or "", context_flag=row["context_flag"] or "",
            skin_exposure=row["skin_exposure"] or "", pose_type=row["pose_type"] or "",
            framing=row["framing"] or "", clothing_coverage=row["clothing_coverage"] or "",
            metadata_json=row["metadata_json"] or "{}", is_pushed=bool(row["is_pushed"]),
            pushed_at=row["pushed_at"], created_at=row["created_at"] or "",
            updated_at=row["updated_at"] or "",
        )
