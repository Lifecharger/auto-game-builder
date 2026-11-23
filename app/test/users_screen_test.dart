import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:app_manager_mobile/l10n/app_localizations.dart';
import 'package:app_manager_mobile/services/api_service.dart';
import 'package:app_manager_mobile/services/mode_service.dart';
import 'package:app_manager_mobile/services/user_session.dart';
import 'package:app_manager_mobile/screens/users_screen.dart';

/// Multi-user AGB: the admin-only Users screen, and what a member key hides.
class _FakeUsersApi implements UsersApi {
  final users = <UserEntry>[
    const UserEntry(id: 1, name: 'admin', role: 'admin', active: true, appCount: 3),
    const UserEntry(id: 2, name: 'User 2', role: 'member', active: true,
        projectsRoot: '/srv/user2', appCount: 1),
  ];
  final deactivated = <int>[];
  final rotated = <int>[];
  String? lastRoot;

  @override
  Future<ApiResult<List<UserEntry>>> list() async => ApiResult.success(List.of(users));

  @override
  Future<ApiResult<IssuedKey>> addMember(String name, String projectsRoot) async {
    lastRoot = projectsRoot;
    final u = UserEntry(id: users.length + 1, name: name, role: 'member', active: true,
        projectsRoot: projectsRoot);
    users.add(u);
    return ApiResult.success(IssuedKey(u, 'new-key-$name'));
  }

  @override
  Future<ApiResult<bool>> deactivate(int id) async {
    deactivated.add(id);
    final i = users.indexWhere((u) => u.id == id);
    final u = users[i];
    users[i] = UserEntry(id: u.id, name: u.name, role: u.role, active: false,
        projectsRoot: u.projectsRoot, appCount: u.appCount);
    return const ApiResult.success(true);
  }

  @override
  Future<ApiResult<IssuedKey>> rotateKey(int id) async {
    rotated.add(id);
    return ApiResult.success(IssuedKey(users.firstWhere((u) => u.id == id), 'rotated-key'));
  }
}

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? clipboard;

  setUp(() {
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
  });

  tearDown(() {
    UserSession.instance.setForTest(null);
    ModeService.setMode(ModeService.code);
  });

  testWidgets('lists users; the main admin has no actions', (tester) async {
    final api = _FakeUsersApi();
    await tester.pumpWidget(_app(UsersScreen(api: api, workerUrl: 'https://worker.example')));
    await tester.pumpAndSettle();
    expect(find.text('admin'), findsOneWidget);
    expect(find.text('User 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('user-menu-1')), findsNothing);
    expect(find.byKey(const ValueKey('user-menu-2')), findsOneWidget);
  });

  testWidgets('add member shows the key once, copyable, with a pairing QR',
      (tester) async {
    final api = _FakeUsersApi();
    await tester.pumpWidget(_app(UsersScreen(api: api, workerUrl: 'https://worker.example')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('users-add')));
    await tester.pumpAndSettle();
    // Empty name is refused in the dialog itself.
    await tester.tap(find.byKey(const ValueKey('users-create')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('users-name')), 'User 3');
    await tester.enterText(find.byKey(const ValueKey('users-root')), '/srv/user3');
    await tester.tap(find.byKey(const ValueKey('users-create')));
    await tester.pumpAndSettle();

    expect(api.lastRoot, '/srv/user3');
    expect(find.text('Key for User 3'), findsOneWidget);
    expect(find.text('new-key-User 3'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('users-copy')));
    await tester.pumpAndSettle();
    expect(clipboard, 'new-key-User 3');
    expect(find.text('Copied'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('users-key-done')));
    await tester.pumpAndSettle();
    expect(find.text('new-key-User 3'), findsNothing, reason: 'the key is never shown again');
    expect(find.text('User 3'), findsOneWidget);
  });

  testWidgets('deactivate asks first, then marks the user inactive', (tester) async {
    final api = _FakeUsersApi();
    await tester.pumpWidget(_app(UsersScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('user-menu-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate User 2?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Deactivate'));
    await tester.pumpAndSettle();
    expect(api.deactivated, [2]);
    expect(find.textContaining('Inactive'), findsOneWidget);
    expect(find.byKey(const ValueKey('user-menu-2')), findsNothing);
  });

  testWidgets('pairing code carries the key and the worker URL', (tester) async {
    final code = KeyOnceDialog.pairingCode('k1', 'https://worker.example');
    final decoded = jsonDecode(utf8.decode(base64Decode(code))) as Map;
    expect(decoded, {'api_key': 'k1', 'worker_url': 'https://worker.example'});
  });

  testWidgets('AdminOnly shows admin tools to admins and hides them from members',
      (tester) async {
    await tester.pumpWidget(_app(const Scaffold(
      body: AdminOnly(child: Text('admin tool')),
    )));
    // Unknown user (older single-key server) = admin.
    expect(find.text('admin tool'), findsOneWidget);

    UserSession.instance.setForTest(const CurrentUser(id: 2, name: 'User 2', role: 'member'));
    await tester.pump();
    expect(find.text('admin tool'), findsNothing);

    UserSession.instance.setForTest(const CurrentUser(id: 1, name: 'admin', role: 'admin'));
    await tester.pump();
    expect(find.text('admin tool'), findsOneWidget);
  });

  test('a member stays in Code mode', () {
    UserSession.instance.setForTest(const CurrentUser(id: 2, name: 'User 2', role: 'member'));
    ModeService.setMode(ModeService.asset);
    expect(ModeService.isCode, isTrue);
    ModeService.setMode(ModeService.delivery);
    expect(ModeService.isCode, isTrue);

    UserSession.instance.setForTest(const CurrentUser(id: 1, name: 'admin', role: 'admin'));
    ModeService.setMode(ModeService.asset);
    expect(ModeService.isAsset, isTrue);
  });
}
