"""In-process pub/sub used by the /api/events SSE endpoint.

Any place in the server that mutates state the dashboard cares about calls
`event_bus.publish(event_type, payload)`. The SSE endpoint subscribes to the
bus, drains its queue, and streams every event to connected phones as
`text/event-stream` frames — so an edit made at 16:37:02 shows up on the
dashboard at 16:37:02 instead of waiting for the next 15-second poll.

Deliberately simple: no durability, no fan-out beyond the current process,
no ordering guarantees across subscribers. Every publish enqueues a shallow
copy onto each live subscriber's asyncio queue and returns. If a subscriber
is slow or dead, its queue fills up and publish drops the event for that
subscriber specifically — never blocks the publisher. On reconnect the
client runs a catchup delta sync against /api/sync so nothing is missed
across disconnects.
"""

from __future__ import annotations

import asyncio
import logging
from typing import Any

logger = logging.getLogger(__name__)

# Bounded per-subscriber queue — if a client can't keep up, we'd rather drop
# events than balloon memory. The client does a catchup delta sync on
# reconnect, so dropped events still get recovered eventually.
_QUEUE_MAX = 256


class EventBus:
    def __init__(self) -> None:
        self._subscribers: list[asyncio.Queue[dict[str, Any]]] = []
        self._lock = asyncio.Lock()

    async def subscribe(self) -> asyncio.Queue[dict[str, Any]]:
        queue: asyncio.Queue[dict[str, Any]] = asyncio.Queue(maxsize=_QUEUE_MAX)
        async with self._lock:
            self._subscribers.append(queue)
        return queue

    async def unsubscribe(self, queue: asyncio.Queue[dict[str, Any]]) -> None:
        async with self._lock:
            try:
                self._subscribers.remove(queue)
            except ValueError:
                pass

    def publish(self, event_type: str, payload: dict[str, Any] | None = None) -> None:
        """Fan-out a single event to every live subscriber.

        Safe to call from synchronous code — we schedule the actual put() on
        the running event loop. No-op when there's no running loop (e.g. at
        import time or inside a test that doesn't run the server).
        """
        event = {"type": event_type, **(payload or {})}
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            return
        loop.call_soon_threadsafe(self._broadcast_nowait, event)

    def _broadcast_nowait(self, event: dict[str, Any]) -> None:
        for queue in list(self._subscribers):
            try:
                queue.put_nowait(event)
            except asyncio.QueueFull:
                logger.debug("event_bus: dropping event for saturated subscriber %r", event.get("type"))


event_bus = EventBus()
