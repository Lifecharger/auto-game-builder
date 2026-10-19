/// A note for the owner left by an automation (weekly report, Play review
/// replies, ...). Not app work (tasks) and not a player report.
class NoticeModel {
  final int id;
  final String source; // weekly_report | play_reviews | ...
  final String title;
  final String body;
  final bool read;
  final String createdAt; // SQLite 'YYYY-MM-DD HH:MM:SS', UTC
  final String updatedAt;

  const NoticeModel({
    required this.id,
    this.source = '',
    this.title = '',
    this.body = '',
    this.read = false,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory NoticeModel.fromJson(Map<String, dynamic> j) => NoticeModel(
        id: (j['id'] as num?)?.toInt() ?? 0,
        source: j['source'] as String? ?? '',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        read: j['read'] == true,
        createdAt: j['created_at'] as String? ?? '',
        updatedAt: j['updated_at'] as String? ?? '',
      );

  /// Last change (a rerun replaces the note), as local time.
  DateTime? get when {
    final s = updatedAt.isNotEmpty ? updatedAt : createdAt;
    if (s.isEmpty) return null;
    return DateTime.tryParse('${s.replaceFirst(' ', 'T')}Z')?.toLocal();
  }
}
