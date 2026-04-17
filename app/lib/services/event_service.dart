import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'app_state.dart';
import 'auth_service.dart';
import 'cache_service.dart';

/// Operation-log SSE consumer.
///
/// Opens a long-lived connection to `/api/events?client_id=<uuid>&last_seq=<N>`
/// and streams server-emitted ops into the Hive cache as they happen. Each
/// op applied bumps `last_seq` locally; a debounced ack POST tells the
/// server which seq the client has actually processed, so reconnects pick
/// up exactly where we left off.
///
/// No more snapshot dumps: the baseline state flows through the event log
/// itself. On first install the client sends `last_seq=0` and the server
/// streams enough ops to reconstruct current state. From then on, every
/// reconnect carries a real cursor and only the missing ops come across
/// the wire.
class EventService {
  EventService(this._appState);

  final AppState _appState;

  http.Client? _client;
  StreamSubscription<String>? _sub;
  Timer? _reconnectTimer;
  Timer? _ackTimer;
  Timer? _refreshTimer;
  bool _stopped = false;
  int _backoffSeconds = 1;
  int _pendingAckSeq = 0;

  void start() {
    _stopped = false;
    _connect();
  }

  void stop() {
    _stopped = true;
    _reconnectTimer?.cancel();
    _ackTimer?.cancel();
    _refreshTimer?.cancel();
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
      final clientId = await _ensureClientId();
      final lastSeq = CacheService.instance.getLastSeq();
      final email = AuthService.instance.userEmail ?? '';

      final uri = Uri.parse('$base/api/events').replace(queryParameters: {
        'client_id': clientId,
        'last_seq': '$lastSeq',
        if (email.isNotEmpty) 'email': email,
      });

      final req = http.Request('GET', uri);
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

      _backoffSeconds = 1;
      debugPrint('EventService: connected client_id=$clientId last_seq=$lastSeq');

      final buffer = StringBuffer();
      _sub = resp.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.isEmpty) {
            final frame = buffer.toString();
            buffer.clear();
            if (frame.isNotEmpty) _handleFrame(frame);
          } else if (line.startsWith(':')) {
            // SSE comment (heartbeat / hello) — ignore.
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

  // ── Frame parsing ──────────────────────────────────────────

  void _handleFrame(String frame) {
    int? seq;
    final dataLines = <String>[];
    for (final line in frame.split('\n')) {
      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      } else if (line.startsWith('id:')) {
        seq = int.tryParse(line.substring(3).trim());
      }
    }
    if (dataLines.isEmpty) return;
    try {
      final body = jsonDecode(dataLines.join('\n')) as Map<String, dynamic>;
      // Prefer the id: line, fall back to a seq field in the JSON body.
      final eventSeq = seq ?? (body['seq'] is int ? body['seq'] as int : null);
      _dispatch(body, eventSeq);
    } catch (e) {
      debugPrint('EventService: bad frame $e');
    }
  }

  // ── Op dispatch ────────────────────────────────────────────

  Future<void> _dispatch(Map<String, dynamic> event, int? seq) async {
    final type = event['type'] as String?;
    if (type == null) return;

    // Skip events the client has already consumed (e.g. covered by a
    // /api/sync that advanced last_seq while we were mid-replay).
    if (seq != null && seq <= CacheService.instance.getLastSeq()) return;

    try {
      switch (type) {
        case 'app.updated':
          final appJson = event['app'];
          if (appJson is Map) {
            await CacheService.instance
                .saveApps([Map<String, dynamic>.from(appJson)]);
            _scheduleRefresh();
          }
          break;

        case 'app.status_changed':
          final appId = _asInt(event['app_id']);
          final status = event['status'] as String?;
          if (appId != 0 && status != null) {
            await CacheService.instance.patchAppField(appId, 'status', status);
            _scheduleRefresh();
          }
          break;

        default:
          // Unknown op types are ignored so the client survives server
          // adding new event shapes before a matching client is deployed.
          break;
      }
    } catch (e) {
      debugPrint('EventService: dispatch failed for $type: $e');
      return;
    }

    if (seq != null && seq > CacheService.instance.getLastSeq()) {
      await CacheService.instance.setLastSeq(seq);
      _scheduleAck(seq);
    }
  }

  /// Coalesce a burst of cache writes into a single dashboard rebuild.
  /// Replay and baseline both land dozens of events back-to-back; without
  /// this, the dashboard would rebuild N times in ~100ms and flicker.
  void _scheduleRefresh() {
    if (_refreshTimer?.isActive ?? false) return;
    _refreshTimer = Timer(
        const Duration(milliseconds: AppConfig.eventRefreshDebounceMs), () {
      _refreshTimer = null;
      if (_stopped) return;
      _appState.refreshFromCache();
    });
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  // ── Ack debounce ───────────────────────────────────────────

  void _scheduleAck(int seq) {
    if (seq > _pendingAckSeq) _pendingAckSeq = seq;
    _ackTimer?.cancel();
    _ackTimer = Timer(
        const Duration(seconds: AppConfig.eventAckDebounceSeconds), _flushAck);
  }

  Future<void> _flushAck() async {
    final seq = _pendingAckSeq;
    if (seq <= 0) return;
    final base = AppConfig.baseUrl;
    if (base.isEmpty) return;
    try {
      final clientId = await _ensureClientId();
      final email = AuthService.instance.userEmail;
      final body = jsonEncode({
        'client_id': clientId,
        'last_seq': seq,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      final resp = await http.post(
        Uri.parse('$base/api/events/ack'),
        headers: {
          'Content-Type': 'application/json',
          if (AppConfig.apiKey.isNotEmpty) 'X-API-Key': AppConfig.apiKey,
        },
        body: body,
      );
      if (resp.statusCode != 200) {
        debugPrint('EventService: ack returned ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('EventService: ack failed $e');
    }
  }

  // ── Reconnect ──────────────────────────────────────────────

  void _scheduleReconnect() {
    _sub?.cancel();
    _sub = null;
    _client?.close();
    _client = null;
    if (_stopped) return;
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: _backoffSeconds);
    _backoffSeconds =
        (_backoffSeconds * 2).clamp(1, AppConfig.eventReconnectMaxBackoffSeconds);
    _reconnectTimer = Timer(delay, _connect);
  }

  // ── Client ID ──────────────────────────────────────────────

  Future<String> _ensureClientId() async {
    var id = CacheService.instance.getClientId();
    if (id.isEmpty) {
      id = _generateUuidV4();
      await CacheService.instance.setClientId(id);
    }
    return id;
  }

  String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final b = bytes.map(hex).toList();
    return '${b[0]}${b[1]}${b[2]}${b[3]}-${b[4]}${b[5]}-${b[6]}${b[7]}-${b[8]}${b[9]}-${b[10]}${b[11]}${b[12]}${b[13]}${b[14]}${b[15]}';
  }
}
