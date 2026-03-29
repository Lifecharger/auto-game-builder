"""Log file management: create, list, read, search, cleanup."""

import os
import re
import glob
from datetime import datetime


ANSI_ESCAPE = re.compile(r"\x1b\[[0-9;]*m")


class LogManager:
    def __init__(self, log_dir: str):
        self.log_dir = log_dir
        os.makedirs(log_dir, exist_ok=True)

    def create_log(self, app_slug: str) -> tuple[str, object]:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        path = os.path.join(self.log_dir, f"session_{app_slug}_{timestamp}.log")
        fh = open(path, "w", encoding="utf-8")
        return path, fh

    def list_logs(self, app_slug: str = None) -> list[dict]:
        pattern = f"session_{app_slug}_*.log" if app_slug else "session_*.log"
        files = glob.glob(os.path.join(self.log_dir, pattern))
        files.sort(key=os.path.getmtime, reverse=True)
        result = []
        for f in files:
            name = os.path.basename(f)
            parts = name.replace("session_", "").replace(".log", "").rsplit("_", 2)
            result.append({
                "path": f,
                "name": name,
                "slug": parts[0] if parts else "",
                "size": os.path.getsize(f),
                "modified": datetime.fromtimestamp(os.path.getmtime(f)).isoformat(),
            })
        return result

    def read_log(self, path: str) -> str:
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                content = f.read()
            return ANSI_ESCAPE.sub("", content)
        except Exception as e:
            return f"Error reading log: {e}"

    def search_logs(self, query: str, app_slug: str = None) -> list[dict]:
        results = []
        for log_info in self.list_logs(app_slug):
            content = self.read_log(log_info["path"])
            if query.lower() in content.lower():
                # Find matching lines
                matches = []
                for i, line in enumerate(content.split("\n"), 1):
                    if query.lower() in line.lower():
                        matches.append({"line_num": i, "text": line[:200]})
                results.append({**log_info, "matches": matches[:10]})
        return results

    def cleanup(self, max_per_app: int = 100):
        # Group by app slug
        by_slug: dict[str, list[str]] = {}
        for log_info in self.list_logs():
            slug = log_info.get("slug", "unknown")
            by_slug.setdefault(slug, []).append(log_info["path"])

        for slug, paths in by_slug.items():
            if len(paths) > max_per_app:
                for old_path in paths[max_per_app:]:
                    try:
                        os.remove(old_path)
                    except Exception:
                        pass
