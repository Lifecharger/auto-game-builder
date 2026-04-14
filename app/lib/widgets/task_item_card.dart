import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

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
  });

  void _showCopyMenu(BuildContext context, String title, String description, String aiResponse) {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(value: 'title', child: Text('Copy Title')),
    ];
    if (description.isNotEmpty) {
      items.add(const PopupMenuItem(value: 'desc', child: Text('Copy Description')));
    }
    if (aiResponse.isNotEmpty) {
      items.add(const PopupMenuItem(value: 'response', child: Text('Copy AI Response')));
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
        const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
      );
    });
  }

  void _showFullImage(BuildContext context, Uint8List bytes) {
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
              child: Image.memory(bytes),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskId = item['id'];
    final title = item['title'] ?? '';
    final description = (item['description'] ?? '').toString().trim();
    final aiResponse = (item['ai_response'] ?? '').toString().trim();
    final taskType = (item['task_type'] ?? item['type'] ?? 'issue').toString();
    final priority = item['priority'] ?? 'normal';
    final status = item['status'] ?? 'pending';
    final agent = (item['agent'] ?? item['ai_agent'] ?? '').toString();
    final appName = (item['app_name'] ?? '').toString();
    final attachments = (item['attachments'] as List<dynamic>?)
        ?.whereType<String>()
        .toList();

    return Card(
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
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.priority_high,
                                        size: 12, color: AppColors.error),
                                    SizedBox(width: 2),
                                    Text(
                                      'urgent',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.error,
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
                if (attachments != null && attachments.isNotEmpty) ...[
                  () {
                    final decoded = <Uint8List>[];
                    for (final a in attachments) {
                      try { decoded.add(base64Decode(a)); } catch (e) { debugPrint('Failed to decode attachment: $e'); }
                    }
                    if (decoded.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: decoded.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (ctx, i) {
                            final bytes = decoded[i];
                            return GestureDetector(
                              onTap: () => _showFullImage(ctx, bytes),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(bytes, height: 120, fit: BoxFit.cover),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }(),
                ],
                if (aiResponse.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  if (title.toLowerCase().startsWith('code check'))
                    _buildCodeCheckResults(aiResponse)
                  else
                    _buildPlainAiResponse(aiResponse),
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
                                    ? 'Retry'
                                    : 'Work on This',
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
                            label: const Text('Reset'),
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
                            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlainAiResponse(String aiResponse) {
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
            Text('AI Response',
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

  Widget _buildCodeCheckResults(String response) {
    final sections = _parseCodeCheckSections(response);
    if (sections.isEmpty) return _buildPlainAiResponse(response);

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
            Text('Code Check Results',
                style: TextStyle(fontSize: 12, color: AppColors.info,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('$total finding${total == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ]),
          if (criticalCount > 0 || highCount > 0 || mediumCount > 0) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              if (criticalCount > 0)
                _severityBadge('$criticalCount critical', const Color(0xFFE74C3C)),
              if (highCount > 0)
                _severityBadge('$highCount high', const Color(0xFFE67E22)),
              if (mediumCount > 0)
                _severityBadge('$mediumCount medium', const Color(0xFFF39C12)),
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

  static List<_CodeCheckSection> _parseCodeCheckSections(String response) {
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
        final config = _matchCategory(headerText);
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

  static ({String name, IconData icon, Color color}) _matchCategory(String header) {
    final lower = header.toLowerCase();
    if (RegExp(r'bug|crash|fault').hasMatch(lower)) {
      return (name: 'Bugs & Crashes', icon: Icons.bug_report, color: const Color(0xFFE74C3C));
    }
    if (RegExp(r'secur|vulnerab|injection|xss').hasMatch(lower)) {
      return (name: 'Security', icon: Icons.security, color: const Color(0xFFE67E22));
    }
    if (RegExp(r'perform|speed|slow|optim|efficien').hasMatch(lower)) {
      return (name: 'Performance', icon: Icons.speed, color: const Color(0xFFF39C12));
    }
    if (RegExp(r'style|format|naming|convention|lint|readab').hasMatch(lower)) {
      return (name: 'Code Style', icon: Icons.brush, color: const Color(0xFF3498DB));
    }
    if (RegExp(r'dead.?code|unused|unreachable|deprecat').hasMatch(lower)) {
      return (name: 'Dead Code', icon: Icons.delete_outline, color: const Color(0xFF95A5A6));
    }
    if (RegExp(r'error.?handl|exception.?handl|try.?catch').hasMatch(lower)) {
      return (name: 'Error Handling', icon: Icons.warning_amber, color: const Color(0xFFF1C40F));
    }
    if (RegExp(r'memory|leak|dispose').hasMatch(lower)) {
      return (name: 'Memory', icon: Icons.memory, color: const Color(0xFFAB47BC));
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

class ElapsedTimer extends StatefulWidget {
  final DateTime since;
  const ElapsedTimer({super.key, required this.since});

  @override
  State<ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<ElapsedTimer> {
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
    final elapsed = DateTime.now().difference(widget.since);
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final text = h > 0 ? '$h:$m:$s' : '$m:$s';
    final color = elapsed.inMinutes >= 20
        ? AppColors.error
        : elapsed.inMinutes >= 10
            ? AppColors.warning
            : Colors.orange.shade300;
    final label = elapsed.inMinutes >= 20 ? '$text STUCK' : text;
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
