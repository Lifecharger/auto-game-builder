/// An in-game bug report / suggestion pulled from the game-reports worker.
class ReportModel {
  final String id;
  final int? appId;
  final String appName;
  final String package;
  final String category; // bug | suggestion | other
  final String message;
  final String appVersion;
  final String platform;
  final String installId;
  final int shotCount;
  final String status; // open | closed
  final String receivedAt; // epoch ms as text, from the worker
  final String pulledAt;
  final String closedAt;
  final Map<String, dynamic> meta; // device brand/model, os version, sdk, ...

  const ReportModel({
    required this.id,
    this.appId,
    this.appName = '',
    this.package = '',
    this.category = 'other',
    this.message = '',
    this.appVersion = '',
    this.platform = '',
    this.installId = '',
    this.shotCount = 0,
    this.status = 'open',
    this.receivedAt = '',
    this.pulledAt = '',
    this.closedAt = '',
    this.meta = const {},
  });

  bool get isOpen => status != 'closed';

  /// Best-effort display name for the source app.
  String get appLabel => appName.isNotEmpty ? appName : (package.isNotEmpty ? package : 'Unknown app');

  String _metaStr(String key) {
    final v = meta[key];
    return v == null ? '' : v.toString();
  }

  /// e.g. "Samsung SM-G991B" — brand/manufacturer + model, de-duplicated.
  String get deviceLabel {
    final brand = _metaStr('brand').isNotEmpty ? _metaStr('brand') : _metaStr('manufacturer');
    final model = _metaStr('model');
    final parts = <String>[];
    if (brand.isNotEmpty) parts.add(_cap(brand));
    if (model.isNotEmpty && model.toLowerCase() != brand.toLowerCase()) parts.add(model);
    return parts.join(' ');
  }

  /// e.g. "Android 14 (API 34)" or "iOS 17.2".
  String get osLabel {
    final os = _metaStr('os_version');
    final sdk = _metaStr('sdk_int');
    if (os.isEmpty) return '';
    final base = platform == 'ios' ? 'iOS $os' : 'Android $os';
    return sdk.isNotEmpty ? '$base (API $sdk)' : base;
  }

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  factory ReportModel.fromJson(Map<String, dynamic> j) => ReportModel(
        id: (j['id'] ?? '').toString(),
        appId: j['app_id'] is int ? j['app_id'] as int : null,
        appName: (j['app_name'] ?? '').toString(),
        package: (j['package'] ?? '').toString(),
        category: (j['category'] ?? 'other').toString(),
        message: (j['message'] ?? '').toString(),
        appVersion: (j['app_version'] ?? '').toString(),
        platform: (j['platform'] ?? '').toString(),
        installId: (j['install_id'] ?? '').toString(),
        shotCount: _asInt(j['shot_count']),
        status: (j['status'] ?? 'open').toString(),
        receivedAt: (j['received_at'] ?? '').toString(),
        pulledAt: (j['pulled_at'] ?? '').toString(),
        closedAt: (j['closed_at'] ?? '').toString(),
        meta: (j['meta'] is Map) ? Map<String, dynamic>.from(j['meta'] as Map) : const {},
      );
}
