import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_model.dart';
import '../models/build_model.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../theme.dart';
import '../widgets/app_build_card.dart';
import '../widgets/app_detail/mcp_servers_section.dart';

class AppDetailScreen extends StatefulWidget {
  final int appId;

  const AppDetailScreen({super.key, required this.appId});

  @override
  State<AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends State<AppDetailScreen> {
  AppModel? _app;
  List<BuildModel> _builds = [];
  bool _loading = true;
  String? _loadError;
  String _selectedStrategy = '';
  String? _gddContent;
  bool _gddLoading = true;
  String? _gddError;
  String? _claudeMdContent;
  bool _claudeMdLoading = true;
  String? _claudeMdError;
  bool _gddEnhancing = false;
  bool _claudeMdEnhancing = false;
  Timer? _enhanceTimer;
  Map<String, dynamic>? _deployStatus;

  // MCP
  List<dynamic> _mcpPresets = [];
  Set<String> _appMcpServers = {};
  bool _mcpLoading = true;

  static const List<String> _aiAgents = ['', 'claude', 'gemini', 'codex', 'local'];
  static const Map<String, String> _aiLabels = {
    '': 'None',
    'claude': 'Claude',
    'gemini': 'Gemini',
    'codex': 'Codex',
    'local': 'Local',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _enhanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Cache-first: hydrate from local Hive before any network call so the
    // screen never blanks out on cold open. Anything the cache doesn't have
    // (deploy/MCP state, fresh app row, tasks) still waits on the network,
    // but the user sees the docs + builds + app info instantly.
    final cache = CacheService.instance;
    final cachedApp =
        cache.getApps().where((a) => a.id == widget.appId).firstOrNull;
    final cachedBuilds = cache.getBuilds(appId: widget.appId);
    final cachedGdd = cache.getGdd(widget.appId);
    final cachedClaudeMd = cache.getClaudeMd(widget.appId);

    setState(() {
      _loadError = null;
      if (cachedApp != null) {
        _app = cachedApp;
        _selectedStrategy = cachedApp.fixStrategy;
      }
      if (cachedBuilds.isNotEmpty) {
        _builds = cachedBuilds;
      }
      if (cachedGdd != null) {
        _gddContent = cachedGdd;
        _gddLoading = false;
      }
      if (cachedClaudeMd != null) {
        _claudeMdContent = cachedClaudeMd;
        _claudeMdLoading = false;
      }
      // Only block the whole screen on the spinner when there's literally
      // nothing to show; otherwise let the cached render stand while the
      // network fills in the rest.
      _loading = _app == null;
    });

    final results = await Future.wait([
      ApiService.getApp(widget.appId),
      ApiService.getBuilds(appId: widget.appId),
      ApiService.getGdd(widget.appId),
      ApiService.getDeployStatus(widget.appId),
      ApiService.getMcpPresets(),
      ApiService.getAppMcp(widget.appId),
      ApiService.getClaudeMd(widget.appId),
    ]);

    final appResult = results[0] as ApiResult<AppModel>;
    final buildsResult = results[1] as ApiResult<List<BuildModel>>;
    final gddResult = results[2] as ApiResult<String>;
    final deployResult = results[3] as ApiResult<Map<String, dynamic>>;
    final presetsResult = results[4] as ApiResult<List<dynamic>>;
    final appMcpResult = results[5] as ApiResult<List<String>>;
    final claudeMdResult = results[6] as ApiResult<String>;

    if (!mounted) return;

    // Fatal only if the main app request failed AND we had nothing cached
    // to fall back to. With a cached app, a transient network blip should
    // leave the previous render intact.
    if (!appResult.ok && cachedApp == null) {
      setState(() {
        _loadError = appResult.error ?? 'Failed to load app';
        _loading = false;
      });
      return;
    }

    final freshBuilds = buildsResult.data;
    if (freshBuilds != null) {
      await cache.saveBuilds(
          freshBuilds.map((b) => b.toJson()).toList());
    }
    if (gddResult.ok) {
      await cache.setGdd(widget.appId, gddResult.data ?? '');
    }
    if (claudeMdResult.ok) {
      await cache.setClaudeMd(widget.appId, claudeMdResult.data ?? '');
    }

    if (!mounted) return;
    setState(() {
      final app = appResult.data ?? cachedApp;
      _app = app;
      if (freshBuilds != null) {
        _builds = freshBuilds;
      }
      if (gddResult.ok) {
        _gddContent = gddResult.data;
        _gddError = null;
      } else if (_gddContent == null) {
        _gddError = gddResult.error;
      }
      _gddLoading = false;
      if (claudeMdResult.ok) {
        _claudeMdContent = claudeMdResult.data;
        _claudeMdError = null;
      } else if (_claudeMdContent == null) {
        _claudeMdError = claudeMdResult.error;
      }
      _claudeMdLoading = false;
      _loading = false;
      if (app != null) {
        _selectedStrategy = app.fixStrategy;
      }
      _deployStatus = deployResult.data;
      _mcpPresets = presetsResult.data ?? [];
      _appMcpServers = Set<String>.from(appMcpResult.data ?? []);
      _mcpLoading = false;
    });
  }

  Future<void> _saveStrategy(String strategy) async {
    if (_app == null) return;
    final result = await ApiService.updateApp(
      _app!.id,
      {'fix_strategy': strategy},
    );
    if (mounted) {
      if (result.ok) {
        setState(() => _selectedStrategy = strategy);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI agent updated'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to update AI agent'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showQuickIssueSheet() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    bool submitting = false;

    showModalBottomSheet<void>(
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
                    const Text('Quick Issue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(controller: titleController, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'Issue title', prefixIcon: Icon(Icons.title))),
                    const SizedBox(height: 12),
                    TextField(controller: descController, maxLines: 3, textInputAction: TextInputAction.newline, decoration: const InputDecoration(hintText: 'Description...')),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 48,
                      child: FilledButton.icon(
                        onPressed: submitting ? null : () async {
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;
                          setSheetState(() => submitting = true);
                          final result = await ApiService.createAppTask(appId: widget.appId, title: title, description: descController.text.trim());
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            if (result.ok) HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.ok ? 'Issue created' : result.error ?? 'Failed'), backgroundColor: result.ok ? AppColors.success : AppColors.error));
                            if (result.ok) _loadData();
                          }
                        },
                        icon: submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                        label: Text(submitting ? 'Creating...' : 'Create Issue'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      titleController.dispose();
      descController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_app?.name ?? 'App Detail'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickIssueSheet(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _app == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade600),
                      const SizedBox(height: 16),
                      Text(
                        _loadError ?? 'Failed to load app',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 16),
                      if (_app!.appType.toLowerCase() == 'flutter' ||
                          _app!.appType.toLowerCase() == 'godot' ||
                          _app!.appType.toLowerCase() == 'phaser')
                        AppBuildCard(
                          appId: widget.appId,
                          appType: _app!.appType,
                          initialDeployStatus: _deployStatus,
                          onDataReload: _loadData,
                        ),
                      if (_app!.appType.toLowerCase() == 'python')
                        _buildPythonCard(),
                      if (_app!.appType.toLowerCase() == 'web')
                        _buildWebDeployCard(),
                      const SizedBox(height: 16),
                      _buildAiAgentCard(),
                      const SizedBox(height: 16),
                      McpServersSection(
                        appId: widget.appId,
                        initialEnabled: _appMcpServers,
                        initialPresets: _mcpLoading ? null : _mcpPresets,
                        onChanged: (enabled) {
                          setState(() => _appMcpServers = enabled);
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildClaudeMdCard(),
                      const SizedBox(height: 16),
                      _buildGddCard(),
                      const SizedBox(height: 16),
                      _buildBuildsSection(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPythonCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.terminal, color: AppColors.accent),
                    SizedBox(width: 8),
                    Text('Python', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _triggerServerAction('run'),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Run'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Run scripts and manage the Python project via the server.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebDeployCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.web, color: AppColors.accent),
                    SizedBox(width: 8),
                    Text('Web Deploy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _triggerServerAction('deploy'),
                  icon: const Icon(Icons.cloud_upload, size: 18),
                  label: const Text('Deploy'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Build and deploy the web app via the server.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerServerAction(String action) async {
    final result = await ApiService.sendDeathpinDirective(action, 'normal');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.ok ? '${action[0].toUpperCase()}${action.substring(1)} triggered' : result.error ?? 'Failed to trigger $action'),
        backgroundColor: result.ok ? AppColors.success : AppColors.error,
      ));
    }
  }

  Widget _buildInfoCard() {
    if (_app == null) return const SizedBox.shrink();
    final app = _app!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  AppColors.appTypeIcon(app.appType),
                  color: AppColors.accent,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        app.slug,
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _infoChip('Version', 'v${app.currentVersion}', AppColors.info),
                const SizedBox(width: 8),
                _infoChip('Type', app.appType, Colors.grey),
                const SizedBox(width: 8),
                _infoChip(
                  'Status',
                  app.status,
                  AppColors.statusColor(app.status),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (app.appType.toLowerCase() == 'flutter') ...[
                  _infoChip(
                    'Publish',
                    app.publishStatus.isNotEmpty ? app.publishStatus : 'N/A',
                    app.publishStatus == 'published'
                        ? AppColors.success
                        : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                ],
                Builder(builder: (_) {
                  final counts = app.taskStatus;
                  final openCount =
                      (counts['pending'] ?? 0) + (counts['in_progress'] ?? 0);
                  return _infoChip(
                    'Issues',
                    '$openCount open',
                    openCount > 0 ? AppColors.accent : AppColors.success,
                  );
                }),
              ],
            ),
            const Divider(height: 24),
            _editableField(
              icon: Icons.inventory_2_outlined,
              label: 'Package Name',
              value: app.packageName,
              field: 'package_name',
              hint: 'com.example.app',
            ),
            const SizedBox(height: 8),
            _editableField(
              icon: Icons.folder_outlined,
              label: 'Project Path',
              value: app.projectPath,
              field: 'project_path',
              hint: 'C:/MyProject',
            ),
            const Divider(height: 24),
            _buildLinksRow(app),
          ],
        ),
      ),
    );
  }

  Widget _buildLinksRow(AppModel app) {
    // Auto-generate Play Store & Console URLs from package_name if not set
    final pkg = app.packageName;
    final playStore = app.playStoreUrl.isNotEmpty
        ? app.playStoreUrl
        : (pkg.isNotEmpty ? 'https://play.google.com/store/apps/details?id=$pkg' : '');
    final console = app.consoleUrl.isNotEmpty
        ? app.consoleUrl
        : '';

    final links = <_LinkInfo>[
      _LinkInfo(Icons.code, 'GitHub', app.githubUrl, 'github_url', 'https://github.com/user/repo'),
      _LinkInfo(Icons.store, 'Play Store', playStore, 'play_store_url', 'https://play.google.com/store/apps/details?id=...'),
      _LinkInfo(Icons.admin_panel_settings, 'Console', console, 'console_url', 'https://play.google.com/console/...'),
      _LinkInfo(Icons.language, 'Website', app.websiteUrl, 'website_url', 'https://example.com'),
    ];

    final hasAnyLink = links.any((l) => l.value.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.link, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Text('Links', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: links.map((link) {
            final hasUrl = link.value.isNotEmpty;
            return Material(
              color: hasUrl ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bgDark,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: hasUrl
                    ? () => _openUrl(link.value)
                    : () => _showEditFieldSheet(link.label, link.value, link.field, link.hint),
                onLongPress: () => _showEditFieldSheet(link.label, link.value, link.field, link.hint),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasUrl ? AppColors.accent.withValues(alpha: 0.4) : Colors.grey.shade700,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(link.icon, size: 16,
                          color: hasUrl ? AppColors.accent : Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(link.label, style: TextStyle(fontSize: 13,
                          color: hasUrl ? AppColors.accent : Colors.grey.shade600)),
                      if (!hasUrl) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.add, size: 14, color: Colors.grey.shade600),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (!hasAnyLink)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Tap to add, long-press to edit',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Tap to open, long-press to edit',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    var uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!uri.hasScheme) {
      uri = Uri.parse('https://$url');
    }
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      debugPrint('Failed to launch URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _editableField({
    required IconData icon,
    required String label,
    required String value,
    required String field,
    String hint = '',
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showEditFieldSheet(label, value, field, hint),
      onLongPress: value.isNotEmpty ? () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label copied to clipboard'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.info,
          ),
        );
        HapticFeedback.lightImpact();
      } : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey.shade500),
              const SizedBox(width: 10),
              Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              Expanded(
                child: Text(
                  value.isNotEmpty ? value : '(not set)',
                  style: TextStyle(
                    fontSize: 13,
                    color: value.isNotEmpty ? Colors.grey.shade200 : Colors.grey.shade600,
                    fontStyle: value.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.edit, size: 14, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditFieldSheet(String label, String currentValue, String field, String hint) {
    final controller = TextEditingController(text: currentValue);
    bool saving = false;

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit $label', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(hintText: hint),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: FilledButton(
                      onPressed: saving ? null : () async {
                        final newValue = controller.text.trim();
                        if (newValue == currentValue) {
                          Navigator.pop(ctx);
                          return;
                        }
                        setSheetState(() => saving = true);
                        final result = await ApiService.updateApp(widget.appId, {field: newValue});
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          if (result.ok) _loadData();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(result.ok ? '$label updated' : result.error ?? 'Failed to update'),
                            backgroundColor: result.ok ? AppColors.success : AppColors.error,
                          ));
                        }
                      },
                      child: Text(saving ? 'Saving...' : 'Save'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() => controller.dispose());
  }

  Widget _infoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAgentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_toy, color: AppColors.accent),
                const SizedBox(width: 8),
                const Text(
                  'AI Agent',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: _aiAgents.map((agent) {
                return ButtonSegment<String>(
                  value: agent,
                  label: Text(_aiLabels[agent] ?? agent),
                  icon: agent == 'claude'
                      ? const Icon(Icons.auto_awesome, size: 18)
                      : agent == 'gemini'
                          ? const Icon(Icons.diamond, size: 18)
                          : agent == 'codex'
                              ? const Icon(Icons.code, size: 18)
                              : agent == 'local'
                                  ? const Icon(Icons.computer, size: 18)
                                  : const Icon(Icons.block, size: 18),
                );
              }).toList(),
              selected: {_selectedStrategy},
              onSelectionChanged: (set) => _saveStrategy(set.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.accent.withValues(alpha: 0.3);
                  }
                  return AppColors.bgDark;
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _retryClaudeMd() async {
    setState(() { _claudeMdLoading = true; _claudeMdError = null; });
    final result = await ApiService.getClaudeMd(widget.appId);
    if (result.ok) {
      await CacheService.instance.setClaudeMd(widget.appId, result.data ?? '');
    }
    if (mounted) {
      setState(() {
        _claudeMdLoading = false;
        if (result.ok) {
          _claudeMdContent = result.data;
          _claudeMdError = null;
        } else {
          _claudeMdError = result.error;
        }
      });
    }
  }

  Future<void> _retryGdd() async {
    setState(() { _gddLoading = true; _gddError = null; });
    final result = await ApiService.getGdd(widget.appId);
    if (result.ok) {
      await CacheService.instance.setGdd(widget.appId, result.data ?? '');
    }
    if (mounted) {
      setState(() {
        _gddLoading = false;
        if (result.ok) {
          _gddContent = result.data;
          _gddError = null;
        } else {
          _gddError = result.error;
        }
      });
    }
  }

  Widget _buildClaudeMdCard() {
    final hasContent = _claudeMdContent != null && _claudeMdContent!.trim().isNotEmpty;
    final hasError = _claudeMdError != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.terminal, color: AppColors.info),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'CLAUDE.md',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_claudeMdEnhancing)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning),
                    ),
                  ),
                if (!hasError && hasContent && !_claudeMdEnhancing)
                  TextButton.icon(
                    onPressed: () => _fireAndForgetEnhance(type: 'claude-md'),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Enhance'),
                  ),
                if (!hasError)
                  TextButton.icon(
                    onPressed: () => _showClaudeMdSheet(),
                    icon: Icon(hasContent ? Icons.edit : Icons.add, size: 18),
                    label: Text(hasContent ? 'Edit' : 'Add'),
                  ),
                if (hasError)
                  TextButton.icon(
                    onPressed: _retryClaudeMd,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_claudeMdLoading)
              const Center(child: CircularProgressIndicator())
            else if (hasError)
              Text(
                'Failed to load: $_claudeMdError',
                style: TextStyle(fontSize: 13, color: AppColors.error),
              )
            else if (hasContent)
              Text(
                _claudeMdContent!.trim(),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
              )
            else
              Text(
                'No CLAUDE.md yet. Tap Add to set project instructions for AI.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
          ],
        ),
      ),
    );
  }

  void _showClaudeMdSheet() {
    final controller = TextEditingController(text: _claudeMdContent?.trim() ?? '');
    bool saving = false;

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
                  Text('CLAUDE.md - ${_app?.name ?? 'App'}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Project instructions for AI agents working on this app.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      hintText: 'Project conventions, build commands, rules...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: FilledButton.icon(
                      onPressed: saving ? null : () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('Cannot save empty CLAUDE.md'),
                            backgroundColor: AppColors.error,
                          ));
                          return;
                        }
                        setSheetState(() => saving = true);
                        final result = await ApiService.updateClaudeMd(
                            widget.appId, controller.text);
                        if (result.ok) {
                          await CacheService.instance
                              .setClaudeMd(widget.appId, controller.text);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(result.ok ? 'CLAUDE.md saved' : result.error ?? 'Failed'),
                            backgroundColor: result.ok ? AppColors.success : AppColors.error));
                          if (result.ok) {
                            setState(() => _claudeMdContent = controller.text);
                          }
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
    ).whenComplete(() => controller.dispose());
  }

  Widget _buildGddCard() {
    final hasContent = _gddContent != null && _gddContent!.trim().isNotEmpty;
    final hasError = _gddError != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, color: AppColors.info),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Design Document',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_gddEnhancing)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning),
                    ),
                  ),
                if (!hasError && hasContent && !_gddEnhancing)
                  TextButton.icon(
                    onPressed: () => _fireAndForgetEnhance(type: 'gdd'),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Enhance'),
                  ),
                if (!hasError)
                  TextButton.icon(
                    onPressed: () => _showGddSheet(),
                    icon: Icon(hasContent ? Icons.edit : Icons.add, size: 18),
                    label: Text(hasContent ? 'Edit' : 'Add'),
                  ),
                if (hasError)
                  TextButton.icon(
                    onPressed: _retryGdd,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_gddLoading)
              const Center(child: CircularProgressIndicator())
            else if (hasError)
              Text(
                'Failed to load: $_gddError',
                style: TextStyle(fontSize: 13, color: AppColors.error),
              )
            else if (hasContent)
              Text(
                _gddContent!.trim(),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
              )
            else
              Text(
                'No design document yet. Tap Add to describe your app vision.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
          ],
        ),
      ),
    );
  }

  void _showGddSheet() {
    final gddController = TextEditingController(text: _gddContent?.trim() ?? '');
    bool saving = false;

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
                  Text('Design Doc - ${_app?.name ?? 'App'}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('The AI will use this as context for all work on this app.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: gddController,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      hintText: 'Describe your app vision, features, goals...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: FilledButton.icon(
                      onPressed: saving ? null : () async {
                        final text = gddController.text.trim();
                        if (text.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('Cannot save empty design document'),
                            backgroundColor: AppColors.error,
                          ));
                          return;
                        }
                        setSheetState(() => saving = true);
                        final result = await ApiService.updateGdd(
                            widget.appId, gddController.text);
                        if (result.ok) {
                          await CacheService.instance
                              .setGdd(widget.appId, gddController.text);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(result.ok ? 'Design doc saved' : result.error ?? 'Failed'),
                            backgroundColor: result.ok ? AppColors.success : AppColors.error));
                          if (result.ok) {
                            setState(() => _gddContent = gddController.text);
                          }
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
    ).whenComplete(() => gddController.dispose());
  }

  /// Fire-and-forget enhance for both GDD and CLAUDE.md.
  /// Triggers background enhance on server, polls for completion.
  void _fireAndForgetEnhance({required String type}) async {
    final isGdd = type == 'gdd';
    final content = isGdd ? _gddContent : _claudeMdContent;
    final label = isGdd ? 'Design doc' : 'CLAUDE.md';

    if (content == null || content.trim().isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        icon: const Icon(Icons.auto_awesome, color: Colors.amber),
        title: Text('Enhance $label?'),
        content: const Text('AI will rewrite the document. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Enhance')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    // Mark as enhancing
    setState(() {
      if (isGdd) {
        _gddEnhancing = true;
      } else {
        _claudeMdEnhancing = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$label enhancement started on server...'),
      backgroundColor: AppColors.info,
    ));

    // Fire the enhance request (returns immediately)
    final future = isGdd
        ? ApiService.enhanceGdd(widget.appId, content)
        : ApiService.enhanceClaudeMd(widget.appId, content);

    future.then((result) {
      if (!mounted) return;
      if (!result.ok) {
        setState(() {
          if (isGdd) _gddEnhancing = false;
          else _claudeMdEnhancing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to start: ${result.error}'),
          backgroundColor: AppColors.error,
        ));
        return;
      }
      // Poll for completion every 10 seconds
      _pollEnhanceStatus(isGdd, label);
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        if (isGdd) _gddEnhancing = false;
        else _claudeMdEnhancing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$label enhance error: $e'),
        backgroundColor: AppColors.error,
      ));
    });
  }

  void _pollEnhanceStatus(bool isGdd, String label) {
    _enhanceTimer?.cancel();
    _enhanceTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted) { timer.cancel(); return; }
      final result = await ApiService.getEnhanceStatus(widget.appId);
      if (!mounted) { timer.cancel(); return; }
      if (!result.ok) return;
      final status = result.data!['status'] as String? ?? 'idle';
      if (status == 'running') return; // Still working
      timer.cancel();
      if (status == 'done') {
        // Reload the content from server
        final refreshed = isGdd
            ? await ApiService.getGdd(widget.appId)
            : await ApiService.getClaudeMd(widget.appId);
        if (refreshed.ok) {
          if (isGdd) {
            await CacheService.instance
                .setGdd(widget.appId, refreshed.data ?? '');
          } else {
            await CacheService.instance
                .setClaudeMd(widget.appId, refreshed.data ?? '');
          }
        }
        if (!mounted) return;
        setState(() {
          if (isGdd) {
            _gddEnhancing = false;
            if (refreshed.ok) _gddContent = refreshed.data;
          } else {
            _claudeMdEnhancing = false;
            if (refreshed.ok) _claudeMdContent = refreshed.data;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$label enhanced successfully'),
          backgroundColor: AppColors.success,
        ));
      } else {
        final error = result.data?['error'] as String? ?? 'Enhancement failed';
        if (!mounted) return;
        setState(() {
          if (isGdd) _gddEnhancing = false;
          else _claudeMdEnhancing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
        ));
      }
    });
  }

  Widget _buildBuildsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Builds',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_builds.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.build_circle_outlined, size: 32, color: Colors.grey.shade600),
                    const SizedBox(height: 8),
                    Text(
                      'No builds yet',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start a build from the card above',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ..._builds.take(5).map((build) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    build.status == 'success'
                        ? Icons.check_circle
                        : build.status == 'failed'
                            ? Icons.error
                            : Icons.hourglass_top,
                    color: build.status == 'success'
                        ? AppColors.success
                        : build.status == 'failed'
                            ? AppColors.error
                            : AppColors.warning,
                  ),
                  title: Text('v${build.version} - ${build.buildType}'),
                  subtitle: Text(
                    build.startedAt,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ),
              )),
      ],
    );
  }

}

class _LinkInfo {
  final IconData icon;
  final String label;
  final String value;
  final String field;
  final String hint;

  _LinkInfo(this.icon, this.label, this.value, this.field, this.hint);
}
