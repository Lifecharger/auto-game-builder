import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_model.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/create_task_sheet.dart';
import '../widgets/issues/issue_task_card.dart';
import '../widgets/task_filters_widget.dart';

class IssuesScreen extends StatefulWidget {
  const IssuesScreen({super.key});

  @override
  State<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends State<IssuesScreen> with WidgetsBindingObserver {
  List<dynamic> _allItems = [];
  bool _loading = false;
  String? _loadError;
  int? _selectedAppId;
  int? _expandedIndex;
  Timer? _pollTimer;
  bool _appInForeground = true;
  static const _myTabIndex = 1;
  final _searchController = TextEditingController();
  AppState? _appStateRef;

  // Track when items entered in_progress (keyed by task id)
  final Map<dynamic, DateTime> _inProgressStartTimes = {};
  /// Max time a task can stay in_progress before auto-reset (30 min).
  static const _stuckThreshold = Duration(minutes: 30);

  String _statusFilter = 'all';
  String _typeFilter = 'all';
  String _searchQuery = '';

  // App category filter: "in_progress", "postponed", or "completed"
  String _appCategory = 'in_progress';
  Set<int> _completedAppIds = {};
  static const _completedAppsKey = 'completed_app_ids';
  Set<int> _postponedAppIds = {};
  static const _postponedAppsKey = 'postponed_app_ids';

  static const _statusOptions = ['all', 'in_progress', 'pending', 'failed', 'divided', 'completed', 'built'];
  static const _typeOptions = ['all', 'issue', 'bug', 'fix', 'feature', 'idea'];

  static const _promptHistoryKey = 'idea_prompt_history';

  /// Analyze existing tasks and GDD to generate context-aware prompt suggestions.
  Future<List<Map<String, String>>> _buildSmartSuggestions() async {
    final suggestions = <Map<String, String>>[];
    final items = _allItems;
    if (items.isEmpty && _selectedAppId == null) return suggestions;

    // Count tasks by type and status
    int uiBugs = 0, securityTasks = 0, perfTasks = 0, featureTasks = 0;
    int pendingCount = 0, failedCount = 0;
    int totalCompleted = 0;

    for (final item in items) {
      final type = (item['task_type'] ?? item['type'] ?? '').toString().toLowerCase();
      final status = (item['status'] ?? '').toString().toLowerCase();
      final title = (item['title'] ?? '').toString().toLowerCase();
      final desc = (item['description'] ?? '').toString().toLowerCase();
      final combined = '$title $desc';

      if (status == 'pending') pendingCount++;
      if (status == 'failed') failedCount++;
      if (status == 'completed') totalCompleted++;

      // Categorize by content
      if (combined.contains('ui') || combined.contains('layout') ||
          combined.contains('design') || combined.contains('screen') ||
          combined.contains('button') || combined.contains('navigation') ||
          combined.contains('theme') || combined.contains('color') ||
          type == 'bug' && (combined.contains('display') || combined.contains('visual'))) {
        uiBugs++;
      }
      if (combined.contains('secur') || combined.contains('auth') ||
          combined.contains('encrypt') || combined.contains('permission') ||
          combined.contains('token') || combined.contains('password')) {
        securityTasks++;
      }
      if (combined.contains('perform') || combined.contains('speed') ||
          combined.contains('cache') || combined.contains('memory') ||
          combined.contains('optim') || combined.contains('slow') ||
          combined.contains('loading')) {
        perfTasks++;
      }
      if (type == 'feature' || combined.contains('add') && combined.contains('feature') ||
          combined.contains('new feature') || combined.contains('functionality')) {
        featureTasks++;
      }
    }

    // Generate suggestions based on patterns
    if (uiBugs >= 3) {
      suggestions.add({
        'label': 'UX Polish',
        'prompt': 'Many UI-related tasks were worked on recently. Suggest ideas for further UX improvements, better user flows, and visual polish to build on those fixes.',
      });
    }

    if (securityTasks >= 2) {
      suggestions.add({
        'label': 'Security Hardening',
        'prompt': 'There are security-related tasks in this app. Suggest additional security improvements like input validation, secure storage, API hardening, and data protection.',
      });
    }

    if (perfTasks >= 2) {
      suggestions.add({
        'label': 'Performance Boost',
        'prompt': 'Performance-related work has been done on this app. Suggest further optimizations like lazy loading, caching strategies, reducing rebuilds, and memory efficiency.',
      });
    }

    if (failedCount >= 2) {
      suggestions.add({
        'label': 'Fix Failures',
        'prompt': 'Several tasks have failed status. Suggest ideas for improving reliability, adding error recovery, better error handling, and automated testing to prevent failures.',
      });
    }

    if (featureTasks >= 3) {
      suggestions.add({
        'label': 'Feature Integration',
        'prompt': 'Multiple features have been added. Suggest ideas for better integration between existing features, reducing complexity, and improving feature discoverability.',
      });
    }

    if (totalCompleted >= 10 && pendingCount == 0) {
      suggestions.add({
        'label': 'Next Milestone',
        'prompt': 'Many tasks are completed with nothing pending. Suggest ideas for the next development milestone, including new capabilities, polish, and user-requested features.',
      });
    }

    if (pendingCount >= 5) {
      suggestions.add({
        'label': 'Task Prioritization',
        'prompt': 'There are many pending tasks. Suggest ideas for which areas to focus on first, potential quick wins, and how to group related tasks for efficient execution.',
      });
    }

    // GDD-based suggestions
    if (_selectedAppId != null) {
      final gddResult = await ApiService.getGdd(_selectedAppId!);
      if (gddResult.ok && gddResult.data != null && gddResult.data!.isNotEmpty) {
        final gdd = gddResult.data!.toLowerCase();

        if (gdd.contains('monetiz') || gdd.contains('revenue') || gdd.contains('business model')) {
          suggestions.add({
            'label': 'Revenue Ideas',
            'prompt': 'Based on the app\'s design document mentioning monetization/revenue, suggest creative monetization strategies that align with the app\'s goals and user base.',
          });
        }

        if (gdd.contains('user') && (gdd.contains('engage') || gdd.contains('retention'))) {
          suggestions.add({
            'label': 'User Engagement',
            'prompt': 'The app\'s design document focuses on user engagement. Suggest ideas for notifications, gamification, onboarding improvements, and retention strategies.',
          });
        }

        if (gdd.contains('api') || gdd.contains('backend') || gdd.contains('server')) {
          suggestions.add({
            'label': 'API & Backend',
            'prompt': 'The app relies on API/backend services. Suggest ideas for offline support, better error recovery, API caching, and reducing network dependency.',
          });
        }

        if (gdd.contains('test') || gdd.contains('quality')) {
          suggestions.add({
            'label': 'Testing & QA',
            'prompt': 'Suggest ideas for improving test coverage, adding integration tests, automated UI testing, and quality assurance workflows.',
          });
        }

        // If GDD exists but no specific pattern matched, add a generic GDD-aware prompt
        if (suggestions.where((s) =>
            s['label'] == 'Revenue Ideas' || s['label'] == 'User Engagement' ||
            s['label'] == 'API & Backend' || s['label'] == 'Testing & QA').isEmpty) {
          suggestions.add({
            'label': 'GDD-Aligned',
            'prompt': 'Based on this app\'s design document and goals, suggest ideas that align with the product vision and fill gaps in the current implementation.',
          });
        }
      }
    }

    // If still empty, add at least one generic smart suggestion based on task count
    if (suggestions.isEmpty && items.isNotEmpty) {
      suggestions.add({
        'label': 'Improve Codebase',
        'prompt': 'Based on the app\'s current state and task history, suggest ideas for code quality improvements, refactoring opportunities, and developer experience enhancements.',
      });
    }

    return suggestions;
  }

  Future<List<Map<String, dynamic>>> _loadPromptHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_promptHistoryKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> _savePromptHistory(List<Map<String, dynamic>> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_promptHistoryKey, jsonEncode(history));
  }

  Future<void> _addPromptToHistory(String prompt, List<String> categories) async {
    final history = await _loadPromptHistory();
    history.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch,
      'prompt': prompt,
      'categories': categories,
      'favorite': false,
      'timestamp': DateTime.now().toIso8601String(),
    });
    // Keep max 50 entries
    if (history.length > 50) history.removeRange(50, history.length);
    await _savePromptHistory(history);
  }

  Future<void> _toggleFavorite(int id) async {
    final history = await _loadPromptHistory();
    final idx = history.indexWhere((e) => e['id'] == id);
    if (idx != -1) {
      history[idx]['favorite'] = !(history[idx]['favorite'] as bool);
      await _savePromptHistory(history);
    }
  }

  Future<void> _deletePromptFromHistory(int id) async {
    final history = await _loadPromptHistory();
    history.removeWhere((e) => e['id'] == id);
    await _savePromptHistory(history);
  }

  Future<void> _loadCompletedAppIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_completedAppsKey) ?? [];
    final postponedIds = prefs.getStringList(_postponedAppsKey) ?? [];
    if (mounted) {
      setState(() {
        _completedAppIds = ids.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toSet();
        _postponedAppIds = postponedIds.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toSet();
      });
    }
  }

  List<AppModel> _filteredApps(List<AppModel> apps) {
    if (_appCategory == 'completed') {
      return apps.where((a) => _completedAppIds.contains(a.id)).toList();
    }
    if (_appCategory == 'postponed') {
      return apps.where((a) => _postponedAppIds.contains(a.id) && !_completedAppIds.contains(a.id)).toList();
    }
    // in_progress: exclude both completed and postponed
    return apps.where((a) => !_completedAppIds.contains(a.id) && !_postponedAppIds.contains(a.id)).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      if (!mounted) return;
      await _loadCompletedAppIds();
      if (!mounted) return;
      final apps = context.read<AppState>().apps;
      final filtered = _filteredApps(apps);
      if (filtered.isNotEmpty) {
        setState(() => _selectedAppId = filtered.first.id);
        _loadItems();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _appStateRef = context.read<AppState>();
      _appStateRef!.addListener(_handleIssuesRequest);
    });
    _startPolling();
  }

  @override
  void dispose() {
    _appStateRef?.removeListener(_handleIssuesRequest);
    _pollTimer?.cancel();
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleIssuesRequest() {
    if (!mounted) return;
    final appState = _appStateRef;
    if (appState == null) return;
    final requestedId = appState.issuesRequestedAppId;
    if (requestedId == null) return;

    appState.clearIssuesRequest();

    // Determine which category this app belongs to
    String category;
    if (_completedAppIds.contains(requestedId)) {
      category = 'completed';
    } else if (_postponedAppIds.contains(requestedId)) {
      category = 'postponed';
    } else {
      category = 'in_progress';
    }

    setState(() {
      _appCategory = category;
      _selectedAppId = requestedId;
      _expandedIndex = null;
    });
    _loadItems();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
  }

  /// Poll every 5s (same cadence as dashboard since we only sync changes).
  void _startPolling() {
    _pollTimer?.cancel();
    const interval = Duration(seconds: 5);
    _pollTimer = Timer.periodic(interval, (_) {
      if (!mounted || !_appInForeground) return;
      if (context.read<AppState>().activeTabIndex != _myTabIndex) return;
      _loadItems(silent: true);
    });
  }

  Future<void> _loadItems({bool silent = false}) async {
    if (_selectedAppId == null) return;
    if (!silent) setState(() {
      _loading = true;
      _loadError = null;
    });

    // getAppTasks already returns all tasks including ideas - no need for separate getIdeas call
    final result = await ApiService.getAppTasks(_selectedAppId!);

    if (mounted) {
      setState(() {
        final items = <dynamic>[];
        if (result.ok) {
          _loadError = null;
          for (final t in result.data!) {
            final type = (t['task_type'] ?? t['type'] ?? 'issue').toString();
            t['_source'] = type == 'idea' ? 'idea' : 'task';
            items.add(t);
          }
        } else {
          _loadError = result.error ?? 'Failed to load tasks';
        }

        // Normalize "done" → "completed" (some agents use "done" instead)
        for (final item in items) {
          if ((item['status'] ?? '').toString().toLowerCase() == 'done') {
            item['status'] = 'completed';
          }
        }

        // Sort: status groups first, then by task ID (highest first) within each group
        int statusWeight(String s) {
          switch (s) {
            case 'in_progress': return 0;
            case 'pending': return 1;
            case 'failed': return 2;
            case 'divided': return 3;
            case 'completed': return 4;
            case 'built': return 5;
            default: return 1;
          }
        }
        items.sort((a, b) {
          final aStatus = (a['status'] ?? 'pending').toString();
          final bStatus = (b['status'] ?? 'pending').toString();
          final sw = statusWeight(aStatus).compareTo(statusWeight(bStatus));
          if (sw != 0) return sw;
          return (b['id'] as int? ?? 0).compareTo(a['id'] as int? ?? 0);
        });

        _allItems = items;
        _loading = false;
        if (!silent) _expandedIndex = null;

        // Sync in_progress start times
        final activeIds = <dynamic>{};
        for (final item in items) {
          final id = item['id'];
          final status = (item['status'] ?? '').toString();
          if (status == 'in_progress' && id != null) {
            activeIds.add(id);
            _inProgressStartTimes.putIfAbsent(id, () => DateTime.now());
          }
        }
        _inProgressStartTimes.removeWhere((id, _) => !activeIds.contains(id));
      });

      // Auto-reset stuck tasks (in_progress longer than threshold)
      _autoResetStuckTasks();

      // Update pending count in AppState for badge
      final pendingCount = _allItems.where((i) {
        final s = (i['status'] ?? 'pending').toString().toLowerCase();
        return s == 'pending' || s == 'in_progress';
      }).length;
      context.read<AppState>().updatePendingCount(pendingCount);
    }
  }

  /// Auto-reset tasks stuck in_progress beyond [_stuckThreshold].
  void _autoResetStuckTasks() {
    final now = DateTime.now();
    final stuckIds = <dynamic>[];
    _inProgressStartTimes.forEach((id, startTime) {
      if (now.difference(startTime) > _stuckThreshold) {
        stuckIds.add(id);
      }
    });
    if (stuckIds.isEmpty) return;

    for (final id in stuckIds) {
      final item = _allItems.where((i) => i['id'] == id).firstOrNull;
      if (item == null) continue;
      final appId = item['app_id'] as int? ?? _selectedAppId;
      if (appId == null) continue;
      // Fire-and-forget reset on server
      ApiService.updateAppTask(appId, id as int, {'status': 'failed', 'response': 'Auto-failed: task stuck for over 30 minutes'});
      // Update locally immediately
      item['status'] = 'failed';
      _inProgressStartTimes.remove(id);
    }
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${stuckIds.length} stuck task(s) auto-failed after 30min timeout'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  List<dynamic> get _filteredItems {
    return _allItems.where((item) {
      final status = (item['status'] ?? 'pending').toString().toLowerCase();
      final type = (item['task_type'] ?? item['type'] ?? 'issue').toString().toLowerCase();
      if (_statusFilter != 'all' && status != _statusFilter) return false;
      if (_typeFilter != 'all' && type != _typeFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final title = (item['title'] ?? '').toString().toLowerCase();
        final desc = (item['description'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        if (!title.contains(query) && !desc.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  void _showCreateSheet() {
    CreateTaskSheet.show(
      context: context,
      appId: _selectedAppId!,
      onCreated: _loadItems,
    );
  }

  /// Get the AI agent (fix_strategy) for an app from AppState.
  String _getAppAgent(int appId) {
    final apps = context.read<AppState>().apps;
    final app = apps.where((a) => a.id == appId).firstOrNull;
    return app?.fixStrategy ?? '';
  }

  Future<void> _fixNow(Map<String, dynamic> item) async {
    HapticFeedback.lightImpact();
    final appId = item['app_id'] as int? ?? _selectedAppId;
    if (appId == null) return;
    final taskId = item['id'] as int?;
    if (taskId == null) return;
    final title = item['title'] ?? '';
    final aiAgent = _getAppAgent(appId);
    final agentLabel = aiAgent.isNotEmpty ? aiAgent : 'default';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Work on This'),
        content: Text('Run $agentLabel AI on:\n"$title"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Do It'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    // Immediately show in_progress in UI
    setState(() {
      item['status'] = 'in_progress';
      _inProgressStartTimes[taskId] = DateTime.now();
    });
    try {
      await ApiService.updateAppTask(appId, taskId, {'status': 'in_progress'});
      final result = await ApiService.runTask(appId, taskId, aiAgent: aiAgent);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.ok
                ? '$agentLabel AI triggered for "$title"'
                : result.error ?? 'Failed to run task'),
            backgroundColor: result.ok ? AppColors.success : AppColors.error,
          ),
        );
        // If run failed, revert task status so it doesn't stay stuck in_progress
        if (!result.ok) {
          await ApiService.updateAppTask(appId, taskId, {'status': 'pending'});
          if (mounted) setState(() => item['status'] = 'pending');
        }
        await _loadItems(silent: true);
        // Re-apply in_progress only if run succeeded and server hasn't updated yet
        if (mounted && result.ok) {
          final match = _allItems.where((i) => i['id'] == taskId).firstOrNull;
          if (match != null && match['status'] == 'pending') {
            setState(() => match['status'] = 'in_progress');
          }
        }
      }
    } catch (e) {
      try {
        await ApiService.updateAppTask(appId, taskId, {'status': 'pending'});
      } catch (revertError) {
        debugPrint('Failed to revert task $taskId: $revertError');
      }
      if (mounted) {
        setState(() {
          item['status'] = 'pending';
          _inProgressStartTimes.remove(taskId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _resetItem(Map<String, dynamic> item) async {
    final appId = item['app_id'] as int? ?? _selectedAppId;
    final taskId = item['id'] as int?;
    if (appId == null || taskId == null) return;
    final result = await ApiService.updateAppTask(appId, taskId, {'status': 'pending'});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.ok ? 'Task reset to pending' : result.error ?? 'Failed to reset'),
          backgroundColor: result.ok ? AppColors.success : AppColors.error,
        ),
      );
      if (result.ok) {
        setState(() {
          item['status'] = 'pending';
          _inProgressStartTimes.remove(taskId);
        });
      }
    }
  }

  Future<void> _completeItem(Map<String, dynamic> item) async {
    HapticFeedback.lightImpact();
    final source = item['_source'];
    if (source == 'idea') return; // ideas can't be "completed" via this
    final appId = item['app_id'] as int? ?? _selectedAppId;
    final taskId = item['id'] as int?;
    if (appId == null || taskId == null) return;
    final result = await ApiService.updateAppTask(appId, taskId, {'status': 'completed'});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.ok ? 'Marked as completed' : result.error ?? 'Failed to update'),
          backgroundColor: result.ok ? AppColors.success : AppColors.error,
        ),
      );
      if (result.ok) _loadItems();
    }
  }

  Future<void> _deleteItemDirect(Map<String, dynamic> item) async {
    final source = item['_source'];
    if (source == 'idea') {
      final ideaId = item['id'] as int?;
      if (ideaId == null) return;
      final result = await ApiService.deleteIdea(ideaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.ok ? 'Deleted' : result.error ?? 'Failed to delete'),
            backgroundColor: result.ok ? AppColors.success : AppColors.error,
          ),
        );
        if (result.ok) _loadItems();
      }
    } else {
      final appId = item['app_id'] as int? ?? _selectedAppId;
      final taskId = item['id'] as int?;
      if (appId == null || taskId == null) return;
      final result = await ApiService.deleteAppTask(appId, taskId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.ok ? 'Deleted' : result.error ?? 'Failed to delete'),
            backgroundColor: result.ok ? AppColors.success : AppColors.error,
          ),
        );
        if (result.ok) _loadItems();
      }
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    HapticFeedback.mediumImpact();
    final title = item['title'] ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Delete'),
        content: Text('Delete "$title"?\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    _deleteItemDirect(item);
  }

  Future<void> _workOnAll() async {
    if (_selectedAppId == null) return;
    final pendingItems = _allItems.where((item) {
      final status = (item['status'] ?? 'pending').toString().toLowerCase();
      return status == 'pending';
    }).toList();

    if (pendingItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pending items to work on'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Work on All Pending'),
        content: Text('Run AI on all ${pendingItems.length} pending item(s)?\nThey will be processed sequentially.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Work on All'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    int triggered = 0;
    int processed = 0;
    final total = pendingItems.length;
    final setInProgress = <int>[]; // track which tasks we set to in_progress
    final aiAgent = _selectedAppId != null ? _getAppAgent(_selectedAppId!) : '';
    try {
      for (final item in pendingItems) {
        if (!mounted) break;
        processed++;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Processing $processed of $total tasks...'),
              duration: const Duration(seconds: 30),
              backgroundColor: AppColors.info,
            ),
          );
        }
        final appId = item['app_id'] as int? ?? _selectedAppId!;
        final taskId = item['id'] as int?;
        if (taskId != null) {
          await ApiService.updateAppTask(appId, taskId, {'status': 'in_progress'});
          setInProgress.add(taskId);
          setState(() {
            item['status'] = 'in_progress';
            _inProgressStartTimes[taskId] = DateTime.now();
          });
          final result = await ApiService.runTask(appId, taskId, aiAgent: aiAgent);
          if (result.ok) {
            triggered++;
          } else {
            // Revert to pending if run failed so task doesn't get stuck
            await ApiService.updateAppTask(appId, taskId, {'status': 'pending'});
            setInProgress.remove(taskId);
            if (mounted) {
              setState(() {
                item['status'] = 'pending';
                _inProgressStartTimes.remove(taskId);
              });
            }
          }
        }
      }
    } catch (e) {
      for (final taskId in setInProgress) {
        final appId = pendingItems
            .where((i) => i['id'] == taskId)
            .firstOrNull?['app_id'] as int? ?? _selectedAppId;
        if (appId != null) {
          try {
            await ApiService.updateAppTask(appId, taskId, {'status': 'pending'});
          } catch (revertError) {
            debugPrint('Failed to revert task $taskId: $revertError');
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during batch run: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Triggered $triggered of ${pendingItems.length} items'),
          backgroundColor: triggered > 0 ? AppColors.success : AppColors.error,
        ),
      );
      _loadItems();
    }
  }

  Future<void> _createTestTask() async {
    if (_selectedAppId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an app first'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final result = await ApiService.createAppTask(
      appId: _selectedAppId!,
      title: 'Emulator Test Run',
      description:
          "Build debug APK, install on emulator via mobile MCP, test all screens and core gameplay. "
          "For each problem found (crash, layout issue, missing element, broken navigation, off-screen content), "
          "create a separate new task with clear description. If everything works, report 'All tests passed'. "
          "IGNORE: dynamic prices, Google Billing, sign-in, cloud save, IAP.",
      taskType: 'issue',
      priority: 'high',
    );

    if (!mounted) return;

    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test task created'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadItems();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to create test task'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _generateIdeas() async {
    if (_selectedAppId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an app first'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    const categoryChips = <String, String>{
      'UI/UX': 'Ideas for improving the user interface and user experience, such as better layouts, navigation, animations, and visual design',
      'Performance': 'Ideas for improving app performance, such as faster loading, reduced memory usage, caching, and optimization',
      'Features': 'Ideas for new features and functionality that would add value to the app',
      'Security': 'Ideas for improving app security, such as authentication, data protection, input validation, and encryption',
      'Monetization': 'Ideas for monetization strategies, such as in-app purchases, subscriptions, ads, and premium features',
      'Accessibility': 'Ideas for improving accessibility, such as screen reader support, color contrast, font scaling, and keyboard navigation',
    };

    // Load smart suggestions before showing dialog
    final smartSuggestions = await _buildSmartSuggestions();

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        final selectedCategories = <String>{};
        String? selectedSmartPrompt;
        var showHistory = false;
        var historyItems = <Map<String, dynamic>>[];
        var historyLoaded = false;
        var showFavoritesOnly = false;

        Future<void> loadHistory(StateSetter setDialogState) async {
          historyItems = await _loadPromptHistory();
          historyLoaded = true;
          setDialogState(() {});
        }

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            void updatePromptFromChips() {
              if (selectedCategories.isEmpty && selectedSmartPrompt == null) {
                controller.clear();
              } else if (selectedSmartPrompt != null) {
                controller.text = selectedSmartPrompt!;
                controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: controller.text.length),
                );
              } else {
                final combined = selectedCategories
                    .map((k) => categoryChips[k]!)
                    .join('. Also: ');
                controller.text = combined;
                controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: controller.text.length),
                );
              }
            }

            final filteredHistory = showFavoritesOnly
                ? historyItems.where((e) => e['favorite'] == true).toList()
                : historyItems;

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with history toggle
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              showHistory ? 'Prompt History' : 'Generate Ideas',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (showHistory)
                            IconButton(
                              icon: Icon(
                                showFavoritesOnly ? Icons.star : Icons.star_border,
                                color: showFavoritesOnly ? Colors.amber : Colors.grey,
                                size: 22,
                              ),
                              tooltip: showFavoritesOnly ? 'Show all' : 'Favorites only',
                              onPressed: () => setDialogState(
                                () => showFavoritesOnly = !showFavoritesOnly,
                              ),
                            ),
                          IconButton(
                            icon: Icon(
                              showHistory ? Icons.edit : Icons.history,
                              size: 22,
                            ),
                            tooltip: showHistory ? 'New prompt' : 'Prompt history',
                            onPressed: () {
                              setDialogState(() => showHistory = !showHistory);
                              if (showHistory && !historyLoaded) {
                                loadHistory(setDialogState);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Compose view
                      if (!showHistory) ...[
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Smart suggestions section
                                if (smartSuggestions.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.auto_awesome, size: 14, color: Colors.amber.shade400),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Suggested for you',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.amber.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: smartSuggestions.map((s) {
                                      final isSelected = selectedSmartPrompt == s['prompt'];
                                      return FilterChip(
                                        label: Text(s['label']!, style: const TextStyle(fontSize: 12)),
                                        selected: isSelected,
                                        selectedColor: Colors.amber.withAlpha(140),
                                        backgroundColor: AppColors.bgCard,
                                        checkmarkColor: Colors.white,
                                        avatar: isSelected ? null : Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber.shade300),
                                        onSelected: (selected) {
                                          setDialogState(() {
                                            if (selected) {
                                              selectedSmartPrompt = s['prompt'];
                                              selectedCategories.clear();
                                            } else {
                                              selectedSmartPrompt = null;
                                            }
                                            updatePromptFromChips();
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),
                                ],
                                const Text(
                                  'Select categories or type your own prompt.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: categoryChips.entries.map((e) {
                                    final isSelected = selectedCategories.contains(e.key);
                                    return FilterChip(
                                      label: Text(e.key, style: const TextStyle(fontSize: 12)),
                                      selected: isSelected,
                                      selectedColor: AppColors.accent.withAlpha(180),
                                      backgroundColor: AppColors.bgCard,
                                      checkmarkColor: Colors.white,
                                      onSelected: (selected) {
                                        setDialogState(() {
                                          selectedSmartPrompt = null;
                                          if (selected) {
                                            selectedCategories.add(e.key);
                                          } else {
                                            selectedCategories.remove(e.key);
                                          }
                                          updatePromptFromChips();
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: controller,
                                  autofocus: true,
                                  maxLines: 2,
                                  onChanged: (_) {
                                    if (selectedCategories.isNotEmpty || selectedSmartPrompt != null) {
                                      setDialogState(() {
                                        selectedCategories.clear();
                                        selectedSmartPrompt = null;
                                      });
                                    }
                                  },
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. "Ideas for improving the UI"',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, {
                                'prompt': controller.text,
                                'categories': selectedCategories.toList(),
                              }),
                              child: const Text('Generate', style: TextStyle(fontSize: 13)),
                            ),
                          ],
                        ),
                      ] else ...[
                        // History view
                        if (!historyLoaded)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (filteredHistory.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                showFavoritesOnly
                                    ? 'No favorite prompts yet'
                                    : 'No prompt history yet.\nGenerate ideas to build history.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ),
                          )
                        else
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredHistory.length,
                              itemBuilder: (_, i) {
                                final entry = filteredHistory[i];
                                final prompt = entry['prompt'] as String? ?? '';
                                final cats = (entry['categories'] as List?)
                                    ?.cast<String>() ?? [];
                                final isFav = entry['favorite'] as bool? ?? false;
                                final ts = entry['timestamp'] as String? ?? '';
                                final date = ts.isNotEmpty
                                    ? DateTime.tryParse(ts)
                                    : null;
                                final dateStr = date != null
                                    ? '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                                    : '';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      // Fill prompt and switch to compose view
                                      controller.text = prompt;
                                      selectedCategories.clear();
                                      selectedCategories.addAll(cats);
                                      setDialogState(() => showHistory = false);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  prompt,
                                                  style: const TextStyle(fontSize: 13),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    if (cats.isNotEmpty) ...[
                                                      Icon(Icons.category,
                                                          size: 12,
                                                          color: Colors.grey.shade500),
                                                      const SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          cats.join(', '),
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.grey.shade500),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                    ],
                                                    Text(
                                                      dateStr,
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.grey.shade600),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              isFav ? Icons.star : Icons.star_border,
                                              color: isFav ? Colors.amber : Colors.grey,
                                              size: 20,
                                            ),
                                            constraints: const BoxConstraints(
                                                minWidth: 48, minHeight: 48),
                                            padding: EdgeInsets.zero,
                                            onPressed: () async {
                                              await _toggleFavorite(entry['id'] as int);
                                              await loadHistory(setDialogState);
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline,
                                                size: 18,
                                                color: Colors.grey.shade500),
                                            constraints: const BoxConstraints(
                                                minWidth: 48, minHeight: 48),
                                            padding: EdgeInsets.zero,
                                            onPressed: () async {
                                              await _deletePromptFromHistory(
                                                  entry['id'] as int);
                                              await loadHistory(setDialogState);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close', style: TextStyle(fontSize: 13)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
            );
          },
        );
      },
    );

    if (result == null) return; // cancelled

    final userPrompt = (result['prompt'] as String? ?? '').trim();
    final categories = (result['categories'] as List?)?.cast<String>() ?? [];
    final title = userPrompt.isEmpty
        ? 'Generate improvement ideas for this app'
        : 'Generate ideas: $userPrompt';

    final apiResult = await ApiService.createAppTask(
      appId: _selectedAppId!,
      title: title,
      description: userPrompt.isEmpty ? null : userPrompt,
      taskType: 'idea',
    );
    if (apiResult.ok) {
      await _addPromptToHistory(
        userPrompt.isEmpty ? 'Generate improvement ideas for this app' : userPrompt,
        categories,
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiResult.ok ? 'Idea generation requested' : apiResult.error ?? 'Failed to request ideas'),
          backgroundColor: apiResult.ok ? AppColors.success : AppColors.error,
        ),
      );
      if (apiResult.ok) _loadItems();
    }
  }

  Future<void> _codeCheck() async {
    if (_selectedAppId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an app first'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final checks = <String, bool>{
      'Bugs & crashes': true,
      'Security vulnerabilities': true,
      'Performance issues': true,
      'Code style': true,
      'Dead code': true,
      'Error handling': true,
      'Memory leaks': true,
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Code Check'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will create a task for the AI agent to review your code and report findings as issues.',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  const Text('Checks to run:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...checks.entries.map((e) => CheckboxListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.key, style: const TextStyle(fontSize: 14)),
                    value: e.value,
                    onChanged: (v) => setDialogState(() => checks[e.key] = v ?? false),
                  )),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: checks.values.any((v) => v)
                      ? () => Navigator.pop(ctx, true)
                      : null,
                  child: const Text('Run Check'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final selected = checks.entries.where((e) => e.value).map((e) => e.key).toList();
    final description = 'Perform a code review focusing on: ${selected.join(', ')}. '
        'For EACH issue found, create a separate NEW task in tasklist.json with type "bug" for crash risks or "fix" for quality issues. '
        'Include specific file paths and line numbers. Check: null/validity guards after await, signal cleanup in _exit_tree, '
        'memory leaks, typed variables, single responsibility (no scripts >500 lines), data-driven economy values (not hardcoded), '
        'no magic numbers or string-typing. Write overall Health Score X/10 in this task\'s response.';

    final result = await ApiService.createAppTask(
      appId: _selectedAppId!,
      title: 'Code Review: ${selected.join(', ')}',
      description: description,
      taskType: 'issue',
      priority: 'high',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.ok ? 'Code check requested' : result.error ?? 'Failed to request code check'),
          backgroundColor: result.ok ? AppColors.success : AppColors.error,
        ),
      );
      if (result.ok) _loadItems();
    }
  }

  Future<void> _designReview() async {
    if (_selectedAppId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an app first'), backgroundColor: AppColors.warning),
      );
      return;
    }
    final result = await ApiService.studioAction(_selectedAppId!, 'design-review');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok ? 'Design review task created' : result.error ?? 'Failed'),
        backgroundColor: result.ok ? AppColors.success : AppColors.error,
      ),
    );
    if (result.ok) _loadItems();
  }

  Future<void> _balanceCheck() async {
    await _runStudioAction('balance-check', 'Balance check task created');
  }

  /// Generic handler for any /api/apps/{id}/studio/{action} call.
  /// Shows a warning if no app is selected, otherwise posts the action
  /// and refreshes the task list on success.
  Future<void> _runStudioAction(String action, String successMessage) async {
    if (_selectedAppId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an app first'), backgroundColor: AppColors.warning),
      );
      return;
    }
    final result = await ApiService.studioAction(_selectedAppId!, action);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok ? successMessage : result.error ?? 'Failed'),
        backgroundColor: result.ok ? AppColors.success : AppColors.error,
      ),
    );
    if (result.ok) _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final allApps = context.watch<AppState>().apps;
    final categoryApps = _filteredApps(allApps);
    final filtered = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Issues'),
        actions: [
          IconButton(
            onPressed: _createTestTask,
            icon: const Icon(Icons.phone_android),
            tooltip: 'Test',
          ),
          IconButton(
            onPressed: _generateIdeas,
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Generate Ideas',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.science),
            tooltip: 'Studio Reviews',
            onSelected: (value) {
              switch (value) {
                case 'code-review':
                  _codeCheck();
                  break;
                case 'design-review':
                  _designReview();
                  break;
                case 'balance-check':
                  _balanceCheck();
                  break;
                case 'consistency-check':
                  _runStudioAction('consistency-check', 'Consistency check task created');
                  break;
                case 'tech-debt':
                  _runStudioAction('tech-debt', 'Tech debt scan task created');
                  break;
                case 'asset-audit':
                  _runStudioAction('asset-audit', 'Asset audit task created');
                  break;
                case 'content-audit':
                  _runStudioAction('content-audit', 'Content audit task created');
                  break;
                case 'scope-check':
                  _runStudioAction('scope-check', 'Scope check task created');
                  break;
                case 'perf-profile':
                  _runStudioAction('perf-profile', 'Performance profile task created');
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'code-review',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.bug_report, size: 20),
                  title: Text('Code Review', style: TextStyle(fontSize: 14)),
                  subtitle: Text('Bugs, crashes, code quality', style: TextStyle(fontSize: 11)),
                ),
              ),
              const PopupMenuItem(
                value: 'design-review',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.design_services, size: 20),
                  title: Text('Design Review', style: TextStyle(fontSize: 14)),
                  subtitle: Text('GDD, mechanics, UX audit', style: TextStyle(fontSize: 11)),
                ),
              ),
              const PopupMenuItem(
                value: 'balance-check',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.balance, size: 20),
                  title: Text('Balance Check', style: TextStyle(fontSize: 14)),
                  subtitle: Text('Economy, progression, rewards', style: TextStyle(fontSize: 11)),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'consistency-check',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.rule, size: 20),
                  title: Text('Consistency Check', style: TextStyle(fontSize: 14)),
                  subtitle: Text('GDD ↔ code ↔ data drift', style: TextStyle(fontSize: 11)),
                ),
              ),
              const PopupMenuItem(
                value: 'tech-debt',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.cleaning_services, size: 20),
                  title: Text('Tech Debt Scan', style: TextStyle(fontSize: 14)),
                  subtitle: Text('God scripts, duplicates, TODOs', style: TextStyle(fontSize: 11)),
                ),
              ),
              const PopupMenuItem(
                value: 'asset-audit',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.fact_check, size: 20),
                  title: Text('Asset Audit', style: TextStyle(fontSize: 14)),
                  subtitle: Text('Broken refs, orphans, placeholders', style: TextStyle(fontSize: 11)),
                ),
              ),
              const PopupMenuItem(
                value: 'content-audit',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.playlist_add_check, size: 20),
                  title: Text('Content Audit', style: TextStyle(fontSize: 14)),
                  subtitle: Text('Levels, characters, items, text', style: TextStyle(fontSize: 11)),
                ),
              ),
              const PopupMenuItem(
                value: 'scope-check',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.filter_list, size: 20),
                  title: Text('Scope Check', style: TextStyle(fontSize: 14)),
                  subtitle: Text('Cut list + realism pass', style: TextStyle(fontSize: 11)),
                ),
              ),
              const PopupMenuItem(
                value: 'perf-profile',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.speed, size: 20),
                  title: Text('Performance Profile', style: TextStyle(fontSize: 14)),
                  subtitle: Text('Frame drops, memory, load time', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.palette),
            tooltip: 'Art & Assets',
            onSelected: (value) {
              switch (value) {
                case 'art-bible':
                  _runStudioAction('art-bible', 'Art bible task created');
                  break;
                case 'asset-spec':
                  _runStudioAction('asset-spec', 'Asset spec task created');
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'art-bible',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.auto_stories, size: 20),
                  title: Text('Art Bible', style: TextStyle(fontSize: 14)),
                  subtitle: Text('Visual identity anchor doc', style: TextStyle(fontSize: 11)),
                ),
              ),
              const PopupMenuItem(
                value: 'asset-spec',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.inventory_2, size: 20),
                  title: Text('Asset Specs', style: TextStyle(fontSize: 14)),
                  subtitle: Text('Per-asset prompts from bible', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: _workOnAll,
            icon: const Icon(Icons.play_circle_outline),
            tooltip: 'Work on All Pending',
          ),
        ],
      ),
      floatingActionButton: _selectedAppId != null
          ? FloatingActionButton(
              onPressed: _showCreateSheet,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          // App category toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'in_progress',
                  label: const Text('In Progress'),
                  icon: const Icon(Icons.code, size: 18),
                ),
                ButtonSegment(
                  value: 'postponed',
                  label: const Text('Postponed'),
                  icon: const Icon(Icons.pause_circle_outline, size: 18),
                ),
                ButtonSegment(
                  value: 'completed',
                  label: const Text('Completed'),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                ),
              ],
              selected: {_appCategory},
              onSelectionChanged: (selection) {
                setState(() {
                  _appCategory = selection.first;
                  final apps = _filteredApps(allApps);
                  if (apps.isNotEmpty) {
                    _selectedAppId = apps.first.id;
                  } else {
                    _selectedAppId = null;
                    _allItems = [];
                  }
                  _expandedIndex = null;
                });
                if (_selectedAppId != null) _loadItems();
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    if (_appCategory == 'completed') {
                      return AppColors.success.withValues(alpha: 0.2);
                    } else if (_appCategory == 'postponed') {
                      return AppColors.warning.withValues(alpha: 0.2);
                    }
                    return AppColors.info.withValues(alpha: 0.2);
                  }
                  return null;
                }),
              ),
            ),
          ),
          // App dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonFormField<int>(
              key: ValueKey('app_dropdown_$_appCategory'),
              value: _selectedAppId,
              decoration: const InputDecoration(
                hintText: 'Select app',
                prefixIcon: Icon(Icons.apps),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              dropdownColor: AppColors.bgCard,
              items: categoryApps
                  .map<DropdownMenuItem<int>>((app) => DropdownMenuItem<int>(
                        value: app.id,
                        child: Text(app.name),
                      ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedAppId = val;
                  _expandedIndex = null;
                });
                _loadItems();
              },
            ),
          ),
          TaskFiltersWidget(
            searchController: _searchController,
            searchQuery: _searchQuery,
            onSearchChanged: (val) => setState(() => _searchQuery = val),
            onSearchClear: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            statusFilter: _statusFilter,
            statusOptions: _statusOptions,
            onStatusChanged: (s) {
              setState(() {
                _statusFilter = s;
                _expandedIndex = null;
              });
            },
            typeFilter: _typeFilter,
            typeOptions: _typeOptions,
            onTypeChanged: (t) {
              setState(() {
                _typeFilter = t;
                _expandedIndex = null;
              });
            },
          ),
          // Item list
          Expanded(
            child: _selectedAppId == null
                ? const Center(
                    child: Text(
                      'Select an app to view items',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        color: AppColors.accent,
                        onRefresh: _loadItems,
                        child: _loadError != null
                            ? ListView(
                                children: [
                                  const SizedBox(height: 160),
                                  Center(
                                    child: Text(
                                      _loadError!,
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 16),
                                    ),
                                  ),
                                ],
                              )
                            : filtered.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 160),
                                  const Center(
                                    child: Text(
                                      'No items found',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 16),
                                    ),
                                  ),
                                  if (_statusFilter != 'all' || _typeFilter != 'all' || _searchQuery.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Center(
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        alignment: WrapAlignment.center,
                                        children: [
                                          if (_statusFilter != 'all')
                                            Chip(
                                              label: Text('Status: ${TaskFiltersWidget.chipLabel(_statusFilter)}', style: const TextStyle(fontSize: 11)),
                                              visualDensity: VisualDensity.compact,
                                              side: BorderSide(color: AppColors.taskStatusColor(_statusFilter)),
                                            ),
                                          if (_typeFilter != 'all')
                                            Chip(
                                              label: Text('Type: ${TaskFiltersWidget.chipLabel(_typeFilter)}', style: const TextStyle(fontSize: 11)),
                                              visualDensity: VisualDensity.compact,
                                              side: BorderSide(color: AppColors.taskTypeColor(_typeFilter)),
                                            ),
                                          if (_searchQuery.isNotEmpty)
                                            Chip(
                                              label: Text('Search: "$_searchQuery"', style: const TextStyle(fontSize: 11)),
                                              visualDensity: VisualDensity.compact,
                                              side: BorderSide(color: Colors.grey.shade600),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Center(
                                      child: TextButton.icon(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _statusFilter = 'all';
                                            _typeFilter = 'all';
                                            _searchQuery = '';
                                            _expandedIndex = null;
                                          });
                                        },
                                        icon: const Icon(Icons.filter_alt_off, size: 16),
                                        label: const Text('Clear filters'),
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final isExpanded = _expandedIndex == index;
                                  final status = item['status'] ?? 'pending';
                                  final itemId = item['id'];
                                  final inProgressSince = (status == 'in_progress' && itemId != null)
                                      ? _inProgressStartTimes[itemId]
                                      : null;
                                  return IssueTaskCard(
                                    item: item,
                                    index: index,
                                    isExpanded: isExpanded,
                                    inProgressSince: inProgressSince,
                                    onTap: () {
                                      setState(() {
                                        _expandedIndex = isExpanded ? null : index;
                                      });
                                    },
                                    onFix: () => _fixNow(item),
                                    onReset: () => _resetItem(item),
                                    onCardDelete: () => _deleteItem(item),
                                    onSwipeDelete: () => _deleteItemDirect(item),
                                    onComplete: () => _completeItem(item),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

