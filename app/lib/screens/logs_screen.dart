import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../theme.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> with WidgetsBindingObserver {
  List<dynamic> _logs = [];
  bool _loading = false;
  String? _error;
  int? _selectedAppId;
  int? _expandedIndex;
  Timer? _pollTimer;
  bool _appInForeground = true;
  static const _myTabIndex = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => _loadLogs());
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || !_appInForeground) return;
      if (context.read<AppState>().activeTabIndex != _myTabIndex) return;
      _loadLogs(silent: true);
    });
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

  Future<void> _loadLogs({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    final result = await ApiService.getLogs(appId: _selectedAppId);
    if (mounted) {
      setState(() {
        if (result.ok) {
          _logs = result.data!;
          _error = null;
        } else if (_logs.isEmpty) {
          _error = result.error ?? 'Failed to load logs';
        }
        _loading = false;
        if (!silent) _expandedIndex = null;
      });
    }
  }

  /// Derive the actual log level. Prefers the structured fields the server
  /// emits (exit_code, status) over the heuristic level the parser sets from
  /// the message text — keyword detection is brittle ("Task started: fix
  /// login error" would otherwise be flagged red).
  String _effectiveLevel(Map<String, dynamic> log) {
    final exitCodeRaw = log['exit_code'];
    final exitCode = exitCodeRaw is int
        ? exitCodeRaw
        : (exitCodeRaw is String ? int.tryParse(exitCodeRaw) : null);
    if (exitCode != null) {
      return exitCode == 0 ? 'success' : 'error';
    }
    return (log['level'] ?? 'info').toString().toLowerCase();
  }

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'error': return AppColors.error;
      case 'warning': return AppColors.warning;
      case 'success': return AppColors.success;
      case 'info': return AppColors.info;
      default: return Colors.grey;
    }
  }

  IconData _levelIcon(String level) {
    switch (level.toLowerCase()) {
      case 'error': return Icons.error_outline;
      case 'warning': return Icons.warning_amber;
      case 'success': return Icons.check_circle_outline;
      case 'info': return Icons.info_outline;
      default: return Icons.article_outlined;
    }
  }

  String _formatTimestamp(String ts) {
    if (ts.isEmpty) return '';
    try {
      final dt = DateTime.parse(ts);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (e) {
      debugPrint('Failed to parse timestamp "$ts": $e');
      return ts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final apps = context.watch<AppState>().apps;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<int>(
              value: _selectedAppId,
              decoration: const InputDecoration(
                hintText: 'All apps', prefixIcon: Icon(Icons.filter_list),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              dropdownColor: AppColors.bgCard,
              items: [
                const DropdownMenuItem<int>(value: null, child: Text('All Apps')),
                ...apps.map((app) => DropdownMenuItem(value: app.id, child: Text(app.name))),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedAppId = val;
                  _expandedIndex = null;
                });
                _loadLogs();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade600),
                            const SizedBox(height: 16),
                            Text(_error!, style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadLogs,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                    color: AppColors.accent,
                    onRefresh: _loadLogs,
                    child: _logs.isEmpty
                        ? ListView(children: const [
                            SizedBox(height: 200),
                            Center(child: Text('No logs found',
                              style: TextStyle(color: Colors.grey, fontSize: 16)))])
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              final log = _logs[index];
                              final level = _effectiveLevel(log);
                              final message = (log['message'] ?? '').toString();
                              final appName = (log['app_name'] ?? '').toString();
                              final timestamp = (log['timestamp'] ?? log['created_at'] ?? '').toString();
                              final source = (log['source'] ?? log['agent'] ?? log['ai_agent'] ?? '').toString();
                              final details = (log['details'] ?? '').toString();
                              final output = (log['output'] ?? '').toString();
                              final summary = (log['summary'] ?? '').toString();
                              final exitCode = log['exit_code']?.toString() ?? '';
                              final duration = (log['duration'] ?? log['duration_seconds'] ?? '').toString();
                              final taskTitle = (log['task_title'] ?? log['task'] ?? '').toString();
                              final isExpanded = _expandedIndex == index;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _expandedIndex = isExpanded ? null : index;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Badges row
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _levelColor(level).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(_levelIcon(level),
                                                    color: _levelColor(level), size: 14),
                                                  const SizedBox(width: 4),
                                                  Text(level.toUpperCase(),
                                                    style: TextStyle(fontSize: 11, color: _levelColor(level),
                                                      fontWeight: FontWeight.w700)),
                                                ],
                                              ),
                                            ),
                                            if (appName.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              ConstrainedBox(
                                                constraints: const BoxConstraints(maxWidth: 120),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.accent.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(4)),
                                                  child: Text(appName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 11, color: AppColors.accent,
                                                      fontWeight: FontWeight.w600)),
                                                ),
                                              ),
                                            ],
                                            if (source.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppColors.agentColor(source).withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4)),
                                                child: Text(source.toUpperCase(),
                                                  style: TextStyle(fontSize: 10,
                                                    color: AppColors.agentColor(source),
                                                    fontWeight: FontWeight.w700)),
                                              ),
                                            ],
                                            const Spacer(),
                                            if (timestamp.isNotEmpty)
                                              Text(_formatTimestamp(timestamp),
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                          ],
                                        ),
                                        // Message preview (always shown)
                                        if (message.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Text(message,
                                            style: TextStyle(
                                              fontSize: 14,
                                              height: 1.4,
                                              color: Colors.grey.shade200,
                                            ),
                                            maxLines: isExpanded ? null : 3,
                                            overflow: isExpanded ? null : TextOverflow.ellipsis),
                                        ],
                                        // Expanded detail
                                        if (isExpanded) ...[
                                          const SizedBox(height: 10),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: AppColors.bgDark,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: SelectableText(message,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontFamily: 'monospace',
                                                color: Colors.grey.shade200,
                                                height: 1.6,
                                              )),
                                          ),
                                          if (summary.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: AppColors.info.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Summary', style: TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w600)),
                                                  const SizedBox(height: 4),
                                                  SelectableText(summary, style: TextStyle(fontSize: 13, color: Colors.grey.shade200, height: 1.4)),
                                                ],
                                              ),
                                            ),
                                          ],
                                          if (details.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: AppColors.bgDark,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Details', style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                                                  const SizedBox(height: 4),
                                                  SelectableText(details, style: TextStyle(fontSize: 13, fontFamily: 'monospace', color: Colors.grey.shade200, height: 1.5)),
                                                ],
                                              ),
                                            ),
                                          ],
                                          if (output.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: AppColors.bgDark,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Output', style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                                                  const SizedBox(height: 4),
                                                  SelectableText(output, style: TextStyle(fontSize: 13, fontFamily: 'monospace', color: Colors.grey.shade200, height: 1.5)),
                                                ],
                                              ),
                                            ),
                                          ],
                                          // Metadata row
                                          if (source.isNotEmpty || exitCode.isNotEmpty || duration.isNotEmpty || taskTitle.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 4,
                                              children: [
                                                if (source.isNotEmpty)
                                                  Text('Agent: $source', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                                if (taskTitle.isNotEmpty)
                                                  Text('Task: $taskTitle', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                                if (exitCode.isNotEmpty)
                                                  Text('Exit: $exitCode', style: TextStyle(fontSize: 12,
                                                    color: exitCode == '0' ? AppColors.success : AppColors.error)),
                                                if (duration.isNotEmpty)
                                                  Text('Duration: ${duration}s', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
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
