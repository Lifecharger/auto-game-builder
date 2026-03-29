class IssueModel {
  final int id;
  final int appId;
  final int priority;
  final String title;
  final String description;
  final String category;
  final String status;
  final String source;
  final String assignedAi;
  final String createdAt;
  final String? appName;

  IssueModel({
    required this.id,
    required this.appId,
    required this.priority,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.source,
    required this.assignedAi,
    required this.createdAt,
    this.appName,
  });

  factory IssueModel.fromJson(Map<String, dynamic> json) {
    return IssueModel(
      id: json['id'] ?? 0,
      appId: json['app_id'] ?? 0,
      priority: json['priority'] ?? 3,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      status: json['status'] ?? 'open',
      source: json['source'] ?? '',
      assignedAi: json['assigned_ai'] ?? '',
      createdAt: json['created_at'] ?? '',
      appName: json['app_name'],
    );
  }
}
