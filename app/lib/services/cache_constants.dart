class CacheBoxes {
  static const String apps = 'apps_cache';
  static const String issues = 'issues_cache';
  static const String builds = 'builds_cache';
  static const String sessions = 'sessions_cache';
  static const String syncMeta = 'sync_meta';
  static const String appIcons = 'app_icons';
  /// Per-app long-form docs (GDD, CLAUDE.md) and other detail-screen
  /// payloads that are too big to ship through /api/sync but still
  /// benefit from a cache-first render.
  static const String appDocs = 'app_docs';
  /// Per-app tasklist.json snapshots + Last-Modified header for conditional
  /// GET. Keyed by `app_<id>` (tasks JSON) and `app_<id>_lm` (last-modified).
  static const String tasks = 'tasks_cache';
}
