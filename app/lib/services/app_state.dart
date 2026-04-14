import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_model.dart';
import '../models/issue_model.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'cache_service.dart';
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
  Future<void>? _appsInFlight;
  Future<void>? _issuesInFlight;

  List<AppModel> get apps => _apps;
  List<IssueModel> get issues => _issues;
  bool get loading => _loading;
  String? get error => _error;
  int get activeTabIndex => _activeTabIndex;
  bool? get connected => _connected;
  int get pendingTaskCount => _pendingTaskCount;

  /// Total cached builds across all apps — sourced from Hive, no network.
  /// Stays in sync automatically because SyncService writes the builds box
  /// and loadApps() calls notifyListeners() after each sync.
  int get totalBuilds => CacheService.instance.buildCount;
  /// True when 2+ consecutive health checks have failed.
  bool get showOfflineBanner => _consecutiveFailures >= 2;

  /// Whether the user is signed in via Google.
  bool get isSignedIn => AuthService.instance.isSignedIn;

  /// The signed-in user's email, or null.
  String? get userEmail => AuthService.instance.userEmail;

  void updatePendingCount(int count) {
    if (_pendingTaskCount != count) {
      _pendingTaskCount = count;
      notifyListeners();
    }
  }

  void startHealthCheck() {
    _checkHealth();
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 60), (_) => _checkHealth());
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

  Future<void> loadApps() {
    if (_appsInFlight != null) return _appsInFlight!;
    _appsInFlight = _doLoadApps().whenComplete(() => _appsInFlight = null);
    return _appsInFlight!;
  }

  Future<void> _doLoadApps() async {
    _error = null;

    // 1. Paint from cache immediately — zero-latency startup.
    final cached = CacheService.instance.getApps();
    if (cached.isNotEmpty) {
      _apps = cached;
      _loading = false;
      notifyListeners();
    } else {
      _loading = true;
      notifyListeners();
    }

    // 2. Sync delta in the background and refresh from cache when it lands.
    final synced = await SyncService.instance.sync();
    if (synced) {
      _apps = CacheService.instance.getApps();
      _error = null;
    } else if (cached.isEmpty) {
      // No cache AND sync failed — fall back to the plain list endpoint so
      // first-run users see something instead of an empty screen.
      final result = await ApiService.getApps();
      if (result.ok) {
        _apps = result.data!;
      } else {
        _error = result.error ?? 'Failed to load apps';
      }
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
