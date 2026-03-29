import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _apiUrlKey = 'api_base_url';
  static const String defaultApiUrl = '';

  static String _baseUrl = defaultApiUrl;

  static String get baseUrl => _baseUrl;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_apiUrlKey) ?? defaultApiUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    // Remove trailing slash if present
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiUrlKey, url);
  }
}
