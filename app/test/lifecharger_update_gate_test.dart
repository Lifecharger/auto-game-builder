// Shared test for the forced update gate (copied unchanged into every app's test/ folder).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_manager_mobile/services/lifecharger_update_gate.dart';

Widget _app() => const MaterialApp(home: Scaffold(body: Text('game')));

void main() {
  tearDown(() {
    ForcedUpdateGate.enabledInTests = false;
    ForcedUpdateGate.checkForTest = null;
  });

  testWidgets('no update: the app plays, no gate', (tester) async {
    ForcedUpdateGate.enabledInTests = true;
    ForcedUpdateGate.checkForTest = () async => false;
    await tester.pumpWidget(ForcedUpdateGate(child: _app()));
    await tester.pumpAndSettle();
    expect(find.text('game'), findsOneWidget);
    expect(find.byKey(const Key('forced_update_gate')), findsNothing);
  });

  testWidgets('update available: the gate covers the app and cannot be skipped', (tester) async {
    ForcedUpdateGate.enabledInTests = true;
    var checks = 0;
    ForcedUpdateGate.checkForTest = () async {
      checks++;
      return true;
    };
    await tester.pumpWidget(ForcedUpdateGate(child: _app()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forced_update_gate')), findsOneWidget);
    // the app stays mounted underneath, but nothing reaches it
    expect(find.text('game', skipOffstage: false), findsOneWidget);
    await tester.tap(find.byKey(const Key('forced_update_button')));
    await tester.pumpAndSettle();
    expect(checks, greaterThanOrEqualTo(2)); // Update asks Play again
    expect(find.byKey(const Key('forced_update_gate')), findsOneWidget);
  });

  testWidgets('a failed check never locks the player out', (tester) async {
    ForcedUpdateGate.enabledInTests = true;
    ForcedUpdateGate.checkForTest = () async => throw Exception('offline');
    await tester.pumpWidget(ForcedUpdateGate(child: _app()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forced_update_gate')), findsNothing);
    expect(find.text('game'), findsOneWidget);
  });

  testWidgets('the update lands: the gate lifts', (tester) async {
    ForcedUpdateGate.enabledInTests = true;
    var available = true;
    ForcedUpdateGate.checkForTest = () async => available;
    await tester.pumpWidget(ForcedUpdateGate(child: _app()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forced_update_gate')), findsOneWidget);
    available = false;
    await tester.tap(find.byKey(const Key('forced_update_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forced_update_gate')), findsNothing);
  });
}
