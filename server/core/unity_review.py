"""Bounded Unity editor reviews in the server-owned GPU lane; no release steps."""
import logging
import re
import subprocess
import threading
import uuid
from pathlib import Path

from config.settings_loader import get_settings
from core import gpu_lane

logger = logging.getLogger(__name__)
_lock = threading.Lock()
_jobs = {}


def command(project, method, log):
    if not re.fullmatch(r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)+", method):
        raise ValueError("Expected a fully qualified static Unity review method")
    executable = get_settings().get("unity_path", "")
    if not executable or not Path(executable).is_file():
        raise ValueError("Configured Unity executable is unavailable")
    if not (project / "ProjectSettings/ProjectVersion.txt").is_file():
        raise ValueError("Project is not a Unity project")
    return [executable, "-batchmode", "-projectPath", str(project),
            "-executeMethod", method, "-logFile", str(log)]


def start(app_id, name, project_path, method, timeout):
    project = Path(project_path).resolve()
    op_id = uuid.uuid4().hex
    log = project / "build/review" / ("unity-" + op_id + ".log")
    argv = command(project, method, log)
    with _lock:
        if any(j["app_id"] == app_id and j["status"] in ("queued", "running") for j in _jobs.values()):
            raise ValueError("A Unity review is already active for this project")
        ticket = gpu_lane.reserve("Unity review: " + name, kind="unity_review", op_id=op_id)
        _jobs[op_id] = dict(op_id=op_id, app_id=app_id, status="queued", ticket_id=ticket["id"], log=str(log))
    threading.Thread(target=_run, args=(op_id, ticket, project, argv, timeout), daemon=True).start()
    return get(op_id)


def _run(op_id, ticket, project, argv, timeout):
    try:
        with gpu_lane.hold_reserved(ticket):
            if (project / "Temp/UnityLockfile").exists():
                raise RuntimeError("Project already has an open Unity editor")
            Path(argv[-1]).parent.mkdir(parents=True, exist_ok=True)
            # A server restart loses the previous lane kind, so explicitly ask the
            # existing Comfy owner to free idle models after acquiring the lane.
            from core import comfy_gen
            comfy_gen.free_memory("Unity editor review")
            with _lock:
                _jobs[op_id]["status"] = "running"
            proc = subprocess.Popen(argv, cwd=str(project), stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            try:
                code = proc.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
                raise RuntimeError("Unity review exceeded its time limit")
            if code:
                raise RuntimeError("Unity review exited with code %s; inspect review log" % code)
            with _lock:
                _jobs[op_id].update(status="completed", exit_code=code)
    except Exception as exc:
        logger.exception("Unity review failed app_id=%s op_id=%s", _jobs[op_id]["app_id"], op_id)
        with _lock:
            _jobs[op_id].update(status="failed", error=str(exc))


def get(op_id):
    with _lock:
        if op_id not in _jobs:
            raise KeyError(op_id)
        return dict(_jobs[op_id])
