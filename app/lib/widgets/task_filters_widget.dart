import 'package:flutter/material.dart';
import '../theme.dart';

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

  static String chipLabel(String value) {
    switch (value) {
      case 'all': return 'All';
      case 'in_progress': return 'In Progress';
      default: return value[0].toUpperCase() + value.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search...',
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
                  label: Text(chipLabel(s), style: TextStyle(fontSize: 12)),
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
                  label: Text(chipLabel(t), style: TextStyle(fontSize: 12)),
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
