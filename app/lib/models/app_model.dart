class AppModel {
  final int id;
  final String name;
  final String slug;
  final String appType;
  final String projectPath;
  final String packageName;
  final String status;
  final String publishStatus;
  final String currentVersion;
  final String fixStrategy;
  final String notes;
  final int openIssues;
  final String githubUrl;
  final String playStoreUrl;
  final String websiteUrl;
  final String consoleUrl;

  AppModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.appType,
    required this.projectPath,
    required this.packageName,
    required this.status,
    required this.publishStatus,
    required this.currentVersion,
    required this.fixStrategy,
    required this.notes,
    required this.openIssues,
    required this.githubUrl,
    required this.playStoreUrl,
    required this.websiteUrl,
    required this.consoleUrl,
  });

  factory AppModel.fromJson(Map<String, dynamic> json) {
    return AppModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      appType: json['app_type'] ?? '',
      projectPath: json['project_path'] ?? '',
      packageName: json['package_name'] ?? '',
      status: json['status'] ?? 'idle',
      publishStatus: json['publish_status'] ?? '',
      currentVersion: json['current_version'] ?? '',
      fixStrategy: json['fix_strategy'] ?? '',
      notes: json['notes'] ?? '',
      openIssues: json['open_issues'] ?? 0,
      githubUrl: json['github_url'] ?? '',
      playStoreUrl: json['play_store_url'] ?? '',
      websiteUrl: json['website_url'] ?? '',
      consoleUrl: json['console_url'] ?? '',
    );
  }
}
