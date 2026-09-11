import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../services/generate_service.dart';

/// Download authenticated audio only when requested, then open its player.
class GeneratedAudio extends StatefulWidget {
  const GeneratedAudio({super.key, required this.job});
  final GenerateJob job;

  @override
  State<GeneratedAudio> createState() => _GeneratedAudioState();
}

class _GeneratedAudioState extends State<GeneratedAudio> {
  bool _loading = false;

  Future<void> _open() async {
    setState(() => _loading = true);
    try {
      final job = widget.job;
      final response = await http.get(Uri.parse(job.fileUrl),
          headers: GenerateService.authHeaders).timeout(const Duration(minutes: 2));
      if (response.statusCode != 200) {
        throw Exception('Ses indirilemedi (${response.statusCode})');
      }
      final dir = await getTemporaryDirectory();
      final folder = await Directory('${dir.path}/generated_audio').create(recursive: true);
      final ext = job.fileName!.split('.').last.toLowerCase();
      final safeId = job.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${folder.path}/$safeId.$ext');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      if (!mounted) return;
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) throw Exception(result.message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_note, size: 72, color: Colors.white70),
            const SizedBox(height: 16),
            Text(widget.job.fileName ?? 'Ses', maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _open,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              label: Text(_loading ? 'Indiriliyor...' : 'Sesi ac'),
            ),
          ],
        ),
      );
}
