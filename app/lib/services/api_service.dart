import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config.dart';
import '../models/app_model.dart';
import '../models/issue_model.dart';
import '../models/build_model.dart';
import '../models/automation_model.dart';
import 'cache_service.dart';

class ApiResult<T> {
  final T? data;
  final String? error;
  bool get ok => data != null;
  const ApiResult({this.data, this.error});
  const ApiResult.success(T this.data) : error = null;
  const ApiResult.failure(String this.error) : data = null;
}

class ApiService {
  static String _friendlyError(Object e) {
    if (e is TimeoutException) return 'Connection timeout - check your network';
    if (e is SocketException) return 'Cannot reach server - check your connection';
    if (e is FormatException) return 'Invalid response from server';
    return 'Network error: ${e.runtimeType}';
  }

  static String _httpError(int statusCode) {
    if (statusCode >= 500) return 'Server error ($statusCode) - try again later';
    if (statusCode == 404) return 'Not found (404)';
    if (statusCode == 403) return 'Access denied (403)';
    if (statusCode == 401) return 'Unauthorized (401)';
    return 'Request failed ($statusCode)';
  }

  /// FastAPI reports refusals as `{"detail": "..."}`. Prefer that message over
  /// a generic status-code string so the user learns what to fix.
  static String _detailOrHttpError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } on FormatException {
      // Non-JSON error body — fall through to the generic message.
    }
    return _httpError(response.statusCode);
  }

  static String get _base => AppConfig.baseUrl;
  static String get baseUrl => _base;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // dart:io HttpClient (which IOClient wraps) auto-decompresses gzip
        // responses; this header makes the negotiation explicit so the
        // server's GZipMiddleware always kicks in even on platforms where
        // the underlying client doesn't advertise gzip by default.
        'Accept-Encoding': 'gzip',
        if (AppConfig.apiKey.isNotEmpty) 'X-API-Key': AppConfig.apiKey,
      };

  /// Auth-only headers for non-JSON requests (e.g. image loading).
  static Map<String, String> get authHeaders => {
        if (AppConfig.apiKey.isNotEmpty) 'X-API-Key': AppConfig.apiKey,
      };

  /// GET with automatic retry + exponential backoff (1s, 2s, 4s).
  /// Retries on network errors, 5xx responses, and 429 (rate-limit).
  static Future<http.Response> _getWithRetry(
    Uri uri, {
    Duration timeout = const Duration(seconds: 10),
    int maxRetries = 3,
    Map<String, String>? extraHeaders,
  }) async {
    final mergedHeaders = extraHeaders == null
        ? _headers
        : (Map<String, String>.from(_headers)..addAll(extraHeaders));
    late Object lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .get(uri, headers: mergedHeaders)
            .timeout(timeout);
        // Retry on 429 rate-limit
        if (response.statusCode == 429) {
          if (attempt == maxRetries) return response;
          final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
          await Future.delayed(Duration(seconds: retryAfter ?? (1 << attempt)));
          continue;
        }
        // Don't retry on success or other client errors (4xx) — 304 is
        // also a non-error "use your cache" signal, not something to retry.
        if (response.statusCode < 500) return response;
        // Retry on server errors
        if (attempt == maxRetries) return response;
      } catch (e) {
        lastError = e;
        if (attempt == maxRetries) rethrow;
      }
      // Exponential backoff: 1s, 2s, 4s
      await Future.delayed(Duration(seconds: 1 << attempt));
    }
    throw lastError; // unreachable, but satisfies analyzer
  }

  // Health check
  static Future<bool> healthCheck() async {
    try {
      final response = await http
          .get(Uri.parse('$_base/api/health'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Delta Sync
  static Future<ApiResult<Map<String, dynamic>>> getSync({String? since}) async {
    try {
      final uri = since != null && since.isNotEmpty
          ? Uri.parse('$_base/api/sync?since=${Uri.encodeQueryComponent(since)}')
          : Uri.parse('$_base/api/sync');
      final response = await _getWithRetry(uri, timeout: const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return ApiResult.success(jsonDecode(response.body) as Map<String, dynamic>);
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // Dashboard
  static Future<ApiResult<Map<String, dynamic>>> getDashboard() async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/dashboard'));
      if (response.statusCode == 200) {
        return ApiResult.success(jsonDecode(response.body));
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // Apps
  static Future<ApiResult<List<AppModel>>> getApps() async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/apps'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return ApiResult.success(data.map((json) => AppModel.fromJson(json)).toList());
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<AppModel>> getApp(int id) async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/apps/$id'));
      if (response.statusCode == 200) {
        return ApiResult.success(AppModel.fromJson(jsonDecode(response.body)));
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> updateApp(
      int id, Map<String, dynamic> updates) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$_base/api/apps/$id'),
            headers: _headers,
            body: jsonEncode(updates),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // Issues
  static Future<ApiResult<List<IssueModel>>> getIssues({int? appId, String? status}) async {
    try {
      final params = <String, String>{};
      if (appId != null) params['app_id'] = appId.toString();
      if (status != null && status != 'all') params['status'] = status;
      final uri = Uri.parse('$_base/api/issues').replace(queryParameters: params.isNotEmpty ? params : null);
      final response = await _getWithRetry(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return ApiResult.success(data.map((json) => IssueModel.fromJson(json)).toList());
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> createIssue(Map<String, dynamic> issue) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_base/api/issues'),
            headers: _headers,
            body: jsonEncode(issue),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> updateIssue(
      int id, Map<String, dynamic> updates) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$_base/api/issues/$id'),
            headers: _headers,
            body: jsonEncode(updates),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> deleteIssue(int id) async {
    try {
      final response = await http
          .delete(Uri.parse('$_base/api/issues/$id'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 204) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // Builds
  static Future<ApiResult<List<BuildModel>>> getBuilds({int? appId}) async {
    try {
      final params = <String, String>{};
      if (appId != null) params['app_id'] = appId.toString();
      final uri = Uri.parse('$_base/api/builds').replace(queryParameters: params.isNotEmpty ? params : null);
      final response = await _getWithRetry(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return ApiResult.success(data.map((json) => BuildModel.fromJson(json)).toList());
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // Sessions
  static Future<ApiResult<List<dynamic>>> getSessions() async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/sessions'));
      if (response.statusCode == 200) {
        return ApiResult.success(jsonDecode(response.body));
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // Deathpin
  static Future<ApiResult<Map<String, dynamic>>> getDeathpinStatus() async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/deathpin/status'));
      if (response.statusCode == 200) {
        return ApiResult.success(jsonDecode(response.body));
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<List<dynamic>>> getDeathpinTasks() async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/deathpin/tasks'));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return ApiResult.success(decoded);
        return const ApiResult.success([]);
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<List<dynamic>>> getDeathpinLog() async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/deathpin/log'));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) return ApiResult.success((decoded['lines'] as List?) ?? []);
        if (decoded is List) return ApiResult.success(decoded);
        return const ApiResult.success([]);
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> sendDeathpinDirective(
      String directive, String priority) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_base/api/deathpin/directive'),
            headers: _headers,
            body: jsonEncode({
              'message': directive,
              'priority': priority,
              'target_app': '',
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // Automations
  static Future<ApiResult<List<AutomationModel>>> getAutomations() async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/automations'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return ApiResult.success(data.map((j) => AutomationModel.fromJson(j)).toList());
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> createAutomation({
    required int appId,
    required String aiAgent,
    required int intervalMinutes,
    required int maxSessionMinutes,
    required String prompt,
  }) async {
    try {
      final body = {
        'app_id': appId,
        'ai_agent': aiAgent,
        'interval_minutes': intervalMinutes,
        'max_session_minutes': maxSessionMinutes,
        'prompt': prompt,
      };
      final response = await http
          .post(
            Uri.parse('$_base/api/automations'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> updateAutomation({
    required int appId,
    String? aiAgent,
    int? intervalMinutes,
    int? maxSessionMinutes,
    String? prompt,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (aiAgent != null) body['ai_agent'] = aiAgent;
      if (intervalMinutes != null) body['interval_minutes'] = intervalMinutes;
      if (maxSessionMinutes != null) body['max_session_minutes'] = maxSessionMinutes;
      if (prompt != null) body['prompt'] = prompt;
      final response = await http
          .patch(
            Uri.parse('$_base/api/automations/$appId'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> autoSetupMcpPresets() async {
    try {
      final response = await http
          .post(Uri.parse('$_base/api/mcp/presets/auto-setup'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> runOnceAutomation(int appId) async {
    try {
      final response = await http
          .post(Uri.parse('$_base/api/automations/$appId/run-once'),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> runTask(int appId, int taskId, {String? aiAgent}) async {
    try {
      final body = <String, dynamic>{};
      if (aiAgent != null && aiAgent.isNotEmpty) body['ai_agent'] = aiAgent;
      final response = await http
          .post(Uri.parse('$_base/api/apps/$appId/tasks/$taskId/run'),
              headers: _headers,
              body: body.isNotEmpty ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // Per-App MCP
  static Future<ApiResult<List<String>>> getAppMcp(int appId) async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/apps/$appId/mcp'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResult.success(List<String>.from(data['mcp_servers'] ?? []));
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> setAppMcp(int appId, List<String> mcpServers) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_base/api/apps/$appId/mcp'),
            headers: _headers,
            body: jsonEncode({'mcp_servers': mcpServers}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> startAutomation(int appId) async {
    try {
      final response = await http
          .post(Uri.parse('$_base/api/automations/$appId/start'),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> stopAutomation(int appId) async {
    try {
      final response = await http
          .post(Uri.parse('$_base/api/automations/$appId/stop'),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> deleteAutomation(int appId) async {
    try {
      final response = await http
          .delete(Uri.parse('$_base/api/automations/$appId'),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 204) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // App Tasks (tasklist.json)
  //
  // Cache-aware: we keep the last server response in Hive (CacheService.tasks)
  // along with its Last-Modified header. On every fetch we send
  // If-Modified-Since; the server returns 304 with no body when the file
  // hasn't moved, and we resolve from cache. On network failure we also
  // serve cached data so the screen renders instead of showing a spinner.
  //
  // Caching is keyed by appId only — we skip cache writes when a status
  // filter is in play so a filtered subset never overwrites the full list.
  static Future<ApiResult<List<dynamic>>> getAppTasks(int appId, {String? status}) async {
    final cache = CacheService.instance;
    final cacheable = status == null;
    try {
      final params = <String, String>{};
      if (status != null) params['status'] = status;
      final uri = Uri.parse('$_base/api/apps/$appId/tasks')
          .replace(queryParameters: params.isNotEmpty ? params : null);

      final extra = <String, String>{};
      if (cacheable) {
        final lm = cache.getTasksLastModified(appId);
        if (lm != null && lm.isNotEmpty) extra['If-Modified-Since'] = lm;
      }

      final response = await _getWithRetry(uri, extraHeaders: extra);

      if (response.statusCode == 304 && cacheable) {
        return ApiResult.success(cache.getTasks(appId));
      }
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final list = decoded is List ? decoded : const [];
        if (cacheable) {
          final lm = response.headers['last-modified'] ?? '';
          await cache.saveTasks(appId, list, lm);
        }
        return ApiResult.success(list);
      }
      // Hard failure — fall back to cache if we have one rather than
      // leaving the screen empty.
      if (cacheable) {
        final cached = cache.getTasks(appId);
        if (cached.isNotEmpty) return ApiResult.success(cached);
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      // Network/timeout error: serve cached if available.
      if (cacheable) {
        final cached = cache.getTasks(appId);
        if (cached.isNotEmpty) return ApiResult.success(cached);
      }
      return ApiResult.failure(_friendlyError(e));
    }
  }

  /// Server-side keyword search across active AND archived tasks
  /// (title, description and response fields).
  static Future<ApiResult<List<dynamic>>> searchAppTasks(int appId, String query) async {
    try {
      final uri = Uri.parse('$_base/api/apps/$appId/tasks/search')
          .replace(queryParameters: {'q': query});
      final response = await _getWithRetry(uri);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return ApiResult.success(decoded is List ? decoded : const []);
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  /// Absolute URL for a task attachment served by the API.
  static String taskAttachmentUrl(int appId, int taskId, int index) =>
      '$_base/api/apps/$appId/tasks/$taskId/attachments/$index';

  /// Download an attachment into the app cache and return the local path.
  /// The attachment endpoint requires the API key header, so an external
  /// viewer cannot fetch the URL itself — the bytes have to come through here.
  static Future<ApiResult<String>> downloadAttachment(
    String url, {
    required String filename,
  }) async {
    try {
      final uri = Uri.parse(url.startsWith('http') ? url : '$_base$url');
      final response = await http
          .get(uri, headers: authHeaders)
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        return ApiResult.failure(_httpError(response.statusCode));
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/attachments/$filename');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes);
      return ApiResult.success(file.path);
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<Map<String, dynamic>>> getAppTasksStatus(int appId) async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/apps/$appId/tasks/status'));
      if (response.statusCode == 200) {
        return ApiResult.success(jsonDecode(response.body));
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> createAppTask({
    required int appId,
    required String title,
    String? description,
    String taskType = 'issue',
    String priority = 'normal',
    List<String>? attachments,
    List<int>? dependsOn,
  }) async {
    try {
      final body = <String, dynamic>{
        'title': title,
        'task_type': taskType,
        'priority': priority,
      };
      if (description != null && description.isNotEmpty) {
        body['description'] = description;
      }
      if (attachments != null && attachments.isNotEmpty) {
        body['attachments'] = attachments;
      }
      if (dependsOn != null && dependsOn.isNotEmpty) {
        body['depends_on'] = dependsOn;
      }
      final response = await http
          .post(
            Uri.parse('$_base/api/apps/$appId/tasks'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: attachments != null && attachments.isNotEmpty ? 120 : 10));
      if (response.statusCode == 200 || response.statusCode == 201) return const ApiResult.success(true);
      // A rejected attachment (unsupported type, too large) comes back as a
      // 400 with a human-readable detail — show it instead of a bare code.
      if (response.statusCode == 400) {
        return ApiResult.failure(_detailOrHttpError(response));
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> updateAppTask(int appId, int taskId, Map<String, dynamic> updates) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$_base/api/apps/$appId/tasks/$taskId'),
            headers: _headers,
            body: jsonEncode(updates),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> deleteAppTask(int appId, int taskId) async {
    try {
      final response = await http
          .delete(Uri.parse('$_base/api/apps/$appId/tasks/$taskId'),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 204) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // Ideas
  static Future<ApiResult<List<dynamic>>> getIdeas({int? appId}) async {
    try {
      final params = <String, String>{};
      if (appId != null) params['app_id'] = appId.toString();
      final uri = Uri.parse('$_base/api/ideas')
          .replace(queryParameters: params.isNotEmpty ? params : null);
      final response = await _getWithRetry(uri);
      if (response.statusCode == 200) {
        return ApiResult.success(jsonDecode(response.body));
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> deleteIdea(int ideaId) async {
    try {
      final response = await http
          .delete(Uri.parse('$_base/api/ideas/$ideaId'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 204) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // Logs
  static Future<ApiResult<List<dynamic>>> getLogs({int? appId, int limit = 50}) async {
    try {
      final params = <String, String>{'limit': limit.toString()};
      if (appId != null) params['app_id'] = appId.toString();
      final uri = Uri.parse('$_base/api/logs')
          .replace(queryParameters: params);
      final response = await _getWithRetry(uri);
      if (response.statusCode == 200) {
        return ApiResult.success(jsonDecode(response.body));
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<Map<String, dynamic>>> getAutomationStatus(int appId) async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/automations/$appId/status'));
      if (response.statusCode == 200) {
        return ApiResult.success(jsonDecode(response.body));
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // Create App
  static Future<ApiResult<Map<String, dynamic>>> createApp({
    required String name,
    String appType = 'flutter',
    String fixStrategy = 'claude',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_base/api/apps'),
            headers: _headers,
            body: jsonEncode({
              'name': name,
              'app_type': appType,
              'fix_strategy': fixStrategy,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResult.success(jsonDecode(response.body));
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // GDD
  static Future<ApiResult<String>> getGdd(int appId) async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/apps/$appId/gdd'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResult.success((data['content'] as String?) ?? '');
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> updateGdd(int appId, String content) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_base/api/apps/$appId/gdd'),
            headers: _headers,
            body: jsonEncode({'content': content}),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  /// Fire-and-forget GDD enhance: triggers background enhance on server.
  static Future<ApiResult<bool>> enhanceGdd(int appId, String currentContent) async {
    try {
      final response = await http
          .post(Uri.parse('$_base/api/apps/$appId/enhance'),
              headers: _headers,
              body: jsonEncode({'type': 'gdd'}))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // Claude.md
  static Future<ApiResult<String>> getClaudeMd(int appId) async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/apps/$appId/claude-md'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResult.success((data['content'] as String?) ?? '');
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> updateClaudeMd(int appId, String content) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_base/api/apps/$appId/claude-md'),
            headers: _headers,
            body: jsonEncode({'content': content}),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> enhanceClaudeMd(int appId, String currentContent) async {
    try {
      final response = await http
          .post(Uri.parse('$_base/api/apps/$appId/enhance'),
              headers: _headers,
              body: jsonEncode({'type': 'claude-md'}))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // Art Bible
  static Future<ApiResult<String>> getArtBible(int appId) async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/apps/$appId/art-bible'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResult.success((data['content'] as String?) ?? '');
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> updateArtBible(int appId, String content) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_base/api/apps/$appId/art-bible'),
            headers: _headers,
            body: jsonEncode({'content': content}),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> enhanceArtBible(int appId, String currentContent) async {
    try {
      final response = await http
          .post(Uri.parse('$_base/api/apps/$appId/enhance'),
              headers: _headers,
              body: jsonEncode({'type': 'art-bible'}))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<Map<String, dynamic>>> getEnhanceStatus(int appId) async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/apps/$appId/enhance/status'));
      if (response.statusCode == 200) {
        return ApiResult.success(jsonDecode(response.body) as Map<String, dynamic>);
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // Deploy / Build
  static Future<ApiResult<String>> deployApp(
    int appId, {
    String track = 'internal',
    String buildTarget = 'aab',
    bool upload = false,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_base/api/apps/$appId/deploy'),
            headers: _headers,
            body: jsonEncode({
              'track': track,
              'build_target': buildTarget,
              'upload': upload,
            }),
          )
          .timeout(const Duration(minutes: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResult.success(data['message']?.toString() ?? 'Build started');
      }
      final errorData = jsonDecode(response.body);
      return ApiResult.failure(errorData['detail']?.toString() ?? _httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<Map<String, dynamic>>> getDeployStatus(int appId) async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/apps/$appId/deploy/status'));
      if (response.statusCode == 200) {
        return ApiResult.success(jsonDecode(response.body));
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<String>> cancelDeploy(int appId) async {
    try {
      final response = await http
          .post(Uri.parse('$_base/api/apps/$appId/deploy/cancel'), headers: _headers)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResult.success(data['message']?.toString() ?? 'Build cancelled');
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // Server Reset
  static Future<ApiResult<String>> resetServer() async {
    try {
      final response = await http
          .post(Uri.parse('$_base/api/reset'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResult.success(data['message']?.toString() ?? 'Server reset successful');
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // Agent Chat
  static Future<ApiResult<Map<String, dynamic>>> askAgent({
    required String question,
    int? appId,
    String agent = 'claude',
    String? sessionId,
    List<Map<String, String>>? history,
    String? appContext,
    String? model,
    int? timeoutSeconds,
  }) async {
    try {
      final body = <String, dynamic>{
        'question': question,
        'agent': agent,
      };
      if (appId != null) body['app_id'] = appId;
      if (sessionId != null) body['session_id'] = sessionId;
      if (history != null && history.isNotEmpty) body['history'] = history;
      if (appContext != null) body['context'] = appContext;
      if (model != null) body['model'] = model;
      if (timeoutSeconds != null) body['timeout'] = timeoutSeconds;
      final response = await http
          .post(
            Uri.parse('$_base/api/chat'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: timeoutSeconds ?? 120));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResult.success({
          'response': data['response']?.toString() ?? '',
          'session_id': data['session_id']?.toString(),
        });
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // MCP Presets
  static Future<ApiResult<List<dynamic>>> getMcpPresets() async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/mcp/presets'));
      if (response.statusCode == 200) {
        return ApiResult.success(jsonDecode(response.body));
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> enableMcpPreset(String name, {String? apiKey}) async {
    try {
      final body = <String, dynamic>{};
      if (apiKey != null && apiKey.isNotEmpty) body['api_key'] = apiKey;
      final response = await http
          .post(
            Uri.parse('$_base/api/mcp/presets/$name/enable'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  static Future<ApiResult<bool>> disableMcpPreset(String name) async {
    try {
      final response = await http
          .delete(Uri.parse('$_base/api/mcp/presets/$name'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  // (Pipeline methods removed — moved to Pixel Guy project)
  // MARKER_DELETE_START

  // ── Game Studio Endpoints ──────────────────────────────────

  /// Create a Game Studio specialist task (design-review, code-review, balance-check)
  static Future<ApiResult<Map<String, dynamic>>> studioAction(int appId, String action) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_base/api/apps/$appId/studio/$action'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return ApiResult.success(jsonDecode(response.body));
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  /// Create a new project via Game Studio brainstorm
  static Future<ApiResult<Map<String, dynamic>>> studioBrainstorm({
    String concept = '',
    String genre = '',
    String platform = 'mobile',
    String appType = 'godot',
    String name = '',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_base/api/studio/brainstorm'),
            headers: _headers,
            body: jsonEncode({
              'concept': concept,
              'genre': genre,
              'platform': platform,
              'app_type': appType,
              'name': name,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return ApiResult.success(jsonDecode(response.body));
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

  /// List available Game Studio knowledge files
  static Future<ApiResult<List<dynamic>>> getStudioKnowledge() async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/studio/knowledge'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResult.success(data['files'] ?? []);
      }
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) {
      return ApiResult.failure(_friendlyError(e));
    }
  }

}
