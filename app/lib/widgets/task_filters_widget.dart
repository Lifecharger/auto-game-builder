import 'package:flutter/material.dart';
import '../theme.dart';
import '../l10n/app_localizations.dart';

class TaskFiltersWidget extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final String statusFilter;
  final List<String> statusOptions;
  final ValueChanged<String> onStatusChanged;
  final String typeFilter;
  final List<String> typeOptions;
  final ValueChanged<String> onTypeChanged;

  const TaskFiltersWidget({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.statusFilter,
    required this.statusOptions,
    required this.onStatusChanged,
    required this.typeFilter,
    required this.typeOptions,
    required this.onTypeChanged,
  });

  static String chipLabel(BuildContext context, String value) {
    final l10n = AppLocalizations.of(context)!;
    switch (value) {
      case 'all': return l10n.filterAll;
      case 'in_progress': return l10n.statusInProgress;
      case 'pending': return l10n.statusPendingLower;
      case 'failed': return l10n.statusFailedLower;
      case 'divided': return l10n.statusDivided;
      case 'completed': return l10n.statusCompleted;
      case 'built': return l10n.statusBuiltLower;
      case 'done': return l10n.statusDone;
      case 'issue': return l10n.typeIssue;
      case 'bug': return l10n.typeBug;
      case 'fix': return l10n.typeFix;
      case 'feature': return l10n.typeFeature;
      case 'idea': return l10n.typeIdea;
      default: return value[0].toUpperCase() + value.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: onSearchClear,
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            onChanged: onSearchChanged,
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: statusOptions.map((s) {
              final selected = s == statusFilter;
              final color = s == 'all' ? AppColors.accent : AppColors.taskStatusColor(s);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(chipLabel(context, s), style: TextStyle(fontSize: 12)),
                  selected: selected,
                  selectedColor: color.withValues(alpha: 0.3),
                  checkmarkColor: color,
                  side: BorderSide(color: selected ? color : Colors.grey.shade700),
                  onSelected: (_) => onStatusChanged(s),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: typeOptions.map((t) {
              final selected = t == typeFilter;
              final color = t == 'all' ? AppColors.accent : AppColors.taskTypeColor(t);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(chipLabel(context, t), style: TextStyle(fontSize: 12)),
                  selected: selected,
                  selectedColor: color.withValues(alpha: 0.3),
                  checkmarkColor: color,
                  side: BorderSide(color: selected ? color : Colors.grey.shade700),
                  onSelected: (_) => onTypeChanged(t),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
