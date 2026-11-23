"""Who may call which route (multi-user AGB).

Admins may call everything. Members are DEFAULT-DENY: a route is open to them
only when it matches ``MEMBER_ROUTES`` below; every other /api route (settings,
users, GPU/ComfyUI queue, workers/R2, Cloudflare, delivery, asset flows, MCP,
chat, reports pull, server reset, ...) answers 403. New server-wide routes are
therefore admin-only until someone adds them here on purpose.

Per-object routes name the object in the path. The check loads it and answers
404 - not 403 - when it belongs to another user, so a member can't even learn
that another user's app id exists.

List routes (``/api/apps``, ``/api/builds``, ``/api/sync``, ...) are allowed
here and filtered to the member's own apps inside their handlers.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Optional

ANY = None  # any HTTP method


@dataclass(frozen=True)
class Rule:
    methods: Optional[frozenset]
    pattern: re.Pattern
    check: Optional[str] = None  # None | app | build | issue | notice | report


def _r(methods, pattern, check=None) -> Rule:
    ms = frozenset(methods) if methods else None
    return Rule(ms, re.compile(r"^" + pattern + r"$"), check)


_APP = r"(?P<app_id>\d+)"

# Per-app sub-routes a member may NOT call even on an own app: they write the
# server's MCP servers (which carry the admin's paid API keys) into the project.
MEMBER_APP_DENY = (
    _r({"PUT"}, r"/api/apps/\d+/mcp"),
)

MEMBER_ROUTES = (
    _r({"GET"}, r"/api/me"),
    _r({"GET"}, r"/api/sync"),
    _r({"GET"}, r"/api/events"),
    _r({"POST"}, r"/api/events/ack"),
    _r({"GET"}, r"/api/dashboard"),
    # Apps: list is filtered; a created app is owned by its creator.
    _r({"GET", "POST"}, r"/api/apps"),
    _r(ANY, r"/api/apps/" + _APP + r"(?:/.*)?", "app"),
    # Automations of own apps (list filtered, create checks body.app_id).
    _r({"GET", "POST"}, r"/api/automations"),
    _r(ANY, r"/api/automations/" + _APP + r"(?:/.*)?", "app"),
    # Builds, issues, autofix sessions, completion logs, ideas: filtered.
    _r({"GET"}, r"/api/builds"),
    _r({"GET"}, r"/api/builds/(?P<build_id>\d+)", "build"),
    _r({"GET", "POST"}, r"/api/issues"),
    _r(ANY, r"/api/issues/(?P<issue_id>\d+)", "issue"),
    _r({"GET"}, r"/api/sessions"),
    _r({"GET"}, r"/api/logs"),
    _r({"GET"}, r"/api/ideas"),
    # Store status pull-to-refresh: refreshes only the caller's own apps.
    _r({"POST"}, r"/api/store-status/refresh"),
    # Own notes (notices.user_id).
    _r({"GET", "POST"}, r"/api/notices"),
    _r({"GET"}, r"/api/notices/count"),
    _r({"PATCH", "DELETE"}, r"/api/notices/(?P<notice_id>\d+)", "notice"),
    # Player reports of own apps (pulling from the worker stays admin-only).
    _r({"GET"}, r"/api/reports"),
    _r({"GET"}, r"/api/reports/count"),
    _r({"GET"}, r"/api/reports/(?P<report_id>[A-Za-z0-9_-]+)/shot/\d+", "report"),
    _r({"PATCH", "DELETE"}, r"/api/reports/(?P<report_id>[A-Za-z0-9_-]+)", "report"),
)


@dataclass
class Denial:
    status: int
    message: str


NOT_FOUND = "Not found"
ADMIN_ONLY = "Admin only"


def owns_app(db, user, app_id) -> bool:
    if app_id is None:
        return False
    a = db.get_app(int(app_id))
    return a is not None and int(getattr(a, "owner_user_id", 1) or 1) == user.id


def _object_ok(db, user, check: str, groups: dict) -> bool:
    if check == "app":
        return owns_app(db, user, groups["app_id"])
    if check == "build":
        b = db.get_build(int(groups["build_id"]))
        return b is not None and owns_app(db, user, b.app_id)
    if check == "issue":
        i = db.get_issue(int(groups["issue_id"]))
        return i is not None and owns_app(db, user, i.app_id)
    if check == "notice":
        n = db.get_notice(int(groups["notice_id"]))
        return n is not None and n.get("user_id") == user.id
    if check == "report":
        r = db.get_report(groups["report_id"])
        return r is not None and owns_app(db, user, r.get("app_id"))
    return False


def check_member(db, user, method: str, path: str) -> Optional[Denial]:
    """None when ``user`` (a member) may call ``method path``, else a Denial."""
    method = method.upper()
    for rule in MEMBER_APP_DENY:
        if rule.pattern.match(path) and (rule.methods is None or method in rule.methods):
            # Hide the app's existence first, then refuse the action.
            m = re.match(r"^/api/apps/(\d+)/", path)
            if m and not owns_app(db, user, m.group(1)):
                return Denial(404, NOT_FOUND)
            return Denial(403, ADMIN_ONLY)
    for rule in MEMBER_ROUTES:
        m = rule.pattern.match(path)
        if not m:
            continue
        if rule.methods is not None and method not in rule.methods:
            continue
        if rule.check and not _object_ok(db, user, rule.check, m.groupdict()):
            return Denial(404, NOT_FOUND)
        return None
    return Denial(403, ADMIN_ONLY)


def check(db, user, method: str, path: str) -> Optional[Denial]:
    if user is None:
        return Denial(401, "Invalid or missing API key")
    if user.is_admin:
        return None
    return check_member(db, user, method, path)
