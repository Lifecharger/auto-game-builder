import 'package:flutter/material.dart';
import '../../theme.dart';
import '../task_item_card.dart';

/// Swipeable wrapper around [TaskItemCard] used by the Issues list.
///
/// Encapsulates the Dismissible + confirm-dialog pattern so the
/// per-item ListView builder in IssuesScreen stays compact. The wrapper
/// degrades gracefully: when the item is already completed (or sourced
/// from the Ideas feed) it skips the Dismissible and returns the card
/// directly.
///
/// [onCardDelete] is the icon-tap callback bound to [TaskItemCard.onDelete]
/// — it is expected to handle its own confirmation. [onSwipeDelete] fires
/// after the post-swipe confirmation dialog, so it should delete directly
/// without re-prompting.
class IssueTaskCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
  final bool isExpanded;
  final DateTime? inProgressSince;
  final VoidCallback onTap;
  final VoidCallback? onFix;
  final VoidCallback? onReset;
  final VoidCallback onCardDelete;
  final VoidCallback onSwipeDelete;
  final VoidCallback onComplete;

  const IssueTaskCard({
    super.key,
    required this.item,
    required this.index,
    required this.isExpanded,
    required this.inProgressSince,
    required this.onTap,
    required this.onFix,
    required this.onReset,
    required this.onCardDelete,
    required this.onSwipeDelete,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final status = item['status'] ?? 'pending';
    final taskType =
        (item['task_type'] ?? item['type'] ?? 'issue').toString();
    final canDelete = status != 'completed';
    final canComplete = status != 'completed' && item['_source'] != 'idea';

    final card = TaskItemCard(
      item: item,
      typeColor: AppColors.taskTypeColor(taskType),
      statusColor: AppColors.taskStatusColor(status),
      isExpanded: isExpanded,
      inProgressSince: inProgressSince,
      onTap: onTap,
      onFixNow: onFix,
      onDelete: canDelete ? onCardDelete : null,
      onReset: status == 'in_progress' ? onReset : null,
    );

    if (!canDelete && !canComplete) return card;

    return Dismissible(
      key: ValueKey('${item['_source']}_${item['id'] ?? index}'),
      direction: canDelete && canComplete
          ? DismissDirection.horizontal
          : canComplete
              ? DismissDirection.startToEnd
              : DismissDirection.endToStart,
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
            Text('Complete',
                style: TextStyle(
                    color: AppColors.success, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
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
            Text('Delete',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.delete, color: AppColors.error),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.bgCard,
              title: const Text('Mark Complete'),
              content: Text('Mark "${item['title']}" as completed?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success),
                  child: const Text('Complete'),
                ),
              ],
            ),
          );
          if (confirm == true) onComplete();
        } else {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.bgCard,
              title: const Text('Delete'),
              content:
                  Text('Delete "${item['title']}"?\nThis cannot be undone.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style:
                      FilledButton.styleFrom(backgroundColor: AppColors.error),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirm == true) onSwipeDelete();
        }
        return false;
      },
      child: card,
    );
  }
}
