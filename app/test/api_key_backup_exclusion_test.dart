import 'dart:io';

import 'package:app_manager_mobile/config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The pairing API key must live outside the auto-backed-up main prefs file on
/// Android (AppConfig.secretPrefsFileName, excluded by the backup rules), and
/// installs that still have it in the main prefs must keep working.
void main() {
  late InMemorySharedPreferencesAsync secret;

  setUp(() {
    secret = InMemorySharedPreferencesAsync.empty();
    SharedPreferencesAsyncPlatform.instance = secret;
    AppConfig.debugUseSecretStore = true;
  });

  tearDown(() => AppConfig.debugUseSecretStore = null);

  Future<String?> secretKey() =>
      SharedPreferencesAsync().getString('api_key');

  test('old install: key in main prefs moves to the secret file', () async {
    SharedPreferences.setMockInitialValues({
      'api_key': 'old-key',
      'worker_url': 'https://w.example',
      'show_app_icons': true,
    });
    await AppConfig.load();

    expect(AppConfig.apiKey, 'old-key');
    expect(AppConfig.isPaired, isTrue);
    expect(await secretKey(), 'old-key');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('api_key'), isNull,
        reason: 'the backed-up main prefs file must no longer hold the key');
    // Everything else stays in the backed-up prefs untouched.
    expect(prefs.getString('worker_url'), 'https://w.example');
    expect(prefs.getBool('show_app_icons'), isTrue);
    expect(AppConfig.workerUrl, 'https://w.example');
    expect(AppConfig.showAppIcons, isTrue);
  });

  test('setApiKey writes only the secret file', () async {
    SharedPreferences.setMockInitialValues({});
    await AppConfig.load();
    await AppConfig.setApiKey('new-key');

    expect(await secretKey(), 'new-key');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('api_key'), isNull);

    await AppConfig.load();
    expect(AppConfig.apiKey, 'new-key');
  });

  test('a main-prefs key (fallback write) wins over a stale secret copy',
      () async {
    await SharedPreferencesAsync().setString('api_key', 'stale');
    SharedPreferences.setMockInitialValues({'api_key': 'fresh'});
    await AppConfig.load();
    expect(AppConfig.apiKey, 'fresh');
    expect(await secretKey(), 'fresh');
  });

  test('non-Android platforms keep using the main prefs', () async {
    AppConfig.debugUseSecretStore = false;
    SharedPreferences.setMockInitialValues({'api_key': 'desk-key'});
    await AppConfig.load();
    expect(AppConfig.apiKey, 'desk-key');
    await AppConfig.setApiKey('desk-2');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('api_key'), 'desk-2');
    expect(await secretKey(), isNull);
  });

  test('Android backup rules exclude exactly the secret file', () {
    const res = 'android/app/src/main/res/xml';
    final file = '${AppConfig.secretPrefsFileName}.xml';
    final legacy = File('$res/backup_rules.xml').readAsStringSync();
    final modern = File('$res/data_extraction_rules.xml').readAsStringSync();
    final exclude = '<exclude domain="sharedpref" path="$file" />';
    expect(legacy, contains(exclude));
    expect(RegExp(RegExp.escape(exclude)).allMatches(modern).length, 2,
        reason: 'cloud-backup and device-transfer');
    expect(legacy, isNot(contains('<include')),
        reason: 'no include = everything else keeps backing up');
    expect(modern, isNot(contains('<include')));
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
  });
}
