import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_manager_mobile/l10n/app_localizations.dart';
import 'package:app_manager_mobile/main.dart';
import 'package:app_manager_mobile/services/api_service.dart';
import 'package:app_manager_mobile/services/locale_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A failed server call tells the user what really went wrong - a gateway
/// error page, a refused key, a dead connection and a slow server each read
/// as what they are, in the app's language - and the banner at the top of the
/// app names a refused API key instead of calling the server unreachable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final en = lookupAppLocalizations(const Locale('en'));

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocaleService.instance.setLocale(const Locale('en'));
    ApiService.keyRefused.value = false;
  });

  tearDown(() async {
    await LocaleService.instance.setLocale(const Locale('en'));
    ApiService.keyRefused.value = false;
  });

  Future<T> withServer<T>(
    Future<http.Response> Function(http.Request request) answer,
    Future<T> Function() body,
  ) =>
      http.runWithClient(body, () => MockClient(answer));

  group('the message for a cause', () {
    test('names each cause in plain words', () {
      expect(ApiService.messageForCause('offline'), en.errOffline);
      expect(ApiService.messageForCause('timeout'), en.errTimeout);
      expect(ApiService.messageForCause('timeout', status: 504),
          en.errGatewayTimeout(504));
      expect(ApiService.messageForCause('unauthorized', status: 401),
          en.errUnauthorized(401));
      expect(ApiService.messageForCause('not_found', status: 404),
          en.errNotFound(404));
      expect(ApiService.messageForCause('rate_limited', status: 429),
          en.errRateLimited(429));
      expect(ApiService.messageForCause('too_large', status: 413),
          en.errTooLarge(413));
      expect(ApiService.messageForCause('server_error', status: 500),
          en.errServer(500));
      expect(ApiService.messageForCause('server_error', status: 502),
          en.errGateway(502));
      expect(ApiService.messageForCause('server_error', status: 503),
          en.errGateway(503));
      expect(ApiService.messageForCause('rejected', status: 400),
          en.errRejected(400));
      expect(ApiService.messageForCause('bad_response'), en.errBadResponse);
      expect(ApiService.messageForCause('error'), en.errUnknown);
    });

    test('carries the status code and says where to fix a refused key', () {
      expect(en.errGateway(502), contains('502'));
      expect(en.errServer(500), contains('500'));
      expect(en.errUnauthorized(401), contains('401'));
      expect(en.errUnauthorized(401), contains('Settings'));
    });

    test('follows the language the app is set to', () async {
      await LocaleService.instance.setLocale(const Locale('de'));
      expect(ApiService.messageForCause('offline'),
          lookupAppLocalizations(const Locale('de')).errOffline);
      expect(ApiService.messageForCause('offline'), isNot(en.errOffline));
    });
  });

  group('a build request', () {
    Future<String?> deployError(
            Future<http.Response> Function(http.Request) answer) async =>
        (await withServer(answer, () => ApiService.deployApp(7))).error;

    test('answered by a gateway error page says the server is unreachable',
        () async {
      final error = await deployError(
          (_) async => http.Response('<html>502 Bad Gateway</html>', 502));
      expect(error, en.errGateway(502));
      expect(error, isNot(en.errBadResponse));
    });

    test('answered by an empty 500 says server error with the code', () async {
      expect(await deployError((_) async => http.Response('', 500)),
          en.errServer(500));
    });

    test('refused for the key says not authorized', () async {
      expect(await deployError((_) async => http.Response('Forbidden', 403)),
          en.errUnauthorized(403));
    });

    test('that times out says so', () async {
      expect(await deployError((_) async => throw TimeoutException('slow')),
          en.errTimeout);
    });

    test('that cannot connect says so', () async {
      expect(
          await deployError(
              (_) async => throw const SocketException('unreachable')),
          en.errOffline);
    });

    test('keeps the reason the server gave when there is one', () async {
      expect(
          await deployError((_) async => http.Response(
              jsonEncode({'detail': 'A build is already running'}), 409)),
          'A build is already running');
    });

    test('with a JSON error that carries no reason falls back to the cause',
        () async {
      expect(
          await deployError(
              (_) async => http.Response(jsonEncode({'error': true}), 400)),
          en.errRejected(400));
    });
  });

  group('other calls', () {
    test('a task refused by a gateway error page reads the same way', () async {
      final result = await withServer(
        (_) async => http.Response('<html>Service unavailable</html>', 503),
        () => ApiService.createAppTask(appId: 7, title: 'x'),
      );
      expect(result.error, en.errGateway(503));
    });

    test('a report pull behind a gateway error page reads the same way',
        () async {
      final result = await withServer(
        (_) async => http.Response('<html>Bad gateway</html>', 502),
        () => ApiService.pullReportsNow(),
      );
      expect(result.error, en.errGateway(502));
    });
  });

  group('a refused API key', () {
    test('is noticed on a read and forgotten on the next accepted one',
        () async {
      await withServer(
        (_) async => http.Response('', 401),
        () => ApiService.getSync(),
      );
      expect(ApiService.keyRefused.value, isTrue);

      // "Not found" says nothing about the key either way.
      await withServer(
        (_) async => http.Response('', 404),
        () => ApiService.getApp(1),
      );
      expect(ApiService.keyRefused.value, isTrue);

      await withServer(
        (_) async => http.Response('{}', 200),
        () => ApiService.getSync(),
      );
      expect(ApiService.keyRefused.value, isFalse);
    });

    test('a passing health check does not clear it: that route needs no key',
        () async {
      ApiService.keyRefused.value = true;
      await withServer(
        (_) async => http.Response('{}', 200),
        () => ApiService.healthCheck(),
      );
      expect(ApiService.keyRefused.value, isTrue);
    });

    test('a gateway that refuses the key on the health route sets it',
        () async {
      await withServer(
        (_) async => http.Response('', 401),
        () => ApiService.healthCheck(),
      );
      expect(ApiService.lastHealthFailure, 'unauthorized');
      expect(ApiService.keyRefused.value, isTrue);
    });

    test('the banner names the key, not an outage, in every language', () {
      for (final code in LocaleService.supportedCodes) {
        final l10n = lookupAppLocalizations(Locale(code));
        expect(offlineBannerText(l10n, keyRefused: true),
            l10n.apiKeyRefusedBanner);
        expect(offlineBannerText(l10n, keyRefused: false),
            l10n.serverUnreachable);
        expect(l10n.apiKeyRefusedBanner, isNot(l10n.serverUnreachable));
      }
    });
  });
}
