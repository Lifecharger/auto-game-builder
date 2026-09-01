import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../l10n/app_localizations.dart';

/// Bottom sheet that creates a new app by name + type + AI agent.
///
/// Use [CreateAppSheet.show] — it owns the controller, ensures it is
/// disposed when the sheet closes, and invokes [onCreated] only on a
/// successful API response so the caller can refresh its list.
class CreateAppSheet {
  static String _appTypeHint(AppLocalizations l10n, String type) {
    switch (type) {
      case 'flutter':
        return l10n.appTypeFlutterDesc;
      case 'godot':
        return l10n.appTypeGodotDesc;
      case 'python':
        return l10n.appTypePythonDesc;
      case 'web':
        return l10n.appTypeWebDesc;
      case 'phaser':
        return l10n.appTypePhaserDesc;
      default:
        return '';
    }
  }

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onCreated,
  }) {
    final l10n = AppLocalizations.of(context)!;
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
                    Text(l10n.newApp,
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: l10n.appNameHint,
                        prefixIcon: Icon(Icons.apps),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.type,
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
                      _appTypeHint(l10n, appType),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.aiAgent,
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
                                    SnackBar(
                                        content: Text(l10n.nameIsRequired),
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
                                        ? l10n.appCreated
                                        : result.error ??
                                            l10n.failedToCreateApp),
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
                            submitting ? l10n.creating : l10n.createApp),
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
