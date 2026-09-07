import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Baslik gerektiren bir URL'den video oynatir (dongulu, otomatik baslar).
///
/// AGB'nin dosya uclari `X-API-Key` istiyor; `Image.network` gibi
/// `VideoPlayerController.networkUrl` de httpHeaders kabul ediyor.
/// Hem "Uretilenler" goruntuleyicisi hem "Hat" ekranindaki onizleme bunu
/// kullanir - iki yerde ayri oynatici tutmayalim.
class NetworkVideo extends StatefulWidget {
  const NetworkVideo({
    super.key,
    required this.url,
    this.headers = const {},
    this.autoPlay = true,
    this.loop = true,
  });

  final String url;
  final Map<String, String> headers;
  final bool autoPlay;
  final bool loop;

  @override
  State<NetworkVideo> createState() => _NetworkVideoState();
}

class _NetworkVideoState extends State<NetworkVideo> {
  VideoPlayerController? _c;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: widget.headers,
    );
    try {
      await c.initialize();
      await c.setLooping(widget.loop);
      if (widget.autoPlay) await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _c = c);
    } catch (e) {
      await c.dispose();
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Video oynatilamadi\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      );
    }
    final c = _c;
    if (c == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return GestureDetector(
      onTap: () => setState(
          () => c.value.isPlaying ? c.pause() : c.play()),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
          if (!c.value.isPlaying)
            const DecoratedBox(
              decoration:
                  BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.play_arrow, size: 40, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
