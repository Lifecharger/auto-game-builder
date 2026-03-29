"""Parse Google Play Console ANR reports into structured data."""

import re
from config.settings_loader import get_settings


class ANRParser:
    def parse(self, raw_text: str, package_prefix: str = "") -> dict:
        """Parse raw ANR text into structured data.

        Args:
            raw_text: Raw ANR report text.
            package_prefix: Package prefix to filter key frames (e.g. "com.example").
                            If empty, attempts to detect from ANR package field.
        """
        result = {
            "reason": "",
            "package": "",
            "thread": "",
            "key_frames": [],
            "full_trace": raw_text,
        }

        # Extract reason
        reason_match = re.search(r"Reason:\s*(.+)", raw_text)
        if reason_match:
            result["reason"] = reason_match.group(1).strip()

        # Extract package
        pkg_match = re.search(r"ANR in\s+(\S+)", raw_text)
        if pkg_match:
            result["package"] = pkg_match.group(1).strip()

        # Extract thread
        thread_match = re.search(r'"(main|[^"]+)"\s+(?:prio|tid)', raw_text)
        if thread_match:
            result["thread"] = thread_match.group(1)

        # Determine package prefix for filtering key frames
        if not package_prefix and result["package"]:
            # Use the first two segments of the package name as prefix
            parts = result["package"].split(".")
            if len(parts) >= 2:
                package_prefix = ".".join(parts[:2])

        # Extract key frames matching the package prefix
        if package_prefix:
            pattern = rf"at\s+({re.escape(package_prefix)}\.\S+)"
            frames = re.findall(pattern, raw_text)
        else:
            # Fallback: extract all "at" frames
            frames = re.findall(r"at\s+(\S+)", raw_text)

        result["key_frames"] = frames[:10]

        return result

    def to_issue_data(self, anr_data: dict, app_id: int) -> dict:
        """Convert parsed ANR into issue creation kwargs."""
        reason = anr_data.get("reason", "Unknown ANR")
        key_frames = anr_data.get("key_frames", [])

        if key_frames:
            target = key_frames[0].rsplit(".", 1)
            title = f"ANR: {reason[:60]} in {target[-1] if len(target) > 1 else key_frames[0]}"
        else:
            title = f"ANR: {reason[:80]}"

        description_parts = [f"**Reason:** {reason}"]
        if anr_data.get("thread"):
            description_parts.append(f"**Thread:** {anr_data['thread']}")
        if key_frames:
            description_parts.append("**Key frames:**")
            for frame in key_frames:
                description_parts.append(f"- `{frame}`")

        return {
            "app_id": app_id,
            "title": title[:200],
            "description": "\n".join(description_parts),
            "category": "anr",
            "priority": 1,
            "source": "anr_report",
            "raw_data": anr_data.get("full_trace", ""),
        }
