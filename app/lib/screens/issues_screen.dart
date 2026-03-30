import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
// image_picker temporarily disabled - incompatible with Flutter 3.38+
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_model.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../theme.dart';

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
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
  }

  bool get _hasActiveInProgress => _inProgressStartTimes.isNotEmpty;

  /// Adaptive polling: 8s when tasks are running, 30s otherwise.
  void _startPolling() {
    _pollTimer?.cancel();
    final interval = _hasActiveInProgress
        ? const Duration(seconds: 8)
        : const Duration(seconds: 30);
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

      // Adjust polling speed based on whether tasks are active
      _startPolling();

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
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String taskType = 'issue';
    String priority = 'normal';
    bool submitting = false;
    List<File> attachedImages = [];

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
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: mq.viewInsets.bottom + mq.padding.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const Text(
                      'New Item',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        hintText: 'Title',
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Description...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Type',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['issue', 'bug', 'fix', 'feature', 'idea'].map((type) {
                        final selected = type == taskType;
                        return ChoiceChip(
                          label: Text(type[0].toUpperCase() + type.substring(1)),
                          selected: selected,
                          selectedColor: AppColors.taskTypeColor(type),
                          onSelected: (sel) {
                            if (sel) setSheetState(() => taskType = type);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Priority',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['normal', 'urgent'].map((p) {
                        final selected = p == priority;
                        return ChoiceChip(
                          label: Text(p[0].toUpperCase() + p.substring(1)),
                          selected: selected,
                          selectedColor:
                              p == 'urgent' ? AppColors.error : AppColors.info,
                          avatar: Icon(
                            p == 'urgent'
                                ? Icons.priority_high
                                : Icons.flag_outlined,
                            size: 16,
                            color: selected
                                ? Colors.white
                                : Colors.grey.shade400,
                          ),
                          onSelected: (sel) {
                            if (sel) setSheetState(() => priority = p);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Attachments',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (attachedImages.isNotEmpty)
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: attachedImages.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(attachedImages[i].path),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => setSheetState(() => attachedImages.removeAt(i)),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (attachedImages.isNotEmpty)
                      const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickMultiImage(imageQuality: 80);
                        if (picked.isNotEmpty) {
                          setSheetState(() {
                            attachedImages.addAll(picked.map((x) => File(x.path)));
                          });
                        }
                      },
                      icon: const Icon(Icons.attach_file),
                      label: Text(attachedImages.isEmpty ? 'Add Photo' : 'Add More'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: submitting
                            ? null
                            : () async {
                                final title = titleController.text.trim();
                                if (title.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Title is required'),
                                      backgroundColor: AppColors.warning,
                                    ),
                                  );
                                  return;
                                }
                                setSheetState(() => submitting = true);
                                List<String>? base64Attachments;
                                if (attachedImages.isNotEmpty) {
                                  base64Attachments = [];
                                  for (final img in attachedImages) {
                                    final bytes = await File(img.path).readAsBytes();
                                    base64Attachments.add(base64Encode(bytes));
                                  }
                                }
                                final result = await ApiService.createAppTask(
                                  appId: _selectedAppId!,
                                  title: title,
                                  description: descController.text.trim(),
                                  taskType: taskType,
                                  priority: priority,
                                  attachments: base64Attachments,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(result.ok
                                          ? 'Item created'
                                          : result.error ?? 'Failed to create item'),
                                      backgroundColor:
                                          result.ok ? AppColors.success : AppColors.error,
                                    ),
                                  );
                                  if (result.ok) _loadItems();
                                }
                              },
                        icon: submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        label: Text(submitting ? 'Submitting...' : 'Submit'),
                      ),
                    ),
                  ],
                ),
              );
          },
        );
      },
    );
  }

  /// Get the AI agent (fix_strategy) for an app from AppState.
  String _getAppAgent(int appId) {
    final apps = context.read<AppState>().apps;
    final app = apps.where((a) => a.id == appId).firstOrNull;
    return app?.fixStrategy ?? '';
  }

  Future<void> _fixNow(Map<String, dynamic> item) async {
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
      // Revert on any unexpected error so task never stays stuck
      ApiService.updateAppTask(appId, taskId, {'status': 'pending'});
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
    final setInProgress = <int>[]; // track which tasks we set to in_progress
    final aiAgent = _selectedAppId != null ? _getAppAgent(_selectedAppId!) : '';
    try {
      for (final item in pendingItems) {
        if (!mounted) break;
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
      // Revert any tasks we set to in_progress that weren't successfully triggered
      for (final taskId in setInProgress) {
        final appId = pendingItems
            .where((i) => i['id'] == taskId)
            .firstOrNull?['app_id'] as int? ?? _selectedAppId;
        if (appId != null) {
          ApiService.updateAppTask(appId, taskId, {'status': 'pending'});
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
                                                minWidth: 36, minHeight: 36),
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
                                                minWidth: 32, minHeight: 32),
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
    if (_selectedAppId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an app first'), backgroundColor: AppColors.warning),
      );
      return;
    }
    final result = await ApiService.studioAction(_selectedAppId!, 'balance-check');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok ? 'Balance check task created' : result.error ?? 'Failed'),
        backgroundColor: result.ok ? AppColors.success : AppColors.error,
      ),
    );
    if (result.ok) _loadItems();
  }

  String _chipLabel(String value) {
    switch (value) {
      case 'all': return 'All';
      case 'in_progress': return 'In Progress';
      default: return value[0].toUpperCase() + value.substring(1);
    }
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
            tooltip: 'Studio Actions',
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
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          // Status filter chips
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _statusOptions.map((s) {
                final selected = s == _statusFilter;
                final color = s == 'all' ? AppColors.accent : AppColors.taskStatusColor(s);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(_chipLabel(s), style: TextStyle(fontSize: 12)),
                    selected: selected,
                    selectedColor: color.withValues(alpha: 0.3),
                    checkmarkColor: color,
                    side: BorderSide(color: selected ? color : Colors.grey.shade700),
                    onSelected: (_) {
                      setState(() {
                        _statusFilter = s;
                        _expandedIndex = null;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          // Type/tag filter chips
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _typeOptions.map((t) {
                final selected = t == _typeFilter;
                final color = t == 'all' ? AppColors.accent : AppColors.taskTypeColor(t);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(_chipLabel(t), style: TextStyle(fontSize: 12)),
                    selected: selected,
                    selectedColor: color.withValues(alpha: 0.3),
                    checkmarkColor: color,
                    side: BorderSide(color: selected ? color : Colors.grey.shade700),
                    onSelected: (_) {
                      setState(() {
                        _typeFilter = t;
                        _expandedIndex = null;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
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
                                              label: Text('Status: ${_chipLabel(_statusFilter)}', style: const TextStyle(fontSize: 11)),
                                              visualDensity: VisualDensity.compact,
                                              side: BorderSide(color: AppColors.taskStatusColor(_statusFilter)),
                                            ),
                                          if (_typeFilter != 'all')
                                            Chip(
                                              label: Text('Type: ${_chipLabel(_typeFilter)}', style: const TextStyle(fontSize: 11)),
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
                                  final taskType = (item['task_type'] ?? item['type'] ?? 'issue').toString();
                                  final canDelete = status != 'completed';
                                  final itemId = item['id'];
                                  final inProgressSince = (status == 'in_progress' && itemId != null)
                                      ? _inProgressStartTimes[itemId]
                                      : null;
                                  final card = _ItemCard(
                                    item: item,
                                    typeColor: AppColors.taskTypeColor(taskType),
                                    statusColor: AppColors.taskStatusColor(status),
                                    isExpanded: isExpanded,
                                    inProgressSince: inProgressSince,
                                    onTap: () {
                                      setState(() {
                                        _expandedIndex = isExpanded ? null : index;
                                      });
                                    },
                                    onFixNow: () => _fixNow(item),
                                    onDelete: canDelete ? () => _deleteItem(item) : null,
                                    onReset: status == 'in_progress' ? () => _resetItem(item) : null,
                                  );
                                  final canComplete = status != 'completed' && item['_source'] != 'idea';
                                  if (!canDelete && !canComplete) return card;
                                  return Dismissible(
                                    key: ValueKey('${item['_source']}_${item['id'] ?? index}'),
                                    direction: canDelete && canComplete
                                        ? DismissDirection.horizontal
                                        : canComplete
                                            ? DismissDirection.startToEnd
                                            : DismissDirection.endToStart,
                                    // Swipe right -> complete (green)
                                    background: Container(
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.only(left: 20),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle, color: AppColors.success),
                                          SizedBox(width: 8),
                                          Text('Complete', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    // Swipe left -> delete (red)
                                    secondaryBackground: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                                          SizedBox(width: 8),
                                          Icon(Icons.delete, color: AppColors.error),
                                        ],
                                      ),
                                    ),
                                    confirmDismiss: (direction) async {
                                      if (direction == DismissDirection.startToEnd) {
                                        // Complete: confirm then act
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: AppColors.bgCard,
                                            title: const Text('Mark Complete'),
                                            content: Text('Mark "${item['title']}" as completed?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(ctx, true),
                                                style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                                                child: const Text('Complete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) _completeItem(item);
                                        return false; // don't remove from list; _loadItems will refresh
                                      } else {
                                        // Delete: confirm
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: AppColors.bgCard,
                                            title: const Text('Delete'),
                                            content: Text('Delete "${item['title']}"?\nThis cannot be undone.'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(ctx, true),
                                                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) _deleteItemDirect(item);
                                        return false; // _loadItems handles list refresh
                                      }
                                    },
                                    child: card,
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

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Color typeColor;
  final Color statusColor;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onFixNow;
  final VoidCallback? onDelete;
  final VoidCallback? onReset;
  final DateTime? inProgressSince;

  const _ItemCard({
    required this.item,
    required this.typeColor,
    required this.statusColor,
    required this.isExpanded,
    required this.onTap,
    this.onFixNow,
    this.onDelete,
    this.onReset,
    this.inProgressSince,
  });

  void _showCopyMenu(BuildContext context, String title, String description, String aiResponse) {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(value: 'title', child: Text('Copy Title')),
    ];
    if (description.isNotEmpty) {
      items.add(const PopupMenuItem(value: 'desc', child: Text('Copy Description')));
    }
    if (aiResponse.isNotEmpty) {
      items.add(const PopupMenuItem(value: 'response', child: Text('Copy AI Response')));
    }

    final RenderBox box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final size = MediaQuery.of(context).size;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + box.size.width / 2,
        offset.dy + box.size.height / 2,
        size.width - (offset.dx + box.size.width / 2),
        size.height - (offset.dy + box.size.height / 2),
      ),
      items: items,
      color: AppColors.bgCard,
    ).then((value) {
      if (value == null) return;
      String text;
      switch (value) {
        case 'title': text = title; break;
        case 'desc': text = description; break;
        case 'response': text = aiResponse; break;
        default: return;
      }
      Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
      );
    });
  }

  void _showFullImage(BuildContext context, Uint8List bytes) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(bytes),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskId = item['id'];
    final title = item['title'] ?? '';
    final description = (item['description'] ?? '').toString().trim();
    final aiResponse = (item['ai_response'] ?? '').toString().trim();
    final taskType = (item['task_type'] ?? item['type'] ?? 'issue').toString();
    final priority = item['priority'] ?? 'normal';
    final status = item['status'] ?? 'pending';
    final agent = (item['agent'] ?? item['ai_agent'] ?? '').toString();
    final appName = (item['app_name'] ?? '').toString();
    final attachments = (item['attachments'] as List<dynamic>?)
        ?.whereType<String>()
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: () => _showCopyMenu(context, title, description, aiResponse),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 50,
                    decoration: BoxDecoration(
                      color: priority == 'urgent' ? AppColors.error : typeColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              if (taskId != null)
                                TextSpan(
                                  text: '#$taskId  ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              TextSpan(
                                text: title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          maxLines: isExpanded ? null : 2,
                          overflow: isExpanded ? null : TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                taskType,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: typeColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (priority == 'urgent')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.priority_high,
                                        size: 12, color: AppColors.error),
                                    SizedBox(width: 2),
                                    Text(
                                      'urgent',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (agent.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.agentColor(agent).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  agent.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.agentColor(agent),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            if (appName.isNotEmpty)
                              Text(
                                appName,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (status == 'in_progress') ...[
                              SizedBox(
                                width: 10, height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5, color: statusColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (inProgressSince != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _ElapsedTimer(since: inProgressSince!),
                        ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ),
                ],
              ),
              // Expanded detail
              if (isExpanded) ...[
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade300, height: 1.4),
                  ),
                ],
                if (attachments != null && attachments.isNotEmpty) ...[
                  () {
                    final decoded = <Uint8List>[];
                    for (final a in attachments) {
                      try { decoded.add(base64Decode(a)); } catch (_) {}
                    }
                    if (decoded.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: decoded.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (ctx, i) {
                            final bytes = decoded[i];
                            return GestureDetector(
                              onTap: () => _showFullImage(ctx, bytes),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(bytes, height: 120, fit: BoxFit.cover),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }(),
                ],
                if (aiResponse.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  if (title.toLowerCase().startsWith('code check'))
                    _buildCodeCheckResults(aiResponse)
                  else
                    _buildPlainAiResponse(aiResponse),
                ],
                if (status != 'completed') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (onFixNow != null)
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: FilledButton.icon(
                              onPressed: onFixNow,
                              style: FilledButton.styleFrom(
                                backgroundColor: status == 'in_progress' || status == 'failed'
                                    ? AppColors.error
                                    : AppColors.warning,
                              ),
                              icon: Icon(
                                status == 'in_progress' || status == 'failed'
                                    ? Icons.refresh
                                    : Icons.bolt,
                                size: 18,
                              ),
                              label: Text(
                                status == 'in_progress' || status == 'failed'
                                    ? 'Retry'
                                    : 'Work on This',
                              ),
                            ),
                          ),
                        ),
                      if (status == 'in_progress' && onReset != null) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 40,
                          child: OutlinedButton.icon(
                            onPressed: onReset,
                            icon: const Icon(Icons.restart_alt, size: 18),
                            label: const Text('Reset'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.warning,
                              side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5)),
                            ),
                          ),
                        ),
                      ],
                      if (onFixNow != null && onDelete != null)
                        const SizedBox(width: 8),
                      if (onDelete != null)
                        SizedBox(
                          height: 40,
                          width: 40,
                          child: IconButton(
                            onPressed: onDelete,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.error.withValues(alpha: 0.15),
                            ),
                            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlainAiResponse(String aiResponse) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.smart_toy, size: 14, color: AppColors.info),
            const SizedBox(width: 6),
            Text('AI Response',
                style: TextStyle(fontSize: 12, color: AppColors.info,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          SelectableText(
            aiResponse,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade200, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCheckResults(String response) {
    final sections = _parseCodeCheckSections(response);
    if (sections.isEmpty) return _buildPlainAiResponse(response);

    int total = 0, criticalCount = 0, highCount = 0, mediumCount = 0;
    for (final s in sections) {
      total += s.findings.length;
      for (final f in s.findings) {
        if (f.severity == 'critical') criticalCount++;
        if (f.severity == 'high') highCount++;
        if (f.severity == 'medium') mediumCount++;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.fact_check, size: 14, color: AppColors.info),
            const SizedBox(width: 6),
            Text('Code Check Results',
                style: TextStyle(fontSize: 12, color: AppColors.info,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('$total finding${total == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ]),
          if (criticalCount > 0 || highCount > 0 || mediumCount > 0) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              if (criticalCount > 0)
                _severityBadge('$criticalCount critical', const Color(0xFFE74C3C)),
              if (highCount > 0)
                _severityBadge('$highCount high', const Color(0xFFE67E22)),
              if (mediumCount > 0)
                _severityBadge('$mediumCount medium', const Color(0xFFF39C12)),
            ]),
          ],
          const SizedBox(height: 12),
          ...sections.map((s) => _buildCategorySection(s)),
        ],
      ),
    );
  }

  Widget _severityBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildCategorySection(_CodeCheckSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(section.icon, size: 14, color: section.color),
            const SizedBox(width: 6),
            Text(section.name,
                style: TextStyle(fontSize: 12, color: section.color,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Text('(${section.findings.length})',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ]),
          const SizedBox(height: 6),
          ...section.findings.map((f) => _buildFindingRow(f)),
        ],
      ),
    );
  }

  Widget _buildFindingRow(_CodeCheckFinding finding) {
    final color = _severityColor(finding.severity);
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          if (finding.severity != 'info') ...[
            Container(
              margin: const EdgeInsets.only(top: 1),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(finding.severity.toUpperCase(),
                  style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: SelectableText(finding.text,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade300, height: 1.4)),
          ),
        ],
      ),
    );
  }

  static Color _severityColor(String severity) {
    switch (severity) {
      case 'critical': return const Color(0xFFE74C3C);
      case 'high': return const Color(0xFFE67E22);
      case 'medium': return const Color(0xFFF39C12);
      case 'low': return const Color(0xFF3498DB);
      default: return const Color(0xFF95A5A6);
    }
  }

  static List<_CodeCheckSection> _parseCodeCheckSections(String response) {
    final lines = response.split('\n');
    final sections = <_CodeCheckSection>[];
    String? currentName;
    IconData currentIcon = Icons.info;
    Color currentColor = Colors.grey;
    List<_CodeCheckFinding> currentFindings = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Detect section headers: ## Header, **Header**, Header:
      final headerMatch = RegExp(
        r'^#{1,3}\s+(.*?)(?::?\s*$)'
        r'|^(?:\d+\.\s+)?\*\*(.*?)\*\*:?\s*$'
        r'|^([A-Z][A-Za-z &/]{2,50}):\s*$'
      ).firstMatch(trimmed);

      if (headerMatch != null) {
        final headerText = (headerMatch.group(1) ?? headerMatch.group(2) ?? headerMatch.group(3) ?? '').trim();
        if (headerText.isEmpty) continue;

        if (currentName != null && currentFindings.isNotEmpty) {
          sections.add(_CodeCheckSection(
            name: currentName, icon: currentIcon,
            color: currentColor, findings: List.from(currentFindings),
          ));
        }
        final config = _matchCategory(headerText);
        currentName = config.name;
        currentIcon = config.icon;
        currentColor = config.color;
        currentFindings = [];
        continue;
      }

      if (currentName != null) {
        String text = trimmed
            .replaceFirst(RegExp(r'^[-*\u2022]\s*'), '')
            .replaceFirst(RegExp(r'^\d+\.\s*'), '');
        if (text.isEmpty) continue;
        if (RegExp(r'^no\s+(issues?|findings?|problems?)\s+found', caseSensitive: false).hasMatch(text)) continue;

        final severity = _detectSeverity(text);
        text = text
            .replaceAll(RegExp(r'\*?\*?\[(?:CRITICAL|HIGH|MEDIUM|LOW|INFO)\]\*?\*?\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'\((?:critical|high|medium|low|info)\)\s*', caseSensitive: false), '')
            .replaceFirst(RegExp(r'^(?:CRITICAL|HIGH|MEDIUM|LOW|INFO):\s*', caseSensitive: false), '')
            .replaceFirst(RegExp(r'^Severity:\s*\w+\s*[-\u2013\u2014]\s*', caseSensitive: false), '')
            .trim();
        if (text.isNotEmpty) {
          currentFindings.add(_CodeCheckFinding(text: text, severity: severity));
        }
      }
    }

    if (currentName != null && currentFindings.isNotEmpty) {
      sections.add(_CodeCheckSection(
        name: currentName, icon: currentIcon,
        color: currentColor, findings: List.from(currentFindings),
      ));
    }
    return sections;
  }

  static String _detectSeverity(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'\bcritical\b').hasMatch(lower)) return 'critical';
    if (RegExp(r'\bhigh\b').hasMatch(lower)) return 'high';
    if (RegExp(r'\bmedium\b').hasMatch(lower)) return 'medium';
    if (RegExp(r'\blow\b').hasMatch(lower)) return 'low';
    return 'info';
  }

  static ({String name, IconData icon, Color color}) _matchCategory(String header) {
    final lower = header.toLowerCase();
    if (RegExp(r'bug|crash|fault').hasMatch(lower)) {
      return (name: 'Bugs & Crashes', icon: Icons.bug_report, color: const Color(0xFFE74C3C));
    }
    if (RegExp(r'secur|vulnerab|injection|xss').hasMatch(lower)) {
      return (name: 'Security', icon: Icons.security, color: const Color(0xFFE67E22));
    }
    if (RegExp(r'perform|speed|slow|optim|efficien').hasMatch(lower)) {
      return (name: 'Performance', icon: Icons.speed, color: const Color(0xFFF39C12));
    }
    if (RegExp(r'style|format|naming|convention|lint|readab').hasMatch(lower)) {
      return (name: 'Code Style', icon: Icons.brush, color: const Color(0xFF3498DB));
    }
    if (RegExp(r'dead.?code|unused|unreachable|deprecat').hasMatch(lower)) {
      return (name: 'Dead Code', icon: Icons.delete_outline, color: const Color(0xFF95A5A6));
    }
    if (RegExp(r'error.?handl|exception.?handl|try.?catch').hasMatch(lower)) {
      return (name: 'Error Handling', icon: Icons.warning_amber, color: const Color(0xFFF1C40F));
    }
    if (RegExp(r'memory|leak|dispose').hasMatch(lower)) {
      return (name: 'Memory', icon: Icons.memory, color: const Color(0xFFAB47BC));
    }
    return (name: header, icon: Icons.info_outline, color: const Color(0xFF95A5A6));
  }
}

// --- Code Check Results Display ---

class _CodeCheckSection {
  final String name;
  final IconData icon;
  final Color color;
  final List<_CodeCheckFinding> findings;

  _CodeCheckSection({
    required this.name,
    required this.icon,
    required this.color,
    required this.findings,
  });
}

class _CodeCheckFinding {
  final String text;
  final String severity;

  _CodeCheckFinding({required this.text, required this.severity});
}

/// Counting-up timer that shows elapsed time since a given start time.
class _ElapsedTimer extends StatefulWidget {
  final DateTime since;
  const _ElapsedTimer({required this.since});

  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.since);
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final text = h > 0 ? '$h:$m:$s' : '$m:$s';
    // Warning after 10min, critical after 20min
    final color = elapsed.inMinutes >= 20
        ? AppColors.error
        : elapsed.inMinutes >= 10
            ? AppColors.warning
            : Colors.orange.shade300;
    final label = elapsed.inMinutes >= 20 ? '$text STUCK' : text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          elapsed.inMinutes >= 20 ? Icons.warning_amber : Icons.timer_outlined,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
