import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../l10n/app_localizations.dart';

/// Freshness indicator shared by every screen that paints cache-hydrated
/// data: a coloured dot plus "Synced Xm ago" / "Sync failed" / "Connecting...".
/// Re-renders itself on a timer so the relative label stays current without
/// the host screen needing its own tick timer.
class SyncStatusChip extends StatefulWidget {
  final DateTime? lastSyncedAt;
  final bool failed;

  const SyncStatusChip({
    super.key,
    required this.lastSyncedAt,
    required this.failed,
  });

  static const _tickInterval = Duration(seconds: 5);
  static const _justNowThreshold = Duration(seconds: 10);

  /// Human label for the time since [lastSyncedAt]; empty when never synced.
  static String label(BuildContext context, DateTime? lastSyncedAt,
      {bool failed = false}) {
    final l10n = AppLocalizations.of(context)!;
    if (failed) return l10n.syncFailed;
    if (lastSyncedAt == null) return '';
    final diff = DateTime.now().difference(lastSyncedAt);
    if (diff < _justNowThreshold) return l10n.justNow;
    if (diff.inSeconds < 60) return l10n.timeSecondsAgo(diff.inSeconds);
    if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
    return l10n.timeHoursAgo(diff.inHours);
  }

  @override
  State<SyncStatusChip> createState() => _SyncStatusChipState();
}

class _SyncStatusChipState extends State<SyncStatusChip> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(SyncStatusChip._tickInterval, (_) {
      if (mounted && widget.lastSyncedAt != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = SyncStatusChip.label(context, widget.lastSyncedAt, failed: widget.failed);
    final Color dot;
    if (widget.failed) {
      dot = Colors.red;
    } else if (text.isNotEmpty) {
      dot = AppColors.success;
    } else {
      dot = Colors.grey;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
        ),
        Text(
          text.isNotEmpty ? l10n.syncedAgo(text) : l10n.connecting,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade400,
            fontWeight: FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

/// Dismissible inline banner for a refresh that failed while previously
/// loaded data is still on screen. Keeps the list (and scroll position)
/// intact instead of replacing it with an error page.
class SyncErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  const SyncErrorBanner({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: AppColors.error.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 4, top: 2, bottom: 2),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, size: 18, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.refreshFailedShowingCached(message),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(l10n.retry),
            ),
            IconButton(
              tooltip: l10n.dismiss,
              onPressed: onDismiss,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
