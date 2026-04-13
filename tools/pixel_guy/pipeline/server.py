"""Standalone pipeline server — run with: python server.py"""

import os
import sys
import json
import tempfile
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response
from pydantic import BaseModel
import uvicorn

from db import PipelineDB
from engine import PipelineEngine

# ── Config ───────────────────────────────────────────────────

CONFIG_FILE = Path(__file__).parent / "config.json"
DEFAULT_CONFIG = {
    "port": 8001,
    "grok_favorites_path": str(Path.home() / "Downloads" / "grok-favorites"),
    "pipeline_base": "",
    "wrangler_path": "",
    "gemini_api_key": "",
}

def load_config() -> dict:
    if CONFIG_FILE.exists():
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            cfg = json.load(f)
        for k, v in DEFAULT_CONFIG.items():
            cfg.setdefault(k, v)
        return cfg
    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        json.dump(DEFAULT_CONFIG, f, indent=2)
    return dict(DEFAULT_CONFIG)

# ── App Setup ────────────────────────────────────────────────

config = load_config()
db_path = str(Path(__file__).parent / "pipeline.db")
db = PipelineDB(db_path)
pe = PipelineEngine(db, config)

app = FastAPI(title="Pipeline Server")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

THUMB_CACHE = Path(tempfile.gettempdir()) / "pixel_guy_pipeline_thumbs"
THUMB_CACHE.mkdir(parents=True, exist_ok=True)

# ── Request Models ───────────────────────────────────────────

class PipelineSessionCreate(BaseModel):
    source_folder: str = ""
    rating: str = "teen"

class PipelineAcceptPair(BaseModel):
    image: str = ""
    video: str = ""

class PipelineAcceptRequest(BaseModel):
    asset_ids: Optional[list[int]] = None
    pairs: Optional[list[PipelineAcceptPair]] = None
    collection: str
    rating: str = "teen"

class PipelineRejectRequest(BaseModel):
    asset_ids: Optional[list[int]] = None
    filenames: Optional[list[str]] = None

class PipelineMatchRequest(BaseModel):
    session_id: Optional[int] = None

class PipelineTagRequest(BaseModel):
    session_id: Optional[int] = None
    asset_ids: Optional[list[int]] = None
    force: bool = False

class PipelinePushRequest(BaseModel):
    collection: str
    rating: str = "teen"
    asset_ids: Optional[list[int]] = None

class PipelineMusicRequest(BaseModel):
    collection: str
    rating: str = "teen"
    prompt: str = ""

class PipelineCollectionCreate(BaseModel):
    name: str
    rating: str = "teen"

# ── Helper ───────────────────────────────────────────────────

def _asset_dict(a) -> dict:
    metadata = {}
    try:
        metadata = json.loads(a.metadata_json) if a.metadata_json and a.metadata_json != "{}" else {}
    except (json.JSONDecodeError, TypeError):
        pass
    return {
        "id": a.id, "session_id": a.session_id,
        "filename": a.filename, "file_path": a.file_path,
        "file_type": a.file_type, "rating": a.rating,
        "collection": a.collection, "status": a.status,
        "tags": a.tags, "description": a.description,
        "adult_score": a.adult_score, "racy_score": a.racy_score,
        "violence_score": a.violence_score,
        "safety_level": a.safety_level, "voyeur_risk": a.voyeur_risk,
        "context_flag": a.context_flag, "skin_exposure": a.skin_exposure,
        "pose_type": a.pose_type, "framing": a.framing,
        "clothing_coverage": a.clothing_coverage,
        "paired_asset_id": a.paired_asset_id,
        "thumbnail_path": a.thumbnail_path,
        "metadata_json": metadata,
        "created_at": a.created_at, "updated_at": a.updated_at,
    }

def _media_type(ext: str) -> str:
    return {
        ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
        ".png": "image/png", ".webp": "image/webp",
        ".mp4": "video/mp4", ".mov": "video/quicktime",
        ".webm": "video/webm", ".json": "application/json",
    }.get(ext, "application/octet-stream")

def _make_thumb(file_path: Path, cache_key: str, size: int = 200) -> Response:
    cache_file = THUMB_CACHE / f"{cache_key}.jpg"
    if cache_file.exists() and cache_file.stat().st_mtime >= file_path.stat().st_mtime:
        return FileResponse(str(cache_file), media_type="image/jpeg",
                            headers={"Cache-Control": "public, max-age=3600"})
    from PIL import Image as PILImage
    import io
    img = PILImage.open(file_path)
    img.thumbnail((size, size), PILImage.Resampling.LANCZOS)
    img = img.convert("RGB")
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=75)
    thumb_bytes = buf.getvalue()
    with open(cache_file, "wb") as f:
        f.write(thumb_bytes)
    return Response(content=thumb_bytes, media_type="image/jpeg",
                    headers={"Cache-Control": "public, max-age=3600"})

# ── Endpoints ────────────────────────────────────────────────

@app.get("/api/health")
def health():
    return {"status": "ok", "service": "pipeline"}

@app.get("/api/pipeline/pairs")
def list_pairs():
    return pe.list_pairs()

@app.get("/api/pipeline/scan")
def scan():
    return pe.scan_downloads()

@app.post("/api/pipeline/sessions")
def create_session(body: PipelineSessionCreate):
    result = pe.create_session(body.source_folder, body.rating)
    if "error" in result:
        raise HTTPException(400, result["error"])
    return result

@app.get("/api/pipeline/sessions")
def list_sessions():
    sessions = db.get_pipeline_sessions(limit=20)
    return [
        {"id": s.id, "rating": s.rating, "phase": s.phase, "message": s.message,
         "source_folder": s.source_folder, "total_assets": s.total_assets,
         "processed_assets": s.processed_assets, "tagged_count": s.tagged_count,
         "matched_count": s.matched_count, "failed_count": s.failed_count,
         "started_at": s.started_at, "completed_at": s.completed_at,
         "created_at": s.created_at}
        for s in sessions
    ]

@app.get("/api/pipeline/assets")
def list_assets(session_id: Optional[int] = None, status: Optional[str] = None,
                rating: Optional[str] = None, collection: Optional[str] = None,
                offset: int = 0, limit: int = 500):
    assets = db.get_pipeline_assets(session_id=session_id, status=status,
                                     rating=rating, collection=collection,
                                     offset=offset, limit=limit)
    return [_asset_dict(a) for a in assets]

@app.get("/api/pipeline/assets/{asset_id}")
def get_asset(asset_id: int):
    a = db.get_pipeline_asset(asset_id)
    if not a:
        raise HTTPException(404, "Asset not found")
    return _asset_dict(a)

@app.post("/api/pipeline/match")
def start_match(body: PipelineMatchRequest):
    result = pe.start_matching(body.session_id)
    if "error" in result:
        raise HTTPException(400, result["error"])
    return result

@app.post("/api/pipeline/tag")
def start_tag(body: PipelineTagRequest):
    result = pe.start_tagging(force=body.force)
    if "error" in result:
        raise HTTPException(400, result["error"])
    return result

@app.post("/api/pipeline/accept")
def accept(body: PipelineAcceptRequest):
    pairs_dicts = [p.model_dump() for p in body.pairs] if body.pairs else None
    result = pe.accept_assets(asset_ids=body.asset_ids, collection=body.collection,
                               rating=body.rating, pairs=pairs_dicts)
    if "error" in result:
        raise HTTPException(400, result["error"])
    return result

@app.post("/api/pipeline/reject")
def reject(body: PipelineRejectRequest):
    if body.filenames:
        result = pe.reject_by_filenames(body.filenames)
    elif body.asset_ids:
        result = pe.reject_assets(body.asset_ids)
    else:
        raise HTTPException(400, "Provide asset_ids or filenames")
    if "error" in result:
        raise HTTPException(400, result["error"])
    return result

@app.post("/api/pipeline/generate-music")
def generate_music(body: PipelineMusicRequest):
    result = pe.generate_music(body.collection, body.rating, body.prompt)
    if "error" in result:
        raise HTTPException(400, result["error"])
    return result

@app.post("/api/pipeline/push")
def start_push(body: PipelinePushRequest):
    result = pe.start_push(body.collection, body.rating)
    if "error" in result:
        raise HTTPException(400, result["error"])
    return result

@app.get("/api/pipeline/collections")
def list_collections(rating: Optional[str] = None):
    if rating:
        return pe.list_collections(rating)
    all_cols = []
    for r in ("kid", "teen", "adult"):
        for c in pe.list_collections(r):
            c["rating"] = r
            all_cols.append(c)
    return all_cols

@app.post("/api/pipeline/collections")
def create_collection(body: PipelineCollectionCreate):
    result = pe.create_collection(body.name, body.rating)
    if "error" in result:
        raise HTTPException(400, result["error"])
    return result

@app.get("/api/pipeline/collections/{collection}/files")
def collection_files(collection: str, rating: str = "teen", pushed: bool = False):
    return pe.list_collection_files(collection, rating, is_pushed=pushed)

@app.get("/api/pipeline/collections/{collection}/file/{filename}")
def serve_collection_file(collection: str, filename: str, rating: str = "teen", pushed: bool = False):
    if ".." in filename or ".." in collection:
        raise HTTPException(400, "Invalid path")
    cfg = pe.RATING_CONFIGS.get(rating, pe.RATING_CONFIGS["teen"])
    folder_name = cfg["folder"]
    base = pe._pipeline_base
    gen_root = base / (f"{folder_name} - Pushed" if pushed else folder_name) / "Generations"
    file_path = gen_root / collection / filename
    if not file_path.exists():
        raise HTTPException(404, "File not found")
    return FileResponse(str(file_path), media_type=_media_type(file_path.suffix.lower()),
                        headers={"Cache-Control": "public, max-age=3600"})

@app.get("/api/pipeline/collections/{collection}/file/{filename}/thumb")
def collection_file_thumb(collection: str, filename: str, rating: str = "teen",
                          pushed: bool = False, size: int = 200):
    if ".." in filename or ".." in collection:
        raise HTTPException(400, "Invalid path")
    cfg = pe.RATING_CONFIGS.get(rating, pe.RATING_CONFIGS["teen"])
    folder_name = cfg["folder"]
    base = pe._pipeline_base
    gen_root = base / (f"{folder_name} - Pushed" if pushed else folder_name) / "Generations"
    file_path = gen_root / collection / filename
    if not file_path.exists():
        raise HTTPException(404, "File not found")
    ext = file_path.suffix.lower()
    if ext not in {".jpg", ".jpeg", ".png", ".webp"}:
        raise HTTPException(400, "Not an image file")
    return _make_thumb(file_path, f"col_{rating}_{collection}_{filename}_{min(size, 400)}", min(size, 400))

@app.get("/api/pipeline/ops/{op_id}")
def op_status(op_id: str):
    status = pe.get_op_status(op_id)
    if not status:
        return {"op_id": op_id, "phase": "unknown", "message": "Operation not found"}
    return status

@app.post("/api/pipeline/ops/{op_id}/cancel")
def cancel_op(op_id: str):
    return pe.cancel_op(op_id)

@app.get("/api/pipeline/file/{filename}")
def serve_file(filename: str):
    if ".." in filename:
        raise HTTPException(400, "Invalid filename")
    file_path = Path(config.get("grok_favorites_path", "")) / filename
    if not file_path.exists():
        file_path = Path.home() / "Downloads" / "grok-favorites" / filename
    if not file_path.exists():
        raise HTTPException(404, "File not found")
    return FileResponse(str(file_path), media_type=_media_type(file_path.suffix.lower()),
                        headers={"Cache-Control": "public, max-age=3600"})

@app.get("/api/pipeline/file/{filename}/thumb")
def serve_thumbnail(filename: str, size: int = 200):
    if ".." in filename:
        raise HTTPException(400, "Invalid filename")
    file_path = Path(config.get("grok_favorites_path", "")) / filename
    if not file_path.exists():
        file_path = Path.home() / "Downloads" / "grok-favorites" / filename
    if not file_path.exists():
        raise HTTPException(404, "File not found")
    ext = file_path.suffix.lower()
    if ext not in {".jpg", ".jpeg", ".png", ".webp"}:
        raise HTTPException(400, "Not an image file")
    return _make_thumb(file_path, f"{filename}_{min(size, 400)}", min(size, 400))

@app.get("/api/pipeline/file/{filename}/metadata")
def file_metadata(filename: str):
    if ".." in filename:
        raise HTTPException(400, "Invalid filename")
    file_path = Path(config.get("grok_favorites_path", "")) / filename
    if not file_path.exists():
        file_path = Path.home() / "Downloads" / "grok-favorites" / filename
    if not file_path.exists():
        raise HTTPException(404, "File not found")
    ext = file_path.suffix.lower()
    metadata = {}
    if ext in {".jpg", ".jpeg"}:
        try:
            import piexif
            exif_dict = piexif.load(str(file_path))
            ifd = exif_dict.get("0th", {})
            raw = ifd.get(0x010E)
            if raw:
                metadata["description"] = raw.decode("utf-8", errors="ignore").strip()
            raw = ifd.get(0x9C9E)
            if raw:
                if isinstance(raw, tuple): raw = bytes(raw)
                metadata["tags"] = raw.decode("utf-16le", errors="ignore").rstrip("\x00").strip()
            raw = ifd.get(0x9C9F)
            if raw:
                if isinstance(raw, tuple): raw = bytes(raw)
                subject = raw.decode("utf-16le", errors="ignore").rstrip("\x00").strip()
                for pair in subject.split("|"):
                    if ":" in pair:
                        k, v = pair.split(":", 1)
                        metadata[k.strip()] = v.strip()
            raw = ifd.get(0x9C9B)
            if raw:
                if isinstance(raw, tuple): raw = bytes(raw)
                title = raw.decode("utf-16le", errors="ignore").rstrip("\x00").strip()
                for pair in title.split("|"):
                    if ":" in pair:
                        k, v = pair.split(":", 1)
                        metadata[k.strip()] = v.strip()
        except Exception:
            pass
    if not metadata or ext in {".mp4", ".mov", ".webm"}:
        sidecar = file_path.with_suffix(".json")
        if sidecar.exists():
            try:
                with open(sidecar, "r", encoding="utf-8") as f:
                    metadata = json.load(f)
            except Exception:
                pass
    return metadata

@app.get("/api/pipeline/assets/{asset_id}/thumbnail")
def asset_thumbnail(asset_id: int):
    path = pe.get_thumbnail_path(asset_id)
    if not path or not path.exists():
        raise HTTPException(404, "Thumbnail not found")
    return FileResponse(str(path), media_type="image/jpeg")

@app.get("/api/pipeline/assets/{asset_id}/image")
def asset_image(asset_id: int):
    a = db.get_pipeline_asset(asset_id)
    if not a or not os.path.isfile(a.file_path):
        raise HTTPException(404, "Image not found")
    return FileResponse(a.file_path, media_type=_media_type(os.path.splitext(a.file_path)[1].lower()))

@app.post("/api/pipeline/catalog/import")
def catalog_import():
    return pe.import_existing_catalog()

@app.get("/api/pipeline/catalog")
def catalog_list(rating: Optional[str] = None, collection: Optional[str] = None,
                 limit: int = Query(500, le=5000), offset: int = Query(0, ge=0)):
    assets = db.get_catalog_assets(rating=rating, collection=collection, limit=limit, offset=offset)
    total = db.count_catalog_assets(rating=rating, collection=collection)
    return {
        "total": total, "offset": offset, "limit": limit,
        "assets": [
            {"id": a.id, "filename": a.filename, "file_path": a.file_path,
             "file_type": a.file_type, "rating": a.rating,
             "collection": a.collection, "slot_number": a.slot_number,
             "tags": a.tags, "description": a.description,
             "adult_score": a.adult_score, "racy_score": a.racy_score,
             "violence_score": a.violence_score,
             "safety_level": a.safety_level, "voyeur_risk": a.voyeur_risk,
             "context_flag": a.context_flag, "skin_exposure": a.skin_exposure,
             "pose_type": a.pose_type, "framing": a.framing,
             "clothing_coverage": a.clothing_coverage,
             "is_pushed": a.is_pushed, "pushed_at": a.pushed_at,
             "created_at": a.created_at, "updated_at": a.updated_at}
            for a in assets
        ],
    }

@app.get("/api/pipeline/catalog/collections")
def catalog_collections(rating: Optional[str] = None):
    return db.get_catalog_collections(rating=rating)


if __name__ == "__main__":
    port = config.get("port", 8001)
    print(f"Pipeline server running at http://localhost:{port}")
    uvicorn.run(app, host="0.0.0.0", port=port)
