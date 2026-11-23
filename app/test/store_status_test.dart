import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_manager_mobile/l10n/app_localizations.dart';
import 'package:app_manager_mobile/models/app_model.dart';
import 'package:app_manager_mobile/models/store_status.dart';
import 'package:app_manager_mobile/screens/dashboard_screen.dart';
import 'package:app_manager_mobile/widgets/store_status_view.dart';

/// Store status: the display-priority rule, the collapsible app card and its
/// remembered expanded state.
StoreEntry _play(String track, String version, int code, [String status = 'completed']) =>
    StoreEntry(track: track, version: version, code: code, status: status);

StoreEntry _apple(String track, String version, String build) =>
    StoreEntry(track: track, version: version, build: build);

Map<String, dynamic> _appJson({Map<String, dynamic>? storeStatus}) => {
      'id': 7,
      'name': 'Sample Game',
      'slug': 'sample-game',
      'app_type': 'flutter',
      'package_name': 'com.example.sample',
      'status': 'idle',
      'current_version': '1.0.171+172',
      'task_status': {'pending': 1, 'completed': 2},
      if (storeStatus != null) 'store_status': storeStatus,
    };

final _status = {
  'play': {
    'entries': [
      {'track': 'internal', 'version': '1.0.171', 'code': 172, 'status': 'completed'},
      {'track': 'production', 'version': '1.0.171', 'code': 172, 'status': 'completed'},
      {'track': 'alpha', 'version': '1.0.170', 'code': 171, 'status': 'completed'},
    ],
    'refreshed_at': '2026-11-24T08:00:00Z',
    'error': '',
  },
  'apple': {
    'entries': [
      {'track': 'testflight', 'version': '1.0.12', 'build': '34', 'status': 'IN_BETA_TESTING', 'build_id': 'b34'},
      {'track': 'live', 'version': '1.0.10', 'build': '30', 'status': 'READY_FOR_SALE'},
    ],
    'live': {'track': 'live', 'version': '1.0.10', 'build': '30', 'status': 'READY_FOR_SALE'},
    'builds': [
      {'build_id': 'b34', 'version': '1.0.12', 'build': '34', 'processing': 'VALID', 'expired': false},
    ],
    'editable_version': {'version': '1.0.12', 'state': 'PREPARE_FOR_SUBMISSION', 'build_id': 'b34', 'build': '34'},
    'refreshed_at': '2026-11-24T08:00:00Z',
    'error': '',
  },
};

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('display rule', () {
    test('same version on internal and production shows production', () {
      final d = pickDisplay('play', [
        _play('internal', '1.0.171', 172),
        _play('production', '1.0.171', 172),
      ]);
      expect(d!.track, 'production');
    });

    test('the highest version wins, whatever its track', () {
      final d = pickDisplay('play', [
        _play('production', '1.0.169', 170),
        _play('internal', '1.0.171', 172),
        _play('beta', '1.0.170', 171),
      ]);
      expect(d!.version, '1.0.171');
      expect(d.track, 'internal');
    });

    test('drafts count only when nothing is live', () {
      expect(
          pickDisplay('play', [_play('production', '1.0.180', 181, 'draft'), _play('alpha', '1.0.171', 172)])!
              .track,
          'alpha');
      expect(pickDisplay('play', [_play('internal', '0.3.0', 3, 'draft')])!.status, 'draft');
      expect(pickDisplay('play', const []), isNull);
    });

    test('Apple: live beats TestFlight for the same build; newer TestFlight beats older live', () {
      expect(
          pickDisplay('apple', [_apple('testflight', '1.0.12', '34'), _apple('live', '1.0.12', '34')])!.track,
          'live');
      final d = pickDisplay('apple', [_apple('live', '1.0.10', '30'), _apple('testflight', '1.0.12', '34')]);
      expect(d!.track, 'testflight');
      expect(pickDisplay('apple', [_apple('testflight', '1.0.9', '40'), _apple('testflight', '1.0.10', '2')])!
          .version, '1.0.10');
    });

    test('a status without the server pick is recomputed on the phone', () {
      final s = StoreStatus.fromJson(_status);
      expect(s.play!.display!.track, 'production');
      expect(s.apple!.display!.label, '1.0.12 (34)');
      expect(s.play!.liveTracks, ['production', 'alpha', 'internal']);
      expect(s.apple!.attachableBuilds.single.buildId, 'b34');
    });
  });

  group('collapsible app card', () {
    testWidgets('collapsed shows one line per store; expanded shows every track and the actions',
        (tester) async {
      final app = AppModel.fromJson(_appJson(storeStatus: _status));
      var expanded = false;
      await tester.pumpWidget(_host(StatefulBuilder(
        builder: (context, setState) => AppCard(
          app: app,
          taskStatus: app.taskStatus,
          appStatus: AppCardStatus.active,
          onToggleCompleted: () {},
          onTogglePostponed: () {},
          storeExpanded: expanded,
          onToggleStore: () => setState(() => expanded = !expanded),
        ),
      )));

      expect(find.text('Play: 1.0.171 (Production)'), findsOneWidget);
      expect(find.text('App Store: 1.0.12 (TestFlight)'), findsOneWidget);
      expect(find.text('Live 1.0.10'), findsOneWidget);
      expect(find.text('Google Play tracks'), findsNothing);
      expect(find.text('Promote to production'), findsNothing);

      await tester.tap(find.byTooltip('Show store details'));
      await tester.pumpAndSettle();
      expect(find.text('Google Play tracks'), findsOneWidget);
      expect(find.text('App Store and TestFlight'), findsOneWidget);
      expect(find.text('Promote to production'), findsOneWidget);
      expect(find.text('Attach to App Store version'), findsOneWidget);
      expect(find.text('Submit for review'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);

      await tester.tap(find.byTooltip('Hide store details'));
      await tester.pumpAndSettle();
      expect(find.text('Google Play tracks'), findsNothing);
    });

    testWidgets('submit for review asks first and cancelling sends nothing', (tester) async {
      await tester.pumpWidget(_host(StoreStatusPanel(appId: 7, status: StoreStatus.fromJson(_status))));
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(find.text('Submit to App Review?'), findsOneWidget);
      expect(find.textContaining('Version 1.0.12 is sent to Apple'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Submit to App Review?'), findsNothing);
    });

    testWidgets('an app never checked keeps the old upload chips', (tester) async {
      final app = AppModel.fromJson(_appJson());
      await tester.pumpWidget(_host(AppCard(
        app: app,
        taskStatus: app.taskStatus,
        appStatus: AppCardStatus.active,
        onToggleCompleted: () {},
        onTogglePostponed: () {},
      )));
      expect(find.textContaining('Play: '), findsOneWidget);
      expect(app.storeStatus.isEmpty, isTrue);
    });

    test('expanded cards are remembered per app', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await StoreCardMemory.load(), isEmpty);
      await StoreCardMemory.save({3, 7});
      expect(await StoreCardMemory.load(), {3, 7});
    });
  });
}
