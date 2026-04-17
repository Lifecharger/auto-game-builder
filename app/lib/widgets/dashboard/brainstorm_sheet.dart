import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

/// Bottom sheet that creates a new project with a brainstorm task seeded
/// from a concept/genre/engine selection.
///
/// Use [BrainstormSheet.show] — it owns both controllers, ensures they
/// are disposed when the sheet closes, and invokes [onCreated] only on a
/// successful brainstorm so the caller can refresh its list.
class BrainstormSheet {
  static const List<String> _genres = [
    '',
    'Puzzle',
    'Idle/Clicker',
    'RPG',
    'Action',
    'Strategy',
    'Simulation',
    'Arcade',
    'Card Game',
    'Tower Defense',
  ];

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onCreated,
  }) {
    final conceptController = TextEditingController();
    final nameController = TextEditingController();
    String appType = 'godot';
    String genre = '';
    bool submitting = false;

    return showModalBottomSheet<void>(
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
                left: 20,
                right: 20,
                top: 20,
                bottom: mq.viewInsets.bottom + mq.padding.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb,
                            color: Colors.amber.shade400, size: 24),
                        const SizedBox(width: 8),
                        const Text('Brainstorm New Game',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Creates a new project with a brainstorm task. When the task runs, AI generates a full GDD and initial tasks.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade400),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        hintText: 'Project name (optional — AI can suggest)',
                        prefixIcon: Icon(Icons.label),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: conceptController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText:
                            'Concept seed (e.g. "ant colony idle game", "puzzle with gravity")',
                        prefixIcon: Icon(Icons.auto_awesome),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Genre',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _genres.map((g) {
                        final label = g.isEmpty ? 'Any' : g;
                        return ChoiceChip(
                          label: Text(label,
                              style: const TextStyle(fontSize: 12)),
                          selected: g == genre,
                          selectedColor: Colors.amber.withAlpha(180),
                          onSelected: (sel) {
                            if (sel) setSheetState(() => genre = g);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Text('Engine',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['godot', 'flutter', 'phaser'].map((t) {
                        return ChoiceChip(
                          label:
                              Text(t[0].toUpperCase() + t.substring(1)),
                          selected: t == appType,
                          selectedColor: AppColors.accent,
                          avatar: Icon(AppColors.appTypeIcon(t),
                              size: 18,
                              color: t == appType
                                  ? Colors.white
                                  : Colors.grey.shade400),
                          onSelected: (sel) {
                            if (sel) setSheetState(() => appType = t);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: submitting
                            ? null
                            : () async {
                                final concept =
                                    conceptController.text.trim();
                                final name = nameController.text.trim();
                                if (concept.isEmpty && name.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Enter a concept or project name'),
                                        backgroundColor:
                                            AppColors.warning),
                                  );
                                  return;
                                }
                                setSheetState(() => submitting = true);
                                final result =
                                    await ApiService.studioBrainstorm(
                                  concept: concept,
                                  genre: genre,
                                  appType: appType,
                                  name: name,
                                );
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                if (result.ok) {
                                  final msg = result.data?['message'] ??
                                      'Project created with brainstorm task!';
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(msg),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                  onCreated();
                                } else {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(result.error ??
                                          'Failed to brainstorm'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              },
                        icon: submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.lightbulb),
                        label: Text(submitting
                            ? 'Creating...'
                            : 'Brainstorm & Create'),
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
      conceptController.dispose();
      nameController.dispose();
    });
  }
}
