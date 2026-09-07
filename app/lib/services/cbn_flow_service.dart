import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'api_service.dart';
import 'generate_service.dart';
import 'jigsaw_flow_service.dart' show FlowCollection, FlowOp;

/// CBN (Color-By-Number) yayin hattinin istemcisi - `/api/cbn/flow/*`.
///
/// Jigsaw hattinin ikizi: 1 uretim (CBN Modu) -> 2 Gelen (EXIF etiketli jpg)
/// -> 3 Hazir (Opus + SAM3 [+ Qwen cizgi] ile insa edilmis varlik klasoru)
/// -> 4 Push edilmis. Insa uzun surer (kid ~2 dk, hot ~4 dk), sunucuda arka
/// planda calisir; `op()` ile izlenir.
class CbnItem {
  final String id;            // '<stem>' (gelen) ya da '<koleksiyon>/<n>'
  final String name;
  final String collection;
  final String stem;
  final bool built;
  final bool video;           // hot: reveal.mp4 var
  final bool svg;             // kid: asset.svg var
  final bool? tagged;         // yalniz 2. akista dolu
  final int regions;
  final int colors;
  final String verdict;       // pass | fail | ''
  final String prompt;
  final String tags;

  const CbnItem({
    required this.id,
    required this.name,
    required this.collection,
    required this.stem,
    required this.built,
    required this.video,
    required this.svg,
    required this.tagged,
    required this.regions,
    required this.colors,
    required this.verdict,
    required this.prompt,
    required this.tags,
  });

  factory CbnItem.fromJson(Map<String, dynamic> j) => CbnItem(
        id: '${j['id']}',
        name: '${j['name']}',
        collection: '${j['collection'] ?? ''}',
        stem: '${j['stem'] ?? ''}',
        built: j['built'] == true,
        video: j['video'] == true,
        svg: j['svg'] == true,
        tagged: j.containsKey('tagged') ? j['tagged'] == true : null,
        regions: (j['regions'] ?? 0) as int,
        colors: (j['colors'] ?? 0) as int,
        verdict: '${j['verdict'] ?? ''}',
        prompt: '${j['prompt'] ?? ''}',
        tags: '${j['tags'] ?? ''}',
      );

  String get label => collection.isEmpty ? name : '$collection/$name';
}

class CbnFlowService {
  static const stages = ['incoming', 'staging', 'pushed'];
  static const ratings = <String, String>{'hot': 'Hot CBN', 'kid': 'Kid CBN'};
  static const _timeout = Duration(seconds: 60);

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AppConfig.apiKey.isNotEmpty) 'X-API-Key': AppConfig.apiKey,
      };

  static Never _fail(http.Response r, String fallback) {
    try {
      final d = json.decode(r.body);
      throw Exception('${d['detail'] ?? fallback}');
    } catch (_) {
      throw Exception('$fallback (${r.statusCode})');
    }
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    final r = await http
        .get(Uri.parse('${ApiService.baseUrl}$path'), headers: _headers)
        .timeout(_timeout);
    if (r.statusCode != 200) _fail(r, 'Istek basarisiz');
    return json.decode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _post(String path,
      [Map<String, dynamic>? body]) async {
    final r = await http
        .post(Uri.parse('${ApiService.baseUrl}$path'),
            headers: _headers, body: json.encode(body ?? {}))
        .timeout(_timeout);
    if (r.statusCode != 200) _fail(r, 'Istek basarisiz');
    return json.decode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  // ------------------------------------------------------------- okuma
  static Future<({List<CbnItem> items, int total})> list({
    required String rating,
    required String stage,
    String collection = '',
    int limit = 200,
    int offset = 0,
  }) async {
    final d = await _get('/api/cbn/flow/list?rating=$rating&stage=$stage'
        '&collection=${Uri.encodeQueryComponent(collection)}'
        '&limit=$limit&offset=$offset');
    return (
      items: (d['items'] as List)
          .map((e) => CbnItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (d['total'] ?? 0) as int,
    );
  }

  static Future<Map<String, List<FlowCollection>>> collections(String rating) async {
    final d = await _get('/api/cbn/flow/collections?rating=$rating');
    return {
      for (final k in ['staging', 'pushed'])
        k: ((d[k] ?? []) as List)
            .map((e) => FlowCollection.fromJson(e as Map<String, dynamic>))
            .toList(),
    };
  }

  /// kind: image | numbered | preview | lineart | segments
  static String thumbUrl(String rating, String stage, String id,
          {String kind = 'image', int size = 360}) =>
      '${ApiService.baseUrl}/api/cbn/flow/thumb?rating=$rating&stage=$stage'
      '&id=${Uri.encodeQueryComponent(id)}&kind=$kind&size=$size';

  /// kind: image | lineart | regions | numbered | preview | segments | video | svg | json
  static String fileUrl(String rating, String stage, String id,
          {String kind = 'image'}) =>
      '${ApiService.baseUrl}/api/cbn/flow/file?rating=$rating&stage=$stage'
      '&id=${Uri.encodeQueryComponent(id)}&kind=$kind';

  static Map<String, String> get authHeaders => GenerateService.authHeaders;

  // ------------------------------------------------------------- yazma
  /// 1 -> 2. Uretim islerini Gelen'e yazar ve EXIF etiketler.
  static Future<String> stageJobs(
          {required List<String> jobs,
          required String rating,
          String agent = 'Gemini'}) async =>
      '${(await _post('/api/cbn/flow/stage',
          {'jobs': jobs, 'rating': rating, 'agent': agent}))['op']}';

  /// Gelen'deki varliklari yeniden etiketler.
  static Future<String> retag(
          {required List<String> ids, required String rating, String agent = 'Gemini'}) async =>
      '${(await _post('/api/cbn/flow/retag',
          {'jobs': ids, 'rating': rating, 'agent': agent}))['op']}';

  /// 2 -> 3. Secili Gelen varliklarini koleksiyona insa eder (uzun surer).
  static Future<String> build(
          {required String rating,
          required List<String> ids,
          required String collection}) async =>
      '${(await _post('/api/cbn/flow/build',
          {'rating': rating, 'ids': ids, 'collection': collection}))['op']}';

  /// 3 -> 4. R2'ye yukler. GERI ALINAMAZ.
  static Future<String> push({required String rating, required List<String> ids}) async =>
      '${(await _post('/api/cbn/flow/push', {'rating': rating, 'ids': ids}))['op']}';

  static Future<int> remove(
      {required String rating, required String stage, required List<String> ids}) async {
    final d = await _post('/api/cbn/flow/delete',
        {'rating': rating, 'stage': stage, 'ids': ids});
    return (d['deleted'] ?? 0) as int;
  }

  static Future<FlowOp> op(String opId) async =>
      FlowOp.fromJson(await _get('/api/cbn/flow/op/$opId'));
}
