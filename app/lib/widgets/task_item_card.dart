import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../l10n/app_localizations.dart';

const String _pdfMimeType = 'application/pdf';

class TaskItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Color typeColor;
  final Color statusColor;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onFixNow;
  final VoidCallback? onDelete;
  final VoidCallback? onReset;
  final DateTime? inProgressSince;
  final void Function(int blockerId)? onBlockerTap;

  const TaskItemCard({
    super.key,
    required this.item,
    required this.typeColor,
    required this.statusColor,
    required this.isExpanded,
    required this.onTap,
    this.onFixNow,
    this.onDelete,
    this.onReset,
    this.inProgressSince,
    this.onBlockerTap,
  });

  /// Server timestamps rendered as relative ages, e.g. `created 3w ago · done 1h ago`.
  /// Prefers `completed_at` for finished tasks, otherwise `updated_at`, and
  /// omits the second part when it would just repeat the creation time.
  String _timestampLine(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context)!;
    final created = _parseServerTime(item['created_at']);
    final finished = _parseServerTime(item['completed_at']);
    final updated = _parseServerTime(item['updated_at']);
    final parts = <String>[];
    if (created != null) parts.add(l10n.createdAgo(formatRelativeAge(context, created)));
    final isFinished = _finishedStatuses.contains(status);
    if (isFinished && finished != null) {
      parts.add(status == 'failed'
          ? l10n.finishedFailedAgo(formatRelativeAge(context, finished))
          : l10n.finishedDoneAgo(formatRelativeAge(context, finished)));
    } else if (updated != null && (created == null || updated.difference(created) >= _sameMomentTolerance)) {
      parts.add(l10n.updatedAgo(formatRelativeAge(context, updated)));
    }
    return parts.join(' · ');
  }

  static const Set<String> _finishedStatuses = {'completed', 'built', 'divided', 'archived', 'failed'};
  static const Duration _sameMomentTolerance = Duration(minutes: 1);

  static DateTime? _parseServerTime(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  void _showCopyMenu(BuildContext context, String title, String description, String aiResponse) {
    final l10n = AppLocalizations.of(context)!;
    final items = <PopupMenuEntry<String>>[
      PopupMenuItem(value: 'title', child: Text(l10n.copyTitle)),
    ];
    if (description.isNotEmpty) {
      items.add(PopupMenuItem(value: 'desc', child: Text(l10n.copyDescription)));
    }
    if (aiResponse.isNotEmpty) {
      items.add(PopupMenuItem(value: 'response', child: Text(l10n.copyAiResponse)));
    }

    final RenderBox box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final size = MediaQuery.of(context).size;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + box.size.width / 2,
        offset.dy + box.size.height / 2,
        size.width - (offset.dx + box.size.width / 2),
        size.height - (offset.dy + box.size.height / 2),
      ),
      items: items,
      color: AppColors.bgCard,
    ).then((value) {
      if (value == null) return;
      String text;
      switch (value) {
        case 'title': text = title; break;
        case 'desc': text = description; break;
        case 'response': text = aiResponse; break;
        default: return;
      }
      Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.copiedToClipboard), duration: Duration(seconds: 1)),
      );
    });
  }

  /// Attachments resolved against the server base, paired with the media type
  /// the server reported. The server sends relative `/api/...` paths so they
  /// work through any tunnel host. Responses without `attachment_types` (older
  /// servers) are treated as images, which is what they were.
  List<({String url, bool isPdf})> get _attachments {
    final urls = (item['attachment_urls'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    final types = (item['attachment_types'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    return [
      for (var i = 0; i < urls.length; i++)
        (
          url: urls[i].startsWith('http')
              ? urls[i]
              : '${ApiService.baseUrl}${urls[i]}',
          isPdf: i < types.length && types[i] == _pdfMimeType,
        ),
    ];
  }

  Widget _networkImage(String url, {BoxFit fit = BoxFit.cover, double? height}) {
    return Image.network(
      url,
      headers: ApiService.authHeaders,
      height: height,
      fit: fit,
      loadingBuilder: (ctx, child, progress) => progress == null
          ? child
          : Container(
              height: height ?? 120,
              width: height ?? 120,
              alignment: Alignment.center,
              color: AppColors.bgDark,
              child: const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
      errorBuilder: (ctx, e, st) => Container(
        height: height ?? 120,
        width: height ?? 120,
        alignment: Alignment.center,
        color: AppColors.bgDark,
        child: Icon(Icons.broken_image, color: Colors.grey.shade600),
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _networkImage(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  /// A PDF cannot be rendered inline, and the API needs an auth header the
  /// system viewer cannot send — so pull the bytes down first, then hand the
  /// cached file to whatever viewer the device has.
  Future<void> _openPdf(BuildContext context, String url, int index) async {
    final l10n = AppLocalizations.of(context)!;
    HapticFeedback.lightImpact();
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Text(l10n.openingPdf),
      duration: Duration(seconds: 1),
    ));
    final result = await ApiService.downloadAttachment(
      url,
      filename: 'task_${item['id']}_$index.pdf',
    );
    if (!result.ok) {
      messenger.showSnackBar(SnackBar(
        content: Text(result.error ?? l10n.couldNotDownloadPdf),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    final opened = await OpenFilex.open(result.data!, type: _pdfMimeType);
    if (opened.type != ResultType.done) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.couldNotOpenPdf(opened.message)),
        backgroundColor: AppColors.error,
      ));
    }
  }

  /// PDF stand-in tile — icon plus a tap hint, sized like an image thumbnail.
  Widget _pdfTile(BuildContext context, {double size = 120}) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: AppColors.bgDark,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf, size: size * 0.35, color: AppColors.error),
          const SizedBox(height: 6),
          Text(l10n.openPdf,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Widget _attachmentThumb(
      BuildContext context, ({String url, bool isPdf}) attachment, int index) {
    return GestureDetector(
      onTap: () => attachment.isPdf
          ? _openPdf(context, attachment.url, index)
          : _showFullImage(context, attachment.url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: attachment.isPdf
            ? _pdfTile(context)
            : _networkImage(attachment.url, height: 120),
      ),
    );
  }

  void _showAttachmentsViewer(
      BuildContext context, List<({String url, bool isPdf})> attachments) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: PageView.builder(
            itemCount: attachments.length,
            itemBuilder: (_, i) => attachments[i].isPdf
                ? Center(
                    child: SizedBox(
                      height: 160,
                      width: 160,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            // Close the viewer first: the PDF opens in another
                            // app, and any error lands on the card's snackbar.
                            Navigator.pop(ctx);
                            _openPdf(context, attachments[i].url, i);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _pdfTile(ctx, size: 160),
                          ),
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: InteractiveViewer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _networkImage(attachments[i].url,
                            fit: BoxFit.contain),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _showBlockerMenu(BuildContext context, List<int> blockedBy) {
    final l10n = AppLocalizations.of(context)!;
    if (onBlockerTap == null || blockedBy.isEmpty) return;
    if (blockedBy.length == 1) {
      onBlockerTap!(blockedBy.first);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: blockedBy
              .map((id) => ListTile(
                    leading: const Icon(Icons.lock_outline, size: 20),
                    title: Text(l10n.blockedByTask(id)),
                    onTap: () {
                      Navigator.pop(ctx);
                      onBlockerTap!(id);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final taskId = item['id'];
    final title = item['title'] ?? '';
    final description = (item['description'] ?? '').toString().trim();
    final aiResponse = (item['ai_response'] ?? '').toString().trim();
    final taskType = (item['task_type'] ?? item['type'] ?? 'issue').toString();
    final priority = item['priority'] ?? 'normal';
    final status = item['status'] ?? 'pending';
    final agent = (item['agent'] ?? item['ai_agent'] ?? '').toString();
    final appName = (item['app_name'] ?? '').toString();
    final attachments = _attachments;
    final isArchived = item['archived'] == true;
    final blockedBy = (item['blocked_by'] as List<dynamic>?)
            ?.whereType<num>()
            .map((e) => e.toInt())
            .toList() ??
        const <int>[];
    final isBlocked = item['blocked'] == true && blockedBy.isNotEmpty;
    final timestampLine = _timestampLine(context, status.toString());

    final card = Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: () => _showCopyMenu(context, title, description, aiResponse),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 50,
                    decoration: BoxDecoration(
                      color: priority == 'urgent' ? AppColors.error : typeColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              if (taskId != null)
                                TextSpan(
                                  text: '#$taskId  ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              TextSpan(
                                text: title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          maxLines: isExpanded ? null : 2,
                          overflow: isExpanded ? null : TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                taskType,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: typeColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (priority == 'urgent')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.priority_high,
                                        size: 12, color: AppColors.error),
                                    SizedBox(width: 2),
                                    Text(
                                      l10n.urgentLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (isBlocked)
                              GestureDetector(
                                onTap: () => _showBlockerMenu(context, blockedBy),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: AppColors.warning.withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_outline,
                                          size: 12, color: AppColors.warning),
                                      const SizedBox(width: 2),
                                      Text(
                                        l10n.blockedByList(blockedBy.map((id) => '#$id').join(', ')),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (isArchived)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.inventory_2_outlined,
                                        size: 12, color: Colors.grey.shade400),
                                    const SizedBox(width: 2),
                                    Text(
                                      l10n.archivedLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade400,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (agent.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.agentColor(agent).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  agent.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.agentColor(agent),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            if (appName.isNotEmpty)
                              Text(
                                appName,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        if (timestampLine.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              timestampLine,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (status == 'in_progress') ...[
                              SizedBox(
                                width: 10, height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5, color: statusColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (inProgressSince != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ElapsedTimer(since: inProgressSince!),
                        ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ),
                ],
              ),
              // Expanded detail
              if (isExpanded) ...[
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade300, height: 1.4),
                  ),
                ],
                if (attachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: attachments.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) =>
                            _attachmentThumb(ctx, attachments[i], i),
                      ),
                    ),
                  ),
                if (aiResponse.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  if (title.toLowerCase().startsWith('code check'))
                    _buildCodeCheckResults(context, aiResponse)
                  else
                    _buildPlainAiResponse(context, aiResponse),
                ],
                if (status != 'completed') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (onFixNow != null)
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: onFixNow,
                              style: FilledButton.styleFrom(
                                backgroundColor: status == 'in_progress' || status == 'failed'
                                    ? AppColors.error
                                    : AppColors.warning,
                              ),
                              icon: Icon(
                                status == 'in_progress' || status == 'failed'
                                    ? Icons.refresh
                                    : Icons.bolt,
                                size: 18,
                              ),
                              label: Text(
                                status == 'in_progress' || status == 'failed'
                                    ? l10n.retry
                                    : l10n.workOnThis,
                              ),
                            ),
                          ),
                        ),
                      if (status == 'in_progress' && onReset != null) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: onReset,
                            icon: const Icon(Icons.restart_alt, size: 18),
                            label: Text(l10n.reset),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.warning,
                              side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5)),
                            ),
                          ),
                        ),
                      ],
                      if (onFixNow != null && onDelete != null)
                        const SizedBox(width: 8),
                      if (onDelete != null)
                        SizedBox(
                          height: 48,
                          width: 48,
                          child: IconButton(
                            onPressed: onDelete,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.error.withValues(alpha: 0.15),
                            ),
                            icon: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                          ),
                        ),
                    ],
                  ),
                ],
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _showAttachmentsViewer(context, attachments),
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: Text(
                        l10n.attachmentsCount(attachments.length),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.info,
                        side: BorderSide(color: AppColors.info.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );

    // Blocked and archived tasks read as inert: dimmed but still tappable
    // (expanding shows details; the blocked chip links to the blocker).
    if (isBlocked || isArchived) {
      return Opacity(opacity: 0.6, child: card);
    }
    return card;
  }

  Widget _buildPlainAiResponse(BuildContext context, String aiResponse) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.smart_toy, size: 14, color: AppColors.info),
            const SizedBox(width: 6),
            Text(l10n.aiResponse,
                style: TextStyle(fontSize: 12, color: AppColors.info,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          SelectableText(
            aiResponse,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade200, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCheckResults(BuildContext context, String response) {
    final l10n = AppLocalizations.of(context)!;
    final sections = _parseCodeCheckSections(l10n, response);
    if (sections.isEmpty) return _buildPlainAiResponse(context, response);

    int total = 0, criticalCount = 0, highCount = 0, mediumCount = 0;
    for (final s in sections) {
      total += s.findings.length;
      for (final f in s.findings) {
        if (f.severity == 'critical') criticalCount++;
        if (f.severity == 'high') highCount++;
        if (f.severity == 'medium') mediumCount++;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.fact_check, size: 14, color: AppColors.info),
            const SizedBox(width: 6),
            Text(l10n.codeCheckResults,
                style: TextStyle(fontSize: 12, color: AppColors.info,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(l10n.findingsCount(total),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ]),
          if (criticalCount > 0 || highCount > 0 || mediumCount > 0) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              if (criticalCount > 0)
                _severityBadge(l10n.criticalCount(criticalCount), const Color(0xFFE74C3C)),
              if (highCount > 0)
                _severityBadge(l10n.highCount(highCount), const Color(0xFFE67E22)),
              if (mediumCount > 0)
                _severityBadge(l10n.mediumCount(mediumCount), const Color(0xFFF39C12)),
            ]),
          ],
          const SizedBox(height: 12),
          ...sections.map((s) => _buildCategorySection(s)),
        ],
      ),
    );
  }

  Widget _severityBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildCategorySection(_CodeCheckSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(section.icon, size: 14, color: section.color),
            const SizedBox(width: 6),
            Text(section.name,
                style: TextStyle(fontSize: 12, color: section.color,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Text('(${section.findings.length})',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ]),
          const SizedBox(height: 6),
          ...section.findings.map((f) => _buildFindingRow(f)),
        ],
      ),
    );
  }

  Widget _buildFindingRow(_CodeCheckFinding finding) {
    final color = _severityColor(finding.severity);
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          if (finding.severity != 'info') ...[
            Container(
              margin: const EdgeInsets.only(top: 1),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(finding.severity.toUpperCase(),
                  style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: SelectableText(finding.text,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade300, height: 1.4)),
          ),
        ],
      ),
    );
  }

  static Color _severityColor(String severity) {
    switch (severity) {
      case 'critical': return const Color(0xFFE74C3C);
      case 'high': return const Color(0xFFE67E22);
      case 'medium': return const Color(0xFFF39C12);
      case 'low': return const Color(0xFF3498DB);
      default: return const Color(0xFF95A5A6);
    }
  }

  static List<_CodeCheckSection> _parseCodeCheckSections(
      AppLocalizations l10n, String response) {
    final lines = response.split('\n');
    final sections = <_CodeCheckSection>[];
    String? currentName;
    IconData currentIcon = Icons.info;
    Color currentColor = Colors.grey;
    List<_CodeCheckFinding> currentFindings = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final headerMatch = RegExp(
        r'^#{1,3}\s+(.*?)(?::?\s*$)'
        r'|^(?:\d+\.\s+)?\*\*(.*?)\*\*:?\s*$'
        r'|^([A-Z][A-Za-z &/]{2,50}):\s*$'
      ).firstMatch(trimmed);

      if (headerMatch != null) {
        final headerText = (headerMatch.group(1) ?? headerMatch.group(2) ?? headerMatch.group(3) ?? '').trim();
        if (headerText.isEmpty) continue;

        if (currentName != null && currentFindings.isNotEmpty) {
          sections.add(_CodeCheckSection(
            name: currentName, icon: currentIcon,
            color: currentColor, findings: List.from(currentFindings),
          ));
        }
        final config = _matchCategory(l10n, headerText);
        currentName = config.name;
        currentIcon = config.icon;
        currentColor = config.color;
        currentFindings = [];
        continue;
      }

      if (currentName != null) {
        String text = trimmed
            .replaceFirst(RegExp(r'^[-*\u2022]\s*'), '')
            .replaceFirst(RegExp(r'^\d+\.\s*'), '');
        if (text.isEmpty) continue;
        if (RegExp(r'^no\s+(issues?|findings?|problems?)\s+found', caseSensitive: false).hasMatch(text)) continue;

        final severity = _detectSeverity(text);
        text = text
            .replaceAll(RegExp(r'\*?\*?\[(?:CRITICAL|HIGH|MEDIUM|LOW|INFO)\]\*?\*?\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'\((?:critical|high|medium|low|info)\)\s*', caseSensitive: false), '')
            .replaceFirst(RegExp(r'^(?:CRITICAL|HIGH|MEDIUM|LOW|INFO):\s*', caseSensitive: false), '')
            .replaceFirst(RegExp(r'^Severity:\s*\w+\s*[-\u2013\u2014]\s*', caseSensitive: false), '')
            .trim();
        if (text.isNotEmpty) {
          currentFindings.add(_CodeCheckFinding(text: text, severity: severity));
        }
      }
    }

    if (currentName != null && currentFindings.isNotEmpty) {
      sections.add(_CodeCheckSection(
        name: currentName, icon: currentIcon,
        color: currentColor, findings: List.from(currentFindings),
      ));
    }
    return sections;
  }

  static String _detectSeverity(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'\bcritical\b').hasMatch(lower)) return 'critical';
    if (RegExp(r'\bhigh\b').hasMatch(lower)) return 'high';
    if (RegExp(r'\bmedium\b').hasMatch(lower)) return 'medium';
    if (RegExp(r'\blow\b').hasMatch(lower)) return 'low';
    return 'info';
  }

  static ({String name, IconData icon, Color color}) _matchCategory(
      AppLocalizations l10n, String header) {
    final lower = header.toLowerCase();
    if (RegExp(r'bug|crash|fault').hasMatch(lower)) {
      return (name: l10n.catBugsCrashes, icon: Icons.bug_report, color: const Color(0xFFE74C3C));
    }
    if (RegExp(r'secur|vulnerab|injection|xss').hasMatch(lower)) {
      return (name: l10n.categorySecurity, icon: Icons.security, color: const Color(0xFFE67E22));
    }
    if (RegExp(r'perform|speed|slow|optim|efficien').hasMatch(lower)) {
      return (name: l10n.categoryPerformance, icon: Icons.speed, color: const Color(0xFFF39C12));
    }
    if (RegExp(r'style|format|naming|convention|lint|readab').hasMatch(lower)) {
      return (name: l10n.catCodeStyle, icon: Icons.brush, color: const Color(0xFF3498DB));
    }
    if (RegExp(r'dead.?code|unused|unreachable|deprecat').hasMatch(lower)) {
      return (name: l10n.catDeadCode, icon: Icons.delete_outline, color: const Color(0xFF95A5A6));
    }
    if (RegExp(r'error.?handl|exception.?handl|try.?catch').hasMatch(lower)) {
      return (name: l10n.catErrorHandling, icon: Icons.warning_amber, color: const Color(0xFFF1C40F));
    }
    if (RegExp(r'memory|leak|dispose').hasMatch(lower)) {
      return (name: l10n.catMemory, icon: Icons.memory, color: const Color(0xFFAB47BC));
    }
    return (name: header, icon: Icons.info_outline, color: const Color(0xFF95A5A6));
  }
}

class _CodeCheckSection {
  final String name;
  final IconData icon;
  final Color color;
  final List<_CodeCheckFinding> findings;

  _CodeCheckSection({
    required this.name,
    required this.icon,
    required this.color,
    required this.findings,
  });
}

class _CodeCheckFinding {
  final String text;
  final String severity;

  _CodeCheckFinding({required this.text, required this.severity});
}

/// Human-readable age of a past moment: `just now`, `5m ago`, `3h ago`,
/// `12d ago`, `3w ago`, `4mo ago`.
String formatRelativeAge(BuildContext context, DateTime time) {
  final l10n = AppLocalizations.of(context)!;
  final diff = DateTime.now().difference(time);
  if (diff < const Duration(minutes: 1)) return l10n.timeJustNow;
  if (diff < const Duration(hours: 1)) return l10n.timeMinutesAgo(diff.inMinutes);
  if (diff < const Duration(days: 1)) return l10n.timeHoursAgo(diff.inHours);
  if (diff < const Duration(days: 14)) return l10n.timeDaysAgo(diff.inDays);
  if (diff < const Duration(days: 60)) return l10n.timeWeeksAgo(diff.inDays ~/ 7);
  return l10n.timeMonthsAgo(diff.inDays ~/ 30);
}

class ElapsedTimer extends StatefulWidget {
  final DateTime since;
  const ElapsedTimer({super.key, required this.since});

  @override
  State<ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<ElapsedTimer> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `since` is a server timestamp; a phone clock slightly behind the server
    // would otherwise yield a negative duration.
    var elapsed = DateTime.now().difference(widget.since);
    if (elapsed.isNegative) elapsed = Duration.zero;
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final text = h > 0 ? '$h:$m:$s' : '$m:$s';
    final color = elapsed.inMinutes >= 20
        ? AppColors.error
        : elapsed.inMinutes >= 10
            ? AppColors.warning
            : Colors.orange.shade300;
    final label = elapsed.inMinutes >= 20 ? l10n.stuckSuffix(text) : text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          elapsed.inMinutes >= 20 ? Icons.warning_amber : Icons.timer_outlined,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
