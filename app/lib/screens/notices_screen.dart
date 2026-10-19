import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/notice_model.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../l10n/app_localizations.dart';

/// Notes from automations (weekly report, Play review replies, ...). Lives in
/// the Reports & Logs tab between Reports and Logs. Opening a note marks it
/// read; it can be marked unread again or deleted.
class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  static const _myTabIndex = 2;

  bool _unreadOnly = false;
  bool _loading = true;
  String? _error;
  List<NoticeModel> _notices = const [];
  final Set<int> _expanded = {};
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
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
    final result = await ApiService.getNotices(unreadOnly: _unreadOnly);
    if (!mounted) return;
    if (result.ok) {
      setState(() {
        _notices = result.data!
            .whereType<Map<String, dynamic>>()
            .map(NoticeModel.fromJson)
            .toList();
        _loading = false;
        _error = null;
      });
    } else if (!silent) {
      setState(() { _loading = false; _error = result.error; });
    }
  }

  Future<void> _toggle(NoticeModel n) async {
    final opening = !_expanded.contains(n.id);
    setState(() => opening ? _expanded.add(n.id) : _expanded.remove(n.id));
    if (opening && !n.read) {
      final result = await ApiService.setNoticeRead(n.id, true);
      // While "Unread" is filtered the note stays on screen until the next
      // refresh, so it does not vanish from under the finger.
      if (result.ok && mounted) _replace(n, read: true);
    }
  }

  Future<void> _markUnread(NoticeModel n) async {
    final result = await ApiService.setNoticeRead(n.id, false);
    if (!mounted) return;
    if (result.ok) {
      setState(() => _expanded.remove(n.id));
      _replace(n, read: false);
    } else {
      setState(() => _error = result.error);
    }
  }

  void _replace(NoticeModel n, {required bool read}) {
    setState(() {
      _notices = [
        for (final x in _notices)
          x.id == n.id
              ? NoticeModel(
                  id: x.id, source: x.source, title: x.title, body: x.body,
                  read: read, createdAt: x.createdAt, updatedAt: x.updatedAt)
              : x,
      ];
    });
  }

  Future<void> _delete(NoticeModel n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteNoticeTitle),
        content: Text(l10n.deleteNoticeBody),
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
    final result = await ApiService.deleteNotice(n.id);
    if (!mounted) return;
    if (result.ok) {
      setState(() => _notices = _notices.where((x) => x.id != n.id).toList());
    } else {
      setState(() => _error = result.error);
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
            child: SegmentedButton<bool>(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(value: false, label: Text(l10n.filterAll)),
                ButtonSegment(value: true, label: Text(l10n.filterUnread)),
              ],
              selected: {_unreadOnly},
              onSelectionChanged: (s) {
                setState(() => _unreadOnly = s.first);
                _load();
              },
            ),
          ),
          IconButton(
            tooltip: l10n.retry,
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(),
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
    if (_notices.isEmpty) {
      return _centered(Icons.notifications_none,
          _unreadOnly ? l10n.noUnreadNotices : l10n.noNotices);
    }
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _notices.length,
        itemBuilder: (_, i) {
          final n = _notices[i];
          return _NoticeCard(
            notice: n,
            expanded: _expanded.contains(n.id),
            onTap: () => _toggle(n),
            onMarkUnread: () => _markUnread(n),
            onDelete: () => _delete(n),
          );
        },
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

class _NoticeCard extends StatelessWidget {
  final NoticeModel notice;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onMarkUnread;
  final VoidCallback onDelete;

  const _NoticeCard({
    required this.notice,
    required this.expanded,
    required this.onTap,
    required this.onMarkUnread,
    required this.onDelete,
  });

  IconData get _icon {
    switch (notice.source) {
      case 'weekly_report':
        return Icons.insights;
      case 'play_reviews':
        return Icons.rate_review_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  String _whenOf(AppLocalizations l10n) {
    final dt = notice.when;
    if (dt == null) return '';
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
    final unread = !notice.read;
    final when = _whenOf(l10n);
    return Card(
      color: AppColors.bgCard,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        key: Key('notice_${notice.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_icon, size: 18, color: unread ? AppColors.accent : Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notice.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: unread ? FontWeight.bold : FontWeight.w500,
                        color: unread ? null : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  if (unread)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 6, right: 6),
                      decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                    ),
                  if (when.isNotEmpty)
                    Text(when, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
              if (notice.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                expanded
                    ? SelectableText(notice.body, style: const TextStyle(fontSize: 13, height: 1.35))
                    : Text(
                        notice.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.35),
                      ),
              ],
              if (expanded)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onMarkUnread,
                      icon: const Icon(Icons.mark_email_unread_outlined, size: 16),
                      label: Text(l10n.markUnread),
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
