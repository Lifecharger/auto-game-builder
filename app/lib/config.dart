import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _apiUrlKey = 'api_base_url';
  static const String _workerUrlKey = 'worker_url';
  static const String _apiKeyKey = 'api_key';
  static const String _showAppIconsKey = 'show_app_icons';
  static const String defaultApiUrl = '';

  /// Period of the recurring background health check that updates the
  /// connection indicator and offline banner.
  static const int healthCheckIntervalSeconds = 60;

  /// Number of consecutive failed health checks before the offline
  /// banner is shown to the user.
  static const int offlineBannerFailureThreshold = 2;

  /// Debounce window before EventService coalesces a burst of cache
  /// writes into a single dashboard rebuild.
  static const int eventRefreshDebounceMs = 50;

  /// Debounce window before EventService POSTs the latest applied seq
  /// back to the server as an ack.
  static const int eventAckDebounceSeconds = 2;

  /// Cap for SSE reconnect backoff (the value doubles after each
  /// failure and is clamped to this maximum).
  static const int eventReconnectMaxBackoffSeconds = 30;

  /// OAuth web client ID for Google Sign-In. Not secret — ships in
  /// every Android APK — but kept centralized so it can be rotated or
  /// swapped per build flavor without touching service code.
  static const String googleWebClientId =
      '690975384091-q12j999ied80kavhjjrbo666t61jg7dp.apps.googleusercontent.com';

  static String _baseUrl = defaultApiUrl;
  static String _workerUrl = '';
  static String _apiKey = '';
  static bool _showAppIcons = false;

  static String get baseUrl => _baseUrl;
  static String get workerUrl => _workerUrl;
  static String get apiKey => _apiKey;
  static bool get isPaired => _apiKey.isNotEmpty;
  static bool get showAppIcons => _showAppIcons;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_apiUrlKey) ?? defaultApiUrl;
    _workerUrl = prefs.getString(_workerUrlKey) ?? '';
    _apiKey = prefs.getString(_apiKeyKey) ?? '';
    _showAppIcons = prefs.getBool(_showAppIconsKey) ?? false;
  }

  static Future<void> setBaseUrl(String url) async {
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiUrlKey, url);
  }

  static Future<void> setWorkerUrl(String url) async {
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    _workerUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_workerUrlKey, url);
  }

  static Future<void> setApiKey(String key) async {
    _apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, key);
  }

  static Future<void> setShowAppIcons(bool value) async {
    _showAppIcons = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showAppIconsKey, value);
  }

  /// Apply pairing data from QR code (base64 JSON with api_key + worker_url).
  /// Returns true on success, false if the data is malformed.
  static Future<bool> applyPairingData(String base64Data) async {
    try {
      final decoded = jsonDecode(utf8.decode(base64Decode(base64Data)))
          as Map<String, dynamic>;
      await setApiKey(decoded['api_key'] as String);
      final url = decoded['worker_url'] as String? ?? '';
      if (url.isNotEmpty) {
        await setWorkerUrl(url);
        await setBaseUrl(url);
      }
      return true;
    } catch (e) {
      debugPrint('Failed to apply pairing data: $e');
      return false;
    }
  }
}
