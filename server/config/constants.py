"""App constants: tech stacks, colors, paths, intervals."""

# ── Supported Technology Stacks ──────────────────────────────────

TECH_STACKS = {
    "flutter": {
        "name": "Flutter",
        "detect_file": "pubspec.yaml",
        "version_file": "pubspec.yaml",
        "version_pattern": r"version:\s*(.+)",
        "default_build_cmd": 'flutter build appbundle --release',
        "default_build_output": "build/app/outputs/bundle/release/app-release.aab",
        "package_detect": "android/app/src/main/AndroidManifest.xml",
        "scaffold_cmd": "flutter create {slug}",
    },
    "godot": {
        "name": "Godot 4.x",
        "detect_file": "project.godot",
        "version_file": "export_presets.cfg",
        "version_pattern": r'version/name="(.+)"',
        "default_build_cmd": 'godot --headless --export-release "Android" build/{slug}.apk',
        "default_build_output": "build/{slug}.apk",
        "package_detect": None,
        "scaffold_cmd": None,
    },
    "react_native": {
        "name": "React Native",
        "detect_file": "package.json",
        "version_file": "package.json",
        "version_pattern": r'"version":\s*"(.+)"',
        "default_build_cmd": "npx react-native build-android --mode=release",
        "default_build_output": "android/app/build/outputs/bundle/release/app-release.aab",
        "package_detect": "android/app/src/main/AndroidManifest.xml",
        "scaffold_cmd": "npx react-native init {name}",
    },
    "python": {
        "name": "Python",
        "detect_file": "pyproject.toml",
        "version_file": "pyproject.toml",
        "version_pattern": r'version\s*=\s*"(.+)"',
        "default_build_cmd": "python -m build",
        "default_build_output": "dist/",
        "package_detect": None,
        "scaffold_cmd": None,
    },
    "custom": {
        "name": "Custom",
        "detect_file": None,
        "version_file": None,
        "version_pattern": None,
        "default_build_cmd": None,
        "default_build_output": None,
        "package_detect": None,
        "scaffold_cmd": None,
    },
}

# ── Default Tool Paths ───────────────────────────────────────────

DEFAULT_SETTINGS = {
    "claude_path": "",
    "gemini_path": "",
    "codex_path": "",
    "flutter_path": "",
    "godot_path": "",
    "autofix_interval": "600",  # seconds between sessions
    "internet_check_url": "https://api.anthropic.com",
    "internet_check_interval": "30",  # seconds
    "session_timeout": "1200",  # 20 min max per session
    "max_logs_per_app": "100",
    "theme": "dark",
}

# ── UI Colors (Dark Theme) ───────────────────────────────────────

COLORS = {
    "bg_dark": "#1a1a2e",
    "bg_sidebar": "#16213e",
    "bg_card": "#0f3460",
    "bg_card_hover": "#1a4080",
    "accent": "#e94560",
    "accent_hover": "#ff6b81",
    "text_primary": "#ffffff",
    "text_secondary": "#a0a0b0",
    "text_muted": "#606080",
    "success": "#2ecc71",
    "warning": "#f39c12",
    "error": "#e74c3c",
    "info": "#3498db",
    "border": "#2a2a4a",
}

# ── Issue Categories ─────────────────────────────────────────────

ISSUE_CATEGORIES = [
    ("bug", "Bug"),
    ("anr", "ANR"),
    ("crash", "Crash"),
    ("improvement", "Improvement"),
    ("feature", "Feature"),
    ("idea", "Idea"),
]

ISSUE_PRIORITIES = [
    (1, "Critical"),
    (2, "High"),
    (3, "Medium"),
    (4, "Low"),
    (5, "Wishlist"),
]

ISSUE_STATUSES = [
    "open",
    "queued",
    "fixing",
    "fixed",
    "verified",
    "rejected",
    "wontfix",
]

# ── Priority Colors ──────────────────────────────────────────────

PRIORITY_COLORS = {
    1: "#e74c3c",  # Critical - red
    2: "#e67e22",  # High - orange
    3: "#f1c40f",  # Medium - yellow
    4: "#3498db",  # Low - blue
    5: "#95a5a6",  # Wishlist - gray
}

STATUS_COLORS = {
    "idle": "#95a5a6",
    "building": "#3498db",
    "fixing": "#e67e22",
    "error": "#e74c3c",
    "open": "#e74c3c",
    "queued": "#f39c12",
    "fixed": "#2ecc71",
    "verified": "#27ae60",
    "rejected": "#95a5a6",
    "wontfix": "#7f8c8d",
    "pending": "#f39c12",
    "running": "#3498db",
    "completed": "#2ecc71",
    "failed": "#e74c3c",
    "cancelled": "#95a5a6",
    "success": "#2ecc71",
}

# ── Build Targets ───────────────────────────────────────────────

BUILD_TARGETS = [
    ("aab", "AAB", "Google Play"),
    ("apk", "APK", "Sideload/itch.io"),
    ("exe", "EXE", "Windows"),
    ("ipa", "IPA", "iOS"),
    ("app", "APP", "macOS"),
]

BUILD_TARGET_COLORS = {
    "aab": "#2ecc71",
    "apk": "#3498db",
    "exe": "#9b59b6",
    "ipa": "#e67e22",
    "app": "#1abc9c",
}

# ── Publish Statuses ────────────────────────────────────────────

PUBLISH_STATUSES = [
    ("development", "Development"),
    ("experimental", "Experimental"),
    ("internal_test", "Internal Test"),
    ("external_test", "External Test"),
    ("published", "Published"),
]

PUBLISH_STATUS_COLORS = {
    "development": "#95a5a6",     # gray
    "experimental": "#9b59b6",    # purple
    "internal_test": "#f39c12",   # orange
    "external_test": "#3498db",   # blue
    "published": "#2ecc71",       # green
}

PUBLISH_STATUS_ICONS = {
    "development": "\u2699",      # gear
    "experimental": "\u26a0",     # warning
    "internal_test": "\u25b6",    # play
    "external_test": "\u25c6",    # diamond
    "published": "\u2713",        # checkmark
}
