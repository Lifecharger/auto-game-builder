import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  LocaleService._();
  static final LocaleService instance = LocaleService._();

  static const String _prefsKey = 'locale_code';
  static const String defaultCode = 'en';
  static const List<String> supportedCodes = <String>[
    'en',
    'tr',
    'es',
    'pt',
    'fr',
    'de',
    'ja',
  ];

  Locale _currentLocale = const Locale(defaultCode);
  Locale get currentLocale => _currentLocale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    final code = stored != null && supportedCodes.contains(stored)
        ? stored
        : defaultCode;
    _currentLocale = Locale(code);
  }

  Future<void> setLocale(Locale l) async {
    if (!supportedCodes.contains(l.languageCode)) return;
    if (l.languageCode == _currentLocale.languageCode) return;
    _currentLocale = Locale(l.languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, l.languageCode);
    notifyListeners();
  }
}
