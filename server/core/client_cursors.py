"""Per-client sync cursor store.

Keeps track of "how far has each phone/desktop client actually acknowledged
the event log?" Stored as a small JSON file so it survives server restart.

Each client is identified by a UUID generated on first launch (plus an
optional human-readable email label from Google sign-in, for debugging).
The cursor advances only when the client POSTs /api/events/ack — not just
when the server sends — so if the client crashes mid-apply, the next
connect replays from the last successfully-processed seq.

File shape:
    {
      "a4f8b3e1-...": {"email": "you@example.com", "last_seq": 1247, "last_seen": "2026-04-14 17:30:12"},
      "c7d2e4f9-...": {"email": null,              "last_seq": 1203, "last_seen": "2026-04-12 09:00:00"}
    }
"""

from __future__ import annotations

import json
import logging
import os
import tempfile
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
CURSORS_PATH = DATA_DIR / "client_cursors.json"


def _utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


class ClientCursorStore:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._data: dict[str, dict] = {}
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        self._load()

    def _load(self) -> None:
        if not CURSORS_PATH.exists():
            return
        try:
            with open(CURSORS_PATH, "r", encoding="utf-8") as f:
                raw = json.load(f)
            if isinstance(raw, dict):
                self._data = raw
        except Exception as e:
            logger.warning("client_cursors: load failed: %s", e)
            self._data = {}

    def _save_locked(self) -> None:
        """Atomic write: temp file in same dir then os.replace."""
        payload = json.dumps(self._data, ensure_ascii=False, indent=2)
        fd, tmp_path = tempfile.mkstemp(dir=DATA_DIR, suffix=".tmp", prefix=".cursors_")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                f.write(payload)
            os.replace(tmp_path, CURSORS_PATH)
        except Exception:
            try:
                os.unlink(tmp_path)
            except Exception:
                pass
            raise

    def get(self, client_id: str) -> int:
        with self._lock:
            entry = self._data.get(client_id)
            return entry.get("last_seq", 0) if entry else 0

    def update(self, client_id: str, last_seq: int, email: Optional[str] = None) -> None:
        with self._lock:
            entry = self._data.setdefault(client_id, {})
            # Never regress the cursor — guards against out-of-order acks.
            if last_seq > entry.get("last_seq", 0):
                entry["last_seq"] = last_seq
            if email:
                entry["email"] = email
            entry["last_seen"] = _utc_now()
            try:
                self._save_locked()
            except Exception as e:
                logger.warning("client_cursors: save failed: %s", e)

    def touch(self, client_id: str, email: Optional[str] = None) -> None:
        """Record that we saw this client without advancing its cursor.
        Used on SSE connect so we know the client is alive."""
        with self._lock:
            entry = self._data.setdefault(client_id, {"last_seq": 0})
            if email:
                entry["email"] = email
            entry["last_seen"] = _utc_now()
            try:
                self._save_locked()
            except Exception as e:
                logger.warning("client_cursors: save failed: %s", e)

    def min_active_seq(self, stale_after_seconds: int = 86400) -> int:
        """Return the lowest last_seq across all clients we've heard from
        recently. Used by event_log.prune_archives to decide which archive
        segments can be deleted — only those every active client has
        already consumed.
        """
        cutoff = datetime.now(timezone.utc).timestamp() - stale_after_seconds
        with self._lock:
            alive: list[int] = []
            for entry in self._data.values():
                last_seen = entry.get("last_seen", "")
                try:
                    ts = datetime.strptime(last_seen, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc).timestamp()
                except ValueError:
                    continue
                if ts >= cutoff:
                    alive.append(entry.get("last_seq", 0))
            return min(alive) if alive else 0

    def snapshot(self) -> dict[str, dict]:
        with self._lock:
            return {cid: dict(entry) for cid, entry in self._data.items()}


client_cursors = ClientCursorStore()
