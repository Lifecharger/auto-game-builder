import 'dart:async';
import 'dart:io';

import 'package:app_manager_mobile/l10n/app_localizations.dart';
import 'package:app_manager_mobile/screens/buckets_screen.dart';
import 'package:app_manager_mobile/services/api_service.dart';
import 'package:app_manager_mobile/services/generate_service.dart';
import 'package:app_manager_mobile/services/lifecharger_analytics.dart';
import 'package:app_manager_mobile/services/r2_control_service.dart';
import 'package:app_manager_mobile/services/usage_events.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the app reports about its own use: an action counts as used only once
/// the server accepted it, a refusal is reported by its cause, a screen only
/// when it is on screen, and a milestone once per install.
///
/// Nothing here touches the network: analytics batches are refused by a stub
/// (so every event stays readable in the queue) and server calls go to a
/// [MockClient].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> startAnalytics() => Analytics.init(
        package: 'com.lifecharger.appmanager',
        appVersion: '1.0.0+1',
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Analytics.instance.resetForTest();
    Usage.resetForTest();
    Analytics.postOverride =
        (uri, headers, body) async => http.Response('{"accepted":0}', 503);
    await startAnalytics();
  });

  tearDown(() {
    Analytics.instance.resetForTest();
    Usage.resetForTest();
    Analytics.postOverride = null;
  });

  /// Props of every queued event called [name], in order.
  List<Map<String, Object?>> logged(String name) => [
        for (final event in Analytics.instance.queuedForTest)
          if (event['event'] == name)
            ((event['props'] as Map?) ?? const {}).cast<String, Object?>(),
      ];

  List<Object?> features() => [for (final p in logged('feature_use')) p['feature']];

  /// Runs [body] with every server call answered by [answer].
  Future<T> withServer<T>(
    Future<http.Response> Function(http.Request request) answer,
    Future<T> Function() body,
  ) =>
      http.runWithClient(body, () => MockClient(answer));

  group('cause of a failure', () {
    test('status codes map to coarse causes', () {
      expect(Usage.causeOfStatus(401), 'unauthorized');
      expect(Usage.causeOfStatus(403), 'unauthorized');
      expect(Usage.causeOfStatus(404), 'not_found');
      expect(Usage.causeOfStatus(429), 'rate_limited');
      expect(Usage.causeOfStatus(400), 'rejected');
      expect(Usage.causeOfStatus(500), 'server_error');
      expect(Usage.causeOfStatus(502), 'server_error');
      expect(Usage.causeOfStatus(504), 'timeout');
    });

    test('thrown errors map to coarse causes, never to their text', () {
      expect(Usage.causeOf(TimeoutException('slow')), 'timeout');
      expect(Usage.causeOf(const SocketException('no route')), 'offline');
      expect(Usage.causeOf(http.ClientException('reset')), 'offline');
      expect(Usage.causeOf(const FormatException('<html>')), 'bad_response');
      expect(Usage.causeOf(const ServerCallException('nope', 401)), 'unauthorized');
      expect(Usage.causeOf(StateError('anything else')), 'error');
    });

    test('a status-carrying error reads like the plain exception it replaced', () {
      expect(const ServerCallException('Bucket is private', 403).toString(),
          Exception('Bucket is private').toString());
    });
  });

  group('milestones', () {
    test('a step is sent once, however often it is reached', () async {
      await Usage.milestone('first_task_created');
      await Usage.milestone('first_task_created');
      await Future.wait([
        Usage.milestone('first_task_created'),
        Usage.milestone('first_build_queued'),
        Usage.milestone('first_build_queued'),
      ]);
      expect([for (final p in logged('milestone')) p['dim']],
          ['first_task_created', 'first_build_queued']);
    });

    test('a step already sent stays sent after an app restart', () async {
      await Usage.milestone('server_connected');
      await Usage.milestone('first_task_created');

      // A new process: nothing in memory, only what the preferences kept.
      Analytics.instance.resetForTest();
      Usage.resetForTest();
      await startAnalytics();

      await Usage.milestone('server_connected');
      await Usage.milestone('first_task_created');
      await Usage.milestone('first_task_run');
      // The unsent queue survives the restart too, so the two steps from the
      // first run are still there - once each, not repeated.
      expect([for (final p in logged('milestone')) p['dim']],
          ['server_connected', 'first_task_created', 'first_task_run']);
    });

    test('a step reached while reporting is off is sent once it is on again',
        () async {
      await Analytics.setEnabled(false);
      await Usage.milestone('first_task_created');
      expect(logged('milestone'), isEmpty);

      await Analytics.setEnabled(true);
      await Usage.milestone('first_task_created');
      expect([for (final p in logged('milestone')) p['dim']],
          ['first_task_created']);
    });

    test('every step id is short and unique', () {
      expect(Usage.milestones.toSet().length, Usage.milestones.length);
      for (final id in Usage.milestones) {
        expect(id, matches(RegExp(r'^[a-z_]{3,40}$')));
      }
    });
  });

  group('a build request', () {
    test('refused by the server is a failure, not a use', () async {
      final result = await withServer(
        (_) async => http.Response('<html>Bad gateway</html>', 502),
        () => ApiService.deployApp(7),
      );
      expect(result.ok, isFalse);
      expect(features(), isNot(contains('deploy')));
      expect(logged('milestone'), isEmpty);
      expect(logged('content_fail'), [
        {'collection': 'server_call', 'item': 'deploy', 'dim': 'server_error'},
      ]);
    });

    test('that never reaches the server is reported as offline', () async {
      final result = await withServer(
        (_) async => throw const SocketException('unreachable'),
        () => ApiService.deployApp(7),
      );
      expect(result.ok, isFalse);
      expect(features(), isNot(contains('deploy')));
      expect([for (final p in logged('content_fail')) p['dim']], ['offline']);
    });

    test('accepted by the server is a use and the first-build step', () async {
      final result = await withServer(
        (_) async => http.Response('{"message":"queued"}', 200),
        () => ApiService.deployApp(7),
      );
      await pumpEventQueue();
      expect(result.ok, isTrue);
      expect(features(), ['deploy']);
      expect(logged('content_fail'), isEmpty);
      expect([for (final p in logged('milestone')) p['dim']],
          ['first_build_queued']);
    });
  });

  group('tasks', () {
    test('a created task is a use and the first-task step', () async {
      final result = await withServer(
        (_) async => http.Response('{}', 201),
        () => ApiService.createAppTask(appId: 7, title: 'private title'),
      );
      await pumpEventQueue();
      expect(result.ok, isTrue);
      expect(features(), ['task_create']);
      expect([for (final p in logged('milestone')) p['dim']],
          ['first_task_created']);
    });

    test('a rejected task is reported by cause and never by its text', () async {
      final result = await withServer(
        (_) async =>
            http.Response('{"detail":"private server message"}', 400),
        () => ApiService.createAppTask(appId: 7, title: 'private title'),
      );
      expect(result.ok, isFalse);
      expect(result.error, 'private server message');
      expect(features(), isEmpty);
      expect(logged('content_fail'), [
        {'collection': 'server_call', 'item': 'task_create', 'dim': 'rejected'},
      ]);
      final everything = Analytics.instance.queuedForTest.toString();
      expect(everything, isNot(contains('private')));
    });

    test('an unauthorized run is reported as unauthorized', () async {
      await withServer(
        (_) async => http.Response('', 401),
        () => ApiService.runTask(7, 3),
      );
      expect([for (final p in logged('content_fail')) '${p['item']}/${p['dim']}'],
          ['task_run/unauthorized']);
    });
  });

  group('background calls', () {
    test('a sync that keeps failing the same way is one event per session',
        () async {
      for (var i = 0; i < 3; i++) {
        await withServer(
          (_) async => http.Response('', 401),
          () => ApiService.getSync(),
        );
      }
      expect([for (final p in logged('content_fail')) '${p['item']}/${p['dim']}'],
          ['sync/unauthorized']);
    });

    test('the health check remembers why it failed', () async {
      await withServer(
        (_) async => throw TimeoutException('slow'),
        () => ApiService.healthCheck(),
      );
      expect(ApiService.lastHealthFailure, 'timeout');
      await withServer(
        (_) async => http.Response('{}', 200),
        () => ApiService.healthCheck(),
      );
      expect(ApiService.lastHealthFailure, isNull);
    });
  });

  group('generation', () {
    test('a refused job is a failure, not a use', () async {
      await expectLater(
        withServer(
          (_) async => http.Response('{"detail":"queue is closed"}', 503),
          () => GenerateService.submit(task: 't2i', prompt: 'private prompt'),
        ),
        throwsA(isA<Exception>()),
      );
      expect(features(), isNot(contains('generate')));
      expect(logged('content_fail'), [
        {'collection': 'server_call', 'item': 'generate', 'dim': 'server_error'},
      ]);
    });
  });

  group('buckets', () {
    test('a refused delete is a failure, not a use', () async {
      await expectLater(
        withServer(
          (_) async => http.Response('{"detail":"confirm mismatch"}', 400),
          () => R2ControlService.delete('some-bucket', ['a.jpg'],
              confirm: 'some-bucket'),
        ),
        throwsA(isA<Exception>()),
      );
      expect(features(), isEmpty);
      expect([for (final p in logged('content_fail')) '${p['item']}/${p['dim']}'],
          ['buckets_delete/rejected']);
    });

    test('a delete that went through is a use, named by its kind', () async {
      await withServer(
        (_) async => http.Response('{"deleted":1}', 200),
        () => R2ControlService.delete('some-bucket', ['a.jpg'],
            takedown: true, confirm: 'some-bucket'),
      );
      expect(features(), ['buckets_takedown']);
    });

    testWidgets('the tab built behind another one reports nothing',
        (tester) async {
      // The shell keeps every tab of a mode alive in one IndexedStack: this
      // screen is built the moment its mode opens, while another tab shows.
      await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IndexedStack(
          index: 0,
          children: [SizedBox.expand(), BucketsScreen()],
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(features(), isEmpty);
      expect(logged('screen_view'), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
