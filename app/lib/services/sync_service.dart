import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'cache_service.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final CacheService _cache = CacheService.instance;
  bool _syncing = false;
  String? _lastError;

  bool get isSyncing => _syncing;

  /// Reason the most recent sync attempt failed, or null if the last attempt
  /// succeeded. Cleared at the start of every new sync.
  String? get lastError => _lastError;

  /// Returns `true` only when the server actually accepted the request and we
  /// wrote fresh data to the cache. On failure, [lastError] explains why.
  ///
  /// When [force] is true, the local cache is wiped and the request is sent
  /// without a `since` parameter — the server replies with the full snapshot
  /// from the database. Use this when the user explicitly asks for a hard
  /// refresh; normal periodic syncs should leave [force] false.
  Future<bool> sync({bool force = false}) async {
    if (_syncing) return false;
    _syncing = true;
    _lastError = null;

    try {
      if (force) {
        await _cache.clearAll();
      }
      final since = force ? null : _cache.getLastSyncTime();
      final result = await ApiService.getSync(since: since);
      if (!result.ok) {
        _lastError = result.error ?? 'Sync request failed';
        debugPrint('Sync failed: $_lastError');
        return false;
      }

      final data = result.data!;
      final apps = (data['apps'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final issues = (data['issues'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final builds = (data['builds'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final sessions = (data['sessions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final deleted = (data['deleted'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final serverTime = data['server_time'] as String? ?? '';

      await _cache.saveApps(apps);
      await _cache.saveIssues(issues);
      await _cache.saveBuilds(builds);
      await _cache.saveSessions(sessions);
      await _cache.applyDeletions(deleted);

      if (serverTime.isNotEmpty) {
        await _cache.setLastSyncTime(serverTime);
      }

      // Advance the event cursor to the server's current head so
      // EventService never replays events the sync already covered.
      // This eliminates the race where old replayed events overwrite
      // the fresh data we just wrote above.
      final eventSeq = data['event_seq'];
      if (eventSeq is int && eventSeq > _cache.getLastSeq()) {
        await _cache.setLastSeq(eventSeq);
      }

      return true;
    } catch (e) {
      _lastError = 'Sync error: $e';
      debugPrint(_lastError);
      return false;
    } finally {
      _syncing = false;
    }
  }
}
