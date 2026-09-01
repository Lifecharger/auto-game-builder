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
import '../widgets/sync_status_chip.dart';
import '../widgets/task_filters_widget.dart';
import '../l10n/app_localizations.dart';
import '../utils/l10n_labels.dart';

class IssuesScreen extends StatefulWidget {
  const IssuesScreen({super.key});

  @override
  State<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends State<IssuesScreen> with WidgetsBindingObserver {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  List<dynamic> _allItems = [];
  bool _loading = false;
  String? _loadError;
  /// Moment the task list was last successfully fetched from the server
  /// (for the "Synced Xm ago" chip). Null until the first good load.
  DateTime? _lastSyncedAt;
  int? _selectedAppId;
  // Expanded task keyed by its stable task id (not the list index) so a
  // reorder/filter/search can't move the expansion to a different task.
  dynamic _expandedTaskId;
  Timer? _pollTimer;
  // Guards against overlapping/stale _loadItems responses (poll can fire while
  // a previous getAppTasks — up to ~17s with retry+timeout — is still running).
  bool _loadInFlight = false;
  int _loadSeq = 0;
  bool _appInForeground = true;
  static const _myTabIndex = 1;
  final _searchController = TextEditingController();
  AppState? _appStateRef;

  /// Max time a task can stay in_progress before auto-reset (30 min).
  /// Measured from the server-stamped `started_at`, never a phone-local clock.
  static const _stuckThreshold = Duration(minutes: 30);

  /// Server-stamped moment a task entered in_progress, or null if the task is
  /// not running or the server has not stamped it yet.
  static DateTime? _inProgressSince(dynamic item) {
    if (item is! Map) return null;
    if ((item['status'] ?? '').toString() != 'in_progress') return null;
    final raw = item['started_at'];
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _statusFilter = 'all';
  String _typeFilter = 'all';
  /// Whether the collapsed "Built" block (built tasks only) is expanded.
  /// Only applies to the unfiltered list view.
  bool _doneExpanded = false;
  static const _doneStatuses = {'built'};
  String _searchQuery = '';

  // Server-side search (single search across active + archived tasks;
  // matches title, description AND response fields).
  List<dynamic> _searchResults = [];
  bool _searchLoading = false;
  Timer? _searchDebounce;
  int _searchSeq = 0;

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
        'label': l10n.suggestUxPolish,
        'prompt': 'Many UI-related tasks were worked on recently. Suggest ideas for further UX improvements, better user flows, and visual polish to build on those fixes.',
      });
    }

    if (securityTasks >= 2) {
      suggestions.add({
        'label': l10n.suggestSecurityHardening,
        'prompt': 'There are security-related tasks in this app. Suggest additional security improvements like input validation, secure storage, API hardening, and data protection.',
      });
    }

    if (perfTasks >= 2) {
      suggestions.add({
        'label': l10n.suggestPerformanceBoost,
        'prompt': 'Performance-related work has been done on this app. Suggest further optimizations like lazy loading, caching strategies, reducing rebuilds, and memory efficiency.',
      });
    }

    if (failedCount >= 2) {
      suggestions.add({
        'label': l10n.suggestFixFailures,
        'prompt': 'Several tasks have failed status. Suggest ideas for improving reliability, adding error recovery, better error handling, and automated testing to prevent failures.',
      });
    }

    if (featureTasks >= 3) {
      suggestions.add({
        'label': l10n.suggestFeatureIntegration,
        'prompt': 'Multiple features have been added. Suggest ideas for better integration between existing features, reducing complexity, and improving feature discoverability.',
      });
    }

    if (totalCompleted >= 10 && pendingCount == 0) {
      suggestions.add({
        'label': l10n.suggestNextMilestone,
        'prompt': 'Many tasks are completed with nothing pending. Suggest ideas for the next development milestone, including new capabilities, polish, and user-requested features.',
      });
    }

    if (pendingCount >= 5) {
      suggestions.add({
        'label': l10n.suggestTaskPrioritization,
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
            'label': l10n.suggestRevenueIdeas,
            'prompt': 'Based on the app\'s design document mentioning monetization/revenue, suggest creative monetization strategies that align with the app\'s goals and user base.',
          });
        }

        if (gdd.contains('user') && (gdd.contains('engage') || gdd.contains('retention'))) {
          suggestions.add({
            'label': l10n.suggestUserEngagement,
            'prompt': 'The app\'s design document focuses on user engagement. Suggest ideas for notifications, gamification, onboarding improvements, and retention strategies.',
          });
        }

        if (gdd.contains('api') || gdd.contains('backend') || gdd.contains('server')) {
          suggestions.add({
            'label': l10n.suggestApiBackend,
            'prompt': 'The app relies on API/backend services. Suggest ideas for offline support, better error recovery, API caching, and reducing network dependency.',
          });
        }

        if (gdd.contains('test') || gdd.contains('quality')) {
          suggestions.add({
            'label': l10n.suggestTestingQa,
            'prompt': 'Suggest ideas for improving test coverage, adding integration tests, automated UI testing, and quality assurance workflows.',
          });
        }

        // If GDD exists but no specific pattern matched, add a generic GDD-aware prompt
        if (suggestions.where((s) =>
            s['label'] == l10n.suggestRevenueIdeas || s['label'] == l10n.suggestUserEngagement ||
            s['label'] == l10n.suggestApiBackend || s['label'] == l10n.suggestTestingQa).isEmpty) {
          suggestions.add({
            'label': l10n.suggestGddAligned,
            'prompt': 'Based on this app\'s design document and goals, suggest ideas that align with the product vision and fill gaps in the current implementation.',
          });
        }
      }
    }

    // If still empty, add at least one generic smart suggestion based on task count
    if (suggestions.isEmpty && items.isNotEmpty) {
      suggestions.add({
        'label': l10n.suggestImproveCodebase,
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
    _searchDebounce?.cancel();
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
    final requestedStatus = appState.issuesRequestedStatus;

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
      _expandedTaskId = null;
      _doneExpanded = false;
      if (requestedStatus != null) {
        _statusFilter = requestedStatus;
      }
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
    // Don't stack silent polls on top of an in-flight request (which can take
    // ~17s with retry+timeout); user-triggered reloads still proceed and rely
    // on the seq/appId guard below.
    if (silent && _loadInFlight) return;
    final appId = _selectedAppId!;
    final seq = ++_loadSeq;
    _loadInFlight = true;
    if (!silent) setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
    // getAppTasks already returns all tasks including ideas - no need for separate getIdeas call
    final result = await ApiService.getAppTasks(appId);

    // Ignore stale/overlapping responses: the app was switched or a newer
    // request superseded this one while it was in flight.
    if (!mounted || seq != _loadSeq || appId != _selectedAppId) return;
    {
      if (!result.ok) {
        // Keep the previously loaded list (and its scroll position) on
        // screen; the failure is surfaced as an inline banner instead.
        setState(() {
          _loadError = result.error ?? l10n.failedToLoadTasks;
          _loading = false;
        });
        return;
      }
      setState(() {
        final items = <dynamic>[];
        _loadError = null;
        _lastSyncedAt = DateTime.now();
        for (final t in result.data!) {
          final type = (t['task_type'] ?? t['type'] ?? 'issue').toString();
          t['_source'] = type == 'idea' ? 'idea' : 'task';
          items.add(t);
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
        if (!silent) _expandedTaskId = null;
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
    } finally {
      _loadInFlight = false;
    }
  }

  /// Auto-reset tasks stuck in_progress beyond [_stuckThreshold], measured
  /// from the server's `started_at` so a phone restart cannot reset the clock.
  void _autoResetStuckTasks() {
    final now = DateTime.now();
    final stuck = _allItems.where((item) {
      final since = _inProgressSince(item);
      return item['id'] is int && since != null && now.difference(since) > _stuckThreshold;
    }).toList();
    if (stuck.isEmpty) return;

    for (final item in stuck) {
      final appId = item['app_id'] as int? ?? _selectedAppId;
      if (appId == null) continue;
      // Fire-and-forget reset on server
      ApiService.updateAppTask(appId, item['id'] as int, {'status': 'failed', 'response': 'Auto-failed: task stuck for over 30 minutes'});
      // Update locally immediately
      item['status'] = 'failed';
    }
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.stuckTasksAutoFailed(stuck.length)),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  List<dynamic> get _filteredItems {
    // With an active query the source is the server search result set
    // (already matched on title/description/response across active +
    // archived tasks); status/type chips still narrow it locally.
    final source = _searchQuery.trim().isNotEmpty ? _searchResults : _allItems;
    return source.where((item) {
      final status = (item['status'] ?? 'pending').toString().toLowerCase();
      final type = (item['task_type'] ?? item['type'] ?? 'issue').toString().toLowerCase();
      if (_statusFilter != 'all' && status != _statusFilter) return false;
      if (_typeFilter != 'all' && type != _typeFilter) return false;
      return true;
    }).toList();
  }

  /// True when the list is grouped into actionable + collapsed built block.
  /// A specific status filter or a search query shows a flat list instead.
  bool get _isGroupedView => _statusFilter == 'all' && _searchQuery.trim().isEmpty;

  static bool _isDone(dynamic item) =>
      _doneStatuses.contains((item['status'] ?? 'pending').toString().toLowerCase());

  Widget _buildDoneHeader(int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _doneExpanded = !_doneExpanded),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.taskStatusColor('built').withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.taskStatusColor('built').withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.rocket_launch_outlined,
                  size: 18, color: AppColors.taskStatusColor('built')),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.builtCount(count),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Text(
                _doneExpanded ? l10n.hide : l10n.show,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
              Icon(
                _doneExpanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(dynamic item, int index) {
    final itemId = item['id'];
    final isExpanded = itemId != null && _expandedTaskId == itemId;
    final inProgressSince = _inProgressSince(item);
    return IssueTaskCard(
      item: item,
      index: index,
      isExpanded: isExpanded,
      inProgressSince: inProgressSince,
      onTap: () {
        setState(() {
          _expandedTaskId = isExpanded ? null : itemId;
        });
      },
      onFix: () => _fixNow(item),
      onReset: () => _resetItem(item),
      onCardDelete: () => _deleteItem(item),
      onSwipeDelete: () => _deleteItemDirect(item),
      onComplete: () => _completeItem(item),
      onBlockerTap: _showBlockerDialog,
    );
  }

  /// Grouped list: actionable items (in_progress/pending/failed/divided) are
  /// always visible; completed/built sit under a single collapsible header.
  Widget _buildGroupedList(List<dynamic> filtered) {
    final actionable = <dynamic>[];
    final done = <dynamic>[];
    for (final item in filtered) {
      (_isDone(item) ? done : actionable).add(item);
    }
    final showDoneItems = _doneExpanded && done.isNotEmpty;
    final headerCount = done.isEmpty ? 0 : 1;
    final itemCount =
        actionable.length + headerCount + (showDoneItems ? done.length : 0);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < actionable.length) {
          return _buildItemCard(actionable[index], index);
        }
        if (index == actionable.length) {
          return _buildDoneHeader(done.length);
        }
        final doneIndex = index - actionable.length - 1;
        if (doneIndex < 0 || doneIndex >= done.length) {
          return const SizedBox.shrink();
        }
        return _buildItemCard(done[doneIndex], index);
      },
    );
  }

  /// Debounced server-side search across active + archived tasks.
  void _scheduleServerSearch() {
    _searchDebounce?.cancel();
    final q = _searchQuery.trim();
    if (q.isEmpty || _selectedAppId == null) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      return;
    }
    setState(() => _searchLoading = true);
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      final appId = _selectedAppId!;
      final seq = ++_searchSeq;
      final result = await ApiService.searchAppTasks(appId, q);
      if (!mounted || seq != _searchSeq || appId != _selectedAppId) return;
      setState(() {
        _searchLoading = false;
        if (result.ok) {
          final items = result.data!;
          for (final t in items) {
            final type = (t['task_type'] ?? t['type'] ?? 'issue').toString();
            t['_source'] = type == 'idea' ? 'idea' : 'task';
          }
          _searchResults = items;
        }
      });
    });
  }

  /// Show the blocker task's details when a "blocked by #N" chip is tapped.
  void _showBlockerDialog(int blockerId) {
    final blocker =
        _allItems.where((i) => i['id'] == blockerId).firstOrNull;
    if (blocker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.blockerNotInList(blockerId)),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final status = (blocker['status'] ?? 'pending').toString();
    final desc = (blocker['description'] ?? '').toString().trim();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('#$blockerId ${blocker['title'] ?? ''}',
            style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.taskStatusColor(status).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.taskStatusColor(status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(desc,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade300)),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
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
        title: Text(l10n.workOnThis),
        content: Text(l10n.workOnThisConfirm(agentLabel, title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.doIt),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    // Immediately show in_progress in UI
    setState(() {
      item['status'] = 'in_progress';
      item['started_at'] = DateTime.now().toIso8601String();
    });
    try {
      await ApiService.updateAppTask(appId, taskId, {'status': 'in_progress'});
      final result = await ApiService.runTask(appId, taskId, aiAgent: aiAgent);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.ok
                ? l10n.agentTriggeredFor(agentLabel, title)
                : result.error ?? l10n.failedToRunTask),
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
          item.remove('started_at');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorWithMessage(e)),
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
          content: Text(result.ok ? l10n.taskResetToPending : result.error ?? l10n.failedToReset),
          backgroundColor: result.ok ? AppColors.success : AppColors.error,
        ),
      );
      if (result.ok) {
        setState(() {
          item['status'] = 'pending';
          item.remove('started_at');
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
          content: Text(result.ok ? l10n.markedAsCompleted : result.error ?? l10n.failedToUpdate),
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
            content: Text(result.ok ? l10n.deleted : result.error ?? l10n.failedToDelete),
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
            content: Text(result.ok ? l10n.deleted : result.error ?? l10n.failedToDelete),
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
        title: Text(l10n.delete),
        content: Text(l10n.deleteConfirmTitled(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    _deleteItemDirect(item);
  }

  Future<void> _workOnAll() async {
    if (_selectedAppId == null) return;
    // Blocked tasks (unmet depends_on) are skipped — their blocker has to
    // finish first; the server would reject the run anyway.
    final blockedCount = _allItems.where((item) {
      final status = (item['status'] ?? 'pending').toString().toLowerCase();
      return status == 'pending' && item['blocked'] == true;
    }).length;
    final pendingItems = _allItems.where((item) {
      final status = (item['status'] ?? 'pending').toString().toLowerCase();
      return status == 'pending' && item['blocked'] != true;
    }).toList();

    if (pendingItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(blockedCount > 0
                ? l10n.allPendingBlocked
                : l10n.noPendingItems),
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
        title: Text(l10n.workOnAllPending),
        content: Text(l10n.workOnAllConfirm(pendingItems.length) +
            (blockedCount > 0 ? l10n.workOnAllBlockedNote(blockedCount) : '')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.workOnAll),
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
              content: Text(l10n.processingTasks(processed, total)),
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
            item['started_at'] = DateTime.now().toIso8601String();
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
                item.remove('started_at');
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
            content: Text(l10n.batchRunError(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.triggeredOfItems(triggered, pendingItems.length)),
          backgroundColor: triggered > 0 ? AppColors.success : AppColors.error,
        ),
      );
      _loadItems();
    }
  }

  Future<void> _createTestTask() async {
    if (_selectedAppId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.selectAnAppFirst),
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
        SnackBar(
          content: Text(l10n.testTaskCreated),
          backgroundColor: AppColors.success,
        ),
      );
      _loadItems();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? l10n.failedToCreateTestTask),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _generateIdeas() async {
    if (_selectedAppId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.selectAnAppFirst),
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
                              showHistory ? l10n.promptHistory : l10n.generateIdeas,
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
                              tooltip: showFavoritesOnly ? l10n.showAll : l10n.favoritesOnly,
                              onPressed: () => setDialogState(
                                () => showFavoritesOnly = !showFavoritesOnly,
                              ),
                            ),
                          IconButton(
                            icon: Icon(
                              showHistory ? Icons.edit : Icons.history,
                              size: 22,
                            ),
                            tooltip: showHistory ? l10n.newPrompt : l10n.promptHistoryTooltip,
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
                                        l10n.suggestedForYou,
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
                                Text(
                                  l10n.selectCategoriesOrPrompt,
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: categoryChips.entries.map((e) {
                                    final isSelected = selectedCategories.contains(e.key);
                                    return FilterChip(
                                      label: Text(ideaCategoryLabel(l10n, e.key),
                                          style: const TextStyle(fontSize: 12)),
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
                                  decoration: InputDecoration(
                                    hintText: l10n.generateIdeasHint,
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
                              child: Text(l10n.cancel, style: TextStyle(fontSize: 13)),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, {
                                'prompt': controller.text,
                                'categories': selectedCategories.toList(),
                              }),
                              child: Text(l10n.generate, style: TextStyle(fontSize: 13)),
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
                                    ? l10n.noFavoritePrompts
                                    : l10n.noPromptHistory,
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
                              child: Text(l10n.close, style: TextStyle(fontSize: 13)),
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
          content: Text(apiResult.ok ? l10n.ideaGenerationRequested : apiResult.error ?? l10n.failedToRequestIdeas),
          backgroundColor: apiResult.ok ? AppColors.success : AppColors.error,
        ),
      );
      if (apiResult.ok) _loadItems();
    }
  }

  Future<void> _codeCheck() async {
    if (_selectedAppId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.selectAnAppFirst),
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
              title: Text(l10n.codeCheck),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.codeCheckBody,
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.checksToRun, style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...checks.entries.map((e) => CheckboxListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: EdgeInsets.zero,
                    title: Text(codeCheckLabel(l10n, e.key),
                        style: const TextStyle(fontSize: 14)),
                    value: e.value,
                    onChanged: (v) => setDialogState(() => checks[e.key] = v ?? false),
                  )),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                FilledButton(
                  onPressed: checks.values.any((v) => v)
                      ? () => Navigator.pop(ctx, true)
                      : null,
                  child: Text(l10n.runCheck),
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
          content: Text(result.ok ? l10n.codeCheckRequested : result.error ?? l10n.failedToRequestCodeCheck),
          backgroundColor: result.ok ? AppColors.success : AppColors.error,
        ),
      );
      if (result.ok) _loadItems();
    }
  }

  Future<void> _designReview() async {
    if (_selectedAppId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectAnAppFirst), backgroundColor: AppColors.warning),
      );
      return;
    }
    final result = await ApiService.studioAction(_selectedAppId!, 'design-review');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok ? l10n.designReviewTaskCreated : result.error ?? l10n.failed),
        backgroundColor: result.ok ? AppColors.success : AppColors.error,
      ),
    );
    if (result.ok) _loadItems();
  }

  Future<void> _balanceCheck() async {
    await _runStudioAction('balance-check', l10n.balanceCheckTaskCreated);
  }

  /// Generic handler for any /api/apps/{id}/studio/{action} call.
  /// Shows a warning if no app is selected, otherwise posts the action
  /// and refreshes the task list on success.
  Future<void> _runStudioAction(String action, String successMessage) async {
    if (_selectedAppId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectAnAppFirst), backgroundColor: AppColors.warning),
      );
      return;
    }
    final result = await ApiService.studioAction(_selectedAppId!, action);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok ? successMessage : result.error ?? l10n.failed),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.issues),
            if (_selectedAppId != null)
              SyncStatusChip(
                lastSyncedAt: _lastSyncedAt,
                failed: _loadError != null,
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _createTestTask,
            icon: const Icon(Icons.phone_android),
            tooltip: l10n.test,
          ),
          IconButton(
            onPressed: _generateIdeas,
            icon: const Icon(Icons.auto_awesome),
            tooltip: l10n.generateIdeas,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.science),
            tooltip: l10n.studioReviews,
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
                  _runStudioAction('consistency-check', l10n.consistencyCheckTaskCreated);
                  break;
                case 'tech-debt':
                  _runStudioAction('tech-debt', l10n.techDebtTaskCreated);
                  break;
                case 'asset-audit':
                  _runStudioAction('asset-audit', l10n.assetAuditTaskCreated);
                  break;
                case 'content-audit':
                  _runStudioAction('content-audit', l10n.contentAuditTaskCreated);
                  break;
                case 'scope-check':
                  _runStudioAction('scope-check', l10n.scopeCheckTaskCreated);
                  break;
                case 'perf-profile':
                  _runStudioAction('perf-profile', l10n.perfProfileTaskCreated);
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'code-review',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.bug_report, size: 20),
                  title: Text(l10n.codeReview, style: TextStyle(fontSize: 14)),
                  subtitle: Text(l10n.codeReviewSubtitle, style: TextStyle(fontSize: 11)),
                ),
              ),
              PopupMenuItem(
                value: 'design-review',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.design_services, size: 20),
                  title: Text(l10n.designReview, style: TextStyle(fontSize: 14)),
                  subtitle: Text(l10n.designReviewSubtitle, style: TextStyle(fontSize: 11)),
                ),
              ),
              PopupMenuItem(
                value: 'balance-check',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.balance, size: 20),
                  title: Text(l10n.balanceCheck, style: TextStyle(fontSize: 14)),
                  subtitle: Text(l10n.balanceCheckSubtitle, style: TextStyle(fontSize: 11)),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'consistency-check',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.rule, size: 20),
                  title: Text(l10n.consistencyCheck, style: TextStyle(fontSize: 14)),
                  subtitle: Text(l10n.consistencyCheckSubtitle, style: TextStyle(fontSize: 11)),
                ),
              ),
              PopupMenuItem(
                value: 'tech-debt',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.cleaning_services, size: 20),
                  title: Text(l10n.techDebtScan, style: TextStyle(fontSize: 14)),
                  subtitle: Text(l10n.techDebtScanSubtitle, style: TextStyle(fontSize: 11)),
                ),
              ),
              PopupMenuItem(
                value: 'asset-audit',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.fact_check, size: 20),
                  title: Text(l10n.assetAudit, style: TextStyle(fontSize: 14)),
                  subtitle: Text(l10n.assetAuditSubtitle, style: TextStyle(fontSize: 11)),
                ),
              ),
              PopupMenuItem(
                value: 'content-audit',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.playlist_add_check, size: 20),
                  title: Text(l10n.contentAudit, style: TextStyle(fontSize: 14)),
                  subtitle: Text(l10n.contentAuditSubtitle, style: TextStyle(fontSize: 11)),
                ),
              ),
              PopupMenuItem(
                value: 'scope-check',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.filter_list, size: 20),
                  title: Text(l10n.scopeCheck, style: TextStyle(fontSize: 14)),
                  subtitle: Text(l10n.scopeCheckSubtitle, style: TextStyle(fontSize: 11)),
                ),
              ),
              PopupMenuItem(
                value: 'perf-profile',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.speed, size: 20),
                  title: Text(l10n.performanceProfile, style: TextStyle(fontSize: 14)),
                  subtitle: Text(l10n.performanceProfileSubtitle, style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.palette),
            tooltip: l10n.artAndAssets,
            onSelected: (value) {
              switch (value) {
                case 'art-bible':
                  _runStudioAction('art-bible', l10n.artBibleTaskCreated);
                  break;
                case 'asset-spec':
                  _runStudioAction('asset-spec', l10n.assetSpecTaskCreated);
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'art-bible',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.auto_stories, size: 20),
                  title: Text(l10n.artBible, style: TextStyle(fontSize: 14)),
                  subtitle: Text(l10n.artBibleCardSubtitle, style: TextStyle(fontSize: 11)),
                ),
              ),
              PopupMenuItem(
                value: 'asset-spec',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.inventory_2, size: 20),
                  title: Text(l10n.assetSpecs, style: TextStyle(fontSize: 14)),
                  subtitle: Text(l10n.assetSpecsSubtitle, style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: _workOnAll,
            icon: const Icon(Icons.play_circle_outline),
            tooltip: l10n.workOnAllPending,
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
                  label: Text(l10n.statusInProgress),
                  icon: const Icon(Icons.code, size: 18),
                ),
                ButtonSegment(
                  value: 'postponed',
                  label: Text(l10n.statusPostponed),
                  icon: const Icon(Icons.pause_circle_outline, size: 18),
                ),
                ButtonSegment(
                  value: 'completed',
                  label: Text(l10n.statusCompleted),
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
                  _expandedTaskId = null;
                  _searchResults = [];
                });
                if (_selectedAppId != null) _loadItems();
                _scheduleServerSearch();
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
              decoration: InputDecoration(
                hintText: l10n.selectApp,
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
                  _expandedTaskId = null;
                  _doneExpanded = false;
                  _searchResults = [];
                  _lastSyncedAt = null;
                  _loadError = null;
                });
                _loadItems();
                _scheduleServerSearch();
              },
            ),
          ),
          TaskFiltersWidget(
            searchController: _searchController,
            searchQuery: _searchQuery,
            onSearchChanged: (val) {
              setState(() => _searchQuery = val);
              _scheduleServerSearch();
            },
            onSearchClear: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _searchResults = [];
                _searchLoading = false;
              });
            },
            statusFilter: _statusFilter,
            statusOptions: _statusOptions,
            onStatusChanged: (s) {
              setState(() {
                _statusFilter = s;
                _expandedTaskId = null;
              });
            },
            typeFilter: _typeFilter,
            typeOptions: _typeOptions,
            onTypeChanged: (t) {
              setState(() {
                _typeFilter = t;
                _expandedTaskId = null;
              });
            },
          ),
          if (_searchLoading) const LinearProgressIndicator(minHeight: 2),
          if (_loadError != null && !_loading)
            SyncErrorBanner(
              message: _loadError!,
              onRetry: () => _loadItems(silent: true),
              onDismiss: () => setState(() => _loadError = null),
            ),
          // Item list
          Expanded(
            child: _selectedAppId == null
                ? Center(
                    child: Text(
                      l10n.selectAppToViewItems,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        color: AppColors.accent,
                        onRefresh: _loadItems,
                        child: _loadError != null && _allItems.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 120),
                                  Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade600),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: Text(
                                      _loadError!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 16),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: ElevatedButton.icon(
                                      onPressed: _loadItems,
                                      icon: const Icon(Icons.refresh),
                                      label: Text(l10n.retry),
                                    ),
                                  ),
                                ],
                              )
                            : filtered.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 160),
                                  Center(
                                    child: Text(
                                      l10n.noItemsFound,
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
                                              label: Text(l10n.statusFilterChip(TaskFiltersWidget.chipLabel(context, _statusFilter)), style: const TextStyle(fontSize: 11)),
                                              visualDensity: VisualDensity.compact,
                                              side: BorderSide(color: AppColors.taskStatusColor(_statusFilter)),
                                            ),
                                          if (_typeFilter != 'all')
                                            Chip(
                                              label: Text(l10n.typeFilterChip(TaskFiltersWidget.chipLabel(context, _typeFilter)), style: const TextStyle(fontSize: 11)),
                                              visualDensity: VisualDensity.compact,
                                              side: BorderSide(color: AppColors.taskTypeColor(_typeFilter)),
                                            ),
                                          if (_searchQuery.isNotEmpty)
                                            Chip(
                                              label: Text(l10n.searchFilterChip(_searchQuery), style: const TextStyle(fontSize: 11)),
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
                                            _expandedTaskId = null;
                                          });
                                        },
                                        icon: const Icon(Icons.filter_alt_off, size: 16),
                                        label: Text(l10n.clearFilters),
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            : _isGroupedView
                                ? _buildGroupedList(filtered)
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) =>
                                        _buildItemCard(filtered[index], index),
                                  ),
                      ),
          ),
        ],
      ),
    );
  }
}