import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../l10n/app_localizations.dart';

/// A file staged for upload. The sheet has to remember whether a pick is a
/// document or an image: PDFs cannot be shown as a thumbnail.
class _StagedAttachment {
  final File file;
  final String name;
  final bool isPdf;

  const _StagedAttachment({
    required this.file,
    required this.name,
    required this.isPdf,
  });
}

class CreateTaskSheet {
  /// Mirrors the server's per-attachment PDF limit
  /// (`MAX_PDF_ATTACHMENT_BYTES` in server/api/server.py) so the user is told
  /// before a multi-megabyte upload is attempted.
  static const int _maxPdfBytes = 25 * 1024 * 1024;
  static const double _tileSize = 80;
  static void show({
    required BuildContext context,
    required int appId,
    required VoidCallback onCreated,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String taskType = 'issue';
    String priority = 'normal';
    bool submitting = false;
    List<_StagedAttachment> attachedFiles = [];
    // Optional dependencies: this task stays blocked until they finish.
    final dependsOn = <int>{};
    List<Map<String, dynamic>>? openTasks; // null = not loaded yet
    bool showDependsOn = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final mq = MediaQuery.of(ctx);
            // Read the system bar inset straight from the view so the footer
            // clears the navigation bar even if an ancestor stripped padding.
            final view = View.of(ctx);
            final systemBottom = view.padding.bottom / view.devicePixelRatio;
            final keyboardBottom = mq.viewInsets.bottom;
            final footerBottom =
                keyboardBottom > 0 ? keyboardBottom : systemBottom;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.newItem,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            hintText: l10n.titleHint,
                            prefixIcon: Icon(Icons.title),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: l10n.descriptionHint,
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.type,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              ['issue', 'bug', 'fix', 'feature', 'idea'].map((
                                type,
                              ) {
                                final selected = type == taskType;
                                return ChoiceChip(
                                  label: Text(
                                    type[0].toUpperCase() + type.substring(1),
                                  ),
                                  selected: selected,
                                  selectedColor: AppColors.taskTypeColor(type),
                                  onSelected: (sel) {
                                    if (sel)
                                      setSheetState(() => taskType = type);
                                  },
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.priority,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children:
                              ['normal', 'urgent'].map((p) {
                                final selected = p == priority;
                                return ChoiceChip(
                                  label: Text(
                                    p[0].toUpperCase() + p.substring(1),
                                  ),
                                  selected: selected,
                                  selectedColor:
                                      p == 'urgent'
                                          ? AppColors.error
                                          : AppColors.info,
                                  avatar: Icon(
                                    p == 'urgent'
                                        ? Icons.priority_high
                                        : Icons.flag_outlined,
                                    size: 16,
                                    color:
                                        selected
                                            ? Colors.white
                                            : Colors.grey.shade400,
                                  ),
                                  onSelected: (sel) {
                                    if (sel) setSheetState(() => priority = p);
                                  },
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              l10n.dependsOn,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 6),
                            if (dependsOn.isNotEmpty)
                              Text(
                                dependsOn.map((id) => '#$id').join(', '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                showDependsOn
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                              ),
                              onPressed: () async {
                                setSheetState(
                                  () => showDependsOn = !showDependsOn,
                                );
                                if (showDependsOn && openTasks == null) {
                                  final result = await ApiService.getAppTasks(
                                    appId,
                                  );
                                  if (result.ok) {
                                    const doneStatuses = {
                                      'completed',
                                      'built',
                                      'divided',
                                      'archived',
                                    };
                                    setSheetState(() {
                                      openTasks =
                                          result.data!
                                              .whereType<Map<String, dynamic>>()
                                              .where(
                                                (t) =>
                                                    t['id'] != null &&
                                                    !doneStatuses.contains(
                                                      (t['status'] ?? '')
                                                          .toString()
                                                          .toLowerCase(),
                                                    ),
                                              )
                                              .toList();
                                    });
                                  } else {
                                    setSheetState(() => openTasks = []);
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                        if (showDependsOn) ...[
                          if (openTasks == null)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          else if (openTasks!.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                l10n.noOpenTasksToDependOn,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children:
                                  openTasks!.map((t) {
                                    final id = t['id'] as int;
                                    final selected = dependsOn.contains(id);
                                    final label = '#$id ${t['title'] ?? ''}';
                                    return FilterChip(
                                      label: Text(
                                        label.length > 34
                                            ? '${label.substring(0, 32)}…'
                                            : label,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      selected: selected,
                                      selectedColor: AppColors.warning
                                          .withValues(alpha: 0.35),
                                      onSelected:
                                          (sel) => setSheetState(
                                            () =>
                                                sel
                                                    ? dependsOn.add(id)
                                                    : dependsOn.remove(id),
                                          ),
                                    );
                                  }).toList(),
                            ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          l10n.attachments,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        if (attachedFiles.isNotEmpty) ...[
                          SizedBox(
                            height: _tileSize,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: attachedFiles.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(width: 8),
                              itemBuilder:
                                  (_, i) => _stagedTile(
                                    attachedFiles[i],
                                    () => setSheetState(
                                      () => attachedFiles.removeAt(i),
                                    ),
                                  ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    HapticFeedback.lightImpact();
                                    final picked = await _pickImages();
                                    if (picked.isNotEmpty) {
                                      setSheetState(
                                        () => attachedFiles.addAll(picked),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.image_outlined,
                                    size: 18,
                                  ),
                                  label: Text(l10n.photo),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    HapticFeedback.lightImpact();
                                    final picked = await _pickPdfs();
                                    if (!ctx.mounted) return;
                                    if (picked.oversized.isNotEmpty) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l10n.fileTooLarge(
                                                _maxPdfBytes ~/ (1024 * 1024),
                                                picked.oversized.join(', ')),
                                          ),
                                          backgroundColor: AppColors.warning,
                                        ),
                                      );
                                    }
                                    if (picked.files.isNotEmpty) {
                                      setSheetState(
                                        () =>
                                            attachedFiles.addAll(picked.files),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.picture_as_pdf_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('PDF'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, footerBottom + 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed:
                          submitting
                              ? null
                              : () async {
                                HapticFeedback.lightImpact();
                                final title = titleController.text.trim();
                                if (title.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.titleIsRequired),
                                      backgroundColor: AppColors.warning,
                                    ),
                                  );
                                  return;
                                }
                                setSheetState(() => submitting = true);
                                List<String>? base64Attachments;
                                if (attachedFiles.isNotEmpty) {
                                  base64Attachments = [];
                                  for (final attachment in attachedFiles) {
                                    final bytes =
                                        await attachment.file.readAsBytes();
                                    base64Attachments.add(base64Encode(bytes));
                                  }
                                }
                                final result = await ApiService.createAppTask(
                                  appId: appId,
                                  title: title,
                                  description: descController.text.trim(),
                                  taskType: taskType,
                                  priority: priority,
                                  attachments: base64Attachments,
                                  dependsOn: dependsOn.toList()..sort(),
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        result.ok
                                            ? l10n.itemCreated
                                            : result.error ??
                                                l10n.failedToCreateItem,
                                      ),
                                      backgroundColor:
                                          result.ok
                                              ? AppColors.success
                                              : AppColors.error,
                                    ),
                                  );
                                  if (result.ok) onCreated();
                                }
                              },
                      icon:
                          submitting
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.send),
                      label: Text(submitting ? l10n.submitting : l10n.submit),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      titleController.dispose();
      descController.dispose();
    });
  }

  static Future<List<_StagedAttachment>> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 80);
    return picked
        .map(
          (x) =>
              _StagedAttachment(file: File(x.path), name: x.name, isPdf: false),
        )
        .toList();
  }

  /// Pick PDFs, splitting off any that exceed the server's size limit so the
  /// caller can tell the user which ones were dropped instead of failing the
  /// whole upload later.
  static Future<({List<_StagedAttachment> files, List<String> oversized})>
  _pickPdfs() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
      withData: false,
    );
    final files = <_StagedAttachment>[];
    final oversized = <String>[];
    for (final picked in result?.files ?? const <PlatformFile>[]) {
      final path = picked.path;
      if (path == null) continue;
      final file = File(path);
      if (await file.length() > _maxPdfBytes) {
        oversized.add(picked.name);
        continue;
      }
      files.add(_StagedAttachment(file: file, name: picked.name, isPdf: true));
    }
    return (files: files, oversized: oversized);
  }

  static Widget _stagedTile(
    _StagedAttachment attachment,
    VoidCallback onRemove,
  ) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child:
              attachment.isPdf
                  ? Container(
                    width: _tileSize,
                    height: _tileSize,
                    padding: const EdgeInsets.all(4),
                    color: AppColors.bgDark,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.picture_as_pdf,
                          size: 28,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          attachment.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  )
                  : Image.file(
                    attachment.file,
                    width: _tileSize,
                    height: _tileSize,
                    fit: BoxFit.cover,
                  ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: onRemove,
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              icon: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
