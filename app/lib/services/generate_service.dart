import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import '../config.dart';

/// Uretim kipi. Free Mod serbest uretim, Jigsaw Modu Hot Jigsaw is akisi.
class GenerateMode {
  const GenerateMode({
    required this.id,
    required this.label,
    required this.prompt2,
    required this.motion2,
    required this.negative,
    required this.exports,
    this.profiles = '',
    this.aspects = false,
  });

  final String id;
  final String label;
  final String prompt2;   // gorsel gorevleri icin ikinci pozitif sablon
  final String motion2;   // video gorevleri icin hareket sablonu
  final String negative;
  final bool exports;     // ciktilar bir havuza yazilabiliyor mu
  final String profiles;  // '' | 'jigsaw' | 'cbn' - derece secenek dosyasi
  final bool aspects;     // oran secici (kare / dikey / yatay) gosterilsin mi

  bool get isJigsaw => id == 'jigsaw';
  bool get hasProfiles => profiles.isNotEmpty;

  factory GenerateMode.fromJson(Map<String, dynamic> j) => GenerateMode(
        id: j['id'] as String,
        label: (j['label'] ?? j['id']) as String,
        prompt2: (j['prompt2'] ?? '') as String,
        motion2: (j['motion2'] ?? '') as String,
        negative: (j['negative'] ?? '') as String,
        exports: j['exports'] == true,
        profiles: (j['profiles'] ?? (j['id'] == 'jigsaw' ? 'jigsaw' : '')) as String,
        aspects: j['aspects'] == true,
      );
}

/// Bir uretim gorevi (sunucudaki manifest'ten gelir).
class GenerateTask {
  const GenerateTask({
    required this.id,
    required this.label,
    required this.needsImage,
    required this.isVideo,
    required this.width,
    required this.height,
    required this.duration,
  });

  final String id;
  final String label;
  final bool needsImage;
  final bool isVideo;
  final int width;
  final int height;
  final int duration;

  factory GenerateTask.fromJson(Map<String, dynamic> j) => GenerateTask(
        id: j['id'] as String,
        label: (j['label'] ?? j['id']) as String,
        needsImage: j['needs_image'] == true,
        isVideo: j['is_video'] == true,
        width: (j['default_width'] ?? 0) as int,
        height: (j['default_height'] ?? 0) as int,
        duration: (j['default_duration'] ?? 5) as int,
      );
}

/// Hot Jigsaw havuzundaki bir kategori.
class JigsawCategory {
  const JigsawCategory({required this.name, required this.next, required this.count});

  final String name;
  final int next;   // bu kategoride siradaki numara
  final int count;

  factory JigsawCategory.fromJson(Map<String, dynamic> j) => JigsawCategory(
        name: j['name'] as String,
        next: (j['next'] ?? 1) as int,
        count: (j['count'] ?? 0) as int,
      );
}

/// Kuyruga alinmis / bitmis bir uretim isi.
class GenerateJob {
  const GenerateJob({
    required this.id,
    required this.task,
    required this.prompt,
    required this.status,
    required this.isVideo,
    this.prompt2 = '',
    this.combined = '',
    this.negative = '',
    this.mode = 'free',
    this.category = '',
    this.seconds,
    this.error,
    this.fileName,
    this.createdAt,
    this.sourceJob,
    this.seed,
    this.width = 0,
    this.height = 0,
    this.favorite = false,
    this.progress = 0,
    this.node = '',
    this.position,
    this.exported,
  });

  final String id;
  final String task;
  final String prompt;
  final String prompt2;
  final String combined;
  final String negative;
  final String mode;
  final String category;
  final String status; // queued | running | done | error | cancelled
  final bool isVideo;
  final double? seconds;
  final String? error;
  final String? fileName;
  final String? createdAt;
  final String? sourceJob;
  final int? seed;
  final int width;
  final int height;
  final bool favorite;
  final int progress;   // 0-100, yalnizca calisirken anlamli
  final String node;    // ComfyUI'de o an calisan dugum
  final int? position;  // 0 = calisiyor, 1+ = sirada, null = kuyrukta degil
  final String? exported;

  bool get isDone => status == 'done';
  bool get isFailed => status == 'error' || status == 'cancelled';
  bool get isBusy => status == 'queued' || status == 'running';
  bool get isRunning => position == 0;

  /// Ciktinin tunel uzerinden erisilebilir adresi.
  String get fileUrl => '${ApiService.baseUrl}/api/generate/$id/file';

  /// Galeri icin kucuk onizleme - tam boy dosyayi indirmeden.
  String thumbUrl({int size = 400}) =>
      '${ApiService.baseUrl}/api/generate/$id/thumb?size=$size';

  factory GenerateJob.fromJson(Map<String, dynamic> j) => GenerateJob(
        id: j['id'] as String,
        task: (j['task'] ?? '') as String,
        prompt: (j['prompt'] ?? '') as String,
        prompt2: (j['prompt2'] ?? '') as String,
        combined: (j['combined'] ?? '') as String,
        negative: (j['negative'] ?? '') as String,
        mode: (j['mode'] ?? 'free') as String,
        category: (j['category'] ?? '') as String,
        status: (j['status'] ?? 'queued') as String,
        isVideo: j['is_video'] == true,
        seconds: (j['seconds'] as num?)?.toDouble(),
        error: j['error'] as String?,
        fileName: j['file_name'] as String?,
        createdAt: j['created_at'] as String?,
        sourceJob: j['source_job'] as String?,
        seed: (j['seed'] as num?)?.toInt(),
        width: (j['width'] ?? 0) as int,
        height: (j['height'] ?? 0) as int,
        favorite: j['favorite'] == true,
        progress: (j['progress'] ?? 0) as int,
        node: (j['node'] ?? '') as String,
        position: (j['position'] as num?)?.toInt(),
        exported: j['exported'] as String?,
      );
}

/// Kuyrugun anlik hali.
class QueueState {
  const QueueState({this.running, required this.pending, required this.depth,
    required this.comfyUp});

  final GenerateJob? running;
  final List<GenerateJob> pending;
  final int depth;
  final bool comfyUp;

  /// Calisan + bekleyenler, gosterim sirasiyla.
  List<GenerateJob> get all => [if (running != null) running!, ...pending];

  factory QueueState.fromJson(Map<String, dynamic> j) => QueueState(
        running: j['running'] == null
            ? null
            : GenerateJob.fromJson(j['running'] as Map<String, dynamic>),
        pending: ((j['pending'] ?? []) as List)
            .map((e) => GenerateJob.fromJson(e as Map<String, dynamic>))
            .toList(),
        depth: (j['depth'] ?? 0) as int,
        comfyUp: j['comfy_up'] == true,
      );
}

/// Sunucudaki yerel ComfyUI uretim koprusune baglanir.
///
/// Tum emirler sunucuda TEK sirali bir kuyruga girer; burasi yalnizca
/// istegi acar ve kuyrugu izler.
class GenerateService {
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AppConfig.apiKey.isNotEmpty) 'X-API-Key': AppConfig.apiKey,
      };

  static Map<String, String> get authHeaders => {
        if (AppConfig.apiKey.isNotEmpty) 'X-API-Key': AppConfig.apiKey,
      };

  static const _timeout = Duration(seconds: 30);

  static Never _fail(http.Response r, String fallback) {
    String msg = '$fallback (${r.statusCode})';
    try {
      final d = jsonDecode(r.body);
      if (d is Map && d['detail'] != null) msg = d['detail'].toString();
    } catch (_) {}
    throw Exception(msg);
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    final r = await http
        .get(Uri.parse('${ApiService.baseUrl}$path'), headers: _headers)
        .timeout(_timeout);
    if (r.statusCode != 200) _fail(r, 'Istek basarisiz');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _post(String path,
      [Map<String, dynamic>? body]) async {
    final r = await http
        .post(Uri.parse('${ApiService.baseUrl}$path'),
            headers: _headers, body: jsonEncode(body ?? {}))
        .timeout(_timeout);
    if (r.statusCode != 200) _fail(r, 'Istek reddedildi');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Gorev listesi + kipler + ComfyUI ayakta mi.
  static Future<({bool comfyUp, List<GenerateTask> tasks, List<GenerateMode> modes})>
      fetchTasks({String mode = ''}) async {
    final d = await _get('/api/generate/tasks?mode=$mode');
    return (
      comfyUp: d['comfy_up'] == true,
      tasks: (d['tasks'] as List)
          .map((e) => GenerateTask.fromJson(e as Map<String, dynamic>))
          .toList(),
      modes: ((d['modes'] ?? []) as List)
          .map((e) => GenerateMode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Yeni uretim isini kuyruga ekler.
  static Future<GenerateJob> submit({
    required String task,
    required String prompt,
    String prompt2 = '',
    String negative = '',
    int width = 0,
    int height = 0,
    int duration = 5,
    bool turbo = true,
    int? seed,
    String? imagePath,
    String? sourceJob,
    String mode = 'free',
    String category = '',
    String? client,
  }) async {
    final d = await _post('/api/generate', {
      'task': task,
      'prompt': prompt,
      'prompt2': prompt2,
      'negative': negative,
      'width': width,
      'height': height,
      'duration': duration,
      'turbo': turbo,
      'mode': mode,
      'category': category,
      if (seed != null) 'seed': seed,
      if (imagePath != null) 'image_path': imagePath,
      if (sourceJob != null) 'source_job': sourceJob,
      if (client != null) 'client': client,
    });
    return GenerateJob.fromJson(d);
  }

  /// Tek bir isin guncel durumu.
  static Future<GenerateJob> status(String jobId) async =>
      GenerateJob.fromJson(await _get('/api/generate/$jobId'));

  /// Son isler (galeri ekrani icin).
  static Future<List<GenerateJob>> list({
    int limit = 30,
    String? client,
    String? mode,
    bool favorites = false,
  }) async {
    final q = StringBuffer('/api/generate?limit=$limit');
    if (client != null) q.write('&client=$client');
    if (mode != null) q.write('&mode=$mode');
    if (favorites) q.write('&favorites=true');
    final d = await _get(q.toString());
    return (d['jobs'] as List)
        .map((e) => GenerateJob.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Kuyrugun anlik hali - calisan is, bekleyenler, sira derinligi.
  static Future<QueueState> queue() async =>
      QueueState.fromJson(await _get('/api/generate/queue'));

  static Future<void> cancel(String jobId) => _post('/api/generate/$jobId/cancel');

  /// Bekleyen bir isi kuyrukta tasir: -1 yukari, +1 asagi.
  static Future<void> move(String jobId, int delta) =>
      _post('/api/generate/$jobId/move', {'delta': delta});

  static Future<void> clearQueue() => _post('/api/generate/queue/clear');

  static Future<GenerateJob> setFavorite(String jobId, bool favorite) async =>
      GenerateJob.fromJson(await _post('/api/generate/$jobId/meta', {'favorite': favorite}));

  static Future<void> delete(String jobId) async {
    final r = await http
        .delete(Uri.parse('${ApiService.baseUrl}/api/generate/$jobId'), headers: _headers)
        .timeout(_timeout);
    if (r.statusCode != 200) _fail(r, 'Silinemedi');
  }

  // ---------------------------------------------------------------- jigsaw
  static Future<List<JigsawCategory>> jigsawCategories() async {
    final d = await _get('/api/jigsaw/categories');
    return (d['categories'] as List)
        .map((e) => JigsawCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Gorsel + videoyu havuza `<n>.jpg` / `<n>.mp4` / `<n>.webp` olarak yazar.
  static Future<({int number, String category, List<String> written,
      List<String> warnings})> jigsawExport({
    required String imageJob,
    String? videoJob,
    required String category,
  }) async {
    final d = await _post('/api/jigsaw/export', {
      'image_job': imageJob,
      'video_job': videoJob,
      'category': category,
    });
    return (
      number: (d['number'] ?? 0) as int,
      category: (d['category'] ?? '') as String,
      written: ((d['written'] ?? []) as List).map((e) => e.toString()).toList(),
      warnings: ((d['warnings'] ?? []) as List).map((e) => e.toString()).toList(),
    );
  }
}
