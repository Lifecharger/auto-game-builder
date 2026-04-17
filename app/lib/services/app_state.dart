import 'dart:async';
import 'package:flutter/material.dart';
import '../config.dart';
import '../models/app_model.dart';
import '../models/issue_model.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'cache_service.dart';
import 'event_service.dart';
import 'sync_service.dart';

class AppState extends ChangeNotifier {
  List<AppModel> _apps = [];
  List<IssueModel> _issues = [];
  bool _loading = false;
  String? _error;
  int _activeTabIndex = 0;
  bool? _connected;
  Timer? _healthTimer;
  int _pendingTaskCount = 0;
  int _consecutiveFailures = 0;
  int? _issuesRequestedAppId;
  Future<void>? _appsInFlight;
  Future<void>? _issuesInFlight;
  EventService? _eventService;

  List<AppModel> get apps => _apps;
  List<IssueModel> get issues => _issues;
  bool get loading => _loading;
  String? get error => _error;
  int get activeTabIndex => _activeTabIndex;
  bool? get connected => _connected;
  int get pendingTaskCount => _pendingTaskCount;
  int? get issuesRequestedAppId => _issuesRequestedAppId;

  /// Total cached builds across all apps — sourced from Hive, no network.
  /// Stays in sync automatically because SyncService writes the builds box
  /// and loadApps() calls notifyListeners() after each sync.
  int get totalBuilds => CacheService.instance.buildCount;
  /// True when consecutive health checks have failed at or beyond the
  /// configured offline-banner threshold.
  bool get showOfflineBanner =>
      _consecutiveFailures >= AppConfig.offlineBannerFailureThreshold;

  /// Whether the user is signed in via Google.
  bool get isSignedIn => AuthService.instance.isSignedIn;

  /// The signed-in user's email, or null.
  String? get userEmail => AuthService.instance.userEmail;

  void requestIssuesForApp(int appId) {
    _issuesRequestedAppId = appId;
    notifyListeners();
  }

  void clearIssuesRequest() {
    _issuesRequestedAppId = null;
  }

  /// Bind the EventService so force-refresh can stop/restart it.
  void bindEventService(EventService es) => _eventService = es;

  void updatePendingCount(int count) {
    if (_pendingTaskCount != count) {
      _pendingTaskCount = count;
      notifyListeners();
    }
  }

  void startHealthCheck() {
    _checkHealth();
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(
      const Duration(seconds: AppConfig.healthCheckIntervalSeconds),
      (_) => _checkHealth(),
    );
  }

  Future<void> _checkHealth() async {
    final ok = await ApiService.healthCheck();
    final prevBanner = showOfflineBanner;
    if (ok) {
      _consecutiveFailures = 0;
    } else {
      _consecutiveFailures++;
    }
    if (_connected != ok || showOfflineBanner != prevBanner) {
      _connected = ok;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    super.dispose();
  }

  void setActiveTab(int index) {
    if (_activeTabIndex != index) {
      _activeTabIndex = index;
      notifyListeners();
    }
  }

  Future<void> loadApps({bool force = false}) {
    if (_appsInFlight != null) return _appsInFlight!;
    _appsInFlight =
        _doLoadApps(force: force).whenComplete(() => _appsInFlight = null);
    return _appsInFlight!;
  }

  /// Re-read the apps cache and notify listeners. Called by EventService
  /// after it applies a server-pushed delta (app_updated, app_status_changed,
  /// etc.) — skips the network round trip and the loading spinner because
  /// we know the cache just got fresh data.
  void refreshFromCache() {
    _apps = CacheService.instance.getApps();
    _error = null;
    notifyListeners();
  }

  Future<void> _doLoadApps({bool force = false}) async {
    // 1. Paint from cache immediately — zero-latency startup. Skip the
    // optimistic paint on a forced refresh because the user explicitly
    // asked us to throw the cache away.
    final cached = force ? <AppModel>[] : CacheService.instance.getApps();
    if (cached.isNotEmpty) {
      _apps = cached;
      _loading = false;
      notifyListeners();
    } else {
      _loading = true;
      notifyListeners();
    }

    // On force refresh, stop EventService so replayed old events can't
    // overwrite the fresh data we're about to fetch. It reconnects after
    // sync completes with the updated last_seq cursor.
    if (force) _eventService?.stop();

    // 2. Sync delta in the background and refresh from cache when it lands.
    final synced = await SyncService.instance.sync(force: force);
    if (force) _eventService?.start();
    if (synced) {
      _apps = CacheService.instance.getApps();
      _error = null;
    } else if (cached.isEmpty) {
      // No cache AND sync failed — fall back to the plain list endpoint so
      // first-run users see something instead of an empty screen.
      final result = await ApiService.getApps();
      if (result.ok) {
        _apps = result.data!;
        _error = null;
      } else {
        _error = result.error ?? SyncService.instance.lastError ?? 'Failed to load apps';
      }
    } else {
      // Sync failed but we have cached data — surface the failure so the
      // dashboard's "Synced Xm ago" label flips to "Sync failed" instead of
      // pretending the data is fresh. Cached apps stay on screen.
      _error = SyncService.instance.lastError ?? 'Sync failed';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadIssues({String? status}) {
    if (_issuesInFlight != null) return _issuesInFlight!;
    _issuesInFlight = _doLoadIssues(status: status).whenComplete(() => _issuesInFlight = null);
    return _issuesInFlight!;
  }

  Future<void> _doLoadIssues({String? status}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    final cached = CacheService.instance.getIssues(status: status);
    if (cached.isNotEmpty) {
      _issues = cached;
      _loading = false;
      notifyListeners();
    }

    final result = await ApiService.getIssues(status: status);
    if (result.ok) {
      _issues = result.data!;
    } else if (cached.isEmpty) {
      _error = result.error ?? 'Failed to load issues';
    }
    _loading = false;
    notifyListeners();
  }

  String getAppName(int appId) {
    final app = _apps.where((a) => a.id == appId).firstOrNull;
    return app?.name ?? 'App #$appId';
  }
}
