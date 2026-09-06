import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'api_service.dart';
import 'generate_service.dart';

/// Jigsaw dort akisli yayin hattinin istemcisi.
///
/// Telefonda varlik havuzu klasorleri, wrangler ve EXIF etiketleyici yok;
/// hepsi sunucuda calisir. Bu servis AGB'nin `/api/jigsaw/flow/*`
/// uclarini sarar. Uzun isler (etiketleme, webp, push) sunucuda arka planda
/// calisir ve `op()` ile izlenir.
class FlowItem {
  final String id;          // '<stem>' (incoming) ya da '<koleksiyon>/<stem>'
  final String name;
  final String collection;
  final String stem;
  final bool video;
  final bool webp;
  final bool? tagged;       // yalniz 2. akista dolu
  final int size;

  const FlowItem({
    required this.id,
    required this.name,
    required this.collection,
    required this.stem,
    required this.video,
    required this.webp,
    required this.tagged,
    required this.size,
  });

  factory FlowItem.fromJson(Map<String, dynamic> j) => FlowItem(
        id: '${j['id']}',
        name: '${j['name']}',
        collection: '${j['collection'] ?? ''}',
        stem: '${j['stem'] ?? ''}',
        video: j['video'] == true,
        webp: j['webp'] == true,
        tagged: j.containsKey('tagged') ? j['tagged'] == true : null,
        size: (j['size'] ?? 0) as int,
      );

  String get label => collection.isEmpty ? name : '$collection/$name';
}

class FlowCollection {
  final String name;
  final int count;      // bu akistaki varlik sayisi
  final int total;      // staging + pushed toplami
  final bool full;      // 10'a ulasti (Generic haric) - kabul icin sunulmaz
  final int next;
  const FlowCollection(this.name, this.count, this.total, this.full, this.next);

  factory FlowCollection.fromJson(Map<String, dynamic> j) => FlowCollection(
        '${j['name']}',
        (j['count'] ?? 0) as int,
        (j['total'] ?? j['count'] ?? 0) as int,
        j['full'] == true,
        (j['next'] ?? 1) as int,
      );
}

/// Sunucudaki arka plan isleminin anlik hali.
class FlowOp {
  final String id;
  final String kind;
  final String status;      // running | done | error
  final int done;
  final int total;
  final int ok;
  final int failed;
  final String message;
  final List<String> log;

  const FlowOp({
    required this.id,
    required this.kind,
    required this.status,
    required this.done,
    required this.total,
    required this.ok,
    required this.failed,
    required this.message,
    required this.log,
  });

  factory FlowOp.fromJson(Map<String, dynamic> j) => FlowOp(
        id: '${j['id']}',
        kind: '${j['kind']}',
        status: '${j['status']}',
        done: (j['done'] ?? 0) as int,
        total: (j['total'] ?? 0) as int,
        ok: (j['ok'] ?? 0) as int,
        failed: (j['failed'] ?? 0) as int,
        message: '${j['message'] ?? ''}',
        log: ((j['log'] ?? []) as List).map((e) => '$e').toList(),
      );

  bool get running => status == 'running';
  double? get progress => total > 0 ? (done / total).clamp(0, 1).toDouble() : null;
}

/// 2. akistaki hazir hareket sablonu.
class VideoTemplate {
  final String name;
  final String prompt;
  const VideoTemplate(this.name, this.prompt);

  factory VideoTemplate.fromJson(Map<String, dynamic> j) =>
      VideoTemplate('${j['ad'] ?? ''}', '${j['prompt'] ?? ''}');
}

class VideoDefaults {
  final List<VideoTemplate> templates;
  final String negative;
  final String motionDefault;
  const VideoDefaults(this.templates, this.negative, this.motionDefault);

  static const empty = VideoDefaults([], '', '');
}

/// Bir koleksiyonun muzik durumu.
class CollectionMusic {
  final String name;
  final String stage;     // staging | pushed
  final String music;     // dosya adi, yoksa bos
  final bool hasMusic;
  const CollectionMusic(this.name, this.stage, this.music, this.hasMusic);

  factory CollectionMusic.fromJson(Map<String, dynamic> j) => CollectionMusic(
        '${j['name']}', '${j['stage']}', '${j['music'] ?? ''}',
        j['has_music'] == true,
      );
}

class MusicStatus {
  final bool modelReady;
  final String modelError;
  final String defaultCollection;
  final List<CollectionMusic> collections;
  const MusicStatus(
      this.modelReady, this.modelError, this.defaultCollection, this.collections);

  static const empty = MusicStatus(false, '', 'Generic', []);
}

class JigsawFlowService {
  static const stages = ['incoming', 'staging', 'pushed'];
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
  static Future<({List<FlowItem> items, int total})> list({
    required String rating,
    required String stage,
    String collection = '',
    int limit = 200,
    int offset = 0,
  }) async {
    final d = await _get('/api/jigsaw/flow/list?rating=$rating&stage=$stage'
        '&collection=${Uri.encodeQueryComponent(collection)}'
        '&limit=$limit&offset=$offset');
    return (
      items: (d['items'] as List)
          .map((e) => FlowItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (d['total'] ?? 0) as int,
    );
  }

  static Future<Map<String, List<FlowCollection>>> collections(String rating) async {
    final d = await _get('/api/jigsaw/flow/collections?rating=$rating');
    return {
      for (final k in ['staging', 'pushed'])
        k: ((d[k] ?? []) as List)
            .map((e) => FlowCollection.fromJson(e as Map<String, dynamic>))
            .toList(),
    };
  }

  static String thumbUrl(String rating, String stage, String id, {int size = 360}) =>
      '${ApiService.baseUrl}/api/jigsaw/flow/thumb?rating=$rating&stage=$stage'
      '&id=${Uri.encodeQueryComponent(id)}&size=$size';

  static String fileUrl(String rating, String stage, String id,
          {String kind = 'image'}) =>
      '${ApiService.baseUrl}/api/jigsaw/flow/file?rating=$rating&stage=$stage'
      '&id=${Uri.encodeQueryComponent(id)}&kind=$kind';

  static Map<String, String> get authHeaders => GenerateService.authHeaders;

  // ------------------------------------------------------------- yazma
  /// 1 -> 2. Uretim islerini _Incoming'e tasir ve EXIF etiketini isler.
  static Future<String> stageJobs(
          {required List<String> jobs,
          required String rating,
          String agent = 'Gemini'}) async =>
      '${(await _post('/api/jigsaw/flow/stage',
          {'jobs': jobs, 'rating': rating, 'agent': agent}))['op']}';

  /// Derecenin hazir hareket sablonlari + varsayilan negatifi.
  static Future<VideoDefaults> videoTemplates(String rating) async {
    final d = await _get('/api/jigsaw/flow/video-templates?rating=$rating');
    return VideoDefaults(
      ((d['templates'] ?? []) as List)
          .map((e) => VideoTemplate.fromJson(e as Map<String, dynamic>))
          .toList(),
      '${d['negative'] ?? ''}',
      '${d['motion_default'] ?? ''}',
    );
  }

  /// 2. akis: secili gorseller icin LTX video isi acar.
  ///
  /// [rotateTemplates] "Que All" davranisi: prompt2 bossa hazir sablonlar
  /// siradaki varliga sirayla dagitilir, parti tek tip olmaz.
  static Future<({int queued, int skipped})> makeVideos({
    required String rating,
    required List<String> ids,
    int duration = 5,
    bool turbo = true,
    String prompt = '',
    String prompt2 = '',
    String negative = '',
    bool rotateTemplates = false,
  }) async {
    final d = await _post('/api/jigsaw/flow/video', {
      'rating': rating,
      'ids': ids,
      'duration': duration,
      'turbo': turbo,
      'prompt': prompt,
      'prompt2': prompt2,
      'negative': negative,
      'rotate_templates': rotateTemplates,
    });
    return (
      queued: (d['queued'] ?? 0) as int,
      skipped: (d['skipped'] ?? 0) as int,
    );
  }

  /// 2 -> 3. Koleksiyona `<n>.jpg` / `.mp4` / `.webp` olarak tasir.
  static Future<String> accept(
          {required String rating,
          required List<String> ids,
          required String collection}) async =>
      '${(await _post('/api/jigsaw/flow/accept',
          {'rating': rating, 'ids': ids, 'collection': collection}))['op']}';

  /// 3 -> 4. R2'ye yukler. GERI ALINAMAZ.
  static Future<String> push(
          {required String rating, required List<String> ids}) async =>
      '${(await _post('/api/jigsaw/flow/push', {'rating': rating, 'ids': ids}))['op']}';

  static Future<String> encodeWebp(
          {required String rating, String collection = ''}) async =>
      '${(await _post('/api/jigsaw/flow/webp',
          {'rating': rating, 'collection': collection}))['op']}';

  static Future<int> remove(
      {required String rating,
      required String stage,
      required List<String> ids}) async {
    final d = await _post(
        '/api/jigsaw/flow/delete', {'rating': rating, 'stage': stage, 'ids': ids});
    return (d['deleted'] ?? 0) as int;
  }

  /// Koleksiyon muzikleri: hangisinde var, model hazir mi.
  static Future<MusicStatus> musicStatus(String rating) async {
    final d = await _get('/api/jigsaw/flow/music?rating=$rating');
    return MusicStatus(
      d['model_ready'] == true,
      '${d['model_error'] ?? ''}',
      '${d['default_collection'] ?? 'Generic'}',
      ((d['collections'] ?? []) as List)
          .map((e) => CollectionMusic.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Secili koleksiyonlar icin yerel ACE-Step ile mp3 uretir.
  static Future<String> makeMusic({
    required String rating,
    required List<String> collections,
    String tags = '',
    double seconds = 30,
    bool overwrite = false,
  }) async =>
      '${(await _post('/api/jigsaw/flow/music', {
            'rating': rating,
            'collections': collections,
            'tags': tags,
            'seconds': seconds,
            'overwrite': overwrite,
          }))['op']}';

  static Future<FlowOp> op(String opId) async =>
      FlowOp.fromJson(await _get('/api/jigsaw/flow/op/$opId'));
}
