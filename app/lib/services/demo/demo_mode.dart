import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../config.dart';
import '../cache_service.dart';
import '../user_session.dart';
import 'demo_backend.dart';

/// Demo mode: the whole app running offline on bundled sample data.
///
/// Made for people who have no AGB server (App Review in particular). While
/// it is on, [AppConfig.baseUrl] points at [demoBaseUrl] and every request to
/// that host is answered in memory by [DemoBackend]; nothing is sent
/// anywhere. Nothing of the demo is kept: the local cache is wiped when the
/// demo starts and again when it ends, and the real server address / key are
/// never touched.
class DemoMode {
  DemoMode._();

  /// A reserved, never-resolving host (RFC 6761 `.invalid`).
  static const demoHost = 'demo.agb.invalid';
  static const demoBaseUrl = 'https://$demoHost';

  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);
  static bool get isActive => active.value;

  /// The HTTP client every `http.get` / `http.post` of the app uses (wired in
  /// `main()` through `http.runWithClient`): the demo backend while the demo
  /// runs, the normal network client otherwise.
  static http.Client clientFactory() => isActive ? DemoBackend.instance : IOClient();

  static Future<void> enter() async {
    if (isActive) return;
    DemoBackend.instance.reset();
    AppConfig.setDemoOverride(demoBaseUrl);
    await _wipeLocalData();
    active.value = true;
  }

  static Future<void> exit() async {
    if (!isActive) return;
    AppConfig.setDemoOverride(null);
    await _wipeLocalData();
    active.value = false;
  }

  static Future<void> _wipeLocalData() async {
    await CacheService.instance.clearAll();
    await UserSession.instance.clear();
  }
}
