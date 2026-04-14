import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _apiUrlKey = 'api_base_url';
  static const String _workerUrlKey = 'worker_url';
  static const String _apiKeyKey = 'api_key';
  static const String defaultApiUrl = '';

  static String _baseUrl = defaultApiUrl;
  static String _workerUrl = '';
  static String _apiKey = '';

  static String get baseUrl => _baseUrl;
  static String get workerUrl => _workerUrl;
  static String get apiKey => _apiKey;
  static bool get isPaired => _apiKey.isNotEmpty;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_apiUrlKey) ?? defaultApiUrl;
    _workerUrl = prefs.getString(_workerUrlKey) ?? '';
    _apiKey = prefs.getString(_apiKeyKey) ?? '';
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
