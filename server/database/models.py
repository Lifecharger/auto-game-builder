"""Dataclass models mirroring database tables."""

from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional
import json


@dataclass
class App:
    id: int = 0
    name: str = ""
    slug: str = ""
    project_path: str = ""
    app_type: str = "flutter"  # flutter|godot|react_native|python|custom
    current_version: str = ""
    package_name: str = ""
    build_command: str = ""
    build_output_path: str = ""
    claude_md_path: str = ""
    fix_strategy: str = "claude"  # claude|gemini|codex
    status: str = "idle"  # idle|building|fixing|error
    publish_status: str = "development"  # development|internal_test|external_test|experimental|published
    last_build_at: Optional[str] = None
    last_fix_at: Optional[str] = None
    notes: str = ""
    tech_stack: str = "{}"  # JSON
    mcp_config_path: str = ""
    automation_script_path: str = ""
    is_archived: bool = False
    build_targets: str = "{}"  # JSON: {"aab": true, "apk": false, ...}
    group_name: str = ""
    icon_path: str = ""
    github_url: str = ""
    play_store_url: str = ""
    website_url: str = ""
    console_url: str = ""
    created_at: str = ""
    updated_at: str = ""

    def build_targets_dict(self) -> dict[str, bool]:
        try:
            return json.loads(self.build_targets) if self.build_targets else {}
        except json.JSONDecodeError:
            return {}

    def tech_stack_dict(self) -> dict:
        try:
            return json.loads(self.tech_stack) if self.tech_stack else {}
        except json.JSONDecodeError:
            return {}


@dataclass
class Issue:
    id: int = 0
    app_id: int = 0
    title: str = ""
    description: str = ""
    category: str = "bug"  # bug|anr|crash|improvement|feature|idea
    priority: int = 3  # 1=critical, 5=wishlist
    status: str = "open"  # open|queued|fixing|fixed|verified|rejected|wontfix
    source: str = "manual"  # manual|anr_report|play_console|auto_detected
    raw_data: str = ""  # JSON
    fix_prompt: str = ""  # override
    fix_result: str = ""
    fix_session_id: Optional[int] = None
    assigned_ai: str = ""  # claude|gemini|codex or empty for app default
    created_at: str = ""
    updated_at: str = ""


@dataclass
class AutofixSession:
    id: int = 0
    app_id: int = 0
    issue_id: Optional[int] = None
    ai_tool: str = "claude"
    prompt_used: str = ""
    status: str = "pending"  # pending|running|completed|failed|cancelled
    exit_code: Optional[int] = None
    log_file_path: str = ""
    duration_seconds: Optional[int] = None
    error_message: str = ""
    files_changed: str = "[]"  # JSON array
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    created_at: str = ""

    def files_changed_list(self) -> list[str]:
        try:
            return json.loads(self.files_changed) if self.files_changed else []
        except json.JSONDecodeError:
            return []


@dataclass
class Build:
    id: int = 0
    app_id: int = 0
    build_type: str = "appbundle"  # appbundle|apk|godot_export|debug
    version: str = ""
    status: str = "pending"  # pending|running|success|failed
    output_path: str = ""
    log_output: str = ""
    duration_seconds: Optional[int] = None
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    created_at: str = ""


@dataclass
class VersionHistory:
    id: int = 0
    app_id: int = 0
    old_version: str = ""
    new_version: str = ""
    bump_type: str = ""  # patch|minor|major|build_number
    changed_by: str = "manual"  # manual|autofix|build
    created_at: str = ""


@dataclass
class AppGroup:
    id: int = 0
    name: str = ""
    description: str = ""
    color: str = "#3498db"
    created_at: str = ""


@dataclass
class AppTemplate:
    id: int = 0
    name: str = ""
    app_type: str = "flutter"
    description: str = ""
    default_build_command: str = ""
    default_build_output: str = ""
    default_prompt_template: str = ""
    tech_stack: str = "{}"  # JSON
    created_at: str = ""


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
