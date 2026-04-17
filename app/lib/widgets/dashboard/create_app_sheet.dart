import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

/// Bottom sheet that creates a new app by name + type + AI agent.
///
/// Use [CreateAppSheet.show] — it owns the controller, ensures it is
/// disposed when the sheet closes, and invokes [onCreated] only on a
/// successful API response so the caller can refresh its list.
class CreateAppSheet {
  static String _appTypeHint(String type) {
    switch (type) {
      case 'flutter':
        return 'Mobile/desktop app with Google Play deploy support';
      case 'godot':
        return 'Game project with export targets (Windows, Android, Web)';
      case 'python':
        return 'Python project with script runner and pip management';
      case 'web':
        return 'Web app with static hosting deploy support';
      case 'phaser':
        return 'Phaser 3 + TypeScript game, wrapped as Android AAB via Capacitor';
      default:
        return '';
    }
  }

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onCreated,
  }) {
    final nameController = TextEditingController();
    String appType = 'flutter';
    String agent = 'claude';
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
                    const Text('New App',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        hintText: 'App Name (e.g. My Game)',
                        prefixIcon: Icon(Icons.apps),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Type',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['flutter', 'godot', 'python', 'phaser']
                          .map((t) {
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
                    const SizedBox(height: 4),
                    Text(
                      _appTypeHint(appType),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 12),
                    const Text('AI Agent',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children:
                          ['claude', 'gemini', 'codex', 'local'].map((a) {
                        return ChoiceChip(
                          label:
                              Text(a[0].toUpperCase() + a.substring(1)),
                          selected: a == agent,
                          selectedColor: AppColors.info,
                          onSelected: (sel) {
                            if (sel) setSheetState(() => agent = a);
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
                                final name = nameController.text.trim();
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: Text('Name is required'),
                                        backgroundColor: AppColors.warning),
                                  );
                                  return;
                                }
                                setSheetState(() => submitting = true);
                                final result = await ApiService.createApp(
                                    name: name,
                                    appType: appType,
                                    fixStrategy: agent);
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(result.ok
                                        ? 'App created!'
                                        : result.error ??
                                            'Failed to create app'),
                                    backgroundColor: result.ok
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                );
                                if (result.ok) onCreated();
                              },
                        icon: submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.add),
                        label: Text(
                            submitting ? 'Creating...' : 'Create App'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(nameController.dispose);
  }
}
