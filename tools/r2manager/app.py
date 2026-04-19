"""
r2manager - minimal asset browser for the Jigsaw R2 buckets.

Browse the Downloads folder (new/incoming assets) and the two Pushed folders
(Hot Jigsaw = teen bucket, Kid Jigsaw = kid bucket). For any file: view
thumbnail, read EXIF metadata, play the paired mp4, open in Explorer.
"""

import os
import re
import sys
import json
import shutil
import hashlib
import subprocess
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import cv2
import numpy as np
import piexif
import tkinter as tk
from tkinter import ttk, messagebox
from PIL import Image, ImageTk

# EXIF writer lives in the sibling script — single source of truth for the format
sys.path.insert(0, str(Path(__file__).parent))
from exif_writer import write_exif  # noqa: E402


# Machine-local config lives in config.py (gitignored). See config.example.py
# for the template new users should copy.
try:
    from config import (  # noqa: F401
        DOWNLOADS,
        STAGING_ROOTS,
        PUSHED_ROOTS,
        BUCKET_BY_RATING,
        WRANGLER_BIN,
    )
except ImportError as e:
    raise SystemExit(
        "r2manager: config.py not found. Copy config.example.py to config.py "
        "and fill in your paths / bucket names.\n"
        f"(import error: {e})"
    )

PUSHED_BY_RATING = {
    "Teen": PUSHED_ROOTS["Hot Jigsaw (teen)"],
    "Kid":  PUSHED_ROOTS["Kid Jigsaw (kid)"],
}

IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp"}
VIDEO_EXTS = {".mp4", ".mov", ".avi", ".mkv", ".webm"}


def _parse_pipe_fields(raw) -> dict:
    """Decode a utf-16le `key:val|key:val|...` buffer into a dict."""
    if isinstance(raw, tuple):
        raw = bytes(raw)
    text = raw.decode("utf-16le").rstrip("\x00").strip()
    out = {}
    for part in text.split("|"):
        k, _, v = part.partition(":")
        if k:
            out[k.strip()] = v.strip()
    return out


def read_exif_metadata(path: Path) -> dict:
    """Read tags (0x9C9E), subject (0x9C9F), policy (0x9C9B), and description
    (0x9C9C / 0x010E) from image EXIF."""
    out = {"tags": "", "subject_fields": {}, "policy_fields": {}, "description": ""}
    if path.suffix.lower() not in {".jpg", ".jpeg"}:
        return out
    try:
        exif = piexif.load(str(path))
        zeroth = exif.get("0th", {})

        raw = zeroth.get(0x9C9E)  # XPKeywords
        if raw:
            if isinstance(raw, tuple):
                raw = bytes(raw)
            out["tags"] = raw.decode("utf-16le").rstrip("\x00").strip()

        raw = zeroth.get(0x9C9F)  # XPSubject — rating/camera/pose fields
        if raw:
            out["subject_fields"] = _parse_pipe_fields(raw)

        raw = zeroth.get(0x9C9B)  # XPTitle — policy/body/clothing fields
        if raw:
            out["policy_fields"] = _parse_pipe_fields(raw)

        # Description: prefer XPComment (0x9C9C, utf-16le), fall back to
        # ImageDescription (0x010E, utf-8).
        raw = zeroth.get(0x9C9C)
        if raw:
            if isinstance(raw, tuple):
                raw = bytes(raw)
            out["description"] = raw.decode("utf-16le").rstrip("\x00").strip()
        else:
            raw = zeroth.get(0x010E)
            if raw:
                if isinstance(raw, tuple):
                    raw = bytes(raw)
                out["description"] = raw.decode("utf-8", errors="replace").rstrip("\x00").strip()
    except Exception as e:
        out["error"] = str(e)
    return out


def read_video_sidecar(video_path: Path) -> dict:
    """Read the .json sidecar next to a video, if present."""
    sidecar = video_path.with_suffix(".json")
    if not sidecar.exists():
        return {}
    try:
        with open(sidecar, encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        return {"error": str(e)}


def find_paired_video(image_path: Path) -> Path | None:
    """Return the paired video (same stem, any video ext) if it exists."""
    for ext in VIDEO_EXTS:
        candidate = image_path.with_suffix(ext)
        if candidate.exists():
            return candidate
    return None


def extract_video_thumb(video_path: Path):
    """64x64 grayscale thumbnail of the first video frame (None on failure)."""
    try:
        cap = cv2.VideoCapture(str(video_path))
        if not cap.isOpened():
            return None
        ret, frame = cap.read()
        cap.release()
        if not ret:
            return None
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        return cv2.resize(gray, (64, 64))
    except Exception:
        return None


def extract_image_thumb(image_path: Path):
    """64x64 grayscale thumbnail of an image (None on failure)."""
    try:
        arr = np.fromfile(str(image_path), dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_GRAYSCALE)
        if img is None:
            return None
        return cv2.resize(img, (64, 64))
    except Exception:
        return None


def mse(a, b) -> float:
    diff = a.astype("float") - b.astype("float")
    return float(np.sum(diff * diff) / (a.shape[0] * a.shape[1]))


GEMINI_BIN = (
    shutil.which("gemini.cmd")
    or shutil.which("gemini")
    or "gemini"
)
CLAUDE_BIN = (
    shutil.which("claude.cmd")
    or shutil.which("claude")
    or "claude"
)
CODEX_BIN = (
    shutil.which("codex.cmd")
    or shutil.which("codex")
    or "codex"
)

# ElevenLabs key — loaded from gitignored config.py (or ELEVENLABS_API_KEY env var).
from config import ELEVENLABS_API_KEY  # noqa: E402


class LLMRateLimit(Exception):
    """Raised when an agent CLI output indicates a rate / quota limit hit."""


# Back-compat alias — earlier code raised this name.
GeminiRateLimit = LLMRateLimit

RATE_MARKERS = (
    "rate limit", "rate_limit", "rate-limit",
    "quota exceeded", "quota_exceeded",
    "resource_exhausted", "resource exhausted",
    "too many requests", "429",
    "daily limit", "usage limit",
)


def _check_rate_limit(text: str):
    low = text.lower()
    if any(m in low for m in RATE_MARKERS):
        raise LLMRateLimit(text[:400].strip() or "rate/quota limit")


def _extract_metadata_json(text: str) -> dict | None:
    """Find the last balanced {...} block with a 'tags' key and return it parsed."""
    matches = re.findall(r"\{(?:[^{}]|\{[^{}]*\})*\}", text, re.DOTALL)
    for raw in reversed(matches):
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict) and obj.get("tags"):
            return obj
    return None

def _build_tag_prompt(img_name: str) -> str:
    """Full-schema prompt matching the existing Hot Jigsaw - Pushed asset
    format 1:1. Windows cmd.exe mangles newlines in -p args, but this prompt
    is passed via stdin so multi-line is fine."""
    return (
        f'Analyze the image file "{img_name}" in the current directory.\n\n'
        'Output ONLY a single flat JSON object (no markdown, no code fences, no '
        'commentary). Use these exact keys:\n\n'
        '  "tags": string — 15-25 comma-separated keywords (subject/setting/style)\n'
        '  "description": string — 1 sentence\n'
        '  "adult": int 1-5 (1=fully clothed, 3=swimwear/lingerie, 5=nude)\n'
        '  "racy": int 1-5 (suggestiveness)\n'
        '  "violence": int 1-5\n'
        '  "rating": "kid" | "teen" | "adult"\n'
        '      Rule: "adult" only if adult>=3 OR racy>=4; "kid" only if adult<=1 AND '
        'racy<=1 AND violence<=1; otherwise "teen".\n'
        '  "safety_level": "safe" | "borderline" | "risky"\n'
        '  "camera_angle": e.g. "eye_level" | "low_angle" | "high_angle" | "over_shoulder"\n'
        '  "view_type": e.g. "frontal_view" | "back_view" | "side_view" | "three_quarter"\n'
        '  "pose_type": e.g. "neutral" | "suggestive" | "action" | "relaxed"\n'
        '  "framing": "full_body" | "upper_body" | "portrait" | "close_up"\n'
        '  "skin_exposure": "low" | "medium" | "high" | "very_high"\n'
        '  "mood": short free-form string (e.g. "elegant", "playful", "serious")\n'
        '  "voyeur_risk": "none" | "low" | "medium" | "high"\n'
        '  "context_flag": "ok" | "mismatch" (outfit vs setting)\n'
        '  "body_parts": array of strings (visible body parts like '
        '"cleavage","thighs","legs","arms","shoulders")\n'
        '  "clothing_coverage": "minimal" | "revealing" | "moderate" | "modest"\n'
        '  "clothing_fit": "loose" | "fitted" | "tight"\n'
        '  "clothing_type": array of strings (e.g. ["dress","evening gown"])\n'
        '  "art_style": array of strings (e.g. ["realistic","photorealistic"] or '
        '["anime","digital_art"])\n'
        '  "setting": array of strings (e.g. ["studio","urban","forest"])\n'
        '  "risk_factors": array of strings (e.g. ["cleavage","thigh_exposure",'
        '"suggestive_pose"]) — empty array [] if none\n'
        '  "visual_focus": array of strings (e.g. ["body","face","eyes"])\n'
        '  "policy_flags": array of strings (e.g. ["nudity","minor"]) — empty array [] if none\n\n'
        'Return ONLY the JSON object, no prose before or after.'
    )


def tag_image_via_gemini_cli(img_path: Path, timeout: int = 180) -> bool:
    """Invoke headless gemini, parse JSON from stdout, write EXIF via write_exif."""
    img_path = img_path.resolve()
    prompt = _build_tag_prompt(img_path.name)
    # Pass prompt via stdin — Windows cmd.exe mangles newlines in `-p <arg>`,
    # so stdin is the safe channel for multi-line prompts.
    try:
        proc = subprocess.run(
            [GEMINI_BIN, "-p", "", "-y", "-o", "text"],
            input=prompt,
            capture_output=True, text=True, timeout=timeout,
            cwd=str(img_path.parent),
            encoding="utf-8", errors="replace",
            creationflags=(subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0),
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False

    out = (proc.stdout or "") + "\n" + (proc.stderr or "")
    _check_rate_limit(out)
    meta = _extract_metadata_json(out)
    if not meta:
        return False
    try:
        write_exif(img_path, meta)
        return True
    except Exception as e:
        print(f"write_exif err on {img_path.name}: {e}")
        return False


def tag_image_via_claude_cli(img_path: Path, timeout: int = 180) -> bool:
    """Invoke Claude Code CLI headlessly. Output-format json wraps the response,
    but we still scan for a JSON object with 'tags' anywhere in the text.

    Prompt is fed via stdin — Windows cmd.exe strips newlines from -p <arg>,
    same bug we hit with Gemini."""
    img_path = img_path.resolve()
    prompt = _build_tag_prompt(img_path.name)
    try:
        # NOTE: intentionally NOT using --bare — it bypasses OAuth/keychain
        # and breaks Claude Max subscription auth ("Not logged in"). Trade the
        # leaner scaffolding for functional auth.
        proc = subprocess.run(
            [CLAUDE_BIN, "-p",
             "--output-format", "json",
             "--permission-mode", "bypassPermissions",
             "--add-dir", str(img_path.parent)],
            input=prompt,
            capture_output=True, text=True, timeout=timeout,
            cwd=str(img_path.parent),
            encoding="utf-8", errors="replace",
            creationflags=(subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0),
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False

    stdout = proc.stdout or ""
    stderr = proc.stderr or ""
    _check_rate_limit(stdout + "\n" + stderr)

    # Claude's --output-format json wraps the model's reply. Unpack first.
    payloads: list[str] = [stdout]
    try:
        wrapper = json.loads(stdout)
        if isinstance(wrapper, dict):
            inner = wrapper.get("result") or wrapper.get("response") or ""
            if inner:
                payloads.insert(0, inner)
    except json.JSONDecodeError:
        pass

    for payload in payloads:
        meta = _extract_metadata_json(payload)
        if meta:
            try:
                write_exif(img_path, meta)
                return True
            except Exception as e:
                print(f"write_exif err on {img_path.name}: {e}")
                return False
    return False


def tag_image_via_codex_cli(img_path: Path, timeout: int = 180) -> bool:
    """Invoke OpenAI Codex CLI headlessly. NOTE: if the Windows native dep
    (`@openai/codex-win32-x64`) is missing, codex crashes immediately — the
    stderr will carry the npm install hint and we raise a clear RuntimeError."""
    img_path = img_path.resolve()
    prompt = _build_tag_prompt(img_path.name)
    try:
        proc = subprocess.run(
            [CODEX_BIN, "exec", "--skip-git-repo-check", "-"],
            input=prompt,
            capture_output=True, text=True, timeout=timeout,
            cwd=str(img_path.parent),
            encoding="utf-8", errors="replace",
            creationflags=(subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0),
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False

    stdout = proc.stdout or ""
    stderr = proc.stderr or ""
    combined = stdout + "\n" + stderr
    _check_rate_limit(combined)

    # Surface the known Windows install breakage loudly
    if "@openai/codex-win32-x64" in combined or "Reinstall Codex" in combined:
        raise RuntimeError("Codex CLI is broken on this machine — run:\n  "
                           "npm install -g @openai/codex@latest")

    meta = _extract_metadata_json(combined)
    if not meta:
        return False
    try:
        write_exif(img_path, meta)
        return True
    except Exception as e:
        print(f"write_exif err on {img_path.name}: {e}")
        return False


AGENTS = {
    "Gemini": tag_image_via_gemini_cli,
    "Claude": tag_image_via_claude_cli,
    "Codex":  tag_image_via_codex_cli,
}


def tag_image(img_path: Path, agent: str, timeout: int = 180) -> bool:
    fn = AGENTS.get(agent, tag_image_via_gemini_cli)
    return fn(img_path, timeout)


def find_extra_videos(image_path: Path) -> list[Path]:
    """Return any -extra/-extraN video siblings."""
    parent = image_path.parent
    stem = image_path.stem
    extras = []
    for f in parent.iterdir():
        if not f.is_file() or f.suffix.lower() not in VIDEO_EXTS:
            continue
        if f.stem.startswith(f"{stem}-extra"):
            extras.append(f)
    extras.sort()
    return extras


class App:
    def __init__(self, root: tk.Tk):
        self.root = root
        root.title("R2 Manager")
        root.geometry("1400x850")

        self._thumb_ref = None
        self._current_path: Path | None = None
        self.rating_var = tk.StringVar(value="Teen")
        self.agent_var = tk.StringVar(value="Gemini")
        self._thumb_cache: dict[Path, ImageTk.PhotoImage] = {}  # keep refs alive

        self._build_ui()
        self.refresh_downloads()
        self.refresh_accepted()
        self.refresh_pushed()

    # ---------- UI layout ----------
    def _build_ui(self):
        # Top rating bar — scopes which pushed folder shows in the Pushed tab
        rating_bar = ttk.Frame(self.root)
        rating_bar.pack(fill="x", padx=6, pady=(6, 0))
        ttk.Label(rating_bar, text="Rating:", font=("TkDefaultFont", 10, "bold")).pack(side="left")
        for label in ("Teen", "Kid"):
            ttk.Radiobutton(
                rating_bar, text=f"{label} Rated", value=label,
                variable=self.rating_var,
                command=self._on_rating_change,
            ).pack(side="left", padx=(8, 0))
        ttk.Separator(self.root, orient="horizontal").pack(fill="x", pady=(6, 0))

        nb = ttk.Notebook(self.root)
        nb.pack(fill="both", expand=True)

        # Downloads tab
        self.downloads_tab = ttk.Frame(nb)
        nb.add(self.downloads_tab, text="Downloads")
        self._build_downloads_tab(self.downloads_tab)

        # Accepted tab (between Downloads and Pushed)
        self.accepted_tab = ttk.Frame(nb)
        nb.add(self.accepted_tab, text="Accepted")
        self._build_collection_tab(self.accepted_tab, kind="accepted")

        # Pushed tab
        self.pushed_tab = ttk.Frame(nb)
        nb.add(self.pushed_tab, text="Pushed")
        self._build_collection_tab(self.pushed_tab, kind="pushed")

    def _build_downloads_tab(self, parent):
        paned = ttk.Panedwindow(parent, orient="horizontal")
        paned.pack(fill="both", expand=True)

        # left: file list
        left = ttk.Frame(paned)
        paned.add(left, weight=2)

        top_bar = ttk.Frame(left)
        top_bar.pack(fill="x", padx=4, pady=4)
        ttk.Label(top_bar, text=str(DOWNLOADS)).pack(side="left")
        ttk.Button(top_bar, text="Refresh", command=self.refresh_downloads).pack(side="right")
        ttk.Button(top_bar, text="Match Videos", command=self.match_videos).pack(side="right", padx=(0, 4))
        ttk.Button(top_bar, text="AI Tag", command=self.ai_tag).pack(side="right", padx=(0, 4))
        ttk.Button(top_bar, text="Tag Selected", command=self.ai_tag_selected).pack(side="right", padx=(0, 4))
        agent_box = ttk.Combobox(
            top_bar, textvariable=self.agent_var,
            values=list(AGENTS.keys()), width=9, state="readonly",
        )
        agent_box.pack(side="right", padx=(0, 4))
        ttk.Label(top_bar, text="Agent:").pack(side="right", padx=(6, 2))

        # Accept / Reject / Search row
        action_bar = ttk.Frame(left)
        action_bar.pack(fill="x", padx=4, pady=(0, 4))
        ttk.Label(action_bar, text="Collection:").pack(side="left")
        self.collection_var = tk.StringVar()
        ttk.Entry(action_bar, textvariable=self.collection_var, width=28).pack(side="left", padx=(4, 8))
        ttk.Button(action_bar, text="Accept →", command=self.accept_selected).pack(side="left")
        ttk.Button(action_bar, text="Reject ✕", command=self.reject_selected).pack(side="left", padx=(4, 0))

        ttk.Label(action_bar, text="  Search tags:").pack(side="left", padx=(12, 2))
        self.search_var = tk.StringVar()
        search_entry = ttk.Entry(action_bar, textvariable=self.search_var, width=24)
        search_entry.pack(side="left")
        search_entry.bind("<KeyRelease>", lambda _e: self._render_dl_tree())
        ttk.Button(action_bar, text="✕", width=3,
                   command=lambda: (self.search_var.set(""), self._render_dl_tree())).pack(side="left", padx=(2, 0))

        cols = ("name", "video", "rating", "adult", "racy", "voyeur", "ctx")
        self.dl_tree = ttk.Treeview(left, columns=cols, show="tree headings")
        self.dl_tree.heading("#0", text="")
        self.dl_tree.column("#0", width=56, stretch=False)
        headers = {"name": "File", "video": "Vid", "rating": "Rating", "adult": "A", "racy": "R", "voyeur": "Voy", "ctx": "!"}
        widths = {"name": 220, "video": 40, "rating": 70, "adult": 30, "racy": 30, "voyeur": 60, "ctx": 30}
        for c in cols:
            self.dl_tree.heading(c, text=headers[c])
            self.dl_tree.column(c, width=widths[c], anchor="w")
        # Taller rows so the 48px thumbnail fits
        style = ttk.Style()
        style.configure("dl.Treeview", rowheight=52)
        self.dl_tree.configure(style="dl.Treeview")
        ysb = ttk.Scrollbar(left, orient="vertical", command=self.dl_tree.yview)
        self.dl_tree.configure(yscrollcommand=ysb.set)
        self.dl_tree.pack(side="left", fill="both", expand=True)
        ysb.pack(side="right", fill="y")
        self.dl_tree.bind("<<TreeviewSelect>>", self._on_dl_select)
        self.dl_tree.bind("<Double-1>", lambda e: self._play_video())

        # right: preview + metadata
        right = self._build_preview_pane(paned)
        paned.add(right, weight=3)

    def _build_collection_tab(self, parent, kind: str):
        """Build a tab that lists collections under rating-scoped roots.
        kind: 'accepted' (STAGING_ROOTS) or 'pushed' (PUSHED_ROOTS)."""
        paned = ttk.Panedwindow(parent, orient="horizontal")
        paned.pack(fill="both", expand=True)

        left = ttk.Frame(paned)
        paned.add(left, weight=2)

        refresh_fn = self.refresh_accepted if kind == "accepted" else self.refresh_pushed
        header_text = "Accepted collections (pre-push)" if kind == "accepted" else "Pushed collections"
        top_bar = ttk.Frame(left)
        top_bar.pack(fill="x", padx=4, pady=4)
        ttk.Label(top_bar, text=header_text).pack(side="left")
        ttk.Button(top_bar, text="Refresh", command=refresh_fn).pack(side="right")
        if kind == "accepted":
            ttk.Button(top_bar, text="Push to R2", command=self.push_all).pack(side="right", padx=(0, 4))
            ttk.Button(top_bar, text="Generate Music", command=self.generate_music_selected).pack(side="right", padx=(0, 4))

        tree = ttk.Treeview(left, columns=("rating",), show="tree headings")
        tree.heading("#0", text="Collection / File")
        tree.heading("rating", text="Rating")
        tree.column("#0", width=320)
        tree.column("rating", width=100)
        ysb = ttk.Scrollbar(left, orient="vertical", command=tree.yview)
        tree.configure(yscrollcommand=ysb.set)
        tree.pack(side="left", fill="both", expand=True)
        ysb.pack(side="right", fill="y")
        if kind == "accepted":
            self.accepted_tree = tree
            style = ttk.Style()
            style.configure("accepted.Treeview", rowheight=52)
            tree.configure(style="accepted.Treeview")
            tree.bind("<<TreeviewSelect>>", self._on_accepted_select)
        else:
            self.pushed_tree = tree
            tree.bind("<<TreeviewSelect>>", self._on_pushed_select)
        tree.bind("<Double-1>", lambda e: self._play_video())

        right = self._build_preview_pane(paned, kind=kind)
        paned.add(right, weight=3)

    def _build_preview_pane(self, parent, kind: str = "downloads"):
        frame = ttk.Frame(parent)

        preview_label = tk.Label(frame, bg="#222", text="(select a file)", fg="#888")
        preview_label.pack(fill="both", expand=True, padx=4, pady=4)

        btn_bar = ttk.Frame(frame)
        btn_bar.pack(fill="x", padx=4, pady=2)
        ttk.Button(btn_bar, text="Play Video", command=self._play_video).pack(side="left")
        ttk.Button(btn_bar, text="Open Folder", command=self._open_folder).pack(side="left", padx=(4, 0))
        extras_btn = ttk.Menubutton(btn_bar, text="Extras")
        extras_btn.pack(side="left", padx=(4, 0))
        extras_menu = tk.Menu(extras_btn, tearoff=0)
        extras_btn["menu"] = extras_menu

        ttk.Label(frame, text="Metadata").pack(anchor="w", padx=4, pady=(6, 0))
        meta_frame = ttk.Frame(frame)
        meta_frame.pack(fill="both", expand=False, padx=4, pady=4)
        meta_text = tk.Text(meta_frame, height=18, wrap="word", font=("Consolas", 9))
        meta_sb = ttk.Scrollbar(meta_frame, orient="vertical", command=meta_text.yview)
        meta_text.configure(yscrollcommand=meta_sb.set)
        meta_text.pack(side="left", fill="both", expand=True)
        meta_sb.pack(side="right", fill="y")

        if kind == "pushed":
            self._pushed_preview = preview_label
            self._pushed_meta = meta_text
            self._pushed_extras_menu = extras_menu
            self._pushed_extras_btn = extras_btn
        elif kind == "accepted":
            self._accepted_preview = preview_label
            self._accepted_meta = meta_text
            self._accepted_extras_menu = extras_menu
            self._accepted_extras_btn = extras_btn
        else:
            self._dl_preview = preview_label
            self._dl_meta = meta_text
            self._dl_extras_menu = extras_menu
            self._dl_extras_btn = extras_btn

        return frame

    # ---------- Refresh ----------
    def refresh_downloads(self):
        """Scan disk, cache per-image metadata, then render (respecting filter)."""
        # Flush the thumbnail cache — files may have been renamed (Match
        # Videos, Accept, Reject), and the cache key is the Path, which a
        # renamed-into file reuses while carrying new content.
        self._thumb_cache.clear()
        self._dl_paths: dict[str, Path] = {}
        self._dl_rows: list[tuple[Path, tuple, str]] = []  # (path, row-values, searchable-text)
        if not DOWNLOADS.exists():
            self._render_dl_tree()
            return
        images = [p for p in DOWNLOADS.iterdir()
                  if p.is_file() and p.suffix.lower() in IMAGE_EXTS]

        def sort_key(p: Path):
            stem = p.stem.split("-")[0]
            return (0, int(stem), p.stem) if stem.isdigit() else (1, 0, p.stem)
        images.sort(key=sort_key)

        for img in images:
            meta = read_exif_metadata(img)
            subj = meta.get("subject_fields", {})
            has_vid = "Y" if find_paired_video(img) else "-"
            row = (
                img.name,
                has_vid,
                subj.get("rating", "-"),
                subj.get("adult", "-"),
                subj.get("racy", "-"),
                subj.get("voyeur", "-") if subj.get("voyeur", "").lower() not in ("", "none") else "-",
                "!" if subj.get("context", "").lower() == "mismatch" else "-",
            )
            searchable = (meta.get("tags", "") or "").lower()
            self._dl_rows.append((img, row, searchable))
        self._render_dl_tree()

    def _thumb_for(self, path: Path, size: int = 48) -> ImageTk.PhotoImage | None:
        """Return a cached 48px PhotoImage thumbnail (builds on first miss)."""
        cached = self._thumb_cache.get(path)
        if cached is not None:
            return cached
        try:
            with Image.open(path) as im:
                im.thumbnail((size, size))
                tk_img = ImageTk.PhotoImage(im.copy())
        except Exception:
            return None
        self._thumb_cache[path] = tk_img
        return tk_img

    def _render_dl_tree(self):
        """Rebuild the Downloads tree, applying the search-tags filter."""
        self.dl_tree.delete(*self.dl_tree.get_children())
        self._dl_paths.clear()
        query = (self.search_var.get() if hasattr(self, "search_var") else "").strip().lower()
        # Split on whitespace/commas — all terms must appear in tag text (AND)
        terms = [t for t in re.split(r"[\s,]+", query) if t]
        for path, row, searchable in self._dl_rows:
            if terms and not all(t in searchable for t in terms):
                continue
            thumb = self._thumb_for(path)
            kwargs = {"values": row}
            if thumb is not None:
                kwargs["image"] = thumb
            iid = self.dl_tree.insert("", "end", **kwargs)
            self._dl_paths[iid] = path

    def _on_rating_change(self):
        self.refresh_accepted()
        self.refresh_pushed()

    def _current_pushed_roots(self) -> dict[str, Path]:
        """Filter PUSHED_ROOTS to only the currently-selected rating."""
        rating = self.rating_var.get()
        if rating == "Teen":
            return {k: v for k, v in PUSHED_ROOTS.items() if "Hot Jigsaw" in k}
        if rating == "Kid":
            return {k: v for k, v in PUSHED_ROOTS.items() if "Kid Jigsaw" in k}
        return PUSHED_ROOTS

    def _current_accepted_roots(self) -> dict[str, Path]:
        """STAGING_ROOTS scoped to the selected rating."""
        rating = self.rating_var.get()
        return {rating: v for k, v in STAGING_ROOTS.items() if k == rating}

    def _populate_collection_tree(self, tree, roots: dict, paths: dict):
        """Populate a tree with `{label: root_path} -> collections -> files`."""
        tree.delete(*tree.get_children())
        paths.clear()
        for label, root in roots.items():
            if not root.exists():
                continue
            root_iid = tree.insert("", "end", text=label, values=(label,), open=True)
            collections = sorted([p for p in root.iterdir() if p.is_dir()],
                                 key=lambda p: p.name.lower())
            for coll in collections:
                images = [p for p in coll.iterdir()
                          if p.is_file() and p.suffix.lower() in IMAGE_EXTS]

                def sort_key(p: Path):
                    stem = p.stem.split("-")[0]
                    return (0, int(stem), p.stem) if stem.isdigit() else (1, 0, p.stem)
                images.sort(key=sort_key)

                coll_iid = tree.insert(
                    root_iid, "end", text=f"{coll.name}  ({len(images)})",
                    values=(label,), open=False)
                for img in images:
                    iid = tree.insert(coll_iid, "end", text=img.name, values=(label,))
                    paths[iid] = img

    def refresh_pushed(self):
        if not hasattr(self, "_pushed_paths"):
            self._pushed_paths = {}
        self._populate_collection_tree(
            self.pushed_tree, self._current_pushed_roots(), self._pushed_paths)

    def _collection_readiness(self, coll: Path) -> dict:
        """Count images/videos/music in a collection folder. Skips -extra videos."""
        imgs = vids = music = 0
        for p in coll.iterdir():
            if not p.is_file():
                continue
            ext = p.suffix.lower()
            stem = p.stem
            if ext in IMAGE_EXTS and stem.split("-")[0].isdigit():
                imgs += 1
            elif ext in VIDEO_EXTS and "-extra" not in stem:
                vids += 1
            elif ext == ".mp3":
                music += 1
        return {
            "imgs": imgs, "vids": vids, "music": music,
            "is_generic": coll.name.lower() == "generic",
        }

    def _readiness_label(self, stats: dict) -> str:
        """Count display, shown in the Accepted tree. No pass/fail gate —
        Push uploads whatever is there."""
        if stats["imgs"] == 0 and stats["vids"] == 0 and stats["music"] == 0:
            return "  [empty]"
        if stats["is_generic"]:
            return f"  [{stats['imgs']} img, {stats['vids']} vid]"
        return (f"  [{stats['imgs']} img, {stats['vids']} vid, "
                f"{stats['music']} mp3]")

    def refresh_accepted(self):
        if not hasattr(self, "_accepted_paths"):
            self._accepted_paths = {}
        # Thumb cache invalidation: Accept moves files, filenames reused later.
        self._thumb_cache.clear()
        self.accepted_tree.delete(*self.accepted_tree.get_children())
        self._accepted_paths.clear()
        for label, root in self._current_accepted_roots().items():
            if not root.exists():
                continue
            root_iid = self.accepted_tree.insert(
                "", "end", text=label, values=(label,), open=True)
            collections = sorted([p for p in root.iterdir() if p.is_dir()],
                                 key=lambda p: p.name.lower())
            for coll in collections:
                stats = self._collection_readiness(coll)
                readiness = self._readiness_label(stats)
                images = [p for p in coll.iterdir()
                          if p.is_file() and p.suffix.lower() in IMAGE_EXTS]

                def sort_key(p: Path):
                    stem = p.stem.split("-")[0]
                    return (0, int(stem), p.stem) if stem.isdigit() else (1, 0, p.stem)
                images.sort(key=sort_key)

                coll_iid = self.accepted_tree.insert(
                    root_iid, "end",
                    text=f"{coll.name}{readiness}",
                    values=(label,), open=False)
                for img in images:
                    thumb = self._thumb_for(img)
                    kwargs = {"text": img.name, "values": (label,)}
                    if thumb is not None:
                        kwargs["image"] = thumb
                    iid = self.accepted_tree.insert(coll_iid, "end", **kwargs)
                    self._accepted_paths[iid] = img

    # ---------- Selection ----------
    def _on_dl_select(self, _event):
        sel = self.dl_tree.selection()
        if not sel:
            return
        path = self._dl_paths.get(sel[0])
        if path:
            self._show_file(path, self._dl_preview, self._dl_meta,
                            self._dl_extras_btn, self._dl_extras_menu)

    def _on_pushed_select(self, _event):
        sel = self.pushed_tree.selection()
        if not sel:
            return
        path = self._pushed_paths.get(sel[0])
        if not path:
            self._current_path = None
            return
        self._show_file(path, self._pushed_preview, self._pushed_meta,
                        self._pushed_extras_btn, self._pushed_extras_menu)

    def _on_accepted_select(self, _event):
        sel = self.accepted_tree.selection()
        if not sel:
            return
        path = self._accepted_paths.get(sel[0])
        if not path:
            self._current_path = None
            return
        self._show_file(path, self._accepted_preview, self._accepted_meta,
                        self._accepted_extras_btn, self._accepted_extras_menu)

    def _show_file(self, path: Path, preview_label, meta_text, extras_btn, extras_menu):
        self._current_path = path

        # thumbnail
        try:
            img = Image.open(path)
            img.thumbnail((640, 640))
            tk_img = ImageTk.PhotoImage(img)
            img.close()
            preview_label.configure(image=tk_img, text="")
            preview_label.image = tk_img  # prevent GC
        except Exception as e:
            preview_label.configure(image="", text=f"(preview failed: {e})")
            preview_label.image = None

        # metadata
        meta_text.delete("1.0", "end")
        meta_text.insert("end", f"Path: {path}\n")
        meta_text.insert("end", f"Size: {path.stat().st_size/1024:.1f} KB\n\n")

        exif = read_exif_metadata(path)
        if exif.get("description"):
            meta_text.insert("end", f"Description:\n  {exif['description']}\n\n")
        if exif.get("tags"):
            meta_text.insert("end", f"Tags:\n  {exif['tags']}\n\n")
        if exif.get("subject_fields"):
            meta_text.insert("end", "Subject fields:\n")
            for k, v in exif["subject_fields"].items():
                meta_text.insert("end", f"  {k}: {v}\n")
            meta_text.insert("end", "\n")
        if exif.get("policy_fields"):
            meta_text.insert("end", "Policy fields:\n")
            for k, v in exif["policy_fields"].items():
                meta_text.insert("end", f"  {k}: {v}\n")
            meta_text.insert("end", "\n")

        vid = find_paired_video(path)
        if vid:
            meta_text.insert("end", f"Paired video: {vid.name}\n")
            sidecar = read_video_sidecar(vid)
            if sidecar:
                meta_text.insert("end", "Video sidecar:\n")
                for k, v in sidecar.items():
                    meta_text.insert("end", f"  {k}: {v}\n")
        else:
            meta_text.insert("end", "No paired video.\n")

        # Extras menu — only the -extra/-extraN videos (primary handled by Play Video)
        extras_menu.delete(0, "end")
        extras = find_extra_videos(path)
        if extras:
            for v in extras:
                extras_menu.add_command(
                    label=v.name,
                    command=lambda p=v: os.startfile(str(p)))  # noqa
            extras_btn.state(["!disabled"])
        else:
            extras_btn.state(["disabled"])

    # ---------- Actions ----------
    def _play_video(self):
        if not self._current_path:
            return
        vid = find_paired_video(self._current_path)
        if vid:
            os.startfile(str(vid))  # noqa

    def _open_folder(self):
        if not self._current_path:
            return
        os.startfile(str(self._current_path.parent))  # noqa

    # ---------- Match Videos ----------
    def match_videos(self):
        if not DOWNLOADS.exists():
            messagebox.showerror("Match Videos", f"Downloads folder not found: {DOWNLOADS}")
            return
        if getattr(self, "_match_running", False):
            return
        self._match_running = True

        win = tk.Toplevel(self.root)
        win.title("Matching Videos (Downloads)")
        win.geometry("720x480")
        win.transient(self.root)

        bar_frame = ttk.Frame(win)
        bar_frame.pack(fill="x", padx=4, pady=(4, 0))
        pbar = ttk.Progressbar(bar_frame, mode="determinate", length=200)
        pbar.pack(side="left", fill="x", expand=True)
        status_var = tk.StringVar(value="Starting...")
        ttk.Label(bar_frame, textvariable=status_var, width=22, anchor="e").pack(side="right", padx=(6, 0))

        log_frame = ttk.Frame(win)
        log_frame.pack(fill="both", expand=True, padx=4, pady=4)
        log_text = tk.Text(log_frame, wrap="word", font=("Consolas", 9))
        log_sb = ttk.Scrollbar(log_frame, orient="vertical", command=log_text.yview)
        log_text.configure(yscrollcommand=log_sb.set)
        log_text.pack(side="left", fill="both", expand=True)
        log_sb.pack(side="right", fill="y")

        cancel = {"flag": False}
        btn = ttk.Button(win, text="Cancel", command=lambda: cancel.update(flag=True))
        btn.pack(side="bottom", pady=4)

        def log(msg):
            self.root.after(0, lambda: (log_text.insert("end", msg + "\n"), log_text.see("end")))

        def set_progress(done, total, status=None):
            def apply():
                pbar.configure(maximum=max(total, 1), value=done)
                if status is not None:
                    status_var.set(status)
            self.root.after(0, apply)

        def worker():
            try:
                summary = self._do_match(log, set_progress, lambda: cancel["flag"])
            except Exception as e:
                log(f"ERROR: {e}")
                summary = None
            finally:
                self._match_running = False

            def finish():
                if summary:
                    messagebox.showinfo("Match Videos", summary, parent=win)
                btn.configure(text="Close", command=win.destroy)
                self.refresh_downloads()
            self.root.after(0, finish)

        threading.Thread(target=worker, daemon=True).start()

    def _do_match(self, log, set_progress, cancelled) -> str | None:
        # Step 1: byte-exact dedupe of image files only (videos left alone —
        # user handles video dupes manually).
        log("Step 1: Byte-exact dedupe of images...")
        seen: dict[tuple[int, str], Path] = {}  # (size, full-file-sha256) -> path
        removed = 0
        img_files = [x for x in DOWNLOADS.iterdir()
                     if x.is_file() and x.suffix.lower() in IMAGE_EXTS]
        for p in img_files:
            if cancelled():
                return "Cancelled."
            try:
                size = p.stat().st_size
                h = hashlib.sha256()
                with open(p, "rb") as f:
                    for block in iter(lambda: f.read(1024 * 1024), b""):
                        h.update(block)
                key = (size, h.hexdigest())
                if key in seen:
                    log(f"  duplicate removed: {p.name}  (matches {seen[key].name})")
                    p.unlink()
                    removed += 1
                else:
                    seen[key] = p
            except Exception as e:
                log(f"  dedupe err {p.name}: {e}")

        # Step 2: extract thumbs in parallel
        log("Step 2: Extracting thumbnails...")
        videos = [p for p in DOWNLOADS.iterdir() if p.is_file() and p.suffix.lower() in VIDEO_EXTS]
        images = [p for p in DOWNLOADS.iterdir() if p.is_file() and p.suffix.lower() in IMAGE_EXTS]

        def sort_key(p: Path):
            return (0, int(p.stem)) if p.stem.isdigit() else (1, p.stem)
        images.sort(key=sort_key)

        log(f"  videos: {len(videos)}   images: {len(images)}")

        video_thumbs: dict = {}
        image_thumbs: dict = {}
        total_extract = len(videos) + len(images)
        extracted = 0
        set_progress(0, total_extract, "Extracting thumbs")
        with ThreadPoolExecutor(max_workers=8) as ex:
            video_futures = {ex.submit(extract_video_thumb, v): v for v in videos}
            for fut in as_completed(video_futures):
                if cancelled():
                    return "Cancelled."
                vid = video_futures[fut]
                thumb = fut.result()
                if thumb is not None:
                    video_thumbs[vid] = thumb
                extracted += 1
                set_progress(extracted, total_extract, f"Thumbs {extracted}/{total_extract}")
            image_futures = {ex.submit(extract_image_thumb, i): i for i in images}
            for fut in as_completed(image_futures):
                if cancelled():
                    return "Cancelled."
                img = image_futures[fut]
                thumb = fut.result()
                if thumb is not None:
                    image_thumbs[img] = thumb
                extracted += 1
                set_progress(extracted, total_extract, f"Thumbs {extracted}/{total_extract}")

        log(f"  extracted {len(video_thumbs)} video thumbs, {len(image_thumbs)} image thumbs")

        # Step 3: match
        # Each video's first frame == its source image (AI-gen pipeline guarantees this),
        # so real matches have MSE near 0. Threshold kept tight to reject coincidences.
        # Algorithm:
        #   Phase A - build every (img, vid, err) pair under threshold.
        #   Phase B - globally-optimal primary pairing: sort pairs by err asc;
        #             each img gets its BEST still-free vid. This ensures a vid goes
        #             to its tightest-matching image, so videoless images never lose
        #             a vid to a better-off image's extras.
        #   Phase C - remaining unclaimed vids become extras for the claimed image
        #             they match best (err-sorted).
        log("Step 3: Matching...")
        # Old pipeline used 2000 and worked well. Real pairs have MSE ~0-50
        # untouched / 200-500 after tag re-encoding. Unrelated 64x64 grayscale
        # content typically lands at 1000+. 2000 gives clean separation without
        # dropping tag-damaged real pairs.
        threshold = 2000
        weak_threshold = 100  # above this = suspicious, log as warning
        sorted_imgs = sorted(image_thumbs.keys(), key=sort_key)
        total_pairs = len(sorted_imgs) * max(len(video_thumbs), 1)
        set_progress(0, total_pairs, "Scoring pairs")

        all_pairs: list[tuple[Path, Path, float]] = []
        scanned = 0
        for img in sorted_imgs:
            if cancelled():
                return "Cancelled."
            it = image_thumbs[img]
            for vid, vt in video_thumbs.items():
                err = mse(vt, it)
                if err < threshold:
                    all_pairs.append((img, vid, err))
            scanned += len(video_thumbs)
            set_progress(scanned, total_pairs, f"Scoring {scanned}/{total_pairs}")

        # Phase B: primary (best err wins globally). Every run starts from
        # scratch — the sorted (img, vid, err) pairs drive the assignment, no
        # pre-locking based on filenames.
        all_pairs.sort(key=lambda t: t[2])
        primary: dict[Path, Path] = {}
        claimed: set[Path] = set()
        for img, vid, _err in all_pairs:
            if img in primary or vid in claimed:
                continue
            primary[img] = vid
            claimed.add(vid)

        # Phase C: extras — unclaimed vids go to their best primary-holder match
        extras: dict[Path, list[tuple[Path, float]]] = {}
        for img, vid, err in all_pairs:  # still sorted by err asc
            if vid in claimed:
                continue
            if img not in primary:
                # img was orphan and has no other pair either — skip
                continue
            extras.setdefault(img, []).append((vid, err))
            claimed.add(vid)

        # Build the match list in image order. Record err for the primary
        # (look it up from all_pairs) so we can flag weak matches.
        primary_err: dict[Path, float] = {}
        for img, vid, err in all_pairs:
            if primary.get(img) == vid and img not in primary_err:
                primary_err[img] = err

        matches: list[tuple[Path, list[tuple[Path, float]]]] = []
        orphans: list[Path] = []
        weak = 0
        for img in images:
            if img in primary:
                hits = [(primary[img], primary_err.get(img, 0.0))] + extras.get(img, [])
                matches.append((img, hits))
                if primary_err.get(img, 0.0) > weak_threshold:
                    weak += 1
                    log(f"  ! weak match: {img.name} <-> {primary[img].name} (err={primary_err[img]:.0f})")
            else:
                orphans.append(img)

        log(f"  {len(matches)} image matches ({sum(len(v) for _, v in matches)} videos), {len(orphans)} orphans, {weak} weak")

        # Step 4: rename via temp dir to avoid collisions
        log("Step 4: Renaming...")
        temp_dir = DOWNLOADS / "_temp_sorting"
        if temp_dir.exists():
            shutil.rmtree(temp_dir, ignore_errors=True)
        temp_dir.mkdir()

        current = 1
        matched_count = 0
        extras_count = 0

        def move_image_to(img: Path, dest: Path):
            if img.suffix.lower() != ".jpg":
                with Image.open(img) as im:
                    if im.mode != "RGB":
                        im = im.convert("RGB")
                    im.save(dest, quality=95)
                try:
                    img.unlink()
                except Exception:
                    pass
            else:
                shutil.move(str(img), str(dest))

        for img, hits in matches:
            dest_img = temp_dir / f"{current}.jpg"
            try:
                move_image_to(img, dest_img)
            except Exception as e:
                log(f"  img err: {e}")

            for vi, (vid, _err) in enumerate(hits):
                if vi == 0:
                    dest_vid = temp_dir / f"{current}.mp4"
                    matched_count += 1
                else:
                    suffix = "" if vi == 1 else str(vi)
                    dest_vid = temp_dir / f"{current}-extra{suffix}.mp4"
                    extras_count += 1
                try:
                    shutil.move(str(vid), str(dest_vid))
                    log(f"  {current}. {img.name} <-> {vid.name} -> {dest_vid.name}")
                except Exception as e:
                    log(f"  vid err: {e}")

                sidecar = vid.with_suffix(".json")
                if sidecar.exists():
                    try:
                        shutil.move(str(sidecar), str(dest_vid.with_suffix(".json")))
                    except Exception:
                        pass
            current += 1

        for img in orphans:
            dest_img = temp_dir / f"{current}.jpg"
            try:
                move_image_to(img, dest_img)
            except Exception as e:
                log(f"  img err: {e}")
            current += 1

        # Step 4c: rename leftover (unclaimed) videos to orphan_N.mp4 so they
        # can't collide with the numeric scheme used for matched/orphan images.
        unclaimed_videos = [v for v in videos if v not in claimed]
        orphan_vid_count = 0
        if unclaimed_videos:
            log(f"Step 4c: {len(unclaimed_videos)} unmatched video(s) → orphan_N.mp4")
            for idx, v in enumerate(unclaimed_videos, start=1):
                dest_vid = temp_dir / f"orphan_{idx}{v.suffix.lower()}"
                try:
                    shutil.move(str(v), str(dest_vid))
                    orphan_vid_count += 1
                except Exception as e:
                    log(f"  orphan vid err {v.name}: {e}")
                    continue
                # Keep sidecar json with the video
                sidecar = v.with_suffix(".json")
                if sidecar.exists():
                    try:
                        shutil.move(str(sidecar), str(dest_vid.with_suffix(".json")))
                    except Exception:
                        pass

        # Step 5: move everything back
        log("Step 5: Restoring files...")
        for p in temp_dir.iterdir():
            dest = DOWNLOADS / p.name
            if dest.exists():
                try:
                    dest.unlink()
                except Exception:
                    pass
            shutil.move(str(p), str(dest))
        try:
            temp_dir.rmdir()
        except Exception:
            pass

        return (
            f"Done.\n"
            f"Duplicates removed: {removed}\n"
            f"Matched pairs: {matched_count}\n"
            f"Extra videos: {extras_count}\n"
            f"Orphan videos renamed: {orphan_vid_count}\n"
            f"Total renamed: {current - 1}"
        )


    # ---------- Accept / Reject ----------
    def _current_staging_root(self) -> Path | None:
        """Resolve the staging (accept target) root for the selected rating."""
        return STAGING_ROOTS.get(self.rating_var.get())

    def _resolve_collection_folder(self, staging_root: Path, requested: str) -> tuple[Path, bool, bool]:
        """Map the user's typed name to a real folder under staging_root.

        Returns (folder_path, exists_already, is_generic). The returned folder
        may not exist yet (caller creates it); `exists_already` reflects the
        pre-call state.
        """
        name = requested.strip()
        is_generic = (name == "" or name.lower() == "generic")
        if is_generic:
            target = staging_root / "Generic"
            return target, target.exists(), True

        # Case-insensitive match against existing dirs so typos like
        # "Air_Wizard" vs "air_wizard" don't create duplicates
        if staging_root.exists():
            for existing in staging_root.iterdir():
                if existing.is_dir() and existing.name.lower() == name.lower():
                    return existing, True, False
        return staging_root / name, False, False

    def _paired_pushed_folder(self, accepted_coll: Path) -> Path | None:
        """Given an accepted collection folder, return the sibling `- Pushed`
        collection folder (or None if no rating match)."""
        staging_root = accepted_coll.parent
        for rating, sroot in STAGING_ROOTS.items():
            if sroot == staging_root:
                return PUSHED_BY_RATING[rating] / accepted_coll.name
        return None

    def _next_number(self, folder: Path) -> int:
        """Next free slot number — scans BOTH the accepted folder and its
        pushed twin, so Generic numbering stays globally unique across R2."""
        nums: list[int] = []
        for f in (folder, self._paired_pushed_folder(folder)):
            if not f or not f.exists():
                continue
            for p in f.iterdir():
                if not p.is_file():
                    continue
                stem = p.stem.split("-")[0]
                if stem.isdigit():
                    nums.append(int(stem))
        return max(nums) + 1 if nums else 1

    def _bundle_files_for(self, img: Path) -> list[Path]:
        """Every file that travels with the image: the image itself, any image
        sidecar, every paired/extra video, and those videos' .json sidecars.
        Used by Reject (delete all)."""
        bundle = [img]
        img_sidecar = img.with_suffix(".json")
        if img_sidecar.exists():
            bundle.append(img_sidecar)
        for vid, sc in self._paired_videos_for(img):
            bundle.append(vid)
            if sc is not None:
                bundle.append(sc)
        return bundle

    def _paired_videos_for(self, img: Path) -> list[tuple[Path, Path | None]]:
        """Return [(video, sidecar_or_None), ...] for the image's primary video
        and every -extra/-extraN video. Primary (exact-stem match) first, then
        extras ordered naturally."""
        parent = img.parent
        stem = img.stem

        primary: Path | None = None
        extras: list[Path] = []
        for f in parent.iterdir():
            if not f.is_file() or f.suffix.lower() not in VIDEO_EXTS:
                continue
            if f.stem == stem:
                primary = f
            elif f.stem.startswith(f"{stem}-extra"):
                extras.append(f)
        extras.sort(key=lambda p: p.stem)

        out: list[tuple[Path, Path | None]] = []
        if primary is not None:
            sc = primary.with_suffix(".json")
            out.append((primary, sc if sc.exists() else None))
        for v in extras:
            sc = v.with_suffix(".json")
            out.append((v, sc if sc.exists() else None))
        return out

    def _pick_video_dialog(
        self, videos: list[tuple[Path, Path | None]]
    ) -> tuple[Path, Path | None] | None:
        """Modal picker. User plays videos and selects one. Returns the chosen
        (video, sidecar_or_None), or None if cancelled."""
        win = tk.Toplevel(self.root)
        win.title("Choose video")
        win.transient(self.root)
        win.grab_set()

        ttk.Label(
            win,
            text=(f"{len(videos)} videos paired with this image. "
                  "Pick one to accept — the others will be deleted."),
            wraplength=520,
        ).pack(padx=12, pady=(12, 6), anchor="w")

        choice = tk.IntVar(value=0)
        for idx, (vid, _sc) in enumerate(videos):
            row = ttk.Frame(win)
            row.pack(fill="x", padx=12, pady=3)
            ttk.Radiobutton(row, variable=choice, value=idx, text=vid.name).pack(side="left")
            ttk.Button(row, text="▶ Play",
                       command=lambda v=vid: os.startfile(str(v))).pack(side="right")  # noqa

        result: dict = {"picked": None}
        btns = ttk.Frame(win)
        btns.pack(fill="x", padx=12, pady=(10, 12))
        ttk.Button(btns, text="Cancel", command=win.destroy).pack(side="right")
        def on_ok():
            result["picked"] = videos[choice.get()]
            win.destroy()
        ttk.Button(btns, text="Accept →", command=on_ok).pack(side="right", padx=(0, 6))

        win.wait_window()
        return result["picked"]

    def accept_selected(self):
        sel = self.dl_tree.selection()
        if not sel:
            messagebox.showinfo("Accept", "Select one or more files in the Downloads list.")
            return
        imgs = [self._dl_paths[iid] for iid in sel
                if iid in self._dl_paths and self._dl_paths[iid].exists()]
        if not imgs:
            return

        # Gate: all selected images must already be tagged
        untagged = [p for p in imgs if not read_exif_metadata(p).get("tags")]
        if untagged:
            names = ", ".join(p.name for p in untagged[:5])
            more = f" (+{len(untagged) - 5} more)" if len(untagged) > 5 else ""
            messagebox.showwarning(
                "Not tagged",
                f"{len(untagged)} selected image(s) have no EXIF tags yet: {names}{more}\n\n"
                f"Tag them first, then accept.",
            )
            return

        staging_root = self._current_staging_root()
        if staging_root is None:
            messagebox.showerror("Accept", "No staging root for the current rating.")
            return

        requested = self.collection_var.get()
        target, existed, is_generic = self._resolve_collection_folder(staging_root, requested)

        # One warn for the whole batch
        if existed and not is_generic:
            ok = messagebox.askyesno(
                "Existing collection",
                f"Collection '{target.name}' already exists under {staging_root.name}.\n\n"
                f"Add {len(imgs)} file(s) to it?",
            )
            if not ok:
                return

        target.mkdir(parents=True, exist_ok=True)

        accepted = 0
        total_moved = 0
        total_deleted = 0
        for img in imgs:
            # Video picker per image (if >1 video pairs this img)
            videos = self._paired_videos_for(img)
            chosen: tuple[Path, Path | None] | None = None
            if len(videos) > 1:
                chosen = self._pick_video_dialog(videos)
                if chosen is None:
                    # User cancelled the picker for this image → skip, keep going
                    continue
            elif len(videos) == 1:
                chosen = videos[0]

            n = self._next_number(target)
            moves: list[tuple[Path, Path]] = [(img, target / f"{n}{img.suffix.lower()}")]
            img_sidecar = img.with_suffix(".json")
            if img_sidecar.exists():
                moves.append((img_sidecar, target / f"{n}.json"))

            deletes: list[Path] = []
            if chosen is not None:
                vid, sc = chosen
                moves.append((vid, target / f"{n}{vid.suffix.lower()}"))
                if sc is not None:
                    moves = [(s, d) for (s, d) in moves if d != target / f"{n}.json"]
                    moves.append((sc, target / f"{n}.json"))
                for other_vid, other_sc in videos:
                    if other_vid == vid:
                        continue
                    deletes.append(other_vid)
                    if other_sc is not None:
                        deletes.append(other_sc)

            try:
                for src, dest in moves:
                    shutil.move(str(src), str(dest))
                    total_moved += 1
                for p in deletes:
                    try:
                        p.unlink()
                        total_deleted += 1
                    except Exception as e:
                        print(f"accept: couldn't delete {p.name}: {e}")
            except Exception as e:
                messagebox.showerror("Accept",
                                     f"Move failed on {img.name}: {e}\n\n"
                                     f"Accepted so far: {accepted}.")
                break
            accepted += 1

        self.refresh_downloads()
        self.refresh_accepted()
        self.refresh_pushed()
        msg = f"Accepted {accepted}/{len(imgs)} file(s) → {target.name}/"
        if total_moved:
            msg += f"\nMoved {total_moved} file(s) total."
        if total_deleted:
            msg += f"\nDeleted {total_deleted} unused video/sidecar file(s)."
        messagebox.showinfo("Accept", msg)

    def reject_selected(self):
        sel = self.dl_tree.selection()
        if not sel:
            messagebox.showinfo("Reject", "Select one or more files in the Downloads list.")
            return
        imgs = [self._dl_paths[iid] for iid in sel
                if iid in self._dl_paths and self._dl_paths[iid].exists()]
        if not imgs:
            return

        # Aggregate the full deletion bundle across all selected images
        bundle: list[Path] = []
        seen: set[Path] = set()
        for img in imgs:
            for p in self._bundle_files_for(img):
                if p not in seen:
                    seen.add(p)
                    bundle.append(p)

        head_names = [b.name for b in bundle[:10]]
        preview = "\n  ".join(head_names)
        more = f"\n  ... (+{len(bundle) - 10} more)" if len(bundle) > 10 else ""
        ok = messagebox.askyesno(
            "Reject (delete)",
            f"Permanently delete {len(bundle)} file(s) across {len(imgs)} "
            f"image bundle(s) from Downloads?\n\n  {preview}{more}",
        )
        if not ok:
            return

        deleted = 0
        for p in bundle:
            try:
                p.unlink()
                deleted += 1
            except Exception as e:
                print(f"reject err {p.name}: {e}")

        self.refresh_downloads()
        messagebox.showinfo("Reject", f"Deleted {deleted}/{len(bundle)} file(s).")

    # ---------- AI Tag ----------
    def ai_tag(self):
        # Batch mode — skip already-tagged to save quota
        self._run_tag_dialog(title="AI Tagging (Downloads)", todo=None, force=False)

    def ai_tag_selected(self):
        sel = self.dl_tree.selection()
        if not sel:
            messagebox.showinfo("Tag Selected", "Select one or more files in the Downloads list first.")
            return
        todo: list[Path] = []
        for iid in sel:
            p = self._dl_paths.get(iid)
            if p and p.suffix.lower() in {".jpg", ".jpeg"}:
                todo.append(p)
        if not todo:
            messagebox.showinfo("Tag Selected", "No tag-able jpgs in selection.")
            return
        # Explicit selection — re-tag even if already tagged (user's choice costs quota)
        self._run_tag_dialog(title=f"AI Tagging ({len(todo)} selected)", todo=todo, force=True)

    def _run_tag_dialog(self, title: str, todo: list[Path] | None, force: bool = False):
        if not DOWNLOADS.exists():
            messagebox.showerror("AI Tag", f"Downloads folder not found: {DOWNLOADS}")
            return
        if not GEMINI_BIN or GEMINI_BIN == "gemini":
            if not shutil.which("gemini.cmd") and not shutil.which("gemini"):
                messagebox.showerror("AI Tag", "gemini CLI not found on PATH.")
                return
        if getattr(self, "_tag_running", False):
            return
        self._tag_running = True

        win = tk.Toplevel(self.root)
        win.title(title)
        win.geometry("760x520")
        win.transient(self.root)

        bar_frame = ttk.Frame(win)
        bar_frame.pack(fill="x", padx=4, pady=(4, 0))
        pbar = ttk.Progressbar(bar_frame, mode="determinate", length=200)
        pbar.pack(side="left", fill="x", expand=True)
        status_var = tk.StringVar(value="Starting...")
        ttk.Label(bar_frame, textvariable=status_var, width=24, anchor="e").pack(side="right", padx=(6, 0))

        log_frame = ttk.Frame(win)
        log_frame.pack(fill="both", expand=True, padx=4, pady=4)
        log_text = tk.Text(log_frame, wrap="word", font=("Consolas", 9))
        log_sb = ttk.Scrollbar(log_frame, orient="vertical", command=log_text.yview)
        log_text.configure(yscrollcommand=log_sb.set)
        log_text.pack(side="left", fill="both", expand=True)
        log_sb.pack(side="right", fill="y")

        cancel = {"flag": False}
        btn = ttk.Button(win, text="Cancel", command=lambda: cancel.update(flag=True))
        btn.pack(side="bottom", pady=4)

        def log(msg):
            self.root.after(0, lambda: (log_text.insert("end", msg + "\n"), log_text.see("end")))

        def set_progress(done, total, status=None):
            def apply():
                pbar.configure(maximum=max(total, 1), value=done)
                if status is not None:
                    status_var.set(status)
            self.root.after(0, apply)

        def worker():
            try:
                summary = self._do_tag(log, set_progress, lambda: cancel["flag"], todo, force)
            except Exception as e:
                log(f"ERROR: {e}")
                summary = None
            finally:
                self._tag_running = False

            def finish():
                if summary:
                    messagebox.showinfo("AI Tag", summary, parent=win)
                btn.configure(text="Close", command=win.destroy)
                self.refresh_downloads()
            self.root.after(0, finish)

        threading.Thread(target=worker, daemon=True).start()

    def _do_tag(self, log, set_progress, cancelled,
                todo: list[Path] | None, force: bool) -> str | None:
        if todo is None:
            all_jpgs = sorted(
                [p for p in DOWNLOADS.iterdir()
                 if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg"}],
                key=lambda p: (0, int(p.stem)) if p.stem.isdigit() else (1, p.stem),
            )
        else:
            all_jpgs = list(todo)

        if force:
            # Explicit re-tag — don't skip already-tagged
            todo_final = list(all_jpgs)
            skipped = 0
            log(f"{len(all_jpgs)} candidates — force re-tag (ignoring existing EXIF).")
        else:
            todo_final = [p for p in all_jpgs if not read_exif_metadata(p).get("tags")]
            skipped = len(all_jpgs) - len(todo_final)
            log(f"{len(all_jpgs)} candidates — {skipped} already tagged, {len(todo_final)} to tag.")
        if not todo_final:
            return f"Nothing to tag (all {len(all_jpgs)} already have tags)."
        todo = todo_final

        set_progress(0, len(todo), "Tagging 0/" + str(len(todo)))
        done = 0
        success = 0
        failed = 0

        # Cap concurrency: each gemini call spawns a node process (~300-500MB)
        max_workers = 2

        agent = self.agent_var.get()
        log(f"Agent: {agent}")
        rate_limited = False
        with ThreadPoolExecutor(max_workers=max_workers) as ex:
            futures = {ex.submit(tag_image, img, agent): img for img in todo}
            for fut in as_completed(futures):
                if cancelled() or rate_limited:
                    for f in futures:
                        f.cancel()
                    break
                img = futures[fut]
                ok = False
                try:
                    ok = fut.result()
                except LLMRateLimit as e:
                    rate_limited = True
                    log(f"!!! RATE LIMIT hit on {img.name}")
                    log(f"    {agent}: {str(e)[:240]}")
                    log("Stopping batch. Wait for quota reset and re-run.")
                    continue
                except Exception as e:
                    log(f"  err {img.name}: {e}")
                if ok:
                    success += 1
                    meta = read_exif_metadata(img).get("subject_fields", {})
                    log(f"  tagged: {img.name}  rating={meta.get('rating','?')}  adult={meta.get('adult','?')}")
                else:
                    failed += 1
                    log(f"  FAILED: {img.name}")
                done += 1
                set_progress(done, len(todo), f"Tagging {done}/{len(todo)}")

        header = "Stopped — Gemini rate/quota limit hit." if rate_limited else "Done."
        return (
            f"{header}\n"
            f"Already tagged (skipped): {skipped}\n"
            f"Tagged this run: {success}\n"
            f"Failed: {failed}"
        )


    # ---------- Push to R2 ----------
    def _build_push_tasks(self, staging_root: Path):
        """Walk accepted collections and produce (collection, images_batch, mp3_or_None) tuples.

        No eligibility gate — push whatever's there. Themed collections push
        all images in one batch + any .mp3 present. Generic pushes in batches
        of 10 for progress granularity (trailing partial batch included, no mp3).
        """
        tasks: list[tuple[Path, list[Path], Path | None]] = []
        for coll in sorted([p for p in staging_root.iterdir() if p.is_dir()],
                           key=lambda p: p.name.lower()):
            images = sorted(
                [p for p in coll.iterdir()
                 if p.is_file() and p.suffix.lower() == ".jpg" and p.stem.isdigit()],
                key=lambda p: int(p.stem),
            )
            if not images:
                continue
            is_generic = coll.name.lower() == "generic"
            if is_generic:
                for i in range(0, len(images), 10):
                    tasks.append((coll, images[i:i + 10], None))
            else:
                mp3 = next((p for p in coll.iterdir()
                            if p.suffix.lower() == ".mp3"), None)
                tasks.append((coll, images, mp3))
        return tasks

    def _r2_put(self, bucket: str, key: str, file_path: Path, timeout: int = 240) -> tuple[bool, str]:
        """Upload one file via wrangler. Returns (ok, stderr-head)."""
        try:
            proc = subprocess.run(
                [WRANGLER_BIN, "r2", "object", "put",
                 f"{bucket}/{key}", "--file", str(file_path), "--remote"],
                capture_output=True, text=True, timeout=timeout,
                encoding="utf-8", errors="replace",
                creationflags=(subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0),
            )
        except subprocess.TimeoutExpired:
            return False, "timeout"
        except FileNotFoundError:
            return False, "wrangler not found"
        if proc.returncode != 0:
            return False, (proc.stderr or proc.stdout or "")[:400]
        return True, ""

    def _selected_scope(self, staging_root: Path):
        """Resolve the Accepted-tree selection into (collection_filter, file_filter).

        Returns:
          collection_filter: set[Path] of collection folders the user wants,
                             or None if the selection targets the whole rating.
          file_filter: set[Path] of specific files to restrict to (only those
                      files within their collections will be pushed), or None.
        """
        if not hasattr(self, "accepted_tree"):
            return set(), None
        sel = self.accepted_tree.selection()
        if not sel:
            return set(), None  # nothing selected → caller shows "no selection" error

        coll_filter: set[Path] = set()
        file_filter: set[Path] = set()
        for iid in sel:
            path = self._accepted_paths.get(iid)
            if path is not None:
                # file node: include its parent collection AND pin the file
                coll_filter.add(path.parent)
                file_filter.add(path)
                continue
            # non-file node: rating root or collection node
            raw_text = self.accepted_tree.item(iid, "text")
            name = raw_text.split("  [", 1)[0].strip()
            candidate = staging_root / name
            if candidate.exists() and candidate.is_dir():
                coll_filter.add(candidate)
            else:
                # Probably the rating-root node → user means "push this whole rating"
                return None, None
        return coll_filter, (file_filter or None)

    def push_all(self):
        rating = self.rating_var.get()
        bucket = BUCKET_BY_RATING.get(rating)
        staging_root = STAGING_ROOTS.get(rating)
        pushed_root = PUSHED_BY_RATING.get(rating)
        if not bucket or not staging_root or not pushed_root:
            messagebox.showerror("Push", f"No config for rating {rating!r}.")
            return
        if not staging_root.exists():
            messagebox.showinfo("Push", "Accepted folder is empty.")
            return
        if not Path(WRANGLER_BIN).exists() and not shutil.which("wrangler.cmd"):
            messagebox.showerror("Push", f"wrangler CLI not found at {WRANGLER_BIN}")
            return

        coll_filter, file_filter = self._selected_scope(staging_root)
        if coll_filter == set():
            messagebox.showinfo(
                "Push",
                "Select a collection (or files inside one) in the Accepted tab "
                "first. Select the rating-root node if you truly want to push everything.",
            )
            return

        tasks = self._build_push_tasks(staging_root)
        # Scope tasks to the selection
        if coll_filter:
            tasks = [t for t in tasks if t[0] in coll_filter]
        if file_filter:
            filtered: list[tuple[Path, list[Path], Path | None]] = []
            for coll, imgs, mp3 in tasks:
                imgs_in_scope = [p for p in imgs if p in file_filter]
                if imgs_in_scope:
                    # Music is per-collection (not per-image), so include it
                    # whenever we're pushing any image from the themed
                    # collection, even if the user didn't click the mp3 row.
                    filtered.append((coll, imgs_in_scope, mp3))
            tasks = filtered

        if not tasks:
            messagebox.showinfo("Push", "Nothing in the selection to push.")
            return

        n_files = sum(len(b) for _c, b, _m in tasks) * 2 + sum(1 for _c, _b, m in tasks if m)
        n_batches = len(tasks)
        ok = messagebox.askyesno(
            "Push to R2",
            f"Rating: {rating}  (bucket: {bucket})\n"
            f"{n_batches} batch(es), ~{n_files} file(s) to upload.\n\n"
            f"Continue?",
        )
        if not ok:
            return

        if getattr(self, "_push_running", False):
            return
        self._push_running = True

        win = tk.Toplevel(self.root)
        win.title(f"Push to R2 ({rating} → {bucket})")
        win.geometry("780x520")
        win.transient(self.root)
        bar_frame = ttk.Frame(win)
        bar_frame.pack(fill="x", padx=4, pady=(4, 0))
        pbar = ttk.Progressbar(bar_frame, mode="determinate")
        pbar.pack(side="left", fill="x", expand=True)
        status_var = tk.StringVar(value="Starting...")
        ttk.Label(bar_frame, textvariable=status_var, width=26, anchor="e").pack(side="right", padx=(6, 0))

        log_frame = ttk.Frame(win)
        log_frame.pack(fill="both", expand=True, padx=4, pady=4)
        log_text = tk.Text(log_frame, wrap="word", font=("Consolas", 9))
        log_sb = ttk.Scrollbar(log_frame, orient="vertical", command=log_text.yview)
        log_text.configure(yscrollcommand=log_sb.set)
        log_text.pack(side="left", fill="both", expand=True)
        log_sb.pack(side="right", fill="y")
        cancel = {"flag": False}
        btn = ttk.Button(win, text="Cancel", command=lambda: cancel.update(flag=True))
        btn.pack(side="bottom", pady=4)

        def log(m):
            self.root.after(0, lambda: (log_text.insert("end", m + "\n"), log_text.see("end")))

        def set_progress(d, t, s=None):
            def apply():
                pbar.configure(maximum=max(t, 1), value=d)
                if s is not None:
                    status_var.set(s)
            self.root.after(0, apply)

        def worker():
            try:
                summary = self._do_push(tasks, bucket, pushed_root, log, set_progress,
                                        lambda: cancel["flag"])
            except Exception as e:
                log(f"ERROR: {e}")
                summary = None
            finally:
                self._push_running = False

            def finish():
                if summary:
                    messagebox.showinfo("Push", summary, parent=win)
                btn.configure(text="Close", command=win.destroy)
                self.refresh_accepted()
                self.refresh_pushed()
            self.root.after(0, finish)

        threading.Thread(target=worker, daemon=True).start()

    def _do_push(self, tasks, bucket, pushed_root, log, set_progress, cancelled):
        total_files = sum(len(b) for _c, b, _m in tasks) * 2 + sum(1 for _c, _b, m in tasks if m)
        done = 0
        set_progress(0, total_files, "Pushing")
        uploaded_imgs = 0
        failed = 0

        for coll, batch, mp3 in tasks:
            if cancelled():
                return "Cancelled."
            coll_name = coll.name
            pushed_coll = pushed_root / coll_name
            pushed_coll.mkdir(parents=True, exist_ok=True)

            log(f"== {coll_name}  batch of {len(batch)} ==")

            for img in batch:
                if cancelled():
                    return "Cancelled."
                vid = img.with_suffix(".mp4")
                img_json = img.with_suffix(".json")

                img_key = f"collections/{coll_name}/images/{img.name}"
                ok, err = self._r2_put(bucket, img_key, img)
                if not ok:
                    failed += 1
                    log(f"  FAIL image {img_key}: {err}")
                    return f"Stopped — image upload failed: {img.name}\n{err}"
                log(f"  ✓ {img_key}")
                done += 1; set_progress(done, total_files, f"Uploaded {done}/{total_files}")

                if vid.exists():
                    vid_key = f"collections/{coll_name}/videos/{vid.name}"
                    ok, err = self._r2_put(bucket, vid_key, vid)
                    if not ok:
                        failed += 1
                        log(f"  FAIL video {vid_key}: {err}")
                        return f"Stopped — video upload failed: {vid.name}\n{err}"
                    log(f"  ✓ {vid_key}")
                done += 1; set_progress(done, total_files, f"Uploaded {done}/{total_files}")

                # Move image + video + sidecar json to pushed folder (json not uploaded)
                try:
                    shutil.move(str(img), str(pushed_coll / img.name))
                    if vid.exists():
                        shutil.move(str(vid), str(pushed_coll / vid.name))
                    if img_json.exists():
                        shutil.move(str(img_json), str(pushed_coll / img_json.name))
                except Exception as e:
                    log(f"  move warn for {img.name}: {e}")

                uploaded_imgs += 1

            if mp3 and mp3.exists():
                mp3_key = f"collections/{coll_name}/music/{mp3.name}"
                ok, err = self._r2_put(bucket, mp3_key, mp3)
                if not ok:
                    failed += 1
                    log(f"  FAIL mp3 {mp3_key}: {err}")
                    return f"Stopped — mp3 upload failed: {mp3.name}\n{err}"
                log(f"  ✓ {mp3_key}")
                done += 1; set_progress(done, total_files, f"Uploaded {done}/{total_files}")
                try:
                    shutil.move(str(mp3), str(pushed_coll / mp3.name))
                except Exception as e:
                    log(f"  move warn for mp3 {mp3.name}: {e}")

            # If collection folder now empty, clean up
            try:
                if not any(coll.iterdir()):
                    coll.rmdir()
            except Exception:
                pass

        return (
            f"Done.\n"
            f"Batches: {len(tasks)}\n"
            f"Images pushed: {uploaded_imgs}\n"
            f"Failed uploads: {failed}"
        )

    # ---------- Music generation (ElevenLabs) ----------
    def generate_music_selected(self):
        """Pick the currently-selected collection (or its parent) and generate a
        30-second ElevenLabs track named after the collection."""
        sel = self.accepted_tree.selection()
        if not sel:
            messagebox.showinfo("Music", "Select a collection (or a file inside one) first.")
            return
        path = self._accepted_paths.get(sel[0])
        # If a file is selected, use its parent (the collection folder).
        # If a collection node is selected, it has no path mapping — resolve via tree text.
        coll_path: Path | None = None
        if path is not None:
            coll_path = path.parent
        else:
            # Walk up the tree to find a node that corresponds to a collection directory
            item = sel[0]
            rating = self.rating_var.get()
            staging_root = STAGING_ROOTS.get(rating)
            if staging_root:
                raw_label = self.accepted_tree.item(item, "text")
                # Strip the readiness suffix that looks like "  [ ... ]"
                name = raw_label.split("  [", 1)[0].strip()
                candidate = staging_root / name
                if candidate.exists() and candidate.is_dir():
                    coll_path = candidate
        if coll_path is None or not coll_path.is_dir():
            messagebox.showinfo("Music", "Couldn't resolve a collection folder from the selection.")
            return

        if coll_path.name.lower() == "generic":
            messagebox.showinfo("Music",
                                "Generic doesn't use per-collection music. "
                                "Pick a themed collection.")
            return

        # Confirm — the ElevenLabs Music API costs credits.
        existing = [p for p in coll_path.iterdir() if p.suffix.lower() == ".mp3"]
        if existing:
            ok = messagebox.askyesno(
                "Music",
                f"{coll_path.name}/ already has {len(existing)} mp3.\n"
                f"Generate another 30-second track?",
            )
            if not ok:
                return

        if getattr(self, "_music_running", False):
            return
        self._music_running = True

        win = tk.Toplevel(self.root)
        win.title(f"Generate Music — {coll_path.name}")
        win.geometry("540x260")
        win.transient(self.root)
        ttk.Label(win, text=f"Collection: {coll_path.name}",
                  font=("TkDefaultFont", 10, "bold")).pack(padx=10, pady=(10, 4), anchor="w")
        status_var = tk.StringVar(value="Generating 30s track via ElevenLabs…")
        ttk.Label(win, textvariable=status_var, wraplength=510).pack(padx=10, pady=4, anchor="w")
        pbar = ttk.Progressbar(win, mode="indeterminate", length=520)
        pbar.pack(padx=10, pady=6)
        pbar.start(100)
        log_text = tk.Text(win, height=6, wrap="word", font=("Consolas", 9))
        log_text.pack(fill="both", expand=True, padx=10, pady=4)
        close_btn = ttk.Button(win, text="Close", command=win.destroy, state="disabled")
        close_btn.pack(pady=6)

        def log(m):
            self.root.after(0, lambda: (log_text.insert("end", m + "\n"), log_text.see("end")))

        def worker():
            try:
                path, err = self._generate_music(coll_path, log)
            except Exception as e:
                path, err = None, str(e)
            finally:
                self._music_running = False

            def finish():
                pbar.stop()
                close_btn.configure(state="normal")
                if path:
                    status_var.set(f"Done: {path.name}")
                    messagebox.showinfo("Music", f"Saved:\n{path}", parent=win)
                else:
                    status_var.set(f"Failed: {err}")
                    messagebox.showerror("Music", err or "Unknown error", parent=win)
                self.refresh_accepted()
            self.root.after(0, finish)

        threading.Thread(target=worker, daemon=True).start()

    def _generate_music(self, coll_path: Path, log) -> tuple[Path | None, str]:
        """Call ElevenLabs Music API for a 30s track. Returns (path_or_None, err)."""
        if not ELEVENLABS_API_KEY:
            return None, "No ELEVENLABS_API_KEY."

        # Build a prompt from the collection name (snake_case → space-separated).
        theme = coll_path.name.replace("_", " ").strip()
        prompt = (
            f"A cinematic 30-second instrumental loop matching the theme '{theme}'. "
            "Atmospheric, pleasant, no vocals, suitable as ambient background "
            "music for a mobile jigsaw puzzle app."
        )
        log(f"Theme prompt: {prompt}")

        import urllib.request, urllib.error
        body = json.dumps({
            "prompt": prompt,
            "music_length_ms": 30000,
        }).encode("utf-8")
        req = urllib.request.Request(
            "https://api.elevenlabs.io/v1/music",
            data=body,
            headers={
                "xi-api-key": ELEVENLABS_API_KEY,
                "Content-Type": "application/json",
                "Accept": "audio/mpeg",
            },
            method="POST",
        )
        log("POST https://api.elevenlabs.io/v1/music (may take 20-60s)…")
        try:
            with urllib.request.urlopen(req, timeout=240) as r:
                audio = r.read()
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", errors="replace")[:500]
            return None, f"HTTP {e.code}: {detail}"
        except urllib.error.URLError as e:
            return None, f"URL error: {e}"

        # Pick a unique filename: <collection>_00001_.mp3, incrementing if needed
        existing = sorted(
            p for p in coll_path.iterdir()
            if p.suffix.lower() == ".mp3" and p.stem.startswith(coll_path.name + "_")
        )
        next_idx = 1
        for p in existing:
            tail = p.stem[len(coll_path.name) + 1:]
            try:
                n = int(tail.strip("_"))
                next_idx = max(next_idx, n + 1)
            except ValueError:
                pass
        dest = coll_path / f"{coll_path.name}_{next_idx:05d}_.mp3"
        dest.write_bytes(audio)
        log(f"Wrote {dest.name} ({len(audio) // 1024} KB)")
        return dest, ""


if __name__ == "__main__":
    root = tk.Tk()
    App(root)
    root.mainloop()
