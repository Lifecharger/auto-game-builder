import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

/// #381 Kovalar: R2 kovalarinin kendisi (yerel klasorler degil).
///
/// Sunucu araci `/api/r2/*`; is mantigi AGB sunucusunda (core/r2_control.py),
/// erisim bilgisi hicbir zaman telefona inmez. Onizleme ISTEK UZERINE alinir:
/// video / hareketli webp / 2 MB ustu nesne indirilmez, satir ikon + boyut
/// gosterir (sayacli hat).
class R2Bucket {
  const R2Bucket({
    required this.name,
    this.filesDomain = '',
    this.worker = '',
    this.role = 'content',
    this.holds = '',
    this.layout = '',
    this.twin = '',
    this.twinMap = const [],
    this.legacyPrefixes = const [],
    this.objects,
    this.bytes,
    this.countedAt = '',
  });
  final String name;
  final String filesDomain;
  final String worker;
  final String role;          // content | private | legacy
  final String holds;
  final String layout;
  final String twin;          // ikiz kova(lar)
  final List<R2TwinRule> twinMap;
  final List<String> legacyPrefixes;
  final int? objects;
  final int? bytes;
  final String countedAt;

  bool get isLegacy => role == 'legacy';
  bool get isPrivate => role == 'private';

  factory R2Bucket.fromJson(Map<String, dynamic> j) => R2Bucket(
        name: '${j['name'] ?? ''}',
        filesDomain: '${j['files_domain'] ?? ''}',
        worker: '${j['worker'] ?? ''}',
        role: '${j['role'] ?? 'content'}',
        holds: '${j['holds'] ?? ''}',
        layout: '${j['layout'] ?? ''}',
        twin: '${j['twin'] ?? ''}',
        twinMap: (j['twin_map'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => R2TwinRule.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        legacyPrefixes:
            (j['legacy_prefixes'] as List? ?? const []).map((e) => '$e').toList(),
        objects: (j['objects'] is num) ? (j['objects'] as num).toInt() : null,
        bytes: (j['bytes'] is num) ? (j['bytes'] as num).toInt() : null,
        countedAt: '${j['counted_at'] ?? ''}',
      );
}

class R2TwinRule {
  const R2TwinRule({required this.bucket, required this.from, required this.to});
  final String bucket;
  final String from;
  final String to;

  factory R2TwinRule.fromJson(Map<String, dynamic> j) => R2TwinRule(
        bucket: '${j['bucket'] ?? ''}',
        from: '${j['from'] ?? ''}',
        to: '${j['to'] ?? ''}',
      );
}

class R2Registry {
  const R2Registry({this.buckets = const [], this.legacyRetiresOn = ''});
  final List<R2Bucket> buckets;
  final String legacyRetiresOn;

  factory R2Registry.fromJson(Map<String, dynamic> j) => R2Registry(
        buckets: (j['buckets'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => R2Bucket.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        legacyRetiresOn: '${j['legacy_retires_on'] ?? ''}',
      );
}

class R2Object {
  const R2Object({
    required this.key,
    required this.name,
    required this.size,
    this.lastModified = '',
    this.etag = '',
    this.url = '',
    this.preview = false,
  });
  final String key;
  final String name;
  final int size;
  final String lastModified;
  final String etag;
  final String url;

  /// Sunucu bu satirin onizlemesini vermeye deger buldu mu (kucuk duragan
  /// gorsel). false ise istemci THUMB'I HIC ISTEMEZ - ikon + boyut gosterir.
  final bool preview;

  factory R2Object.fromJson(Map<String, dynamic> j) => R2Object(
        key: '${j['key'] ?? ''}',
        name: '${j['name'] ?? j['key'] ?? ''}',
        size: (j['size'] is num) ? (j['size'] as num).toInt() : 0,
        lastModified: '${j['last_modified'] ?? ''}',
        etag: '${j['etag'] ?? ''}',
        url: '${j['url'] ?? ''}',
        preview: j['preview'] == true,
      );
}

class R2Listing {
  const R2Listing({
    required this.bucket,
    required this.prefix,
    this.folders = const [],
    this.objects = const [],
    this.cursor = '',
    this.truncated = false,
  });
  final String bucket;
  final String prefix;
  final List<R2Folder> folders;
  final List<R2Object> objects;
  final String cursor;
  final bool truncated;

  factory R2Listing.fromJson(Map<String, dynamic> j) => R2Listing(
        bucket: '${j['bucket'] ?? ''}',
        prefix: '${j['prefix'] ?? ''}',
        folders: (j['folders'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => R2Folder(
                prefix: '${e['prefix'] ?? ''}', name: '${e['name'] ?? ''}'))
            .toList(),
        objects: (j['objects'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => R2Object.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        cursor: '${j['cursor'] ?? ''}',
        truncated: j['truncated'] == true,
      );
}

class R2Folder {
  const R2Folder({required this.prefix, required this.name});
  final String prefix;
  final String name;
}

/// Bir nesnenin basliklari + onbellek standardina uygunlugu + ikiz anahtari.
class R2Head {
  const R2Head({
    required this.key,
    required this.size,
    this.etag = '',
    this.lastModified = '',
    this.contentType = '',
    this.cacheControl = '',
    this.url = '',
    this.headerKind = 'asset',
    this.headerOk = true,
    this.headerExpected = '',
    this.twinBucket = '',
    this.twinKey = '',
  });
  final String key;
  final int size;
  final String etag;
  final String lastModified;
  final String contentType;
  final String cacheControl;
  final String url;
  final String headerKind;     // asset | json | mutable
  final bool headerOk;
  final String headerExpected;
  final String twinBucket;
  final String twinKey;

  factory R2Head.fromJson(Map<String, dynamic> j) {
    final h = j['header'] is Map ? Map<String, dynamic>.from(j['header'] as Map) : const {};
    return R2Head(
      key: '${j['key'] ?? ''}',
      size: (j['size'] is num) ? (j['size'] as num).toInt() : 0,
      etag: '${j['etag'] ?? ''}',
      lastModified: '${j['last_modified'] ?? ''}',
      contentType: '${j['content_type'] ?? ''}',
      cacheControl: '${j['cache_control'] ?? ''}',
      url: '${j['url'] ?? ''}',
      headerKind: '${h['kind'] ?? 'asset'}',
      headerOk: h['ok'] != false,
      headerExpected: '${h['expected'] ?? ''}',
      twinBucket: '${j['twin_bucket'] ?? ''}',
      twinKey: '${j['twin_key'] ?? ''}',
    );
  }
}

/// Silme/takedown onay penceresinin gosterdigi plan: hangi kovada hangi
/// anahtarlar. Kullanici bunu gormeden onay yazmaz.
class R2DeletePlan {
  const R2DeletePlan({
    required this.bucket,
    this.keys = const [],
    this.twins = const [],
    this.unmapped = const [],
    this.limit = 500,
  });
  final String bucket;
  final List<String> keys;
  final List<R2BucketKeys> twins;
  final List<String> unmapped;
  final int limit;

  int get totalKeys =>
      keys.length + twins.fold<int>(0, (a, t) => a + t.keys.length);

  factory R2DeletePlan.fromJson(Map<String, dynamic> j) => R2DeletePlan(
        bucket: '${j['bucket'] ?? ''}',
        keys: (j['keys'] as List? ?? const []).map((e) => '$e').toList(),
        twins: (j['twins'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => R2BucketKeys(
                  bucket: '${e['bucket'] ?? ''}',
                  keys: (e['keys'] as List? ?? const []).map((x) => '$x').toList(),
                ))
            .toList(),
        unmapped: (j['unmapped'] as List? ?? const []).map((e) => '$e').toList(),
        limit: (j['limit'] is num) ? (j['limit'] as num).toInt() : 500,
      );
}

class R2BucketKeys {
  const R2BucketKeys({required this.bucket, required this.keys});
  final String bucket;
  final List<String> keys;
}

/// Arka plan islemi - akis op'lariyla ayni govde.
class R2Op {
  const R2Op({
    required this.id,
    this.kind = '',
    this.status = 'running',
    this.done = 0,
    this.total = 0,
    this.ok = 0,
    this.failed = 0,
    this.message = '',
    this.log = const [],
  });
  final String id;
  final String kind;
  final String status;         // running | done | error | cancelled
  final int done;
  final int total;
  final int ok;
  final int failed;
  final String message;
  final List<String> log;

  bool get running => status == 'running';
  double get progress => total <= 0 ? 0 : (done / total).clamp(0.0, 1.0);

  factory R2Op.fromJson(Map<String, dynamic> j) => R2Op(
        id: '${j['id'] ?? ''}',
        kind: '${j['kind'] ?? ''}',
        status: '${j['status'] ?? 'running'}',
        done: (j['done'] is num) ? (j['done'] as num).toInt() : 0,
        total: (j['total'] is num) ? (j['total'] as num).toInt() : 0,
        ok: (j['ok'] is num) ? (j['ok'] as num).toInt() : 0,
        failed: (j['failed'] is num) ? (j['failed'] as num).toInt() : 0,
        message: '${j['message'] ?? ''}',
        log: (j['log'] as List? ?? const []).map((e) => '$e').toList(),
      );
}

class R2ControlService {
  R2ControlService._();

  static Map<String, String> get _headers => {
        ...ApiService.authHeaders,
        'Content-Type': 'application/json',
      };

  static String _detail(http.Response r) {
    try {
      final j = jsonDecode(r.body);
      if (j is Map && j['detail'] != null) return '${j['detail']}';
    } catch (_) {}
    return 'HTTP ${r.statusCode}';
  }

  static Future<Map<String, dynamic>> _get(String path,
      {Duration timeout = const Duration(seconds: 90)}) async {
    final r = await http
        .get(Uri.parse('${ApiService.baseUrl}$path'), headers: _headers)
        .timeout(timeout);
    if (r.statusCode >= 400) throw Exception(_detail(r));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body,
      {Duration timeout = const Duration(seconds: 90)}) async {
    final r = await http
        .post(Uri.parse('${ApiService.baseUrl}$path'),
            headers: _headers, body: jsonEncode(body))
        .timeout(timeout);
    if (r.statusCode >= 400) throw Exception(_detail(r));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Kova listesi. `refresh` sayimi yeniden yapar (yalniz listeleme - bayt
  /// inmez); `bucket` verilirse yalniz o kova sayilir.
  static Future<R2Registry> buckets({bool refresh = false, String bucket = ''}) async =>
      R2Registry.fromJson(await _get(
          '/api/r2/buckets?refresh=$refresh&bucket=${Uri.encodeComponent(bucket)}',
          timeout: const Duration(minutes: 5)));

  static Future<R2Listing> list(String bucket,
          {String prefix = '', String cursor = '', int limit = 200}) async =>
      R2Listing.fromJson(await _get('/api/r2/list?bucket=${Uri.encodeComponent(bucket)}'
          '&prefix=${Uri.encodeComponent(prefix)}'
          '&cursor=${Uri.encodeComponent(cursor)}&limit=$limit'));

  static Future<R2Head> head(String bucket, String key) async =>
      R2Head.fromJson(await _get('/api/r2/head?bucket=${Uri.encodeComponent(bucket)}'
          '&key=${Uri.encodeComponent(key)}'));

  /// Onizleme adresi. YALNIZ [R2Object.preview] true olan satirlar icin ve
  /// yalniz ekranda gorunurken istenir - onden yuklenmez.
  static String thumbUrl(String bucket, String key, {int size = 160}) =>
      '${ApiService.baseUrl}/api/r2/thumb?bucket=${Uri.encodeComponent(bucket)}'
      '&key=${Uri.encodeComponent(key)}&size=$size';

  static Map<String, String> get thumbHeaders => ApiService.authHeaders;

  static Future<R2DeletePlan> deletePlan(String bucket, List<String> keys) async =>
      R2DeletePlan.fromJson(
          await _post('/api/r2/delete-plan', {'bucket': bucket, 'keys': keys}));

  /// Siler. GERI ALINAMAZ. [confirm] kova adiyla birebir ayni olmali;
  /// [takedown] ESKI ikizdeki karsiligini da siler.
  static Future<Map<String, dynamic>> delete(String bucket, List<String> keys,
          {bool takedown = false, required String confirm}) =>
      _post('/api/r2/delete', {
        'bucket': bucket,
        'keys': keys,
        'takedown': takedown,
        'confirm': confirm,
        'client': 'app',
      }, timeout: const Duration(minutes: 2));

  static Future<String> copy({
    required String srcBucket,
    required String dstBucket,
    String srcKey = '',
    String dstKey = '',
    String srcPrefix = '',
    String dstPrefix = '',
  }) async {
    final j = await _post('/api/r2/copy', {
      'src_bucket': srcBucket,
      'dst_bucket': dstBucket,
      'src_key': srcKey,
      'dst_key': dstKey,
      'src_prefix': srcPrefix,
      'dst_prefix': dstPrefix,
      'client': 'app',
    }, timeout: const Duration(minutes: 5));
    return '${j['op'] ?? ''}';
  }

  static Future<String> fixHeaders(String bucket, String prefix) async {
    final j = await _post('/api/r2/fix-headers',
        {'bucket': bucket, 'prefix': prefix, 'client': 'app'},
        timeout: const Duration(minutes: 5));
    return '${j['op'] ?? ''}';
  }

  static Future<Map<String, dynamic>> diff({String rating = 'hot', String collection = ''}) =>
      _get('/api/r2/diff?rating=${Uri.encodeComponent(rating)}'
          '&collection=${Uri.encodeComponent(collection)}',
          timeout: const Duration(minutes: 5));

  static Future<Map<String, dynamic>> twinDiff(String bucket) =>
      _get('/api/r2/twin-diff?bucket=${Uri.encodeComponent(bucket)}',
          timeout: const Duration(minutes: 10));

  static Future<List<R2Op>> ops() async {
    final j = await _get('/api/r2/ops');
    return (j['ops'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => R2Op.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<R2Op> op(String id) async =>
      R2Op.fromJson(await _get('/api/r2/op/$id'));

  static Future<void> cancelOp(String id) async {
    await _post('/api/r2/op/$id/cancel', const {});
  }
}

/// Bayt sayisini kisa okunur metne cevirir (satirlarda ve rozetlerde).
String r2Size(int? bytes) {
  if (bytes == null) return '-';
  const birim = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < birim.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v < 10 && i > 0 ? v.toStringAsFixed(1) : v.round()} ${birim[i]}';
}
