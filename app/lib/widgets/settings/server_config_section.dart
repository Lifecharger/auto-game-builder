import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme.dart';

/// Editor card for the desktop server's `settings.json` file.
///
/// Owns its controller map + edit/save/dispose lifecycle. The parent
/// supplies the parsed map (and the on-disk path); after a successful
/// save the widget rewrites the file and invokes [onReload] so the
/// parent can refresh other UI that consumes the same map.
class ServerConfigSection extends StatefulWidget {
  final Map<String, dynamic>? serverSettings;
  final String? settingsPath;
  final VoidCallback onReload;

  const ServerConfigSection({
    super.key,
    required this.serverSettings,
    required this.settingsPath,
    required this.onReload,
  });

  @override
  State<ServerConfigSection> createState() => _ServerConfigSectionState();
}

class _ServerConfigSectionState extends State<ServerConfigSection> {
  final Map<String, TextEditingController> _controllers = {};
  bool _editing = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    HapticFeedback.lightImpact();
    final path = widget.settingsPath;
    final settings = widget.serverSettings;
    if (path == null || settings == null) return;

    for (final entry in _controllers.entries) {
      final keys = entry.key.split('.');
      if (keys.length != 2) continue;
      final section = settings[keys[0]];
      if (section is! Map<String, dynamic>) continue;
      final val = entry.value.text.trim();
      if (section[keys[1]] is bool) {
        section[keys[1]] = val.toLowerCase() == 'true';
      } else if (section[keys[1]] is int) {
        section[keys[1]] = int.tryParse(val) ?? section[keys[1]];
      } else {
        section[keys[1]] = val;
      }
    }

    try {
      const encoder = JsonEncoder.withIndent('  ');
      await File(path).writeAsString(encoder.convert(settings));
      if (!mounted) return;
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved — restart server to apply'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  static const Map<String, String> _sectionLabels = {
    'paths': 'Paths',
    'ai_agents': 'AI Agents',
    'engines': 'Game Engines',
    'system': 'System Tools',
    'cloudflare': 'Cloudflare',
    'developer': 'Developer',
    'server': 'Server',
    'services': 'Services',
  };

  static const Map<String, IconData> _fieldIcons = {
    'projects_root': Icons.folder,
    'keys_dir': Icons.key,
    'tools_dir': Icons.build,
    'service_account_key': Icons.vpn_key,
    'claude_path': Icons.smart_toy,
    'gemini_path': Icons.smart_toy,
    'codex_path': Icons.smart_toy,
    'aider_path': Icons.smart_toy,
    'flutter_path': Icons.flutter_dash,
    'godot_path': Icons.videogame_asset,
    'bash_path': Icons.terminal,
    'cloudflared_path': Icons.cloud,
    'npx_path': Icons.code,
    'tunnel_enabled': Icons.router,
    'kv_namespace_id': Icons.storage,
    'account_id': Icons.account_box,
    'worker_url': Icons.link,
    'developer_name': Icons.person,
    'host': Icons.dns,
    'port': Icons.numbers,
    'ollama_url': Icons.psychology,
  };

  Widget _buildField(String section, String key, dynamic value) {
    final fullKey = '$section.$key';
    if (!_controllers.containsKey(fullKey)) {
      _controllers[fullKey] = TextEditingController(text: value.toString());
    }
    final controller = _controllers[fullKey]!;
    if (!_editing) {
      controller.text = value.toString();
    }
    final icon = _fieldIcons[key] ?? Icons.settings;
    final label = key.replaceAll('_', ' ').replaceAllMapped(
        RegExp(r'(^|\s)(\w)'), (m) => '${m[1]}${m[2]!.toUpperCase()}');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        readOnly: !_editing,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          isDense: true,
          filled: !_editing,
          fillColor: _editing ? null : Colors.grey.withAlpha(15),
        ),
        style: TextStyle(
          fontSize: 13,
          color: _editing ? Colors.white : Colors.grey.shade400,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.serverSettings;
    if (settings == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(Icons.settings_applications, color: AppColors.warning),
                  SizedBox(width: 8),
                  Text('Server Configuration',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Text('settings.json not found',
                  style: TextStyle(color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }

    final sections = <Widget>[];
    for (final sectionKey in _sectionLabels.keys) {
      final sectionData = settings[sectionKey];
      if (sectionData is! Map<String, dynamic> || sectionData.isEmpty) continue;

      sections.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(
          _sectionLabels[sectionKey]!,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
            letterSpacing: 1,
          ),
        ),
      ));

      for (final entry in sectionData.entries) {
        sections.add(_buildField(sectionKey, entry.key, entry.value));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.settings_applications, color: AppColors.warning),
                SizedBox(width: 8),
                Text('Server Configuration',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'settings.json — restart server after changes',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            ...sections,
            const SizedBox(height: 8),
            Row(
              children: [
                if (!_editing)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _editing = true),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                  ),
                if (_editing) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        widget.onReload();
                        setState(() => _editing = false);
                      },
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Save'),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  onPressed: widget.onReload,
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Reload',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
