import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/cache_service.dart';

/// Renders an app's server-side icon, persisting the downloaded bytes
/// in Hive so the dashboard doesn't refetch them on every cold start
/// (Flutter's default ImageCache is in-memory only and is cleared
/// whenever the OS frees the process).
///
/// The cache is keyed by `appId`; each entry stores the `iconPath`
/// it was fetched for so a server-side icon swap invalidates the
/// stored bytes automatically.
class CachedAppIcon extends StatefulWidget {
  final int appId;
  final String iconPath;
  final double size;
  final BoxFit fit;
  final WidgetBuilder errorBuilder;

  const CachedAppIcon({
    super.key,
    required this.appId,
    required this.iconPath,
    required this.size,
    required this.errorBuilder,
    this.fit = BoxFit.cover,
  });

  @override
  State<CachedAppIcon> createState() => _CachedAppIconState();
}

class _CachedAppIconState extends State<CachedAppIcon> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CachedAppIcon old) {
    super.didUpdateWidget(old);
    if (old.appId != widget.appId || old.iconPath != widget.iconPath) {
      _bytes = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final cached =
        CacheService.instance.getAppIcon(widget.appId, widget.iconPath);
    if (cached != null) {
      // Empty Uint8List is the "no icon" sentinel — the server returned
      // 404 last time, so render the fallback without refetching.
      if (cached.isEmpty) {
        if (mounted) setState(() => _failed = true);
      } else {
        if (mounted) setState(() => _bytes = cached);
      }
      return;
    }
    try {
      final resp = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/apps/${widget.appId}/icon'),
        headers: ApiService.authHeaders,
      );
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
        // Persist the negative result so we don't re-hammer /icon on
        // every dashboard paint for apps that have no icon.
        await CacheService.instance
            .setAppIcon(widget.appId, widget.iconPath, Uint8List(0));
        if (mounted) setState(() => _failed = true);
        return;
      }
      await CacheService.instance
          .setAppIcon(widget.appId, widget.iconPath, resp.bodyBytes);
      if (mounted) setState(() => _bytes = resp.bodyBytes);
    } catch (e) {
      debugPrint('CachedAppIcon: fetch failed for app ${widget.appId}: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.errorBuilder(context);
    final bytes = _bytes;
    if (bytes == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
      );
    }
    return Image.memory(
      bytes,
      width: widget.size,
      height: widget.size,
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (ctx, _, _) => widget.errorBuilder(ctx),
    );
  }
}

/// A deterministic letter avatar used as the last-resort fallback when the
/// server has no rasterised icon for an app. Color is derived from the app
/// name so each app renders with a distinctive tile even without real art.
class AppLetterAvatar extends StatelessWidget {
  final String name;
  final double size;

  const AppLetterAvatar({
    super.key,
    required this.name,
    required this.size,
  });

  static const List<Color> _palette = [
    Color(0xFFE57373), Color(0xFFF06292), Color(0xFFBA68C8),
    Color(0xFF9575CD), Color(0xFF7986CB), Color(0xFF64B5F6),
    Color(0xFF4FC3F7), Color(0xFF4DD0E1), Color(0xFF4DB6AC),
    Color(0xFF81C784), Color(0xFFAED581), Color(0xFFFFD54F),
    Color(0xFFFFB74D), Color(0xFFFF8A65), Color(0xFFA1887F),
  ];

  Color _color() {
    if (name.isEmpty) return _palette[0];
    var hash = 0;
    for (final c in name.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  String _initials() {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].characters.first.toUpperCase();
    }
    return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.35) ?? color],
        ),
      ),
      child: Text(
        _initials(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
