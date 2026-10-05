import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'lifecharger_analytics.dart';

/// The server answered a request with an error status.
///
/// Reads exactly like the plain `Exception(message)` it replaces (the screens
/// show `toString()` to the user), but keeps the status code so a failure can
/// be reported by its cause.
class ServerCallException implements Exception {
  const ServerCallException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => 'Exception: $message';
}

/// What this app reports on top of the shared analytics client: which screen
/// is on screen, which action was used, which action failed and why, and how
/// far a new user got.
///
/// Only fixed labels written in this code base are ever passed in. Nothing the
/// user typed or the server returned is reported: no project names, task or
/// report text, addresses, keys or paths.
class Usage {
  Usage._();

  static const String _kMilestones = 'usage_milestones_sent';

  /// The ladder a new user climbs, in the order it is normally reached.
  static const List<String> milestones = <String>[
    'server_connected',
    'first_project_listed',
    'first_project_opened',
    'first_task_created',
    'first_task_run',
    'first_build_queued',
    'first_generation_queued',
    'first_automation_started',
    'first_project_created',
    'first_report_handled',
  ];

  static final Set<String> _failedThisSession = <String>{};
  static Future<Set<String>>? _sentMilestones;

  /// A screen the user is looking at right now. Call it when the screen is
  /// really shown, never when it is merely built behind another one.
  static void screen(String id) => Analytics.log('screen_view', {'dim': id});

  /// An action the user carried out, reported once it has succeeded.
  static void used(String feature) =>
      Analytics.log('feature_use', {'feature': feature});

  /// A server call that failed, by coarse [cause]. Background calls that
  /// repeat on a timer pass [oncePerSession] so one outage is one event.
  static void fail(String action, String cause, {bool oncePerSession = false}) {
    if (oncePerSession && !_failedThisSession.add('$action/$cause')) return;
    Analytics.log('content_fail', {
      'collection': 'server_call',
      'item': action,
      'dim': cause,
    });
  }

  /// Coarse cause of an error status.
  static String causeOfStatus(int statusCode) {
    if (statusCode == 401 || statusCode == 403) return 'unauthorized';
    if (statusCode == 404) return 'not_found';
    if (statusCode == 408 || statusCode == 504) return 'timeout';
    if (statusCode == 413) return 'too_large';
    if (statusCode == 429) return 'rate_limited';
    if (statusCode >= 500) return 'server_error';
    if (statusCode >= 400) return 'rejected';
    return 'unexpected_status';
  }

  /// Coarse cause of a thrown error. Never the error text.
  static String causeOf(Object error) {
    if (error is ServerCallException) return causeOfStatus(error.statusCode);
    if (error is TimeoutException) return 'timeout';
    if (error is SocketException ||
        error is TlsException ||
        error is http.ClientException) {
      return 'offline';
    }
    if (error is FormatException || error is TypeError) return 'bad_response';
    return 'error';
  }

  /// Runs a server call and reports how it ended: [action] as used (plus an
  /// optional [milestone]) when it returns, as failed by cause when it throws.
  /// The result and the error both pass through untouched.
  static Future<T> track<T>(
    String action,
    Future<T> Function() call, {
    String? milestone,
  }) async {
    final T result;
    try {
      result = await call();
    } catch (e) {
      fail(action, causeOf(e));
      rethrow;
    }
    used(action);
    if (milestone != null) unawaited(Usage.milestone(milestone));
    return result;
  }

  /// A step of the ladder in [milestones], reported once per install. The
  /// "already sent" list lives in the app's preferences. While reporting is
  /// switched off nothing is sent and nothing is marked as sent.
  static Future<void> milestone(String id) async {
    final analytics = Analytics.instance;
    if (!analytics.enabled || analytics.installId.isEmpty) return;
    try {
      final sent = await (_sentMilestones ??= _loadSentMilestones());
      if (!sent.add(id)) return;
      Analytics.log('milestone', {'dim': id});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kMilestones, sent.toList());
    } catch (e) {
      debugPrint('[usage] milestone $id not recorded: $e');
    }
  }

  static Future<Set<String>> _loadSentMilestones() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kMilestones) ?? const <String>[]).toSet();
  }

  /// Forgets the in-memory state, as a fresh app start would.
  @visibleForTesting
  static void resetForTest() {
    _failedThisSession.clear();
    _sentMilestones = null;
  }
}
