import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/report_model.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../l10n/app_localizations.dart';

/// In-game bug reports / suggestions. Lives in the Reports & Logs tab. Reports
/// are pulled by the server from the game-reports worker; here they can be read,
/// their screenshots viewed, and closed (or reopened / deleted).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  static const _myTabIndex = 2;

  String _filter = 'open'; // open | closed | all
  bool _loading = true;
  String? _error;
  List<ReportModel> _reports = const [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (context.read<AppState>().activeTabIndex != _myTabIndex) return;
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    final result = await ApiService.getReports(status: _filter == 'all' ? null : _filter);
    if (!mounted) return;
    if (result.ok) {
      setState(() {
        _reports = result.data!
            .whereType<Map<String, dynamic>>()
            .map(ReportModel.fromJson)
            .toList();
        _loading = false;
        _error = null;
      });
    } else {
      setState(() { _loading = false; _error = result.error; });
    }
  }

  Future<void> _pullNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ApiService.pullReportsNow();
    if (!mounted) return;
    if (result.ok) {
      messenger.showSnackBar(SnackBar(
        content: Text(result.data! > 0 ? l10n.newReportsCount(result.data!) : l10n.noNewReports),
      ));
      await _load(silent: true);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(result.error ?? l10n.pullFailed)));
    }
  }

  Future<void> _setStatus(ReportModel r, String status) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ApiService.updateReport(r.id, {'status': status});
    if (!mounted) return;
    if (result.ok) {
      await _load(silent: true);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(result.error ?? l10n.updateFailed)));
    }
  }

  Future<void> _delete(ReportModel r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteReportTitle),
        content: Text(l10n.deleteReportBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final result = await ApiService.deleteReport(r.id);
    if (!mounted) return;
    if (result.ok) {
      await _load(silent: true);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(result.error ?? l10n.deleteFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _toolbar(),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _toolbar() {
    return Container(
      color: AppColors.bgCard,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<String>(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(value: 'open', label: Text(l10n.filterOpen)),
                ButtonSegment(value: 'closed', label: Text(l10n.filterClosed)),
                ButtonSegment(value: 'all', label: Text(l10n.filterAll)),
              ],
              selected: {_filter},
              onSelectionChanged: (s) {
                setState(() => _filter = s.first);
                _load();
              },
            ),
          ),
          IconButton(
            tooltip: l10n.pullNow,
            icon: const Icon(Icons.cloud_download_outlined),
            onPressed: _pullNow,
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _centered(Icons.error_outline, _error!, action: () => _load());
    }
    if (_reports.isEmpty) {
      return _centered(Icons.inbox_outlined,
          _filter == 'open' ? l10n.noOpenReports : l10n.noReportsHere);
    }
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _reports.length,
        itemBuilder: (_, i) => _ReportCard(
          report: _reports[i],
          onClose: () => _setStatus(_reports[i], 'closed'),
          onReopen: () => _setStatus(_reports[i], 'open'),
          onDelete: () => _delete(_reports[i]),
        ),
      ),
    );
  }

  Widget _centered(IconData icon, String text, {VoidCallback? action}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Colors.grey)),
          if (action != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: action, child: Text(l10n.retry)),
          ],
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportModel report;
  final VoidCallback onClose;
  final VoidCallback onReopen;
  final VoidCallback onDelete;

  const _ReportCard({
    required this.report,
    required this.onClose,
    required this.onReopen,
    required this.onDelete,
  });

  ({IconData icon, Color color, String label}) _catOf(AppLocalizations l10n) {
    switch (report.category) {
      case 'bug':
        return (icon: Icons.bug_report, color: AppColors.error, label: l10n.categoryBug);
      case 'suggestion':
        return (icon: Icons.lightbulb_outline, color: AppColors.warning, label: l10n.categorySuggestion);
      default:
        return (icon: Icons.chat_bubble_outline, color: AppColors.info, label: l10n.categoryOther);
    }
  }

  Widget _deviceInfo() {
    final device = report.deviceLabel;
    final os = report.osLabel;
    if (device.isEmpty && os.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.smartphone, size: 13, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              [if (device.isNotEmpty) device, if (os.isNotEmpty) os].join('  ·  '),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  String _whenOf(AppLocalizations l10n) {
    final ms = int.tryParse(report.receivedAt);
    if (ms == null || ms <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return l10n.timeJustNow;
    if (d.inHours < 1) return l10n.timeMinutesAgo(d.inMinutes);
    if (d.inDays < 1) return l10n.timeHoursAgo(d.inHours);
    if (d.inDays < 7) return l10n.timeDaysAgo(d.inDays);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cat = _catOf(l10n);
    final closed = !report.isOpen;
    return Opacity(
      opacity: closed ? 0.6 : 1.0,
      child: Card(
        color: AppColors.bgCard,
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(cat.icon, color: cat.color, size: 18),
                  const SizedBox(width: 6),
                  Text(cat.label,
                      style: TextStyle(color: cat.color, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.appLabel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_whenOf(l10n).isNotEmpty)
                    Text(_whenOf(l10n),
                        style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              Text(report.message),
              if (report.shotCount > 0) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 68,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: report.shotCount,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, idx) => _Thumb(reportId: report.id, index: idx),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _deviceInfo(),
              Row(
                children: [
                  Text(
                    [
                      if (report.platform.isNotEmpty) report.platform,
                      if (report.appVersion.isNotEmpty) l10n.versionWithNumber(report.appVersion),
                    ].join(' · '),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const Spacer(),
                  if (closed)
                    TextButton.icon(
                      onPressed: onReopen,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(l10n.reopen),
                    )
                  else
                    TextButton.icon(
                      onPressed: onClose,
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: Text(l10n.close),
                    ),
                  IconButton(
                    tooltip: l10n.delete,
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String reportId;
  final int index;
  const _Thumb({required this.reportId, required this.index});

  @override
  Widget build(BuildContext context) {
    final url = ApiService.reportShotUrl(reportId, index);
    final headers = ApiService.authHeaders;
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: InteractiveViewer(
            child: Image.network(url, headers: headers, fit: BoxFit.contain),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          url,
          headers: headers,
          width: 68,
          height: 68,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 68,
            height: 68,
            color: Colors.black26,
            child: const Icon(Icons.broken_image, color: Colors.grey, size: 20),
          ),
        ),
      ),
    );
  }
}
