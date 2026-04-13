import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiResult<T> {
  final T? data;
  final String? error;
  const ApiResult.success(this.data) : error = null;
  const ApiResult.failure(this.error) : data = null;
  bool get ok => error == null;
}

class PipelineApi {
  static const _base = 'http://localhost:8001';
  static const _headers = {'Content-Type': 'application/json'};

  static Future<http.Response> _getWithRetry(Uri uri, {int retries = 1}) async {
    for (var i = 0; i <= retries; i++) {
      try {
        return await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
      } catch (e) {
        if (i == retries) rethrow;
      }
    }
    throw Exception('Request failed');
  }

  static String _httpError(int code) => 'Server error ($code)';
  static String _friendlyError(Object e) => e.toString().replaceAll('Exception: ', '');

  static Future<ApiResult<Map<String, dynamic>>> scanPipeline() async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/pipeline/scan'));
      if (response.statusCode == 200) return ApiResult.success(jsonDecode(response.body));
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) { return ApiResult.failure(_friendlyError(e)); }
  }

  static Future<ApiResult<Map<String, dynamic>>> startPipelineMatch({bool checkFirstFrame = true}) async {
    try {
      final response = await http.post(Uri.parse('$_base/api/pipeline/match'),
          headers: _headers, body: jsonEncode({'rename': true, 'check_first_frame': checkFirstFrame}))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) return ApiResult.success(jsonDecode(response.body));
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) { return ApiResult.failure(_friendlyError(e)); }
  }

  static Future<ApiResult<Map<String, dynamic>>> getPipelineFileMetadata(String filename) async {
    try {
      final response = await http.get(
          Uri.parse('$_base/api/pipeline/file/${Uri.encodeComponent(filename)}/metadata'),
          headers: _headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return ApiResult.success(jsonDecode(response.body) as Map<String, dynamic>);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) { return ApiResult.failure(_friendlyError(e)); }
  }

  static Future<ApiResult<Map<String, dynamic>>> startPipelineTag({bool force = false}) async {
    try {
      final response = await http.post(Uri.parse('$_base/api/pipeline/tag'),
          headers: _headers, body: jsonEncode({'force': force}))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return ApiResult.success(jsonDecode(response.body));
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) { return ApiResult.failure(_friendlyError(e)); }
  }

  static Future<ApiResult<List<dynamic>>> getPipelinePairs() async {
    try {
      final response = await http.get(Uri.parse('$_base/api/pipeline/pairs'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return ApiResult.success(jsonDecode(response.body) as List<dynamic>);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) { return ApiResult.failure(_friendlyError(e)); }
  }

  static Future<ApiResult<Map<String, dynamic>>> acceptPipelinePairs({
    required List<Map<String, String>> pairs,
    required String collection,
    required String rating,
  }) async {
    try {
      final response = await http.post(Uri.parse('$_base/api/pipeline/accept'),
          headers: _headers,
          body: jsonEncode({'pairs': pairs, 'collection': collection, 'rating': rating}))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) return ApiResult.success(jsonDecode(response.body));
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) { return ApiResult.failure(_friendlyError(e)); }
  }

  static Future<ApiResult<Map<String, dynamic>>> rejectPipelineAssets(List<String> filenames) async {
    try {
      final response = await http.post(Uri.parse('$_base/api/pipeline/reject'),
          headers: _headers, body: jsonEncode({'filenames': filenames}))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return ApiResult.success(jsonDecode(response.body));
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) { return ApiResult.failure(_friendlyError(e)); }
  }

  static Future<ApiResult<Map<String, dynamic>>> generatePipelineMusic({
    required String collection, required String rating, String prompt = '',
  }) async {
    try {
      final response = await http.post(Uri.parse('$_base/api/pipeline/generate-music'),
          headers: _headers,
          body: jsonEncode({'collection': collection, 'rating': rating, 'prompt': prompt}))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return ApiResult.success(jsonDecode(response.body));
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) { return ApiResult.failure(_friendlyError(e)); }
  }

  static Future<ApiResult<Map<String, dynamic>>> pushPipelineCollection({
    required String collection, required String rating, List<int>? assetIds,
  }) async {
    try {
      final body = <String, dynamic>{'collection': collection, 'rating': rating};
      if (assetIds != null) body['asset_ids'] = assetIds;
      final response = await http.post(Uri.parse('$_base/api/pipeline/push'),
          headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return ApiResult.success(jsonDecode(response.body));
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) { return ApiResult.failure(_friendlyError(e)); }
  }

  static Future<ApiResult<List<dynamic>>> getPipelineCollections({String? rating}) async {
    try {
      final uri = rating != null
          ? Uri.parse('$_base/api/pipeline/collections?rating=$rating')
          : Uri.parse('$_base/api/pipeline/collections');
      final response = await _getWithRetry(uri);
      if (response.statusCode == 200) return ApiResult.success(jsonDecode(response.body));
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) { return ApiResult.failure(_friendlyError(e)); }
  }

  static Future<ApiResult<Map<String, dynamic>>> createPipelineCollection({
    required String name, required String rating,
  }) async {
    try {
      final response = await http.post(Uri.parse('$_base/api/pipeline/collections'),
          headers: _headers, body: jsonEncode({'name': name, 'rating': rating}))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return ApiResult.success(jsonDecode(response.body));
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) { return ApiResult.failure(_friendlyError(e)); }
  }

  static Future<ApiResult<Map<String, dynamic>>> getPipelineOpStatus(String opId) async {
    try {
      final response = await _getWithRetry(Uri.parse('$_base/api/pipeline/ops/$opId'));
      if (response.statusCode == 200) return ApiResult.success(jsonDecode(response.body));
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) { return ApiResult.failure(_friendlyError(e)); }
  }

  static Future<ApiResult<bool>> cancelPipelineOp(String opId) async {
    try {
      final response = await http.post(Uri.parse('$_base/api/pipeline/ops/$opId/cancel'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return const ApiResult.success(true);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) { return ApiResult.failure(_friendlyError(e)); }
  }

  static Future<ApiResult<List<dynamic>>> getCollectionFiles(String collection, String rating, {bool pushed = false}) async {
    try {
      final uri = Uri.parse('$_base/api/pipeline/collections/${Uri.encodeComponent(collection)}/files?rating=$rating&pushed=$pushed');
      final response = await _getWithRetry(uri);
      if (response.statusCode == 200) return ApiResult.success(jsonDecode(response.body) as List<dynamic>);
      return ApiResult.failure(_httpError(response.statusCode));
    } catch (e) { return ApiResult.failure(_friendlyError(e)); }
  }

  // URL builders
  static String pipelineThumbnailUrl(int assetId) => '$_base/api/pipeline/assets/$assetId/thumbnail';
  static String pipelineImageUrl(int assetId) => '$_base/api/pipeline/assets/$assetId/image';
  static String pipelineFileThumbUrl(String filename, {int size = 200}) =>
      '$_base/api/pipeline/file/${Uri.encodeComponent(filename)}/thumb?size=$size';
  static String pipelineFileUrl(String filename) =>
      '$_base/api/pipeline/file/${Uri.encodeComponent(filename)}';
  static String pipelineCollectionFileThumbUrl(String collection, String filename, String rating,
      {bool pushed = false, int size = 200}) =>
      '$_base/api/pipeline/collections/${Uri.encodeComponent(collection)}/file/${Uri.encodeComponent(filename)}/thumb?rating=$rating&pushed=$pushed&size=$size';
}
