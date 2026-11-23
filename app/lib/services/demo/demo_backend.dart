import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../models/store_status.dart';
import 'demo_data.dart';
import 'demo_mode.dart';

/// A running simulated build.
class _DemoRun {
  final int appId;
  final String track;
  final String target;
  final bool upload;
  final DateTime startedAt;
  final Duration length;
  final String newVersion;
  bool finished = false;
  bool cancelled = false;

  _DemoRun(this.appId, this.track, this.target, this.upload, this.length, this.newVersion)
      : startedAt = DateTime.now();

  double get progress =>
      (DateTime.now().difference(startedAt).inMilliseconds / length.inMilliseconds).clamp(0.0, 1.0);
}

/// The AGB server, simulated in memory for demo mode.
///
/// Answers the routes the app uses with the same JSON shapes as
/// server/api/server.py. State changes (tasks, deploys, promotes, ...) live in
/// memory only and are forgotten when the demo ends. Requests to any other
/// host (none are made by the demo screens) go to the normal network client.
class DemoBackend extends http.BaseClient {
  DemoBackend._();
  static final DemoBackend instance = DemoBackend._();

  final http.Client _passthrough = IOClient();

  late List<DemoApp> _apps;
  late List<Map<String, dynamic>> _reports;
  late List<Map<String, dynamic>> _notices;
  final List<Map<String, dynamic>> _builds = [];
  final List<Map<String, dynamic>> _promotions = [];
  final Map<int, _DemoRun> _runs = {};
  final Map<String, String> _docs = {};
  int _nextId = 1000;
  bool _ready = false;

  /// Fresh sample data, and one build already running so the live build
  /// screen has something to show.
  void reset() {
    _apps = buildDemoApps();
    _reports = buildDemoReports();
    _notices = buildDemoNotices();
    _builds.clear();
    _promotions.clear();
    _runs.clear();
    _docs.clear();
    _nextId = 1000;
    final now = DateTime.now();
    var id = 1;
    for (final a in _apps) {
      for (var i = 0; i < 3; i++) {
        final t = now.subtract(Duration(days: 1 + i * 3 + a.id, hours: a.id));
        _builds.add(_buildDict(id++, a.id, i == 2 && a.id == 2 ? 'failed' : 'success',
            a.version.split('+').first, t, 140 + i * 17 + a.id * 9));
      }
    }
    _startRun(_app(2)!, 'internal', 'aab', true, const Duration(seconds: 90));
    _ready = true;
  }

  // ── http.BaseClient ─────────────────────────────────────────

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.host != DemoMode.demoHost) return _passthrough.send(request);
    if (!_ready) reset();
    final path = request.url.path;
    if (path == '/api/events') return _eventStream(request);
    final body = request is http.Request ? request.body : '';
    Object? json;
    if (body.isNotEmpty) {
      try {
        json = jsonDecode(body);
      } on FormatException {
        json = null;
      }
    }
    _tick();
    final res = _route(request.method, request.url, json);
    final bytes = utf8.encode(jsonEncode(res.body));
    return http.StreamedResponse(
      Stream.value(bytes),
      res.status,
      contentLength: bytes.length,
      request: request,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }

  @override
  void close() {
    // Shared for the whole demo: the top-level http helpers close the client
    // after every call, which must not end the demo.
  }

  /// A server-sent-event stream that stays open with heartbeats and carries
  /// no events (the app re-reads demo data through its normal polling).
  http.StreamedResponse _eventStream(http.BaseRequest request) {
    late StreamController<List<int>> c;
    Timer? beat;
    c = StreamController<List<int>>(
      onListen: () {
        c.add(utf8.encode(': demo\n\n'));
        beat = Timer.periodic(const Duration(seconds: 15), (_) => c.add(utf8.encode(': ping\n\n')));
      },
      onCancel: () {
        beat?.cancel();
        return c.close();
      },
    );
    return http.StreamedResponse(c.stream, 200,
        request: request, headers: const {'content-type': 'text/event-stream'});
  }

  // ── Routing ─────────────────────────────────────────────────

  _Res _route(String method, Uri url, Object? body) {
    final seg = url.pathSegments.where((s) => s.isNotEmpty).toList();
    final q = url.queryParameters;
    final b = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    if (seg.isEmpty || seg.first != 'api') return _Res.notFound();
    final p = seg.skip(1).toList();
    final key = p.isEmpty ? '' : p.first;

    switch (key) {
      case 'health':
        return _Res.ok({'status': 'ok', 'time': demoIso(DateTime.now())});
      case 'me':
        return _Res.ok({'id': 2, 'name': 'Demo', 'role': 'member', 'is_admin': false});
      case 'sync':
        return _Res.ok({
          'apps': _apps.map(_appDict).toList(),
          'issues': const [],
          'builds': _builds.reversed.toList(),
          'sessions': const [],
          'deleted': const [],
          'server_time': demoIso(DateTime.now()),
          'event_seq': 0,
        });
      case 'dashboard':
        return _Res.ok({
          'total_apps': _apps.length,
          'total_open_issues': 0,
          'apps': _apps.map(_appDict).toList(),
        });
      case 'apps':
        return _routeApps(method, p, q, b);
      case 'builds':
        if (p.length == 2) {
          final id = int.tryParse(p[1]);
          final hit = _builds.where((x) => x['id'] == id);
          return hit.isEmpty ? _Res.notFound() : _Res.ok(hit.first);
        }
        final appId = int.tryParse(q['app_id'] ?? '');
        final list = _builds.where((x) => appId == null || x['app_id'] == appId).toList().reversed;
        return _Res.ok(list.take(int.tryParse(q['limit'] ?? '') ?? 20).toList());
      case 'issues':
        return method == 'GET' ? _Res.ok(const []) : _Res.ok({'ok': true});
      case 'sessions':
      case 'ideas':
        return _Res.ok(const []);
      case 'logs':
        return _Res.ok(_logs(int.tryParse(q['app_id'] ?? '')));
      case 'reports':
        return _routeReports(method, p, b);
      case 'notices':
        return _routeNotices(method, p, b);
      case 'automations':
        return _routeAutomations(method, p);
      case 'events':
        return _Res.ok({'ok': true});
      case 'chat':
        return _Res.ok({
          'response': 'This is the demo. On your own AGB server, your AI agent answers here '
              'with full knowledge of the selected project.',
          'session_id': 'demo',
        });
      case 'mcp':
        return _Res.ok(const []);
      case 'store-status':
        return _Res.ok({'queued': _apps.length});
    }
    return _Res.notFound();
  }

  _Res _routeApps(String method, List<String> p, Map<String, String> q, Map<String, dynamic> b) {
    if (p.length == 1) {
      if (method == 'POST') {
        final id = _apps.map((a) => a.id).reduce((a, c) => a > c ? a : c) + 1;
        final name = (b['name'] ?? 'New Game').toString();
        final app = DemoApp(
          id: id,
          name: name,
          slug: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
          appType: (b['app_type'] ?? 'flutter').toString(),
          packageName: 'com.example.${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}',
          version: '0.1.0+1',
          publishStatus: 'development',
          store: DemoStore(play: [], apple: [], appleBuilds: [], refreshedAt: DateTime.now()),
          tasks: [],
        );
        _apps.add(app);
        return _Res.ok(_appDict(app));
      }
      return _Res.ok(_apps.map(_appDict).toList());
    }
    final a = _app(int.tryParse(p[1]));
    if (a == null) return _Res.notFound();
    if (p.length == 2) {
      if (method == 'PATCH') {
        if (b['notes'] is String) a.notes = b['notes'] as String;
        if (b['publish_status'] is String) a.publishStatus = b['publish_status'] as String;
        _touch(a);
        return _Res.ok({'status': 'ok'});
      }
      if (method == 'DELETE') return _Res.ok({'status': 'ok'});
      return _Res.ok({..._appDict(a), 'total_issues': 0});
    }
    final sub = p[2];
    final rest = p.skip(3).toList();
    switch (sub) {
      case 'tasks':
        return _routeTasks(a, method, rest, q, b);
      case 'deploy':
        return _routeDeploy(a, method, rest, b);
      case 'build-targets':
        return _Res.ok({
          'app_type': a.appType,
          'targets': a.appType == 'godot'
              ? {'apk': 'APK', 'aab': 'AAB (Play Store)', 'ios': 'iOS', 'dual': 'Dual (AAB + iOS)'}
              : {'apk': 'APK', 'aab': 'AAB (Play Store)', 'ios': 'iOS', 'dual': 'Dual (AAB + iOS)', 'web': 'Web'},
        });
      case 'store-status':
        if (rest.isNotEmpty && rest.first == 'refresh') a.store.refreshedAt = DateTime.now();
        return _Res.ok({'app_id': a.id, ..._storeStatus(a)});
      case 'promote':
        return _promote(a, b);
      case 'submit-for-review':
        return _submit(a, b);
      case 'promotions':
        return _Res.ok(_promotions.where((x) => x['app_id'] == a.id).toList().reversed.toList());
      case 'gdd':
      case 'claude-md':
      case 'agents-md':
      case 'art-bible':
        final docKey = '${a.id}/$sub';
        if (method == 'PUT') {
          _docs[docKey] = (b['content'] ?? '').toString();
          return _Res.ok({'status': 'ok', 'ok': true});
        }
        final content = _docs[docKey] ??
            (sub == 'gdd' ? a.gdd : sub == 'claude-md' ? a.claudeMd : '');
        return _Res.ok({'content': content, 'exists': content.isNotEmpty});
      case 'enhance':
        return _Res.ok({'status': rest.isEmpty ? 'started' : 'idle'});
      case 'mcp':
        return _Res.ok({'app_id': a.id, 'mcp_servers': const []});
      case 'detect-engine':
        return _Res.ok({'app_type': a.appType, 'previous': a.appType, 'changed': false});
    }
    return _Res.notFound();
  }

  // ── Tasks ───────────────────────────────────────────────────

  _Res _routeTasks(DemoApp a, String method, List<String> rest, Map<String, String> q,
      Map<String, dynamic> b) {
    if (rest.isEmpty) {
      if (method == 'POST') {
        final now = demoIso(DateTime.now());
        a.tasks.add({
          'id': _nextId++,
          'title': (b['title'] ?? '').toString(),
          'description': (b['description'] ?? '').toString(),
          'type': (b['task_type'] ?? 'feature').toString(),
          'task_type': (b['task_type'] ?? 'feature').toString(),
          'priority': (b['priority'] ?? 'medium').toString(),
          'status': 'pending',
          'source': 'manual',
          'response': '',
          'ai_response': '',
          'issue_id': 0,
          'created_at': now,
          'updated_at': now,
          'completed_at': '',
          'built_version': '',
          'agent': 'claude',
          'blocked_by': <int>[],
          'blocked': false,
        });
        _touch(a);
        return _Res.ok({'ok': true});
      }
      final status = q['status'];
      return _Res.ok(a.tasks.where((t) => status == null || t['status'] == status).toList());
    }
    if (rest.first == 'status') return _Res.ok(_taskStatus(a));
    if (rest.first == 'search') {
      final needle = (q['q'] ?? '').toLowerCase();
      return _Res.ok(a.tasks
          .where((t) => '${t['title']} ${t['description']}'.toLowerCase().contains(needle))
          .toList());
    }
    if (rest.first == 'archive') return _Res.ok({'ok': true});
    final id = int.tryParse(rest.first);
    final task = a.tasks.where((t) => t['id'] == id).firstOrNull;
    if (task == null) return _Res.notFound();
    final now = demoIso(DateTime.now());
    if (rest.length > 1 && rest[1] == 'run') {
      task['status'] = 'in_progress';
      task['started_at'] = now;
      task['demo_run'] = true;
      task['updated_at'] = now;
      _touch(a);
      return _Res.ok({'ok': true, 'message': 'Agent started'});
    }
    if (method == 'PATCH') {
      b.forEach((k, v) => task[k] = v);
      task['updated_at'] = now;
      if (b['status'] == 'in_progress') task['started_at'] = now;
      if (b['status'] == 'completed') task['completed_at'] = now;
      _touch(a);
      return _Res.ok(task);
    }
    if (method == 'DELETE') {
      a.tasks.remove(task);
      _touch(a);
      return _Res.ok({'ok': true});
    }
    return _Res.ok(task);
  }

  Map<String, int> _taskStatus(DemoApp a) {
    int n(String s) => a.tasks.where((t) => t['status'] == s).length;
    return {
      'total': a.tasks.length,
      'completed': n('completed'),
      'built': n('built'),
      'divided': 0,
      'pending': n('pending'),
      'in_progress': n('in_progress'),
      'failed': n('failed'),
      'urgent': a.tasks.where((t) => t['priority'] == 'urgent').length,
      'blocked': 0,
    };
  }

  // ── Deploy (simulated build) ────────────────────────────────

  void _startRun(DemoApp a, String track, String target, bool upload, Duration length) {
    final parts = a.version.split('+');
    final nums = parts.first.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (nums.length < 3) {
      nums.add(0);
    }
    nums[2] += 1;
    final code = (int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0) + 1;
    _runs[a.id] = _DemoRun(a.id, track, target, upload, length, '${nums.join('.')}+$code');
    a.status = 'building';
    _touch(a);
  }

  Map<String, dynamic> _runStatus(_DemoRun r) {
    final p = r.progress;
    String phase;
    String message;
    if (r.cancelled) {
      phase = 'failed';
      message = 'Cancelled';
    } else if (p < 0.05) {
      phase = 'starting';
      message = 'Starting ${r.target.toUpperCase()} build...';
    } else if (p < 0.8) {
      phase = 'building';
      final i = (((p - 0.05) / 0.75) * demoBuildSteps.length).floor().clamp(0, demoBuildSteps.length - 1).toInt();
      message = '${demoBuildSteps[i]}...';
    } else if (p < 1 && r.upload) {
      phase = 'uploading';
      message = 'Uploading to ${r.target == 'ios' ? 'TestFlight' : 'Google Play'} (${r.track})...';
    } else {
      phase = 'done';
      message = r.upload
          ? 'Deployed to ${r.track}: v${r.newVersion.split('+').first}'
          : 'Build finished: v${r.newVersion.split('+').first}';
    }
    return {
      'app_id': r.appId,
      'track': r.track,
      'build_target': r.target,
      'upload': r.upload,
      'phase': phase,
      'message': message,
      'started_at': demoIso(r.startedAt),
      'build_id': null,
      'attempt': 1,
      'max_retries': 2,
    };
  }

  List<String> _runLog(_DemoRun r) {
    final shown = (r.progress * (demoBuildSteps.length + 2)).floor();
    final lines = <String>['[demo] build ${r.target} for ${r.track}'];
    for (var i = 0; i < demoBuildSteps.length && i < shown; i++) {
      lines.add('[${demoIso(r.startedAt.add(Duration(milliseconds: (r.length.inMilliseconds * i / demoBuildSteps.length).round())))}] ${demoBuildSteps[i]}');
    }
    if (r.finished) lines.add(_runStatus(r)['message'] as String);
    return lines;
  }

  /// Finishes simulated builds whose time is up and simulated agent tasks.
  void _tick() {
    for (final r in _runs.values) {
      if (r.finished || r.cancelled || r.progress < 1) continue;
      r.finished = true;
      final a = _app(r.appId);
      if (a == null) continue;
      a.version = r.newVersion;
      a.status = 'idle';
      final version = r.newVersion.split('+').first;
      final code = int.tryParse(r.newVersion.split('+').last) ?? 0;
      _builds.add(_buildDict(_nextId++, a.id, 'success', version, r.startedAt, r.length.inSeconds));
      if (r.upload && r.target != 'ios') {
        a.lastUploadTrack = r.track;
        a.store.play.removeWhere((e) => e['track'] == r.track);
        a.store.play.add({'track': r.track, 'version': version, 'code': code, 'codes': [code],
          'name': version, 'status': 'completed'});
      }
      if (r.upload && (r.target == 'ios' || r.target == 'dual')) {
        a.lastIosUploadTrack = r.track;
        a.store.appleBuilds.insert(0, {
          'build_id': 'demo-b$code', 'version': version, 'build': '$code', 'processing': 'VALID',
          'expired': false, 'uploaded_at': demoIsoZ(DateTime.now()),
          'internal_state': 'IN_BETA_TESTING', 'external_state': 'READY_FOR_BETA_SUBMISSION',
        });
        a.store.apple.add({'track': 'testflight', 'version': version, 'build': '$code',
          'status': 'IN_BETA_TESTING', 'build_id': 'demo-b$code'});
      }
      a.store.refreshedAt = DateTime.now();
      for (final t in a.tasks.where((t) => t['status'] == 'completed')) {
        t['status'] = 'built';
        t['built_version'] = version;
      }
      _touch(a);
    }
    final now = DateTime.now();
    for (final a in _apps) {
      for (final t in a.tasks.where((t) => t['status'] == 'in_progress' && t['started_at'] != null)) {
        final started = DateTime.tryParse('${t['started_at']}Z');
        if (started != null && now.difference(started) > const Duration(seconds: 40) &&
            t['demo_run'] == true) {
          t['status'] = 'completed';
          t['completed_at'] = demoIso(now);
          t['response'] = 'Done in the demo: the agent would implement and test this on your server.';
          _touch(a);
        }
      }
    }
  }

  _Res _routeDeploy(DemoApp a, String method, List<String> rest, Map<String, dynamic> b) {
    final run = _runs[a.id];
    if (rest.isEmpty && method == 'POST') {
      if (run != null && !run.finished && !run.cancelled) {
        return _Res(400, {'detail': 'A build is already running for this app'});
      }
      _startRun(a, (b['track'] ?? 'internal').toString(), (b['build_target'] ?? 'aab').toString(),
          b['upload'] == true, const Duration(seconds: 45));
      return _Res.ok({'ok': true, 'message': 'Build queued (demo)'});
    }
    if (rest.isNotEmpty && rest.first == 'status') {
      if (run == null) return _Res.ok({'phase': 'none', 'message': 'No active deploy'});
      return _Res.ok(_runStatus(run));
    }
    if (rest.isNotEmpty && rest.first == 'cancel') {
      if (run != null && !run.finished) {
        run.cancelled = true;
        a.status = 'idle';
        _touch(a);
      }
      return _Res.ok({'ok': true, 'message': 'Cancelled'});
    }
    if (rest.isNotEmpty && rest.first == 'retry-upload') {
      return _Res.ok({'ok': true, 'message': 'Re-uploading (demo)'});
    }
    return _Res.notFound();
  }

  // ── Stores ──────────────────────────────────────────────────

  Map<String, dynamic> _storeStatus(DemoApp a) {
    final s = a.store;
    final refreshed = demoIsoZ(s.refreshedAt);
    Map<String, dynamic>? displayOf(String store, List<Map<String, dynamic>> entries) =>
        pickDisplay(store, entries.map(StoreEntry.fromJson).toList())?.toJson();
    final out = <String, dynamic>{};
    if (s.play.isNotEmpty) {
      out['play'] = {
        'display': displayOf('play', s.play),
        'entries': s.play,
        'refreshed_at': refreshed,
        'error': '',
        'error_at': null,
      };
    }
    if (s.apple.isNotEmpty || s.appleBuilds.isNotEmpty) {
      final live = s.apple.where((e) => e['track'] == 'live').toList();
      out['apple'] = {
        'display': displayOf('apple', s.apple),
        'entries': s.apple,
        'refreshed_at': refreshed,
        'error': '',
        'error_at': null,
        'live': live.isEmpty ? null : live.first,
        'editable_version': s.editableVersion,
        'builds': s.appleBuilds,
      };
    }
    return out;
  }

  _Res _promote(DemoApp a, Map<String, dynamic> b) {
    final store = (b['store'] ?? 'play').toString();
    if (store == 'play') {
      final from = (b['from'] ?? 'internal').toString();
      final to = (b['to'] ?? 'production').toString();
      final src = a.store.play
          .where((e) => e['track'] == from && playLiveStatuses.contains(e['status']))
          .toList();
      if (src.isEmpty) return _Res(400, {'detail': "No live release on the '$from' track to promote"});
      final rel = Map<String, dynamic>.from(src.first)..['track'] = to..['status'] = 'completed';
      a.store.play.removeWhere((e) => e['track'] == to);
      a.store.play.add(rel);
      a.store.refreshedAt = DateTime.now();
      if (to == 'production') a.lastUploadTrack = 'production';
      _record(a, 'play', 'promote', from, to, rel['version'] as String);
      _touch(a);
      return _Res.ok({
        'ok': true,
        'store': 'play',
        'result': {'version': rel['version'], 'version_codes': rel['codes'], 'status': 'completed'},
        'store_status': _storeStatus(a),
      });
    }
    final builds = a.store.appleBuilds.where((x) => x['processing'] == 'VALID' && x['expired'] != true);
    final wanted = b['build_id'];
    final build = wanted == null
        ? builds.firstOrNull
        : builds.where((x) => x['build_id'] == wanted).firstOrNull;
    if (build == null) return _Res(400, {'detail': 'No processed TestFlight build to attach'});
    final created = a.store.editableVersion == null;
    a.store.editableVersion = {
      'version_id': a.store.editableVersion?['version_id'] ?? 'demo-v${build['build']}',
      'version': build['version'],
      'state': 'PREPARE_FOR_SUBMISSION',
      'build_id': build['build_id'],
      'build': build['build'],
    };
    a.store.apple.removeWhere((e) => e['track'] == 'prepare');
    a.store.apple.add({'track': 'prepare', 'version': build['version'], 'build': build['build'],
      'status': 'PREPARE_FOR_SUBMISSION', 'build_id': build['build_id']});
    a.store.refreshedAt = DateTime.now();
    _record(a, 'apple', 'attach', 'testflight', 'app_store', build['version'] as String);
    _touch(a);
    return _Res.ok({
      'ok': true,
      'store': 'apple',
      'result': {
        'version': build['version'],
        'build': build['build'],
        'build_id': build['build_id'],
        'version_id': a.store.editableVersion!['version_id'],
        'created_version': created,
      },
      'store_status': _storeStatus(a),
    });
  }

  _Res _submit(DemoApp a, Map<String, dynamic> b) {
    if (b['confirm'] != true) return _Res(400, {'detail': 'Submitting for review needs confirm: true'});
    final v = a.store.editableVersion;
    if (v == null) return _Res(400, {'detail': 'No App Store version waiting to be submitted'});
    if (v['build_id'] == null) return _Res(400, {'detail': 'Version ${v['version']} has no build attached'});
    a.store.apple.removeWhere((e) => e['track'] == 'prepare');
    a.store.apple.add({'track': 'review', 'version': v['version'], 'build': v['build'],
      'status': 'WAITING_FOR_REVIEW', 'build_id': v['build_id']});
    a.store.editableVersion = null;
    a.store.refreshedAt = DateTime.now();
    _record(a, 'apple', 'submit_for_review', 'app_store', 'review', v['version'] as String);
    _touch(a);
    return _Res.ok({
      'ok': true,
      'result': {'version': v['version'], 'build': v['build'], 'version_id': v['version_id'],
        'submission_id': 'demo-sub'},
      'store_status': _storeStatus(a),
    });
  }

  void _record(DemoApp a, String store, String action, String from, String to, String version) {
    _promotions.add({
      'id': _nextId++, 'app_id': a.id, 'store': store, 'action': action, 'from_track': from,
      'to_track': to, 'version': version, 'build_ref': '', 'status': 'ok', 'error': '',
      'user_id': 2, 'user_name': 'Demo', 'created_at': demoIso(DateTime.now()),
    });
  }

  // ── Reports, notes, automations, logs ───────────────────────

  _Res _routeReports(String method, List<String> p, Map<String, dynamic> b) {
    if (p.length == 1) return _Res.ok(_reports);
    if (p[1] == 'count') {
      return _Res.ok({'open': _reports.where((r) => r['status'] == 'open').length, 'total': _reports.length});
    }
    if (p[1] == 'pull') return _Res.ok({'new': 0});
    final r = _reports.where((x) => x['id'] == p[1]).firstOrNull;
    if (r == null) return _Res.notFound();
    if (method == 'PATCH') {
      b.forEach((k, v) => r[k] = v);
      if (b['status'] == 'closed') r['closed_at'] = demoIso(DateTime.now());
    } else if (method == 'DELETE') {
      _reports.remove(r);
    }
    return _Res.ok({'ok': true});
  }

  _Res _routeNotices(String method, List<String> p, Map<String, dynamic> b) {
    if (p.length == 1) {
      if (method == 'POST') return _Res.ok({'ok': true});
      return _Res.ok(_notices);
    }
    if (p[1] == 'count') {
      return _Res.ok({'unread': _notices.where((n) => n['read'] != true).length, 'total': _notices.length});
    }
    final id = int.tryParse(p[1]);
    final n = _notices.where((x) => x['id'] == id).firstOrNull;
    if (n == null) return _Res.notFound();
    if (method == 'PATCH') {
      if (b.containsKey('read')) n['read'] = b['read'] == true;
    } else if (method == 'DELETE') {
      _notices.remove(n);
    }
    return _Res.ok({'ok': true});
  }

  _Res _routeAutomations(String method, List<String> p) {
    if (p.length == 1) {
      if (method == 'POST') return _Res.ok({'ok': true});
      return _Res.ok(_apps.take(2).map((a) => {
            'app_id': a.id,
            'app_name': a.name,
            'app_type': a.appType,
            'ai_agent': 'claude',
            'interval_minutes': 60,
            'max_session_minutes': 30,
            'prompt_preview': 'Work through the pending tasks of ${a.name}, test, and report.',
            'mcp_servers': const <String>[],
            'running': _runs[a.id] != null && !_runs[a.id]!.finished && !_runs[a.id]!.cancelled,
          }).toList());
    }
    final a = _app(int.tryParse(p[1]));
    if (a == null) return _Res.notFound();
    if (p.length > 2 && p[2] == 'status') {
      final run = _runs[a.id];
      return _Res.ok({
        'app_id': a.id,
        'running': run != null && !run.finished && !run.cancelled,
        'pid': null,
        'running_tasks': a.tasks.where((t) => t['status'] == 'in_progress').map((t) => t['title']).toList(),
        'log': run == null ? const <String>[] : _runLog(run),
      });
    }
    return _Res.ok({'ok': true, 'message': 'Done (demo)'});
  }

  List<Map<String, dynamic>> _logs(int? appId) {
    final out = <Map<String, dynamic>>[];
    for (final bld in _builds.reversed) {
      if (appId != null && bld['app_id'] != appId) continue;
      final a = _app(bld['app_id'] as int);
      out.add({
        'app_name': a?.name ?? '',
        'app_id': bld['app_id'],
        'message': '${bld['build_type']} build v${bld['version']} ${bld['status']}',
        'level': bld['status'] == 'failed' ? 'error' : 'info',
        'timestamp': bld['completed_at'],
        'source': 'build',
        'exit_code': bld['status'] == 'failed' ? 1 : 0,
        'status': bld['status'],
      });
    }
    return out.take(50).toList();
  }

  // ── Dicts ───────────────────────────────────────────────────

  DemoApp? _app(int? id) => _apps.where((a) => a.id == id).firstOrNull;

  void _touch(DemoApp a) => a.updatedAt = demoIso(DateTime.now());

  Map<String, dynamic> _buildDict(int id, int appId, String status, String version, DateTime start, int secs) => {
        'id': id,
        'app_id': appId,
        'build_type': 'aab',
        'version': version,
        'status': status,
        'output_path': '',
        'duration_seconds': secs,
        'started_at': demoIso(start),
        'completed_at': demoIso(start.add(Duration(seconds: secs))),
        'created_at': demoIso(start),
        'updated_at': demoIso(start.add(Duration(seconds: secs))),
        'started_by_user_id': 2,
        'started_by': 'Demo',
      };

  Map<String, dynamic> _appDict(DemoApp a) {
    final last = _builds.where((x) => x['app_id'] == a.id).lastOrNull;
    return {
      'id': a.id,
      'name': a.name,
      'slug': a.slug,
      'project_path': '/projects/${a.slug}',
      'app_type': a.appType,
      'current_version': a.version,
      'package_name': a.packageName,
      'status': a.status,
      'publish_status': a.publishStatus,
      'fix_strategy': 'claude',
      'notes': a.notes,
      'group_name': '',
      'icon_path': '',
      'last_build_at': last?['completed_at'],
      'last_fix_at': null,
      'automation_script_path': '',
      'github_url': '',
      'play_store_url': '',
      'website_url': '',
      'console_url': '',
      'last_upload_track': a.lastUploadTrack,
      'last_upload_at': last?['completed_at'] ?? '',
      'last_ios_upload_track': a.lastIosUploadTrack,
      'last_ios_upload_at': '',
      'last_ios_build_status': a.lastIosUploadTrack.isEmpty ? '' : 'success',
      'apple_app_id': '',
      'app_store_url': '',
      'owner_user_id': 2,
      'play_account': '',
      'created_at': demoIso(DateTime.now().subtract(const Duration(days: 90))),
      'updated_at': a.updatedAt,
      'open_issues': 0,
      'last_build_status': last?['status'] ?? '',
      'store_status': _storeStatus(a),
      'task_status': _taskStatus(a),
    };
  }
}

class _Res {
  final int status;
  final Object body;
  const _Res(this.status, this.body);
  factory _Res.ok(Object body) => _Res(200, body);
  factory _Res.notFound() => const _Res(404, {'detail': 'Not available in the demo'});
}
