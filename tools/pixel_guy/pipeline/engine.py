"""Asset pipeline engine: scan, match, tag, collect, push to R2."""

import os
import re
import io
import json
import shutil
import hashlib
import subprocess
import threading
import time
import uuid
from pathlib import Path
from datetime import datetime
from typing import Optional
from concurrent.futures import ThreadPoolExecutor

import cv2
import numpy as np
from PIL import Image
import piexif

from db import PipelineDB


def _find_agb_mcp_servers_config() -> Optional[Path]:
    """Walk up from this file looking for Auto Game Builder's server/config/mcp_servers.json.

    When this tool lives inside Auto Game Builder/tools/pixel_guy/pipeline/,
    the config is 3 levels up. Fall back to walking the tree for robustness.
    """
    here = Path(os.path.abspath(__file__)).parent
    for parent in [here, *here.parents]:
        candidate = parent / "server" / "config" / "mcp_servers.json"
        if candidate.is_file():
            return candidate
    return None


class PipelineEngine:
    """Headless engine for asset generation pipeline operations."""

    RATING_CONFIGS = {
        "kid": {"bucket": "kidfriendlybucket", "folder": "Kid Jigsaw"},
        "teen": {"bucket": "hotjigsaw", "folder": "Hot Jigsaw"},
        "adult": {"bucket": "steamlevel", "folder": "Adult Jigsaw"},
    }

    IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp"}
    VIDEO_EXTS = {".mp4", ".mov", ".webm"}

    def __init__(self, db: PipelineDB, settings: dict):
        self.db = db
        self.settings = settings

        # Resolve paths from settings instead of hardcoding
        self._pipeline_base = Path(settings.get("pipeline_base", ""))
        if not self._pipeline_base or not self._pipeline_base.is_dir():
            self._pipeline_base = Path(settings.get("projects_root", "")) / "Asset Generation Pipeline"

        self._downloads_path = Path(settings.get("downloads_path", ""))
        if not self._downloads_path or not self._downloads_path.is_dir():
            self._downloads_path = Path.home() / "Downloads"

        self._grok_favorites = Path(settings.get("grok_favorites_path", ""))
        if not self._grok_favorites or not self._grok_favorites.is_dir():
            self._grok_favorites = self._downloads_path / "grok-favorites"

        # Thumbnail cache inside our own server directory
        server_dir = Path(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        self._thumbnail_cache = Path(settings.get("thumbnail_cache_path", ""))
        if not self._thumbnail_cache:
            self._thumbnail_cache = server_dir / "tmp" / "pipeline_thumbs"

        # Wrangler command from settings
        self._wrangler_cmd = settings.get("wrangler_path", "") or shutil.which("wrangler") or "wrangler"

        # Counter file for collection numbering
        config_dir = Path(os.path.dirname(os.path.abspath(__file__))).parent / "config"
        self._counter_file = Path(settings.get("pipeline_counters_path", ""))
        if not self._counter_file:
            self._counter_file = config_dir / "pipeline_counters.json"

        self._active_ops: dict[str, dict] = {}
        self._cancelled_ops: set[str] = set()
        self._gemini_api_key = settings.get("gemini_api_key", "")
        if not self._gemini_api_key:
            self._gemini_api_key = self._load_gemini_key()
        self._thumbnail_cache.mkdir(parents=True, exist_ok=True)

    # ── Scanning ─────────────────────────────────────────────

    def scan_downloads(self) -> dict:
        """Scan grok-favorites folder, auto-import new files as assets.
        Returns {folder, new_assets, total_assets, images, videos}"""
        folder = str(self._grok_favorites)
        if not self._grok_favorites.is_dir():
            return {"folder": folder, "new_assets": 0, "total_assets": 0,
                    "images": 0, "videos": 0}

        # Get existing asset file paths from DB
        existing = self.db.get_pipeline_assets(limit=100000)
        existing_paths = {a.file_path for a in existing}

        new_count = 0
        img_count = 0
        vid_count = 0

        for f in self._grok_favorites.iterdir():
            if not f.is_file():
                continue
            if f.suffix.lower() not in (self.IMAGE_EXTS | self.VIDEO_EXTS):
                continue

            file_path = str(f)
            if file_path in existing_paths:
                continue  # Already in DB

            file_type = "video" if f.suffix.lower() in self.VIDEO_EXTS else "image"
            self.db.create_pipeline_asset(
                filename=f.name,
                file_path=file_path,
                file_type=file_type,
                rating="",
                status="pending",
            )
            new_count += 1
            if file_type == "image":
                img_count += 1
            else:
                vid_count += 1

        total = len(existing) + new_count
        return {
            "folder": folder,
            "new_assets": new_count,
            "total_assets": total,
            "images": img_count,
            "videos": vid_count,
        }

    # ── Session Management ───────────────────────────────────

    def create_session(self, source_folder: str, rating: str = "teen") -> dict:
        """Import scanned files into DB as a new session.
        Creates pipeline_asset records for each file.
        Returns {ok, session_id, asset_count}"""
        source = Path(source_folder)
        if not source.is_dir():
            return {"error": f"Source folder does not exist: {source_folder}"}

        # Collect all media files
        files: list[Path] = []
        for f in source.iterdir():
            if f.is_file() and f.suffix.lower() in (self.IMAGE_EXTS | self.VIDEO_EXTS):
                files.append(f)

        if not files:
            return {"error": "No image or video files found in source folder"}

        session_id = self.db.create_pipeline_session(
            rating=rating,
            phase="created",
            message=f"Imported {len(files)} files",
            source_folder=source_folder,
            total_assets=len(files),
            started_at=datetime.now().isoformat(),
        )

        asset_count = 0
        for f in files:
            file_type = "video" if f.suffix.lower() in self.VIDEO_EXTS else "image"
            self.db.create_pipeline_asset(
                session_id=session_id,
                filename=f.name,
                file_path=str(f),
                file_type=file_type,
                rating=rating,
                status="pending",
            )
            asset_count += 1

        return {"ok": True, "session_id": session_id, "asset_count": asset_count}

    # ── Matching ─────────────────────────────────────────────

    def start_matching(self, session_id: int = None) -> dict:
        """Start background video-image matching. Returns {ok, op_id}.
        If session_id is None, matches all unmatched assets."""
        op_id = self._new_op("matching")
        thread = threading.Thread(
            target=self._match_worker,
            args=(session_id, op_id),
            daemon=True,
        )
        thread.start()
        return {"ok": True, "op_id": op_id}

    def _match_worker(self, session_id: Optional[int], op_id: str):
        """Scan grok-favorites folder directly, match videos to images
        via first-frame histogram comparison, physically rename files."""
        try:
            folder = self._grok_favorites
            if not folder.is_dir():
                self._update_op(op_id, phase="failed", message="grok-favorites folder not found")
                return

            self._update_op(op_id, phase="loading", message="Scanning folder...")

            # Scan folder directly — no DB dependency
            image_files = sorted([f for f in folder.iterdir()
                                   if f.is_file() and f.suffix.lower() in self.IMAGE_EXTS])
            video_files = sorted([f for f in folder.iterdir()
                                   if f.is_file() and f.suffix.lower() in self.VIDEO_EXTS])

            if not video_files or not image_files:
                self._update_op(op_id, phase="done", message="No videos or images to match")
                return

            total = len(video_files)
            matched = 0
            # img_path -> [(vid_path, score)]
            img_to_videos: dict[Path, list[tuple[Path, float]]] = {}

            self._update_op(op_id, phase="matching", total=total, processed=0,
                            message=f"Matching {total} videos against {len(image_files)} images...")

            # ── Helper: resize to thumbnail for SSIM comparison ──
            THUMB_SIZE = (128, 128)

            def to_thumb(img):
                """Resize to fixed thumbnail and convert to grayscale."""
                gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
                return cv2.resize(gray, THUMB_SIZE, interpolation=cv2.INTER_AREA)

            def ssim_score(thumb_a, thumb_b):
                """Structural similarity between two grayscale thumbnails."""
                from skimage.metrics import structural_similarity
                return structural_similarity(thumb_a, thumb_b)

            def extract_first_frame(vid_path):
                """Extract the very first frame — it's the source image."""
                cap = cv2.VideoCapture(str(vid_path))
                ret, frame = cap.read()
                cap.release()
                return frame if ret else None

            # Precompute image thumbnails
            image_thumbs: dict[Path, np.ndarray] = {}
            for img_path in image_files:
                if op_id in self._cancelled_ops:
                    self._update_op(op_id, phase="cancelled", message="Cancelled by user")
                    return
                img = cv2.imread(str(img_path))
                if img is not None:
                    image_thumbs[img_path] = to_thumb(img)

            # Compute ALL video thumbnails
            vid_thumbs: dict[Path, np.ndarray] = {}
            for idx, vid_path in enumerate(video_files):
                if op_id in self._cancelled_ops:
                    self._update_op(op_id, phase="cancelled", message="Cancelled by user")
                    return
                self._update_op(op_id, processed=idx,
                                message=f"Reading video {idx + 1}/{total}: {vid_path.name}")
                frame = extract_first_frame(vid_path)
                if frame is not None:
                    vid_thumbs[vid_path] = to_thumb(frame)

            # Compute ALL pairwise scores
            self._update_op(op_id, phase="matching",
                            message=f"Computing {len(vid_thumbs)}x{len(image_thumbs)} similarity matrix...")
            all_scores: list[tuple[float, Path, Path]] = []  # (score, vid, img)
            for vid_path, vt in vid_thumbs.items():
                for img_path, it in image_thumbs.items():
                    score = ssim_score(vt, it)
                    if score > 0.25:
                        all_scores.append((score, vid_path, img_path))

            # Sort by score descending — assign highest scores first (global optimal greedy)
            all_scores.sort(reverse=True)

            assigned_vids: set[Path] = set()   # videos that have a primary assignment
            assigned_imgs: set[Path] = set()   # images that have a primary video

            for score, vid_path, img_path in all_scores:
                if vid_path in assigned_vids:
                    continue  # This video already has a primary pair
                if img_path not in assigned_imgs:
                    # Primary pair — best available match for both
                    assigned_imgs.add(img_path)
                    assigned_vids.add(vid_path)
                    if img_path not in img_to_videos:
                        img_to_videos[img_path] = []
                    img_to_videos[img_path].insert(0, (vid_path, score))
                    matched += 1
                else:
                    # Image already has a primary — this video is an extra
                    if img_path not in img_to_videos:
                        img_to_videos[img_path] = []
                    img_to_videos[img_path].append((vid_path, score))
                    assigned_vids.add(vid_path)
                    matched += 1

            # Determine primary pairs, extras
            paired_imgs: set[Path] = set(img_to_videos.keys())
            paired_vids: set[Path] = set()
            extra_vids: dict[Path, Path] = {}  # extra_vid -> matched_img

            for img_path, vids in img_to_videos.items():
                if vids:
                    paired_vids.add(vids[0][0])  # Primary = first (highest score)
                    for extra_vid, _ in vids[1:]:
                        extra_vids[extra_vid] = img_path

            # ── Second pass: reassign extras to solo images ──
            solo_imgs = {p: t for p, t in image_thumbs.items() if p not in paired_imgs}
            if extra_vids and solo_imgs:
                self._update_op(op_id, phase="reassigning",
                                message=f"Checking {len(extra_vids)} extras against {len(solo_imgs)} solo images...")
                reassigned = 0
                for extra_vid in list(extra_vids.keys()):
                    frame = extract_first_frame(extra_vid)
                    if frame is None:
                        continue
                    vid_thumb = to_thumb(frame)

                    best_score = -1.0
                    best_solo = None
                    for solo_path, solo_thumb in solo_imgs.items():
                        score = ssim_score(vid_thumb, solo_thumb)
                        if score > best_score:
                            best_score = score
                            best_solo = solo_path

                    if best_solo is not None and best_score > 0.25:
                        # Remove from old image's extras
                        old_img = extra_vids[extra_vid]
                        img_to_videos[old_img] = [(v, s) for v, s in img_to_videos[old_img] if v != extra_vid]

                        # Add as primary for solo image
                        img_to_videos[best_solo] = [(extra_vid, best_score)]
                        paired_imgs.add(best_solo)
                        paired_vids.add(extra_vid)
                        del extra_vids[extra_vid]
                        del solo_imgs[best_solo]
                        reassigned += 1

                if reassigned:
                    self._update_op(op_id, phase="reassigning",
                                    message=f"Reassigned {reassigned} extras to solo images")

            # ── Physical rename + convert images to jpg ──
            self._update_op(op_id, phase="renaming", processed=total,
                            message=f"Matched {matched}/{total}, renaming files...")

            def convert_to_jpg(src: Path, dst: Path):
                """Convert any image to jpg. If already jpg/jpeg, just rename."""
                if src.suffix.lower() in {".jpg", ".jpeg"}:
                    src.rename(dst)
                else:
                    img = Image.open(src)
                    img = img.convert("RGB")
                    img.save(dst, "JPEG", quality=95)
                    src.unlink()

            all_files = image_files + video_files

            # Collect JSON sidecars (video+sidecar = one unit)
            json_files = sorted([f for f in folder.iterdir()
                                  if f.is_file() and f.suffix.lower() == ".json"])
            # Map: original media file -> its JSON sidecar
            sidecar_map: dict[Path, Path] = {}
            for jf in json_files:
                # e.g. "video123.json" -> find "video123.mp4" or "video123.mov"
                for ext in (self.IMAGE_EXTS | self.VIDEO_EXTS):
                    media = folder / f"{jf.stem}{ext}"
                    if media.exists():
                        sidecar_map[media] = jf
                        break

            # First pass: rename everything to temp names (including sidecars)
            temp_map: dict[Path, Path] = {}  # original -> temp
            for f in all_files:
                if f.exists():
                    tmp = folder / f"_tmp_{f.name}"
                    try:
                        f.rename(tmp)
                        temp_map[f] = tmp
                        # Also temp-rename sidecar if exists
                        sidecar = sidecar_map.get(f)
                        if sidecar and sidecar.exists():
                            stmp = folder / f"_tmp_{sidecar.name}"
                            try:
                                sidecar.rename(stmp)
                                sidecar_map[f] = stmp  # update to temp path
                            except Exception:
                                pass
                    except Exception as e:
                        print(f"[PipelineEngine] Temp rename error {f.name}: {e}")
                        temp_map[f] = f

            # Second pass: rename to final names
            pair_num = 1
            renamed: set[Path] = set()

            def rename_sidecar(orig_media_path, new_name_stem):
                """Rename sidecar JSON alongside its media file."""
                sidecar = sidecar_map.get(orig_media_path)
                if sidecar and sidecar.exists():
                    new_json = folder / f"{new_name_stem}.json"
                    try:
                        sidecar.rename(new_json)
                    except Exception:
                        pass

            for img_path in image_files:
                if img_path not in paired_imgs:
                    continue
                img_tmp = temp_map.get(img_path)
                if not img_tmp or not img_tmp.exists():
                    continue

                # Convert and rename image to jpg
                new_img = folder / f"{pair_num}.jpg"
                try:
                    convert_to_jpg(img_tmp, new_img)
                    renamed.add(img_path)
                    rename_sidecar(img_path, str(pair_num))
                except Exception as e:
                    print(f"[PipelineEngine] Rename error img {pair_num}: {e}")

                # Rename primary video (+ its sidecar)
                vids = img_to_videos.get(img_path, [])
                if vids:
                    primary_vid_path = vids[0][0]
                    vid_tmp = temp_map.get(primary_vid_path)
                    if vid_tmp and vid_tmp.exists():
                        new_vid = folder / f"{pair_num}{vid_tmp.suffix.lower()}"
                        try:
                            vid_tmp.rename(new_vid)
                            renamed.add(primary_vid_path)
                            rename_sidecar(primary_vid_path, str(pair_num))
                        except Exception as e:
                            print(f"[PipelineEngine] Rename error vid {pair_num}: {e}")

                    # Rename extras (+ their sidecars)
                    for extra_idx, (extra_path, _) in enumerate(vids[1:], 1):
                        extra_tmp = temp_map.get(extra_path)
                        if extra_tmp and extra_tmp.exists():
                            suffix = f"-extra{extra_idx if extra_idx > 1 else ''}"
                            new_extra = folder / f"{pair_num}{suffix}{extra_tmp.suffix.lower()}"
                            try:
                                extra_tmp.rename(new_extra)
                                renamed.add(extra_path)
                                rename_sidecar(extra_path, f"{pair_num}{suffix}")
                            except Exception as e:
                                print(f"[PipelineEngine] Rename error extra {pair_num}: {e}")

                pair_num += 1

            # Rename solos (convert images to jpg, rename videos + sidecars)
            solo_num = pair_num
            for f in all_files:
                if f in renamed:
                    continue
                tmp = temp_map.get(f)
                if not tmp or not tmp.exists():
                    continue
                is_image = tmp.suffix.lower() in self.IMAGE_EXTS
                ext = ".jpg" if is_image else tmp.suffix.lower()
                solo_name = f"{solo_num}-solo"
                new_path = folder / f"{solo_name}{ext}"
                try:
                    if is_image:
                        convert_to_jpg(tmp, new_path)
                    else:
                        tmp.rename(new_path)
                    rename_sidecar(f, solo_name)
                except Exception as e:
                    print(f"[PipelineEngine] Solo rename error: {e}")
                solo_num += 1

            # Clean up any leftover _tmp_ JSON sidecars that weren't matched
            for f in list(folder.iterdir()):
                if f.is_file() and f.name.startswith("_tmp_") and f.suffix.lower() == ".json":
                    try:
                        f.unlink()
                    except Exception:
                        pass

            # ── Resync DB with actual files on disk ──
            self._update_op(op_id, phase="syncing", message="Syncing DB with renamed files...")
            # Clear all old pipeline assets
            existing = self.db.get_pipeline_assets(limit=100000)
            for a in existing:
                self.db.delete_pipeline_asset(a.id)
            # Re-import from disk
            for f in folder.iterdir():
                if not f.is_file():
                    continue
                if f.suffix.lower() not in (self.IMAGE_EXTS | self.VIDEO_EXTS):
                    continue
                if f.name.startswith("_tmp_"):
                    continue
                file_type = "video" if f.suffix.lower() in self.VIDEO_EXTS else "image"
                self.db.create_pipeline_asset(
                    filename=f.name,
                    file_path=str(f),
                    file_type=file_type,
                    rating="",
                    status="pending",
                )

            # Clear thumbnail cache — files changed names/content
            for cf in self._thumbnail_cache.glob("*.jpg"):
                try:
                    cf.unlink()
                except Exception:
                    pass

            self._update_op(op_id, phase="done", processed=total,
                            message=f"Matched {matched}/{total} videos to images, files renamed")

        except Exception as e:
            import traceback
            traceback.print_exc()
            self._update_op(op_id, phase="failed", message=f"Matching error: {e}")

    # ── Tagging ──────────────────────────────────────────────

    def start_tagging(self, session_id: int = None, asset_ids: list = None,
                      force: bool = False) -> dict:
        """Start background Gemini tagging on grok-favorites folder.
        Tags all untagged files. force=True re-tags everything."""
        if not self._gemini_api_key:
            return {"error": "No Gemini API key configured"}

        op_id = self._new_op("tagging")
        thread = threading.Thread(
            target=self._tag_worker,
            args=(session_id, asset_ids, force, op_id),
            daemon=True,
        )
        thread.start()
        return {"ok": True, "op_id": op_id}

    def _tag_worker(self, session_id, asset_ids, force, op_id):
        """Scan grok-favorites folder, tag each file via Gemini.
        Writes EXIF to images, .json sidecar to videos. No DB needed."""
        try:
            try:
                from google import genai
                from google.genai import types
            except ImportError:
                self._update_op(op_id, phase="failed",
                                message="google-genai package not installed. Run: pip install google-genai")
                return

            self._update_op(op_id, phase="loading", message="Scanning folder...")

            folder = self._grok_favorites
            files_to_tag: list[Path] = []
            for f in sorted(folder.iterdir()):
                if not f.is_file():
                    continue
                if f.name.startswith("_tmp_"):
                    continue
                ext = f.suffix.lower()
                if ext in self.IMAGE_EXTS:
                    if not force and self._has_metadata_tags(f):
                        continue  # Already tagged
                    files_to_tag.append(f)
                elif ext in self.VIDEO_EXTS:
                    sidecar = f.with_suffix(".json")
                    if not force and sidecar.exists():
                        continue  # Already tagged
                    files_to_tag.append(f)

            if not files_to_tag:
                self._update_op(op_id, phase="done", message="All files already tagged")
                return

            total = len(files_to_tag)
            tagged = 0
            failed = 0
            counter_lock = threading.Lock()
            self._update_op(op_id, phase="tagging", total=total, processed=0,
                            message=f"Tagging {total} files...")

            def tag_single(file_path: Path):
                nonlocal tagged, failed
                if op_id in self._cancelled_ops:
                    return
                try:
                    is_video = file_path.suffix.lower() in self.VIDEO_EXTS
                    if is_video:
                        metadata = self._generate_video_metadata(file_path, self._gemini_api_key, genai, types)
                    else:
                        metadata = self._generate_full_metadata(file_path, self._gemini_api_key, genai, types)

                    if metadata is None:
                        with counter_lock:
                            failed += 1
                        return

                    # Write metadata
                    if is_video:
                        self._write_video_sidecar(file_path, metadata)
                    else:
                        self._embed_metadata(file_path, metadata)

                    # Also write .json sidecar for all files (consistent format)
                    sidecar = file_path.with_suffix(".json")
                    with open(sidecar, "w", encoding="utf-8") as f:
                        json.dump(metadata, f, indent=2, ensure_ascii=False)

                    with counter_lock:
                        tagged += 1
                except Exception as e:
                    print(f"[PipelineEngine] Tag error for {file_path.name}: {e}")
                    with counter_lock:
                        failed += 1

            with ThreadPoolExecutor(max_workers=2) as pool:
                futures = []
                for f in files_to_tag:
                    if op_id in self._cancelled_ops:
                        break
                    futures.append(pool.submit(tag_single, f))

                for i, future in enumerate(futures):
                    if op_id in self._cancelled_ops:
                        self._update_op(op_id, phase="cancelled", message="Cancelled by user")
                        return
                    future.result()
                    self._update_op(op_id, processed=i + 1,
                                    message=f"Tagged {tagged}/{total} (failed: {failed})")

            self._update_op(op_id, phase="done", processed=total,
                            message=f"Tagging complete: {tagged}/{total} tagged, {failed} failed")

        except Exception as e:
            self._update_op(op_id, phase="failed", message=f"Tagging error: {e}")

    def _generate_full_metadata(self, image_path: Path, api_key: str, genai, types, _retry=0):
        """Generate all metadata in a single Gemini API call.
        Returns dict with all content analysis fields, or None on failure."""
        if not api_key:
            return None

        try:
            client = genai.Client(api_key=api_key)
            print(f"[PipelineEngine] Processing: {image_path.name}" + (f" (retry {_retry})" if _retry else ""))

            with Image.open(image_path) as img:
                # Downscale and convert to JPEG bytes to reduce input size
                work = img.convert("RGB")
                max_dim = 1024
                if max(work.size) > max_dim:
                    work.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)
                buf = io.BytesIO()
                work.save(buf, format="JPEG", quality=80)
                image_part = types.Part.from_bytes(data=buf.getvalue(), mime_type="image/jpeg")

                prompt = """Analyze this image. Return a FLAT JSON (no nesting) with these keys:

"tags": comma-separated keywords (20-30 words),
"description": 1-2 sentences,
"adult": 1-5 (nudity level: 1=fully clothed, 2=mild cleavage/midriff, 3=swimwear/lingerie, 4=near-nude, 5=nude),
"racy": 1-5 (suggestive level: 1=none, 2=slightly alluring, 3=clearly suggestive pose/outfit, 4=very provocative, 5=explicit),
"violence": 1-5,
"rating": "kid"/"teen"/"adult" — USE THESE STRICT RULES: "adult" ONLY if adult>=3 OR racy>=4. "kid" if adult<=1 AND racy<=1 AND violence<=1. Otherwise "teen". Do NOT rate as "adult" just because the subject is attractive or wearing fitted clothing.,
"body_parts": array of visible parts like buttocks/cleavage/midriff/thighs etc,
"skin_exposure": "low"/"medium"/"high"/"very_high",
"camera_angle": e.g. low_angle/eye_level/high_angle,
"view_type": frontal_view/back_view/side_view/profile,
"pose_type": neutral/action/suggestive/dynamic,
"framing": full_body/upper_body/portrait/close_up,
"clothing_coverage": full/moderate/minimal/nude,
"clothing_type": array like armor/dress/swimwear/casual,
"clothing_fit": loose/fitted/tight/skin_tight,
"art_style": array like digital_art/anime/realistic,
"setting": array like beach/forest/studio/fantasy,
"mood": cheerful/mysterious/romantic/action,
"risk_factors": array of concerns like low_angle_shot/tight_clothing/suggestive_pose/voyeur_angle,
"visual_focus": array like face/body/action/scenery,
"safety_level": "safe"/"borderline"/"risky"/"unsafe",
"policy_flags": array of policy concerns,
"voyeur_risk": "none"/"low"/"medium"/"high" — consider ALL: upskirt/downblouse/low_angle, visual focus on buttocks/crotch/thighs, bent-over/spread/on-all-fours poses, back view emphasizing butt, hidden camera / peeping feel,
"context_flag": "ok"/"mismatch" — is the outfit appropriate for the setting? mismatch examples: bikini/swimwear in city/office/school, lingerie in public/outdoor, nudity in non-artistic context, underwear in casual/work setting

Return ONLY flat JSON, no nested objects."""

                response = client.models.generate_content(
                    model='gemini-2.5-flash',
                    config=types.GenerateContentConfig(
                        safety_settings=[
                            types.SafetySetting(category="HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold="BLOCK_NONE"),
                            types.SafetySetting(category="HARM_CATEGORY_HATE_SPEECH", threshold="BLOCK_NONE"),
                            types.SafetySetting(category="HARM_CATEGORY_HARASSMENT", threshold="BLOCK_NONE"),
                            types.SafetySetting(category="HARM_CATEGORY_DANGEROUS_CONTENT", threshold="BLOCK_NONE"),
                        ]
                    ),
                    contents=[prompt, image_part]
                )

                # Check if response was blocked
                if not response.text:
                    print(f"[PipelineEngine] BLOCKED for {image_path.name}, using default adult metadata")
                    return {
                        "tags": "digital art, character, illustration, game asset, jigsaw puzzle",
                        "description": "Illustrated character for jigsaw puzzle game.",
                        "adult": 4, "racy": 4, "violence": 1,
                        "rating": "adult",
                        "body_parts": [], "skin_exposure": "high",
                        "camera_angle": "eye_level", "view_type": "frontal_view",
                        "pose_type": "neutral", "framing": "full_body",
                        "clothing_coverage": "minimal", "clothing_type": [],
                        "clothing_fit": "tight", "art_style": ["digital_art"],
                        "setting": ["studio"], "mood": "neutral",
                        "risk_factors": [], "visual_focus": ["body"],
                        "safety_level": "risky", "policy_flags": [],
                        "voyeur_risk": "none", "context_flag": "ok",
                    }

                text = response.text.strip()

                # Remove markdown code blocks if present
                if text.startswith("```"):
                    parts = text.split("```")
                    if len(parts) >= 2:
                        text = parts[1]
                        if text.startswith("json"):
                            text = text[4:]
                        text = text.strip()

                # Find JSON object
                start = text.find("{")
                end = text.rfind("}") + 1
                if start >= 0 and end > start:
                    try:
                        data = json.loads(text[start:end])
                    except json.JSONDecodeError as je:
                        print(f"[PipelineEngine] JSON Parse Error for {image_path.name}: {je}")
                        return None

                    return {
                        "tags": data.get("tags", ""),
                        "description": data.get("description", ""),
                        "adult": data.get("adult", 1),
                        "racy": data.get("racy", 1),
                        "violence": data.get("violence", 1),
                        "rating": data.get("rating", "teen"),
                        "body_parts": data.get("body_parts", []),
                        "skin_exposure": data.get("skin_exposure", "low"),
                        "camera_angle": data.get("camera_angle", "eye_level"),
                        "view_type": data.get("view_type", "frontal_view"),
                        "pose_type": data.get("pose_type", "neutral"),
                        "framing": data.get("framing", "full_body"),
                        "clothing_coverage": data.get("clothing_coverage", "moderate"),
                        "clothing_type": data.get("clothing_type", []),
                        "clothing_fit": data.get("clothing_fit", "fitted"),
                        "art_style": data.get("art_style", []),
                        "setting": data.get("setting", []),
                        "mood": data.get("mood", "neutral"),
                        "risk_factors": data.get("risk_factors", []),
                        "visual_focus": data.get("visual_focus", []),
                        "safety_level": data.get("safety_level", "safe"),
                        "policy_flags": data.get("policy_flags", []),
                        "voyeur_risk": data.get("voyeur_risk", "none"),
                        "context_flag": data.get("context_flag", "ok"),
                    }
                else:
                    print(f"[PipelineEngine] No JSON found in response for {image_path.name}")
                    return None

        except Exception as e:
            err_str = str(e)
            print(f"[PipelineEngine] EXCEPTION for {image_path.name}: {type(e).__name__}: {e}")
            # Retry on rate limit (max 2 retries)
            if ("429" in err_str or "RESOURCE_EXHAUSTED" in err_str) and _retry < 2:
                wait = 3 * (_retry + 1)
                print(f"[PipelineEngine] Rate limited, waiting {wait}s and retrying...")
                time.sleep(wait)
                return self._generate_full_metadata(image_path, api_key, genai, types, _retry + 1)
            return None

    def _generate_video_metadata(self, video_path: Path, api_key: str, genai, types, _retry=0):
        """Generate metadata for a video using Gemini File API.
        Uploads the video, waits for processing, then analyzes."""
        if not api_key:
            return None

        try:
            client = genai.Client(api_key=api_key)
            print(f"[PipelineEngine] Uploading video: {video_path.name}" + (f" (retry {_retry})" if _retry else ""))

            # Upload video to Gemini
            uploaded = client.files.upload(file=str(video_path))

            # Wait for processing
            while uploaded.state.name == "PROCESSING":
                time.sleep(2)
                uploaded = client.files.get(name=uploaded.name)

            if uploaded.state.name == "FAILED":
                print(f"[PipelineEngine] Video upload failed: {video_path.name}")
                return None

            prompt = """Analyze this video. Return a FLAT JSON (no nesting) with these keys:

"tags": comma-separated keywords (20-30 words),
"description": 1-2 sentences,
"adult": 1-5 (nudity level),
"racy": 1-5 (suggestive level),
"violence": 1-5,
"rating": "kid"/"teen"/"adult",
"body_parts": array of visible parts like buttocks/cleavage/midriff/thighs etc,
"skin_exposure": "low"/"medium"/"high"/"very_high",
"camera_angle": e.g. low_angle/eye_level/high_angle,
"view_type": frontal_view/back_view/side_view/profile,
"pose_type": neutral/action/suggestive/dynamic,
"framing": full_body/upper_body/portrait/close_up,
"clothing_coverage": full/moderate/minimal/nude,
"clothing_type": array like armor/dress/swimwear/casual,
"clothing_fit": loose/fitted/tight/skin_tight,
"art_style": array like digital_art/anime/realistic,
"setting": array like beach/forest/studio/fantasy,
"mood": cheerful/mysterious/romantic/action,
"risk_factors": array of concerns,
"visual_focus": array like face/body/action/scenery,
"safety_level": "safe"/"borderline"/"risky"/"unsafe",
"policy_flags": array of policy concerns,
"voyeur_risk": "none"/"low"/"medium"/"high",
"context_flag": "ok"/"mismatch"

Return ONLY flat JSON, no nested objects."""

            response = client.models.generate_content(
                model='gemini-2.5-flash',
                config=types.GenerateContentConfig(
                    safety_settings=[
                        types.SafetySetting(category="HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold="BLOCK_NONE"),
                        types.SafetySetting(category="HARM_CATEGORY_HATE_SPEECH", threshold="BLOCK_NONE"),
                        types.SafetySetting(category="HARM_CATEGORY_HARASSMENT", threshold="BLOCK_NONE"),
                        types.SafetySetting(category="HARM_CATEGORY_DANGEROUS_CONTENT", threshold="BLOCK_NONE"),
                    ]
                ),
                contents=[prompt, uploaded]
            )

            if not response.text:
                print(f"[PipelineEngine] BLOCKED for video {video_path.name}, using default adult metadata")
                return {
                    "tags": "digital art, character, animation, game asset",
                    "description": "Animated character for game.",
                    "adult": 4, "racy": 4, "violence": 1,
                    "rating": "adult",
                    "body_parts": [], "skin_exposure": "high",
                    "camera_angle": "eye_level", "view_type": "frontal_view",
                    "pose_type": "neutral", "framing": "full_body",
                    "clothing_coverage": "minimal", "clothing_type": [],
                    "clothing_fit": "tight", "art_style": ["digital_art"],
                    "setting": ["studio"], "mood": "neutral",
                    "risk_factors": [], "visual_focus": ["body"],
                    "safety_level": "risky", "policy_flags": [],
                    "voyeur_risk": "none", "context_flag": "ok",
                }

            text = response.text.strip()

            # Remove markdown code blocks
            if text.startswith("```"):
                parts = text.split("```")
                if len(parts) >= 2:
                    text = parts[1]
                    if text.startswith("json"):
                        text = text[4:]
                    text = text.strip()

            start = text.find("{")
            end = text.rfind("}") + 1
            if start >= 0 and end > start:
                try:
                    data = json.loads(text[start:end])
                except json.JSONDecodeError:
                    print(f"[PipelineEngine] JSON parse error for video {video_path.name}")
                    return None

                return {
                    "tags": data.get("tags", ""),
                    "description": data.get("description", ""),
                    "adult": data.get("adult", 1),
                    "racy": data.get("racy", 1),
                    "violence": data.get("violence", 1),
                    "rating": data.get("rating", "teen"),
                    "body_parts": data.get("body_parts", []),
                    "skin_exposure": data.get("skin_exposure", "low"),
                    "camera_angle": data.get("camera_angle", "eye_level"),
                    "view_type": data.get("view_type", "frontal_view"),
                    "pose_type": data.get("pose_type", "neutral"),
                    "framing": data.get("framing", "full_body"),
                    "clothing_coverage": data.get("clothing_coverage", "moderate"),
                    "clothing_type": data.get("clothing_type", []),
                    "clothing_fit": data.get("clothing_fit", "fitted"),
                    "art_style": data.get("art_style", []),
                    "setting": data.get("setting", []),
                    "mood": data.get("mood", "neutral"),
                    "risk_factors": data.get("risk_factors", []),
                    "visual_focus": data.get("visual_focus", []),
                    "safety_level": data.get("safety_level", "safe"),
                    "policy_flags": data.get("policy_flags", []),
                    "voyeur_risk": data.get("voyeur_risk", "none"),
                    "context_flag": data.get("context_flag", "ok"),
                }
            return None

        except Exception as e:
            err_str = str(e)
            print(f"[PipelineEngine] Video EXCEPTION for {video_path.name}: {type(e).__name__}: {e}")
            if ("429" in err_str or "RESOURCE_EXHAUSTED" in err_str) and _retry < 2:
                wait = 3 * (_retry + 1)
                time.sleep(wait)
                return self._generate_video_metadata(video_path, api_key, genai, types, _retry + 1)
            return None

    # ── EXIF Embedding ───────────────────────────────────────

    def _embed_metadata(self, image_path: Path, metadata: dict):
        """Embed metadata into JPEG EXIF.
        Stores tags in XPKeywords, ratings in XPSubject, body/policy in XPTitle."""
        tags = metadata.get("tags", "") if isinstance(metadata, dict) else metadata
        if not tags:
            return

        # piexif only works with JPEG
        if image_path.suffix.lower() not in {".jpg", ".jpeg"}:
            return

        def arr_to_str(arr):
            if isinstance(arr, str):
                return arr
            return ",".join(arr) if arr else "none"

        try:
            # Re-save image to strip any corrupted EXIF, then add fresh tags
            with Image.open(image_path) as img:
                img_data = img.convert("RGB")
                img_data.save(image_path, "JPEG", quality=95)

            # Build fresh EXIF with all metadata
            exif_dict = {"0th": {}, "Exif": {}, "GPS": {}, "1st": {}, "thumbnail": None}

            # Tags in XPKeywords (0x9C9E)
            exif_dict["0th"][0x9C9E] = tags.encode("utf-16le")

            if isinstance(metadata, dict):
                # Description in ImageDescription and XPComment
                description = metadata.get("description", "")
                if description:
                    exif_dict["0th"][0x010E] = description.encode("utf-8")
                    exif_dict["0th"][0x9C9C] = description.encode("utf-16le")

                # Content ratings + camera/pose in XPSubject (0x9C9F)
                rating_str = (
                    f"adult:{metadata.get('adult', 1)}|"
                    f"racy:{metadata.get('racy', 1)}|"
                    f"violence:{metadata.get('violence', 1)}|"
                    f"rating:{metadata.get('rating', 'teen')}|"
                    f"safety:{metadata.get('safety_level', 'safe')}|"
                    f"camera:{metadata.get('camera_angle', 'eye_level')}|"
                    f"view:{metadata.get('view_type', 'frontal_view')}|"
                    f"pose:{metadata.get('pose_type', 'neutral')}|"
                    f"framing:{metadata.get('framing', 'full_body')}|"
                    f"skin:{metadata.get('skin_exposure', 'low')}|"
                    f"mood:{metadata.get('mood', 'neutral')}|"
                    f"voyeur:{metadata.get('voyeur_risk', 'none')}|"
                    f"context:{metadata.get('context_flag', 'ok')}"
                )
                exif_dict["0th"][0x9C9F] = rating_str.encode("utf-16le")

                # Body/Clothing/Risk in XPTitle (0x9C9B)
                policy_str = (
                    f"body:{arr_to_str(metadata.get('body_parts', []))}|"
                    f"coverage:{metadata.get('clothing_coverage', 'moderate')}|"
                    f"fit:{metadata.get('clothing_fit', 'fitted')}|"
                    f"clothing:{arr_to_str(metadata.get('clothing_type', []))}|"
                    f"style:{arr_to_str(metadata.get('art_style', []))}|"
                    f"setting:{arr_to_str(metadata.get('setting', []))}|"
                    f"risk:{arr_to_str(metadata.get('risk_factors', []))}|"
                    f"focus:{arr_to_str(metadata.get('visual_focus', []))}|"
                    f"flags:{arr_to_str(metadata.get('policy_flags', []))}"
                )
                exif_dict["0th"][0x9C9B] = policy_str.encode("utf-16le")

            exif_bytes = piexif.dump(exif_dict)
            piexif.insert(exif_bytes, str(image_path))
        except Exception as e:
            print(f"[PipelineEngine] EXIF embed error {image_path.name}: {e}")

    def _write_video_sidecar(self, video_path: Path, metadata: dict):
        """Write {stem}.json sidecar next to video."""
        if not metadata:
            return
        sidecar = video_path.with_suffix(".json")
        try:
            with open(sidecar, "w", encoding="utf-8") as f:
                json.dump(metadata, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"[PipelineEngine] Sidecar write error {video_path.name}: {e}")

    def _has_metadata_tags(self, image_path: Path) -> bool:
        """Check if image already has all required EXIF metadata tags.
        Returns False if ANY required field is empty or missing."""
        try:
            exif_dict = piexif.load(str(image_path))
            ifd = exif_dict.get("0th", {})

            # All these fields must have content
            required_fields = [
                0x9C9E,  # XPKeywords (tags)
                0x9C9B,  # XPTitle (body/policy info)
                0x9C9F,  # XPSubject (ratings)
            ]

            for tag_id in required_fields:
                raw = ifd.get(tag_id)
                if not raw:
                    return False

                # piexif might return bytes as tuple
                if isinstance(raw, tuple):
                    raw = bytes(raw)

                # Try to decode
                tags_str = ""
                if isinstance(raw, bytes):
                    try:
                        tags_str = raw.decode("utf-16le").rstrip("\x00").strip()
                    except Exception:
                        try:
                            tags_str = raw.decode("utf-8").rstrip("\x00").strip()
                        except Exception:
                            return False
                elif isinstance(raw, str):
                    tags_str = raw.strip()

                # Must have meaningful content
                if len(tags_str) < 5 or not any(c.isalpha() for c in tags_str):
                    return False

            return True
        except Exception:
            return False

    # ── Collections ──────────────────────────────────────────

    def list_collections(self, rating: str = "teen") -> list[dict]:
        """List all collection folders under {rating_folder}/Generations/ and Pushed.
        Return [{name, count, max_items, is_pushed, folder_path, rating}]"""
        config = self.RATING_CONFIGS.get(rating, self.RATING_CONFIGS["teen"])
        folder_name = config["folder"]
        gen_roots = [
            (self._pipeline_base / folder_name / "Generations", False),
            (self._pipeline_base / f"{folder_name} - Pushed" / "Generations", True),
        ]

        db_cols = self.db.get_pipeline_collections(rating=rating)
        collections = []
        seen_names: set[str] = set()

        for gen_root, is_pushed_folder in gen_roots:
            if not gen_root.is_dir():
                continue

            for d in sorted(gen_root.iterdir()):
                if not d.is_dir():
                    continue
                if d.name in seen_names:
                    continue
                seen_names.add(d.name)

                # Count media files in the folder
                count = 0
                for f in d.iterdir():
                    if f.is_file() and f.suffix.lower() in (self.IMAGE_EXTS | self.VIDEO_EXTS):
                        count += 1

                db_match = next((c for c in db_cols if c.name == d.name), None)

                collections.append({
                    "name": d.name,
                    "count": count,
                    "asset_count": count,
                    "max_items": db_match.max_items if db_match else 10,
                    "is_pushed": is_pushed_folder or (db_match.is_pushed if db_match else False),
                    "folder_path": str(d),
                    "id": db_match.id if db_match else 0,
                    "collection_id": db_match.id if db_match else None,
                    "rating": rating,
                    "pushed_at": db_match.pushed_at if db_match and hasattr(db_match, 'pushed_at') else "",
                    "created_at": db_match.created_at if db_match and hasattr(db_match, 'created_at') else "",
                })

        return collections

    def list_collection_files(self, collection: str, rating: str, is_pushed: bool = False) -> list[dict]:
        """List actual files in a collection folder. Returns [{filename, type, slot}]."""
        config = self.RATING_CONFIGS.get(rating, self.RATING_CONFIGS["teen"])
        folder_name = config["folder"]
        if is_pushed:
            gen_root = self._pipeline_base / f"{folder_name} - Pushed" / "Generations"
        else:
            gen_root = self._pipeline_base / folder_name / "Generations"

        col_folder = gen_root / collection
        if not col_folder.is_dir():
            return []

        files = []
        for f in sorted(col_folder.iterdir()):
            if not f.is_file():
                continue
            ext = f.suffix.lower()
            if ext in self.IMAGE_EXTS:
                file_type = "image"
            elif ext in self.VIDEO_EXTS:
                file_type = "video"
            else:
                continue
            slot = None
            try:
                slot = int(f.stem)
            except ValueError:
                pass
            files.append({
                "filename": f.name,
                "file_type": file_type,
                "slot": slot,
                "folder_path": str(col_folder),
            })
        return files

    def _load_collection_counter(self, rating: str, collection: str) -> int:
        """Load collection counter from our own counter file."""
        try:
            with open(self._counter_file, "r", encoding="utf-8") as f:
                counters = json.load(f)
            key = f"{rating}::{collection.lower()}"
            return counters.get(key, 0)
        except Exception:
            return 0

    def _save_collection_counter(self, rating: str, collection: str, value: int):
        """Save updated counter to our own counter file."""
        try:
            counters = {}
            if self._counter_file.is_file():
                with open(self._counter_file, "r", encoding="utf-8") as f:
                    counters = json.load(f)
            key = f"{rating}::{collection.lower()}"
            counters[key] = value
            self._counter_file.parent.mkdir(parents=True, exist_ok=True)
            with open(self._counter_file, "w", encoding="utf-8") as f:
                json.dump(counters, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"[PipelineEngine] Failed to save counter: {e}")

    def _find_available_slots(self, col_folder: Path, count: int, rating: str, collection: str) -> list[int]:
        """Find available slot numbers.
        - Generic: NEVER fill gaps (gaps = pushed+archived files in R2).
          Always increment counter to avoid overwriting R2 assets.
        - Named collections (max 10): fill gaps in 1-10 (they get pushed as a full set).
        """
        is_generic = collection.lower() == "generic"

        # Scan existing numbered files on disk (images + videos)
        existing_on_disk = set()
        if col_folder.is_dir():
            for f in col_folder.iterdir():
                if f.is_file() and f.suffix.lower() in (self.IMAGE_EXTS | self.VIDEO_EXTS):
                    try:
                        existing_on_disk.add(int(f.stem))
                    except ValueError:
                        pass

        slots = []

        if not is_generic:
            # Named collection: fill gaps in 1-10 (safe — these are local-only until full push)
            for n in range(1, 11):
                if n not in existing_on_disk:
                    slots.append(n)
                if len(slots) >= count:
                    return slots[:count]
            # Named collection full (10 items)
            return slots[:count]
        else:
            # Generic: ONLY use counter. Never fill gaps — those numbers are in R2.
            counter = self._load_collection_counter(rating, collection)
            # Also ensure counter is past anything currently on disk
            if existing_on_disk:
                counter = max(counter, max(existing_on_disk))

            for _ in range(count):
                counter += 1
                # Double-check no file exists at this number (overwrite protection)
                while self._slot_exists_on_disk(col_folder, counter):
                    counter += 1
                slots.append(counter)

            # Save the updated counter
            self._save_collection_counter(rating, collection, counter)
            return slots

    def _slot_exists_on_disk(self, col_folder: Path, num: int) -> bool:
        """Check if any file with this number already exists in the folder."""
        for ext in self.IMAGE_EXTS | self.VIDEO_EXTS:
            if (col_folder / f"{num}{ext}").exists():
                return True
        return False

    def accept_assets(self, asset_ids: list[int] = None, collection: str = "",
                      rating: str = "teen", pairs: list[dict] = None) -> dict:
        """Accept pairs into a collection folder.

        pairs: [{image: "1.jpg", video: "1.mp4"}, ...] — filenames from grok-favorites.
        Each pair's image + chosen video get moved with sequential numbering.
        Unchosen extras and .json sidecars get deleted.
        Falls back to asset_ids for backward compat.
        """
        folder = self._grok_favorites
        gen_root = self._generations_root(rating)
        col_folder = gen_root / collection
        col_folder.mkdir(parents=True, exist_ok=True)

        if pairs:
            # New flow: filename-based pairs
            total_slots = len(pairs)
            slots = self._find_available_slots(col_folder, total_slots, rating, collection)

            moved = 0
            errors = []

            for idx, pair in enumerate(pairs):
                if idx >= len(slots):
                    errors.append(f"No more slots")
                    break

                num = slots[idx]
                img_name = pair.get("image", "")
                vid_name = pair.get("video", "")

                # Move image
                if img_name:
                    src_img = folder / img_name
                    if src_img.exists():
                        dest_img = col_folder / f"{num}.jpg"
                        try:
                            shutil.move(str(src_img), str(dest_img))
                            # Also move image json sidecar if exists
                            src_json = src_img.with_suffix(".json")
                            if src_json.exists():
                                shutil.move(str(src_json), str(col_folder / f"{num}.json"))
                            moved += 1
                        except Exception as e:
                            errors.append(f"{img_name}: {e}")
                    else:
                        errors.append(f"Not found: {img_name}")

                # Move chosen video
                if vid_name:
                    src_vid = folder / vid_name
                    if src_vid.exists():
                        dest_vid = col_folder / f"{num}.mp4"
                        try:
                            shutil.move(str(src_vid), str(dest_vid))
                            # Move video json sidecar
                            src_json = src_vid.with_suffix(".json")
                            if src_json.exists():
                                shutil.move(str(src_json), str(col_folder / f"{num}_vid.json"))
                            moved += 1
                        except Exception as e:
                            errors.append(f"{vid_name}: {e}")

                # Delete unchosen extras for this pair number
                pair_stem = img_name.split(".")[0] if img_name else vid_name.split(".")[0]
                for f in folder.glob(f"{pair_stem}-extra*"):
                    if f.name != vid_name:  # Don't delete if user chose an extra
                        try:
                            f.unlink()
                        except Exception:
                            pass

            # Also delete leftover JSON sidecars for accepted pair stems
            for idx, pair in enumerate(pairs):
                pair_stem = (pair.get("image", "") or pair.get("video", "")).split(".")[0].split("-")[0]
                if pair_stem:
                    for f in list(folder.glob(f"{pair_stem}*.json")):
                        try:
                            f.unlink()
                        except Exception:
                            pass

            # Create catalog records for the accepted assets
            try:
                self._create_catalog_records_for_accepted(col_folder, rating, collection, slots[:len(pairs)])
            except Exception as e:
                errors.append(f"Catalog record error: {e}")

            # Sync collection DB record (was missing — collections tab wouldn't update)
            self._sync_collection_db(collection, rating, col_folder)

            # Clear thumbnail cache for accepted files
            for idx, pair in enumerate(pairs):
                pair_stem = (pair.get("image", "") or pair.get("video", "")).split(".")[0].split("-")[0]
                for cf in self._thumbnail_cache.glob(f"{pair_stem}*"):
                    try:
                        cf.unlink()
                    except Exception:
                        pass

            result = {"ok": True, "moved": moved, "collection": collection, "rating": rating}
            if errors:
                result["errors"] = errors
                print(f"[PipelineEngine] Accept errors: {errors}")
            return result

        # Legacy fallback: asset_ids based
        if not asset_ids:
            return {"error": "Provide pairs or asset_ids"}

        assets = []
        for asset_id in asset_ids:
            asset = self.db.get_pipeline_asset(asset_id)
            if asset:
                assets.append(asset)

        image_assets = [a for a in assets if a.file_type == "image"]
        video_only = [a for a in assets if a.file_type == "video" and a.id not in
                      {a2.paired_asset_id for a2 in image_assets if a2.paired_asset_id}]

        total_slots = len(image_assets) + len(video_only)
        slots = self._find_available_slots(col_folder, total_slots, rating, collection)

        moved = 0
        errors = []
        slot_idx = 0

        for img_asset in image_assets:
            if slot_idx >= len(slots):
                errors.append(f"No more slots for {img_asset.filename}")
                continue
            src = Path(img_asset.file_path)
            if not src.exists():
                errors.append(f"File not found: {src}")
                continue

            num = slots[slot_idx]
            slot_idx += 1
            img_ext = src.suffix.lower()
            dest = col_folder / f"{num}{img_ext}"

            if dest.exists():
                errors.append(f"SKIPPED {num}{img_ext} — file already exists, won't overwrite")
                continue

            try:
                shutil.copy2(str(src), str(dest))
                self.db.update_pipeline_asset(
                    img_asset.id, status="accepted", collection=collection,
                    rating=rating, file_path=str(dest), filename=f"{num}{img_ext}",
                )
                moved += 1

                # Paired video gets the same number
                if img_asset.paired_asset_id:
                    vid_asset = self.db.get_pipeline_asset(img_asset.paired_asset_id)
                    if vid_asset:
                        vid_src = Path(vid_asset.file_path)
                        if vid_src.exists():
                            vid_ext = vid_src.suffix.lower()
                            vid_dest = col_folder / f"{num}{vid_ext}"
                            if vid_dest.exists():
                                errors.append(f"SKIPPED video {num}{vid_ext} — already exists")
                            else:
                                shutil.copy2(str(vid_src), str(vid_dest))
                                self.db.update_pipeline_asset(
                                    vid_asset.id, status="accepted", collection=collection,
                                    rating=rating, file_path=str(vid_dest), filename=f"{num}{vid_ext}",
                                )
                                moved += 1
            except Exception as e:
                errors.append(f"Move error {src.name}: {e}")

        # Handle unpaired videos (get their own slot)
        for vid_asset in video_only:
            if slot_idx >= len(slots):
                break
            src = Path(vid_asset.file_path)
            if not src.exists():
                continue
            num = slots[slot_idx]
            slot_idx += 1
            vid_ext = src.suffix.lower()
            dest = col_folder / f"{num}{vid_ext}"
            if dest.exists():
                errors.append(f"SKIPPED {num}{vid_ext} — file already exists")
                continue
            try:
                shutil.copy2(str(src), str(dest))
                self.db.update_pipeline_asset(
                    vid_asset.id, status="accepted", collection=collection,
                    rating=rating, file_path=str(dest), filename=f"{num}{vid_ext}",
                )
                moved += 1
            except Exception as e:
                errors.append(f"Move error {src.name}: {e}")

        # Sync collection DB record
        self._sync_collection_db(collection, rating, col_folder)

        result = {"ok": True, "moved": moved}
        if errors:
            result["errors"] = errors
        return result

    def _sync_collection_db(self, collection: str, rating: str, col_folder: Path):
        """Sync collection DB record with actual folder contents."""
        image_count = sum(
            1 for f in col_folder.iterdir()
            if f.is_file() and f.suffix.lower() in self.IMAGE_EXTS
        )
        db_cols = self.db.get_pipeline_collections(rating=rating)
        db_match = next((c for c in db_cols if c.name == collection), None)
        if db_match:
            self.db.update_pipeline_collection(db_match.id, asset_count=image_count)
        else:
            self.db.create_pipeline_collection(
                name=collection, rating=rating,
                folder_path=str(col_folder), asset_count=image_count,
            )

    def reject_assets(self, asset_ids: list[int]) -> dict:
        """Delete rejected assets from disk: image + paired video + .json sidecars."""
        rejected = 0
        errors = []
        for asset_id in asset_ids:
            asset = self.db.get_pipeline_asset(asset_id)
            if not asset:
                continue

            files_to_delete = []
            p = Path(asset.file_path)

            # Get the pair number stem (e.g. "6" from "6.jpg" or "6.mp4" or "6-extra.mp4")
            stem = p.stem.split("-")[0]  # "6-extra" -> "6", "6" -> "6"
            folder = p.parent

            # Delete ALL files with this pair number: image, video, extras, sidecars
            for ext in (self.IMAGE_EXTS | self.VIDEO_EXTS):
                # Main pair file: 6.jpg, 6.mp4
                main = folder / f"{stem}{ext}"
                if main.exists():
                    files_to_delete.append(main)
                files_to_delete.append(main.with_suffix(".json"))
                # Extras: 6-extra.mp4, 6-extra2.mp4
                for extra in folder.glob(f"{stem}-extra*{ext}"):
                    files_to_delete.append(extra)
                    files_to_delete.append(extra.with_suffix(".json"))

            for f in files_to_delete:
                try:
                    if f.exists():
                        f.unlink()
                except Exception as e:
                    errors.append(f"{f.name}: {e}")

            # Remove from DB
            self.db.delete_pipeline_asset(asset_id)
            # Also delete paired asset from DB if exists
            if asset.paired_asset_id:
                self.db.delete_pipeline_asset(asset.paired_asset_id)
            rejected += 1

        result = {"ok": True, "rejected": rejected}
        if errors:
            result["errors"] = errors
        return result

    def list_pairs(self) -> list[dict]:
        """List all pairs in grok-favorites. Returns file-based pair info."""
        folder = self._grok_favorites
        if not folder.is_dir():
            return []

        # Group files by pair number
        groups: dict[str, dict] = {}  # stem -> {image, videos[], extras[], solos[]}
        for f in sorted(folder.iterdir()):
            if not f.is_file():
                continue
            ext = f.suffix.lower()
            if ext not in (self.IMAGE_EXTS | self.VIDEO_EXTS | {".json"}):
                continue
            if ext == ".json":
                continue  # Skip sidecars

            name = f.stem  # e.g. "6", "6-extra", "23-solo"
            is_solo = "-solo" in name
            is_extra = "-extra" in name
            stem = name.split("-")[0]  # "6"

            if stem not in groups:
                groups[stem] = {"stem": stem, "image": None, "video": None,
                                "extras": [], "is_solo": False}

            if is_solo:
                groups[stem]["is_solo"] = True
                if ext in self.IMAGE_EXTS:
                    groups[stem]["image"] = f.name
                elif ext in self.VIDEO_EXTS:
                    groups[stem]["video"] = f.name
            elif is_extra:
                groups[stem]["extras"].append(f.name)
            elif ext in self.IMAGE_EXTS:
                groups[stem]["image"] = f.name
            elif ext in self.VIDEO_EXTS:
                groups[stem]["video"] = f.name

        # Build result
        pairs = []
        for stem in sorted(groups.keys(), key=lambda s: int(s) if s.isdigit() else 999):
            g = groups[stem]
            pairs.append({
                "stem": stem,
                "image": g["image"],
                "video": g["video"],
                "extras": g["extras"],
                "is_solo": g["is_solo"],
                "has_extras": len(g["extras"]) > 0,
            })
        return pairs

    def reject_by_filenames(self, filenames: list[str]) -> dict:
        """Delete entire pairs by filename. Any file in a pair deletes the whole pair.
        Deletes images, videos, JSON sidecars — everything matching the pair stem.
        Retries on Windows file locks."""
        folder = self._grok_favorites
        rejected = 0
        errors = []

        # Collect unique pair stems to delete
        stems_to_delete: set[str] = set()
        for name in filenames:
            stem = name.split(".")[0].split("-")[0]  # "6-extra.mp4" -> "6"
            stems_to_delete.add(stem)

        for stem in stems_to_delete:
            deleted_any = False
            # Collect ALL files with matching stem (images, videos, JSONs, sidecars)
            files_to_delete = []
            for f in list(folder.iterdir()):
                if not f.is_file():
                    continue
                f_stem = f.stem.split("-")[0]  # "6-extra" -> "6", "6" -> "6"
                if f_stem == stem:
                    files_to_delete.append(f)

            # Delete with retry for Windows file locking
            for f in files_to_delete:
                deleted = False
                for attempt in range(3):
                    try:
                        f.unlink()
                        deleted = True
                        break
                    except PermissionError:
                        # Windows file lock — wait briefly and retry
                        import gc
                        gc.collect()
                        time.sleep(0.3 * (attempt + 1))
                    except Exception as e:
                        errors.append(f"{f.name}: {e}")
                        break
                if deleted:
                    deleted_any = True
                elif not any(f.name in err for err in errors):
                    errors.append(f"{f.name}: could not delete (file may be locked)")
            if deleted_any:
                rejected += 1

        # Clear thumbnail cache for deleted files
        if rejected > 0:
            for stem in stems_to_delete:
                for cf in self._thumbnail_cache.glob(f"{stem}.*"):
                    try:
                        cf.unlink()
                    except Exception:
                        pass

        result = {"ok": True, "rejected": rejected}
        if errors:
            result["errors"] = errors
            result["ok"] = rejected > 0  # partial success if some deleted
        return result

    def create_collection(self, name: str, rating: str) -> dict:
        """Create a new collection folder."""
        gen_root = self._generations_root(rating)
        col_folder = gen_root / name
        col_folder.mkdir(parents=True, exist_ok=True)

        # Check if already exists in DB
        db_cols = self.db.get_pipeline_collections(rating=rating)
        db_match = next((c for c in db_cols if c.name == name), None)
        if db_match:
            return {"ok": True, "collection_id": db_match.id, "message": "Collection already exists"}

        col_id = self.db.create_pipeline_collection(
            name=name,
            rating=rating,
            folder_path=str(col_folder),
            asset_count=0,
        )
        return {"ok": True, "collection_id": col_id}

    # ── Music Generation ──────────────────────────────────────

    def generate_music(self, collection: str, rating: str, prompt: str = "") -> dict:
        """Generate a 30-second music track for a collection via ElevenLabs."""
        gen_root = self._generations_root(rating)
        col_dir = gen_root / collection
        if not col_dir.is_dir():
            return {"error": f"Collection folder not found: {col_dir}"}

        music_dir = col_dir / "music"
        music_dir.mkdir(exist_ok=True)

        # Find next available music filename: {collection_name}_NNNNN_.mp3
        existing = [f for f in music_dir.iterdir() if f.suffix.lower() in (".mp3", ".m4a", ".wav", ".ogg")]
        next_num = len(existing) + 1
        output_file = music_dir / f"{collection}_{next_num:05d}_.mp3"

        if not prompt:
            prompt = "Calm, relaxing ambient background music for a jigsaw puzzle game. Gentle and soothing, no vocals."

        op_id = self._new_op("music", collection=collection, rating=rating)

        thread = threading.Thread(
            target=self._music_worker,
            args=(prompt, output_file, op_id, collection, rating),
            daemon=True,
        )
        thread.start()
        return {"ok": True, "op_id": op_id}

    def _music_worker(self, prompt: str, output_file: Path, op_id: str, collection: str, rating: str):
        try:
            self._update_op(op_id, phase="generating", message="Generating music via ElevenLabs...")

            # Load API key from settings, Auto Game Builder's MCP config, or env var.
            api_key = self.settings.get("elevenlabs_api_key", "")

            if not api_key:
                mcp_config_path = _find_agb_mcp_servers_config()
                if mcp_config_path:
                    try:
                        with open(mcp_config_path, encoding="utf-8") as f:
                            mcp = json.load(f)
                        api_key = mcp.get("elevenlabs", {}).get("_api_key", "")
                    except Exception:
                        pass

            if not api_key:
                api_key = os.environ.get("ELEVENLABS_API_KEY", "")

            if not api_key:
                self._update_op(op_id, phase="failed", message="ElevenLabs API key not found")
                return

            from elevenlabs import ElevenLabs
            client = ElevenLabs(api_key=api_key)

            result = client.text_to_sound_effects.convert(
                text=prompt,
                duration_seconds=30,
            )

            # Write the audio data to file
            with open(output_file, "wb") as f:
                for chunk in result:
                    f.write(chunk)

            self._update_op(
                op_id, phase="done", progress=1, total=1,
                message=f"Music saved: {output_file.name}",
            )

        except Exception as e:
            self._update_op(op_id, phase="failed", message=f"Music generation failed: {e}")

    # ── R2 Push ──────────────────────────────────────────────

    def start_push(self, collection: str, rating: str) -> dict:
        """Start background R2 push. Returns {ok, op_id}.
        Named collections require 10 jpg + 10 mp4 + 1 music. Generic has no limit."""
        config = self.RATING_CONFIGS.get(rating)
        if not config:
            return {"error": f"Invalid rating: {rating}"}

        gen_root = self._generations_root(rating)
        col_folder = gen_root / collection
        if not col_folder.is_dir():
            return {"error": f"Collection folder not found: {col_folder}"}

        # Collect files to upload
        files = [
            f for f in col_folder.iterdir()
            if f.is_file() and f.suffix.lower() in (self.IMAGE_EXTS | self.VIDEO_EXTS)
        ]
        if not files:
            return {"error": "No files in collection to push"}

        # Validate named collections: need 10 jpg + 10 mp4 + 1 music
        is_generic = collection.lower() == "generic"
        if not is_generic:
            jpg_count = sum(1 for f in files if f.suffix.lower() in self.IMAGE_EXTS)
            mp4_count = sum(1 for f in files if f.suffix.lower() in self.VIDEO_EXTS)
            music_dir = col_folder / "music"
            music_count = len([f for f in music_dir.iterdir() if f.suffix.lower() in {".mp3", ".m4a", ".wav", ".ogg"}]) if music_dir.is_dir() else 0
            missing = []
            if jpg_count < 10:
                missing.append(f"{jpg_count}/10 images")
            if mp4_count < 10:
                missing.append(f"{mp4_count}/10 videos")
            if music_count < 1:
                missing.append("0/1 music")
            if missing:
                return {"error": f"Collection not ready: {', '.join(missing)}"}

        op_id = self._new_op("push", collection=collection, rating=rating, total=len(files))
        thread = threading.Thread(
            target=self._push_worker,
            args=(collection, rating, op_id),
            daemon=True,
        )
        thread.start()
        return {"ok": True, "op_id": op_id}

    def _push_worker(self, collection: str, rating: str, op_id: str):
        """Background: Upload collection files to R2 via wrangler.
        Key structure: collections/{collection}/images/{filename} (or /videos/)
        Mark collection as pushed after success."""
        try:
            config = self.RATING_CONFIGS[rating]
            bucket = config["bucket"]
            gen_root = self._generations_root(rating)
            col_folder = gen_root / collection

            # Gather all files
            image_files = sorted([
                f for f in col_folder.iterdir()
                if f.is_file() and f.suffix.lower() in self.IMAGE_EXTS
            ])
            video_files = sorted([
                f for f in col_folder.iterdir()
                if f.is_file() and f.suffix.lower() in self.VIDEO_EXTS
            ])
            music_dir = col_folder / "music"
            music_files = sorted([
                f for f in music_dir.iterdir()
                if f.is_file() and f.suffix.lower() in {".mp3", ".m4a", ".ogg", ".wav"}
            ]) if music_dir.is_dir() else []

            total = len(image_files) + len(video_files) + len(music_files)
            self._update_op(op_id, phase="uploading", total=total, processed=0,
                            message=f"Pushing {total} files to R2 ({bucket})...")

            uploaded = 0

            # Upload images
            for img in image_files:
                if op_id in self._cancelled_ops:
                    self._update_op(op_id, phase="cancelled", message="Cancelled by user")
                    return
                key = f"collections/{collection}/images/{img.name}"
                self._update_op(op_id, message=f"Uploading {key}")
                if not self._r2_put(bucket, key, img):
                    self._update_op(op_id, phase="failed",
                                    message=f"Failed to upload {img.name}")
                    return
                uploaded += 1
                self._update_op(op_id, processed=uploaded)

            # Upload videos
            for vid in video_files:
                if op_id in self._cancelled_ops:
                    self._update_op(op_id, phase="cancelled", message="Cancelled by user")
                    return
                key = f"collections/{collection}/videos/{vid.name}"
                self._update_op(op_id, message=f"Uploading {key}")
                if not self._r2_put(bucket, key, vid):
                    self._update_op(op_id, phase="failed",
                                    message=f"Failed to upload {vid.name}")
                    return
                uploaded += 1
                self._update_op(op_id, processed=uploaded)

            # Upload music
            for mus in music_files:
                if op_id in self._cancelled_ops:
                    self._update_op(op_id, phase="cancelled", message="Cancelled by user")
                    return
                key = f"collections/{collection}/music/{mus.name}"
                self._update_op(op_id, message=f"Uploading {key}")
                if not self._r2_put(bucket, key, mus):
                    self._update_op(op_id, phase="failed",
                                    message=f"Failed to upload {mus.name}")
                    return
                uploaded += 1
                self._update_op(op_id, processed=uploaded)

            # Mark collection as pushed in DB
            db_cols = self.db.get_pipeline_collections(rating=rating)
            db_match = next((c for c in db_cols if c.name == collection), None)
            if db_match:
                self.db.update_pipeline_collection(
                    db_match.id,
                    is_pushed=1,
                    pushed_at=datetime.now().isoformat(),
                )

            # Move collection folder to "Pushed" folder
            folder_name = config["folder"]  # e.g. "Hot Jigsaw"
            pushed_gen_root = self._pipeline_base / f"{folder_name} - Pushed" / "Generations"
            pushed_gen_root.mkdir(parents=True, exist_ok=True)
            pushed_dest = pushed_gen_root / collection
            try:
                if pushed_dest.exists():
                    # Merge: move individual files into existing pushed folder
                    for f in list(col_folder.iterdir()):
                        dest_f = pushed_dest / f.name
                        if f.is_dir():
                            # Music subfolder — merge contents
                            dest_f.mkdir(exist_ok=True)
                            for sf in f.iterdir():
                                shutil.move(str(sf), str(dest_f / sf.name))
                            f.rmdir()
                        else:
                            shutil.move(str(f), str(dest_f))
                    col_folder.rmdir()
                else:
                    shutil.move(str(col_folder), str(pushed_dest))
                self._update_op(op_id, message=f"Moved to {folder_name} - Pushed")
            except Exception as e:
                print(f"[PipelineEngine] Failed to move to Pushed folder: {e}")

            self._update_op(op_id, phase="done", processed=uploaded,
                            message=f"Pushed {uploaded} files to R2 ({bucket}/{collection})")

        except Exception as e:
            self._update_op(op_id, phase="failed", message=f"R2 push error: {e}")

    def _r2_put(self, bucket: str, key: str, file_path: Path) -> bool:
        """Upload single file to R2 via wrangler. Returns success."""
        try:
            result = subprocess.run(
                [
                    self._wrangler_cmd, "r2", "object", "put",
                    f"{bucket}/{key}",
                    "--file", str(file_path),
                    "--remote",
                ],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                check=True,
                timeout=120,
            )
            return True
        except subprocess.CalledProcessError as e:
            print(f"[PipelineEngine] R2 put failed for {key}: {e.stderr or e.stdout}")
            return False
        except subprocess.TimeoutExpired:
            print(f"[PipelineEngine] R2 put timed out for {key}")
            return False
        except Exception as e:
            print(f"[PipelineEngine] R2 put error for {key}: {e}")
            return False

    # ── Thumbnails ───────────────────────────────────────────

    def get_thumbnail_path(self, asset_id: int) -> Optional[Path]:
        """Get/generate thumbnail for an asset. Returns path to 256px JPEG."""
        asset = self.db.get_pipeline_asset(asset_id)
        if not asset:
            return None

        # Check if thumbnail already exists
        thumb_path = self._thumbnail_cache / f"{asset_id}.jpg"
        if thumb_path.exists():
            return thumb_path

        source = Path(asset.file_path)
        if not source.exists():
            return None

        self._generate_thumbnail(source, thumb_path, size=256)
        return thumb_path if thumb_path.exists() else None

    def _generate_thumbnail(self, source_path: Path, dest_path: Path, size: int = 256):
        """Generate thumbnail JPEG. For videos, extract first frame first."""
        try:
            if source_path.suffix.lower() in self.VIDEO_EXTS:
                # Extract first frame from video
                cap = cv2.VideoCapture(str(source_path))
                ret, frame = cap.read()
                cap.release()
                if not ret or frame is None:
                    return
                # Convert BGR to RGB for PIL
                frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                img = Image.fromarray(frame_rgb)
            else:
                img = Image.open(source_path)

            # Resize to max dimension while keeping aspect ratio
            img = img.convert("RGB")
            img.thumbnail((size, size), Image.Resampling.LANCZOS)

            # Save as JPEG
            dest_path.parent.mkdir(parents=True, exist_ok=True)
            img.save(dest_path, "JPEG", quality=80)
        except Exception as e:
            print(f"[PipelineEngine] Thumbnail error for {source_path.name}: {e}")

    # ── Status & Helpers ─────────────────────────────────────

    def get_op_status(self, op_id: str) -> Optional[dict]:
        """Get operation status."""
        return self._active_ops.get(op_id)

    def cancel_op(self, op_id: str) -> dict:
        """Cancel a running operation."""
        if op_id not in self._active_ops:
            return {"error": f"Operation {op_id} not found"}
        self._cancelled_ops.add(op_id)
        self._update_op(op_id, phase="cancelling", message="Cancellation requested...")
        return {"ok": True, "message": f"Cancellation requested for {op_id}"}

    def _new_op(self, op_type: str, **kwargs) -> str:
        """Create new operation tracker. Returns op_id."""
        op_id = f"{op_type}_{uuid.uuid4().hex[:8]}"
        self._active_ops[op_id] = {
            "op_id": op_id,
            "type": op_type,
            "phase": "starting",
            "message": f"Starting {op_type}...",
            "total": 0,
            "processed": 0,
            "started_at": datetime.now().isoformat(),
            **kwargs,
        }
        return op_id

    def _update_op(self, op_id: str, **kwargs):
        """Update operation status."""
        if op_id in self._active_ops:
            self._active_ops[op_id].update(kwargs)

    def _rating_root(self, rating: str) -> Path:
        """Get root folder for a rating."""
        config = self.RATING_CONFIGS.get(rating, self.RATING_CONFIGS["teen"])
        return self._pipeline_base / config["folder"]

    def _generations_root(self, rating: str) -> Path:
        """Get Generations folder for a rating."""
        return self._rating_root(rating) / "Generations"

    # ── Asset Catalog Import ────────────────────────────────

    def import_existing_catalog(self) -> dict:
        """Scan ALL three rating folders and import every asset into asset_catalog.
        Reads EXIF metadata from .jpg files and .json sidecars.
        Returns {ok, imported, collections, errors}."""
        imported = 0
        collections_found: set[str] = set()
        errors: list[str] = []

        for rating, config in self.RATING_CONFIGS.items():
            # Scan both unpushed and pushed folders
            folder_name = config["folder"]
            gen_roots = [
                self._pipeline_base / folder_name / "Generations",
                self._pipeline_base / f"{folder_name} - Pushed" / "Generations",
            ]

            for gen_root in gen_roots:
                if not gen_root.is_dir():
                    continue
                is_pushed = "Pushed" in str(gen_root)

                for col_dir in sorted(gen_root.iterdir()):
                    if not col_dir.is_dir():
                        continue
                    collection = col_dir.name
                    collections_found.add(f"{rating}/{collection}")

                    # Process each file in the collection
                    for f in sorted(col_dir.iterdir()):
                        if not f.is_file():
                            continue
                        ext = f.suffix.lower()
                        if ext not in (self.IMAGE_EXTS | self.VIDEO_EXTS):
                            continue

                        # Parse slot number from filename stem (e.g. "3" from "3.jpg")
                        try:
                            slot_number = int(f.stem)
                        except ValueError:
                            continue  # skip non-numeric filenames

                        file_type = "video" if ext in self.VIDEO_EXTS else "image"

                        # Read metadata
                        metadata = {}
                        tags = ""
                        description = ""
                        adult_score = 0
                        racy_score = 0
                        violence_score = 0
                        safety_level = ""
                        voyeur_risk = ""
                        context_flag = ""
                        skin_exposure = ""
                        pose_type = ""
                        framing = ""
                        clothing_coverage = ""

                        # Try .json sidecar first
                        json_sidecar = f.with_suffix(".json")
                        if file_type == "video" and not json_sidecar.exists():
                            json_sidecar = col_dir / f"{f.stem}_vid.json"

                        if json_sidecar.exists():
                            try:
                                with open(json_sidecar, "r", encoding="utf-8") as jf:
                                    metadata = json.load(jf)
                                tags = metadata.get("tags", "")
                                if isinstance(tags, list):
                                    tags = ", ".join(tags)
                                description = metadata.get("description", "")
                                adult_score = int(metadata.get("adult", 0))
                                racy_score = int(metadata.get("racy", 0))
                                violence_score = int(metadata.get("violence", 0))
                                safety_level = metadata.get("safety_level", "")
                                voyeur_risk = metadata.get("voyeur_risk", "")
                                context_flag = metadata.get("context_flag", "")
                                skin_exposure = metadata.get("skin_exposure", "")
                                pose_type = metadata.get("pose_type", "")
                                framing = metadata.get("framing", "")
                                clothing_coverage = metadata.get("clothing_coverage", "")
                            except Exception as e:
                                errors.append(f"JSON read error {json_sidecar.name}: {e}")

                        # For images, also try EXIF
                        if file_type == "image" and ext in {".jpg", ".jpeg"}:
                            try:
                                exif_meta = self._read_exif_metadata(f)
                                if exif_meta:
                                    if exif_meta.get("tags"):
                                        tags = exif_meta["tags"]
                                    if exif_meta.get("description"):
                                        description = exif_meta["description"]
                                    if exif_meta.get("adult_score"):
                                        adult_score = exif_meta["adult_score"]
                                    if exif_meta.get("racy_score"):
                                        racy_score = exif_meta["racy_score"]
                                    if exif_meta.get("violence_score"):
                                        violence_score = exif_meta["violence_score"]
                                    if exif_meta.get("safety_level"):
                                        safety_level = exif_meta["safety_level"]
                                    if exif_meta.get("voyeur_risk"):
                                        voyeur_risk = exif_meta["voyeur_risk"]
                                    if exif_meta.get("context_flag"):
                                        context_flag = exif_meta["context_flag"]
                                    if exif_meta.get("skin_exposure"):
                                        skin_exposure = exif_meta["skin_exposure"]
                                    if exif_meta.get("pose_type"):
                                        pose_type = exif_meta["pose_type"]
                                    if exif_meta.get("framing"):
                                        framing = exif_meta["framing"]
                                    if exif_meta.get("clothing_coverage"):
                                        clothing_coverage = exif_meta["clothing_coverage"]
                                    metadata.update(exif_meta.get("_raw", {}))
                            except Exception as e:
                                errors.append(f"EXIF read error {f.name}: {e}")

                        # Insert into DB
                        try:
                            conn = self.db._get_conn()
                            conn.execute(
                                "INSERT OR REPLACE INTO asset_catalog "
                                "(filename, file_path, file_type, rating, collection, slot_number, "
                                "tags, description, adult_score, racy_score, violence_score, "
                                "safety_level, voyeur_risk, context_flag, skin_exposure, "
                                "pose_type, framing, clothing_coverage, metadata_json, "
                                "is_pushed, created_at, updated_at) "
                                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, "
                                "?, datetime('now'), datetime('now'))",
                                (
                                    f.name, str(f), file_type, rating, collection, slot_number,
                                    tags, description, adult_score, racy_score, violence_score,
                                    safety_level, voyeur_risk, context_flag, skin_exposure,
                                    pose_type, framing, clothing_coverage,
                                    json.dumps(metadata, ensure_ascii=False),
                                    1 if is_pushed else 0,
                                ),
                            )
                            conn.commit()
                            imported += 1
                        except Exception as e:
                            errors.append(f"DB insert error {f.name}: {e}")

        return {
            "ok": True,
            "imported": imported,
            "collections": len(collections_found),
            "collection_list": sorted(collections_found),
            "errors": errors[:50] if errors else [],
        }

    def _read_exif_metadata(self, image_path: Path) -> Optional[dict]:
        """Read EXIF metadata from a JPEG file. Returns parsed dict or None."""
        try:
            exif_dict = piexif.load(str(image_path))
            ifd = exif_dict.get("0th", {})
            result = {"_raw": {}}

            # XPKeywords (tags): 0x9C9E — UTF-16LE encoded
            raw = ifd.get(0x9C9E)
            if raw:
                if isinstance(raw, tuple):
                    raw = bytes(raw)
                try:
                    result["tags"] = raw.decode("utf-16le").rstrip("\x00")
                except Exception:
                    pass

            # ImageDescription: 0x010E — UTF-8 description
            raw = ifd.get(0x010E)
            if raw:
                if isinstance(raw, bytes):
                    result["description"] = raw.decode("utf-8", errors="replace").rstrip("\x00")
                elif isinstance(raw, str):
                    result["description"] = raw

            # XPSubject (ratings): 0x9C9F — pipe-delimited
            raw = ifd.get(0x9C9F)
            if raw:
                if isinstance(raw, tuple):
                    raw = bytes(raw)
                try:
                    subject_str = raw.decode("utf-16le").rstrip("\x00")
                    parts = {}
                    for pair in subject_str.split("|"):
                        if ":" in pair:
                            k, v = pair.split(":", 1)
                            parts[k.strip()] = v.strip()

                    result["_raw"].update(parts)
                    try:
                        result["adult_score"] = int(parts.get("adult", 0))
                    except (ValueError, TypeError):
                        pass
                    try:
                        result["racy_score"] = int(parts.get("racy", 0))
                    except (ValueError, TypeError):
                        pass
                    try:
                        result["violence_score"] = int(parts.get("violence", 0))
                    except (ValueError, TypeError):
                        pass
                    result["safety_level"] = parts.get("safety", "")
                    result["voyeur_risk"] = parts.get("voyeur", "")
                    result["context_flag"] = parts.get("context", "")
                    result["skin_exposure"] = parts.get("skin", "")
                    result["pose_type"] = parts.get("pose", "")
                    result["framing"] = parts.get("framing", "")
                except Exception:
                    pass

            # XPTitle (body/policy): 0x9C9B — pipe-delimited
            raw = ifd.get(0x9C9B)
            if raw:
                if isinstance(raw, tuple):
                    raw = bytes(raw)
                try:
                    title_str = raw.decode("utf-16le").rstrip("\x00")
                    parts = {}
                    for pair in title_str.split("|"):
                        if ":" in pair:
                            k, v = pair.split(":", 1)
                            parts[k.strip()] = v.strip()

                    result["_raw"].update(parts)
                    result["clothing_coverage"] = parts.get("coverage", "")
                except Exception:
                    pass

            return result if len(result) > 1 else None  # More than just _raw
        except Exception:
            return None

    def _create_catalog_records_for_accepted(
        self, col_folder: Path, rating: str, collection: str, slot_numbers: list[int]
    ):
        """Create asset_catalog records for files that were just accepted into a collection."""
        for num in slot_numbers:
            # Check for image
            for ext in self.IMAGE_EXTS:
                img_path = col_folder / f"{num}{ext}"
                if img_path.exists():
                    metadata = {}
                    tags = ""
                    description = ""
                    adult_score = 0
                    racy_score = 0
                    violence_score = 0
                    safety_level = ""
                    voyeur_risk = ""
                    context_flag = ""
                    skin_exposure = ""
                    pose_type = ""
                    framing = ""
                    clothing_coverage = ""

                    # Read from .json sidecar
                    json_sidecar = col_folder / f"{num}.json"
                    if json_sidecar.exists():
                        try:
                            with open(json_sidecar, "r", encoding="utf-8") as jf:
                                metadata = json.load(jf)
                            tags = metadata.get("tags", "")
                            if isinstance(tags, list):
                                tags = ", ".join(tags)
                            description = metadata.get("description", "")
                            adult_score = int(metadata.get("adult", 0))
                            racy_score = int(metadata.get("racy", 0))
                            violence_score = int(metadata.get("violence", 0))
                            safety_level = metadata.get("safety_level", "")
                            voyeur_risk = metadata.get("voyeur_risk", "")
                            context_flag = metadata.get("context_flag", "")
                            skin_exposure = metadata.get("skin_exposure", "")
                            pose_type = metadata.get("pose_type", "")
                            framing = metadata.get("framing", "")
                            clothing_coverage = metadata.get("clothing_coverage", "")
                        except Exception:
                            pass

                    # Read EXIF if jpeg
                    if ext in {".jpg", ".jpeg"}:
                        try:
                            exif_meta = self._read_exif_metadata(img_path)
                            if exif_meta:
                                if exif_meta.get("tags"):
                                    tags = exif_meta["tags"]
                                if exif_meta.get("description"):
                                    description = exif_meta["description"]
                                if exif_meta.get("adult_score"):
                                    adult_score = exif_meta["adult_score"]
                                if exif_meta.get("racy_score"):
                                    racy_score = exif_meta["racy_score"]
                                if exif_meta.get("violence_score"):
                                    violence_score = exif_meta["violence_score"]
                                if exif_meta.get("safety_level"):
                                    safety_level = exif_meta["safety_level"]
                                if exif_meta.get("voyeur_risk"):
                                    voyeur_risk = exif_meta["voyeur_risk"]
                                if exif_meta.get("context_flag"):
                                    context_flag = exif_meta["context_flag"]
                                if exif_meta.get("skin_exposure"):
                                    skin_exposure = exif_meta["skin_exposure"]
                                if exif_meta.get("pose_type"):
                                    pose_type = exif_meta["pose_type"]
                                if exif_meta.get("framing"):
                                    framing = exif_meta["framing"]
                                if exif_meta.get("clothing_coverage"):
                                    clothing_coverage = exif_meta["clothing_coverage"]
                        except Exception:
                            pass

                    try:
                        conn = self.db._get_conn()
                        conn.execute(
                            "INSERT OR REPLACE INTO asset_catalog "
                            "(filename, file_path, file_type, rating, collection, slot_number, "
                            "tags, description, adult_score, racy_score, violence_score, "
                            "safety_level, voyeur_risk, context_flag, skin_exposure, "
                            "pose_type, framing, clothing_coverage, metadata_json, "
                            "created_at, updated_at) "
                            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, "
                            "datetime('now'), datetime('now'))",
                            (
                                img_path.name, str(img_path), "image", rating, collection, num,
                                tags, description, adult_score, racy_score, violence_score,
                                safety_level, voyeur_risk, context_flag, skin_exposure,
                                pose_type, framing, clothing_coverage,
                                json.dumps(metadata, ensure_ascii=False),
                            ),
                        )
                        conn.commit()
                    except Exception as e:
                        print(f"[PipelineEngine] Catalog insert error for {img_path.name}: {e}")
                    break  # Only one image per slot

            # Check for video
            for ext in self.VIDEO_EXTS:
                vid_path = col_folder / f"{num}{ext}"
                if vid_path.exists():
                    metadata = {}
                    tags = ""
                    description = ""

                    # Read from video sidecar
                    vid_json = col_folder / f"{num}_vid.json"
                    if not vid_json.exists():
                        vid_json = col_folder / f"{num}.json"
                    if vid_json.exists():
                        try:
                            with open(vid_json, "r", encoding="utf-8") as jf:
                                metadata = json.load(jf)
                            tags = metadata.get("tags", "")
                            if isinstance(tags, list):
                                tags = ", ".join(tags)
                            description = metadata.get("description", "")
                        except Exception:
                            pass

                    try:
                        conn = self.db._get_conn()
                        conn.execute(
                            "INSERT OR REPLACE INTO asset_catalog "
                            "(filename, file_path, file_type, rating, collection, slot_number, "
                            "tags, description, metadata_json, "
                            "created_at, updated_at) "
                            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, "
                            "datetime('now'), datetime('now'))",
                            (
                                vid_path.name, str(vid_path), "video", rating, collection, num,
                                tags, description,
                                json.dumps(metadata, ensure_ascii=False),
                            ),
                        )
                        conn.commit()
                    except Exception as e:
                        print(f"[PipelineEngine] Catalog insert error for {vid_path.name}: {e}")
                    break  # Only one video per slot

    def _load_gemini_key(self) -> str:
        """Load Gemini API key from settings, Auto Game Builder MCP config, or environment."""
        # Try settings first
        key = self.settings.get("gemini_api_key", "")
        if key:
            return key

        # Try Auto Game Builder's gitignored mcp_servers.json
        mcp_config_path = _find_agb_mcp_servers_config()
        if mcp_config_path:
            try:
                with open(mcp_config_path, "r", encoding="utf-8") as f:
                    mcp = json.load(f)
                key = mcp.get("gemini", {}).get("_api_key", "")
                if key:
                    return key
            except Exception:
                pass

        # Try environment variable
        key = os.environ.get("GEMINI_API_KEY", "")
        if key:
            return key

        # Try a user_settings.json in the pipeline base directory
        if self._pipeline_base and self._pipeline_base.is_dir():
            settings_path = self._pipeline_base / "user_settings.json"
            try:
                if settings_path.exists():
                    with open(settings_path, "r", encoding="utf-8") as f:
                        data = json.load(f)
                    return data.get("gemini_api_key", "")
            except Exception:
                pass
        return ""
