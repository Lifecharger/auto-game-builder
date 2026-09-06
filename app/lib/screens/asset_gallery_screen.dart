import 'package:flutter/material.dart';

import '../services/generate_service.dart';
import '../theme.dart';
import '../services/mode_service.dart';

/// Asset Mod - Uretilenler ekrani.
///
/// Sunucudaki son uretim islerini listeler; goruntuler kucuk onizleme ile,
/// videolar dosya adiyla gosterilir. Tam ekran onizleme icin karta dokun.
class AssetGalleryScreen extends StatefulWidget {
  const AssetGalleryScreen({super.key});

  @override
  State<AssetGalleryScreen> createState() => _AssetGalleryScreenState();
}

class _AssetGalleryScreenState extends State<AssetGalleryScreen> {
  List<GenerateJob> _jobs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final j = await GenerateService.list(limit: 50);
      if (!mounted) return;
      setState(() {
        _jobs = j;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _openFull(GenerateJob j) {
    if (!j.isDone || j.isVideo) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(j.fileName ?? j.id)),
        backgroundColor: Colors.black,
        body: Center(
          child: InteractiveViewer(
            child: Image.network(j.fileUrl, headers: GenerateService.authHeaders),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uretilenler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'Code Mod',
            onPressed: () => ModeService.set(false),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _jobs.isEmpty
                  ? _emptyView()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _jobs.length,
                        itemBuilder: (_, i) => _card(_jobs[i]),
                      ),
                    ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );

  Widget _emptyView() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('Henuz uretim yok'),
            SizedBox(height: 4),
            Text('Uretim sekmesinden baslayabilirsin',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );

  Widget _card(GenerateJob j) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openFull(j),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    j.isDone
                        ? (j.isVideo ? Icons.movie : Icons.image)
                        : j.isFailed
                            ? Icons.error
                            : Icons.hourglass_top,
                    size: 18,
                    color: j.isDone
                        ? AppColors.success
                        : j.isFailed
                            ? AppColors.error
                            : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      j.prompt.isEmpty ? j.task : j.prompt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(j.task,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                  const Spacer(),
                  if (j.seconds != null)
                    Text('${j.seconds!.toStringAsFixed(0)} sn',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                ],
              ),
              if (j.isFailed && j.error != null) ...[
                const SizedBox(height: 6),
                Text(j.error!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppColors.error)),
              ],
              if (j.isDone && !j.isVideo) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    j.fileUrl,
                    headers: GenerateService.authHeaders,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 60,
                      alignment: Alignment.center,
                      child: const Text('Onizleme yuklenemedi'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
