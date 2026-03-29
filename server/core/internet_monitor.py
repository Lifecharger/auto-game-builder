"""Internet connectivity monitor with background polling."""

import threading
import time
import urllib.request
from typing import Callable, Optional


class InternetMonitor:
    def __init__(self, check_url: str = "https://api.anthropic.com", interval: int = 30):
        self.check_url = check_url
        self.interval = interval
        self._online = True
        self._callbacks: list[Callable[[bool], None]] = []
        self._thread: Optional[threading.Thread] = None
        self._stop = threading.Event()

    @property
    def is_online(self) -> bool:
        return self._online

    def start(self):
        self._stop.clear()
        self._thread = threading.Thread(target=self._poll_loop, daemon=True)
        self._thread.start()

    def stop(self):
        self._stop.set()

    def on_status_change(self, callback: Callable[[bool], None]):
        self._callbacks.append(callback)

    def wait_for_connection(self, timeout: int = 300) -> bool:
        """Block until online or timeout. Returns True if connected."""
        start = time.time()
        while not self._online and (time.time() - start) < timeout:
            time.sleep(5)
            self._check_once()
        return self._online

    def _poll_loop(self):
        while not self._stop.is_set():
            old = self._online
            self._check_once()
            if old != self._online:
                for cb in self._callbacks:
                    try:
                        cb(self._online)
                    except Exception:
                        pass
            self._stop.wait(self.interval)

    def _check_once(self):
        try:
            req = urllib.request.Request(self.check_url, method="HEAD")
            urllib.request.urlopen(req, timeout=5)
            self._online = True
        except Exception:
            self._online = False
