import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_manager_mobile/services/lifecharger_intro.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('intro strikes into the attached app and removes itself',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final intro = await LifechargerIntroController.create();
    expect(intro.full, isTrue);

    await tester.pumpWidget(LifechargerIntroHost(controller: intro));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(intro.finished, isFalse);

    intro.attachApp(const Text('game'));
    for (var i = 0; i < 300 && !intro.finished; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(intro.finished, isTrue);
    await tester.pump();
    expect(find.text('game'), findsOneWidget);
    expect(find.text('L'), findsNothing);
  });

  testWidgets('second launch the same day plays the short intro',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LifechargerIntroController.create();
    final again = await LifechargerIntroController.create();
    expect(again.full, isFalse);
  });
}
