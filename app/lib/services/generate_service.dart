import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';
import '../config.dart';

/// Uretim kipi. Free Mod serbest uretim, Jigsaw Modu Hot Jigsaw is akisi.
/// #323: `profiles` alani gelmeyen (eski) sunucu icin kip kimliginden
/// secenek dosyasi anahtari - bilinmeyen kipte bos (profil yok).
String _profilesOf(String id) => switch (id) {
      'jigsaw' => 'jigsaw',
      'cbn' => 'cbn',
      'character' => 'character',
      'card' => 'card',
      _ => '',
    };

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
    this.aspectSizes = const {},
  });

  final String id;
  final String label;
  final String prompt2;   // gorsel gorevleri icin ikinci pozitif sablon
  final String motion2;   // video gorevleri icin hareket sablonu
  final String negative;
  final bool exports;     // ciktilar bir havuza yazilabiliyor mu
  final String profiles;  // '' | 'jigsaw' | 'cbn' | 'character' | 'card'
  final bool aspects;     // oran secici gosterilsin mi
  /// Sunucunun oran tablosu: id -> (genislik, yukseklik). Bos ise istemci
  /// kendi tablosunu kullanir.
  final Map<String, (int, int)> aspectSizes;

  bool get isJigsaw => id == 'jigsaw';
  bool get hasProfiles => profiles.isNotEmpty;

  factory GenerateMode.fromJson(Map<String, dynamic> j) => GenerateMode(
        id: j['id'] as String,
        label: (j['label'] ?? j['id']) as String,
        prompt2: (j['prompt2'] ?? '') as String,
        motion2: (j['motion2'] ?? '') as String,
        negative: (j['negative'] ?? '') as String,
        exports: j['exports'] == true,
        // #323: sunucu `profiles` gondermezse bilinen kip kimliklerinden
        // turetilir - yeni "card" kipi de secenek dosyasini boylece bulur.
        profiles: '${j['profiles'] ?? _profilesOf('${j['id']}')}',
        aspects: j['aspects'] == true,
        aspectSizes: {
          for (final a in (j['aspect_sizes'] as List? ?? const []))
            if (a is Map && a['id'] != null)
              a['id'] as String: ((a['width'] ?? 0) as int, (a['height'] ?? 0) as int),
        },
      );
}

/// Bir is akisinin girdi yuvasi (gorev #287).
///
/// Sunucu is akisi JSON'undaki dosya okuyan dugumleri (LoadImage / LoadVideo /
/// LoadAudio) tarar ve her birini bir yuva olarak bildirir: FLF2V ilk+son kare,
/// V2V referans gorsel + surucu video, S2V gorsel + ses...
class GenerateInputSlot {
  const GenerateInputSlot({
    required this.slot,
    required this.kind,
    required this.label,
    this.title = '',
    this.defaultFile = '',
    this.required = true,
  });

  final String slot;        // image_1 | video_1 | audio_1 ...
  final String kind;        // image | video | audio
  final String label;       // "Gorsel 1" - arayuzde gorunen kisa ad
  final String title;       // is akisindaki dugum basligi (ipucu)
  final String defaultFile; // is akisinin kendi ornek dosyasi
  final bool required;

  bool get isImage => kind == 'image';
  bool get isVideo => kind == 'video';
  bool get isAudio => kind == 'audio';

  factory GenerateInputSlot.fromJson(Map<String, dynamic> j) {
    final kind = (j['kind'] ?? 'image') as String;
    final slot = (j['slot'] ?? kind) as String;
    return GenerateInputSlot(
      slot: slot,
      kind: kind,
      label: (j['label'] ?? slot) as String,
      title: (j['title'] ?? '') as String,
      defaultFile: (j['default'] ?? '') as String,
      required: j['required'] != false,
    );
  }
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
    this.inputs = const [],
    this.prompt2 = '',
    this.negative = '',
  });

  final String id;
  final String label;
  final bool needsImage;
  final bool isVideo;
  final int width;
  final int height;
  final int duration;
  /// #353: gorevin kendi sablonu/negatifi (manifest) - kipin/derecenin sablonu
  /// yoksa bu kullanilir (anime gorevi foto sablonuyla calismaz).
  final String prompt2;
  final String negative;

  /// Is akisinin girdi yuvalari. Eski sunucularda bos gelir - o zaman eski
  /// tek gorsellik akis kullanilir.
  final List<GenerateInputSlot> inputs;

  /// Tek bir gorsel yuvasi disinda girdi istiyor mu (ikinci kare, video, ses).
  bool get hasExtraInputs =>
      inputs.length > 1 || (inputs.length == 1 && !inputs.first.isImage);

  factory GenerateTask.fromJson(Map<String, dynamic> j) => GenerateTask(
        id: j['id'] as String,
        label: (j['label'] ?? j['id']) as String,
        needsImage: j['needs_image'] == true,
        isVideo: j['is_video'] == true,
        width: (j['default_width'] ?? 0) as int,
        height: (j['default_height'] ?? 0) as int,
        duration: (j['default_duration'] ?? 5) as int,
        inputs: ((j['inputs'] ?? const []) as List)
            .map((e) => GenerateInputSlot.fromJson(e as Map<String, dynamic>))
            .toList(),
        prompt2: '${j['prompt2'] ?? ''}',
        negative: '${j['negative'] ?? ''}',
      );
}

/// Bir yuvaya secilen girdi: ya onceki bir uretim isi ya da bir dosya.
class GenerateInputRef {
  const GenerateInputRef.job(this.job)
      : path = '',
        fileName = '';
  const GenerateInputRef.file(this.path, this.fileName) : job = null;

  final GenerateJob? job;
  final String path;        // sunucudaki mutlak yol
  final String fileName;    // gosterim adi

  String get display => job != null
      ? (job!.prompt.isEmpty ? job!.id : job!.prompt)
      : (fileName.isEmpty ? path : fileName);

  Map<String, String> toJson() =>
      job != null ? {'job_id': job!.id} : {'path': path};
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
  bool get isAudio => const ['mp3', 'wav', 'flac', 'ogg', 'm4a', 'aac', 'opus']
      .contains((fileName ?? '').split('.').last.toLowerCase());
  bool get isImage => !isVideo && !isAudio;
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
  /// #337: yerel prompt yazari hazir mi ({ready, model}).
  static Future<Map<String, dynamic>> smithStatus() async {
    try {
      return await _get('/api/prompt/smith');
    } catch (_) {
      return {'ready': false, 'model': ''};
    }
  }

  /// #337: prompt'u yerel LLM'e islet. `op` = enrich | normalize | variants |
  /// motion. Hata olursa GIRDI aynen doner - cagiran taraf bozulmaz.
  static Future<String> smith(String op, String prompt,
      {String mode = 'free', String hint = '', String subject = ''}) async {
    try {
      final d = await _post('/api/prompt/smith', {
        'op': op,
        'prompt': prompt,
        'mode': mode,
        if (hint.isNotEmpty) 'hint': hint,
        if (subject.isNotEmpty) 'subject': subject,
      });
      final y = '${d['prompt'] ?? d['motion'] ?? ''}'.trim();
      return y.isEmpty ? prompt : y;
    } catch (_) {
      return prompt;
    }
  }

  /// #337: prompt'tan n ayri varyant (bos liste = LLM yok).
  static Future<List<String>> smithVariants(String prompt,
      {int n = 3, String mode = 'free'}) async {
    try {
      final d = await _post('/api/prompt/smith',
          {'op': 'variants', 'prompt': prompt, 'n': n, 'mode': mode});
      final l = d['variants'];
      return l is List ? l.map((e) => '$e').toList() : <String>[];
    } catch (_) {
      return const [];
    }
  }

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
    Map<String, GenerateInputRef> inputs = const {},
    // #337: yerel LLM prompt yazari - sunucu tarafinda calisir, kapaliysa
    // prompt aynen gecer (uretim asla engellenmez).
    bool enrich = false,
    bool normalize = false,
  }) async {
    final d = await _post('/api/generate', {
      if (inputs.isNotEmpty)
        'inputs': {for (final e in inputs.entries) e.key: e.value.toJson()},
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
      if (enrich) 'enrich': true,
      if (normalize) 'normalize': true,
      if (seed != null) 'seed': seed,
      if (imagePath != null) 'image_path': imagePath,
      if (sourceJob != null) 'source_job': sourceJob,
      if (client != null) 'client': client,
    });
    return GenerateJob.fromJson(d);
  }

  /// Telefondan secilen dosyayi sunucuya yukler; girdi yuvasina verilecek
  /// sunucu yolunu doner ("Dosyadan sec").
  static Future<GenerateInputRef> upload(String name, List<int> bytes) async {
    // Buyuk dosya (video) tunelden gecerken 30 sn yetmez - kendi suresi var.
    final r = await http
        .post(Uri.parse('${ApiService.baseUrl}/api/generate/upload'),
            headers: _headers,
            body: jsonEncode({'name': name, 'data': base64Encode(bytes)}))
        .timeout(const Duration(minutes: 5));
    if (r.statusCode != 200) _fail(r, 'Dosya yuklenemedi');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return GenerateInputRef.file(
        (d['path'] ?? '') as String, (d['name'] ?? name) as String);
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

// --------------------------------------------------------------------- #299
// Birlesik sira: comfy uretimi, karakter isleri, etiketleme, CBN, muzik...
// hepsi sunucuda TEK sirali kuyruga girer. Kullanici artik is bittiginde
// hangi ekranda oldugunu dert etmez - Sira sekmesi her seyi gosterir.

/// Kuyruktaki tek bir is. Sunucu alan gondermezse hepsi bos/0 kalir.
class QueueTicket {
  const QueueTicket({
    required this.id,
    required this.label,
    required this.kind,
    this.queuedAt = '',
    this.startedAt = '',
    this.runningSeconds = 0,
    this.waitedSeconds = 0,
    this.opId = '',
    this.jobId = '',
    this.total = 0,
    this.done = 0,
    this.message = '',
    this.canMoveUp = false,
    this.canMoveDown = false,
  });

  final String id;
  final String label;
  /// comfy | character | tag | cbn | music | cpu | gpu
  final String kind;
  final String queuedAt;
  final String startedAt;
  final double runningSeconds;
  final double waitedSeconds;
  final String opId;      // akis op'u varsa (karakter/CBN/etiket/muzik)
  final String jobId;     // comfy isi varsa
  final int total;
  final int done;
  final String message;
  final bool canMoveUp;
  final bool canMoveDown;

  static double _d(dynamic v) => (v is num) ? v.toDouble() : 0;

  factory QueueTicket.fromJson(Map<String, dynamic> j) => QueueTicket(
        id: '${j['id'] ?? ''}',
        label: '${j['label'] ?? ''}',
        kind: '${j['kind'] ?? ''}',
        queuedAt: '${j['queued_at'] ?? ''}',
        startedAt: '${j['started_at'] ?? ''}',
        runningSeconds: _d(j['running_seconds']),
        waitedSeconds: _d(j['waited_seconds']),
        opId: '${j['op_id'] ?? ''}',
        jobId: '${j['job_id'] ?? ''}',
        total: (j['total'] is num) ? (j['total'] as num).toInt() : 0,
        done: (j['done'] is num) ? (j['done'] as num).toInt() : 0,
        message: '${j['message'] ?? ''}',
        canMoveUp: j['can_move_up'] == true,
        canMoveDown: j['can_move_down'] == true,
      );

  /// Op ilerlemesi (yoksa null - belirsiz cubuk).
  double? get progress =>
      total > 0 ? (done / total).clamp(0, 1).toDouble() : null;

  /// Calisiyorsa gecen sure, bekliyorsa bekleme suresi.
  String get elapsedLabel {
    final sn = (runningSeconds > 0 ? runningSeconds : waitedSeconds).round();
    if (sn <= 0) return '';
    if (sn < 60) return '$sn sn';
    final dk = sn ~/ 60;
    if (dk < 60) return '$dk dk ${(sn % 60).toString().padLeft(2, '0')} sn';
    return '${dk ~/ 60} sa ${(dk % 60).toString().padLeft(2, '0')} dk';
  }
}

/// `/api/queue` cevabi: calisan is + bekleyenler + comfy is kartlari.
class UnifiedQueue {
  const UnifiedQueue({
    this.running,
    required this.waiting,
    required this.comfyPending,
    required this.depth,
  });

  final QueueTicket? running;
  final List<QueueTicket> waiting;
  /// Comfy tarafinin bekleyen isleri - tasima/iptal bunlar uzerinden yapilir.
  final List<GenerateJob> comfyPending;
  final int depth;

  bool get isEmpty =>
      running == null && waiting.isEmpty && comfyPending.isEmpty;

  bool get hasPendingGeneration => comfyPending.isNotEmpty ||
      waiting.any((t) => t.kind == 'comfy' && t.jobId.isNotEmpty);

  static List<Map<String, dynamic>> _list(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];

  factory UnifiedQueue.fromJson(Map<String, dynamic> j) => UnifiedQueue(
        running: j['running'] is Map
            ? QueueTicket.fromJson(Map<String, dynamic>.from(j['running'] as Map))
            : null,
        waiting: _list(j['waiting']).map(QueueTicket.fromJson).toList(),
        comfyPending: _list(j['comfy_pending']).map(GenerateJob.fromJson).toList(),
        depth: (j['depth'] is num) ? (j['depth'] as num).toInt() : 0,
      );
}

/// Birlesik sirayi okur ve alt sekmedeki rozeti besler.
class QueueService {
  /// `/api/queue`. Eski sunucuda uc yoksa (404) NULL doner - cagiran eski
  /// `/api/generate/queue` ucuna duser, ekran calismaya devam eder.
  static Future<UnifiedQueue?> unified() async {
    final r = await http
        .get(Uri.parse('${ApiService.baseUrl}/api/queue'),
            headers: GenerateService._headers)
        .timeout(GenerateService._timeout);
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) GenerateService._fail(r, 'Sira okunamadi');
    return UnifiedQueue.fromJson(
        jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
  }

  /// Alt sekmedeki rozet. Dinleyen oldugu surece 5 sn'de bir sorar - Sira
  /// sekmesi gorunmuyorsa ag trafigi yoktur.
  static final QueueDepthNotifier depth = QueueDepthNotifier._();

  /// #352: birlesik siradaki HERHANGI bir satiri iptal eder - bekleyen serit
  /// bileti, calisan akis op'u (karakter/CBN/kart) ya da comfy isi. Sunucu
  /// biletten op/is kimligini kendisi cozer.
  static Future<void> cancelTicket(QueueTicket t) async {
    final r = await http
        .post(Uri.parse('${ApiService.baseUrl}/api/queue/cancel'),
            headers: GenerateService._headers,
            body: jsonEncode({
              'ticket_id': t.id,
              'op_id': t.opId,
              'job_id': t.jobId,
            }))
        .timeout(GenerateService._timeout);
    if (r.statusCode != 200) GenerateService._fail(r, 'Iptal edilemedi');
  }
}

class QueueDepthNotifier extends ValueNotifier<int> {
  QueueDepthNotifier._() : super(0);

  Timer? _timer;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    refresh();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final u = await QueueService.unified();
      final d = u?.depth ?? (await GenerateService.queue()).depth;
      if (d != value) value = d;
    } catch (_) {
      // sunucu kapali / tunel yok - rozet oldugu gibi kalir
    }
  }
}
