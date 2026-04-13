"""
CBR/CBZ comic book archive extractor.
Uses 7-Zip to extract page images from .cbr (RAR) and .cbz (ZIP) files.
"""

import os
import subprocess
import tempfile
import shutil
from pathlib import Path


def _find_seven_zip() -> str:
    """Locate 7-Zip via env override, PATH, or well-known install dirs."""
    override = os.environ.get("SEVEN_ZIP")
    if override and os.path.exists(override):
        return override
    on_path = shutil.which("7z") or shutil.which("7z.exe")
    if on_path:
        return on_path
    program_files_candidates = [
        os.environ.get("ProgramFiles", "C:/Program Files"),
        os.environ.get("ProgramFiles(x86)", "C:/Program Files (x86)"),
    ]
    for pf in program_files_candidates:
        candidate = os.path.join(pf, "7-Zip", "7z.exe")
        if os.path.exists(candidate):
            return candidate
    return "7z"  # last resort — let subprocess fail with a clear error


SEVEN_ZIP = _find_seven_zip()
IMAGE_EXTS = {'.png', '.jpg', '.jpeg', '.webp', '.bmp', '.tiff', '.gif'}
COMIC_EXTS = {'.cbr', '.cbz', '.cb7', '.cbt'}


def is_comic_archive(path: str) -> bool:
    return Path(path).suffix.lower() in COMIC_EXTS


def extract_comic(archive_path: str, output_dir: str = None) -> list[str]:
    """
    Extract a CBR/CBZ/CB7 comic archive to a directory.

    Args:
        archive_path: path to .cbr, .cbz, or .cb7 file
        output_dir: where to extract (default: temp dir next to archive)

    Returns:
        Sorted list of extracted image file paths
    """
    archive_path = os.path.abspath(archive_path)
    if not os.path.exists(archive_path):
        raise FileNotFoundError(f"Archive not found: {archive_path}")

    if not (os.path.exists(SEVEN_ZIP) or shutil.which(SEVEN_ZIP)):
        raise RuntimeError(
            "7-Zip not found. Set SEVEN_ZIP env var to the 7z executable, "
            "put 7z on PATH, or install it: winget install 7zip.7zip"
        )

    # Create output directory
    if output_dir is None:
        base = Path(archive_path)
        output_dir = str(base.parent / f".{base.stem}_pages")

    os.makedirs(output_dir, exist_ok=True)

    # Extract with 7-Zip
    result = subprocess.run(
        [SEVEN_ZIP, 'x', '-y', f'-o{output_dir}', archive_path],
        capture_output=True, text=True, timeout=120,
        encoding='utf-8', errors='replace',
    )

    if result.returncode != 0:
        raise RuntimeError(f"Extraction failed: {result.stderr}")

    # Collect all image files (may be nested in subdirectories)
    images = []
    for root, _dirs, files in os.walk(output_dir):
        for f in files:
            if Path(f).suffix.lower() in IMAGE_EXTS:
                images.append(os.path.join(root, f))

    # Sort naturally by filename (page order)
    images.sort(key=lambda p: _natural_key(os.path.basename(p)))
    return images


def _natural_key(text: str):
    """Sort key for natural ordering (page1, page2, page10 instead of page1, page10, page2)."""
    import re
    parts = re.split(r'(\d+)', text.lower())
    return [int(p) if p.isdigit() else p for p in parts]


def cleanup_extracted(output_dir: str):
    """Remove extracted temp directory."""
    if os.path.isdir(output_dir) and os.path.basename(output_dir).startswith('.'):
        shutil.rmtree(output_dir, ignore_errors=True)
