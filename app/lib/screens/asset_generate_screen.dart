import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/generate_service.dart';
import '../services/jigsaw_profiles.dart';
import '../theme.dart';
import '../services/mode_service.dart';

/// Asset Mod - Uretim ekrani.
///
/// Ust kisimda kip secimi vardir (Free Mod / Jigsaw Modu) ve arayuz kipe gore
/// degisir. Emirler sunucudaki tek sirali kuyruga girer; bu ekran isi acar,
/// takibi Sira sekmesinden yapilir.
///
/// Jigsaw kipinde masaustundeki Uretim Studyosu ile ayni duzen vardir:
/// derece secimi (Hot Jigsaw / Kid Jigsaw), konu prompt'unun altinda detay
/// dropdown'lari (her birinde kilit), "Karistir" ve "Rastgele uret N".
/// Kilitli alan karisimda sabit kalir; dropdown doluysa Pozitif 2 sablonunun
/// ayni seyi soyleyen parcasi gonderimden dusulur.
class AssetGenerateScreen extends StatefulWidget {
  const AssetGenerateScreen({super.key});

  @override
  State<AssetGenerateScreen> createState() => _AssetGenerateScreenState();
}

class _AssetGenerateScreenState extends State<AssetGenerateScreen> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  final _negative = TextEditingController();

  List<GenerateMode> _modes = [];
  String _mode = 'free';
  List<GenerateTask> _tasks = [];
  GenerateTask? _task;

  // --- jigsaw derece profilleri (her derecenin kendi secim/kilit durumu)
  Map<String, JigsawProfile> _profiles = {};
  final Map<String, DetailState> _details = {};
  String _rating = 'hot';
  int _randomCount = 10;

  DetailState? get _det => _details[_rating];

  bool _comfyUp = false;
  bool _loading = true;
  bool _sending = false;
  String? _loadError;

  bool _turbo = true;
  int _duration = 5;
  int _count = 1;

  GenerateJob? _source;                  // girdi olarak secilen onceki uretim
  List<GenerateJob> _sourceOptions = [];
  int _queueDepth = 0;
  Timer? _poll;

  GenerateMode get _modeDef => _modes.firstWhere((m) => m.id == _mode,
      orElse: () => const GenerateMode(
          id: 'free', label: 'Free Mod', prompt2: '', motion2: '',
          negative: '', exports: false));

  @override
  void initState() {
    super.initState();
    _loadAll();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _pollQueue());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _p1.dispose();
    _p2.dispose();
    _negative.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- yukleme
  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final r = await GenerateService.fetchTasks(mode: _mode);
      final profs = await JigsawProfiles.load();
      List<GenerateJob> srcs = [];
      try {
        final jobs = await GenerateService.list(limit: 60);
        srcs = jobs.where((j) => j.isDone && !j.isVideo).toList();
      } catch (_) {
        // kaynak listesi alinamazsa gorev ekrani yine acilsin
      }
      if (!mounted) return;
      setState(() {
        _sourceOptions = srcs;
        if (_source != null && !srcs.any((j) => j.id == _source!.id)) _source = null;
        _tasks = r.tasks;
        if (r.modes.isNotEmpty) _modes = r.modes;
        _comfyUp = r.comfyUp;
        _task = r.tasks.isNotEmpty ? r.tasks.first : null;
        _duration = _task?.duration ?? 5;
        _profiles = profs;
        for (final e in profs.entries) {
          _details.putIfAbsent(e.key, () => DetailState(e.value));
        }
        _loading = false;
      });
      _applyModeDefaults();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pollQueue() async {
    try {
      final q = await GenerateService.queue();
      if (!mounted) return;
      setState(() {
        _queueDepth = q.depth;
        _comfyUp = q.comfyUp;
      });
    } catch (_) {}
  }

  /// Kip degisince ikinci pozitif ve negatif promptu kipin sablonuyla doldurur.
  void _applyModeDefaults() {
    final m = _modeDef;
    final isVideo = _task?.isVideo ?? false;
    var p2 = isVideo ? m.motion2 : m.prompt2;
    var neg = m.negative;
    if (_mode == 'jigsaw') {
      final p = _profiles[_rating];
      if (p != null) {
        if (!isVideo && p.template.isNotEmpty) p2 = p.template;
        if (p.negative.isNotEmpty) neg = p.negative;
      }
    }
    setState(() {
      _p2.text = p2;
      _negative.text = neg;
    });
  }

  /// Derece degisti: alanlar ve sablon degisir, secim/kilit durumu korunur.
  void _setRating(String id) {
    if (id == _rating) return;
    setState(() => _rating = id);
    HapticFeedback.selectionClick();
    _applyModeDefaults();
  }

  void _setMode(String id) {
    if (id == _mode) return;
    setState(() => _mode = id);
    HapticFeedback.selectionClick();
    _loadAll();
  }

  /// Konu prompt'u + secili detaylar (jigsaw disinda sadece konu).
  String _prompt1([Map<String, String>? v]) {
    if (_mode != 'jigsaw' || _det == null) return _p1.text.trim();
    return _det!.promptWith(_p1.text, v);
  }

  /// Sablon; dropdown'un kapsadigi parcalar dusulmus halde.
  String _prompt2([Map<String, String>? v]) {
    if (_mode != 'jigsaw' || _det == null) return _p2.text.trim();
    return _det!.templateFor(_p2.text,
        isVideo: _task?.isVideo ?? false, v: v);
  }

  /// Iki pozitif promptu birlestirir - sunucudaki kuralin aynisi.
  String _combine(String p1, String p2) {
    if (p2.isEmpty) return p1;
    if (p2.contains('{}')) return p2.replaceAll('{}', p1);
    return p1.isEmpty ? p2 : '$p1, $p2';
  }

  String get _combined => _combine(_prompt1(), _prompt2());

  // -------------------------------------------------------------- uretim
  Future<void> _generate() async {
    final t = _task;
    if (t == null) return;
    if (_prompt1().isEmpty && _prompt2().isEmpty) {
      _snack('Prompt bos olamaz');
      return;
    }
    if (t.needsImage && _source == null) {
      _snack('Bu gorev bir girdi gorseli istiyor - uretilenlerden birini sec');
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _sending = true);
    try {
      for (var i = 0; i < _count; i++) {
        await GenerateService.submit(
          task: t.id,
          prompt: _prompt1(),
          prompt2: _prompt2(),
          negative: _negative.text.trim(),
          width: t.width,
          height: t.height,
          duration: _duration,
          turbo: _turbo,
          mode: _mode,
          category: '',
          sourceJob: t.needsImage ? _source?.id : null,
        );
      }
      if (!mounted) return;
      _snack(_count > 1 ? '$_count is siraya eklendi' : 'Siraya eklendi');
      _pollQueue();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // -------------------------------------------------------------- arayuz
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uretim'),
        actions: [
          if (_queueDepth > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_queueDepth sirada',
                    style: const TextStyle(fontSize: 11, color: Colors.white)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'Code Mod',
            onPressed: () => ModeService.set(false),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _loadAll,
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
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );

  Widget _form() {
    final t = _task;
    final jigsaw = _mode == 'jigsaw';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _modeSwitch(),
        const SizedBox(height: 14),
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
                    child: Text('ComfyUI kapali. Isler siraya girer ama '
                        'baslamaz - bilgisayarda acilmasi gerekiyor.'),
                  ),
                ],
              ),
            ),
          ),
        DropdownButtonFormField<GenerateTask>(
          initialValue: t,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Gorev',
            border: OutlineInputBorder(),
          ),
          items: _tasks
              .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
              .toList(),
          onChanged: (v) {
            setState(() {
              _task = v;
              _duration = v?.duration ?? 5;
            });
            _applyModeDefaults();
          },
        ),
        if (jigsaw) ...[
          const SizedBox(height: 12),
          _ratingSwitch(),
        ],
        if (t != null && t.needsImage) ...[
          const SizedBox(height: 16),
          const Text('Girdi gorseli',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          _sourceStrip(),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _p1,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Pozitif prompt 1 - konu',
            hintText: 'orn: police officer',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        if (jigsaw) ...[
          const SizedBox(height: 12),
          _detailPanel(),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _p2,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Pozitif prompt 2 - sablon',
            helperText: '{} birinci promptun yerine gecer. Bos birakilabilir.',
            helperMaxLines: 2,
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          title: const Text('Gidecek prompt', style: TextStyle(fontSize: 13)),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 12),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_combined.isEmpty ? '(bos)' : _combined,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ],
        ),
        TextField(
          controller: _negative,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Negatif prompt',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Turbo'),
          subtitle: const Text('hizli mod'),
          value: _turbo,
          onChanged: (v) => setState(() => _turbo = v),
        ),
        if (t != null && t.isVideo) ...[
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
        Text('Adet: $_count'),
        Slider(
          value: _count.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          label: '$_count',
          onChanged: (v) => setState(() => _count = v.round()),
        ),
        if (t != null && t.width > 0)
          Text('Olcu: ${t.width} x ${t.height}',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _sending ? null : _generate,
          icon: _sending
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.playlist_add),
          label: Text(_sending ? 'Gonderiliyor...' : 'SIRAYA EKLE'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
        const SizedBox(height: 8),
        const Text('Isler sirayla uretilir. Takibi Sira sekmesinden yapabilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  /// Derece secimi - Hot Jigsaw / Kid Jigsaw. Gorevin hemen altinda durur.
  Widget _ratingSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: JigsawProfiles.ratings.entries.map((e) {
          final on = e.key == _rating;
          return Expanded(
            child: GestureDetector(
              onTap: () => _setRating(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: on ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  e.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: on ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Konu prompt'unun altindaki detay dropdown'lari + kilitler + randomizer.
  Widget _detailPanel() {
    final d = _det;
    if (d == null) return const SizedBox.shrink();
    if (JigsawProfiles.loadError != null && !d.hasAnyOption) {
      return Card(
        color: AppColors.error.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(JigsawProfiles.loadError!,
              style: TextStyle(color: AppColors.error, fontSize: 12)),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detaylar - bos birakilabilir, kilitli olanlar karismaz',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 6),
            for (final f in d.profile.fields) _detailRow(d, f),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => d.apply(d.roll())),
                    icon: const Icon(Icons.casino, size: 18),
                    label: const Text('Karistir'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(d.clearUnlocked),
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Temizle'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _sending ? null : _randomGenerate,
                    icon: const Icon(Icons.shuffle, size: 18),
                    label: Text('Rastgele uret  $_randomCount'),
                  ),
                ),
              ],
            ),
            Slider(
              value: _randomCount.toDouble(),
              min: 1,
              max: 50,
              divisions: 49,
              label: '$_randomCount',
              onChanged: (v) => setState(() => _randomCount = v.round()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(DetailState d, JigsawField f) {
    final pool = d.profile.optionsFor(f.key);
    final val = d.valueOf(f.key);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: pool.contains(val) ? val : '',
              isExpanded: true,
              isDense: true,
              decoration: InputDecoration(
                labelText: f.label,
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              items: [
                const DropdownMenuItem(
                    value: '',
                    child: Text('-', style: TextStyle(color: Colors.grey))),
                ...pool.map((o) => DropdownMenuItem(
                    value: o,
                    child: Text(o, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() => d.values[f.key] = v ?? ''),
            ),
          ),
          IconButton(
            tooltip: d.isLocked(f.key) ? 'kilitli - karisimda sabit' : 'kilitle',
            icon: Icon(d.isLocked(f.key) ? Icons.lock : Icons.lock_open,
                size: 20,
                color: d.isLocked(f.key) ? AppColors.accent : Colors.grey),
            onPressed: () =>
                setState(() => d.locks[f.key] = !d.isLocked(f.key)),
          ),
        ],
      ),
    );
  }

  /// Her is icin kilitsiz detaylari yeniden cekip N is siraya atar.
  Future<void> _randomGenerate() async {
    final t = _task;
    final d = _det;
    if (t == null || d == null) return;
    if (!d.hasAnyOption) {
      _snack(JigsawProfiles.loadError ?? 'Secenek listesi bos');
      return;
    }
    if (t.needsImage && _source == null) {
      _snack('Bu gorev bir girdi gorseli istiyor');
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _sending = true);
    var n = 0;
    Map<String, String>? last;
    try {
      for (var i = 0; i < _randomCount; i++) {
        last = d.roll();
        final p1 = d.promptWith(_p1.text, last);
        final p2 = d.templateFor(_p2.text,
            isVideo: t.isVideo, v: last);
        if (p1.isEmpty && p2.isEmpty) {
          _snack('Prompt bos olamaz');
          break;
        }
        await GenerateService.submit(
          task: t.id,
          prompt: p1,
          prompt2: p2,
          negative: _negative.text.trim(),
          width: t.width,
          height: t.height,
          duration: _duration,
          turbo: _turbo,
          mode: _mode,
          category: '',
          sourceJob: t.needsImage ? _source?.id : null,
        );
        n++;
      }
      if (!mounted) return;
      if (last != null) setState(() => d.apply(last!));   // son cekilis gorunsun
      _snack('$n is siraya eklendi');
      _pollQueue();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _modeSwitch() {
    if (_modes.length < 2) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: _modes.map((m) {
          final on = m.id == _mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => _setMode(m.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: on ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  m.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: on ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Girdi gorseli secimi - metin listesi degil, kucuk kareler.
  Widget _sourceStrip() {
    if (_sourceOptions.isEmpty) {
      return const Text(
        'Girdi olarak kullanilabilecek uretim yok. Once bir gorsel uret.',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _sourceOptions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final j = _sourceOptions[i];
          final on = _source?.id == j.id;
          return GestureDetector(
            onTap: () => setState(() => _source = j),
            child: Container(
              width: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: on ? AppColors.accent : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  j.thumbUrl(size: 200),
                  headers: GenerateService.authHeaders,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Container(color: Colors.white10),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
