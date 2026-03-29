import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// A server connection stored in Google Drive appDataFolder.
class ServerConnection {
  final String name;
  final String url;
  final String lastConnected;

  ServerConnection({
    required this.name,
    required this.url,
    required this.lastConnected,
  });

  factory ServerConnection.fromJson(Map<String, dynamic> json) {
    return ServerConnection(
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      lastConnected: json['lastConnected'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'lastConnected': lastConnected,
      };

  /// Returns a copy with updated fields.
  ServerConnection copyWith({
    String? name,
    String? url,
    String? lastConnected,
  }) {
    return ServerConnection(
      name: name ?? this.name,
      url: url ?? this.url,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }
}

class DriveService {
  DriveService._();
  static final DriveService instance = DriveService._();

  static const String _fileName = 'servers.json';
  static const String _driveApiBase = 'https://www.googleapis.com/drive/v3';
  static const String _driveUploadBase =
      'https://www.googleapis.com/upload/drive/v3';

  /// Load all saved servers from Drive's appDataFolder.
  Future<List<ServerConnection>> loadServers() async {
    final headers = await AuthService.instance.getAuthHeaders();
    if (headers == null) return [];

    try {
      // 1. Find the file in appDataFolder
      final fileId = await _findFileId(headers);
      if (fileId == null) return [];

      // 2. Download its contents
      final content = await _downloadFile(fileId, headers);
      if (content == null) return [];

      final data = jsonDecode(content) as Map<String, dynamic>;
      final serversList = data['servers'] as List<dynamic>? ?? [];
      return serversList
          .map((e) => ServerConnection.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Add or update a server (matched by URL).
  Future<void> saveServer(ServerConnection server) async {
    final servers = await loadServers();

    // Replace existing entry with same URL, or add new
    final index = servers.indexWhere((s) => s.url == server.url);
    if (index >= 0) {
      servers[index] = server;
    } else {
      servers.add(server);
    }

    await _writeServers(servers);
  }

  /// Remove a server by URL.
  Future<void> removeServer(String url) async {
    final servers = await loadServers();
    servers.removeWhere((s) => s.url == url);
    await _writeServers(servers);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Find the file ID of servers.json in appDataFolder.
  Future<String?> _findFileId(Map<String, String> headers) async {
    final query = Uri.encodeQueryComponent(
        "name = '$_fileName' and 'appDataFolder' in parents and trashed = false");
    final uri = Uri.parse(
        '$_driveApiBase/files?spaces=appDataFolder&q=$query&fields=files(id)');

    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final files = data['files'] as List<dynamic>? ?? [];
    if (files.isEmpty) return null;

    return (files.first as Map<String, dynamic>)['id'] as String?;
  }

  /// Download file content by ID.
  Future<String?> _downloadFile(
      String fileId, Map<String, String> headers) async {
    final uri =
        Uri.parse('$_driveApiBase/files/$fileId?alt=media');
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) return null;
    return response.body;
  }

  /// Write the full server list to Drive (create or update).
  Future<void> _writeServers(List<ServerConnection> servers) async {
    final headers = await AuthService.instance.getAuthHeaders();
    if (headers == null) return;

    final jsonContent =
        jsonEncode({'servers': servers.map((s) => s.toJson()).toList()});

    final fileId = await _findFileId(headers);

    if (fileId != null) {
      // Update existing file
      await _updateFile(fileId, jsonContent, headers);
    } else {
      // Create new file in appDataFolder
      await _createFile(jsonContent, headers);
    }
  }

  /// Create a new file in appDataFolder.
  Future<void> _createFile(
      String content, Map<String, String> headers) async {
    // Multipart upload: metadata + content
    final metadata = jsonEncode({
      'name': _fileName,
      'parents': ['appDataFolder'],
    });

    const boundary = '---drive_boundary---';
    final body = '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json\r\n\r\n'
        '$content\r\n'
        '--$boundary--';

    final uri = Uri.parse(
        '$_driveUploadBase/files?uploadType=multipart');

    await http.post(
      uri,
      headers: {
        ...headers,
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );
  }

  /// Update an existing file's content.
  Future<void> _updateFile(
      String fileId, String content, Map<String, String> headers) async {
    final uri = Uri.parse(
        '$_driveUploadBase/files/$fileId?uploadType=media');

    await http.patch(
      uri,
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: content,
    );
  }
}
