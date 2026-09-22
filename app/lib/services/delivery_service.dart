import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

/// #363 Delivery Mod: uygulamalara ne sunulacaginin ac/kapa anahtarlari.
///
/// Kurallar dagitim worker'inda yasar; AGB sunucusu araci
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
    this.hiddenCollections = const [],
  });
  final String package;
  final String name;
  final bool custom;       // kendi kural seti var mi (yoksa varsayilan)
  final int? served;
  final int? total;
  final Map<String, int> blocked;   // 'safety:risky' -> adet
  final List<String> hiddenCollections;   // kapsam disi kalan koleksiyon id'leri

  factory DeliveryApp.fromJson(Map<String, dynamic> j) => DeliveryApp(
        package: '${j['package'] ?? ''}',
        name: '${j['name'] ?? j['package'] ?? ''}',
        custom: j['custom'] == true,
        served: (j['served'] is num) ? (j['served'] as num).toInt() : null,
        total: (j['total'] is num) ? (j['total'] as num).toInt() : null,
        blocked: j['blocked'] is Map
            ? {for (final e in (j['blocked'] as Map).entries) '${e.key}': (e.value as num).toInt()}
            : const {},
        hiddenCollections: j['collections'] is Map
            ? [for (final x in ((j['collections'] as Map)['hidden'] as List? ?? const [])) '$x']
            : const [],
      );
}

/// Kart katalogundaki bir koleksiyon - kapsam kutucuklarinin kaynagi.
class DeliveryCollection {
  const DeliveryCollection({required this.id, required this.name, this.cards = 0});
  final String id;
  final String name;
  final int cards;

  factory DeliveryCollection.fromJson(Map j) => DeliveryCollection(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? j['id'] ?? ''}',
        cards: (j['cards'] is num) ? (j['cards'] as num).toInt() : 0,
      );
}

/// Bir kural seti: etkin / etiketsiz / alan -> deger -> acik mi.
/// Tabloda OLMAYAN deger ACIKTIR (yeni degerler sunulur, kapatana kadar).
class DeliveryRuleSet {
  DeliveryRuleSet({this.enabled = true, this.untagged = true, Map<String, Map<String, bool>>? values,
      this.scopeOnly = false, Set<String>? collections})
      : values = values ?? {},
        collections = collections ?? <String>{};
  bool enabled;
  bool untagged;
  final Map<String, Map<String, bool>> values;

  /// Kart havuzu: uygulama YALNIZ [collections] koleksiyonlarini gorsun mu?
  ///
  /// Kapali (varsayilan) = manifest'teki her koleksiyon gider, sonradan
  /// yayinlananlar dahil. Acik = liste sabittir; yeni bir koleksiyon bu
  /// uygulamaya kendiliginden GECMEZ, birisi id'sini buraya ekleyene kadar.
  bool scopeOnly;
  final Set<String> collections;

  factory DeliveryRuleSet.fromJson(Map? j) {
    final v = <String, Map<String, bool>>{};
    if (j?['values'] is Map) {
      for (final e in (j!['values'] as Map).entries) {
        if (e.value is Map) {
          v['${e.key}'] = {for (final x in (e.value as Map).entries) '${x.key}': x.value != false};
        }
      }
    }
    final k = j?['collections'] is Map ? j!['collections'] as Map : const {};
    return DeliveryRuleSet(
      enabled: j?['enabled'] != false,
      untagged: j?['untagged'] != false,
      values: v,
      scopeOnly: k['mode'] == 'only',
      collections: {for (final x in (k['ids'] as List? ?? const [])) '$x'},
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
      values: {for (final e in values.entries) e.key: Map<String, bool>.from(e.value)},
      scopeOnly: scopeOnly,
      collections: Set<String>.from(collections));

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'untagged': untagged,
        'values': {
          for (final e in values.entries)
            if (e.value.values.any((x) => !x))
              e.key: {for (final x in e.value.entries) if (!x.value) x.key: false},
        },
        'collections': {
          'mode': scopeOnly && collections.isNotEmpty ? 'only' : 'all',
          'ids': scopeOnly ? collections.toList() : const <String>[],
        },
      };
}

/// #385 Engel listesi: kurallar ALANLARA gore filtreler, bu liste TEK TEK
/// ogeyi kapatir (resim / koleksiyon / kart / deste / sunucu seviyesi).
/// Bir uygulamanin gordugu engel = `global` + o uygulamanin listesi.
class DeliveryBlock {
  DeliveryBlock({this.updated = 0, Map<String, Set<String>>? global,
      Map<String, Map<String, Set<String>>>? apps, this.lists = const []})
      : global = global ?? {},
        apps = apps ?? {};
  int updated;                                   // ms
  final Map<String, Set<String>> global;         // liste adi -> id'ler
  final Map<String, Map<String, Set<String>>> apps;  // paket -> liste adi -> id'ler
  final List<String> lists;                      // bu havuzda anlamli liste adlari

  static Map<String, Set<String>> _lists(Map? j) => {
        for (final e in (j ?? const {}).entries)
          if (e.value is List) '${e.key}': {for (final x in (e.value as List)) '$x'},
      };

  /// Worker govdesi beklenenden farkli gelirse (eski surum, hata cevabi) sekli
  /// ZORLAMAZ: o alan bos kalir. Engel listesinin cokmesi, filtrenin tamamen
  /// kaybolmasi demek olurdu.
  factory DeliveryBlock.fromJson(Map? j) => DeliveryBlock(
        updated: (j?['updated'] is num) ? (j!['updated'] as num).toInt() : 0,
        global: _lists(j?['global'] is Map ? j!['global'] as Map : null),
        apps: {
          for (final e in ((j?['apps'] is Map ? j!['apps'] as Map : const {})).entries)
            '${e.key}': _lists(e.value is Map ? e.value as Map : null),
        },
        lists: [for (final x in ((j?['lists'] as List?) ?? const [])) '$x'],
      );

  /// '' = global, aksi halde paket adi.
  Map<String, Set<String>> forApp(String app) =>
      app.isEmpty ? global : apps.putIfAbsent(app, () => {});

  bool isBlocked(String app, String list, String id) =>
      (global[list] ?? const {}).contains(id) ||
      (app.isNotEmpty && ((apps[app] ?? const {})[list] ?? const {}).contains(id));

  /// Bir listedeki ogeyi ac/kapa; global kapali ise uygulama kaydi yazilmaz.
  void toggle(String app, String list, String id, bool blocked) {
    final t = forApp(app).putIfAbsent(list, () => <String>{});
    if (blocked) {
      t.add(id);
    } else {
      t.remove(id);
    }
  }

  int count(String app) =>
      forApp(app).values.fold<int>(0, (a, b) => a + b.length);

  DeliveryBlock copy() => DeliveryBlock(
      updated: updated,
      global: {for (final e in global.entries) e.key: Set<String>.from(e.value)},
      apps: {
        for (final e in apps.entries)
          e.key: {for (final x in e.value.entries) x.key: Set<String>.from(x.value)},
      },
      lists: List<String>.from(lists));

  Map<String, dynamic> toJson() => {
        'global': {for (final e in global.entries) e.key: e.value.toList()},
        'apps': {
          for (final e in apps.entries)
            if (e.value.values.any((x) => x.isNotEmpty))
              e.key: {for (final x in e.value.entries) x.key: x.value.toList()},
        },
      };
}

/// Engel tarayicisinin bir satiri: koleksiyon / deste / host grubu + ogeleri.
class DeliveryCatalogItem {
  const DeliveryCatalogItem({required this.id, required this.name, this.kind = '',
      this.count = 0, this.tagged = 0, this.cover, this.images = const []});
  final String id;
  final String name;
  final String kind;
  final int count;
  final int tagged;
  final String? cover;
  final List<DeliveryCatalogEntry> images;

  factory DeliveryCatalogItem.fromJson(Map j) => DeliveryCatalogItem(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? j['id'] ?? ''}',
        kind: '${j['kind'] ?? ''}',
        count: (j['count'] is num) ? (j['count'] as num).toInt() : 0,
        tagged: (j['tagged'] is num) ? (j['tagged'] as num).toInt() : 0,
        cover: j['cover'] is String ? j['cover'] as String : null,
        images: [
          for (final x in ((j['images'] as List?) ?? const []).whereType<Map>())
            DeliveryCatalogEntry.fromJson(x),
        ],
      );
}

class DeliveryCatalogEntry {
  const DeliveryCatalogEntry({required this.id, required this.name, this.cover, this.tagged = true});
  final String id;       // engel listesine yazilan kimlik
  final String name;
  final String? cover;
  final bool tagged;

  factory DeliveryCatalogEntry.fromJson(Map j) => DeliveryCatalogEntry(
        id: '${j['id'] ?? j['name'] ?? ''}',
        name: '${j['name'] ?? j['id'] ?? ''}',
        cover: (j['cover'] ?? j['url']) is String ? '${j['cover'] ?? j['url']}' : null,
        tagged: j['tagged'] != false,
      );
}

/// #385 Normalizer: bir havuzun etiketleme durumu ve son raporu.
class NormalizePool {
  const NormalizePool({required this.pool, this.label = '', this.index = '', this.bucket = '',
      this.running = false, this.opId = '', this.done = 0, this.total = 0, this.message = '',
      this.last = const {}});
  final String pool;
  final String label;
  final String index;      // bu havuzun indeks mekanizmasi (rapor icin)
  final String bucket;
  final bool running;
  final String opId;
  final int done;
  final int total;
  final String message;
  final Map<String, dynamic> last;   // son rapor

  factory NormalizePool.fromJson(String pool, Map j) {
    final op = j['op'] is Map ? j['op'] as Map : const {};
    return NormalizePool(
      pool: pool,
      label: '${j['label'] ?? pool}',
      index: '${j['index'] ?? ''}',
      bucket: '${j['bucket'] ?? ''}',
      running: j['running'] == true,
      opId: '${op['id'] ?? ''}',
      done: (op['done'] is num) ? (op['done'] as num).toInt() : 0,
      total: (op['total'] is num) ? (op['total'] as num).toInt() : 0,
      message: '${op['message'] ?? ''}',
      last: j['last'] is Map ? Map<String, dynamic>.from(j['last'] as Map) : const {},
    );
  }

  /// "3 gecerli, 12 etiketlendi, 1 basarisiz" - son raporun tek satiri.
  String get summary {
    if (last.isEmpty) return 'hic calismadi';
    int n(String k) => (last[k] is num) ? (last[k] as num).toInt() : 0;
    final d = last['dry_run'] == true ? ' (deneme)' : '';
    return '${last['status'] ?? '?'}$d · ${n('total')} gorsel, ${n('valid')} gecerli, '
        '${n('tagged')} etiketlendi, ${n('failed')} basarisiz';
  }
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
    this.collections = const [],
    this.block,
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
  final List<DeliveryCollection> collections;   // kart havuzu: yayindaki koleksiyonlar
  final DeliveryBlock? block;            // #385 engel listesi (worker'dan)

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
      collections: (j['collections'] as List? ?? const [])
          .whereType<Map>()
          .map(DeliveryCollection.fromJson)
          .toList(),
      block: j['block'] is Map ? DeliveryBlock.fromJson(j['block'] as Map) : null,
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

  static Future<DeliveryOverview> overview({String pool = 'jigsaw'}) async =>
      DeliveryOverview.fromJson(await _get('/api/delivery/overview?pool=$pool'));

  static Future<int> saveRules(
      DeliveryRuleSet def, Map<String, DeliveryRuleSet> apps, {String pool = 'jigsaw'}) async {
    final r = await http
        .put(Uri.parse('${ApiService.baseUrl}/api/delivery/rules?pool=$pool'),
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

  /// #363b: bucket'ta EXIF'i degisen gorselleri yeniden okut. `names` bos ve
  /// `all` true = butun havuz (50'lik partiler, sunucu gezer).
  static Future<Map<String, dynamic>> reindex(
      {List<String> names = const [], bool all = false, String collection = 'generic'}) async {
    final r = await http
        .post(Uri.parse('${ApiService.baseUrl}/api/delivery/reindex'),
            headers: _headers,
            body: jsonEncode({'collection': collection, 'names': names, 'all': all}))
        .timeout(const Duration(minutes: 10));
    if (r.statusCode >= 400) throw Exception(_detail(r));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<DeliveryRuleSet> preset(String name) async =>
      DeliveryRuleSet.fromJson(await _get('/api/delivery/preset?name=$name'));

  // ------------------------------------------------------------ #385 engel
  static Future<DeliveryBlock> block({String pool = 'jigsaw'}) async =>
      DeliveryBlock.fromJson(await _get('/api/delivery/block?pool=$pool'));

  /// Engel listesini worker'a yazar; donen deger yeni `updated` damgasi.
  static Future<int> saveBlock(DeliveryBlock b, {String pool = 'jigsaw'}) async {
    final r = await http
        .put(Uri.parse('${ApiService.baseUrl}/api/delivery/block?pool=$pool'),
            headers: _headers, body: jsonEncode(b.toJson()))
        .timeout(const Duration(seconds: 60));
    if (r.statusCode >= 400) throw Exception(_detail(r));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return (j['updated'] is num) ? (j['updated'] as num).toInt() : 0;
  }

  /// Engel tarayicisinin listesi (koleksiyon / deste / host + ogeleri).
  static Future<List<DeliveryCatalogItem>> catalog({String pool = 'jigsaw'}) async {
    final j = await _get('/api/delivery/catalog?pool=$pool');
    return [
      for (final x in ((j['items'] as List?) ?? const []).whereType<Map>())
        DeliveryCatalogItem.fromJson(x),
    ];
  }

  // -------------------------------------------------------- #385 normalize
  static Future<List<NormalizePool>> normalizeStatus() async {
    final j = await _get('/api/normalize/status');
    final p = j['pools'] is Map ? j['pools'] as Map : const {};
    return [
      for (final e in p.entries)
        if (e.value is Map) NormalizePool.fromJson('${e.key}', e.value as Map),
    ];
  }

  /// Havuzu normalize etmeye baslar; donen deger op kimligi.
  static Future<String> normalizeRun(String pool, {bool dryRun = false}) async {
    final r = await http
        .post(Uri.parse('${ApiService.baseUrl}/api/normalize/run'),
            headers: _headers, body: jsonEncode({'pool': pool, 'dry_run': dryRun}))
        .timeout(const Duration(minutes: 5));
    if (r.statusCode >= 400) throw Exception(_detail(r));
    return '${(jsonDecode(r.body) as Map)['op'] ?? ''}';
  }

  static Future<void> normalizeCancel(String opId) async {
    final r = await http
        .post(Uri.parse('${ApiService.baseUrl}/api/normalize/cancel?op_id=$opId'), headers: _headers)
        .timeout(const Duration(seconds: 60));
    if (r.statusCode >= 400) throw Exception(_detail(r));
  }
}
