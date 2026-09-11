import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/generate_service.dart';
import '../services/jigsaw_profiles.dart';
import '../theme.dart';
import '../services/mode_service.dart';
import '../widgets/flow_kind_switch.dart';   // #353

/// Asset Mod - Uretim ekrani.
///
/// Ust kisimda kip secimi vardir (Free / Jigsaw / CBN / Karakter) ve arayuz
/// kipe gore degisir. Emirler sunucudaki tek sirali kuyruga girer; bu ekran isi acar,
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
  // #337: yerel prompt yazari durumu
  bool _smithReady = false;
  bool _smithBusy = false;
  String _smithModel = '';
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
  String _aspect = '2:3';                 // CBN: oran secici (bes oran, gorev #285)
  // Yedek tablo; sunucu aspect_sizes gonderiyorsa o kullanilir (_aspectSize).
  static const _aspectSizes = {
    '9:16': (720, 1280),
    '2:3': (832, 1248),
    '1:1': (1024, 1024),
    '3:2': (1248, 832),
    '16:9': (1280, 720),
  };
  (int, int) get _aspectSize =>
      _modeDef.aspectSizes[_aspect] ?? _aspectSizes[_aspect] ?? _aspectSizes['2:3']!;
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

  /// Is akisinin girdi yuvalari -> secilen girdi (gorev #287). Free kipinde
  /// her yuva icin ayri bir secici cikar: FLF2V ilk+son kare, V2V referans
  /// gorsel + surucu video, S2V gorsel + ses.
  final Map<String, GenerateInputRef> _inputs = {};
  String? _uploading;                    // o an yuklenen yuvanin adi
  int _queueDepth = 0;
  Timer? _poll;

  /// Kip bir profil dosyasi tasiyor mu (jigsaw, cbn, character: evet;
  /// free: hayir).
  bool get _hasProfiles => _modeDef.hasProfiles;

  /// Kipin derece listesi. Karakter ve Kart kiplerinde derece yoktur - tek
  /// profil vardir, o yuzden derece anahtari da gosterilmez.
  Map<String, String> get _ratingsMap => switch (_modeDef.profiles) {
        'cbn' => CbnProfiles.ratings,
        'character' => CharacterProfiles.ratings,
        'card' => CardProfiles.ratings,          // #323
        _ => JigsawProfiles.ratings,
      };

  /// Secenek dosyasi okunamadiysa ekranda gosterilecek hata - kipe gore.
  String? get _profileError => switch (_modeDef.profiles) {
        'cbn' => CbnProfiles.loadError,
        'character' => CharacterProfiles.loadError,
        'card' => CardProfiles.loadError,        // #323
        _ => JigsawProfiles.loadError,
      };

  GenerateMode get _modeDef => _modes.firstWhere((m) => m.id == _mode,
      orElse: () => const GenerateMode(
          id: 'free', label: 'Free Mod', prompt2: '', motion2: '',
          negative: '', exports: false));

  @override
  void initState() {
    super.initState();
    _loadAll();
    _loadSmith();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _pollQueue());
  }

  /// #337: yerel prompt yazari var mi - yoksa serit hic cizilmez.
  Future<void> _loadSmith() async {
    final d = await GenerateService.smithStatus();
    if (!mounted) return;
    setState(() {
      _smithReady = d['ready'] == true;
      _smithModel = '${d['model'] ?? ''}';
    });
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
      // Secenek dosyasi kipe gore: jigsaw / cbn / karakter / kart_secenekler.
      // #323: sunucu yeni "card" kipini `profiles: "card"` ile gonderir;
      // gondermezse asagidaki `_profilesKeyFor` kip kimliginden turetir.
      final pk = r.modes.isNotEmpty
          ? r.modes
              .firstWhere((m) => m.id == _mode, orElse: () => r.modes.first)
              .profiles
          : _modeDef.profiles;
      final profs = switch (pk) {
        'cbn' => await CbnProfiles.load(),
        'character' => await CharacterProfiles.load(),
        'card' => await CardProfiles.load(),     // #323
        _ => await JigsawProfiles.load(),
      };
      List<GenerateJob> srcs = [];
      try {
        final jobs = await GenerateService.list(limit: 60);
        srcs = jobs.where((j) => j.isDone && j.isImage).toList();
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
        _pruneInputs();          // yeni gorevde olmayan yuva secimleri dussun
        _profiles = profs;
        // Kipler farkli anahtarlar kullanir (hot/kid vs character); eldeki
        // derece yeni kipte yoksa ilkine duseriz.
        if (!profs.containsKey(_rating) && profs.isNotEmpty) {
          _rating = profs.keys.first;
        }
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
    // #353: gorevin kendi sablonu (anime) kip sablonundan once gelir...
    final t = _task;
    if (t != null && !isVideo && t.prompt2.isNotEmpty) p2 = t.prompt2;
    if (t != null && t.negative.isNotEmpty) neg = t.negative;
    if (_hasProfiles) {
      final p = _profiles[_rating];
      if (p != null) {
        // ...ama derecenin KENDI sablonu (kid: aile dostu) her ikisini de ezer.
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
    setState(() {
      _mode = id;
      _details.clear();      // hot/kid anahtarlari kipler arasinda ortak, durum degil
    });
    HapticFeedback.selectionClick();
    _loadAll();
  }

  /// Konu prompt'u + secili detaylar (jigsaw disinda sadece konu).
  String _prompt1([Map<String, String>? v]) {
    if (!_hasProfiles || _det == null) return _p1.text.trim();
    return _det!.promptWith(_p1.text, v);
  }

  /// Sablon; dropdown'un kapsadigi parcalar dusulmus halde.
  /// #337: yerel LLM prompt yazari seridi - Zenginlestir / Duzelt / Varyant.
  /// LLM kapaliysa serit hic gosterilmez, uretim akisi degismez.
  Widget _smithBar() {
    if (!_smithReady) return const SizedBox.shrink();
    final bos = _p1.text.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(_smithModel, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          TextButton.icon(
            onPressed: bos || _smithBusy ? null : () => _smithRun('enrich'),
            icon: const Icon(Icons.auto_awesome, size: 15),
            label: const Text('Zenginlestir'),
          ),
          TextButton.icon(
            onPressed: bos || _smithBusy ? null : () => _smithRun('normalize'),
            icon: const Icon(Icons.auto_fix_high, size: 15),
            label: const Text('Duzelt'),
          ),
          TextButton.icon(
            onPressed: bos || _smithBusy ? null : _smithVariants,
            icon: const Icon(Icons.call_split, size: 15),
            label: const Text('Varyant'),
          ),
          if (_smithBusy)
            const SizedBox(
                width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }

  Future<void> _smithRun(String op) async {
    setState(() => _smithBusy = true);
    final onceki = _p1.text;
    final y = await GenerateService.smith(op, onceki, mode: _mode);
    if (!mounted) return;
    setState(() {
      _smithBusy = false;
      _p1.text = y;
    });
    if (y.trim() == onceki.trim()) {
      _snack('Prompt degismedi (yerel LLM yanit vermedi)');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Prompt yazildi'),
        action: SnackBarAction(
            label: 'Geri al', onPressed: () => setState(() => _p1.text = onceki)),
      ));
    }
  }

  Future<void> _smithVariants() async {
    setState(() => _smithBusy = true);
    final v = await GenerateService.smithVariants(_p1.text, n: 3, mode: _mode);
    if (!mounted) return;
    setState(() => _smithBusy = false);
    if (v.isEmpty) {
      _snack('Varyant uretilemedi (yerel LLM yanit vermedi)');
      return;
    }
    final sec = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        scrollable: true,
        title: const Text('Varyant sec'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final x in v)
              ListTile(
                dense: true,
                title: Text(x, style: const TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(c, x),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgec')),
        ],
      ),
    );
    if (sec != null && sec.isNotEmpty) setState(() => _p1.text = sec);
  }

  String _prompt2([Map<String, String>? v]) {
    if (!_hasProfiles || _det == null) return _p2.text.trim();
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

  // ------------------------------------------------------------- girdiler
  /// Yuva secicileri mi gosterilecek: Free kipinde her is akisi icin, diger
  /// kiplerde yalniz tek gorselden fazlasini isteyen is akislari icin.
  /// (Eski sunucu "inputs" gondermezse liste bostur, eski akis calisir.)
  bool get _useSlots {
    final t = _task;
    if (t == null || t.inputs.isEmpty) return false;
    return _mode == 'free' || t.hasExtraInputs;
  }

  List<GenerateInputSlot> get _slots => _task?.inputs ?? const [];

  /// Gorev/kip degisince baska bir is akisina ait secimler kalmasin.
  void _pruneInputs() {
    final adlar = {for (final s in _slots) s.slot};
    _inputs.removeWhere((k, _) => !adlar.contains(k));
  }

  List<GenerateInputSlot> get _missingSlots =>
      _slots.where((s) => s.required && !_inputs.containsKey(s.slot)).toList();

  /// Yuvaya Uretilenler galerisinden bir is ciktisi secer.
  Future<void> _pickFromGallery(GenerateInputSlot s) async {
    final job = await showModalBottomSheet<GenerateJob>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _GalleryPickerSheet(slot: s),
    );
    if (job == null || !mounted) return;
    setState(() => _inputs[s.slot] = GenerateInputRef.job(job));
  }

  /// Yuvaya cihazdan bir dosya secer - dosya sunucuya yuklenir.
  Future<void> _pickFromFile(GenerateInputSlot s) async {
    final r = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _extsFor(s.kind),
      allowMultiple: false,
      withData: false,
    );
    final picked = r?.files.isNotEmpty == true ? r!.files.first : null;
    if (picked == null || !mounted) return;
    setState(() => _uploading = s.slot);
    try {
      final bytes = picked.bytes ??
          (picked.path != null ? await File(picked.path!).readAsBytes() : null);
      if (bytes == null) throw Exception('Dosya okunamadi');
      final ref = await GenerateService.upload(picked.name, bytes);
      if (!mounted) return;
      setState(() => _inputs[s.slot] = ref);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  static List<String> _extsFor(String kind) => switch (kind) {
        'video' => const ['mp4', 'webm', 'mov', 'mkv'],
        'audio' => const ['mp3', 'wav', 'flac', 'ogg', 'm4a'],
        _ => const ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
      };

  // -------------------------------------------------------------- uretim
  Future<void> _generate() async {
    final t = _task;
    if (t == null) return;
    if (_prompt1().isEmpty && _prompt2().isEmpty) {
      _snack('Prompt bos olamaz');
      return;
    }
    if (_useSlots) {
      final eksik = _missingSlots;
      if (eksik.isNotEmpty) {
        _snack('Eksik girdi: ${eksik.map((s) => s.label).join(', ')}');
        return;
      }
    } else if (t.needsImage && _source == null) {
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
          width: _modeDef.aspects ? _aspectSize.$1 : t.width,
          height: _modeDef.aspects ? _aspectSize.$2 : t.height,
          duration: _duration,
          turbo: _turbo,
          mode: _mode,
          category: '',
          inputs: _useSlots ? _inputs : const {},
          sourceJob: (!_useSlots && t.needsImage) ? _source?.id : null,
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
        // #355: kip anahtari Uretilenler/Hat ile AYNI yerde (app bar alti).
        bottom: kindSwitchBottom(_modeSwitch()),
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
            icon: const Icon(Icons.local_shipping_outlined),
            tooltip: 'Delivery Mod',
            onPressed: () => ModeService.setMode(ModeService.delivery),   // #363
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
    final jigsaw = _hasProfiles;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
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
              _pruneInputs();       // baska is akisinin yuvalari kalmasin
            });
            _applyModeDefaults();
          },
        ),
        if (jigsaw) ...[
          if (_ratingsMap.length > 1) ...[
            const SizedBox(height: 12),
            _ratingSwitch(),
          ],
          if (_modeDef.aspects) ...[
            const SizedBox(height: 10),
            _aspectRow(),
          ],
        ],
        if (t != null && _useSlots) ...[
          const SizedBox(height: 16),
          const Text('Is akisinin girdileri',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 6),
          for (final s in _slots) _slotRow(s),
        ] else if (t != null && t.needsImage) ...[
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
        _smithBar(),
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
        // #352: oran secici acikken GERCEK gonderilen olcu yazilir - eskiden
        // 16:9 secilse bile gorevin varsayilani (896x1600) gorunuyordu.
        if (t != null && (_modeDef.aspects || t.width > 0))
          Text(
              _modeDef.aspects
                  ? 'Olcu: ${_aspectSize.$1} x ${_aspectSize.$2}  ($_aspect)'
                  : 'Olcu: ${t.width} x ${t.height}',
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

  /// CBN: bes oran (9:16, 2:3, 1:1, 3:2, 16:9) - boyutlar sunucunun
  /// tablosundan gelir; hepsi tam oran, cizgi sayfasi esnemez.
  Widget _aspectRow() => SegmentedButton<String>(
        segments: [
          for (final id in (_modeDef.aspectSizes.isNotEmpty ? _modeDef.aspectSizes.keys : _aspectSizes.keys))
            ButtonSegment(value: id, label: Text(id)),
        ],
        selected: {_aspect},
        showSelectedIcon: false,
        onSelectionChanged: (v) {
          HapticFeedback.selectionClick();
          setState(() => _aspect = v.first);
        },
      );

  /// Derece secimi - Hot/Kid (Jigsaw ya da CBN). Gorevin hemen altinda durur.
  Widget _ratingSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: _ratingsMap.entries.map((e) {
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
    if (_profileError != null && !d.hasAnyOption) {
      return Card(
        color: AppColors.error.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(_profileError!,
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
                    // #353: tutarli karistirma sunucuda (kilitler korunur).
                    onPressed: () async {
                      final r = await d.rollServer();
                      if (!mounted) return;
                      setState(() => d.apply(r.first));
                    },
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
      _snack(_profileError ?? 'Secenek listesi bos');
      return;
    }
    if (_useSlots && _missingSlots.isNotEmpty) {
      _snack('Eksik girdi: ${_missingSlots.map((s) => s.label).join(', ')}');
      return;
    }
    if (!_useSlots && t.needsImage && _source == null) {
      _snack('Bu gorev bir girdi gorseli istiyor');
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _sending = true);
    var n = 0;
    Map<String, String>? last;
    try {
      // #353: N tutarli secim tek istekle sunucudan (eski sunucuda yerel).
      final cekilisler = await d.rollServer(n: _randomCount);
      for (var i = 0; i < cekilisler.length; i++) {
        last = cekilisler[i];
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
          width: _modeDef.aspects ? _aspectSize.$1 : t.width,
          height: _modeDef.aspects ? _aspectSize.$2 : t.height,
          duration: _duration,
          turbo: _turbo,
          mode: _mode,
          category: '',
          inputs: _useSlots ? _inputs : const {},
          sourceJob: (!_useSlots && t.needsImage) ? _source?.id : null,
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

  /// #353: kip anahtari Uretilenler'dekiyle AYNI widget (FlowKindSwitch) -
  /// kisa etiketler (Free / Jigsaw / CBN / Kart / Karakter), tam genislik.
  Widget? _modeSwitch() {
    if (_modes.length < 2) return null;
    return FlowKindSwitch(
      items: {for (final m in _modes) m.id: kindLabel(m.id, m.label)},
      selected: _mode,
      onChanged: _setMode,
    );
  }

  /// Tek bir girdi yuvasi: onizleme + Galeriden sec / Dosyadan sec / temizle.
  Widget _slotRow(GenerateInputSlot s) {
    final ref = _inputs[s.slot];
    final busy = _uploading == s.slot;
    final ipucu = s.title.isEmpty ? s.defaultFile : s.title;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _slotThumb(s, ref),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(s.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          if (!s.required)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Text('istege bagli',
                                  style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ),
                        ],
                      ),
                      if (ipucu.isNotEmpty)
                        Text(ipucu,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        busy
                            ? 'yukleniyor...'
                            : ref == null
                                ? 'secilmedi'
                                : ref.display,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: ref == null && !busy
                                ? AppColors.error
                                : Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (ref != null)
                  IconButton(
                    tooltip: 'temizle',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _inputs.remove(s.slot)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _pickFromGallery(s),
                    icon: const Icon(Icons.photo_library, size: 16),
                    label: const Text('Galeriden sec',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _pickFromFile(s),
                    icon: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.folder_open, size: 16),
                    label: const Text('Dosyadan sec',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Yuvanin onizlemesi: is ciktisi ise kucuk resim, dosya ise tur simgesi.
  Widget _slotThumb(GenerateInputSlot s, GenerateInputRef? ref) {
    final ikon = switch (s.kind) {
      'video' => Icons.movie_outlined,
      'audio' => Icons.music_note,
      _ => Icons.image_outlined,
    };
    Widget child;
    if (ref?.job != null && !s.isAudio) {
      child = Image.network(
        ref!.job!.thumbUrl(size: 200),
        headers: GenerateService.authHeaders,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(ikon, color: Colors.grey),
      );
    } else {
      child = Icon(ikon, color: ref == null ? Colors.grey : AppColors.accent);
    }
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: ref == null ? Colors.transparent : AppColors.accent,
            width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(child: child),
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
                  fit: BoxFit.contain,
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


/// Uretilenler galerisinden bir is ciktisi secme sayfasi (gorev #287).
///
/// Yalniz yuvanin turune uyan bitmis isler listelenir: gorsel yuvasina gorsel,
/// video yuvasina video, ses yuvasina ses. Ustteki alan prompt metninde arar.
class _GalleryPickerSheet extends StatefulWidget {
  const _GalleryPickerSheet({required this.slot});

  final GenerateInputSlot slot;

  @override
  State<_GalleryPickerSheet> createState() => _GalleryPickerSheetState();
}

class _GalleryPickerSheetState extends State<_GalleryPickerSheet> {
  static const _audioExt = ['.mp3', '.wav', '.flac', '.ogg', '.m4a', '.opus'];

  final _search = TextEditingController();
  List<GenerateJob> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jobs = await GenerateService.list(limit: 200);
      if (!mounted) return;
      setState(() {
        _all = jobs.where(_matchesKind).toList();
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

  /// Isin ciktisi yuvanin turune uyuyor mu (uzantiya bakar).
  bool _matchesKind(GenerateJob j) {
    if (!j.isDone || j.fileName == null) return false;
    final ad = j.fileName!.toLowerCase();
    final ses = _audioExt.any(ad.endsWith);
    return switch (widget.slot.kind) {
      'video' => j.isVideo && !ses,
      'audio' => ses,
      _ => j.isImage && !ses,
    };
  }

  List<GenerateJob> get _shown {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all
        .where((j) =>
            j.prompt.toLowerCase().contains(q) ||
            j.combined.toLowerCase().contains(q) ||
            j.task.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _shown;
    final mq = MediaQuery.of(context);
    // Sabit 0.72 yukseklik klavye acilinca ekrani asiyordu (gorev #289):
    // guvenli alan + klavye dusuldukten sonra kalanla sinirla.
    final tavan = mq.size.height * 0.72;
    final kalan = mq.size.height - mq.viewInsets.bottom - mq.padding.vertical - 24;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            left: 14,
            right: 14,
            top: 12,
            bottom: mq.viewInsets.bottom + 12),
        child: SizedBox(
          height: kalan > 0 && kalan < tavan ? kalan : tavan,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${widget.slot.label} - Uretilenlerden sec',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loading ? null : _load,
                  ),
                ],
              ),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: 'promptta ara',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Text(_error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.error)))
                        : list.isEmpty
                            ? const Center(
                                child: Text(
                                    'Bu ture uygun bitmis uretim yok.',
                                    style: TextStyle(color: Colors.grey)))
                            : widget.slot.isAudio
                                ? _audioList(list)
                                : _thumbGrid(list),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbGrid(List<GenerateJob> list) => GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.72,
        ),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final j = list[i];
          return InkWell(
            onTap: () => Navigator.pop(context, j),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          j.thumbUrl(size: 300),
                          headers: GenerateService.authHeaders,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Container(color: Colors.white10),
                        ),
                        if (j.isVideo)
                          const Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.play_circle_fill,
                                  size: 18, color: Colors.white70),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(j.prompt.isEmpty ? j.id : j.prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          );
        },
      );

  Widget _audioList(List<GenerateJob> list) => ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final j = list[i];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.music_note),
            title: Text(j.prompt.isEmpty ? j.id : j.prompt,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(j.fileName ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11)),
            onTap: () => Navigator.pop(context, j),
          );
        },
      );
}
