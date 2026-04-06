import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
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
    } catch (e) {
      debugPrint('Update check failed: $e');
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

  /// Run git pull in the repo root (safe while app is running).
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

  /// Launch update.py script and exit the app.
  /// The script pulls, rebuilds, and relaunches the exe.
  Future<String> launchUpdateAndExit() async {
    final root = repoRoot;
    if (root == null) return 'Could not find git repo';

    final updateScript = '$root${Platform.pathSeparator}update.py';
    if (!File(updateScript).existsSync()) {
      return 'update.py not found in repo root';
    }

    try {
      // Launch update.py in a visible terminal window
      await Process.start(
        'cmd',
        ['/c', 'start', 'cmd', '/k', 'python', updateScript, root],
        workingDirectory: root,
        mode: ProcessStartMode.detached,
      );

      // Exit the app so the exe is unlocked for rebuild
      exit(0);
    } catch (e) {
      return 'Error: $e';
    }
  }
}
