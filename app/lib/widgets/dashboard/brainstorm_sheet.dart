import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../utils/l10n_labels.dart';
import '../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
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
                        Text(l10n.brainstormNewGame,
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.brainstormDesc,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade400),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: l10n.brainstormNameHint,
                        prefixIcon: Icon(Icons.label),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: conceptController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText:
                            l10n.brainstormConceptHint,
                        prefixIcon: Icon(Icons.auto_awesome),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.genre,
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _genres.map((g) {
                        final label = genreLabel(l10n, g);
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
                    Text(l10n.engine,
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
                                    SnackBar(
                                        content: Text(
                                            l10n.enterConceptOrName),
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
                                      l10n.brainstormCreated;
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
                                          l10n.failedToBrainstorm),
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
                            ? l10n.creating
                            : l10n.brainstormAndCreate),
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
