import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme.dart';

class CreateTaskSheet {
  static void show({
    required BuildContext context,
    required int appId,
    required VoidCallback onCreated,
  }) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String taskType = 'issue';
    String priority = 'normal';
    bool submitting = false;
    List<File> attachedImages = [];

    showModalBottomSheet(
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
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: mq.viewInsets.bottom + mq.padding.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const Text(
                      'New Item',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        hintText: 'Title',
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Description...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Type',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['issue', 'bug', 'fix', 'feature', 'idea'].map((type) {
                        final selected = type == taskType;
                        return ChoiceChip(
                          label: Text(type[0].toUpperCase() + type.substring(1)),
                          selected: selected,
                          selectedColor: AppColors.taskTypeColor(type),
                          onSelected: (sel) {
                            if (sel) setSheetState(() => taskType = type);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Priority',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['normal', 'urgent'].map((p) {
                        final selected = p == priority;
                        return ChoiceChip(
                          label: Text(p[0].toUpperCase() + p.substring(1)),
                          selected: selected,
                          selectedColor:
                              p == 'urgent' ? AppColors.error : AppColors.info,
                          avatar: Icon(
                            p == 'urgent'
                                ? Icons.priority_high
                                : Icons.flag_outlined,
                            size: 16,
                            color: selected
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
                    const Text('Attachments',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (attachedImages.isNotEmpty)
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: attachedImages.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(attachedImages[i].path),
                                  width: 80,
                                  height: 80,
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
                                    onPressed: () => setSheetState(() => attachedImages.removeAt(i)),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black54,
                                    ),
                                    icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (attachedImages.isNotEmpty)
                      const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        final picker = ImagePicker();
                        final picked = await picker.pickMultiImage(imageQuality: 80);
                        if (picked.isNotEmpty) {
                          setSheetState(() {
                            attachedImages.addAll(picked.map((x) => File(x.path)));
                          });
                        }
                      },
                      icon: const Icon(Icons.attach_file),
                      label: Text(attachedImages.isEmpty ? 'Add Photo' : 'Add More'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: submitting
                            ? null
                            : () async {
                                HapticFeedback.lightImpact();
                                final title = titleController.text.trim();
                                if (title.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Title is required'),
                                      backgroundColor: AppColors.warning,
                                    ),
                                  );
                                  return;
                                }
                                setSheetState(() => submitting = true);
                                List<String>? base64Attachments;
                                if (attachedImages.isNotEmpty) {
                                  base64Attachments = [];
                                  for (final img in attachedImages) {
                                    final bytes = await File(img.path).readAsBytes();
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
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(result.ok
                                          ? 'Item created'
                                          : result.error ?? 'Failed to create item'),
                                      backgroundColor:
                                          result.ok ? AppColors.success : AppColors.error,
                                    ),
                                  );
                                  if (result.ok) onCreated();
                                }
                              },
                        icon: submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        label: Text(submitting ? 'Submitting...' : 'Submit'),
                      ),
                    ),
                  ],
                ),
              );
          },
        );
      },
    ).whenComplete(() {
      titleController.dispose();
      descController.dispose();
    });
  }
}
