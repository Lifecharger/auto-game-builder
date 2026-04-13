import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'cache_service.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final CacheService _cache = CacheService.instance;
  bool _syncing = false;

  bool get isSyncing => _syncing;

  Future<bool> sync() async {
    if (_syncing) return false;
    _syncing = true;

    try {
      final since = _cache.getLastSyncTime();
      final result = await ApiService.getSync(since: since);
      if (!result.ok) return false;

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

      return true;
    } catch (e) {
      debugPrint('Sync failed: $e');
      return false;
    } finally {
      _syncing = false;
    }
  }
}
