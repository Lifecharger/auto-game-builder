"""Keep a local, byte-for-byte mirror of every live R2 bucket.

Why: the user wants to browse the buckets on disk (`D:/Reusable Assets/r2buckets/
<bucket>/<key>`), laid out exactly as they are in R2. Only the buckets that stay
after the legacy retirement are mirrored (registry: server/config/r2_buckets.json,
role "content"); private and legacy buckets are skipped.

What it does per bucket: list every object, download the ones that are missing
locally or whose size differs, into the same relative path. Downloads go to a
temp file first and are renamed when complete, so an interrupted run never
leaves half a file that later looks "current". Nothing local is ever deleted
unless `--prune` is given, and then a file that vanished from R2 is MOVED into
`<root>/_pruned/<bucket>/` rather than removed.

    python tools/r2/mirror_buckets.py                 # every live bucket
    python tools/r2/mirror_buckets.py --bucket cards  # one bucket
    python tools/r2/mirror_buckets.py --prune         # also park files gone from R2
    python tools/r2/mirror_buckets.py --root E:/r2    # another mirror root

Rerun any time: unchanged files are skipped by size, so a refresh costs one
listing per bucket plus whatever is new.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import r2_s3  # noqa: E402

REGISTRY = HERE.parent.parent / "server" / "config" / "r2_buckets.json"
DEFAULT_ROOT = Path(r"D:/Reusable Assets/r2buckets")
WORKERS = 8


def live_buckets() -> list[str]:
    reg = json.loads(REGISTRY.read_text(encoding="utf-8"))
    return [b["name"] for b in reg.get("buckets", []) if b.get("role") == "content"]


def _download(bucket: str, obj: dict, dest: Path) -> int:
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_name(dest.name + ".part")
    data = r2_s3.get_object(bucket, obj["key"], timeout=600)
    if len(data) != obj["size"]:
        raise RuntimeError(f"{obj['key']}: got {len(data)} bytes, listing says {obj['size']}")
    tmp.write_bytes(data)
    os.replace(tmp, dest)
    return len(data)


def mirror_bucket(bucket: str, root: Path, prune: bool, log) -> dict:
    local = root / bucket
    local.mkdir(parents=True, exist_ok=True)
    log(f"== {bucket}: listing...")
    remote = list(r2_s3.list_all(bucket))
    remote_keys = {o["key"] for o in remote}
    total_bytes = sum(o["size"] for o in remote)
    todo = []
    for o in remote:
        if not o["key"] or o["key"].endswith("/"):
            continue
        dest = local / Path(*o["key"].split("/"))
        if dest.is_file() and dest.stat().st_size == o["size"]:
            continue
        todo.append((o, dest))
    log(f"   {len(remote)} objects, {total_bytes/1e9:.2f} GB on R2; "
        f"{len(todo)} to fetch ({sum(o['size'] for o, _ in todo)/1e9:.2f} GB)")

    fetched = failed = 0
    fetched_bytes = 0
    lock = threading.Lock()
    started = time.time()
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futures = {pool.submit(_download, bucket, o, d): o for o, d in todo}
        for i, fut in enumerate(as_completed(futures), 1):
            o = futures[fut]
            try:
                n = fut.result()
                with lock:
                    fetched += 1
                    fetched_bytes += n
            except Exception as e:  # keep going; the summary names the failures
                with lock:
                    failed += 1
                log(f"   FAIL {o['key']}: {e}")
            if i % 200 == 0 or i == len(todo):
                el = time.time() - started
                log(f"   {i}/{len(todo)} files, {fetched_bytes/1e9:.2f} GB, "
                    f"{fetched_bytes/1e6/max(el,1):.1f} MB/s")

    pruned = 0
    if prune:
        park = root / "_pruned" / bucket
        for p in local.rglob("*"):
            if not p.is_file() or p.name.endswith(".part"):
                continue
            key = p.relative_to(local).as_posix()
            if key not in remote_keys:
                target = park / p.relative_to(local)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(p), str(target))
                pruned += 1
        if pruned:
            log(f"   parked {pruned} local files that are no longer on R2 -> {park}")

    return {"bucket": bucket, "remote_objects": len(remote), "remote_bytes": total_bytes,
            "fetched": fetched, "fetched_bytes": fetched_bytes, "failed": failed,
            "pruned": pruned, "seconds": round(time.time() - started, 1)}


def main() -> None:
    global WORKERS
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=str(DEFAULT_ROOT))
    ap.add_argument("--bucket", action="append", help="mirror only this bucket (repeatable)")
    ap.add_argument("--prune", action="store_true")
    ap.add_argument("--workers", type=int, default=WORKERS)
    args = ap.parse_args()

    WORKERS = max(1, args.workers)
    root = Path(args.root)
    root.mkdir(parents=True, exist_ok=True)
    logf = open(root / "_mirror.log", "a", encoding="utf-8")

    def log(msg: str) -> None:
        line = time.strftime("%Y-%m-%d %H:%M:%S ") + msg
        print(line, flush=True)
        logf.write(line + "\n")
        logf.flush()

    buckets = args.bucket or live_buckets()
    log(f"mirror -> {root}  buckets: {', '.join(buckets)}")
    results = []
    for b in buckets:
        try:
            results.append(mirror_bucket(b, root, args.prune, log))
        except Exception as e:
            log(f"== {b}: FAILED {e}")
            results.append({"bucket": b, "error": str(e)})
    state = {"updated": time.strftime("%Y-%m-%dT%H:%M:%S"), "root": str(root), "buckets": results}
    (root / "_mirror_state.json").write_text(json.dumps(state, indent=1), encoding="utf-8")
    log("done: " + "; ".join(
        f"{r['bucket']} {r.get('fetched', '?')} new/{r.get('failed', 0)} failed" for r in results))


if __name__ == "__main__":
    main()
