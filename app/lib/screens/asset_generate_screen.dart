import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/generate_service.dart';
import '../theme.dart';
import '../services/mode_service.dart';

/// Asset Mod - Uretim ekrani.
///
/// Sunucudaki manifest'ten gorev listesini ceker, promptu gonderir ve isi
/// bitene kadar durumunu yoklar. Uretim yerel ComfyUI'de calisir; telefon
/// sadece istegi acar ve sonucu gosterir.
class AssetGenerateScreen extends StatefulWidget {
  const AssetGenerateScreen({super.key});

  @override
  State<AssetGenerateScreen> createState() => _AssetGenerateScreenState();
}

class _AssetGenerateScreenState extends State<AssetGenerateScreen> {
  final _prompt = TextEditingController();
  final _negative = TextEditingController();

  List<GenerateTask> _tasks = [];
  GenerateTask? _task;
  bool _comfyUp = false;
  bool _loading = true;
  String? _loadError;

  bool _turbo = true;
  int _duration = 5;

  GenerateJob? _job;
  GenerateJob? _source;          // girdi olarak secilen onceki uretim
  List<GenerateJob> _sourceOptions = [];
  Timer? _poll;
  final List<GenerateJob> _finished = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _prompt.dispose();
    _negative.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final r = await GenerateService.fetchTasks();
      List<GenerateJob> srcs = [];
      try {
        final jobs = await GenerateService.list(limit: 50);
        srcs = jobs.where((j) => j.isDone && !j.isVideo).toList();
      } catch (_) {
        // kaynak listesi alinamazsa gorev ekrani yine acilsin
      }
      if (!mounted) return;
      setState(() {
        _sourceOptions = srcs;
        _tasks = r.tasks;
        _comfyUp = r.comfyUp;
        _task = r.tasks.isNotEmpty ? r.tasks.first : null;
        _duration = _task?.duration ?? 5;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _generate() async {
    final t = _task;
    if (t == null) return;
    if (_prompt.text.trim().isEmpty) {
      _snack('Prompt bos olamaz');
      return;
    }
    if (t.needsImage && _source == null) {
      _snack('Bu gorev bir girdi gorseli istiyor - uretilenlerden birini sec');
      return;
    }
    HapticFeedback.lightImpact();
    try {
      final job = await GenerateService.submit(
        task: t.id,
        prompt: _prompt.text.trim(),
        negative: _negative.text.trim(),
        width: t.width,
        height: t.height,
        duration: _duration,
        turbo: _turbo,
        sourceJob: t.needsImage ? _source?.id : null,
      );
      if (!mounted) return;
      setState(() => _job = job);
      _startPolling(job.id);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _startPolling(String id) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (t) async {
      try {
        final j = await GenerateService.status(id);
        if (!mounted) return;
        setState(() => _job = j);
        if (!j.isBusy) {
          t.cancel();
          if (j.isDone) {
            setState(() => _finished.insert(0, j));
          }
        }
      } catch (_) {
        // gecici ag hatasi - yoklamaya devam
      }
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uretim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'Code Mod',
            onPressed: () => ModeService.set(false),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Gorevleri yenile',
            onPressed: _loadTasks,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _errorView()
              : _form(),
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
              Text('Sunucuya baglanilamadi',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(_loadError!.replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadTasks,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );

  Widget _form() {
    final t = _task;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!_comfyUp)
          Card(
            color: AppColors.error.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: AppColors.error),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('ComfyUI kapali. Bilgisayarda baslatilmasi gerekiyor.'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        DropdownButtonFormField<GenerateTask>(
          initialValue: t,
          decoration: const InputDecoration(
            labelText: 'Gorev',
            border: OutlineInputBorder(),
          ),
          items: _tasks
              .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
              .toList(),
          onChanged: (v) => setState(() {
            _task = v;
            _duration = v?.duration ?? 5;
          }),
        ),
        if (t != null && t.needsImage) ...[
          const SizedBox(height: 12),
          if (_sourceOptions.isEmpty)
            const Text(
              'Girdi olarak kullanilabilecek uretim yok. Once bir gorsel uret.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            )
          else
            DropdownButtonFormField<GenerateJob>(
              initialValue: _source,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Girdi gorseli (uretilenlerden)',
                border: OutlineInputBorder(),
              ),
              items: _sourceOptions
                  .map((j) => DropdownMenuItem(
                        value: j,
                        child: Text(
                          j.prompt.isEmpty ? j.id : j.prompt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _source = v),
            ),
          if (_source != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _source!.fileUrl,
                headers: GenerateService.authHeaders,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _prompt,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Prompt',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _negative,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Negatif prompt (bos birakilabilir)',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Turbo'),
                subtitle: const Text('hizli mod'),
                value: _turbo,
                onChanged: (v) => setState(() => _turbo = v),
              ),
            ),
          ],
        ),
        if (t != null && t.isVideo) ...[
          const SizedBox(height: 4),
          Text('Sure: $_duration saniye'),
          Slider(
            value: _duration.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '$_duration sn',
            onChanged: (v) => setState(() => _duration = v.round()),
          ),
        ],
        const SizedBox(height: 8),
        if (t != null && t.width > 0)
          Text('Olcu: ${t.width} x ${t.height}',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: (_job?.isBusy ?? false) ? null : _generate,
          icon: (_job?.isBusy ?? false)
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: Text((_job?.isBusy ?? false) ? 'Uretiliyor...' : 'URET'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        if (_job != null) ...[
          const SizedBox(height: 20),
          _jobCard(_job!),
        ],
        if (_finished.length > 1) ...[
          const SizedBox(height: 20),
          const Text('Bu oturumda uretilenler',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._finished.skip(1).map(_jobCard),
        ],
      ],
    );
  }

  Widget _jobCard(GenerateJob j) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  j.isDone
                      ? Icons.check_circle
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
                Text(j.status,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (j.seconds != null)
                  Text('${j.seconds!.toStringAsFixed(0)} sn',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
              ],
            ),
            if (j.isFailed && j.error != null) ...[
              const SizedBox(height: 8),
              Text(j.error!,
                  style: TextStyle(fontSize: 12, color: AppColors.error)),
            ],
            if (j.isDone && !j.isVideo) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  j.fileUrl,
                  headers: GenerateService.authHeaders,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Text('Onizleme yuklenemedi'),
                ),
              ),
            ],
            if (j.isDone && j.isVideo) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.movie, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(j.fileName ?? j.id)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
