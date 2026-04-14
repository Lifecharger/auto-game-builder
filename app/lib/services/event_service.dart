import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'app_state.dart';
import 'cache_service.dart';
import 'sync_service.dart';

/// Server-Sent Events consumer.
///
/// Opens a single long-lived HTTP connection to `/api/events` on startup
/// and holds it for the life of the app. Every frame pushed by the server
/// is parsed, applied straight to the Hive cache, and broadcast via
/// `AppState.notifyListeners()` — so edits made on disk show up on the
/// dashboard in ~100ms without waiting for the next 15-second poll.
///
/// On connection drop (backgrounding, tunnel restart, network flap) the
/// service reconnects with exponential backoff and runs a single catchup
/// delta sync so anything that happened during the outage still lands in
/// the cache.
class EventService {
  EventService(this._appState);

  final AppState _appState;

  http.Client? _client;
  StreamSubscription<String>? _sub;
  Timer? _reconnectTimer;
  bool _stopped = false;
  int _backoffSeconds = 1;

  void start() {
    _stopped = false;
    _connect();
  }

  void stop() {
    _stopped = true;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _client?.close();
    _client = null;
    _sub = null;
  }

  Future<void> _connect() async {
    if (_stopped) return;
    final base = AppConfig.baseUrl;
    if (base.isEmpty) {
      _scheduleReconnect();
      return;
    }

    _client?.close();
    _client = http.Client();

    try {
      final req = http.Request('GET', Uri.parse('$base/api/events'));
      req.headers['Accept'] = 'text/event-stream';
      req.headers['Cache-Control'] = 'no-cache';
      if (AppConfig.apiKey.isNotEmpty) {
        req.headers['X-API-Key'] = AppConfig.apiKey;
      }

      final resp = await _client!.send(req);
      if (resp.statusCode != 200) {
        debugPrint('EventService: /api/events returned ${resp.statusCode}');
        _scheduleReconnect();
        return;
      }

      // We're connected — reset the backoff and run a catchup delta sync
      // so anything that happened while we were disconnected still lands
      // in the cache.
      _backoffSeconds = 1;
      unawaited(SyncService.instance.sync().then((ok) {
        if (ok) _appState.refreshFromCache();
      }));

      final buffer = StringBuffer();
      _sub = resp.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.isEmpty) {
            // Empty line = end of one event frame.
            final frame = buffer.toString();
            buffer.clear();
            if (frame.isNotEmpty) _handleFrame(frame);
          } else if (line.startsWith(':')) {
            // Comment / heartbeat — ignore.
          } else {
            buffer.writeln(line);
          }
        },
        onError: (err) {
          debugPrint('EventService: stream error $err');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('EventService: stream closed');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('EventService: connect failed $e');
      _scheduleReconnect();
    }
  }

  void _handleFrame(String frame) {
    // A frame is one or more lines. We only care about `data:` lines —
    // concatenate any consecutive ones, JSON-decode, dispatch.
    final dataLines = <String>[];
    for (final line in frame.split('\n')) {
      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }
    if (dataLines.isEmpty) return;
    try {
      final json = jsonDecode(dataLines.join('\n')) as Map<String, dynamic>;
      _dispatch(json);
    } catch (e) {
      debugPrint('EventService: bad frame $e');
    }
  }

  void _dispatch(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'app_updated':
        final appJson = event['app'];
        if (appJson is Map) {
          final id = appJson['id']?.toString() ?? '';
          if (id.isEmpty) return;
          unawaited(
            CacheService.instance
                .saveApps([Map<String, dynamic>.from(appJson)])
                .then((_) => _appState.refreshFromCache()),
          );
        }
        break;

      case 'app_status_changed':
        // Light-touch patch: mutate just the status field of the cached
        // app so the dashboard card colour flips without losing any other
        // data we already have in cache.
        final appId = event['app_id'];
        final status = event['status'] as String?;
        if (appId == null || status == null) return;
        unawaited(
          CacheService.instance
              .patchAppField(appId is int ? appId : int.tryParse(appId.toString()) ?? 0, 'status', status)
              .then((_) => _appState.refreshFromCache()),
        );
        break;

      case 'issue_updated':
      case 'build_added':
        // For anything not covered by a dedicated handler yet, run a
        // lightweight delta sync — still much cheaper than waiting for
        // the 15s poll.
        unawaited(SyncService.instance.sync().then((ok) {
          if (ok) _appState.refreshFromCache();
        }));
        break;

      default:
        // Unknown event types are silently ignored so the client can
        // survive new event types being added server-side.
        break;
    }
  }

  void _scheduleReconnect() {
    _sub?.cancel();
    _sub = null;
    _client?.close();
    _client = null;
    if (_stopped) return;
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: _backoffSeconds);
    _backoffSeconds = (_backoffSeconds * 2).clamp(1, 30);
    _reconnectTimer = Timer(delay, _connect);
  }
}
