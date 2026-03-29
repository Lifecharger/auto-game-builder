class AutomationModel {
  final int appId;
  final String appName;
  final String appType;
  final String aiAgent;
  final int intervalMinutes;
  final int maxSessionMinutes;
  final String promptPreview;
  final bool running;
  final DateTime? startedAt;
  final DateTime? lastRunAt;
  final List<String> mcpServers;

  AutomationModel({
    required this.appId,
    required this.appName,
    required this.appType,
    required this.aiAgent,
    required this.intervalMinutes,
    required this.maxSessionMinutes,
    required this.promptPreview,
    required this.running,
    this.startedAt,
    this.lastRunAt,
    this.mcpServers = const [],
  });

  AutomationModel copyWith({List<String>? mcpServers}) {
    return AutomationModel(
      appId: appId,
      appName: appName,
      appType: appType,
      aiAgent: aiAgent,
      intervalMinutes: intervalMinutes,
      maxSessionMinutes: maxSessionMinutes,
      promptPreview: promptPreview,
      running: running,
      startedAt: startedAt,
      lastRunAt: lastRunAt,
      mcpServers: mcpServers ?? this.mcpServers,
    );
  }

  factory AutomationModel.fromJson(Map<String, dynamic> json) {
    return AutomationModel(
      appId: json['app_id'] ?? 0,
      appName: json['app_name'] ?? '',
      appType: json['app_type'] ?? '',
      aiAgent: json['ai_agent'] ?? 'claude',
      intervalMinutes: json['interval_minutes'] ?? 10,
      maxSessionMinutes: json['max_session_minutes'] ?? 18,
      promptPreview: json['prompt_preview'] ?? '',
      running: json['running'] ?? false,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString())
          : null,
      lastRunAt: json['last_run_at'] != null
          ? DateTime.tryParse(json['last_run_at'].toString())
          : null,
      mcpServers: json['mcp_servers'] != null
          ? List<String>.from(json['mcp_servers'])
          : const [],
    );
  }
}
