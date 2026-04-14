import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/automation_model.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../theme.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> with WidgetsBindingObserver {
  List<AutomationModel> _automations = [];
  bool _loading = false;
  String? _error;
  Timer? _pollTimer;
  bool _appInForeground = true;
  bool _resetting = false;
  static const _myTabIndex = 2;

  // Filters (app category uses same SharedPreferences keys as issues screen)
  String _appCategory = 'in_progress';
  Set<int> _completedAppIds = {};
  static const _completedAppsKey = 'completed_app_ids';
  Set<int> _postponedAppIds = {};
  static const _postponedAppsKey = 'postponed_app_ids';
  String _statusFilter = 'all'; // all, running, stopped

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      await _loadAppCategories();
      _loadAutomations();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || !_appInForeground) return;
      if (context.read<AppState>().activeTabIndex != _myTabIndex) return;
      _loadAutomations(silent: true);
    });
  }

  Future<void> _loadAppCategories() async {
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

  List<AutomationModel> get _filteredAutomations {
    var list = _automations;

    // Filter by app category
    if (_appCategory == 'completed') {
      list = list.where((a) => _completedAppIds.contains(a.appId)).toList();
    } else if (_appCategory == 'postponed') {
      list = list.where((a) => _postponedAppIds.contains(a.appId) && !_completedAppIds.contains(a.appId)).toList();
    } else {
      // in_progress: exclude both completed and postponed
      list = list.where((a) => !_completedAppIds.contains(a.appId) && !_postponedAppIds.contains(a.appId)).toList();
    }

    // Filter by running status
    if (_statusFilter == 'running') {
      list = list.where((a) => a.running).toList();
    } else if (_statusFilter == 'stopped') {
      list = list.where((a) => !a.running).toList();
    }

    return list;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
  }

  Future<void> _loadAutomations({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    final result = await ApiService.getAutomations();
    if (mounted) {
      if (result.ok) {
        var automations = result.data!;
        // Fetch per-app MCP servers for automations missing them
        final needsMcp = automations.where((a) => a.mcpServers.isEmpty).toList();
        if (needsMcp.isNotEmpty) {
          final uniqueAppIds = needsMcp.map((a) => a.appId).toSet();
          final mcpFutures = <int, Future<ApiResult<List<String>>>>{};
          for (final appId in uniqueAppIds) {
            mcpFutures[appId] = ApiService.getAppMcp(appId);
          }
          final mcpResults = <int, List<String>>{};
          for (final entry in mcpFutures.entries) {
            final r = await entry.value;
            if (r.ok && r.data != null && r.data!.isNotEmpty) {
              mcpResults[entry.key] = r.data!;
            }
          }
          if (mcpResults.isNotEmpty) {
            automations = automations.map((a) {
              if (a.mcpServers.isEmpty && mcpResults.containsKey(a.appId)) {
                return a.copyWith(mcpServers: mcpResults[a.appId]);
              }
              return a;
            }).toList();
          }
        }
        setState(() {
          _automations = automations;
          _error = null;
          _loading = false;
        });
      } else {
        setState(() {
          if (_automations.isEmpty) {
            _error = result.error ?? 'Failed to load automations';
          }
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleAutomation(AutomationModel auto) async {
    HapticFeedback.lightImpact();
    final result = auto.running
        ? await ApiService.stopAutomation(auto.appId)
        : await ApiService.startAutomation(auto.appId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.ok
              ? '${auto.appName} ${auto.running ? "stopped" : "started"}'
              : result.error ?? 'Failed'),
          backgroundColor: result.ok ? AppColors.success : AppColors.error,
        ),
      );
      if (result.ok) _loadAutomations();
    }
  }

  Future<bool> _runOnceAutomation(AutomationModel auto) async {
    final result = await ApiService.runOnceAutomation(auto.appId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.ok
              ? '${auto.appName} one-time run triggered'
              : result.error ?? 'Failed to trigger run'),
          backgroundColor: result.ok ? AppColors.success : AppColors.error,
        ),
      );
      if (result.ok) _loadAutomations(silent: true);
    }
    return result.ok;
  }

  Future<void> _deleteAutomation(AutomationModel auto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Delete Automation'),
        content: Text('Remove automation for ${auto.appName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    HapticFeedback.mediumImpact();
    final result = await ApiService.deleteAutomation(auto.appId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.ok ? 'Deleted' : result.error ?? 'Failed to delete'),
          backgroundColor: result.ok ? AppColors.success : AppColors.error,
        ),
      );
      if (result.ok) _loadAutomations();
    }
  }

  Future<void> _resetServer() async {
    if (_resetting) return;
    final runningAutomations = _automations.where((a) => a.running).toList();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Reset Server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will restart the backend server.'),
            if (runningAutomations.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${runningAutomations.length} running automation(s) will be stopped first to prevent auto-restart.',
                style: TextStyle(color: AppColors.warning, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _resetting = true);
    try {
      // Stop all running automations before reset to prevent auto-restart
      if (runningAutomations.isNotEmpty) {
        for (final auto in runningAutomations) {
          await ApiService.stopAutomation(auto.appId);
        }
      }

      final result = await ApiService.resetServer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.ok ? result.data! : result.error!),
            backgroundColor: result.ok ? AppColors.success : AppColors.error,
          ),
        );
        if (result.ok) _loadAutomations();
      }
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  void _showGddSheet(int appId, String appName) {
    final gddController = TextEditingController();
    bool loading = true;
    bool saving = false;
    bool loadStarted = false;
    String? loadError;

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
            if (loading && !loadStarted) {
              loadStarted = true;
              ApiService.getGdd(appId).then((result) {
                if (ctx.mounted) {
                  setSheetState(() {
                    if (result.ok) {
                      gddController.text = result.data!;
                      loadError = null;
                    } else {
                      loadError = result.error;
                    }
                    loading = false;
                  });
                }
              });
            }
            final mq = MediaQuery.of(ctx);
            final hasError = loadError != null;
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: mq.viewInsets.bottom + mq.padding.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Design Doc - $appName',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('The AI will use this as context for all work on this app.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  const SizedBox(height: 12),
                  if (loading)
                    const Center(child: CircularProgressIndicator())
                  else if (hasError)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Text('Failed to load: $loadError',
                              style: const TextStyle(color: AppColors.error)),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              setSheetState(() {
                                loading = true;
                                loadStarted = false;
                                loadError = null;
                              });
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    TextField(
                      controller: gddController,
                      maxLines: 10,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Describe your app vision, features, goals...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${gddController.text.length} characters',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: FilledButton.icon(
                      onPressed: (saving || loading || hasError) ? null : () async {
                        if (gddController.text.trim().isEmpty) {
                          final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (d) => AlertDialog(
                              title: const Text('Save empty GDD?'),
                              content: const Text('This will erase the current design document.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save')),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                        }
                        setSheetState(() => saving = true);
                        final result = await ApiService.updateGdd(
                            appId, gddController.text);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(result.ok ? 'Design doc saved' : result.error ?? 'Failed'),
                            backgroundColor: result.ok ? AppColors.success : AppColors.error));
                        }
                      },
                      icon: saving
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(saving ? 'Saving...' : 'Save'),
                    ),
                  ),
                ],
                ),
              );
          },
        );
      },
    ).whenComplete(() {
      gddController.dispose();
    });
  }

  void _showCreateSheet() {
    final allApps = context.read<AppState>().apps;
    // Filter out apps that already have an automation
    final existingAppIds = _automations.map((a) => a.appId).toSet();
    final apps = allApps.where((a) => !existingAppIds.contains(a.id)).toList();
    int? selectedAppId;
    String? selectedAppName;
    String aiAgent = 'claude';
    int intervalMinutes = 10;
    int maxSessionMinutes = 18;
    final promptController = TextEditingController();
    final searchController = TextEditingController();
    bool submitting = false;
    bool fullAuto = true;
    String searchQuery = '';
    // MCP servers are configured per-app on the app detail page

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
            final filtered = searchQuery.isEmpty
                ? apps
                : apps.where((a) => a.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: mq.viewInsets.bottom + mq.padding.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('New Automation',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    // App selector with search
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: selectedAppName ?? 'Search apps...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: selectedAppId != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setSheetState(() {
                                  selectedAppId = null;
                                  selectedAppName = null;
                                  searchController.clear();
                                  searchQuery = '';
                                }),
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (v) => setSheetState(() {
                        searchQuery = v;
                        if (selectedAppId != null) {
                          selectedAppId = null;
                          selectedAppName = null;
                        }
                      }),
                    ),
                    if (selectedAppId == null) ...[
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: filtered.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  apps.isEmpty ? 'All apps already have automations' : 'No apps match',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                itemBuilder: (_, i) {
                                  final app = filtered[i];
                                  return ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    title: Text(app.name, style: const TextStyle(fontSize: 14)),
                                    subtitle: Text(app.appType, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                    onTap: () => setSheetState(() {
                                      selectedAppId = app.id;
                                      selectedAppName = app.name;
                                      searchController.clear();
                                      searchQuery = '';
                                    }),
                                  );
                                },
                              ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text('AI Agent', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['claude', 'gemini', 'codex', 'local'].map((agent) {
                        final selected = agent == aiAgent;
                        return ChoiceChip(
                          label: Text(agent[0].toUpperCase() + agent.substring(1)),
                          selected: selected,
                          selectedColor: AppColors.agentColor(agent),
                          onSelected: (sel) {
                            if (sel) setSheetState(() => aiAgent = agent);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Text('Interval (min): '),
                      Expanded(child: Slider(
                        value: intervalMinutes.toDouble(), min: 5, max: 60,
                        divisions: 11, label: '$intervalMinutes',
                        onChanged: (v) => setSheetState(() => intervalMinutes = v.round()),
                      )),
                      Text('$intervalMinutes'),
                    ]),
                    Row(children: [
                      const Text('Max session (min): '),
                      Expanded(child: Slider(
                        value: maxSessionMinutes.toDouble(), min: 5, max: 60,
                        divisions: 11, label: '$maxSessionMinutes',
                        onChanged: (v) => setSheetState(() => maxSessionMinutes = v.round()),
                      )),
                      Text('$maxSessionMinutes'),
                    ]),
                    const SizedBox(height: 12),
                    // Full Auto toggle
                    SwitchListTile(
                      title: const Text('Full Auto Mode'),
                      subtitle: Text(fullAuto
                          ? 'AI reads tasks, fixes, generates new ideas, repeats'
                          : 'Custom prompt',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                      value: fullAuto,
                      thumbColor: WidgetStateProperty.resolveWith((states) =>
                          states.contains(WidgetState.selected) ? AppColors.accent : null),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setSheetState(() => fullAuto = v),
                    ),
                    if (!fullAuto) ...[
                      TextField(
                        controller: promptController, maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Custom automation prompt...', alignLabelWithHint: true),
                      ),
                    ],
                    // MCP servers are set per-app on the app detail page
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 48,
                      child: FilledButton.icon(
                        onPressed: submitting ? null : () async {
                          if (selectedAppId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Select an app'),
                                backgroundColor: AppColors.warning));
                            return;
                          }
                          setSheetState(() => submitting = true);
                          final result = await ApiService.createAutomation(
                            appId: selectedAppId!, aiAgent: aiAgent,
                            intervalMinutes: intervalMinutes,
                            maxSessionMinutes: maxSessionMinutes,
                            prompt: fullAuto ? '' : promptController.text.trim(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(result.ok ? 'Automation created' : result.error ?? 'Failed'),
                              backgroundColor: result.ok ? AppColors.success : AppColors.error));
                            if (result.ok) _loadAutomations();
                          }
                        },
                        icon: submitting
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add),
                        label: Text(submitting ? 'Creating...' : 'Create'),
                      ),
                    ),
                  ],
                ),
              );
          },
        );
      },
    ).whenComplete(() {
      promptController.dispose();
      searchController.dispose();
    });
  }

  void _showEditSheet(AutomationModel auto) {
    String aiAgent = auto.aiAgent;
    int intervalMinutes = auto.intervalMinutes;
    int maxSessionMinutes = auto.maxSessionMinutes;
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
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: mq.viewInsets.bottom + mq.padding.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit: ${auto.appName}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('AI Agent', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['claude', 'gemini', 'codex', 'local'].map((agent) {
                      final selected = agent == aiAgent;
                      return ChoiceChip(
                        label: Text(agent[0].toUpperCase() + agent.substring(1)),
                        selected: selected,
                        selectedColor: AppColors.agentColor(agent),
                        onSelected: (sel) {
                          if (sel) setSheetState(() => aiAgent = agent);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Text('Interval (min): '),
                    Expanded(child: Slider(
                      value: intervalMinutes.toDouble(), min: 5, max: 60,
                      divisions: 11, label: '$intervalMinutes',
                      onChanged: (v) => setSheetState(() => intervalMinutes = v.round()),
                    )),
                    Text('$intervalMinutes'),
                  ]),
                  Row(children: [
                    const Text('Max session (min): '),
                    Expanded(child: Slider(
                      value: maxSessionMinutes.toDouble(), min: 5, max: 60,
                      divisions: 11, label: '$maxSessionMinutes',
                      onChanged: (v) => setSheetState(() => maxSessionMinutes = v.round()),
                    )),
                    Text('$maxSessionMinutes'),
                  ]),
                  const SizedBox(height: 8),
                  Text('MCP servers are configured per-app on the app detail page.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: FilledButton.icon(
                      onPressed: submitting ? null : () async {
                        setSheetState(() => submitting = true);
                        final result = await ApiService.updateAutomation(
                          appId: auto.appId,
                          aiAgent: aiAgent,
                          intervalMinutes: intervalMinutes,
                          maxSessionMinutes: maxSessionMinutes,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(result.ok ? 'Automation updated' : result.error ?? 'Failed'),
                            backgroundColor: result.ok ? AppColors.success : AppColors.error));
                          if (result.ok) _loadAutomations();
                        }
                      },
                      icon: submitting
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(submitting ? 'Saving...' : 'Save Changes'),
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAutomations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Control'),
        actions: [
          IconButton(
            icon: _resetting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.restart_alt),
            tooltip: 'Reset Server',
            onPressed: _resetting ? null : _resetServer,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAutomations),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateSheet, child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _automations.isEmpty
              ? RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: _loadAutomations,
                  child: ListView(children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade600),
                          const SizedBox(height: 16),
                          Text(_error!, style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadAutomations,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ]),
                )
              : Column(
                  children: [
                    // App category segmented button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'in_progress',
                            label: Text('In Progress'),
                            icon: Icon(Icons.code, size: 18),
                          ),
                          ButtonSegment(
                            value: 'postponed',
                            label: Text('Postponed'),
                            icon: Icon(Icons.pause_circle_outline, size: 18),
                          ),
                          ButtonSegment(
                            value: 'completed',
                            label: Text('Completed'),
                            icon: Icon(Icons.check_circle_outline, size: 18),
                          ),
                        ],
                        selected: {_appCategory},
                        onSelectionChanged: (selection) {
                          setState(() => _appCategory = selection.first);
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
                    // Status filter chips
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: ['all', 'running', 'stopped'].map((status) {
                            final selected = _statusFilter == status;
                            final color = status == 'running'
                                ? AppColors.success
                                : status == 'stopped'
                                    ? Colors.grey
                                    : AppColors.accent;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(status[0].toUpperCase() + status.substring(1)),
                                selected: selected,
                                selectedColor: color.withValues(alpha: 0.3),
                                checkmarkColor: color,
                                side: BorderSide(
                                  color: selected ? color : Colors.grey.shade700,
                                ),
                                onSelected: (_) {
                                  setState(() => _statusFilter = selected ? 'all' : status);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    // Automation list
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.accent,
                        onRefresh: _loadAutomations,
                        child: filtered.isEmpty
                            ? ListView(children: [
                                const SizedBox(height: 80),
                                Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        _automations.isEmpty ? Icons.smart_toy_outlined : Icons.filter_alt_off,
                                        size: 48,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _automations.isEmpty
                                            ? 'No automations yet'
                                            : 'No automations match filters',
                                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _automations.isEmpty
                                            ? 'Tap + to create your first automation'
                                            : 'Try changing the category or status filter',
                                        style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ])
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final auto = filtered[index];
                                  return _AutomationCard(
                                    key: ValueKey(auto.appId),
                                    automation: auto,
                                    agentColor: AppColors.agentColor(auto.aiAgent),
                                    onToggle: () => _toggleAutomation(auto),
                                    onRunOnce: () => _runOnceAutomation(auto),
                                    onDelete: () => _deleteAutomation(auto),
                                    onGdd: () => _showGddSheet(auto.appId, auto.appName),
                                    onEdit: () => _showEditSheet(auto),
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

class _AutomationCard extends StatefulWidget {
  final AutomationModel automation;
  final Color agentColor;
  final VoidCallback onToggle;
  final Future<bool> Function() onRunOnce;
  final VoidCallback onDelete;
  final VoidCallback onGdd;
  final VoidCallback onEdit;

  const _AutomationCard({
    super.key,
    required this.automation, required this.agentColor,
    required this.onToggle, required this.onRunOnce,
    required this.onDelete, required this.onGdd,
    required this.onEdit,
  });

  @override
  State<_AutomationCard> createState() => _AutomationCardState();
}

class _AutomationCardState extends State<_AutomationCard> {
  Timer? _tickTimer;
  DateTime? _cycleStart;
  bool _oneShotActive = false;
  DateTime? _oneShotStart;
  bool _runOnceLoading = false;

  String get _cycleKey => 'auto_cycle_${widget.automation.appId}';
  String get _oneShotKey => 'auto_oneshot_${widget.automation.appId}';

  @override
  void initState() {
    super.initState();
    _restorePersistedState();
  }

  Future<void> _restorePersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final auto = widget.automation;

    if (auto.running) {
      // Use server-provided startedAt, then SharedPreferences, then now()
      _cycleStart = auto.startedAt;
      if (_cycleStart == null) {
        final saved = prefs.getString(_cycleKey);
        if (saved != null) _cycleStart = DateTime.tryParse(saved);
      }
      _cycleStart ??= DateTime.now();
      prefs.setString(_cycleKey, _cycleStart!.toIso8601String());
    } else {
      prefs.remove(_cycleKey);
      // Restore one-shot state if not in loop mode
      final saved = prefs.getString(_oneShotKey);
      if (saved != null) {
        final t = DateTime.tryParse(saved);
        if (t != null) {
          final elapsed = DateTime.now().difference(t);
          if (elapsed.inMinutes < auto.maxSessionMinutes) {
            _oneShotActive = true;
            _oneShotStart = t;
          } else {
            prefs.remove(_oneShotKey);
          }
        }
      }
    }

    if (mounted) {
      setState(() {});
      _syncTimer();
    }
  }

  @override
  void didUpdateWidget(_AutomationCard old) {
    super.didUpdateWidget(old);
    if (old.automation.running != widget.automation.running) {
      if (widget.automation.running) {
        _oneShotActive = false;
        _oneShotStart = null;
        _clearPref(_oneShotKey);
        // Use server time or keep existing
        if (widget.automation.startedAt != null) {
          _cycleStart = widget.automation.startedAt;
        }
        _cycleStart ??= DateTime.now();
        _savePref(_cycleKey, _cycleStart!);
      } else {
        _cycleStart = null;
        _clearPref(_cycleKey);
      }
      _syncTimer();
    }
  }

  Future<void> _savePref(String key, DateTime value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(key, value.toIso8601String());
  }

  Future<void> _clearPref(String key) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(key);
  }

  void _syncTimer() {
    final needsTimer = widget.automation.running || _oneShotActive;
    if (needsTimer) {
      if (widget.automation.running) {
        _cycleStart ??= DateTime.now();
      }
      if (_tickTimer == null || !_tickTimer!.isActive) {
        _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          // Auto-expire one-shot countdown
          if (_oneShotActive && _oneShotStart != null) {
            final elapsed = DateTime.now().difference(_oneShotStart!);
            if (elapsed.inMinutes >= widget.automation.maxSessionMinutes) {
              _oneShotActive = false;
              _oneShotStart = null;
              _clearPref(_oneShotKey);
            }
          }
          setState(() {});
          // Cancel timer if nothing needs it anymore
          if (!widget.automation.running && !_oneShotActive) {
            _tickTimer?.cancel();
            _tickTimer = null;
          }
        });
      }
    } else {
      _tickTimer?.cancel();
      _tickTimer = null;
      _cycleStart = null;
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    if (d.isNegative) return '00:00';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final auto = widget.automation;
    final agentColor = widget.agentColor;

    // Compute countdown phase
    String? phaseLabel;
    Duration? remaining;
    bool isSleepPhase = false;
    double? phaseProgress;

    if (auto.running && _cycleStart != null) {
      final elapsed = DateTime.now().difference(_cycleStart!);
      final sessionDur = Duration(minutes: auto.maxSessionMinutes);
      final sleepDur = Duration(minutes: auto.intervalMinutes);
      final totalCycle = sessionDur + sleepDur;
      final pos = Duration(seconds: elapsed.inSeconds % totalCycle.inSeconds);

      if (pos < sessionDur) {
        remaining = sessionDur - pos;
        phaseLabel = 'Session ends in';
        isSleepPhase = false;
        phaseProgress = pos.inSeconds / sessionDur.inSeconds;
      } else {
        remaining = totalCycle - pos;
        phaseLabel = 'Next run in';
        isSleepPhase = true;
        phaseProgress = (pos - sessionDur).inSeconds / sleepDur.inSeconds;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 12, height: 12,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: auto.running ? AppColors.success : Colors.grey)),
              const SizedBox(width: 10),
              Expanded(child: Text(auto.appName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: agentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(auto.aiAgent.toUpperCase(),
                  style: TextStyle(fontSize: 11, color: agentColor, fontWeight: FontWeight.w700)),
              ),
              if (auto.mcpServers.isNotEmpty) ...[
                const SizedBox(width: 6),
                Icon(Icons.hub, size: 14, color: Colors.grey.shade400),
              ],
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.timer, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text('Every ${auto.intervalMinutes}m',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              const SizedBox(width: 16),
              Icon(Icons.hourglass_bottom, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text('Max ${auto.maxSessionMinutes}m',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ]),
            if (auto.mcpServers.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: auto.mcpServers.map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hub, size: 11, color: Colors.purple.shade200),
                      const SizedBox(width: 4),
                      Text(s, style: TextStyle(fontSize: 11, color: Colors.purple.shade200)),
                    ],
                  ),
                )).toList(),
              ),
            ],
            // Countdown timer row (loop mode)
            if (auto.running && phaseLabel != null && remaining != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isSleepPhase ? AppColors.info : AppColors.warning)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(
                        isSleepPhase ? Icons.bedtime : Icons.play_circle,
                        size: 16,
                        color: isSleepPhase ? AppColors.info : AppColors.warning,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        phaseLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSleepPhase ? AppColors.info : AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _fmt(remaining),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: isSleepPhase ? AppColors.info : AppColors.warning,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: phaseProgress ?? 0,
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        color: isSleepPhase ? AppColors.info : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // One-shot countdown timer
            if (_oneShotActive && _oneShotStart != null && !auto.running) ...[
              () {
                final elapsed = DateTime.now().difference(_oneShotStart!);
                final sessionDur = Duration(minutes: auto.maxSessionMinutes);
                final oneShotRemaining = sessionDur - elapsed;
                final progress = (elapsed.inSeconds / sessionDur.inSeconds).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.bolt, size: 16, color: AppColors.warning),
                          const SizedBox(width: 6),
                          const Text(
                            'One-shot run ends in',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _fmt(oneShotRemaining),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: AppColors.warning,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }(),
            ],
            if (auto.promptPreview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(auto.promptPreview, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              FilledButton.icon(
                onPressed: widget.onToggle,
                style: FilledButton.styleFrom(
                  backgroundColor: auto.running ? AppColors.error : AppColors.success,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                icon: Icon(auto.running ? Icons.stop : Icons.play_arrow, size: 18),
                label: Text(auto.running ? 'Stop' : 'Start',
                  style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 4),
              _runOnceLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning),
                    )
                  : IconButton(
                onPressed: () async {
                  if (_oneShotActive) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.bgCard,
                        title: const Text('Run Again?'),
                        content: const Text(
                          'A one-shot run is already in progress but the AI may have stopped early. Trigger another run?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.warning),
                            child: const Text('Run Anyway'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                  }
                  HapticFeedback.lightImpact();
                  setState(() => _runOnceLoading = true);
                  final ok = await widget.onRunOnce();
                  if (mounted) {
                    setState(() => _runOnceLoading = false);
                    if (ok) {
                      final now = DateTime.now();
                      setState(() {
                        _oneShotActive = true;
                        _oneShotStart = now;
                      });
                      _savePref(_oneShotKey, now);
                      _syncTimer();
                    }
                  }
                },
                icon: Icon(Icons.bolt,
                  color: _oneShotActive ? AppColors.warning.withValues(alpha: 0.5) : AppColors.warning),
                iconSize: 20, tooltip: _oneShotActive ? 'Run Once (in progress)' : 'Run Once'),
              IconButton(onPressed: () { HapticFeedback.lightImpact(); widget.onEdit(); },
                icon: const Icon(Icons.edit_outlined, color: AppColors.accent),
                iconSize: 20, tooltip: 'Edit'),
              IconButton(onPressed: widget.onGdd,
                icon: const Icon(Icons.description_outlined, color: AppColors.info),
                iconSize: 20, tooltip: 'Design Doc'),
              IconButton(onPressed: () { HapticFeedback.mediumImpact(); widget.onDelete(); },
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                iconSize: 20, tooltip: 'Delete'),
            ]),
          ],
        ),
      ),
    );
  }
}
