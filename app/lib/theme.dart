import 'package:flutter/material.dart';
import 'theme/palette.dart';

class AppColors {
  static AppPalette _activePalette = AppPalette.navy;

  static AppPalette get activePalette => _activePalette;

  static void applyPalette(AppPalette p) {
    _activePalette = p;
  }

  static Color get bgDark => _activePalette.bgDark;
  static Color get bgSidebar => _activePalette.bgSidebar;
  static Color get bgCard => _activePalette.bgCard;
  static Color get accent => _activePalette.accent;
  static Color get success => _activePalette.success;
  static Color get warning => _activePalette.warning;
  static Color get error => _activePalette.error;
  static Color get info => _activePalette.info;

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'idle':
        return Colors.grey;
      case 'queued':
        return const Color(0xFFF1C40F); // amber — waiting for turn
      case 'building':
        return info;
      case 'uploading':
        return const Color(0xFF9B59B6); // purple — distinct from build blue
      case 'working':
        return const Color(0xFF1ABC9C); // teal — a task is running right now
      case 'fixing':
        return warning;
      case 'deploying':
        return info;
      case 'error':
        return error;
      case 'published':
        return success;
      default:
        return Colors.grey;
    }
  }

  static Color priorityColor(int priority) {
    switch (priority) {
      case 1:
        return error;
      case 2:
        return warning;
      case 3:
        return Colors.yellow;
      case 4:
        return info;
      case 5:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  static String priorityLabel(int priority) {
    switch (priority) {
      case 1:
        return 'Critical';
      case 2:
        return 'High';
      case 3:
        return 'Medium';
      case 4:
        return 'Low';
      case 5:
        return 'Wishlist';
      default:
        return 'Unknown';
    }
  }

  static Color agentColor(String agent) {
    switch (agent.toLowerCase()) {
      case 'claude': return accent;
      case 'gemini': return info;
      case 'codex': return success;
      case 'local': return warning;
      default: return Colors.grey;
    }
  }

  static Color taskStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return warning;
      case 'in_progress': return info;
      case 'completed': return success;
      case 'done': return success;
      case 'built': return const Color(0xFF9B59B6);
      case 'failed': return error;
      case 'divided': return const Color(0xFF3498DB);
      default: return Colors.grey;
    }
  }

  static Color taskTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'issue': return warning;
      case 'bug': return error;
      case 'fix': return info;
      case 'feature': return success;
      case 'idea': return Color(0xFFAB47BC);
      default: return Colors.grey;
    }
  }

  static IconData appTypeIcon(String appType) {
    switch (appType.toLowerCase()) {
      case 'flutter':
        return Icons.phone_android;
      case 'godot':
        return Icons.games;
      case 'python':
        return Icons.terminal;
      case 'web':
        return Icons.web;
      case 'phaser':
        return Icons.sports_esports;
      default:
        return Icons.apps;
    }
  }
}

ThemeData buildAppTheme() {
  final palette = AppColors.activePalette;
  final isDark = palette.brightness == Brightness.dark;
  final onBg = isDark ? Colors.white : Colors.black87;
  final mutedOn = isDark ? Colors.grey : Colors.grey.shade700;
  return ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    colorScheme: (isDark ? ColorScheme.dark : ColorScheme.light)(
      primary: AppColors.accent,
      secondary: AppColors.accent,
      surface: AppColors.bgSidebar,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.bgDark,
    cardColor: AppColors.bgCard,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bgSidebar,
      foregroundColor: onBg,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.bgCard,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.bgSidebar,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: mutedOn,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.bgCard,
      selectedColor: AppColors.accent,
      labelStyle: TextStyle(color: onBg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: mutedOn),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: mutedOn),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.accent),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.bgCard,
      contentTextStyle: TextStyle(color: onBg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
