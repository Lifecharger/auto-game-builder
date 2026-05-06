import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import '../theme/palette.dart';

class ThemeService extends ChangeNotifier {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const String _prefsKey = 'theme_key';
  static const String defaultKey = 'navy';

  String _currentKey = defaultKey;
  String get currentKey => _currentKey;
  AppPalette get currentPalette => AppPalette.byKey(_currentKey);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    final key = stored != null && AppPalette.all.any((p) => p.key == stored)
        ? stored
        : defaultKey;
    _currentKey = key;
    AppColors.applyPalette(AppPalette.byKey(key));
  }

  Future<void> setTheme(String key) async {
    if (key == _currentKey) return;
    if (!AppPalette.all.any((p) => p.key == key)) return;
    _currentKey = key;
    AppColors.applyPalette(AppPalette.byKey(key));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, key);
    notifyListeners();
  }
}
