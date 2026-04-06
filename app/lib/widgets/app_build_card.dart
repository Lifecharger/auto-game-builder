import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../services/api_service.dart';
import '../theme.dart';

class AppBuildCard extends StatefulWidget {
  final int appId;
  final String appType;
  final Map<String, dynamic>? initialDeployStatus;
  final VoidCallback onDataReload;

  const AppBuildCard({
    super.key,
    required this.appId,
    required this.appType,
    this.initialDeployStatus,
    required this.onDataReload,
  });

  @override
  State<AppBuildCard> createState() => _AppBuildCardState();
}

class _AppBuildCardState extends State<AppBuildCard> {
  Map<String, dynamic>? _deployStatus;
  bool _deploying = false;
  int _deployPollGeneration = 0;

  String _buildTarget = 'aab';
  bool _uploadAfterBuild = false;
  String _buildTrack = 'internal';

  static const Map<String, List<Map<String, String>>> _buildTargets = {
    'flutter': [
      {'key': 'apk', 'label': 'APK', 'icon': 'phone_android'},
      {'key': 'aab', 'label': 'AAB', 'icon': 'inventory_2'},
      {'key': 'exe', 'label': 'Windows', 'icon': 'desktop_windows'},
      {'key': 'web', 'label': 'Web', 'icon': 'web'},
      {'key': 'ios', 'label': 'iOS', 'icon': 'phone_iphone'},
    ],
    'godot': [
      {'key': 'apk', 'label': 'APK', 'icon': 'phone_android'},
      {'key': 'aab', 'label': 'AAB', 'icon': 'inventory_2'},
      {'key': 'windows', 'label': 'Windows', 'icon': 'desktop_windows'},
      {'key': 'web', 'label': 'Web', 'icon': 'web'},
      {'key': 'linux', 'label': 'Linux', 'icon': 'computer'},
    ],
    'phaser': [
      {'key': 'apk', 'label': 'APK', 'icon': 'phone_android'},
      {'key': 'aab', 'label': 'AAB', 'icon': 'inventory_2'},
      {'key': 'debug', 'label': 'Debug APK', 'icon': 'bug_report'},
      {'key': 'web', 'label': 'Web', 'icon': 'web'},
    ],
  };

  static const Map<String, IconData> _targetIcons = {
    'phone_android': Icons.phone_android,
    'inventory_2': Icons.inventory_2,
    'desktop_windows': Icons.desktop_windows,
    'web': Icons.web,
    'phone_iphone': Icons.phone_iphone,
    'computer': Icons.computer,
    'bug_report': Icons.bug_report,
  };

  @override
  void initState() {
    super.initState();
    _deployStatus = widget.initialDeployStatus;
    final phase = _deployStatus?['phase'] ?? 'none';
    final isActive = phase != 'none' && phase != 'done' && phase != 'failed';
    if (isActive) {
      _deploying = true;
      _pollDeployStatus();
    }
    _loadBuildPrefs();
  }

  @override
  void didUpdateWidget(AppBuildCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDeployStatus != widget.initialDeployStatus) {
      final phase = widget.initialDeployStatus?['phase'] ?? 'none';
      final isActive = phase != 'none' && phase != 'done' && phase != 'failed';
      setState(() {
        _deployStatus = widget.initialDeployStatus;
        if (isActive && !_deploying) {
          _deploying = true;
        }
      });
      if (isActive && _deploying) {
        _pollDeployStatus();
      }
    }
  }

  Future<void> _loadBuildPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final target = prefs.getString('build_target_${widget.appId}');
    final upload = prefs.getBool('build_upload_${widget.appId}');
    final track = prefs.getString('build_track_${widget.appId}');
    if (mounted) {
      setState(() {
        if (target != null) _buildTarget = target;
        if (upload != null) _uploadAfterBuild = upload;
        if (track != null) _buildTrack = track;
      });
    }
  }

  Future<void> _saveBuildPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('build_target_${widget.appId}', _buildTarget);
    prefs.setBool('build_upload_${widget.appId}', _uploadAfterBuild);
    prefs.setString('build_track_${widget.appId}', _buildTrack);
  }

  Future<void> _startBuild() async {
    final result = await ApiService.deployApp(
      widget.appId,
      track: _buildTrack,
      buildTarget: _buildTarget,
      upload: _uploadAfterBuild && _buildTarget == 'aab',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.ok ? result.data! : result.error!),
        backgroundColor: result.ok ? AppColors.success : AppColors.error,
      ));
      if (result.ok) {
        setState(() => _deploying = true);
        _pollDeployStatus();
      }
    }
  }

  Future<void> _pollDeployStatus() async {
    _deployPollGeneration++;
    final myGeneration = _deployPollGeneration;
    final deadline = DateTime.now().add(const Duration(minutes: 30));
    while (_deploying && mounted && myGeneration == _deployPollGeneration) {
      await Future.delayed(const Duration(seconds: 3));
      if (!_deploying || !mounted || myGeneration != _deployPollGeneration) return;
      if (DateTime.now().isAfter(deadline)) {
        if (mounted) {
          setState(() {
            _deploying = false;
            _deployStatus = {
              'phase': 'failed',
              'message': 'Build polling timed out after 30 minutes - check server logs',
            };
          });
        }
        return;
      }
      final result = await ApiService.getDeployStatus(widget.appId);
      if (!mounted || myGeneration != _deployPollGeneration) return;
      final status = result.data;
      setState(() => _deployStatus = status);
      final phase = status?['phase'] ?? 'none';
      if (phase == 'done' || phase == 'failed' || phase == 'none') {
        setState(() => _deploying = false);
        if (phase == 'done') widget.onDataReload();
        break;
      }
    }
  }

  Future<void> _cancelBuild() async {
    setState(() => _deploying = false);
    await Future.wait([
      ApiService.cancelDeploy(widget.appId),
      ApiService.stopAutomation(widget.appId),
    ]);
    if (mounted) {
      setState(() {
        _deployStatus = {
          'phase': 'failed',
          'message': 'Build cancelled',
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Build cancelled'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  Future<void> _retryUpload() async {
    final track = _deployStatus?['track'] ?? 'internal';
    setState(() => _deploying = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/apps/${widget.appId}/deploy/retry-upload'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'track': track}),
      ).timeout(const Duration(minutes: 5));
      if (mounted) {
        final ok = response.statusCode == 200;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Re-upload started' : 'Failed to start re-upload'),
          backgroundColor: ok ? AppColors.success : AppColors.error,
        ));
        if (ok) _pollDeployStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deploying = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appType = widget.appType.toLowerCase();
    final targets = _buildTargets[appType] ?? [];
    final phase = _deployStatus?['phase'] ?? 'none';
    final message = _deployStatus?['message'] ?? '';
    final isActive = _deploying && phase != 'none' && phase != 'done' && phase != 'failed';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.build_circle, color: AppColors.accent),
                const SizedBox(width: 8),
                const Text('Build & Deploy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),

            // Build target chips
            Text('Build Target', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: targets.map((t) {
                final key = t['key']!;
                final label = t['label']!;
                final iconKey = t['icon']!;
                final selected = _buildTarget == key;
                return GestureDetector(
                  onTap: isActive ? null : () {
                    setState(() => _buildTarget = key);
                    _saveBuildPrefs();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.accent.withValues(alpha: 0.25) : AppColors.bgDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? AppColors.accent : Colors.grey.shade700,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_targetIcons[iconKey] ?? Icons.build, size: 16,
                            color: selected ? AppColors.accent : Colors.grey.shade400),
                        const SizedBox(width: 6),
                        Text(label, style: TextStyle(fontSize: 13,
                            color: selected ? AppColors.accent : Colors.grey.shade300,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Upload toggle (only for AAB)
            Row(
              children: [
                SizedBox(
                  height: 24, width: 24,
                  child: Checkbox(
                    value: _uploadAfterBuild && _buildTarget == 'aab',
                    onChanged: _buildTarget != 'aab' || isActive ? null : (v) {
                      setState(() => _uploadAfterBuild = v ?? false);
                      _saveBuildPrefs();
                    },
                    activeColor: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Upload to Google Play',
                    style: TextStyle(fontSize: 13,
                        color: _buildTarget == 'aab' ? Colors.grey.shade200 : Colors.grey.shade600)),
              ],
            ),

            // Track selector (only when upload is on)
            if (_uploadAfterBuild && _buildTarget == 'aab') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'internal', label: Text('Internal')),
                    ButtonSegment(value: 'alpha', label: Text('Alpha')),
                    ButtonSegment(value: 'beta', label: Text('Beta')),
                    ButtonSegment(value: 'production', label: Text('Prod')),
                  ],
                  selected: {_buildTrack},
                  onSelectionChanged: isActive ? null : (set) {
                    setState(() => _buildTrack = set.first);
                    _saveBuildPrefs();
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.accent.withValues(alpha: 0.3);
                      }
                      return AppColors.bgDark;
                    }),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              if (_buildTrack == 'production')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Warning: This publishes to all users!',
                      style: TextStyle(color: AppColors.error, fontSize: 11)),
                ),
            ],
            const SizedBox(height: 14),

            // Build button
            if (!isActive)
              SizedBox(
                width: double.infinity, height: 44,
                child: FilledButton.icon(
                  onPressed: () => _startBuild(),
                  icon: const Icon(Icons.rocket_launch, size: 18),
                  label: Text(_uploadAfterBuild && _buildTarget == 'aab'
                      ? 'Build & Deploy' : 'Build'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _buildTrack == 'production' && _uploadAfterBuild && _buildTarget == 'aab'
                        ? AppColors.error : AppColors.accent,
                  ),
                ),
              ),

            // Status: Active build
            if (isActive) ...[
              LinearProgressIndicator(
                color: AppColors.accent,
                backgroundColor: AppColors.bgDark,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${phase.toUpperCase()}: $message',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _cancelBuild,
                    icon: const Icon(Icons.stop_circle_outlined, size: 16),
                    label: const Text('Stop'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ],

            // Status: Done
            if (!isActive && phase == 'done') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.success))),
                ],
              ),
            ],

            // Status: Failed
            if (!isActive && phase == 'failed') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.error, color: AppColors.error, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.error))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _retryUpload(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry Upload'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.warning.withValues(alpha: 0.2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => _startBuild(),
                    icon: const Icon(Icons.replay, size: 18),
                    label: const Text('Rebuild'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
