"""Pipeline data models."""

from dataclasses import dataclass
from typing import Optional


@dataclass
class PipelineSession:
    id: int = 0
    rating: str = "teen"
    phase: str = "idle"
    message: str = ""
    source_folder: str = ""
    total_assets: int = 0
    processed_assets: int = 0
    tagged_count: int = 0
    matched_count: int = 0
    failed_count: int = 0
    started_at: str = ""
    completed_at: str = ""
    created_at: str = ""


@dataclass
class PipelineAsset:
    id: int = 0
    session_id: int = 0
    filename: str = ""
    file_path: str = ""
    file_type: str = "image"
    rating: str = ""
    collection: str = ""
    status: str = "pending"
    tags: str = ""
    description: str = ""
    adult_score: int = 0
    racy_score: int = 0
    violence_score: int = 0
    safety_level: str = ""
    voyeur_risk: str = ""
    context_flag: str = ""
    skin_exposure: str = ""
    pose_type: str = ""
    framing: str = ""
    clothing_coverage: str = ""
    paired_asset_id: int = 0
    thumbnail_path: str = ""
    metadata_json: str = "{}"
    created_at: str = ""
    updated_at: str = ""


@dataclass
class PipelineCollection:
    id: int = 0
    name: str = ""
    rating: str = "teen"
    folder_path: str = ""
    asset_count: int = 0
    max_items: int = 0
    is_pushed: bool = False
    pushed_at: str = ""
    created_at: str = ""


@dataclass
class CatalogAsset:
    id: int = 0
    filename: str = ""
    file_path: str = ""
    file_type: str = "image"
    rating: str = "teen"
    collection: str = ""
    slot_number: int = 0
    tags: str = ""
    description: str = ""
    adult_score: int = 0
    racy_score: int = 0
    violence_score: int = 0
    safety_level: str = ""
    voyeur_risk: str = ""
    context_flag: str = ""
    skin_exposure: str = ""
    pose_type: str = ""
    framing: str = ""
    clothing_coverage: str = ""
    metadata_json: str = "{}"
    is_pushed: bool = False
    pushed_at: Optional[str] = None
    created_at: str = ""
    updated_at: str = ""
