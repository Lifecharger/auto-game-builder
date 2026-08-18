"""Unity project helpers shared by the build and deploy engines.

Unity has no equivalent of `flutter build` or `godot --export-release`: a
head-less build must call a static C# method inside the project, so the caller
has to know that method's fully-qualified name. Rather than hardcode one
project's namespace, resolve it from the project's own BuildPlayer.cs.
"""

import logging
import os
import re

logger = logging.getLogger(__name__)

# Static entry points every Auto Game Builder Unity project must expose on its
# BuildPlayer class, keyed by the build target the deploy engine asked for.
BUILD_METHODS = {
    "aab": "Aab",
    "appbundle": "Aab",
    "apk": "Apk",
    "debug": "DebugApk",
}

BUILD_SCRIPT_NAME = "BuildPlayer.cs"
BUILD_CLASS_NAME = "BuildPlayer"
LOCKFILE_REL = os.path.join("Temp", "UnityLockfile")

# Unity's own C# lives under Assets/; scanning deeper than this just walks the
# user's art folders for nothing.
_MAX_SCAN_DEPTH = 4

_NAMESPACE_RE = re.compile(r"^\s*namespace\s+([A-Za-z_][\w.]*)", re.MULTILINE)


def find_build_script(project_path: str) -> str | None:
    """Absolute path to the project's BuildPlayer.cs, or None if absent."""
    conventional = os.path.join(project_path, "Assets", "Editor", BUILD_SCRIPT_NAME)
    if os.path.isfile(conventional):
        return conventional

    assets = os.path.join(project_path, "Assets")
    if not os.path.isdir(assets):
        return None
    base_depth = assets.rstrip(os.sep).count(os.sep)
    for root, dirs, files in os.walk(assets):
        if root.count(os.sep) - base_depth >= _MAX_SCAN_DEPTH:
            dirs[:] = []
            continue
        if BUILD_SCRIPT_NAME in files:
            return os.path.join(root, BUILD_SCRIPT_NAME)
    return None


def resolve_build_method(project_path: str, build_target: str) -> str:
    """Fully-qualified -executeMethod argument for a build target.

    Raises RuntimeError when the project has no BuildPlayer.cs or the target
    has no entry point — a Unity batch build that cannot find its method exits
    0 with no artifact, which would otherwise read as a silent success.
    """
    method = BUILD_METHODS.get(build_target)
    if not method:
        raise RuntimeError(
            f"No Unity build method for target '{build_target}'. "
            f"Valid targets: {sorted(BUILD_METHODS)}"
        )

    script = find_build_script(project_path)
    if not script:
        raise RuntimeError(
            f"Refusing to build: {BUILD_SCRIPT_NAME} not found under "
            f"{os.path.join(project_path, 'Assets')}. A Unity project needs an editor "
            f"script exposing static {BUILD_CLASS_NAME}.Aab/.Apk/.DebugApk to build head-lessly."
        )

    with open(script, "r", encoding="utf-8", errors="replace") as handle:
        source = handle.read()
    match = _NAMESPACE_RE.search(source)
    namespace = match.group(1) if match else ""
    qualified = f"{namespace}.{BUILD_CLASS_NAME}" if namespace else BUILD_CLASS_NAME
    return f"{qualified}.{method}"


def editor_lock_holder(project_path: str) -> str | None:
    """Path of the Unity editor lock file if the project is open, else None.

    Unity refuses to open a project in batch mode while the editor holds it,
    and fails with a wall of log noise instead of a usable message.
    """
    lock = os.path.join(project_path, LOCKFILE_REL)
    return lock if os.path.isfile(lock) else None
