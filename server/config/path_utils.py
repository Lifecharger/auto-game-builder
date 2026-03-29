"""Cross-platform path utilities."""

import os
import platform
import re


def to_unix_path(path: str) -> str:
    """Convert a path to Git-Bash-compatible POSIX format.

    On Windows: C:\\Users\\foo -> /c/Users/foo
    On Linux/macOS: returns path unchanged.
    """
    if not path:
        return path
    if platform.system() != "Windows":
        return path
    path = path.replace("\\", "/")
    # Handle any drive letter (C:, D:, etc.)
    path = re.sub(r"^([A-Za-z]):", lambda m: "/" + m.group(1).lower(), path)
    return path


def to_native_path(path: str) -> str:
    """Convert a POSIX path back to the native OS format.

    On Windows: /c/Users/foo -> C:\\Users\\foo
    On Linux/macOS: returns path unchanged.
    """
    if not path:
        return path
    if platform.system() != "Windows":
        return path
    # Handle /c/... -> C:\...
    m = re.match(r"^/([a-zA-Z])/(.*)", path)
    if m:
        return f"{m.group(1).upper()}:\\{m.group(2).replace('/', os.sep)}"
    return path.replace("/", os.sep)
