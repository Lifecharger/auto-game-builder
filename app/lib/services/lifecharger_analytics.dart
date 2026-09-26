// Lifecharger first-party analytics client (canonical copy:
// C:/Cloudflare Workers/analytics/clients/flutter/lifecharger_analytics.dart).
//
// Anonymous by construction: a random install id generated on this device, the app version and
// the events below. No advertising id, no account, no device identifiers. Events are queued on
// disk, sent in batches to https://analytics.lifecharger.workers.dev/events and survive restarts
// and offline play. The player can switch reporting off (setEnabled(false)); the queue is dropped.
//
// Shared vocabulary (keep names identical across apps so the dashboard can compare them):
//   first_open                                   once per install
//   session_start {n}            session_end {seconds}
//   content_start / content_complete / content_abandon {collection, item, variant, seconds}
//   collection_open {collection} collection_unlock {collection, method}
//   purchase {product, amount}   store_view {screen}
//   ad_rewarded {placement}      ad_interstitial {placement}
//   coins_earned {source, amount} coins_spent {sink, amount}
//   daily_reward {dim: 'day_<n>'} streak {dim: '<n>'} notification_open {source}
//   feature_use {feature}        tutorial_step {dim: '<step>'}   settings_change {dim}
// Stability and performance, reported by the client itself (nothing to wire in the app):
//   app_start {amount: ms, dim: '<1s'|'1-2s'|'2-4s'|'4s+', basis: 'process'|'init'}  cold start to first frame
//   app_error {dim: '<Type> @ <frame>', source: 'flutter'|'async', stack}  uncaught errors, never the message text
//   ui_stall {amount: ms, dim: '2-5s'|'5s+'}     the UI thread stopped answering ('5s+' is ANR territory)
//   unclean_exit {dim: '<version that died>', last: '<last event>', rss: <MB>, secs: <seconds in session>}
//                                                the previous run died while ON SCREEN (crash / ANR / OOM kill).
//                                                The marker is cleared the moment the app leaves the foreground
//                                                (inactive / hidden / paused), so a swipe from recents is never one.
// Call Analytics.init AFTER installing your own FlutterError.onError / PlatformDispatcher.onError:
// the client chains to whatever handler it finds and never swallows an error.
// Anything else: Analytics.log('snake_case_name', {...}) — a `dim`/`feature`/`placement`/`product`/
// `source`/`sink`/`method`/`screen`/`result` string is what the dashboard groups by; `amount` is summed.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Analytics with WidgetsBindingObserver {
  Analytics._();
  static final Analytics instance = Analytics._();

  static const String endpoint = 'https://analytics.lifecharger.workers.dev/events';
  static const String _kInstallId = 'lc_analytics_install_id';
  static const String _kQueue = 'lc_analytics_queue_v1';
  static const String _kEnabled = 'lc_analytics_enabled';
  static const String _kSessions = 'lc_analytics_session_count';
  static const String _kForeground = 'lc_analytics_foreground_version';
  static const int _maxErrorsPerSession = 5;
  static const int _stallReportMs = 2000;
  static const int _anrMs = 5000;
  static const int _maxQueued = 500;
  static const int _batchSize = 50;
  static const int _flushAt = 20;
  static const Duration _flushEvery = Duration(seconds: 30);
  static const Duration _newSessionAfter = Duration(minutes: 30);
  static const Duration _timeout = Duration(seconds: 12);

  /// Stability capture (error hooks, stall watchdog, start timing, unclean-exit detection) is off
  /// under `flutter test`, where global handlers and a second isolate would fight the test
  /// binding. A test that wants it sets this to true before init.
  @visibleForTesting
  static bool stabilityInTests = false;

  /// Test seam: replace to capture requests instead of hitting the network.
  @visibleForTesting
  static Future<http.Response> Function(Uri, Map<String, String>, String)? postOverride;

  SharedPreferences? _prefs;
  String _package = '';
  String _appVersion = 'unknown';
  String _installId = '';
  bool _enabled = true;
  bool _ready = false;
  bool _flushing = false;
  final List<Map<String, Object?>> _queue = <Map<String, Object?>>[];
  Timer? _timer;
  String? _sessionId;
  DateTime? _sessionStart;
  DateTime? _pausedAt;
  DateTime? _resumedAt;
  final Set<String> _errorsThisSession = <String>{};
  FlutterExceptionHandler? _previousFlutterHandler;
  ErrorCallback? _previousPlatformHandler;
  bool _hooksInstalled = false;
  Isolate? _watchdog;
  ReceivePort? _watchdogPort;
  SendPort? _toWatchdog;

  bool get enabled => _enabled;
  String get installId => _installId;

  /// Call once from main() after WidgetsFlutterBinding.ensureInitialized().
  /// [appVersion] is "versionName+versionCode" (e.g. from PackageInfo).
  static Future<void> init({required String package, required String appVersion, SharedPreferences? prefs}) =>
      instance._init(package, appVersion, prefs);

  static void log(String event, [Map<String, Object?> props = const <String, Object?>{}]) => instance._log(event, props);

  static void contentStart({required String collection, required String item, String variant = ''}) =>
      log('content_start', {'collection': collection, 'item': item, 'variant': variant});

  static void contentComplete({required String collection, required String item, String variant = '', int? seconds}) =>
      log('content_complete', _contentProps(collection, item, variant, seconds));

  static void contentAbandon({required String collection, required String item, String variant = '', int? seconds}) =>
      log('content_abandon', _contentProps(collection, item, variant, seconds));

  static Map<String, Object?> _contentProps(String collection, String item, String variant, int? seconds) {
    final Map<String, Object?> props = <String, Object?>{'collection': collection, 'item': item, 'variant': variant};
    if (seconds != null) props['seconds'] = seconds;
    return props;
  }

  static void collectionOpen(String collection) => log('collection_open', {'collection': collection});

  static void collectionUnlock(String collection, {required String method}) =>
      log('collection_unlock', {'collection': collection, 'method': method, 'variant': method});

  static Future<void> setEnabled(bool value) => instance._setEnabled(value);

  static Future<void> flush() => instance._flush();

  Future<void> _init(String package, String appVersion, SharedPreferences? prefs) async {
    if (_ready) return;
    _package = package;
    _appVersion = appVersion;
    _prefs = prefs ?? await SharedPreferences.getInstance();
    _enabled = _prefs!.getBool(_kEnabled) ?? true;
    final String? storedId = _prefs!.getString(_kInstallId);
    final bool firstOpen = storedId == null;
    _installId = storedId ?? _uuidV4();
    if (firstOpen) await _prefs!.setString(_kInstallId, _installId);
    final String? stored = _prefs!.getString(_kQueue);
    if (stored != null && stored.isNotEmpty) {
      final Object? decoded = jsonDecode(stored);
      if (decoded is List) {
        for (final Object? e in decoded) {
          if (e is Map) _queue.add(e.cast<String, Object?>());
        }
      }
    }
    _ready = true;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_flushEvery, (_) => _flush());
    if (firstOpen) _log('first_open', const <String, Object?>{});
    final bool stability = _stabilityActive;
    if (stability) _reportUncleanExit();
    _beginSession();
    if (stability) {
      final DateTime initAt = DateTime.now();
      WidgetsBinding.instance.addPostFrameCallback((_) => _reportAppStart(initAt));
      _installErrorHooks();
      unawaited(_startWatchdog());
    }
    unawaited(_flush());
  }

  bool get _stabilityActive => !kIsWeb && (stabilityInTests || !Platform.environment.containsKey('FLUTTER_TEST'));

  // ---------------------------------------------------------------- stability

  /// The foreground marker is written while the app is ON SCREEN and cleared the moment it leaves
  /// (inactive / hidden / paused / detached). Finding it at start-up means the last run died while
  /// the player was looking at it. It carries the last meaningful event and the memory in use, so a
  /// real crash says where it happened and whether it was an out-of-memory kill (2026-09-24: the old
  /// marker was only cleared on `paused`, and a swipe from recents that never paused counted too).
  void _reportUncleanExit() {
    final String? raw = _prefs?.getString(_kForeground);
    if (raw == null) return;
    Map<String, Object?> props = {'dim': raw};
    if (raw.startsWith('{')) {
      try {
        final Map<String, Object?> m = (jsonDecode(raw) as Map).cast<String, Object?>();
        props = {
          'dim': m['v'] ?? '',
          if (m['e'] != null) 'last': m['e'],
          if (m['rss'] != null) 'rss': m['rss'],
          if (m['s'] != null) 'secs': m['s'],
        };
      } catch (_) {
        props = {'dim': 'unknown'};
      }
    }
    _log('unclean_exit', props);
  }

  /// The last event that says what the player was doing (not the lifecycle / stability noise).
  String? _lastMeaningful;
  DateTime _markerWrittenAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Set<String> _markerNoise = {
    'session_start', 'session_end', 'session_resume', 'app_start', 'ui_stall', 'unclean_exit',
    'app_error', 'coins_earned', 'coins_spent', 'first_open',
  };

  /// Write the on-screen marker with its context; [force] ignores the 5 s throttle.
  void _writeForegroundMarker({bool force = false}) {
    if (!_stabilityActive || _pausedAt != null) return;
    // Off screen (inactive / hidden, before `paused` lands): an event logged in that gap must not
    // put the marker back, or a swipe from recents reads as a death (2026-09-26).
    final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    final DateTime now = DateTime.now();
    if (!force && now.difference(_markerWrittenAt) < const Duration(seconds: 5)) return;
    _markerWrittenAt = now;
    int? rssMb;
    try {
      rssMb = ProcessInfo.currentRss ~/ (1024 * 1024);
    } catch (_) {}
    final DateTime? start = _sessionStart;
    _prefs?.setString(_kForeground, jsonEncode(<String, Object?>{
      'v': _appVersion,
      if (_lastMeaningful != null) 'e': _lastMeaningful,
      if (rssMb != null) 'rss': rssMb,
      if (start != null) 's': now.difference(start).inSeconds,
    }));
  }

  void _reportAppStart(DateTime initAt) {
    int? ms = _processAgeMs();
    String basis = 'process';
    final int sinceInit = DateTime.now().difference(initAt).inMilliseconds;
    // A process that was already alive before this Dart start (pre-warmed, a relaunch into a
    // process that survived, a second engine) did not cold-start now: time the part we can see
    // instead. The old 60 s cut-off let a relaunch 47-59 s into a live process read as a
    // 47-59 s cold start (ADSC, 2026-09-26); a real cold start reaches main() within seconds.
    if (ms == null || ms > 60000 || ms - sinceInit > 10000) {
      ms = DateTime.now().difference(initAt).inMilliseconds;
      basis = 'init';
    }
    final String bucket = ms < 1000 ? '<1s' : ms < 2000 ? '1-2s' : ms < 4000 ? '2-4s' : '4s+';
    _log('app_start', {'amount': ms, 'dim': bucket, 'basis': basis});
  }

  /// Milliseconds since this process was created, from /proc (Android, Linux); null elsewhere.
  static int? _processAgeMs() {
    try {
      final String stat = File('/proc/self/stat').readAsStringSync();
      // Field 2 (comm) may contain spaces and parentheses: count from the last ')'.
      final List<String> rest = stat.substring(stat.lastIndexOf(')') + 2).split(' ');
      final double startTicks = double.parse(rest[19]); // field 22: starttime, in clock ticks since boot
      final double uptime = double.parse(File('/proc/uptime').readAsStringSync().split(' ').first);
      return ((uptime - startTicks / 100.0) * 1000).round(); // CLK_TCK is 100 on Android and Linux
    } on Exception {
      return null; // no /proc here (iOS, desktop sandboxes): the caller times from init instead
    }
  }

  void _installErrorHooks() {
    if (_hooksInstalled) return;
    _hooksInstalled = true;
    _previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _reportError('flutter', details.exception, details.stack);
      _previousFlutterHandler?.call(details);
    };
    _previousPlatformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _reportError('async', error, stack);
      // Not handled by us: whatever was installed before decides; with nothing installed the
      // engine keeps its default reporting.
      return _previousPlatformHandler?.call(error, stack) ?? false;
    };
  }

  void _reportError(String source, Object error, StackTrace? stack) {
    if (_errorsThisSession.length >= _maxErrorsPerSession) return;
    final String trace = stack?.toString() ?? '';
    String dim = '${error.runtimeType} @ ${_frameSignature(trace)}';
    if (dim.length > 64) dim = dim.substring(0, 64);
    if (!_errorsThisSession.add(dim)) return;
    // The message is left out on purpose: exception text can carry user data. Type, top frame
    // and the symbolizable head of the trace are enough to find the bug.
    _log('app_error', {'dim': dim, 'source': source, 'stack': _symbolizableHead(trace)});
  }

  /// `app/foo.dart:42` in readable traces; the instruction offset in split-debug-info builds,
  /// where frames look like `#00 abs ... virt ... _kDartIsolateSnapshotInstructions+0x3a1f2c`.
  static String _frameSignature(String trace) {
    final RegExp readable = RegExp(r'\(package:([^)]+?\.dart:\d+)');
    final RegExp stripped = RegExp(r'_kDartIsolateSnapshotInstructions\+(0x[0-9a-f]+)');
    for (final String line in trace.split('\n')) {
      final RegExpMatch? r = readable.firstMatch(line);
      if (r != null && !line.contains('package:flutter/')) return r.group(1)!;
      final RegExpMatch? o = stripped.firstMatch(line);
      if (o != null) return o.group(1)!;
    }
    return 'unknown';
  }

  /// What `flutter symbolize` needs: the build id / dso base lines and the first frames.
  static String _symbolizableHead(String trace) {
    final List<String> keep = <String>[];
    int frames = 0;
    for (final String raw in trace.split('\n')) {
      final String line = raw.trim();
      if (line.startsWith('build_id') || line.startsWith('isolate_dso_base') || line.startsWith('isolate_instructions')) {
        keep.add(line);
      } else if (line.startsWith('#') && frames < 8) {
        keep.add(line);
        frames++;
      }
    }
    final String head = keep.join('\n');
    return head.length > 1200 ? head.substring(0, 1200) : head;
  }

  /// A second isolate pings this one every second; this isolate answers from its event loop. An
  /// answer that takes seconds means the UI thread was blocked that long - the thing that, past
  /// five seconds with input pending, Android reports as an ANR.
  Future<void> _startWatchdog() async {
    if (_watchdog != null) return;
    final ReceivePort port = ReceivePort();
    _watchdogPort = port;
    port.listen((Object? message) {
      if (message is SendPort) {
        _toWatchdog = message;
      } else if (message == 'ping') {
        _toWatchdog?.send('pong');
      } else if (message is int) {
        _reportStall(message);
      }
    });
    try {
      _watchdog = await Isolate.spawn<SendPort>(_watchdogMain, port.sendPort, debugName: 'lc-analytics-watchdog');
    } on IsolateSpawnException catch (e) {
      debugPrint('[analytics] stall watchdog unavailable: $e');
      port.close();
      _watchdogPort = null;
    }
  }

  static void _watchdogMain(SendPort toMain) {
    final ReceivePort fromMain = ReceivePort();
    final Stopwatch clock = Stopwatch()..start();
    int? pingAt;
    bool paused = false;
    toMain.send(fromMain.sendPort);
    fromMain.listen((Object? message) {
      if (message == 'pong') {
        final int? sent = pingAt;
        pingAt = null;
        if (sent != null && !paused) {
          final int waited = clock.elapsedMilliseconds - sent;
          if (waited >= _stallReportMs) toMain.send(waited);
        }
      } else if (message == 'pause') {
        paused = true;
        pingAt = null;
      } else if (message == 'resume') {
        paused = false;
        pingAt = null;
      }
    });
    Timer.periodic(const Duration(seconds: 1), (_) {
      if (paused || pingAt != null) return;
      pingAt = clock.elapsedMilliseconds;
      toMain.send('ping');
    });
  }

  void _reportStall(int waitedMs) {
    // A frozen background process also answers late; only a stall the player sat through counts.
    if (_pausedAt != null) return;
    final DateTime? resumedAt = _resumedAt;
    if (resumedAt != null && DateTime.now().difference(resumedAt).inMilliseconds < waitedMs + 2000) return;
    _log('ui_stall', {'amount': waitedMs, 'dim': waitedMs >= _anrMs ? '5s+' : '2-5s'});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ready) return;
    if (state != AppLifecycleState.resumed) {
      // off screen in any way: a death from here on is not one the player saw
      _prefs?.remove(_kForeground);
    }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (_pausedAt == null) {
        _pausedAt = DateTime.now();
        _toWatchdog?.send('pause');
        _endSession();
        unawaited(_flush());
      }
    } else if (state == AppLifecycleState.resumed) {
      final DateTime? pausedAt = _pausedAt;
      _pausedAt = null;
      _resumedAt = DateTime.now();
      _toWatchdog?.send('resume');
      _writeForegroundMarker(force: true);
      if (_sessionStart == null) {
        // A short trip out of the app continues the same visit in the player's mind, but the
        // seconds already reported stay reported: a new session row keeps the arithmetic honest.
        final bool longBreak = pausedAt == null || DateTime.now().difference(pausedAt) >= _newSessionAfter;
        _beginSession(resumed: !longBreak);
      }
    }
  }

  void _beginSession({bool resumed = false}) {
    _sessionId = _uuidV4().substring(0, 13);
    _sessionStart = DateTime.now();
    _errorsThisSession.clear();
    _writeForegroundMarker(force: true);
    if (resumed) {
      _log('session_resume', const <String, Object?>{});
      return;
    }
    final int n = (_prefs?.getInt(_kSessions) ?? 0) + 1;
    _prefs?.setInt(_kSessions, n);
    _log('session_start', {'n': n});
  }

  void _endSession() {
    final DateTime? start = _sessionStart;
    if (start == null) return;
    _log('session_end', {'seconds': DateTime.now().difference(start).inSeconds});
    _sessionStart = null;
    _prefs?.remove(_kForeground);
  }

  void _log(String event, Map<String, Object?> props) {
    if (!_ready || !_enabled) return;
    if (!_markerNoise.contains(event)) {
      final Object? dim = props['dim'] ?? props['feature'] ?? props['collection'] ?? props['screen'];
      String last = dim == null ? event : '$event:$dim';
      if (last.length > 80) last = last.substring(0, 80);
      // a new action is always recorded; the same one again only refreshes every 5 s
      final bool changed = last != _lastMeaningful;
      _lastMeaningful = last;
      _writeForegroundMarker(force: changed);
    }
    _queue.add(<String, Object?>{
      'event': event,
      'at': DateTime.now().millisecondsSinceEpoch,
      if (_sessionId != null) 'session': _sessionId,
      if (props.isNotEmpty) 'props': props,
    });
    if (_queue.length > _maxQueued) _queue.removeRange(0, _queue.length - _maxQueued);
    _persist();
    if (_queue.length >= _flushAt) unawaited(_flush());
  }

  void _persist() {
    _prefs?.setString(_kQueue, jsonEncode(_queue));
  }

  Future<void> _setEnabled(bool value) async {
    _enabled = value;
    await _prefs?.setBool(_kEnabled, value);
    if (!value) {
      _queue.clear();
      _persist();
    }
  }

  Future<void> _flush() async {
    if (!_ready || !_enabled || _flushing || _queue.isEmpty) return;
    _flushing = true;
    try {
      while (_queue.isNotEmpty) {
        final int n = min(_batchSize, _queue.length);
        final String body = jsonEncode(<String, Object?>{
          'install_id': _installId,
          'app_version': _appVersion,
          'platform': defaultTargetPlatform.name,
          'events': _queue.sublist(0, n),
        });
        final Map<String, String> headers = <String, String>{'content-type': 'application/json', 'x-app-package': _package};
        final http.Response response = postOverride != null
            ? await postOverride!(Uri.parse(endpoint), headers, body)
            : await http.post(Uri.parse(endpoint), headers: headers, body: body).timeout(_timeout);
        if (response.statusCode == 200 || (response.statusCode >= 400 && response.statusCode < 500)) {
          // 4xx means the server will never accept this batch; keeping it would block the queue forever.
          if (response.statusCode != 200) debugPrint('[analytics] batch rejected ${response.statusCode}: ${response.body}');
          // setEnabled(false) can empty the queue while this batch is in flight,
          // so never drop more rows than are actually still there.
          _queue.removeRange(0, min(n, _queue.length));
          _persist();
        } else {
          debugPrint('[analytics] server ${response.statusCode}, will retry');
          break;
        }
      }
    } on Exception catch (e) {
      // Offline or timed out: the queue is on disk and the next tick retries.
      debugPrint('[analytics] flush postponed: $e');
    } finally {
      _flushing = false;
    }
  }

  static String _uuidV4() {
    final Random r = Random.secure();
    final List<int> b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final String h = b.map((int x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  @visibleForTesting
  void resetForTest() {
    _timer?.cancel();
    if (_ready) WidgetsBinding.instance.removeObserver(this);
    _ready = false;
    _queue.clear();
    _sessionId = null;
    _sessionStart = null;
    _pausedAt = null;
    _resumedAt = null;
    _errorsThisSession.clear();
    if (_hooksInstalled) {
      FlutterError.onError = _previousFlutterHandler;
      PlatformDispatcher.instance.onError = _previousPlatformHandler;
      _hooksInstalled = false;
    }
    _watchdog?.kill(priority: Isolate.immediate);
    _watchdog = null;
    _watchdogPort?.close();
    _watchdogPort = null;
    _toWatchdog = null;
  }

  @visibleForTesting
  static String frameSignatureForTest(String trace) => _frameSignature(trace);

  @visibleForTesting
  static String symbolizableHeadForTest(String trace) => _symbolizableHead(trace);

  @visibleForTesting
  void reportErrorForTest(Object error, StackTrace stack) => _reportError('flutter', error, stack);

  @visibleForTesting
  void reportStallForTest(int waitedMs) => _reportStall(waitedMs);

  @visibleForTesting
  List<Map<String, Object?>> get queuedForTest => List<Map<String, Object?>>.unmodifiable(_queue);
}
