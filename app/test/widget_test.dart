import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_manager_mobile/main.dart';
import 'package:app_manager_mobile/l10n/app_localizations.dart';
import 'package:app_manager_mobile/services/locale_service.dart';

void main() {
  testWidgets('App builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(const AppManagerMobile());
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
    // With no server configured the shell opens on the login screen; its
    // strings come from the ARB bundle, so this also proves the
    // localization delegate resolved.
    final l10n = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );
    expect(l10n, isNotNull);
    expect(find.text(l10n!.signInWithGoogle), findsWidgets);
  });

  testWidgets('Every supported locale resolves its bundle',
      (WidgetTester tester) async {
    for (final code in LocaleService.supportedCodes) {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return Text(l10n.dashboard);
            },
          ),
        ),
      );
      expect(l10n.localeName, code, reason: 'locale $code did not load');
      expect(l10n.dashboard.isNotEmpty, isTrue, reason: 'empty label for $code');
      expect(l10n.settings.isNotEmpty, isTrue, reason: 'empty label for $code');
      expect(l10n.language.isNotEmpty, isTrue, reason: 'empty label for $code');
    }
  });
}
