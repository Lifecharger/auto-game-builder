import 'package:flutter/material.dart';

class AppColors {
  static const Color bgDark = Color(0xFF1A1A2E);
  static const Color bgSidebar = Color(0xFF16213E);
  static const Color bgCard = Color(0xFF0F3460);
  static const Color accent = Color(0xFFE94560);
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);
  static const Color info = Color(0xFF3498DB);

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
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accent,
      surface: AppColors.bgSidebar,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.bgDark,
    cardColor: AppColors.bgCard,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgSidebar,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.bgCard,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bgSidebar,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: Colors.grey,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.bgCard,
      selectedColor: AppColors.accent,
      labelStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.bgCard,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
