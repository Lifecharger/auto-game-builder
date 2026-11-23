import 'dart:io';

import 'package:app_manager_mobile/config.dart';
import 'package:app_manager_mobile/l10n/app_localizations.dart';
import 'package:app_manager_mobile/main.dart';
import 'package:app_manager_mobile/models/store_status.dart';
import 'package:app_manager_mobile/services/api_service.dart';
import 'package:app_manager_mobile/services/app_state.dart';
import 'package:app_manager_mobile/services/cache_service.dart';
import 'package:app_manager_mobile/screens/dashboard_screen.dart';
import 'package:app_manager_mobile/services/demo/demo_backend.dart';
import 'package:app_manager_mobile/services/demo/demo_mode.dart';
import 'package:app_manager_mobile/services/lifecharger_analytics.dart';
import 'package:app_manager_mobile/services/mode_service.dart';
import 'package:app_manager_mobile/services/usage_events.dart';
import 'package:app_manager_mobile/widgets/demo_entry_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Demo mode (for App Review): the whole app on bundled sample data, every
/// request answered in memory, nothing sent anywhere.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory cacheDir;

  setUpAll(() async {
    cacheDir = Directory.systemTemp.createTempSync('demo_mode_test');
    Hive.init(cacheDir.path);
    await CacheService.instance.openBoxes();
  });

  tearDownAll(() async {
    await Hive.close();
    cacheDir.deleteSync(recursive: true);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Analytics.instance.resetForTest();
    Usage.resetForTest();
    ModeService.setMode(ModeService.code);
    Analytics.postOverride = (uri, headers, body) async => http.Response('{"accepted":0}', 503);
    await Analytics.init(package: 'com.lifecharger.appmanager', appVersion: '1.0.0+1');
  });

  tearDown(() async {
    await DemoMode.exit();
    Analytics.postOverride = null;
  });

  /// Runs [body] with the app's HTTP client factory, as main() does.
  Future<T> withAppClient<T>(Future<T> Function() body) =>
      http.runWithClient(body, DemoMode.clientFactory);

  group('demo backend', () {
    setUp(() async {
      await DemoMode.enter();
    });

    test('serves sample apps with store status, without any server', () async {
      expect(AppConfig.baseUrl, DemoMode.demoBaseUrl);
      final res = await withAppClient(() => ApiService.getSync());
      expect(res.ok, isTrue);
      final apps = (res.data!['apps'] as List).cast<Map<String, dynamic>>();
      expect(apps.map((a) => a['name']), containsAll(['Puzzle Garden', 'Sky Courier', 'Word Orchard']));
      final garden = StoreStatus.fromJson(apps.first['store_status']);
      // 1.4.3 on internal is newer than 1.4.2 on production: the newest shows.
      expect(garden.play!.display!.label, '1.4.3');
      expect(garden.play!.display!.track, 'internal');
      expect(garden.apple!.live!.version, '1.4.1');
      final orchard = StoreStatus.fromJson(apps[2]['store_status']);
      // Same 2.1.0 on internal and production: production is shown.
      expect(orchard.play!.display!.track, 'production');
      expect(orchard.apple!.display!.track, 'review');
      // One app is building right now.
      final status = await withAppClient(() => ApiService.getDeployStatus(2));
      expect(status.data!['phase'], isNot('none'));
    });

    test('promote, attach and submit are simulated in memory', () async {
      final promoted = await withAppClient(
          () => ApiService.promote(1, store: 'play', fromTrack: 'internal', toTrack: 'production'));
      expect(promoted.ok, isTrue, reason: promoted.error);
      expect(StoreStatus.fromJson(promoted.data!['store_status']).play!.display!.version, '1.4.3');

      final early = await withAppClient(() => ApiService.submitForReview(1));
      expect(early.ok, isFalse, reason: 'no build attached yet');

      final attached = await withAppClient(() => ApiService.promote(1, store: 'apple'));
      expect(attached.ok, isTrue, reason: attached.error);
      expect((attached.data!['result'] as Map)['build'], '43');

      final submitted = await withAppClient(() => ApiService.submitForReview(1));
      expect(submitted.ok, isTrue, reason: submitted.error);
      final apple = StoreStatus.fromJson(submitted.data!['store_status']).apple!;
      expect(apple.entries.any((e) => e.track == 'review' && e.version == '1.4.3'), isTrue);
      expect(apple.editableVersion, isNull);
    });

    test('a demo deploy starts a simulated build', () async {
      final started = await withAppClient(() => ApiService.deployApp(1, track: 'internal', buildTarget: 'aab', upload: true));
      expect(started.ok, isTrue, reason: started.error);
      final status = await withAppClient(() => ApiService.getDeployStatus(1));
      expect(['starting', 'building'], contains(status.data!['phase']));
      DemoBackend.instance.reset();
    });
  });

  testWidgets('Try demo opens the app on sample data; Exit demo leaves it', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Center(child: DemoEntryButton())),
    ));
    await tester.runAsync(() async {
      await tester.tap(find.text('Try demo'));
      // DemoMode.enter clears the on-disk cache: real async work.
      for (var i = 0; i < 50 && !DemoMode.isActive; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    expect(DemoMode.isActive, isTrue);

    // The dashboard as the shell shows it in demo mode, fed by the demo server.
    final state = AppState();
    await tester.runAsync(() => withAppClient(() => state.loadApps()));
    expect(state.error, isNull);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Column(children: [
            DemoBanner(topInset: 0),
            Expanded(child: DashboardScreen()),
          ]),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Demo: sample data, actions are simulated'), findsOneWidget);
    expect(find.text('Puzzle Garden'), findsOneWidget);
    expect(find.text('Play: 1.4.3 (Internal)'), findsOneWidget);
    expect(find.text('Play: 2.1.0 (Production)'), findsOneWidget);
    expect(find.text('App Store: 2.1.0 (In review)'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Exit demo'));
      for (var i = 0; i < 50 && DemoMode.isActive; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    expect(DemoMode.isActive, isFalse);
    expect(AppConfig.baseUrl, isNot(DemoMode.demoBaseUrl));
    expect(CacheService.instance.getApps(), isEmpty, reason: 'nothing of the demo is kept');
    await tester.pumpWidget(const SizedBox());
  });
}
