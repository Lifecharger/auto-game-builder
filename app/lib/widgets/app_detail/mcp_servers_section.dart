import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

/// Collapsible card on the App Detail screen that lists every MCP
/// server preset and lets the user toggle which are enabled for the
/// current app.
///
/// The widget owns its own loading + selection state. Initial values
/// can be passed in via [initialEnabled] / [initialPresets] so the
/// parent screen can bulk-load with the rest of its data and avoid a
/// double round-trip; if neither is provided the widget fetches
/// presets on mount.
///
/// Emits [onChanged] every time the server confirms a successful
/// update so the parent can keep its own cache in sync.
class McpServersSection extends StatefulWidget {
  final int appId;
  final Set<String> initialEnabled;
  final List<dynamic>? initialPresets;
  final ValueChanged<Set<String>>? onChanged;

  const McpServersSection({
    super.key,
    required this.appId,
    this.initialEnabled = const {},
    this.initialPresets,
    this.onChanged,
  });

  @override
  State<McpServersSection> createState() => _McpServersSectionState();
}

class _McpServersSectionState extends State<McpServersSection> {
  late Set<String> _enabled;
  List<dynamic> _presets = [];
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _enabled = Set<String>.from(widget.initialEnabled);
    if (widget.initialPresets != null) {
      _presets = widget.initialPresets!;
      _loading = false;
    } else {
      _fetchPresets();
    }
  }

  Future<void> _fetchPresets() async {
    final result = await ApiService.getMcpPresets();
    if (!mounted) return;
    setState(() {
      _presets = result.data ?? [];
      _loading = false;
    });
  }

  IconData _mcpIcon(String name) {
    switch (name) {
      case 'pixellab':
        return Icons.palette;
      case 'elevenlabs':
        return Icons.mic;
      case 'godot':
        return Icons.videogame_asset;
      case 'cloudflare':
        return Icons.cloud;
      case 'meshy':
        return Icons.view_in_ar;
      default:
        return Icons.hub;
    }
  }

  Future<void> _toggle(String name, bool sel) async {
    setState(() {
      if (sel) {
        _enabled.add(name);
      } else {
        _enabled.remove(name);
      }
    });
    final result =
        await ApiService.setAppMcp(widget.appId, _enabled.toList());
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        if (sel) {
          _enabled.remove(name);
        } else {
          _enabled.add(name);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to update MCP'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    widget.onChanged?.call(Set<String>.from(_enabled));
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _enabled.length;
    return Card(
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.hub, size: 18, color: Colors.purple.shade200),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _loading
                        ? 'MCP Servers'
                        : 'MCP Servers ($activeCount active)',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey.shade500,
                ),
              ]),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tool servers available for all AI runs on this app',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ))
                  else
                    ..._presets.map((p) {
                      final name = p['name']?.toString() ?? '';
                      final label = p['label']?.toString() ?? name;
                      final desc = p['description']?.toString() ?? '';
                      final active = _enabled.contains(name);
                      return SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(_mcpIcon(name),
                            size: 20,
                            color: active
                                ? Colors.purple.shade200
                                : Colors.grey.shade600),
                        title:
                            Text(label, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(desc,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                        value: active,
                        onChanged: (sel) => _toggle(name, sel),
                      );
                    }),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
