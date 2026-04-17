import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'cache_constants.dart';
import '../models/app_model.dart';
import '../models/issue_model.dart';
import '../models/build_model.dart';

class CacheService {
  static final CacheService instance = CacheService._();
  CacheService._();

  /// Bump this whenever AppModel/IssueModel/BuildModel JSON shape changes in a
  /// way that makes old cache entries semantically stale (e.g. a new field that
  /// the dashboard relies on). On mismatch, openBoxes() wipes the cache and
  /// forces the next sync to fetch a fresh full snapshot.
  static const int _schemaVersion = 5;

  static const List<String> _boxNames = [
    CacheBoxes.apps,
    CacheBoxes.issues,
    CacheBoxes.builds,
    CacheBoxes.sessions,
    CacheBoxes.syncMeta,
  ];

  Future<void> openBoxes() async {
    try {
      await _openAllBoxes();
    } catch (e, st) {
      debugPrint('CacheService: Hive box open failed, wiping cache: $e\n$st');
      for (final name in _boxNames) {
        try {
          if (Hive.isBoxOpen(name)) {
            await Hive.box<String>(name).close();
          }
          await Hive.deleteBoxFromDisk(name);
        } catch (inner) {
          debugPrint('CacheService: failed to delete box $name: $inner');
        }
      }
      try {
        if (Hive.isBoxOpen(CacheBoxes.appIcons)) {
          await Hive.box<Uint8List>(CacheBoxes.appIcons).close();
        }
        await Hive.deleteBoxFromDisk(CacheBoxes.appIcons);
      } catch (inner) {
        debugPrint(
            'CacheService: failed to delete box ${CacheBoxes.appIcons}: $inner');
      }
      await _openAllBoxes();
      debugPrint('CacheService: recovered from corrupt Hive state');
    }
    await _migrateIfNeeded();
  }

  Future<void> _openAllBoxes() async {
    await Future.wait(_boxNames.map((n) => Hive.openBox<String>(n)));
    await Hive.openBox<Uint8List>(CacheBoxes.appIcons);
  }

  Future<void> _migrateIfNeeded() async {
    final box = Hive.box<String>(CacheBoxes.syncMeta);
    final stored = int.tryParse(box.get('schema_version') ?? '') ?? 0;
    if (stored != _schemaVersion) {
      // Preserve the per-install client_id across schema wipes — it
      // identifies the device to the server, not the data layout, and
      // wiping it would make this device look like a brand-new client
      // and lose its cursor history.
      final preservedClientId = box.get('client_id');
      await Hive.box<String>(CacheBoxes.apps).clear();
      await Hive.box<String>(CacheBoxes.issues).clear();
      await Hive.box<String>(CacheBoxes.builds).clear();
      await Hive.box<String>(CacheBoxes.sessions).clear();
      await box.clear();
      await box.put('schema_version', _schemaVersion.toString());
      if (preservedClientId != null && preservedClientId.isNotEmpty) {
        await box.put('client_id', preservedClientId);
      }
      // last_seq intentionally NOT preserved — the local cache is empty
      // so the next sync should start from 0 and rebuild state.
    }
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

  /// Merge a single field into a cached app entry without rewriting the
  /// whole object. Used by EventService for `app_status_changed` events
  /// where the server only sends the delta.
  Future<void> patchAppField(int appId, String field, dynamic value) async {
    if (appId == 0) return;
    final box = Hive.box<String>(CacheBoxes.apps);
    final raw = box.get(appId.toString());
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    map[field] = value;
    await box.put(appId.toString(), jsonEncode(map));
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

  /// Cheap count of cached builds — avoids deserializing every entry.
  int get buildCount => Hive.box<String>(CacheBoxes.builds).length;

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

  // ── Op-log sync state ────────────────────────────────────

  /// Highest op seq this client has successfully applied to its cache.
  /// Sent to /api/events as `last_seq` so the server only replays events
  /// the client hasn't already processed.
  int getLastSeq() {
    final box = Hive.box<String>(CacheBoxes.syncMeta);
    return int.tryParse(box.get('last_seq') ?? '') ?? 0;
  }

  Future<void> setLastSeq(int seq) async {
    final box = Hive.box<String>(CacheBoxes.syncMeta);
    await box.put('last_seq', seq.toString());
  }

  /// Per-install UUID used by the server to key each client's cursor in
  /// client_cursors.json. Generated once on first launch and kept for
  /// the life of this Hive cache.
  String getClientId() {
    final box = Hive.box<String>(CacheBoxes.syncMeta);
    return box.get('client_id') ?? '';
  }

  Future<void> setClientId(String id) async {
    final box = Hive.box<String>(CacheBoxes.syncMeta);
    await box.put('client_id', id);
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
    await Hive.box<Uint8List>(CacheBoxes.appIcons).clear();
  }

  // ── App icons ────────────────────────────────────────

  /// Returns cached icon bytes for [appId] when the cache entry was
  /// written for the same [iconPath] (so the cache is invalidated when
  /// the server's icon changes).
  Uint8List? getAppIcon(int appId, String iconPath) {
    final box = Hive.box<Uint8List>(CacheBoxes.appIcons);
    final bytes = box.get(_iconBytesKey(appId));
    final storedPath = box.get(_iconPathKey(appId));
    if (bytes == null) return null;
    final storedPathStr = storedPath == null
        ? ''
        : utf8.decode(storedPath, allowMalformed: true);
    if (storedPathStr != iconPath) return null;
    return bytes;
  }

  Future<void> setAppIcon(
      int appId, String iconPath, Uint8List bytes) async {
    final box = Hive.box<Uint8List>(CacheBoxes.appIcons);
    await box.put(_iconBytesKey(appId), bytes);
    await box.put(
        _iconPathKey(appId), Uint8List.fromList(utf8.encode(iconPath)));
  }

  String _iconBytesKey(int appId) => 'app_$appId';
  String _iconPathKey(int appId) => 'app_${appId}_path';
}
