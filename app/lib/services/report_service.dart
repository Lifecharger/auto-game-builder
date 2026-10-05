import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'app_l10n.dart';
import 'usage_events.dart';

/// One screenshot the user attached to a report.
class ReportShot {
  final List<int> bytes;
  final String filename;
  final MediaType contentType;
  const ReportShot({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });
}

/// Sends bug reports / suggestions to the shared `game-reports` Cloudflare
/// Worker. The endpoint is hardcoded like the games — this is the control app,
/// but its own feedback still goes to the shared worker, not the paired server.
///
/// Write-only: the app never reads reports back, so it holds no secret.
class ReportService {
  static const String _endpoint =
      'https://game-reports.lifecharger.workers.dev/report';
  static const String _package = 'com.lifecharger.appmanager';
  static const int maxShots = 3;
  static const int maxTotalBytes = 5 * 1024 * 1024; // 5 MB

  /// A stable, anonymous per-install id (not tied to any account). Lets us group
  /// multiple reports from the same device without identifying the user.
  static Future<String> _installId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('report_install_id');
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      id = List.generate(
        16,
        (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await prefs.setString('report_install_id', id);
    }
    return id;
  }

  static String get _platform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'other';
  }

  static Future<String> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return 'unknown';
    }
  }

  /// Device brand / model / OS version — everything that helps reproduce a bug.
  /// Returns an empty map if the plugin isn't available on this platform.
  static Future<Map<String, dynamic>> _deviceMeta() async {
    final info = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        return {
          'brand': a.brand,
          'manufacturer': a.manufacturer,
          'model': a.model,
          'device': a.device,
          'product': a.product,
          'os_version': a.version.release,
          'sdk_int': a.version.sdkInt,
        };
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        return {
          'brand': 'Apple',
          'manufacturer': 'Apple',
          'model': i.utsname.machine,
          'name': i.name,
          'os_version': i.systemVersion,
        };
      } else if (Platform.isWindows) {
        final w = await info.windowsInfo;
        return {
          'brand': 'PC',
          'model': w.productName,
          'os_version': w.displayVersion,
          'computer_name': w.computerName,
        };
      } else if (Platform.isMacOS) {
        final m = await info.macOsInfo;
        return {
          'brand': 'Apple',
          'model': m.model,
          'os_version': m.osRelease,
        };
      } else if (Platform.isLinux) {
        final l = await info.linuxInfo;
        return {
          'brand': 'Linux',
          'model': l.prettyName,
          'os_version': l.versionId,
        };
      }
    } catch (_) {
      /* device info is best-effort — never block a report on it */
    }
    return {};
  }

  /// Longest address the form accepts (the RFC limit for a mailbox).
  static const int maxEmailLength = 254;

  static final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  /// The contact address a user typed, cleaned up: trimmed, or empty when
  /// the field was left blank. Null when something was typed that is not
  /// an e-mail address (the form shows an error and does not send).
  static String? cleanEmail(String raw) {
    final e = raw.trim();
    if (e.isEmpty) return '';
    if (e.length > maxEmailLength || !_emailShape.hasMatch(e)) return null;
    return e;
  }

  /// [meta] plus the optional reply address under `contact_email`. The
  /// key is only there when the user typed a valid address.
  static Map<String, dynamic> metaWithContact(
    Map<String, dynamic> meta,
    String contactEmail,
  ) {
    final email = cleanEmail(contactEmail) ?? '';
    return {...meta, if (email.isNotEmpty) 'contact_email': email};
  }

  /// Submit a report. [category] is `bug`, `suggestion` or `other`.
  /// [contactEmail] is OPTIONAL: the address the user typed so the
  /// developer can answer this report.
  /// Returns `null` on success, or a short human-readable error otherwise.
  static Future<String?> submit({
    required String category,
    required String message,
    String contactEmail = '',
    List<ReportShot> shots = const [],
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return appL10n.reportErrEmpty;

    try {
      final req = http.MultipartRequest('POST', Uri.parse(_endpoint));
      req.fields['package'] = _package;
      req.fields['category'] = category;
      req.fields['message'] = trimmed;
      req.fields['app_version'] = await _appVersion();
      req.fields['platform'] = _platform;
      req.fields['install_id'] = await _installId();
      req.fields['meta'] = jsonEncode(
          metaWithContact(await _deviceMeta(), contactEmail));

      var total = 0;
      var i = 0;
      for (final shot in shots.take(maxShots)) {
        total += shot.bytes.length;
        if (total > maxTotalBytes) break;
        req.files.add(http.MultipartFile.fromBytes(
          'shot$i',
          shot.bytes,
          filename: shot.filename,
          contentType: shot.contentType,
        ));
        i++;
      }

      final streamed = await req.send().timeout(const Duration(seconds: 30));
      // Only that a report was sent, or why it was not - never its text,
      // its category or the contact address.
      if (streamed.statusCode == 200) {
        Usage.used('report_send');
        return null;
      }
      Usage.fail('report_send', Usage.causeOfStatus(streamed.statusCode));
      if (streamed.statusCode == 413) {
        return appL10n.reportErrTooLarge;
      }
      return ApiService.messageForCause(
          Usage.causeOfStatus(streamed.statusCode),
          status: streamed.statusCode);
    } catch (e) {
      Usage.fail('report_send', Usage.causeOf(e));
      return ApiService.messageForCause(Usage.causeOf(e));
    }
  }
}
