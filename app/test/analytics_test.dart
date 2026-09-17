import 'dart:convert';

import 'package:app_manager_mobile/services/lifecharger_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// The anonymous usage client, exercised entirely off the network: every send
/// goes through [Analytics.postOverride] into [bodies] instead of a socket.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> bodies;
  late List<Map<String, String>> headers;

  setUp(() async {
    bodies = <String>[];
    headers = <Map<String, String>>[];
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Analytics.instance.resetForTest();
    Analytics.postOverride = (uri, sent, body) async {
      headers.add(sent);
      bodies.add(body);
      return http.Response('', 200);
    };
    await Analytics.init(
      package: 'com.lifecharger.appmanager',
      appVersion: '1.0.227+228',
    );
  });

  tearDown(() {
    Analytics.instance.resetForTest();
    Analytics.postOverride = null;
  });

  /// Every event name across every batch sent so far, in order.
  List<String> sentEvents() => [
        for (final body in bodies)
          for (final event
              in (jsonDecode(body) as Map<String, dynamic>)['events'] as List)
            (event as Map<String, dynamic>)['event'] as String,
      ];

  /// Everything logged so far, whether it is still on the disk queue or has
  /// already been drained by the flush `init` kicks off.
  List<String> loggedEvents() => [
        ...sentEvents(),
        for (final event in Analytics.instance.queuedForTest)
          event['event'] as String,
      ];

  test('a fresh install queues first_open and session_start', () {
    expect(
      loggedEvents(),
      containsAllInOrder(<String>['first_open', 'session_start']),
    );
  });

  test('a screen ping reaches the endpoint under this package', () async {
    Analytics.log('feature_use', {'feature': 'tasklist'});
    await Analytics.flush();

    expect(bodies, isNotEmpty);
    expect(headers.first['x-app-package'], 'com.lifecharger.appmanager');
    expect(sentEvents(), contains('feature_use'));

    final batch = jsonDecode(bodies.last) as Map<String, dynamic>;
    expect(batch['app_version'], '1.0.227+228');
    expect(batch['install_id'], isNotEmpty);
    final ping = (batch['events'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((e) => e['event'] == 'feature_use');
    expect(ping['props'], <String, Object?>{'feature': 'tasklist'});
  });

  test('switching reporting off empties the queue and stops sending', () async {
    // Drain the boot batch first, so anything that arrives below can only have
    // been sent after reporting was switched off.
    await Analytics.flush();
    bodies.clear();

    await Analytics.setEnabled(false);
    expect(Analytics.instance.queuedForTest, isEmpty);

    Analytics.log('feature_use', {'feature': 'deploy'});
    await Analytics.flush();

    expect(Analytics.instance.queuedForTest, isEmpty);
    expect(bodies, isEmpty);
    expect(Analytics.instance.enabled, isFalse);
  });
}
