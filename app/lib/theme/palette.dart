import 'package:flutter/material.dart';

@immutable
class AppPalette {
  final String key;
  final String displayName;
  final Brightness brightness;
  final Color bgDark;
  final Color bgSidebar;
  final Color bgCard;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  const AppPalette({
    required this.key,
    required this.displayName,
    required this.brightness,
    required this.bgDark,
    required this.bgSidebar,
    required this.bgCard,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
  });

  static const AppPalette navy = AppPalette(
    key: 'navy',
    displayName: 'Navy',
    brightness: Brightness.dark,
    bgDark: Color(0xFF1A1A2E),
    bgSidebar: Color(0xFF16213E),
    bgCard: Color(0xFF0F3460),
    accent: Color(0xFFE94560),
    success: Color(0xFF2ECC71),
    warning: Color(0xFFF39C12),
    error: Color(0xFFE74C3C),
    info: Color(0xFF3498DB),
  );

  static const AppPalette light = AppPalette(
    key: 'light',
    displayName: 'Light',
    brightness: Brightness.light,
    bgDark: Color(0xFFF5F5F7),
    bgSidebar: Color(0xFFFFFFFF),
    bgCard: Color(0xFFFFFFFF),
    accent: Color(0xFF3F51B5),
    success: Color(0xFF2E7D32),
    warning: Color(0xFFEF6C00),
    error: Color(0xFFC62828),
    info: Color(0xFF1565C0),
  );

  static const AppPalette neon = AppPalette(
    key: 'neon',
    displayName: 'Neon',
    brightness: Brightness.dark,
    bgDark: Color(0xFF050008),
    bgSidebar: Color(0xFF0E0220),
    bgCard: Color(0xFF1A0533),
    accent: Color(0xFFFF00FF),
    success: Color(0xFF39FF14),
    warning: Color(0xFFFFD300),
    error: Color(0xFFFF003C),
    info: Color(0xFF00F0FF),
  );

  static const AppPalette steampunk = AppPalette(
    key: 'steampunk',
    displayName: 'Steampunk',
    brightness: Brightness.dark,
    bgDark: Color(0xFF2B1B0E),
    bgSidebar: Color(0xFF3D2A18),
    bgCard: Color(0xFF4E3622),
    accent: Color(0xFFB87333),
    success: Color(0xFF8FA055),
    warning: Color(0xFFD4A24C),
    error: Color(0xFFA0522D),
    info: Color(0xFF8B7355),
  );

  static const AppPalette pink = AppPalette(
    key: 'pink',
    displayName: 'Pink',
    brightness: Brightness.light,
    bgDark: Color(0xFFFFE4EC),
    bgSidebar: Color(0xFFFFC9DD),
    bgCard: Color(0xFFFFF0F5),
    accent: Color(0xFFE91E63),
    success: Color(0xFFE57FBE),
    warning: Color(0xFFFF8FAB),
    error: Color(0xFFD81B60),
    info: Color(0xFFAD1457),
  );

  static const List<AppPalette> all = <AppPalette>[
    navy,
    light,
    neon,
    steampunk,
    pink,
  ];

  static AppPalette byKey(String key) {
    for (final p in all) {
      if (p.key == key) return p;
    }
    return navy;
  }
}
