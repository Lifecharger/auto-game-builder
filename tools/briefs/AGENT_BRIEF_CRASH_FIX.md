# Brief: fix every real crash / error in your apps (2026-09-26)

The user: "find and fix all bugs and errors first. And fix all crashes."

## Evidence (read before touching code)
Scratchpad = <scratchpad> (the orchestrating session's scratchpad folder, given when the brief is handed out)
- `errors/<app>.md` - every uncaught Dart error our analytics caught since 2026-09-01, ONE row per
  (version, signature), SYMBOLIZED to function + file:line (paths are relative to lib/ or pub-cache).
  Many rows are from old builds - check the CURRENT code before "fixing" something already fixed.
- `vitals_issues.txt` - Google Play Vitals crashes and ANRs (native / Java) with sample stacks.
- `analytics/com.lifecharger.<app>.json` -> `stability` block: `died_at` = where a run DIED ON SCREEN
  (last action + memory in MB at death, client 2026-09-24+), `died_memory`, `start_buckets` (cold start),
  `by_version`. Deaths at 450-900 MB with no Dart error are out-of-memory kills: the fix is memory
  (decode images at display size - `cacheWidth`/`ResizeImage`, don't hold full-res bitmaps of every
  card, dispose controllers/players, evict image cache on screen exit), not a try/catch.
- Re-run the decoder if you need more stacks: `python <scratchpad>/symbolize_all.py` (D1 via wrangler +
  NDK llvm-symbolizer; symbols in <AGB repo>/server/data/symbols/<pkg>/<versionCode>/).

## Rules
- Fix the ROOT cause. A try/catch that swallows an error silently is hiding it (CLAUDE.md). Where an
  external call can legitimately fail (image picker cancelled / permission denied, network font fetch,
  decode of a corrupt file) handle it: user-facing message or a real fallback path, plus a debugPrint.
- NO builds, NO deploys, NO git commits, NO emulator/device, NO GUI input. Edit only your apps' folders.
- Keep `flutter analyze` free of new errors/warnings and each app's full `flutter test` green
  (<flutter> = engines.flutter_path in server/config/settings.json). Add a regression test where the app already tests that code.
- Do not change files under lib/event_minigames/ (the shared module is handled by the main session).
- Do not change lib/services/lifecharger_analytics.dart (synced from a shared client).
- Track work in each app's tasklist.json: one task per fix, int id = max+1, status "completed",
  positive wording (what the app now does), never mention deploys/production; do not set "built".
- Unpublished apps have no players: no save-migration work there.

## Report (short)
Per app: each error/crash -> cause -> fix (file:line) or "already fixed in current code" / "not
fixable in app (why)"; memory/start-time changes with before/after reasoning; test counts.
