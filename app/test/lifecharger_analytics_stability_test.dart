// Stability capture of the shared analytics client. Copy next to the app's other analytics test
// and fix the import to the app's package name.
import 'dart:ui' show AppLifecycleState;

import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_manager_mobile/services/lifecharger_analytics.dart';

const String _strippedTrace = '''
Warning: This VM has been configured to produce stack traces that violate the Dart standard.
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
pid: 1234, tid: 5678, name 1.ui
os: android arch: arm64 comp: no sim: no
build_id: 'a1b2c3d4e5f60718'
isolate_dso_base: 7b3c400000, vm_dso_base: 7b3c400000
isolate_instructions: 7b3c5a1000, vm_instructions: 7b3c59d000
    #00 abs 0000007b3c9a2f2c virt 00000000005a2f2c _kDartIsolateSnapshotInstructions+0x3a1f2c
    #01 abs 0000007b3c9a3000 virt 00000000005a3000 _kDartIsolateSnapshotInstructions+0x3a2000
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Map<String, Object?>> events() => Analytics.instance.queuedForTest;
  Iterable<String> names() => events().map((Map<String, Object?> e) => e['event']! as String);

  setUp(() {
    Analytics.postOverride = (Uri url, Map<String, String> headers, String body) async => http.Response('{"accepted":0}', 503);
    Analytics.stabilityInTests = true;
  });

  tearDown(() {
    Analytics.instance.resetForTest();
    Analytics.stabilityInTests = false;
    Analytics.postOverride = null;
    Analytics.testLabProbe = null;
    Analytics.exitInfoProbe = null;
  });

  test('a readable trace is signed by its first app frame, never a framework frame', () {
    const String trace = '#0      State.setState (package:flutter/src/widgets/framework.dart:1167:9)\n'
        '#1      _ShopState._buy (package:acepong/screens/shop.dart:88:5)\n';
    expect(Analytics.frameSignatureForTest(trace), 'acepong/screens/shop.dart:88');
  });

  test('a split-debug-info trace is signed by its instruction offset and keeps what symbolize needs', () {
    expect(Analytics.frameSignatureForTest(_strippedTrace), '0x3a1f2c');
    final String head = Analytics.symbolizableHeadForTest(_strippedTrace);
    expect(head, contains("build_id: 'a1b2c3d4e5f60718'"));
    expect(head, contains('isolate_dso_base'));
    expect(head, contains('#01 abs'));
    expect(head, isNot(contains('pid:')));
  });

  test('an uncaught error is reported once per session, without its message', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Analytics.init(package: 'com.lifecharger.test', appVersion: '1.0.0+1');
    final StackTrace stack = StackTrace.fromString(_strippedTrace);
    Analytics.instance.reportErrorForTest(StateError('player email is a@b.c'), stack);
    Analytics.instance.reportErrorForTest(StateError('player email is a@b.c'), stack);

    final List<Map<String, Object?>> errors = events().where((Map<String, Object?> e) => e['event'] == 'app_error').toList();
    expect(errors, hasLength(1));
    final Map<String, Object?> props = errors.single['props']! as Map<String, Object?>;
    expect(props['dim'], 'StateError @ 0x3a1f2c');
    expect(props.values.join(' '), isNot(contains('a@b.c')));
  });

  test('error reports stop at five per session', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Analytics.init(package: 'com.lifecharger.test', appVersion: '1.0.0+1');
    for (int i = 0; i < 9; i++) {
      Analytics.instance.reportErrorForTest(
          StateError('x'), StackTrace.fromString('#0 f (package:acepong/a.dart:${i + 1}:1)\n'));
    }
    expect(names().where((String n) => n == 'app_error'), hasLength(5));
  });

  test('a run that died in the foreground is reported by the next start, a clean one is not', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Analytics.init(package: 'com.lifecharger.test', appVersion: '1.0.0+1');
    expect(names(), isNot(contains('unclean_exit')));

    // the process dies here: no pause, no session_end
    Analytics.instance.resetForTest();
    await Analytics.init(package: 'com.lifecharger.test', appVersion: '1.0.1+2');
    final Map<String, Object?> died = events().firstWhere((Map<String, Object?> e) => e['event'] == 'unclean_exit');
    expect((died['props']! as Map<String, Object?>)['dim'], '1.0.0+1');

    // this time the player leaves normally
    Analytics.instance.didChangeAppLifecycleState(AppLifecycleState.paused);
    Analytics.instance.resetForTest();
    await Analytics.init(package: 'com.lifecharger.test', appVersion: '1.0.1+2');
    expect(names().where((String n) => n == 'unclean_exit'), hasLength(1), reason: 'only the first death is on record');
  });

  test('a swipe from recents (inactive / hidden, never paused) is not a crash', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Analytics.init(package: 'com.lifecharger.test', appVersion: '1.0.0+1');
    Analytics.instance.didChangeAppLifecycleState(AppLifecycleState.inactive);
    Analytics.instance.didChangeAppLifecycleState(AppLifecycleState.hidden);
    Analytics.instance.resetForTest();
    await Analytics.init(package: 'com.lifecharger.test', appVersion: '1.0.0+1');
    expect(names(), isNot(contains('unclean_exit')));
  });

  test('a real death says what the player was doing and the memory in use', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Analytics.init(package: 'com.lifecharger.test', appVersion: '1.0.0+1');
    Analytics.log('feature_use', <String, Object?>{'feature': 'hint'});
    Analytics.instance.resetForTest();
    await Analytics.init(package: 'com.lifecharger.test', appVersion: '1.0.0+1');
    final Map<String, Object?> props = events()
        .firstWhere((Map<String, Object?> e) => e['event'] == 'unclean_exit')['props']! as Map<String, Object?>;
    expect(props['dim'], '1.0.0+1');
    expect(props['last'], 'feature_use:hint');
    expect(props['rss'], isA<int>());
  });

  test('a stall is bucketed, and one that overlaps a resume is ignored', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Analytics.init(package: 'com.lifecharger.test', appVersion: '1.0.0+1');
    Analytics.instance.reportStallForTest(2600);
    Analytics.instance.reportStallForTest(7200);
    final List<Object?> dims = events()
        .where((Map<String, Object?> e) => e['event'] == 'ui_stall')
        .map((Map<String, Object?> e) => (e['props']! as Map<String, Object?>)['dim'])
        .toList();
    expect(dims, <String>['2-5s', '5s+']);

    Analytics.instance.didChangeAppLifecycleState(AppLifecycleState.paused);
    Analytics.instance.reportStallForTest(9000);
    Analytics.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);
    Analytics.instance.reportStallForTest(9000);
    expect(names().where((String n) => n == 'ui_stall'), hasLength(2));
  });

  test('a reinstall that restored its cloud save carries on as the old install', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Analytics.init(package: 'com.lifecharger.test', appVersion: '1.0.0+1');
    final String fresh = Analytics.instance.installId;
    const String old = '0b7c2f5e-1d4a-4c8e-9f3b-2a6d8e1c4b7a';
    await Analytics.adoptInstallId(old);
    expect(Analytics.instance.installId, old);
    final Map<String, Object?> merged = events().lastWhere((e) => e['event'] == 'install_merged');
    expect((merged['props'] as Map)['orphan'], fresh);
    // kept for the next launch
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('lc_analytics_install_id'), old);
    // nothing happens for the same, a missing or a malformed id
    final int n = events().length;
    await Analytics.adoptInstallId(old);
    await Analytics.adoptInstallId(null);
    await Analytics.adoptInstallId('not-an-id');
    expect(events().length, n);
    expect(Analytics.instance.installId, old);
  });

  test('a Firebase Test Lab / Play pre-launch device reports test_device', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Analytics.testLabProbe = () async => true;
    await Analytics.init(package: 'com.lifecharger.test', appVersion: '1.0.0+1');
    await Future<void>.delayed(Duration.zero);
    final Map<String, Object?> e = events().lastWhere((e) => e['event'] == 'test_device');
    expect((e['props'] as Map)['dim'], 'firebase.test.lab');
  });

  test("Android's reason for each earlier exit is reported once, with where the app was", () async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final List<int> asked = <int>[];
    Analytics.exitInfoProbe = (int since) async {
      asked.add(since);
      return <Object?>[
        // killed for memory while on screen, then swiped away from recents in the background
        <Object?, Object?>{'reason': 3, 'importance': 100, 'at': now - 60000, 'rss': 512 * 1024, 'status': 0, 'desc': 'low memory'},
        <Object?, Object?>{'reason': 10, 'importance': 400, 'at': now - 30000, 'rss': 0, 'status': 0, 'desc': 'remove task'},
        // a reason this client does not know yet keeps its number
        <Object?, Object?>{'reason': 42, 'importance': 200, 'at': now - 10000},
      ].where((Object? r) => ((r! as Map)['at']! as int) > since).toList();
    };
    await Analytics.init(package: 'com.lifecharger.test', appVersion: '1.0.0+1');
    await Future<void>.delayed(Duration.zero);
    expect(asked.single, closeTo(now - 86400000, 5000), reason: 'the first run looks back one day only');
    final List<Map<String, Object?>> exits = events()
        .where((Map<String, Object?> e) => e['event'] == 'app_exit')
        .map((Map<String, Object?> e) => (e['props']! as Map).cast<String, Object?>())
        .toList();
    expect(exits.map((Map<String, Object?> p) => p['dim']), <String>['low_memory:fg', 'user_requested:bg', 'reason_42:visible']);
    expect(exits.first['rss'], 512);
    expect(exits.first['desc'], 'low memory');
    expect(exits[1].containsKey('rss'), isFalse);

    // the next start asks only for exits after the newest one already sent
    Analytics.instance.resetForTest();
    await Analytics.init(package: 'com.lifecharger.test', appVersion: '1.0.0+1');
    await Future<void>.delayed(Duration.zero);
    expect(asked.last, now - 10000);
    expect(names().where((String n) => n == 'app_exit'), hasLength(3), reason: 'nothing is reported twice');
  });

  test('a build without the plugin reports no exit reasons and keeps working', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Analytics.exitInfoProbe = (int since) async => throw MissingPluginException('no plugin');
    await Analytics.init(package: 'com.lifecharger.test', appVersion: '1.0.0+1');
    await Future<void>.delayed(Duration.zero);
    expect(names(), isNot(contains('app_exit')));
    expect(names(), contains('session_start'));
  });

  test('a real device, or a build without the test-lab plugin, reports no test_device', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Analytics.testLabProbe = () async => false;
    await Analytics.init(package: 'com.lifecharger.test', appVersion: '1.0.0+1');
    await Future<void>.delayed(Duration.zero);
    expect(names(), isNot(contains('test_device')));
    Analytics.instance.resetForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Analytics.testLabProbe = () async => throw MissingPluginException('no plugin');
    await Analytics.init(package: 'com.lifecharger.test', appVersion: '1.0.0+1');
    await Future<void>.delayed(Duration.zero);
    expect(names(), isNot(contains('test_device')));
  });
}
