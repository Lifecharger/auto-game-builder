import 'package:flutter/services.dart';

class InstalledAppsService {
  static const _channel = MethodChannel('app_manager/installed_apps');

  /// Returns a map of packageName -> installedVersion (null if not installed).
  static Future<Map<String, String?>> getInstalledVersions(
      List<String> packageNames) async {
    // Filter out empty package names
    final validNames = packageNames.where((p) => p.isNotEmpty).toList();
    if (validNames.isEmpty) return {};
    try {
      final result =
          await _channel.invokeMethod('getInstalledVersions', validNames);
      if (result is Map) {
        return result
            .map((key, value) => MapEntry(key.toString(), value?.toString()));
      }
      return {};
    } on PlatformException {
      return {};
    } on MissingPluginException {
      // Platform channel not available (e.g. on iOS or web)
      return {};
    }
  }
}
