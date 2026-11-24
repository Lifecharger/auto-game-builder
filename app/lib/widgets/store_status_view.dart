import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/store_status.dart';
import '../services/api_service.dart';
import '../theme.dart';

/// Localized name of a store track ("production", "TestFlight", "in review").
String storeTrackLabel(AppLocalizations l10n, String store, String track) {
  switch (track) {
    case 'production':
      return l10n.trackProduction;
    case 'beta':
      return l10n.trackBeta;
    case 'alpha':
      return l10n.trackAlpha;
    case 'internal':
      return l10n.trackInternal;
    case 'live':
      return l10n.trackLive;
    case 'review':
      return l10n.trackReview;
    case 'testflight':
      return l10n.trackTestflight;
    case 'prepare':
      return l10n.trackPrepare;
  }
  return track;
}

/// Green = in players' hands, amber = testers / review, blue = internal.
Color storeTrackColor(String track) {
  switch (track) {
    case 'production':
    case 'live':
      return AppColors.success;
    case 'beta':
    case 'alpha':
    case 'review':
      return AppColors.warning;
    case 'testflight':
    case 'internal':
      return AppColors.info;
  }
  return Colors.grey.shade500;
}

/// Apple / Play status codes made readable ("READY_FOR_SALE" -> "ready for sale").
String humanStatus(String code) {
  return code
      .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ')
      .replaceAll('_', ' ')
      .toLowerCase();
}

/// One collapsed-card line per store: "Play: 1.0.171 (production)".
class StoreStatusChip extends StatelessWidget {
  final String store; // play | apple
  final StoreInfo info;
  final VoidCallback? onTap;

  const StoreStatusChip({super.key, required this.store, required this.info, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = store == 'play' ? l10n.storePlay : l10n.storeAppStore;
    final d = info.display;
    final color = d == null ? Colors.grey.shade500 : storeTrackColor(d.track);
    final text = d == null
        ? '$name: ${info.refreshedAt == null && info.error.isEmpty ? l10n.storeNotChecked : l10n.storeNotOnStore}'
        : '$name: ${l10n.storeLineVersion(d.version, storeTrackLabel(l10n, store, d.track))}';
    final live = info.live;
    final showLive = store == 'apple' && live != null && d != null && d.track != 'live';
    final chips = <Widget>[
      _chip(text, color, warn: info.error.isNotEmpty),
      if (showLive) _chip(l10n.storeLiveVersion(live.version), AppColors.success),
    ];
    final row = Wrap(spacing: 4, runSpacing: 4, children: chips);
    if (onTap == null) return row;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap!();
      },
      borderRadius: BorderRadius.circular(6),
      child: row,
    );
  }

  Widget _chip(String text, Color color, {bool warn = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(warn ? Icons.sync_problem : Icons.storefront_outlined, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}

/// Expanded card body: every track of both stores plus the store actions
/// (promote on Play, attach + submit on Apple).
class StoreStatusPanel extends StatefulWidget {
  final int appId;
  final StoreStatus status;

  /// Called after an action changed something on the server, so the owner
  /// list can re-sync.
  final VoidCallback? onChanged;

  const StoreStatusPanel({super.key, required this.appId, required this.status, this.onChanged});

  @override
  State<StoreStatusPanel> createState() => _StoreStatusPanelState();
}

class _StoreStatusPanelState extends State<StoreStatusPanel> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  /// The status an action or refresh just returned, until the app list
  /// catches up with it.
  StoreStatus? _fresh;
  bool _busy = false;

  StoreStatus get _status => _fresh ?? widget.status;

  @override
  void didUpdateWidget(StoreStatusPanel old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status) _fresh = null;
  }

  Future<void> _run(Future<ApiResult<Map<String, dynamic>>> Function() call,
      String Function(Map<String, dynamic> result) doneText) async {
    setState(() => _busy = true);
    final res = await call();
    if (!mounted) return;
    setState(() {
      _busy = false;
      final raw = res.data?['store_status'] ?? res.data;
      if (res.ok && raw is Map) _fresh = StoreStatus.fromJson(raw);
    });
    if (res.ok) widget.onChanged?.call();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(res.ok ? Icons.check_circle : Icons.error_outline,
            color: res.ok ? AppColors.success : AppColors.error),
        content: Text(res.ok ? doneText(res.data!) : l10n.storeActionFailed(res.error ?? '')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.close))],
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    final res = await ApiService.refreshStoreStatus(widget.appId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res.ok) _fresh = StoreStatus.fromJson(res.data);
    });
    if (res.ok) {
      widget.onChanged?.call();
    } else {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.error_outline, color: AppColors.error),
          content: Text(l10n.storeActionFailed(res.error ?? '')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.close))],
        ),
      );
    }
  }

  // ── Play ───────────────────────────────────────────────────

  Future<void> _promote(StoreInfo play) async {
    final sources = play.liveTracks.where((t) => t != 'production').toList();
    if (sources.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(l10n.promoteNoSource),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.close))],
        ),
      );
      return;
    }
    String source = sources.first;
    StoreEntry entryOf(String t) => play.entries
        .where((e) => e.track == t && playLiveStatuses.contains(e.status))
        .reduce((a, b) => compareVersions(a, b) >= 0 ? a : b);
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(l10n.promoteToProduction),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.promoteChooseSource),
                RadioGroup<String>(
                  groupValue: source,
                  onChanged: (v) => setD(() => source = v ?? source),
                  child: Column(
                    children: [
                      for (final t in sources)
                        RadioListTile<String>(
                          value: t,
                          contentPadding: EdgeInsets.zero,
                          title: Text(storeTrackLabel(l10n, 'play', t)),
                          subtitle: Text(entryOf(t).version),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.promoteBody(entryOf(source).version, storeTrackLabel(l10n, 'play', source)),
                  style: TextStyle(color: AppColors.warning, fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, source), child: Text(l10n.promoteConfirm)),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    await _run(
      () => ApiService.promote(widget.appId, store: 'play', fromTrack: chosen, toTrack: 'production'),
      (r) => l10n.promoteDone('${(r['result'] as Map?)?['version'] ?? ''}', l10n.trackProduction),
    );
  }

  // ── Apple ──────────────────────────────────────────────────

  /// The newest TestFlight build that Apple can take (processed, not expired).
  AppleBuild? _newestBuild(StoreInfo apple) {
    AppleBuild? best;
    for (final b in apple.attachableBuilds) {
      if (best == null ||
          compareVersions(StoreEntry(track: 'testflight', version: b.version, build: b.build),
                  StoreEntry(track: 'testflight', version: best.version, build: best.build)) >
              0) {
        best = b;
      }
    }
    return best;
  }

  /// Like Play's promote: one tap sends the newest TestFlight build to App
  /// Review. Apple needs the build put on an App Store version first; the
  /// server does that (creating or renaming the version) and then submits.
  Future<void> _sendToReview(AppleBuild build) async {
    final version = build.version;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 36),
        title: Text(l10n.submitReviewTitle),
        content: Text(l10n.submitReviewBody('$version (${build.build})')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.submitReviewConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      () async {
        final attached = await ApiService.promote(widget.appId, store: 'apple', buildId: build.buildId);
        if (!attached.ok) return attached;
        return ApiService.submitForReview(widget.appId);
      },
      (r) => l10n.submitReviewDone('${(r['result'] as Map?)?['version'] ?? version}'),
    );
  }

  // ── UI ─────────────────────────────────────────────────────

  String _checked(StoreInfo info) {
    final t = DateTime.tryParse(info.refreshedAt ?? '');
    if (t == null) return l10n.storeNotChecked;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return l10n.storeLastChecked(DateFormat('d MMM HH:mm', locale).format(t.toLocal()));
  }

  Widget _entryRow(String store, StoreEntry e) {
    final color = storeTrackColor(e.track);
    final noBuild = store == 'apple' && e.track == 'prepare' && e.build.isEmpty;
    final extra = noBuild
        ? l10n.storeNoBuildAttached
        : [
            if (e.status != 'completed') humanStatus(e.status),
            if (e.fraction != null) '${(e.fraction! * 100).round()}%',
          ].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(storeTrackLabel(l10n, store, e.track),
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text(e.label, style: const TextStyle(fontSize: 13)),
          if (extra.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(extra,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end),
            ),
          ],
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap, {Color? color}) => TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: color,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        onPressed: _busy ? null : onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
      );

  Widget _section(String title, StoreInfo? info, List<Widget> actions, {Widget? trailing}) {
    final rows = info == null ? const <StoreEntry>[] : visibleEntries(info.store, info.entries);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (info != null)
              Expanded(
                child: Text(_checked(info),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis),
              )
            else
              const Spacer(),
            if (trailing != null) trailing,
          ],
        ),
        if (rows.isEmpty)
          Text(info == null ? l10n.storeNotChecked : l10n.storeNotOnStore,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
        else
          ...rows.map((e) => _entryRow(info!.store, e)),
        if (info != null && info.error.isNotEmpty)
          Text(l10n.storeCheckFailed(info.error),
              style: TextStyle(fontSize: 11, color: AppColors.error), maxLines: 2,
              overflow: TextOverflow.ellipsis),
        if (actions.isNotEmpty) Wrap(spacing: 4, children: actions),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final play = _status.play;
    final apple = _status.apple;
    final newest = apple == null ? null : _newestBuild(apple);
    final appleRows = apple == null ? const <StoreEntry>[] : visibleEntries('apple', apple.entries);
    final canSend = newest != null && appleRows.any((e) => e.track == 'testflight');
    final canPromote = play != null &&
        visibleEntries('play', play.entries).any((e) => e.track != 'production');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          if (_busy) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 8),
          _section(
            l10n.storePlay,
            play,
            [
              if (canPromote)
                _action(Icons.rocket_launch_outlined, l10n.promoteToProduction, () => _promote(play)),
            ],
            trailing: IconButton(
              tooltip: l10n.storeRefreshStatus,
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.sync),
            ),
          ),
          const SizedBox(height: 8),
          _section(l10n.storeAppStore, apple, [
            if (canSend)
              _action(Icons.rocket_launch_outlined, l10n.submitForReview, () => _sendToReview(newest),
                  color: AppColors.warning),
          ]),
        ],
      ),
    );
  }
}

/// Which app cards show their store details, remembered on this phone.
class StoreCardMemory {
  StoreCardMemory._();
  static const key = 'dashboard_store_expanded_ids';

  static Future<Set<int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(key) ?? const [])
        .map((e) => int.tryParse(e) ?? 0)
        .where((e) => e > 0)
        .toSet();
  }

  static Future<void> save(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, ids.map((e) => e.toString()).toList());
  }
}
