import 'dart:convert';
import 'package:hive/hive.dart';
import 'cache_constants.dart';
import '../models/app_model.dart';
import '../models/issue_model.dart';
import '../models/build_model.dart';

class CacheService {
  static final CacheService instance = CacheService._();
  CacheService._();

  Future<void> openBoxes() async {
    await Future.wait([
      Hive.openBox<String>(CacheBoxes.apps),
      Hive.openBox<String>(CacheBoxes.issues),
      Hive.openBox<String>(CacheBoxes.builds),
      Hive.openBox<String>(CacheBoxes.sessions),
      Hive.openBox<String>(CacheBoxes.syncMeta),
    ]);
  }

  // ── Apps ─────────────────────────────────────────────

  Future<void> saveApps(List<Map<String, dynamic>> apps) async {
    final box = Hive.box<String>(CacheBoxes.apps);
    for (final app in apps) {
      final id = app['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        await box.put(id, jsonEncode(app));
      }
    }
  }

  List<AppModel> getApps() {
    final box = Hive.box<String>(CacheBoxes.apps);
    return box.values
        .map((json) => AppModel.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList();
  }

  // ── Issues ───────────────────────────────────────────

  Future<void> saveIssues(List<Map<String, dynamic>> issues) async {
    final box = Hive.box<String>(CacheBoxes.issues);
    for (final issue in issues) {
      final id = issue['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        await box.put(id, jsonEncode(issue));
      }
    }
  }

  List<IssueModel> getIssues({String? status}) {
    final box = Hive.box<String>(CacheBoxes.issues);
    var items = box.values
        .map((json) => IssueModel.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList();
    if (status != null) {
      items = items.where((i) => i.status == status).toList();
    }
    return items;
  }

  // ── Builds ───────────────────────────────────────────

  Future<void> saveBuilds(List<Map<String, dynamic>> builds) async {
    final box = Hive.box<String>(CacheBoxes.builds);
    for (final build in builds) {
      final id = build['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        await box.put(id, jsonEncode(build));
      }
    }
  }

  List<BuildModel> getBuilds({int? appId}) {
    final box = Hive.box<String>(CacheBoxes.builds);
    var items = box.values
        .map((json) => BuildModel.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList();
    if (appId != null) {
      items = items.where((b) => b.appId == appId).toList();
    }
    return items;
  }

  // ── Sessions ─────────────────────────────────────────

  Future<void> saveSessions(List<Map<String, dynamic>> sessions) async {
    final box = Hive.box<String>(CacheBoxes.sessions);
    for (final session in sessions) {
      final id = session['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        await box.put(id, jsonEncode(session));
      }
    }
  }

  // ── Deletions ────────────────────────────────────────

  Future<void> applyDeletions(List<Map<String, dynamic>> deleted) async {
    for (final entry in deleted) {
      final table = entry['table'] as String? ?? '';
      final recordId = entry['record_id']?.toString() ?? '';
      if (recordId.isEmpty) continue;

      final boxName = _tableToBox(table);
      if (boxName != null && Hive.isBoxOpen(boxName)) {
        await Hive.box<String>(boxName).delete(recordId);
      }
    }
  }

  String? _tableToBox(String table) {
    switch (table) {
      case 'apps':
        return CacheBoxes.apps;
      case 'issues':
        return CacheBoxes.issues;
      case 'builds':
        return CacheBoxes.builds;
      case 'autofix_sessions':
        return CacheBoxes.sessions;
      default:
        return null;
    }
  }

  // ── Sync Metadata ────────────────────────────────────

  String? getLastSyncTime() {
    final box = Hive.box<String>(CacheBoxes.syncMeta);
    return box.get('last_sync_time');
  }

  Future<void> setLastSyncTime(String time) async {
    final box = Hive.box<String>(CacheBoxes.syncMeta);
    await box.put('last_sync_time', time);
  }

  bool get hasCachedData {
    final box = Hive.box<String>(CacheBoxes.apps);
    return box.isNotEmpty;
  }

  Future<void> clearAll() async {
    await Hive.box<String>(CacheBoxes.apps).clear();
    await Hive.box<String>(CacheBoxes.issues).clear();
    await Hive.box<String>(CacheBoxes.builds).clear();
    await Hive.box<String>(CacheBoxes.sessions).clear();
    await Hive.box<String>(CacheBoxes.syncMeta).clear();
  }
}
