import 'dart:async';

import 'package:flutter/material.dart';

import '../services/generate_service.dart';
import '../services/mode_service.dart';
import '../theme.dart';
import '../widgets/flow_kind_switch.dart' show kindSwitchBottom;
import '../widgets/network_video.dart';
import '../widgets/generated_audio.dart';

/// #353: Asset Mod - FREE hatti (basit).
///
/// Free kipinin akisi yoktur (havuz/push yok); burasi Free uretimlerine hizli
/// ince ayar icin durur: bir gorsele dokun, alttan **Duzenle** (edit motoru,
/// kimlik korur) ya da **Video uret** (kipin hareket sablonuyla i2v). Uretilenler
/// ekranindaki goruntuleyiciyle ayni islerdir, yalnizca tek yerde toplandi.
class FreeFlowScreen extends StatefulWidget {
  const FreeFlowScreen({super.key, this.kindSwitch});

  final Widget? kindSwitch;

  @override
  State<FreeFlowScreen> createState() => _FreeFlowScreenState();
}

class _FreeFlowScreenState extends State<FreeFlowScreen> {
  List<GenerateJob> _jobs = [];
  List<GenerateTask> _tasks = [];
  GenerateJob? _sel;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_jobs.any((j) => j.isBusy)) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final j = await GenerateService.list(limit: 80, mode: 'free');
      if (_tasks.isEmpty) {
        try {
          _tasks = (await GenerateService.fetchTasks(mode: 'free')).tasks;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _jobs = j;
        if (_sel != null) {
          _sel = j.where((x) => x.id == _sel!.id).firstOrNull;
        }
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// Gorseller kart, videolar kaynak gorselin uzerinde oynatma isareti.
  List<GenerateJob> get _cards {
    final gorseller = _jobs.where((j) => j.isImage).map((j) => j.id).toSet();
    return _jobs
        .where((j) => !(j.isVideo && gorseller.contains(j.sourceJob)))
        .toList();
  }

  List<GenerateJob> _videosOf(GenerateJob j) =>
      _jobs.where((v) => v.isVideo && v.sourceJob == j.id && v.isDone).toList();

  Future<String?> _ask(String baslik, String etiket, String ipucu,
      {String onay = 'Uret'}) async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        scrollable: true,
        title: Text(baslik),
        content: TextField(
          controller: ctl,
          autofocus: true,
          maxLines: 4,
          decoration: InputDecoration(
              labelText: etiket, hintText: ipucu, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgec')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(onay)),
        ],
      ),
    );
    if (ok != true) return null;
    final t = ctl.text.trim();
    return t.isEmpty ? null : t;
  }

  /// Duzenle: edit motoru (Qwen Image Edit, kimlik korur) - yeni is acar.
  Future<void> _edit() async {
    final j = _sel;
    if (j == null || !j.isDone || !j.isImage) {
      _snack('Tamamlanmis bir gorsel sec');
      return;
    }
    final p = await _ask('Duzenle - edit motoru', 'Ne degissin',
        'orn. change the dress to red, keep face and pose');
    if (p == null) return;
    setState(() => _busy = true);
    try {
      await GenerateService.submit(task: 'edit_qwen', prompt: p, sourceJob: j.id, mode: 'free');
      _snack('Duzenleme siraya eklendi');
      _load(silent: true);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Video uret: Free kipindeki ilk gorselden-video gorevi (LTX), hareket cumlesi.
  Future<void> _video() async {
    final j = _sel;
    if (j == null || !j.isDone || !j.isImage) {
      _snack('Tamamlanmis bir gorsel sec');
      return;
    }
    final vt = _tasks.where((t) => t.isVideo && t.needsImage).firstOrNull;
    if (vt == null) {
      _snack('Free kipinde video gorevi yok');
      return;
    }
    final p = await _ask('Video uret - ${vt.label}', 'Hareket',
        'orn. she turns her head slowly toward the camera, hair moving in the breeze');
    if (p == null) return;
    setState(() => _busy = true);
    try {
      await GenerateService.submit(
          task: vt.id, prompt: p, sourceJob: j.id, mode: 'free', duration: vt.duration);
      _snack('Video siraya eklendi - bitince bu kartta oynatma isareti cikar');
      _load(silent: true);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final j = _sel;
    if (j == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sil'),
        content: Text('Bu uretim${_videosOf(j).isNotEmpty ? " ve videolari" : ""} silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgec')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      for (final v in _videosOf(j)) {
        await GenerateService.delete(v.id);
      }
      await GenerateService.delete(j.id);
      setState(() => _sel = null);
      _load(silent: true);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _big(GenerateJob j, {bool video = false}) {
    final v = video ? _videosOf(j).firstOrNull ?? (j.isVideo ? j : null) : null;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: v != null ? Colors.black : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: j.isAudio
                  ? GeneratedAudio(job: j)
                  : v != null
                  ? NetworkVideo(url: v.fileUrl, headers: GenerateService.authHeaders)
                  : InteractiveViewer(
                      child: Image.network(j.fileUrl, headers: GenerateService.authHeaders),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(j.combined.isNotEmpty ? j.combined : j.prompt,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: v != null ? Colors.white70 : null)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Free hatti'),
        bottom: kindSwitchBottom(widget.kindSwitch),
        actions: [
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'Code Mod',
            onPressed: () => ModeService.set(false),
          ),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Yenile', onPressed: _load),
        ],
      ),
      bottomNavigationBar: _sel == null ? null : _actionBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : cards.isEmpty
                  ? const Center(
                      child: Text('Free kipinde uretim yok - Uretim sekmesinden baslat',
                          style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(10),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 9 / 16,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: cards.length,
                        itemBuilder: (_, i) => _tile(cards[i]),
                      ),
                    ),
    );
  }

  Widget _tile(GenerateJob j) {
    final on = _sel?.id == j.id;
    final video = _videosOf(j).isNotEmpty || j.isVideo;
    return GestureDetector(
      onTap: () => setState(() => _sel = on ? null : j),
      onLongPress: j.isDone ? () => _big(j) : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? AppColors.accent : Colors.transparent, width: 3),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              if (j.isDone && j.isAudio)
                const Center(child: Icon(Icons.music_note, size: 48))
              else if (j.isDone)
                Image.network(j.thumbUrl(),
                    headers: GenerateService.authHeaders,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(color: Colors.white10))
              else
                Center(
                  child: Text(j.isBusy ? (j.isRunning ? '%${j.progress}' : 'sirada') : (j.error ?? j.status),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      textAlign: TextAlign.center),
                ),
              if (j.isDone && video)
                Center(
                  child: GestureDetector(
                    onTap: () => _big(j, video: true),
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.play_arrow, size: 26, color: Colors.white),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
                  color: Colors.black54,
                  child: Text(j.prompt.isEmpty ? j.task : j.prompt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBar() => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              _act(Icons.auto_fix_high, 'Duzenle', _busy || _sel?.isImage != true ? null : _edit),
              _act(Icons.movie_creation_outlined, 'Video uret', _busy || _sel?.isImage != true ? null : _video),
              _act(Icons.zoom_in, 'Buyut', _sel == null ? null : () => _big(_sel!)),
              _act(Icons.delete_outline, 'Sil', _delete),
            ],
          ),
        ),
      );

  Widget _act(IconData i, String t, VoidCallback? f) => Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                onPressed: f,
                tooltip: t,
                icon: Icon(i, size: 22),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact),
            Text(t,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, color: f == null ? Colors.grey : Colors.white70)),
          ],
        ),
      );
}
