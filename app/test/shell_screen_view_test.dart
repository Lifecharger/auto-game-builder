import 'dart:io';

import 'package:app_manager_mobile/l10n/app_localizations.dart';
import 'package:app_manager_mobile/main.dart';
import 'package:app_manager_mobile/services/api_service.dart';
import 'package:app_manager_mobile/services/app_state.dart';
import 'package:app_manager_mobile/services/locale_service.dart';
import 'package:app_manager_mobile/services/cache_service.dart';
import 'package:app_manager_mobile/services/lifecharger_analytics.dart';
import 'package:app_manager_mobile/services/mode_service.dart';
import 'package:app_manager_mobile/services/usage_events.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The shell keeps every tab of a mode built inside one IndexedStack, so a
/// tab being built says nothing about it being seen. `screen_view` must name
/// the one tab that is showing: the first tab when the shell appears, and a
/// newly chosen tab only once it has replaced the old one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory cacheDir;

  setUpAll(() async {
    cacheDir = Directory.systemTemp.createTempSync('shell_screen_view_test');
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
    Analytics.postOverride =
        (uri, headers, body) async => http.Response('{"accepted":0}', 503);
    await Analytics.init(
      package: 'com.lifecharger.appmanager',
      appVersion: '1.0.0+1',
    );
  });

  tearDown(() {
    Analytics.instance.resetForTest();
    Usage.resetForTest();
    Analytics.postOverride = null;
    ModeService.setMode(ModeService.code);
  });

  List<Object?> screens() => [
        for (final event in Analytics.instance.queuedForTest)
          if (event['event'] == 'screen_view') (event['props'] as Map)['dim'],
      ];

  List<Object?> features() => [
        for (final event in Analytics.instance.queuedForTest)
          if (event['event'] == 'feature_use') (event['props'] as Map)['feature'],
      ];

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MainShell(),
      ),
    ));
    await tester.pump();
  }

  /// Lets the 200 ms fade out and the fade back in finish.
  Future<void> settleSwitch(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('only the tab that is showing is reported', (tester) async {
    await pumpShell(tester);

    // Five tabs are built; one is on screen.
    expect(screens(), ['dashboard']);

    await tester.tap(find.byIcon(Icons.tune));
    await settleSwitch(tester);
    expect(screens(), ['dashboard', 'control']);

    // Tapping the tab that is already showing shows nothing new.
    await tester.tap(find.byIcon(Icons.tune));
    await settleSwitch(tester);
    expect(screens(), ['dashboard', 'control']);

    // A tab is a screen, not a feature the user "used".
    expect(features(), isEmpty);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a refused API key is named on the banner and leads to Settings',
      (tester) async {
    await pumpShell(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(MainShell)))!;
    expect(find.text(l10n.apiKeyRefusedBanner), findsNothing);

    ApiService.keyRefused.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.apiKeyRefusedBanner), findsOneWidget);
    expect(find.text(l10n.serverUnreachable), findsNothing);

    await tester.tap(find.text(l10n.apiKeyRefusedBanner));
    await settleSwitch(tester);
    expect(screens().last, 'settings');

    ApiService.keyRefused.value = false;
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the Asset and Delivery tabs are labelled in the app language',
      (tester) async {
    await LocaleService.instance.setLocale(const Locale('en'));
    await pumpShell(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(MainShell)))!;

    ModeService.setMode(ModeService.delivery);
    await settleSwitch(tester);
    final bar = find.byType(BottomNavigationBar);
    for (final label in [l10n.navDelivery, l10n.navBuckets, l10n.settings]) {
      expect(find.descendant(of: bar, matching: find.text(label)),
          findsWidgets);
    }

    ModeService.setMode(ModeService.asset);
    await settleSwitch(tester);
    for (final label in [
      l10n.navGenerate,
      l10n.navGallery,
      l10n.navFlow,
      l10n.navQueue,
      l10n.settings,
    ]) {
      expect(find.descendant(of: bar, matching: find.text(label)),
          findsWidgets);
    }

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a mode change reports the first tab of the new mode',
      (tester) async {
    await pumpShell(tester);
    expect(screens(), ['dashboard']);

    ModeService.setMode(ModeService.delivery);
    await settleSwitch(tester);

    // Delivery mode builds Delivery, Buckets and Settings at once; only
    // Delivery is on screen.
    expect(screens(), ['dashboard', 'delivery']);
    expect(features(), ['mode_delivery']);

    await tester.pumpWidget(const SizedBox());
  });
}
