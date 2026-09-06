import 'dart:async';

import 'package:flutter/material.dart';

import '../services/generate_service.dart';
import '../services/mode_service.dart';
import '../theme.dart';

/// Asset Mod - Sira ekrani.
///
/// Tum emirler sunucuda tek sirali bir kuyruga girer. Burasi o kuyrugu
/// gosterir: calisan is yuzdesiyle, bekleyenler sira numarasiyla. Bekleyenler
/// tasinabilir veya iptal edilebilir.
class AssetQueueScreen extends StatefulWidget {
  const AssetQueueScreen({super.key});

  @override
  State<AssetQueueScreen> createState() => _AssetQueueScreenState();
}

class _AssetQueueScreenState extends State<AssetQueueScreen> {
  QueueState? _q;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final q = await GenerateService.queue();
      if (!mounted) return;
      setState(() {
        _q = q;
        _error = null;
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _act(Future<void> Function() f) async {
    try {
      await f();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sirayi temizle'),
        content: const Text('Bekleyen tum isler iptal edilsin mi? '
            'Calisan is devam eder.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgec')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Iptal et')),
        ],
      ),
    );
    if (ok == true) _act(GenerateService.clearQueue);
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    final items = q?.all ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sira'),
        actions: [
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'Code Mod',
            onPressed: () => ModeService.set(false),
          ),
          if (items.length > 1)
            IconButton(
              icon: const Icon(Icons.playlist_remove),
              tooltip: 'Bekleyenleri iptal et',
              onPressed: _clear,
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _error != null && q == null
          ? _errorView()
          : RefreshIndicator(
              onRefresh: _load,
              child: items.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        const Center(
                          child: Column(
                            children: [
                              Icon(Icons.done_all, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('Sira bos'),
                              SizedBox(height: 4),
                              Text('Uretim sekmesinden is ekleyebilirsin',
                                  style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length + 1,
                      itemBuilder: (_, i) {
                        if (i == 0) return _header(q!);
                        return _card(items[i - 1], items.length - 1);
                      },
                    ),
            ),
    );
  }

  Widget _header(QueueState q) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(Icons.circle,
                size: 9, color: q.comfyUp ? AppColors.success : AppColors.error),
            const SizedBox(width: 8),
            Text(q.comfyUp ? 'ComfyUI hazir' : 'ComfyUI kapali',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Spacer(),
            Text('${q.depth} is',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _card(GenerateJob j, int pendingCount) {
    final running = j.isRunning;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: running ? AppColors.accent : Colors.transparent,
          width: running ? 1.4 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: running ? AppColors.accent : Colors.white10,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: running
                      ? const Icon(Icons.play_arrow, size: 16, color: Colors.white)
                      : Text('${j.position ?? ''}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(j.task,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                Text(
                  running ? (j.node.isEmpty ? 'calisiyor' : j.node) : 'bekliyor',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              j.prompt.isEmpty ? j.combined : j.prompt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            if (running) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: j.progress > 0 ? j.progress / 100 : null,
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 4),
              Text('%${j.progress}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (!running) ...[
                  TextButton.icon(
                    onPressed: (j.position ?? 1) > 1
                        ? () => _act(() => GenerateService.move(j.id, -1))
                        : null,
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    label: const Text('Yukari', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton.icon(
                    onPressed: (j.position ?? 0) < pendingCount
                        ? () => _act(() => GenerateService.move(j.id, 1))
                        : null,
                    icon: const Icon(Icons.arrow_downward, size: 16),
                    label: const Text('Asagi', style: TextStyle(fontSize: 12)),
                  ),
                ],
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _act(() => GenerateService.cancel(j.id)),
                  icon: Icon(Icons.close, size: 16, color: AppColors.error),
                  label: Text('Iptal',
                      style: TextStyle(fontSize: 12, color: AppColors.error)),
                ),
              ],
            ),
          ],
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
}
