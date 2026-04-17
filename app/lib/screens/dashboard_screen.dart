import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/app_model.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../services/installed_apps_service.dart';
import '../theme.dart';
import '../widgets/cached_app_icon.dart';
import '../widgets/dashboard/brainstorm_sheet.dart';
import '../widgets/dashboard/create_app_sheet.dart';
import 'app_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  Map<String, String?> _installedVersions = {};
  Timer? _pollTimer;
  Timer? _tickTimer;
  bool _appInForeground = true;
  static const _myTabIndex = 0;
  static const _completedAppsKey = 'completed_app_ids';
  static const _postponedAppsKey = 'postponed_app_ids';
  static const _completedExpandedKey = 'dashboard_completed_expanded';
  static const _postponedExpandedKey = 'dashboard_postponed_expanded';
  DateTime? _lastSyncedAt;
  bool _syncFailed = false;

  Set<int> _completedAppIds = {};
  Set<int> _postponedAppIds = {};
  bool _completedExpanded = false;
  bool _postponedExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCompletedApps();
    _loadPostponedApps();
    // main.dart already kicks off loadApps() via the provider factory.
    // That means cached apps have typically already painted by the time we get here.
    // We only need to: (1) trigger the device-local installed-version scan, and
    // (2) await any in-flight sync to update the "synced Xm ago" label.
    Future.microtask(() async {
      if (!mounted) return;
      final state = context.read<AppState>();
      _loadInstalledVersions();
      await state.loadApps();
      if (!mounted) return;
      setState(() {
        _syncFailed = state.error != null;
        if (!_syncFailed) _lastSyncedAt = DateTime.now();
      });
    });
    _startPolling();
    // Tick every 5s to update the "Xm ago" label
    _tickTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _lastSyncedAt != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
  }

  Future<void> _loadCompletedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_completedAppsKey) ?? [];
    final expanded = prefs.getBool(_completedExpandedKey) ?? false;
    if (mounted) {
      setState(() {
        _completedAppIds = ids.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toSet();
        _completedExpanded = expanded;
      });
    }
  }

  Future<void> _saveCompletedApps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _completedAppsKey,
      _completedAppIds.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _toggleAppCompleted(int appId) async {
    setState(() {
      if (_completedAppIds.contains(appId)) {
        _completedAppIds.remove(appId);
      } else {
        _completedAppIds.add(appId);
        _postponedAppIds.remove(appId);
      }
    });
    await _saveCompletedApps();
    await _savePostponedApps();
  }

  Future<void> _loadPostponedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_postponedAppsKey) ?? [];
    final expanded = prefs.getBool(_postponedExpandedKey) ?? false;
    if (mounted) {
      setState(() {
        _postponedAppIds = ids.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toSet();
        _postponedExpanded = expanded;
      });
    }
  }

  Future<void> _savePostponedApps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _postponedAppsKey,
      _postponedAppIds.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _toggleAppPostponed(int appId) async {
    setState(() {
      if (_postponedAppIds.contains(appId)) {
        _postponedAppIds.remove(appId);
      } else {
        _postponedAppIds.add(appId);
        _completedAppIds.remove(appId);
      }
    });
    await _savePostponedApps();
    await _saveCompletedApps();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_appInForeground) return;
      if (context.read<AppState>().activeTabIndex != _myTabIndex) return;
      _refresh();
    });
  }

  Future<void> _refresh({bool force = false}) async {
    final state = context.read<AppState>();
    await state.loadApps(force: force);
    await _loadInstalledVersions();
    if (mounted) {
      final hasError = state.error != null;
      setState(() {
        _syncFailed = hasError;
        if (!hasError) _lastSyncedAt = DateTime.now();
      });
      if (force) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(hasError
              ? 'Force refresh failed: ${state.error}'
              : 'Refreshed from server'),
          backgroundColor:
              hasError ? AppColors.error : AppColors.success,
          duration: Duration(seconds: hasError ? 4 : 2),
          action: hasError
              ? SnackBarAction(
                  label: 'Retry',
                  onPressed: () => _refresh(force: true),
                )
              : null,
        ));
      }
    }
  }

  Future<void> _forceRefresh() async {
    HapticFeedback.mediumImpact();
    await _refresh(force: true);
  }

  Future<void> _scanProjects() async {
    HapticFeedback.lightImpact();
    try {
      final resp = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/apps/scan'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (resp.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: server returned ${resp.statusCode}'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      final data = jsonDecode(resp.body);
      final imported = data['imported'] ?? 0;
      final found = data['found'] ?? 0;
      final skipped = data['skipped'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanned $found folders: $imported imported, $skipped skipped'),
          backgroundColor: imported > 0 ? AppColors.success : AppColors.info,
        ),
      );
      if (imported > 0) await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showCreateAppSheet() =>
      CreateAppSheet.show(context, onCreated: _refresh);

  void _showBrainstormSheet() =>
      BrainstormSheet.show(context, onCreated: _refresh);

  Future<void> _loadInstalledVersions() async {
    final apps = context.read<AppState>().apps;
    final packageNames =
        apps.map((a) => a.packageName).where((p) => p.isNotEmpty).toList();
    if (packageNames.isEmpty) return;
    final versions =
        await InstalledAppsService.getInstalledVersions(packageNames);
    if (mounted) {
      setState(() => _installedVersions = versions);
    }
  }

  String _syncLabel() {
    if (_syncFailed) return 'Sync failed';
    if (_lastSyncedAt == null) return '';
    final diff = DateTime.now().difference(_lastSyncedAt!);
    if (diff.inSeconds < 10) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final syncText = _syncLabel();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard'),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _syncFailed ? Colors.red : (syncText.isNotEmpty ? AppColors.success : Colors.grey),
                  ),
                ),
                Text(
                  syncText.isNotEmpty ? 'Synced $syncText' : 'Connecting...',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.radar),
            tooltip: 'Scan for projects',
            onPressed: _scanProjects,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync),
            tooltip: 'Force refresh from server (clears local cache)',
            onPressed: _forceRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              HapticFeedback.lightImpact();
              _refresh();
            },
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedFab(
            heroTag: 'brainstorm',
            small: true,
            backgroundColor: Colors.amber.shade700,
            onPressed: _showBrainstormSheet,
            child: const Icon(Icons.lightbulb, size: 20),
          ),
          const SizedBox(height: 16),
          _AnimatedFab(
            heroTag: 'create',
            onPressed: _showCreateAppSheet,
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          if (state.loading && state.apps.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null && state.apps.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 64, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Cannot reach server',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      state.error!,
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final activeApps = state.apps
              .where((a) => !_completedAppIds.contains(a.id) && !_postponedAppIds.contains(a.id))
              .toList();
          final completedApps = state.apps
              .where((a) => _completedAppIds.contains(a.id))
              .toList();
          final postponedApps = state.apps
              .where((a) => _postponedAppIds.contains(a.id) && !_completedAppIds.contains(a.id))
              .toList();

          final showCreateEmpty = state.apps.isEmpty;
          final showAllCategorized = !showCreateEmpty && activeApps.isEmpty && (completedApps.isNotEmpty || postponedApps.isNotEmpty);

          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: _refresh,
            child: showCreateEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.rocket_launch, size: 64, color: Colors.grey.shade600),
                            const SizedBox(height: 16),
                            const Text(
                              'No apps yet',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create your first app to get started',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: () => _showCreateAppSheet(),
                              icon: const Icon(Icons.add),
                              label: const Text('Create App'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView(
                    // Extra bottom padding clears the stacked FABs
                    // (lightbulb + plus = ~56+16+56) plus a small
                    // breathing margin so the last app card never
                    // sits behind them.
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 160),
                    children: [
                      _TaskSummaryCard(apps: state.apps, totalBuilds: state.totalBuilds),
                      if (showAllCategorized)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.check_circle_outline, size: 48, color: Colors.grey.shade600),
                                const SizedBox(height: 12),
                                Text(
                                  'All apps are completed or postponed',
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Expand the folders below or create a new app',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ...activeApps.map((app) => _AppCard(
                        app: app,
                        taskStatus: app.taskStatus,
                        installedVersion: app.packageName.isNotEmpty
                            ? _installedVersions[app.packageName]
                            : null,
                        hasPackageName: app.packageName.isNotEmpty,
                        appStatus: _AppStatus.active,
                        onToggleCompleted: () => _toggleAppCompleted(app.id),
                        onTogglePostponed: () => _toggleAppPostponed(app.id),
                        onIconTap: () => context.read<AppState>().requestIssuesForApp(app.id),
                      )),
                      if (postponedApps.isNotEmpty)
                        Card(
                          margin: const EdgeInsets.only(top: 4, bottom: 10),
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            key: PageStorageKey('postponed_folder'),
                            initiallyExpanded: _postponedExpanded,
                            onExpansionChanged: (expanded) async {
                              setState(() => _postponedExpanded = expanded);
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool(_postponedExpandedKey, expanded);
                            },
                            leading: Icon(
                              _postponedExpanded ? Icons.folder_open : Icons.folder,
                              color: AppColors.warning,
                            ),
                            title: Text(
                              'Postponed (${postponedApps.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              'On hold',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                            children: postponedApps.map((app) => _AppCard(
                              app: app,
                              taskStatus: app.taskStatus,
                              installedVersion: app.packageName.isNotEmpty
                                  ? _installedVersions[app.packageName]
                                  : null,
                              hasPackageName: app.packageName.isNotEmpty,
                              appStatus: _AppStatus.postponed,
                              onToggleCompleted: () => _toggleAppCompleted(app.id),
                              onTogglePostponed: () => _toggleAppPostponed(app.id),
                              onIconTap: () => context.read<AppState>().requestIssuesForApp(app.id),
                            )).toList(),
                          ),
                        ),
                      if (completedApps.isNotEmpty)
                        Card(
                          margin: const EdgeInsets.only(top: 4, bottom: 10),
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            key: PageStorageKey('completed_folder'),
                            initiallyExpanded: _completedExpanded,
                            onExpansionChanged: (expanded) async {
                              setState(() => _completedExpanded = expanded);
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool(_completedExpandedKey, expanded);
                            },
                            leading: Icon(
                              _completedExpanded ? Icons.folder_open : Icons.folder,
                              color: AppColors.success,
                            ),
                            title: Text(
                              'Completed (${completedApps.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              'Maintenance only',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                            children: completedApps.map((app) => _AppCard(
                              app: app,
                              taskStatus: app.taskStatus,
                              installedVersion: app.packageName.isNotEmpty
                                  ? _installedVersions[app.packageName]
                                  : null,
                              hasPackageName: app.packageName.isNotEmpty,
                              appStatus: _AppStatus.completed,
                              onToggleCompleted: () => _toggleAppCompleted(app.id),
                              onTogglePostponed: () => _toggleAppPostponed(app.id),
                              onIconTap: () => context.read<AppState>().requestIssuesForApp(app.id),
                            )).toList(),
                          ),
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _AnimatedFab extends StatefulWidget {
  final VoidCallback onPressed;
  final String heroTag;
  final Widget child;
  final Color? backgroundColor;
  final bool small;

  const _AnimatedFab({
    required this.onPressed,
    required this.heroTag,
    required this.child,
    this.backgroundColor,
    this.small = false,
  });

  @override
  State<_AnimatedFab> createState() => _AnimatedFabState();
}

class _AnimatedFabState extends State<_AnimatedFab> {
  static const _pressDuration = Duration(milliseconds: 90);
  double _scale = 1.0;

  void _handlePress() {
    HapticFeedback.lightImpact();
    setState(() => _scale = 0.92);
    Future.delayed(_pressDuration, () {
      if (mounted) setState(() => _scale = 1.0);
    });
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final fab = widget.small
        ? FloatingActionButton.small(
            heroTag: widget.heroTag,
            backgroundColor: widget.backgroundColor,
            onPressed: _handlePress,
            child: widget.child,
          )
        : FloatingActionButton(
            heroTag: widget.heroTag,
            backgroundColor: widget.backgroundColor,
            onPressed: _handlePress,
            child: widget.child,
          );
    return AnimatedScale(
      scale: _scale,
      duration: _pressDuration,
      curve: Curves.easeOutBack,
      child: fab,
    );
  }
}

enum _AppStatus { active, completed, postponed }

class _AppCard extends StatelessWidget {
  final AppModel app;
  final Map<String, int> taskStatus;
  final String? installedVersion;
  final bool hasPackageName;
  final _AppStatus appStatus;
  final VoidCallback onToggleCompleted;
  final VoidCallback onTogglePostponed;
  final VoidCallback? onIconTap;

  const _AppCard({
    required this.app,
    required this.taskStatus,
    this.installedVersion,
    this.hasPackageName = false,
    required this.appStatus,
    required this.onToggleCompleted,
    required this.onTogglePostponed,
    this.onIconTap,
  });

  bool get isCompleted => appStatus == _AppStatus.completed;
  bool get isPostponed => appStatus == _AppStatus.postponed;

  @override
  Widget build(BuildContext context) {
    final pendingTasks = taskStatus['pending'] ?? 0;
    final inProgressTasks = taskStatus['in_progress'] ?? 0;
    final completedTasks = taskStatus['completed'] ?? 0;
    final unshipped = pendingTasks + inProgressTasks;
    final totalUnbuilt = pendingTasks + inProgressTasks + completedTasks;

    // Derive the display status: when a persisted state like building/
    // uploading/error is set on the server, surface that. Otherwise if the
    // app is sitting "idle" but a task is actually running, the card should
    // read 'working' so the user can see that something is happening right
    // now without waiting for app.status to flip.
    final serverStatus = app.status.toLowerCase();
    final displayStatus = (serverStatus == 'idle' && inProgressTasks > 0)
        ? 'working'
        : serverStatus;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  AppDetailScreen(appId: app.id),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                final offsetAnimation = Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                return SlideTransition(
                  position: offsetAnimation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              transitionDuration: const Duration(milliseconds: 300),
              reverseTransitionDuration: const Duration(milliseconds: 250),
            ),
          );
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          showModalBottomSheet(
            context: context,
            backgroundColor: AppColors.bgCard,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (appStatus != _AppStatus.active)
                    ListTile(
                      leading: const Icon(Icons.replay, color: AppColors.info),
                      title: const Text('Move back to Active'),
                      subtitle: const Text('Resume active development'),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (isCompleted) {
                          onToggleCompleted();
                        } else {
                          onTogglePostponed();
                        }
                      },
                    ),
                  if (!isCompleted)
                    ListTile(
                      leading: const Icon(Icons.check_circle_outline, color: AppColors.success),
                      title: const Text('Mark as Completed'),
                      subtitle: const Text('Move to completed folder'),
                      onTap: () {
                        Navigator.pop(ctx);
                        onToggleCompleted();
                      },
                    ),
                  if (!isPostponed)
                    ListTile(
                      leading: const Icon(Icons.pause_circle_outline, color: AppColors.warning),
                      title: const Text('Postpone'),
                      subtitle: const Text('Put on hold for later'),
                      onTap: () {
                        Navigator.pop(ctx);
                        onTogglePostponed();
                      },
                    ),
                ],
              ),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // App icon — tappable to navigate to issues
              GestureDetector(
                onTap: onIconTap != null
                    ? () {
                        HapticFeedback.lightImpact();
                        onIconTap!();
                      }
                    : null,
                child: Tooltip(
                  message: 'View issues',
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _AppIconWidget(
                        app: app,
                        dimmed: isCompleted || isPostponed,
                      ),
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.bgDark, width: 1),
                          ),
                          child: const Icon(
                            Icons.bug_report,
                            size: 12,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // App info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: (isCompleted || isPostponed) ? Colors.grey.shade400 : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'v${app.currentVersion}',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasPackageName) ...[
                          const SizedBox(width: 6),
                          _installedBadge(),
                        ],
                        const SizedBox(width: 6),
                        Text(
                          app.appType,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Status, issues, and tasks
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Status dot + label
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? AppColors.success
                              : isPostponed
                                  ? AppColors.warning
                                  : AppColors.statusColor(displayStatus),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isCompleted
                              ? 'completed'
                              : isPostponed
                                  ? 'postponed'
                                  : displayStatus,
                          style: TextStyle(
                            color: isCompleted
                                ? AppColors.success
                                : isPostponed
                                    ? AppColors.warning
                                    : AppColors.statusColor(displayStatus),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Task count badge
                  if (totalUnbuilt > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: unshipped > 0
                            ? AppColors.warning.withValues(alpha: 0.2)
                            : AppColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$completedTasks/$totalUnbuilt',
                        style: TextStyle(
                          color: unshipped > 0
                              ? AppColors.warning
                              : AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              ),
            ],
          ),
        ),
          if (serverStatus == 'building' || serverStatus == 'uploading' || displayStatus == 'working')
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.statusColor(displayStatus),
                backgroundColor: AppColors.bgDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _installedBadge() {
    if (installedVersion == null) {
      // Not installed on this device - yellow
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'not installed',
          style: TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w500),
        ),
      );
    }

    // Compare version without build number (e.g. "1.2.25+37" -> "1.2.25")
    final currentBase = app.currentVersion.split('+').first;
    final installedBase = (installedVersion ?? '').split('+').first;
    final isUpToDate = installedBase == currentBase;
    // Green if same version, red if older
    final color = isUpToDate ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUpToDate ? Icons.check_circle : Icons.update,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            isUpToDate ? 'installed' : 'v$installedVersion',
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _TaskSummaryCard extends StatelessWidget {
  final List<AppModel> apps;
  final int totalBuilds;

  const _TaskSummaryCard({required this.apps, required this.totalBuilds});

  @override
  Widget build(BuildContext context) {
    int total = 0, pending = 0, inProgress = 0, completed = 0, built = 0, failed = 0;
    for (final app in apps) {
      final counts = app.taskStatus;
      total += counts['total'] ?? 0;
      pending += counts['pending'] ?? 0;
      inProgress += counts['in_progress'] ?? 0;
      completed += counts['completed'] ?? 0;
      built += counts['built'] ?? 0;
      failed += counts['failed'] ?? 0;
    }

    if (total == 0) return const SizedBox.shrink();

    final done = completed + built;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                const Text('Task Overview',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                Text('$done / $total done',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: total > 0
                    ? Row(
                        children: [
                          if (built > 0)
                            Expanded(flex: built, child: Container(color: const Color(0xFF9B59B6))),
                          if (completed > 0)
                            Expanded(flex: completed, child: Container(color: AppColors.success)),
                          if (inProgress > 0)
                            Expanded(flex: inProgress, child: Container(color: AppColors.info)),
                          if (pending > 0)
                            Expanded(flex: pending, child: Container(color: AppColors.warning)),
                          if (failed > 0)
                            Expanded(flex: failed, child: Container(color: AppColors.error)),
                        ],
                      )
                    : Container(color: Colors.grey.shade800),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('Pending', pending, AppColors.warning),
                _stat('Active', inProgress, AppColors.info),
                _stat('Completed', completed, AppColors.success),
                _stat('Built', built, const Color(0xFF9B59B6)),
                if (failed > 0) _stat('Failed', failed, AppColors.error),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }
}

class _AppIconWidget extends StatelessWidget {
  final AppModel app;
  final bool dimmed;

  const _AppIconWidget({required this.app, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    // Always attempt the icon fetch when the user has the toggle on:
    // CachedAppIcon caches a "no icon" sentinel for 404s so it does not
    // refetch on every paint, and we still fall back to the type icon
    // for apps the server has no icon for. Gating on iconPath.isNotEmpty
    // would silently drop apps that the server *would* serve an icon for
    // but had not populated the icon_path field for yet.
    final showReal = AppConfig.showAppIcons;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: showReal
          ? Opacity(
              opacity: dimmed ? 0.5 : 1.0,
              child: CachedAppIcon(
                appId: app.id,
                iconPath: app.iconPath,
                size: 48,
                errorBuilder: (_) => AppLetterAvatar(name: app.name, size: 48),
              ),
            )
          : Icon(
              AppColors.appTypeIcon(app.appType),
              color: dimmed ? Colors.grey : AppColors.accent,
              size: 26,
            ),
    );
  }
}
