"""Append-only operation log used by the dashboard sync pipeline.

Every mutation that the phone cares about (task added, task status flipped,
app version bumped, build started, issue created) lands in this log as a
single JSONL line with a monotonic `seq` integer. The SSE endpoint replays
from disk on reconnect — so a client whose cache is stale just asks
"give me everything after seq N" and the server streams the missing ops one
by one. No snapshot diffing, no timestamp comparisons, no timezone games.

Design constraints:
- **Append-only.** Never seek, never rewrite. Crash-safe by construction
  (a half-written last line is detected on startup and truncated).
- **Bounded disk footprint.** Rotate when the current segment exceeds
  LOG_MAX_LINES. Archived segments are kept until every active client has
  advanced past them, then deleted.
- **Thread-safe.** FastAPI's event loop runs async handlers on one thread
  but deploy/build engines call in from worker threads. A single
  `threading.Lock` guards the append path — cheap because appends are fast.
- **Cheap live fan-out.** Append both persists to disk AND publishes to
  the in-memory event_bus so currently-connected SSE subscribers see the
  new event within milliseconds without re-reading the file.
"""

from __future__ import annotations

import json
import logging
import os
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator

from core.event_bus import event_bus

logger = logging.getLogger(__name__)

LOG_MAX_LINES = 5000  # rotate segments at ~5k entries
DATA_DIR = Path(__file__).resolve().parent.parent / "data"
ACTIVE_LOG_PATH = DATA_DIR / "event_log.jsonl"
ARCHIVE_GLOB = "event_log.*.jsonl"


def _utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


class EventLog:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._seq = 0
        self._line_count = 0
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        self._recover()

    def _recover(self) -> None:
        """On startup, scan the active segment to pick up the latest seq
        and count lines. Tolerates a half-written final line (drops it).
        """
        if not ACTIVE_LOG_PATH.exists():
            return
        lines_kept: list[str] = []
        last_seq = 0
        try:
            with open(ACTIVE_LOG_PATH, "r", encoding="utf-8") as f:
                for raw in f:
                    raw = raw.rstrip("\n")
                    if not raw:
                        continue
                    try:
                        entry = json.loads(raw)
                    except json.JSONDecodeError:
                        # Half-written final line — drop it.
                        continue
                    seq = entry.get("seq")
                    if isinstance(seq, int):
                        last_seq = max(last_seq, seq)
                        lines_kept.append(raw)
            if len(lines_kept) != sum(1 for _ in open(ACTIVE_LOG_PATH, "r", encoding="utf-8")):
                # We dropped a corrupt line — rewrite the file cleanly so
                # subsequent appends stay valid JSONL.
                with open(ACTIVE_LOG_PATH, "w", encoding="utf-8") as f:
                    for line in lines_kept:
                        f.write(line + "\n")
            self._seq = last_seq
            self._line_count = len(lines_kept)
            logger.info("event_log: recovered seq=%d line_count=%d", self._seq, self._line_count)
        except Exception as e:
            logger.warning("event_log: recovery failed, starting clean: %s", e)
            self._seq = 0
            self._line_count = 0

    def append(self, op_type: str, payload: dict[str, Any] | None = None) -> int:
        """Record a new op and broadcast it to live SSE subscribers.

        Returns the assigned seq. Safe to call from any thread.
        """
        with self._lock:
            self._seq += 1
            entry = {
                "seq": self._seq,
                "type": op_type,
                "ts": _utc_now(),
                **(payload or {}),
            }
            try:
                with open(ACTIVE_LOG_PATH, "a", encoding="utf-8") as f:
                    f.write(json.dumps(entry, ensure_ascii=False) + "\n")
                self._line_count += 1
            except Exception as e:
                logger.error("event_log: append failed: %s", e)
                return self._seq
            if self._line_count >= LOG_MAX_LINES:
                try:
                    self._rotate_locked()
                except Exception as e:
                    logger.warning("event_log: rotate failed: %s", e)

        # Fan out to live subscribers AFTER releasing the lock so a slow
        # subscriber can't stall new writers.
        event_bus.publish(op_type, entry)
        return entry["seq"]

    def replay_since(self, since_seq: int) -> Iterator[dict[str, Any]]:
        """Yield every logged event with seq > since_seq, in order.

        Reads from the active segment plus any archived segments whose
        highest seq is > since_seq. Returns an iterator so the SSE handler
        can stream without loading everything into memory.
        """
        archive_files = sorted(DATA_DIR.glob(ARCHIVE_GLOB))
        for path in archive_files:
            yield from self._replay_file(path, since_seq)
        if ACTIVE_LOG_PATH.exists():
            yield from self._replay_file(ACTIVE_LOG_PATH, since_seq)

    def _replay_file(self, path: Path, since_seq: int) -> Iterator[dict[str, Any]]:
        try:
            with open(path, "r", encoding="utf-8") as f:
                for raw in f:
                    raw = raw.rstrip("\n")
                    if not raw:
                        continue
                    try:
                        entry = json.loads(raw)
                    except json.JSONDecodeError:
                        continue
                    seq = entry.get("seq", 0)
                    if seq > since_seq:
                        yield entry
        except FileNotFoundError:
            return

    @property
    def current_seq(self) -> int:
        return self._seq

    def _rotate_locked(self) -> None:
        """Move the active segment to an archive file and start fresh.
        Must be called while holding self._lock."""
        if not ACTIVE_LOG_PATH.exists():
            return
        stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        archive_name = f"event_log.{stamp}.jsonl"
        archive_path = DATA_DIR / archive_name
        try:
            os.replace(ACTIVE_LOG_PATH, archive_path)
            self._line_count = 0
            logger.info("event_log: rotated to %s", archive_name)
        except Exception as e:
            logger.warning("event_log: rotate failed: %s", e)

    def prune_archives(self, min_active_seq: int) -> int:
        """Delete archived segments whose highest seq is <= min_active_seq.

        Called periodically with `min(cursors.values())` so we only drop
        segments every active client has already consumed. Returns the
        number of files removed.
        """
        removed = 0
        for path in sorted(DATA_DIR.glob(ARCHIVE_GLOB)):
            try:
                # Read just the last line to learn the highest seq in this archive.
                with open(path, "rb") as f:
                    f.seek(0, os.SEEK_END)
                    size = f.tell()
                    if size == 0:
                        path.unlink(missing_ok=True)
                        removed += 1
                        continue
                    # Walk back to find the last newline.
                    chunk = min(4096, size)
                    f.seek(size - chunk)
                    tail = f.read().decode("utf-8", errors="ignore").rstrip("\n")
                last_line = tail.rsplit("\n", 1)[-1]
                try:
                    entry = json.loads(last_line)
                except json.JSONDecodeError:
                    continue
                last_seq = entry.get("seq", 0)
                if last_seq <= min_active_seq:
                    path.unlink(missing_ok=True)
                    removed += 1
            except Exception as e:
                logger.debug("prune_archives: %s failed: %s", path.name, e)
        return removed


event_log = EventLog()
