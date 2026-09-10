import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

/// #363 Delivery Mod: uygulamalara ne sunulacaginin ac/kapa anahtarlari.
///
/// Kurallar hotjigsaw-scanner worker'inda yasar; AGB sunucusu araci
/// (`/api/delivery/*`). Kaydet = anlik canli: worker manifesti uygulama
/// basina filtreler ve kenar onbellegini kendisi dusurur.
class DeliveryApp {
  const DeliveryApp({
    required this.package,
    required this.name,
    this.custom = false,
    this.served,
    this.total,
    this.blocked = const {},
  });
  final String package;
  final String name;
  final bool custom;       // kendi kural seti var mi (yoksa varsayilan)
  final int? served;
  final int? total;
  final Map<String, int> blocked;   // 'safety:risky' -> adet

  factory DeliveryApp.fromJson(Map<String, dynamic> j) => DeliveryApp(
        package: '${j['package'] ?? ''}',
        name: '${j['name'] ?? j['package'] ?? ''}',
        custom: j['custom'] == true,
        served: (j['served'] is num) ? (j['served'] as num).toInt() : null,
        total: (j['total'] is num) ? (j['total'] as num).toInt() : null,
        blocked: j['blocked'] is Map
            ? {for (final e in (j['blocked'] as Map).entries) '${e.key}': (e.value as num).toInt()}
            : const {},
      );
}

/// Bir kural seti: etkin / etiketsiz / alan -> deger -> acik mi.
/// Tabloda OLMAYAN deger ACIKTIR (yeni degerler sunulur, kapatana kadar).
class DeliveryRuleSet {
  DeliveryRuleSet({this.enabled = true, this.untagged = true, Map<String, Map<String, bool>>? values})
      : values = values ?? {};
  bool enabled;
  bool untagged;
  final Map<String, Map<String, bool>> values;

  factory DeliveryRuleSet.fromJson(Map? j) {
    final v = <String, Map<String, bool>>{};
    if (j?['values'] is Map) {
      for (final e in (j!['values'] as Map).entries) {
        if (e.value is Map) {
          v['${e.key}'] = {for (final x in (e.value as Map).entries) '${x.key}': x.value != false};
        }
      }
    }
    return DeliveryRuleSet(
      enabled: j?['enabled'] != false,
      untagged: j?['untagged'] != false,
      values: v,
    );
  }

  bool isOn(String field, String value) => values[field]?[value] ?? true;

  void setOn(String field, String value, bool on) {
    final t = values.putIfAbsent(field, () => {});
    if (on) {
      t.remove(value);
      if (t.isEmpty) values.remove(field);
    } else {
      t[value] = false;
    }
  }

  int offCount(String field) => (values[field] ?? const {}).values.where((x) => !x).length;

  DeliveryRuleSet copy() => DeliveryRuleSet(
      enabled: enabled,
      untagged: untagged,
      values: {for (final e in values.entries) e.key: Map<String, bool>.from(e.value)});

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'untagged': untagged,
        'values': {
          for (final e in values.entries)
            if (e.value.values.any((x) => !x))
              e.key: {for (final x in e.value.entries) if (!x.value) x.key: false},
        },
      };
}

class DeliveryOverview {
  const DeliveryOverview({
    this.worker = '',
    this.updated = 0,
    required this.defaultRules,
    required this.appRules,
    this.order = const [],
    this.labels = const {},
    this.fields = const {},
    this.total = 0,
    this.tagged = 0,
    this.untagged = 0,
    this.apps = const [],
    this.defaultServed,
    this.defaultTotal,
    this.presets = const {},
  });
  final String worker;
  final int updated;                     // ms
  final DeliveryRuleSet defaultRules;
  final Map<String, DeliveryRuleSet> appRules;
  final List<String> order;              // alan sirasi
  final Map<String, String> labels;      // alan -> Turkce etiket
  final Map<String, Map<String, int>> fields;   // alan -> deger -> adet
  final int total;
  final int tagged;
  final int untagged;
  final List<DeliveryApp> apps;
  final int? defaultServed;
  final int? defaultTotal;
  final Map<String, String> presets;     // id -> etiket

  factory DeliveryOverview.fromJson(Map<String, dynamic> j) {
    final r = j['rules'] is Map ? Map<String, dynamic>.from(j['rules'] as Map) : <String, dynamic>{};
    final v = j['values'] is Map ? Map<String, dynamic>.from(j['values'] as Map) : <String, dynamic>{};
    final fields = <String, Map<String, int>>{};
    if (v['fields'] is Map) {
      for (final e in (v['fields'] as Map).entries) {
        if (e.value is Map) {
          fields['${e.key}'] = {for (final x in (e.value as Map).entries) '${x.key}': (x.value as num).toInt()};
        }
      }
    }
    final ds = j['default_stats'] is Map ? j['default_stats'] as Map : const {};
    return DeliveryOverview(
      worker: '${j['worker'] ?? ''}',
      updated: (r['updated'] is num) ? (r['updated'] as num).toInt() : 0,
      defaultRules: DeliveryRuleSet.fromJson(r['default'] is Map ? r['default'] as Map : null),
      appRules: r['apps'] is Map
          ? {for (final e in (r['apps'] as Map).entries) '${e.key}': DeliveryRuleSet.fromJson(e.value as Map?)}
          : {},
      order: (v['order'] as List? ?? const []).map((e) => '$e').toList(),
      labels: v['labels'] is Map ? {for (final e in (v['labels'] as Map).entries) '${e.key}': '${e.value}'} : const {},
      fields: fields,
      total: (v['total'] is num) ? (v['total'] as num).toInt() : 0,
      tagged: (v['tagged'] is num) ? (v['tagged'] as num).toInt() : 0,
      untagged: (v['untagged'] is num) ? (v['untagged'] as num).toInt() : 0,
      apps: (j['apps'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => DeliveryApp.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      defaultServed: (ds['served'] is num) ? (ds['served'] as num).toInt() : null,
      defaultTotal: (ds['total'] is num) ? (ds['total'] as num).toInt() : null,
      presets: j['presets'] is Map
          ? {for (final e in (j['presets'] as Map).entries) '${e.key}': '${(e.value as Map?)?['label'] ?? e.key}'}
          : const {},
    );
  }
}

class DeliveryService {
  DeliveryService._();

  static Map<String, String> get _headers => {
        ...ApiService.authHeaders,
        'Content-Type': 'application/json',
      };

  static Future<Map<String, dynamic>> _get(String path) async {
    final r = await http
        .get(Uri.parse('${ApiService.baseUrl}$path'), headers: _headers)
        .timeout(const Duration(seconds: 150));
    if (r.statusCode >= 400) throw Exception(_detail(r));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static String _detail(http.Response r) {
    try {
      final j = jsonDecode(r.body);
      if (j is Map && j['detail'] != null) return '${j['detail']}';
    } catch (_) {}
    return 'HTTP ${r.statusCode}';
  }

  static Future<DeliveryOverview> overview() async =>
      DeliveryOverview.fromJson(await _get('/api/delivery/overview'));

  static Future<int> saveRules(
      DeliveryRuleSet def, Map<String, DeliveryRuleSet> apps) async {
    final r = await http
        .put(Uri.parse('${ApiService.baseUrl}/api/delivery/rules'),
            headers: _headers,
            body: jsonEncode({
              'default': def.toJson(),
              'apps': {for (final e in apps.entries) e.key: e.value.toJson()},
            }))
        .timeout(const Duration(seconds: 60));
    if (r.statusCode >= 400) throw Exception(_detail(r));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return (j['updated'] is num) ? (j['updated'] as num).toInt() : 0;
  }

  static Future<DeliveryRuleSet> preset(String name) async =>
      DeliveryRuleSet.fromJson(await _get('/api/delivery/preset?name=$name'));
}
