"""Game music with local ACE-Step, for any project (not tied to jigsaw collections).

Each track is one job through the GPU lane (jigsaw_music.generate holds it), so it
shows in the queue like every other heavy job. Tracks land in `out_dir` as
`<name>_00001_.mp3`; looping and loudness are the caller's job.
"""
from __future__ import annotations

import threading
import time
import uuid

from . import jigsaw_music as MZ

_ops: dict[str, dict] = {}
_lock = threading.Lock()


def start(tracks: list[dict], out_dir: str, seconds: float = 60.0) -> str:
    """tracks: [{"name": str, "tags": str}]. Returns an op id; runs in the background."""
    ok, err = MZ.model_ready()
    if not ok:
        raise ValueError(err)
    op_id = uuid.uuid4().hex[:10]
    with _lock:
        _ops[op_id] = {"id": op_id, "total": len(tracks), "done": 0, "files": [],
                       "errors": [], "started": time.time(), "finished": None}

    def run():
        for t in tracks:
            path, error = MZ.generate(out_dir, str(t.get("name", "track")), tags=str(t.get("tags", "")),
                                      seconds=float(t.get("seconds", seconds)), op_id=op_id)
            with _lock:
                op = _ops[op_id]
                op["done"] += 1
                if path:
                    op["files"].append(path)
                else:
                    op["errors"].append("%s: %s" % (t.get("name"), error[:200]))
        with _lock:
            _ops[op_id]["finished"] = time.time()

    threading.Thread(target=run, daemon=True, name="music-" + op_id).start()
    return op_id


def status(op_id: str) -> dict | None:
    with _lock:
        op = _ops.get(op_id)
        return dict(op) if op else None
