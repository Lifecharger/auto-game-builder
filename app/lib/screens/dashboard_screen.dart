import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_model.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../services/installed_apps_service.dart';
import '../theme.dart';
import 'app_detail_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  Map<int, Map<String, dynamic>> _taskCounts = {};
  Map<String, String?> _installedVersions = {};
  int _totalBuilds = 0;
  Timer? _pollTimer;
  Timer? _tickTimer;
  bool _appInForeground = true;
  static const _myTabIndex = 0;
  static const _completedAppsKey = 'completed_app_ids';
  static const _postponedAppsKey = 'postponed_app_ids';
  DateTime? _lastSyncedAt;

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
    Future.microtask(() {
      if (!mounted) return;
      context.read<AppState>().loadApps().then((_) {
        _loadTaskCounts();
        _loadInstalledVersions();
        _loadBuildCount();
        if (mounted && context.read<AppState>().error == null) {
          setState(() => _lastSyncedAt = DateTime.now());
        }
      });
    });
    _startPolling();
    // Tick every 15s to update the "Xm ago" label
    _tickTimer = Timer.periodic(const Duration(seconds: 15), (_) {
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
    if (mounted) {
      setState(() {
        _completedAppIds = ids.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toSet();
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
    if (mounted) {
      setState(() {
        _postponedAppIds = ids.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toSet();
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
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || !_appInForeground) return;
      if (context.read<AppState>().activeTabIndex != _myTabIndex) return;
      _refresh();
    });
  }

  Future<void> _refresh() async {
    await context.read<AppState>().loadApps();
    await _loadTaskCounts();
    await _loadInstalledVersions();
    await _loadBuildCount();
    if (mounted && context.read<AppState>().error == null) {
      setState(() => _lastSyncedAt = DateTime.now());
    }
  }

  Future<void> _scanProjects() async {
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

  static String _appTypeHint(String type) {
    switch (type) {
      case 'flutter': return 'Mobile/desktop app with Google Play deploy support';
      case 'godot': return 'Game project with export targets (Windows, Android, Web)';
      case 'python': return 'Python project with script runner and pip management';
      case 'web': return 'Web app with static hosting deploy support';
      case 'phaser': return 'Phaser 3 + TypeScript game, wrapped as Android AAB via Capacitor';
      default: return '';
    }
  }

  void _showCreateAppSheet() {
    final nameController = TextEditingController();
    String appType = 'flutter';
    String agent = 'claude';
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final mq = MediaQuery.of(ctx);
            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: mq.viewInsets.bottom + mq.padding.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('New App',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        hintText: 'App Name (e.g. My Game)',
                        prefixIcon: Icon(Icons.apps),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Type', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['flutter', 'godot', 'python', 'phaser'].map((t) {
                        return ChoiceChip(
                          label: Text(t[0].toUpperCase() + t.substring(1)),
                          selected: t == appType,
                          selectedColor: AppColors.accent,
                          avatar: Icon(AppColors.appTypeIcon(t), size: 18,
                            color: t == appType ? Colors.white : Colors.grey.shade400),
                          onSelected: (sel) {
                            if (sel) setSheetState(() => appType = t);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _appTypeHint(appType),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 12),
                    const Text('AI Agent', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['claude', 'gemini', 'codex', 'local'].map((a) {
                        return ChoiceChip(
                          label: Text(a[0].toUpperCase() + a.substring(1)),
                          selected: a == agent,
                          selectedColor: AppColors.info,
                          onSelected: (sel) {
                            if (sel) setSheetState(() => agent = a);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 48,
                      child: FilledButton.icon(
                        onPressed: submitting ? null : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Name is required'),
                                backgroundColor: AppColors.warning));
                            return;
                          }
                          setSheetState(() => submitting = true);
                          final result = await ApiService.createApp(
                            name: name, appType: appType, fixStrategy: agent);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(result.ok ? 'App created!' : result.error ?? 'Failed to create app'),
                              backgroundColor: result.ok ? AppColors.success : AppColors.error));
                            if (result.ok) _refresh();
                          }
                        },
                        icon: submitting
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add),
                        label: Text(submitting ? 'Creating...' : 'Create App'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showBrainstormSheet() {
    final conceptController = TextEditingController();
    final nameController = TextEditingController();
    String appType = 'godot';
    String genre = '';
    bool submitting = false;

    final genres = ['', 'Puzzle', 'Idle/Clicker', 'RPG', 'Action', 'Strategy', 'Simulation', 'Arcade', 'Card Game', 'Tower Defense'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final mq = MediaQuery.of(ctx);
            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: mq.viewInsets.bottom + mq.padding.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.amber.shade400, size: 24),
                        const SizedBox(width: 8),
                        const Text('Brainstorm New Game',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Creates a new project with a brainstorm task. When the task runs, AI generates a full GDD and initial tasks.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        hintText: 'Project name (optional — AI can suggest)',
                        prefixIcon: Icon(Icons.label),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: conceptController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Concept seed (e.g. "ant colony idle game", "puzzle with gravity")',
                        prefixIcon: Icon(Icons.auto_awesome),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Genre', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: genres.map((g) {
                        final label = g.isEmpty ? 'Any' : g;
                        return ChoiceChip(
                          label: Text(label, style: const TextStyle(fontSize: 12)),
                          selected: g == genre,
                          selectedColor: Colors.amber.withAlpha(180),
                          onSelected: (sel) {
                            if (sel) setSheetState(() => genre = g);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Text('Engine', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['godot', 'flutter', 'phaser'].map((t) {
                        return ChoiceChip(
                          label: Text(t[0].toUpperCase() + t.substring(1)),
                          selected: t == appType,
                          selectedColor: AppColors.accent,
                          avatar: Icon(AppColors.appTypeIcon(t), size: 18,
                            color: t == appType ? Colors.white : Colors.grey.shade400),
                          onSelected: (sel) {
                            if (sel) setSheetState(() => appType = t);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 48,
                      child: FilledButton.icon(
                        onPressed: submitting ? null : () async {
                          final concept = conceptController.text.trim();
                          final name = nameController.text.trim();
                          if (concept.isEmpty && name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter a concept or project name'),
                                backgroundColor: AppColors.warning));
                            return;
                          }
                          setSheetState(() => submitting = true);
                          final result = await ApiService.studioBrainstorm(
                            concept: concept,
                            genre: genre,
                            appType: appType,
                            name: name,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            if (result.ok) {
                              final msg = result.data?['message'] ?? 'Project created with brainstorm task!';
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(msg),
                                backgroundColor: AppColors.success));
                              _refresh();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(result.error ?? 'Failed to brainstorm'),
                                backgroundColor: AppColors.error));
                            }
                          }
                        },
                        icon: submitting
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.lightbulb),
                        label: Text(submitting ? 'Creating...' : 'Brainstorm & Create'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadTaskCounts() async {
    final apps = context.read<AppState>().apps;
    final Map<int, Map<String, dynamic>> counts = {};
    await Future.wait(apps.map((app) async {
      final result = await ApiService.getAppTasksStatus(app.id);
      if (result.ok) {
        counts[app.id] = result.data!;
      }
    }));
    if (mounted) {
      setState(() => _taskCounts = counts);
    }
  }

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

  Future<void> _loadBuildCount() async {
    final result = await ApiService.getBuilds();
    if (mounted && result.ok) {
      setState(() => _totalBuilds = result.data!.length);
    }
  }

  String _syncLabel() {
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
            if (syncText.isNotEmpty)
              Text(
                'Synced $syncText',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.normal),
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
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'brainstorm',
            onPressed: _showBrainstormSheet,
            backgroundColor: Colors.amber.shade700,
            child: const Icon(Icons.lightbulb, size: 20),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'create',
            onPressed: () => _showCreateAppSheet(),
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
                  Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade600),
                  const SizedBox(height: 16),
                  Text(
                    state.error!,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
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

          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: _refresh,
            child: state.apps.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 200),
                      Center(
                        child: Text(
                          'No apps found',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _TaskSummaryCard(taskCounts: _taskCounts, totalBuilds: _totalBuilds),
                      ...activeApps.map((app) => _AppCard(
                        app: app,
                        taskStatus: _taskCounts[app.id],
                        installedVersion: app.packageName.isNotEmpty
                            ? _installedVersions[app.packageName]
                            : null,
                        hasPackageName: app.packageName.isNotEmpty,
                        appStatus: _AppStatus.active,
                        onToggleCompleted: () => _toggleAppCompleted(app.id),
                        onTogglePostponed: () => _toggleAppPostponed(app.id),
                      )),
                      if (postponedApps.isNotEmpty)
                        Card(
                          margin: const EdgeInsets.only(top: 4, bottom: 10),
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            key: PageStorageKey('postponed_folder'),
                            initiallyExpanded: _postponedExpanded,
                            onExpansionChanged: (expanded) {
                              setState(() => _postponedExpanded = expanded);
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
                              taskStatus: _taskCounts[app.id],
                              installedVersion: app.packageName.isNotEmpty
                                  ? _installedVersions[app.packageName]
                                  : null,
                              hasPackageName: app.packageName.isNotEmpty,
                              appStatus: _AppStatus.postponed,
                              onToggleCompleted: () => _toggleAppCompleted(app.id),
                              onTogglePostponed: () => _toggleAppPostponed(app.id),
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
                            onExpansionChanged: (expanded) {
                              setState(() => _completedExpanded = expanded);
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
                              taskStatus: _taskCounts[app.id],
                              installedVersion: app.packageName.isNotEmpty
                                  ? _installedVersions[app.packageName]
                                  : null,
                              hasPackageName: app.packageName.isNotEmpty,
                              appStatus: _AppStatus.completed,
                              onToggleCompleted: () => _toggleAppCompleted(app.id),
                              onTogglePostponed: () => _toggleAppPostponed(app.id),
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

enum _AppStatus { active, completed, postponed }

class _AppCard extends StatelessWidget {
  final AppModel app;
  final Map<String, dynamic>? taskStatus;
  final String? installedVersion;
  final bool hasPackageName;
  final _AppStatus appStatus;
  final VoidCallback onToggleCompleted;
  final VoidCallback onTogglePostponed;

  const _AppCard({
    required this.app,
    this.taskStatus,
    this.installedVersion,
    this.hasPackageName = false,
    required this.appStatus,
    required this.onToggleCompleted,
    required this.onTogglePostponed,
  });

  bool get isCompleted => appStatus == _AppStatus.completed;
  bool get isPostponed => appStatus == _AppStatus.postponed;

  @override
  Widget build(BuildContext context) {
    final pendingTasks = taskStatus?['pending'] as int? ?? 0;
    final inProgressTasks = taskStatus?['in_progress'] as int? ?? 0;
    final completedTasks = taskStatus?['completed'] as int? ?? 0;
    final unshipped = pendingTasks + inProgressTasks;
    final totalUnbuilt = pendingTasks + inProgressTasks + completedTasks;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AppDetailScreen(appId: app.id),
            ),
          );
        },
        onLongPress: () {
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // App type icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.bgDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  AppColors.appTypeIcon(app.appType),
                  color: (isCompleted || isPostponed) ? Colors.grey : AppColors.accent,
                  size: 26,
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
                                  : AppColors.statusColor(app.status),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isCompleted
                              ? 'completed'
                              : isPostponed
                                  ? 'postponed'
                                  : app.status,
                          style: TextStyle(
                            color: isCompleted
                                ? AppColors.success
                                : isPostponed
                                    ? AppColors.warning
                                    : AppColors.statusColor(app.status),
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
    final installedBase = installedVersion!.split('+').first;
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
  final Map<int, Map<String, dynamic>> taskCounts;
  final int totalBuilds;

  const _TaskSummaryCard({required this.taskCounts, required this.totalBuilds});

  @override
  Widget build(BuildContext context) {
    int total = 0, pending = 0, inProgress = 0, completed = 0, built = 0, failed = 0;
    for (final counts in taskCounts.values) {
      total += (counts['total'] as int? ?? 0);
      pending += (counts['pending'] as int? ?? 0);
      inProgress += (counts['in_progress'] as int? ?? 0);
      completed += (counts['completed'] as int? ?? 0);
      built += (counts['built'] as int? ?? 0);
      failed += (counts['failed'] as int? ?? 0);
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
