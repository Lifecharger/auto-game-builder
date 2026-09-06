import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import '../config.dart';

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

/// Kuyruga alinmis / bitmis bir uretim isi.
class GenerateJob {
  const GenerateJob({
    required this.id,
    required this.task,
    required this.prompt,
    required this.status,
    required this.isVideo,
    this.seconds,
    this.error,
    this.fileName,
    this.createdAt,
    this.sourceJob,
  });

  final String id;
  final String task;
  final String prompt;
  final String status; // queued | running | done | error
  final bool isVideo;
  final double? seconds;
  final String? error;
  final String? fileName;
  final String? createdAt;
  final String? sourceJob;

  bool get isDone => status == 'done';
  bool get isFailed => status == 'error';
  bool get isBusy => status == 'queued' || status == 'running';

  /// Ciktinin tunel uzerinden erisilebilir adresi.
  String get fileUrl => '${ApiService.baseUrl}/api/generate/$id/file';

  factory GenerateJob.fromJson(Map<String, dynamic> j) => GenerateJob(
        id: j['id'] as String,
        task: (j['task'] ?? '') as String,
        prompt: (j['prompt'] ?? '') as String,
        status: (j['status'] ?? 'queued') as String,
        isVideo: j['is_video'] == true,
        seconds: (j['seconds'] as num?)?.toDouble(),
        error: j['error'] as String?,
        fileName: j['file_name'] as String?,
        createdAt: j['created_at'] as String?,
        sourceJob: j['source_job'] as String?,
      );
}

/// Sunucudaki yerel ComfyUI uretim koprusune baglanir.
class GenerateService {
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AppConfig.apiKey.isNotEmpty) 'X-API-Key': AppConfig.apiKey,
      };

  static Map<String, String> get authHeaders => {
        if (AppConfig.apiKey.isNotEmpty) 'X-API-Key': AppConfig.apiKey,
      };

  static const _timeout = Duration(seconds: 30);

  /// Gorev listesi + ComfyUI ayakta mi.
  static Future<({bool comfyUp, List<GenerateTask> tasks})> fetchTasks() async {
    final r = await http
        .get(Uri.parse('${ApiService.baseUrl}/api/generate/tasks'), headers: _headers)
        .timeout(_timeout);
    if (r.statusCode != 200) {
      throw Exception('Gorevler alinamadi (${r.statusCode})');
    }
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    final list = (d['tasks'] as List)
        .map((e) => GenerateTask.fromJson(e as Map<String, dynamic>))
        .toList();
    return (comfyUp: d['comfy_up'] == true, tasks: list);
  }

  /// Yeni uretim isi baslatir.
  static Future<GenerateJob> submit({
    required String task,
    required String prompt,
    String negative = '',
    int width = 0,
    int height = 0,
    int duration = 5,
    bool turbo = true,
    int? seed,
    String? imagePath,
    String? sourceJob,
  }) async {
    final r = await http
        .post(
          Uri.parse('${ApiService.baseUrl}/api/generate'),
          headers: _headers,
          body: jsonEncode({
            'task': task,
            'prompt': prompt,
            'negative': negative,
            'width': width,
            'height': height,
            'duration': duration,
            'turbo': turbo,
            if (seed != null) 'seed': seed,
            if (imagePath != null) 'image_path': imagePath,
            if (sourceJob != null) 'source_job': sourceJob,
          }),
        )
        .timeout(_timeout);
    if (r.statusCode != 200) {
      String msg = 'Istek reddedildi (${r.statusCode})';
      try {
        final d = jsonDecode(r.body);
        if (d is Map && d['detail'] != null) msg = d['detail'].toString();
      } catch (_) {}
      throw Exception(msg);
    }
    return GenerateJob.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Tek bir isin guncel durumu.
  static Future<GenerateJob> status(String jobId) async {
    final r = await http
        .get(Uri.parse('${ApiService.baseUrl}/api/generate/$jobId'), headers: _headers)
        .timeout(_timeout);
    if (r.statusCode != 200) throw Exception('Durum alinamadi (${r.statusCode})');
    return GenerateJob.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Son isler (galeri ekrani icin).
  static Future<List<GenerateJob>> list({int limit = 30}) async {
    final r = await http
        .get(Uri.parse('${ApiService.baseUrl}/api/generate?limit=$limit'), headers: _headers)
        .timeout(_timeout);
    if (r.statusCode != 200) throw Exception('Liste alinamadi (${r.statusCode})');
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return (d['jobs'] as List)
        .map((e) => GenerateJob.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
