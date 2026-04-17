class BuildModel {
  final int id;
  final int appId;
  final String buildType;
  final String status;
  final String version;
  final String startedAt;
  final String? completedAt;
  final String? appName;

  BuildModel({
    required this.id,
    required this.appId,
    required this.buildType,
    required this.status,
    required this.version,
    required this.startedAt,
    this.completedAt,
    this.appName,
  });

  factory BuildModel.fromJson(Map<String, dynamic> json) {
    return BuildModel(
      id: json['id'] ?? 0,
      appId: json['app_id'] ?? 0,
      buildType: json['build_type'] ?? '',
      status: json['status'] ?? '',
      version: json['version'] ?? '',
      startedAt: json['started_at'] ?? '',
      completedAt: json['completed_at'],
      appName: json['app_name'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'app_id': appId,
        'build_type': buildType,
        'status': status,
        'version': version,
        'started_at': startedAt,
        'completed_at': completedAt,
        'app_name': appName,
      };
}
