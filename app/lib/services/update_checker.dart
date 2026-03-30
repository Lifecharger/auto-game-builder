import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateChecker {
  UpdateChecker._();
  static final UpdateChecker instance = UpdateChecker._();

  static const _repo = 'Lifecharger/auto-game-builder';
  static const _branch = 'main';

  String? latestVersion;
  String? repoRoot;
  bool _checked = false;

  /// Returns true if a newer version is available (desktop only).
  Future<bool> check() async {
    if (_checked) return latestVersion != null;
    _checked = true;

    // Only check on desktop — Google Play handles mobile updates
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return false;
    }

    // Find repo root for pull/rebuild
    repoRoot = _findRepoRoot();

    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      // Check pubspec.yaml on GitHub for the latest version
      final resp = await http.get(
        Uri.parse(
            'https://raw.githubusercontent.com/$_repo/$_branch/app/pubspec.yaml'),
      ).timeout(const Duration(seconds: 5));

      if (resp.statusCode != 200) return false;

      // Parse version from pubspec content
      final match =
          RegExp(r'version:\s*(\d+\.\d+\.\d+)\+(\d+)').firstMatch(resp.body);
      if (match == null) return false;

      final remoteVersion = match.group(1)!;
      final remoteBuild = int.tryParse(match.group(2)!) ?? 0;

      if (remoteBuild > currentBuild) {
        latestVersion = '$remoteVersion+${match.group(2)}';
        return true;
      }
    } catch (_) {
      // Network error, timeout, etc. — silently ignore
    }

    return false;
  }

  /// Find the git repo root by walking up from the exe location.
  String? _findRepoRoot() {
    try {
      var dir = File(Platform.resolvedExecutable).parent;
      // Walk up at most 6 levels to find .git
      for (var i = 0; i < 6; i++) {
        if (Directory('${dir.path}${Platform.pathSeparator}.git')
            .existsSync()) {
          return dir.path;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    } catch (_) {}
    return null;
  }

  /// Run git pull in the repo root.
  Future<String> pull() async {
    final root = repoRoot;
    if (root == null) return 'Could not find git repo';

    try {
      final result = await Process.run(
        'git',
        ['pull'],
        workingDirectory: root,
        runInShell: true,
      );
      final output = '${result.stdout}'.trim();
      final error = '${result.stderr}'.trim();
      if (result.exitCode != 0) {
        return error.isNotEmpty ? error : 'git pull failed (exit ${result.exitCode})';
      }
      return output.isNotEmpty ? output : 'Already up to date.';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Resolve flutter executable from server settings or PATH.
  String _resolveFlutter() {
    if (repoRoot != null) {
      final sep = Platform.pathSeparator;
      final settingsPath = '$repoRoot${sep}server${sep}config${sep}settings.json';
      final file = File(settingsPath);
      if (file.existsSync()) {
        try {
          final content = file.readAsStringSync();
          final match = RegExp(r'"flutter_path"\s*:\s*"([^"]+)"').firstMatch(content);
          if (match != null) {
            final path = match.group(1)!;
            if (File(path).existsSync()) return path;
            // Try .bat/.exe variants on Windows
            if (Platform.isWindows) {
              for (final ext in ['.bat', '.exe']) {
                if (File('$path$ext').existsSync()) return '$path$ext';
              }
            }
          }
        } catch (_) {}
      }
    }
    return 'flutter';
  }

  /// Run flutter build windows --release in the app/ subdirectory.
  Future<String> rebuild() async {
    final root = repoRoot;
    if (root == null) return 'Could not find git repo';

    final appDir = '$root${Platform.pathSeparator}app';
    if (!Directory(appDir).existsSync()) {
      return 'app/ directory not found in repo';
    }

    final flutter = _resolveFlutter();

    try {
      final result = await Process.run(
        flutter,
        ['build', 'windows', '--release'],
        workingDirectory: appDir,
        runInShell: true,
      );
      final output = '${result.stdout}'.trim();
      final error = '${result.stderr}'.trim();
      if (result.exitCode != 0) {
        return error.isNotEmpty ? error : 'Build failed (exit ${result.exitCode})';
      }
      return output.contains('Built') ? 'Build complete. Restart the app.' : output;
    } catch (e) {
      return 'Error: $e';
    }
  }
}
