"""Build the LcInAppUpdate Godot Android plugin (v2) and install it into Godot projects.

The plugin gives Godot 4.2+ games a forced app update gate backed by Google Play
In-App Updates (IMMEDIATE flow). What gets installed into each project:

    addons/lc_in_app_update/plugin.cfg          editor plugin entry (enable it in project.godot)
    addons/lc_in_app_update/export_plugin.gd    ships the AAR + adds com.google.android.play:app-update
    addons/lc_in_app_update/update_gate.gd      UpdateGate autoload: drives the flow, blocking page
    addons/lc_in_app_update/bin/{debug,release}/LcInAppUpdate-{debug,release}.aar

Each project then needs, once:
    [autoload]        UpdateGate="*res://addons/lc_in_app_update/update_gate.gd"
    [editor_plugins]  "res://addons/lc_in_app_update/plugin.cfg" in the enabled list
    translations      UPDATE_GATE_TITLE, UPDATE_GATE_BODY, UPDATE_GATE_BUTTON

Usage:
    python build_and_install.py "<godot project dir>" ["<godot project dir>" ...]
    python build_and_install.py --skip-build "<godot project dir>"   # copy only

Needs JDK 17 and an Android SDK (ANDROID_HOME / ANDROID_SDK_ROOT or local.properties).
Builds only the library AARs; it never exports or builds a game.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ADDON_SRC = HERE / "addon" / "lc_in_app_update"
AAR_DIR = HERE / "build" / "outputs" / "aar"
AARS = {
    "debug": "LcInAppUpdate-debug.aar",
    "release": "LcInAppUpdate-release.aar",
}


def build() -> None:
    gradlew = HERE / ("gradlew.bat" if sys.platform == "win32" else "gradlew")
    cmd = [str(gradlew), "--no-daemon", "assembleDebug", "assembleRelease"]
    print("+", " ".join(cmd))
    subprocess.run(cmd, cwd=HERE, check=True)


def install(project: Path) -> None:
    if not (project / "project.godot").is_file():
        raise SystemExit(f"not a Godot project: {project}")
    dst = project / "addons" / "lc_in_app_update"
    dst.mkdir(parents=True, exist_ok=True)
    for src in ADDON_SRC.iterdir():
        if src.is_file():
            shutil.copy2(src, dst / src.name)
    for variant, name in AARS.items():
        aar = AAR_DIR / name
        if not aar.is_file():
            raise SystemExit(f"missing {aar} - run without --skip-build first")
        out = dst / "bin" / variant
        out.mkdir(parents=True, exist_ok=True)
        shutil.copy2(aar, out / name)
    print(f"installed into {dst}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("projects", nargs="+", type=Path, help="Godot project directories")
    parser.add_argument("--skip-build", action="store_true", help="copy the existing AARs without rebuilding")
    args = parser.parse_args()
    if not args.skip_build:
        build()
    for project in args.projects:
        install(project.resolve())


if __name__ == "__main__":
    main()
