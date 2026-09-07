#!/usr/bin/env python3
"""Bundle staged color-by-number assets into a Flutter app's assets/packs folder.

Usage:
    python cbn_pack.py --rating hot --dest "C:/Projects/CBN Hot/assets/packs"
    python cbn_pack.py --rating kid --dest "C:/Projects/CBN Pro/assets/packs"
    python cbn_pack.py --rating hot --dest ... --source-root "D:/some/other/Hot CBN"

Reads the staging tree produced by AGB tools/comfyui/{hot_cbn,kid_cbn}.py:

    <source-root>/<Collection>/<n>/{asset.json, regions.png, source.jpg,
                                    lineart.png, numbered.png, ...}

For the `hot` rating the prototype folders `<source-root>/_proto/9x16_*` are also
packed (collection id "proto"); there the files carry the pipeline's numbered
names (00_source.png, 02_regions.png, 04_numbered.png, 05_lineart.png) and are
mapped onto the standard names.  Folders without an `asset.json` are skipped --
generation may still be writing them.

Writes, per asset:

    <dest>/<collection_slug>/<n>/{asset.json, regions.png, source.jpg,
                                  lineart.png, thumb.jpg}

plus <dest>/index.json, and rewrites the app's pubspec.yaml `assets:` entries
between the `# packs-begin` / `# packs-end` marker lines (Flutter does not
recurse into subdirectories, so every pack directory has to be listed).

The tool is idempotent: stale collection/asset folders under <dest> are removed.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

import cv2
import numpy as np

DEFAULT_ROOTS = {
    "hot": Path(r"D:/Asset Generation Pipeline/Hot CBN"),
    "kid": Path(r"D:/Asset Generation Pipeline/Kid CBN"),
}

# _proto folders that are packed for the hot rating (spec section 6).
PROTO_GLOB = "9x16_*"
PROTO_COLLECTION_ID = "proto"
PROTO_COLLECTION_TITLE = "Proto"

# Pipeline file name -> standard pack file name.
PROTO_NAMES = {
    "source": "00_source.png",
    "regions": "02_regions.png",
    "lineart": "05_lineart.png",
    "numbered": "04_numbered.png",
}
STANDARD_NAMES = {
    "source": "source.jpg",
    "regions": "regions.png",
    "lineart": "lineart.png",
    "numbered": "numbered.png",
}

THUMB_LONG_SIDE = 512
THUMB_QUALITY = 85
SOURCE_QUALITY = 92

ASPECTS = [
    ("9:16", 9 / 16),
    ("2:3", 2 / 3),
    ("1:1", 1.0),
    ("3:2", 3 / 2),
    ("16:9", 16 / 9),
]

MARK_BEGIN = "# packs-begin"
MARK_END = "# packs-end"


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
def log(msg: str) -> None:
    print(msg, flush=True)


def slugify(name: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", name.strip().lower()).strip("_")
    return slug or "collection"


def closest_aspect(width: int, height: int) -> str:
    if not width or not height:
        return "1:1"
    ratio = width / height
    best, best_err = ASPECTS[0][0], None
    for label, value in ASPECTS:
        # compare in log space so 9:16 and 16:9 are treated symmetrically
        err = abs(np.log(ratio) - np.log(value))
        if best_err is None or err < best_err:
            best, best_err = label, err
    return best


def imread(path: Path, flags: int = cv2.IMREAD_UNCHANGED) -> np.ndarray | None:
    data = np.fromfile(str(path), dtype=np.uint8)
    if data.size == 0:
        return None
    return cv2.imdecode(data, flags)


def imwrite(path: Path, img: np.ndarray, params: list[int] | None = None) -> None:
    ok, buf = cv2.imencode(path.suffix, img, params or [])
    if not ok:
        raise RuntimeError(f"failed to encode {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    buf.tofile(str(path))


def to_bgr(img: np.ndarray) -> np.ndarray:
    if img.ndim == 2:
        return cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
    if img.shape[2] == 4:
        # flatten onto white so jpg conversion never produces black halos
        bgr = img[:, :, :3].astype(np.float32)
        alpha = (img[:, :, 3:4].astype(np.float32)) / 255.0
        flat = bgr * alpha + 255.0 * (1.0 - alpha)
        return np.clip(flat, 0, 255).astype(np.uint8)
    return img


def copy_if_changed(src: Path, dst: Path) -> None:
    if dst.exists():
        s, d = src.stat(), dst.stat()
        if s.st_size == d.st_size and int(s.st_mtime) <= int(d.st_mtime):
            return
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def write_source_jpg(src: Path, dst: Path) -> None:
    """Copy source.jpg straight through, or transcode a source png at q92."""
    if src.suffix.lower() in (".jpg", ".jpeg"):
        copy_if_changed(src, dst)
        return
    if dst.exists() and dst.stat().st_mtime >= src.stat().st_mtime:
        return
    img = imread(src, cv2.IMREAD_COLOR)
    if img is None:
        raise RuntimeError(f"cannot read {src}")
    imwrite(dst, to_bgr(img), [cv2.IMWRITE_JPEG_QUALITY, SOURCE_QUALITY])


def write_thumb(src: Path, dst: Path) -> None:
    if dst.exists() and dst.stat().st_mtime >= src.stat().st_mtime:
        return
    img = imread(src, cv2.IMREAD_UNCHANGED)
    if img is None:
        raise RuntimeError(f"cannot read {src}")
    img = to_bgr(img)
    h, w = img.shape[:2]
    scale = THUMB_LONG_SIDE / float(max(h, w))
    if scale < 1.0:
        img = cv2.resize(
            img,
            (max(1, int(round(w * scale))), max(1, int(round(h * scale)))),
            interpolation=cv2.INTER_AREA,
        )
    imwrite(dst, img, [cv2.IMWRITE_JPEG_QUALITY, THUMB_QUALITY])


def prune(directory: Path, keep: set[str]) -> None:
    """Delete child directories of `directory` that are not in `keep`."""
    if not directory.is_dir():
        return
    for child in directory.iterdir():
        if child.is_dir() and child.name not in keep:
            log(f"  - removing stale {child}")
            shutil.rmtree(child, ignore_errors=True)


# --------------------------------------------------------------------------- #
# discovery
# --------------------------------------------------------------------------- #
class SourceAsset:
    def __init__(self, folder: Path, names: dict[str, str], out_name: str):
        self.folder = folder
        self.names = names
        self.out_name = out_name

    def file(self, kind: str) -> Path | None:
        candidates = [self.names.get(kind)]
        if kind == "source":
            # tolerate either extension whichever layout we are in
            candidates += ["source.jpg", "source.png", "00_source.png", "00_source.jpg"]
        elif kind == "numbered":
            candidates += ["numbered.png", "04_numbered.png"]
        elif kind == "regions":
            candidates += ["regions.png", "02_regions.png"]
        elif kind == "lineart":
            candidates += ["lineart.png", "05_lineart.png"]
        for name in candidates:
            if not name:
                continue
            path = self.folder / name
            if path.is_file():
                return path
        return None


def discover(
    root: Path, rating: str, proto_glob: str = PROTO_GLOB
) -> list[tuple[str, str, list[SourceAsset]]]:
    """Return [(collection_id, collection_title, [SourceAsset, ...]), ...]."""
    collections: list[tuple[str, str, list[SourceAsset]]] = []

    if not root.is_dir():
        log(f"! source root does not exist: {root}")
        return collections

    for coll_dir in sorted(p for p in root.iterdir() if p.is_dir()):
        if coll_dir.name.startswith("_"):
            continue
        assets: list[SourceAsset] = []
        for asset_dir in sorted(
            (p for p in coll_dir.iterdir() if p.is_dir()),
            key=lambda p: (0, int(p.name)) if p.name.isdigit() else (1, p.name),
        ):
            if not (asset_dir / "asset.json").is_file():
                log(f"  . skipping {asset_dir.name} (no asset.json yet)")
                continue
            assets.append(SourceAsset(asset_dir, STANDARD_NAMES, asset_dir.name))
        if assets:
            collections.append((slugify(coll_dir.name), coll_dir.name, assets))

    if rating == "hot":
        proto_root = root / "_proto"
        proto_assets: list[SourceAsset] = []
        if proto_root.is_dir():
            for i, folder in enumerate(
                sorted(p for p in proto_root.glob(proto_glob) if p.is_dir()), start=1
            ):
                if not (folder / "asset.json").is_file():
                    log(f"  . skipping _proto/{folder.name} (no asset.json yet)")
                    continue
                proto_assets.append(SourceAsset(folder, PROTO_NAMES, str(i)))
        if proto_assets:
            collections.append(
                (PROTO_COLLECTION_ID, PROTO_COLLECTION_TITLE, proto_assets)
            )

    return collections


# --------------------------------------------------------------------------- #
# packing
# --------------------------------------------------------------------------- #
def pack_asset(src: SourceAsset, out_dir: Path, collection_id: str) -> dict | None:
    meta_path = src.folder / "asset.json"
    try:
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001 - report and skip a half-written file
        log(f"  ! {src.folder.name}: unreadable asset.json ({exc})")
        return None

    regions_png = src.file("regions")
    lineart_png = src.file("lineart")
    source_img = src.file("source")
    numbered_png = src.file("numbered") or lineart_png

    missing = [
        kind
        for kind, path in (
            ("regions", regions_png),
            ("lineart", lineart_png),
            ("source", source_img),
        )
        if path is None
    ]
    if missing:
        log(f"  ! {src.folder.name}: missing {', '.join(missing)} - skipped")
        return None

    out_dir.mkdir(parents=True, exist_ok=True)
    copy_if_changed(meta_path, out_dir / "asset.json")
    copy_if_changed(regions_png, out_dir / "regions.png")
    copy_if_changed(lineart_png, out_dir / "lineart.png")
    write_source_jpg(source_img, out_dir / "source.jpg")
    write_thumb(numbered_png, out_dir / "thumb.jpg")

    width = int(meta.get("width") or 0)
    height = int(meta.get("height") or 0)
    if not width or not height:
        img = imread(regions_png, cv2.IMREAD_COLOR)
        if img is not None:
            height, width = img.shape[:2]

    asset_id = f"{collection_id}/{out_dir.name}"
    return {
        "id": asset_id,
        "path": f"packs/{collection_id}/{out_dir.name}",
        "width": width,
        "height": height,
        "colors": len(meta.get("palette") or []),
        "regions": len(meta.get("regions") or []),
        "aspect": closest_aspect(width, height),
    }


def build_packs(
    root: Path, rating: str, dest: Path, proto_glob: str = PROTO_GLOB
) -> dict:
    dest.mkdir(parents=True, exist_ok=True)
    found = discover(root, rating, proto_glob)

    index_collections = []
    for collection_id, title, sources in found:
        log(f"* collection {collection_id} ({len(sources)} candidate assets)")
        coll_dir = dest / collection_id
        entries = []
        kept: set[str] = set()
        for src in sources:
            entry = pack_asset(src, coll_dir / src.out_name, collection_id)
            if entry is None:
                continue
            kept.add(src.out_name)
            entries.append(entry)
            log(f"  + {entry['id']}  {entry['width']}x{entry['height']}"
                f"  {entry['colors']} colors  {entry['regions']} regions"
                f"  {entry['aspect']}")
        prune(coll_dir, kept)
        if entries:
            index_collections.append(
                {"id": collection_id, "title": title, "assets": entries}
            )
        elif coll_dir.is_dir():
            shutil.rmtree(coll_dir, ignore_errors=True)

    prune(dest, {c["id"] for c in index_collections})

    index = {"version": 1, "collections": index_collections}
    (dest / "index.json").write_text(
        json.dumps(index, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    return index


# --------------------------------------------------------------------------- #
# pubspec
# --------------------------------------------------------------------------- #
def pack_directories(dest: Path, index: dict) -> list[str]:
    """Every directory Flutter has to be told about, as posix asset paths."""
    app_root = dest.parent.parent  # <app>/assets/packs -> <app>
    rel = dest.relative_to(app_root).as_posix()
    dirs = [f"{rel}/"]
    for collection in index["collections"]:
        dirs.append(f"{rel}/{collection['id']}/")
        for asset in collection["assets"]:
            dirs.append(f"{rel}/{collection['id']}/{asset['id'].split('/')[-1]}/")
    return dirs


def rewrite_pubspec(pubspec: Path, dirs: list[str]) -> bool:
    if not pubspec.is_file():
        log(f"! pubspec not found: {pubspec}")
        return False

    text = pubspec.read_text(encoding="utf-8")
    lines = text.splitlines()

    block = [f"    {MARK_BEGIN}"]
    block += [f"    - {d}" for d in dirs]
    block.append(f"    {MARK_END}")

    begin = end = None
    for i, line in enumerate(lines):
        if line.strip() == MARK_BEGIN and begin is None:
            begin = i
        elif line.strip() == MARK_END:
            end = i
    if begin is not None and end is not None and end > begin:
        lines[begin : end + 1] = block
        pubspec.write_text("\n".join(lines) + "\n", encoding="utf-8")
        log(f"= pubspec markers refreshed ({len(dirs)} directories)")
        return True

    # No markers yet: find the flutter: section.
    flutter_at = None
    for i, line in enumerate(lines):
        if re.match(r"^flutter:\s*$", line):
            flutter_at = i
            break
    if flutter_at is None:
        log(f"! no `flutter:` section in {pubspec}")
        return False

    section_end = len(lines)
    for i in range(flutter_at + 1, len(lines)):
        if lines[i].strip() and not lines[i].startswith((" ", "\t", "#")):
            section_end = i
            break

    assets_at = None
    for i in range(flutter_at + 1, section_end):
        if re.match(r"^\s+assets:\s*$", lines[i]):
            assets_at = i
            break

    if assets_at is not None:
        lines[assets_at + 1 : assets_at + 1] = block
    else:
        insert_at = section_end
        while insert_at > flutter_at + 1 and not lines[insert_at - 1].strip():
            insert_at -= 1
        lines[insert_at:insert_at] = ["", "  assets:"] + block

    pubspec.write_text("\n".join(lines) + "\n", encoding="utf-8")
    log(f"= pubspec markers created ({len(dirs)} directories)")
    return True


# --------------------------------------------------------------------------- #
def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Bundle CBN content packs into a Flutter app.")
    ap.add_argument("--rating", required=True, choices=("hot", "kid"))
    ap.add_argument("--dest", required=True, help="<app>/assets/packs")
    ap.add_argument("--source-root", default=None, help="override the staging root")
    ap.add_argument(
        "--no-pubspec", action="store_true", help="only write packs, leave pubspec alone"
    )
    ap.add_argument(
        "--proto-glob",
        default=PROTO_GLOB,
        help=f"hot only: which _proto folders to pack (default {PROTO_GLOB!r}; "
        "pass '*' to take every prototype folder that has an asset.json)",
    )
    args = ap.parse_args(argv)

    root = Path(args.source_root) if args.source_root else DEFAULT_ROOTS[args.rating]
    dest = Path(args.dest).resolve()

    log(f"rating      : {args.rating}")
    log(f"source root : {root}")
    log(f"destination : {dest}")

    index = build_packs(root, args.rating, dest, args.proto_glob)

    total = sum(len(c["assets"]) for c in index["collections"])
    log(f"\nindex.json  : {len(index['collections'])} collections, {total} assets")
    for c in index["collections"]:
        log(f"  {c['id']:<12} {len(c['assets'])} assets")

    if not args.no_pubspec:
        pubspec = dest.parent.parent / "pubspec.yaml"
        rewrite_pubspec(pubspec, pack_directories(dest, index))

    return 0 if total else 1


if __name__ == "__main__":
    sys.exit(main())
