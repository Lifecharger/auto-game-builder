import '../l10n/app_localizations.dart';
import 'locale_service.dart';

/// The app's texts in the language chosen in Settings, for code that has no
/// `BuildContext` at hand: services, static label tables and helper functions.
///
/// Widgets read `AppLocalizations.of(context)` so they rebuild when the
/// language changes; this getter answers the same language at call time.
AppLocalizations get appL10n =>
    lookupAppLocalizations(LocaleService.instance.currentLocale);
