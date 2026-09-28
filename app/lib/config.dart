import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

class AppConfig {
  /// Android SharedPreferences file that holds ONLY the pairing API key.
  /// `android/app/src/main/res/xml/backup_rules.xml` and
  /// `data_extraction_rules.xml` exclude `<this>.xml` from Android auto-backup
  /// and device-to-device transfer, so the key never leaves the phone, while
  /// every other preference (`FlutterSharedPreferences.xml`) keeps backing up.
  static const String secretPrefsFileName = 'agb_secrets';

  /// Tests flip this to exercise the Android secret-store path on the host.
  @visibleForTesting
  static bool? debugUseSecretStore;

  static bool get _useSecretStore =>
      debugUseSecretStore ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  static SharedPreferencesAsync _secretStore() => SharedPreferencesAsync(
        options: const SharedPreferencesAsyncAndroidOptions(
          backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
          originalSharedPreferencesOptions: AndroidSharedPreferencesStoreOptions(
            fileName: secretPrefsFileName,
          ),
        ),
      );

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
    _apiKey = await _loadApiKey(prefs);
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

  /// Reads the API key. On Android it lives in the backup-excluded secret
  /// file; a key still sitting in the backed-up main prefs (installs from
  /// before this change) is moved there, and removed from the main prefs
  /// only after the secret copy reads back identical, so a failure can never
  /// unpair the app.
  static Future<String> _loadApiKey(SharedPreferences prefs) async {
    final legacy = prefs.getString(_apiKeyKey);
    if (!_useSecretStore) return legacy ?? '';
    final store = _secretStore();
    String? stored;
    try {
      if (legacy != null && legacy.isNotEmpty) {
        // A main-prefs key is always the newest one (setApiKey only writes
        // there when the secret file failed), so it replaces the secret copy.
        await store.setString(_apiKeyKey, legacy);
        stored = await store.getString(_apiKeyKey);
        if (stored == legacy) {
          await prefs.remove(_apiKeyKey);
        }
        return legacy;
      }
      stored = await store.getString(_apiKeyKey);
    } catch (e) {
      debugPrint('AppConfig: secret key store unavailable, using main prefs: $e');
      return (legacy != null && legacy.isNotEmpty) ? legacy : (stored ?? '');
    }
    if (stored != null && stored.isNotEmpty) return stored;
    return legacy ?? '';
  }

  static Future<void> setApiKey(String key) async {
    _apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    if (_useSecretStore) {
      try {
        await _secretStore().setString(_apiKeyKey, key);
        await prefs.remove(_apiKeyKey);
        return;
      } catch (e) {
        debugPrint('AppConfig: secret key store write failed, using main prefs: $e');
      }
    }
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
