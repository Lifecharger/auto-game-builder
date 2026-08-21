import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';

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
  static String label(DateTime? lastSyncedAt, {bool failed = false}) {
    if (failed) return 'Sync failed';
    if (lastSyncedAt == null) return '';
    final diff = DateTime.now().difference(lastSyncedAt);
    if (diff < _justNowThreshold) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  State<SyncStatusChip> createState() => _SyncStatusChipState();
}

class _SyncStatusChipState extends State<SyncStatusChip> {
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
    final text = SyncStatusChip.label(widget.lastSyncedAt, failed: widget.failed);
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
          text.isNotEmpty ? 'Synced $text' : 'Connecting...',
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
                'Refresh failed — showing last synced data. $message',
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
              child: const Text('Retry'),
            ),
            IconButton(
              tooltip: 'Dismiss',
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
