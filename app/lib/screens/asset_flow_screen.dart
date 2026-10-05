import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/character_flow_service.dart';  // #329
import '../services/jigsaw_flow_service.dart';
import '../widgets/outfit_extract_dialog.dart';  // #329
import '../services/jigsaw_profiles.dart';
import '../services/mode_service.dart';
import '../widgets/network_video.dart';
import '../widgets/flow_kind_switch.dart' show kindSwitchBottom;
import '../theme.dart';

/// Asset Mod - Jigsaw yayin hatti (2-3-4. akis).
///
/// Masaustundeki Uretim Studyosu ile ayni akis; dosya islerinin tamami
/// sunucuda calisir, telefon yalnizca komut verir ve ilerlemeyi izler.
///
///   2 Etiketli      _Incoming - EXIF etiketli jpg (istege bagli mp4 ile).
///                   Video uretimi burada yapilir; her gorsele video sart degil.
///   3 Push bekleyen Koleksiyona `<n>.jpg` / `.mp4` / `.webp` girmis varliklar.
///   4 Push edilmis  R2'ye yuklenmis olanlar (salt gorunum).
///
/// 1. akis (uretim) "Uretilenler" ekranindadir; oradaki KABUL ET bu ekranin
/// 2. akisina dusurur.
class AssetFlowScreen extends StatefulWidget {
  const AssetFlowScreen({super.key, this.kindSwitch});

  /// Ust cubuktaki Jigsaw | CBN anahtari (FlowHub verir).
  final Widget? kindSwitch;

  @override
  State<AssetFlowScreen> createState() => _AssetFlowScreenState();
}

class _AssetFlowScreenState extends State<AssetFlowScreen>
    with SingleTickerProviderStateMixin {
  static const _stages = ['incoming', 'staging', 'pushed'];

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  List<String> get _titles =>
      [l10n.jigsawFlowTabTagged, l10n.jigsawFlowTabToPush, l10n.flowTabPushed];

  String _yesNo(bool v) => v ? l10n.flowYes : l10n.flowNo;

  late final TabController _tabs;
  String _rating = 'hot';
  String _collection = 'Generic';          // varsayilan koleksiyon; '' = hepsi

  final Map<String, List<FlowItem>> _items = {};
  final Map<String, int> _totals = {};
  Map<String, List<FlowCollection>> _colls = {};
  final Set<String> _sel = {};

  bool _loading = true;
  String? _error;
  FlowOp? _op;
  Timer? _opPoll;

  // --- 2. akis video uretimi
  VideoDefaults _vd = VideoDefaults.empty;
  final _vp1 = TextEditingController();
  final _vp2 = TextEditingController();
  final _vneg = TextEditingController();
  int _vSablon = 0;          // 0 = (sirayla dagit)
  int _vDuration = 5;

  String get _stage => _stages[_tabs.index];
  List<FlowItem> get _cur => _items[_stage] ?? const [];
  bool get _selecting => _sel.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!_tabs.indexIsChanging) {
          setState(() {
            _sel.clear();
            _collection = 'Generic';
          });
          _load();
        }
      });
    _load();
  }

  @override
  void dispose() {
    _opPoll?.cancel();
    _tabs.dispose();
    _vp1.dispose();
    _vp2.dispose();
    _vneg.dispose();
    super.dispose();
  }

  Future<void> _loadVideoDefaults() async {
    try {
      final v = await JigsawFlowService.videoTemplates(_rating);
      if (!mounted) return;
      setState(() {
        _vd = v;
        _vSablon = 0;
        _vp2.text = '';
        if (_vneg.text.trim().isEmpty) _vneg.text = v.negative;
      });
    } catch (_) {
      // sablonlar alinamazsa panel yine calisir - elle prompt girilebilir
    }
  }

  // ------------------------------------------------------------- yukleme
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_vd.templates.isEmpty) unawaited(_loadVideoDefaults());
      final c = await JigsawFlowService.collections(_rating);
      final r = await JigsawFlowService.list(
          rating: _rating, stage: _stage, collection: _collection, limit: 300);
      if (!mounted) return;
      setState(() {
        _colls = c;
        _items[_stage] = r.items;
        _totals[_stage] = r.total;
        _sel.removeWhere((id) => !r.items.any((i) => i.id == id));
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

  /// Sunucudaki arka plan islemini bitene kadar izler.
  void _watch(String opId) {
    _opPoll?.cancel();
    var hata = 0;
    _opPoll = Timer.periodic(const Duration(seconds: 2), (t) async {
      try {
        final o = await JigsawFlowService.op(opId);
        if (!mounted) return;
        hata = 0;
        setState(() => _op = o);
        if (!o.running) {
          t.cancel();
          _snack(o.status == 'error'
              ? l10n.flowOpError(o.message)
              : o.status == 'cancelled'
                  ? l10n.flowOpCancelled
                  : o.failed > 0
                      ? l10n.flowOpDoneWithFailed(o.ok, o.failed)
                      : l10n.flowOpDone(o.ok));
          _load();
        }
      } catch (_) {
        // #352: tek bir ag hatasi izlemeyi bitiriyor ve ilerleme cubugu
        // "calisiyor" halinde donmus kaliyordu - 3 ardisik hatada birak.
        if (++hata >= 3) {
          t.cancel();
          if (mounted) setState(() => _op = null);
        }
      }
    });
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<bool> _confirm(String baslik, String metin, {String? onay}) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          // Uzun onay metni (orn. Muzik) kucuk ekranda tasiyordu (gorev #289).
          scrollable: true,
          title: Text(baslik),
          content: Text(metin),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(onay ?? l10n.continueLabel)),
          ],
        ),
      ) ??
      false;

  // -------------------------------------------------------------- eylem
  /// Video uretim ayarlarini soran alt sayfa (Pozitif 1 / 2 / Negatif).
  ///
  /// Pozitif 2 bos birakilirsa ve "Que All" secildiyse hazir sablonlar
  /// siradaki varliga sirayla dagitilir - parti tek tip olmaz.
  Future<bool> _videoAyarSayfasi({required int adet, required bool queAll}) async {
    final onay = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      // Uygulama edgeToEdge modunda: alt sayfa sistem gezinme cubugunun
      // (3 tus ~48px) ARKASINA uzanir, `viewInsets` yalnizca klavyeyi verir.
      // `padding.bottom` eklenmezse Vazgec / QUE ALL cubugun altinda kalir
      // (gorev #288). Kod tabaninin kalibi: viewInsets + padding + N.
      builder: (c) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(c).viewInsets.bottom +
              MediaQuery.of(c).padding.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (c, setSheet) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(queAll ? l10n.jigsawFlowQueueAllTitle(adet) : l10n.jigsawFlowVideoTitle(adet),
                    style: Theme.of(c).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _vp1,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.jigsawFlowPositive1,
                    helperText: l10n.jigsawFlowPositive1Help,
                    helperMaxLines: 2,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _vSablon,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.jigsawFlowMotionPreset,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 0, child: Text(l10n.jigsawFlowSpreadInTurn)),
                    for (var i = 0; i < _vd.templates.length; i++)
                      DropdownMenuItem(
                          value: i + 1,
                          child: Text(_vd.templates[i].name,
                              overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setSheet(() {
                    _vSablon = v ?? 0;
                    _vp2.text = (_vSablon == 0)
                        ? ''
                        : _vd.templates[_vSablon - 1].prompt;
                  }),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _vp2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.jigsawFlowPositive2,
                    helperText: l10n.jigsawFlowPositive2Help('{}'),
                    helperMaxLines: 3,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _vneg,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.flowNegative,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(l10n.flowDuration),
                    Expanded(
                      child: Slider(
                        value: _vDuration.toDouble(),
                        min: 1, max: 10, divisions: 9,
                        label: l10n.durSeconds(_vDuration),
                        onChanged: (v) => setSheet(() => _vDuration = v.round()),
                      ),
                    ),
                    Text(l10n.durSeconds(_vDuration)),
                  ],
                ),
                if (queAll && _vp2.text.trim().isEmpty && _vd.templates.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                        l10n.jigsawFlowPresetsSpread(_vd.templates.length),
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                Row(
                  children: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: Text(l10n.cancel)),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(c, true),
                      icon: const Icon(Icons.movie_creation_outlined, size: 18),
                      label: Text(queAll ? l10n.jigsawFlowQueueAll : l10n.flowAddToQueue),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return onay == true;
  }

  Future<void> _gonderVideo(List<String> ids, {required bool queAll}) async {
    if (ids.isEmpty) {
      _snack(l10n.jigsawFlowNoAssetWithoutVideo);
      return;
    }
    if (!await _videoAyarSayfasi(adet: ids.length, queAll: queAll)) return;
    try {
      final r = await JigsawFlowService.makeVideos(
        rating: _rating,
        ids: ids,
        duration: _vDuration,
        prompt: _vp1.text.trim(),
        prompt2: _vp2.text.trim(),
        negative: _vneg.text.trim(),
        rotateTemplates: queAll,
      );
      _snack(r.skipped > 0
          ? l10n.jigsawFlowVideosQueuedSkipped(r.queued, r.skipped)
          : l10n.jigsawFlowVideosQueued(r.queued));
      setState(_sel.clear);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _makeVideos() async {
    final ids = _sel.where((id) {
      final i = _cur.where((x) => x.id == id).firstOrNull;
      return i != null && !i.video;
    }).toList();
    if (ids.isEmpty) {
      _snack(l10n.jigsawFlowSelectWithoutVideo);
      return;
    }
    await _gonderVideo(ids, queAll: false);
  }

  /// QUE ALL - 2. akistaki videosu olmayan TUM varliklara video acar.
  Future<void> _queueAll() async {
    final ids = _cur.where((i) => !i.video).map((i) => i.id).toList();
    await _gonderVideo(ids, queAll: true);
  }

  Future<void> _accept() async {
    if (_sel.isEmpty) return;
    final coll = await _pickCollection();
    if (coll == null) return;
    final videosuz = _sel.where((id) {
      final i = _cur.where((x) => x.id == id).firstOrNull;
      return i != null && !i.video;
    }).length;
    if (videosuz > 0 &&
        !await _confirm(l10n.jigsawFlowNoVideoTitle,
            l10n.jigsawFlowNoVideoBody(videosuz))) {
      return;
    }
    try {
      final op = await JigsawFlowService.accept(
          rating: _rating, ids: _sel.toList(), collection: coll);
      setState(_sel.clear);
      _watch(op);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Koleksiyon muzigi - sunucuda ACE-Step ile yerel uretim.
  ///
  /// Generic'in muzigi olmaz (kovada da yok). Muzigi olan koleksiyon atlanir.
  Future<void> _music() async {
    MusicStatus st;
    try {
      st = await JigsawFlowService.musicStatus(_rating);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    if (!st.modelReady) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l10n.jigsawFlowMusicNotReady),
          content: Text(st.modelError),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: Text(l10n.close)),
          ],
        ),
      );
      return;
    }
    final eksik = st.collections
        .where((c) => !c.hasMusic && c.stage == 'staging')
        .map((c) => c.name)
        .toList();
    final secili = _collection.isEmpty
        ? eksik
        : eksik.where((n) => n == _collection).toList();
    if (secili.isEmpty) {
      _snack(_collection.isEmpty
          ? l10n.jigsawFlowNoMusicMissing
          : l10n.jigsawFlowHasMusic(_collection));
      return;
    }
    if (!await _confirm(
        l10n.queueKindMusic,
        l10n.jigsawFlowMusicBody(secili.length,
            '${secili.take(6).join(", ")}${secili.length > 6 ? " ..." : ""}'),
        onay: l10n.generate)) {
      return;
    }
    try {
      final op = await JigsawFlowService.makeMusic(
          rating: _rating, collections: secili);
      _watch(op);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _push() async {
    if (_sel.isEmpty) return;
    if (!await _confirm(
        l10n.flowPush,
        l10n.jigsawFlowPushBody(_sel.length),
        onay: l10n.flowUpload)) {
      return;
    }
    try {
      final op = await JigsawFlowService.push(rating: _rating, ids: _sel.toList());
      setState(_sel.clear);
      _watch(op);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete() async {
    if (_sel.isEmpty) return;
    if (!await _confirm(l10n.delete,
        l10n.jigsawFlowDeleteBody(_sel.length),
        onay: l10n.delete)) {
      return;
    }
    try {
      final n = await JigsawFlowService.remove(
          rating: _rating, stage: _stage, ids: _sel.toList());
      setState(_sel.clear);
      _snack(l10n.flowFilesDeleted(n));
      _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _webp() async {
    try {
      final op = await JigsawFlowService.encodeWebp(
          rating: _rating, collection: _collection);
      _watch(op);
      _snack(l10n.jigsawFlowWebpStarted);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<String?> _pickCollection() async {
    // 10'a ulasmis tematik koleksiyon secenek olarak sunulmaz - o koleksiyon
    // tamamlanmistir. Generic sinirsiz.
    final hepsi = [
      ...(_colls['staging'] ?? const <FlowCollection>[]),
      ...(_colls['pushed'] ?? const <FlowCollection>[]),
    ];
    final gorulen = <String, FlowCollection>{};
    for (final c in hepsi) {
      final v = gorulen[c.name];
      if (v == null || c.total > v.total) gorulen[c.name] = c;
    }
    final liste = gorulen.values.where((c) => !c.full).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final dolu = gorulen.values.where((c) => c.full).length;
    final ctrl = TextEditingController(
        text: liste.any((c) => c.name == 'Generic') ? 'Generic' : '');
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        // Metin kutusu + 180px liste klavye acilinca sigmiyordu (gorev #289).
        scrollable: true,
        title: Text(l10n.jigsawFlowCollectionTitle('${JigsawProfiles.ratings[_rating]}')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: l10n.flowCollection,
                helperText: dolu == 0
                    ? l10n.jigsawFlowCollectionHelp
                    : l10n.jigsawFlowCollectionHelpFull(dolu),
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 180,
              width: double.maxFinite,
              child: ListView(
                children: liste
                    .map((k) => ListTile(
                          dense: true,
                          title: Text(k.name),
                          subtitle: Text(l10n.jigsawFlowCollectionRow(k.total, k.next)),
                          onTap: () => ctrl.text = k.name,
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(c, 'Generic'),
              child: const Text('Generic')),
          TextButton(
              onPressed: () => ctrl.clear(),
              child: Text(l10n.flowNew)),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text.trim()),
              child: Text(l10n.flowAccept)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- arayuz
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _selecting
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(_sel.clear))
            : null,
        title: Text(_selecting ? l10n.bucketsSelectedCount(_sel.length) : l10n.jigsawFlowTitle),
        actions: [
          if (!_selecting)
            IconButton(
              icon: const Icon(Icons.code),
              tooltip: l10n.assetCodeMode,
              onPressed: () => ModeService.set(false),
            ),
          IconButton(
              icon: const Icon(Icons.refresh), tooltip: l10n.refresh, onPressed: _load),
        ],
        // #353: hat anahtari app bar'in altinda tam genislikte (Uretilenler kalibi).
        bottom: kindSwitchBottom(
          widget.kindSwitch,
          tabs: TabBar(
            controller: _tabs,
            tabs: [for (final t in _titles) Tab(text: t)],
          ),
        ),
      ),
      body: Column(
        children: [
          _ratingBar(),
          if (_op != null && _op!.running) _opBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _errorView()
                    : _grid(),
          ),
        ],
      ),
      bottomNavigationBar: _selecting ? _actionBar() : null,
    );
  }

  Widget _ratingBar() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(
          children: [
            Expanded(
              child: SegmentedButton<String>(
                segments: JigsawProfiles.ratings.entries
                    .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
                    .toList(),
                selected: {_rating},
                showSelectedIcon: false,
                onSelectionChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _rating = v.first;
                    _sel.clear();
                    _collection = 'Generic';
                    _vd = VideoDefaults.empty;
                  });
                  _loadVideoDefaults();
                  _load();
                },
              ),
            ),
            if (_stage != 'incoming') ...[
              const SizedBox(width: 8),
              _collectionMenu(),
            ],
          ],
        ),
      );

  Widget _collectionMenu() {
    final liste = _colls[_stage == 'staging' ? 'staging' : 'pushed'] ?? const [];
    return PopupMenuButton<String>(
      tooltip: l10n.flowCollection,
      onSelected: (v) {
        setState(() {
          _collection = v;
          _sel.clear();
        });
        _load();
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: '', child: Text(l10n.flowAllParen)),
        for (final k in liste)
          PopupMenuItem(value: k.name, child: Text('${k.name}  (${k.count})')),
      ],
      child: Chip(
        avatar: const Icon(Icons.folder_outlined, size: 16),
        label: Text(_collection.isEmpty ? l10n.flowAll : _collection,
            overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _opBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _op!.message.isEmpty
                  ? '${_op!.kind}: ${_op!.done}/${_op!.total}'
                  : _op!.message,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: _op!.progress),
          ],
        ),
      );

  Widget _grid() {
    if (_cur.isEmpty) {
      return Center(
        child: Text(
          _stage == 'incoming'
              ? l10n.jigsawFlowEmptyIncoming
              : l10n.jigsawFlowEmpty,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text('${_cur.length} / ${_totals[_stage] ?? _cur.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ),
                // QUE ALL secime bagli degil: videosu olmayan HERKESE video
                // acar, o yuzden "Tumunu sec"in yanindaki tek dugme (gorev #275).
                if (_stage == 'incoming')
                  TextButton.icon(
                    onPressed: _queueAll,
                    icon: const Icon(Icons.playlist_play, size: 18),
                    label: Text(l10n.jigsawFlowQueueAll),
                  ),
                TextButton(
                  onPressed: () =>
                      setState(() => _sel.addAll(_cur.map((i) => i.id))),
                  child: Text(l10n.flowSelectAll),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 9 / 16,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _cur.length,
              itemBuilder: (_, i) => _tile(_cur[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(FlowItem it) {
    final on = _sel.contains(it.id);
    return GestureDetector(
      // Standart galeri davranisi (gorev #280): tek dokunus acar, basili tutma
      // secime alir; secim acikken tek dokunus digerlerini de secer/birakir.
      onTap: () => _selecting
          ? setState(() => on ? _sel.remove(it.id) : _sel.add(it.id))
          : _preview(it),
      onLongPress: () => setState(() => on ? _sel.remove(it.id) : _sel.add(it.id)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: on ? AppColors.accent : Colors.transparent, width: 3),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Sigdir, kirpma: havuz dikey/yatay/kare karisik, "cover" genis
              // gorselin yalnizca ortasini gosteriyordu (gorev #268).
              const ColoredBox(color: Colors.black),
              Image.network(
                JigsawFlowService.thumbUrl(_rating, _stage, it.id),
                headers: JigsawFlowService.authHeaders,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(color: Colors.white10),
              ),
              // Video, gorselin uzerinde oynat dugmesi olarak durur.
              if (it.video)
                Center(
                  child: GestureDetector(
                    onTap: () => _preview(it, video: true),
                    child: Container(
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.play_arrow,
                          size: 26, color: Colors.white),
                    ),
                  ),
                ),
              Positioned(
                left: 4,
                top: 4,
                child: Row(children: [
                  if (it.tagged == false) _rozet(l10n.flowBadgeNoTags, AppColors.error),
                  if (it.video && !it.webp) _rozet(l10n.jigsawFlowBadgeNoWebp, Colors.orange),
                ]),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8)
                      ],
                    ),
                  ),
                  child: Text(it.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, color: Colors.white)),
                ),
              ),
              if (_selecting)
                Positioned(
                  right: 4,
                  bottom: 20,
                  child: Icon(
                      on ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 20,
                      color: on ? AppColors.accent : Colors.white70),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rozet(String t, Color c) => Container(
        margin: const EdgeInsets.only(right: 3),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
        child: Text(t, style: const TextStyle(fontSize: 8, color: Colors.white)),
      );

  /// Onizleme. Oynat dugmesine basildiysa GERCEK videoyu oynatir - eskiden
  /// burada yalnizca kucuk resim gosteriliyordu, "video oynamiyor" hatasi
  /// (gorev #267) tam olarak buydu.
  void _preview(FlowItem it, {bool video = false}) {
    final oynat = video && it.video;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: oynat ? Colors.black : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: oynat
                  ? NetworkVideo(
                      url: JigsawFlowService.fileUrl(_rating, _stage, it.id,
                          kind: 'video'),
                      headers: JigsawFlowService.authHeaders,
                    )
                  : Image.network(
                      JigsawFlowService.thumbUrl(_rating, _stage, it.id,
                          size: 900),
                      headers: JigsawFlowService.authHeaders,
                      errorBuilder: (_, _, _) => const SizedBox(height: 120),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                '${l10n.jigsawFlowPreviewInfo(it.label, _yesNo(it.video), _yesNo(it.webp))}'
                '${it.tagged == null ? "" : "   ${l10n.jigsawFlowPreviewTags(it.tagged! ? l10n.flowYes : l10n.flowMissingUpper)}"}',
                style: TextStyle(
                    fontSize: 12, color: oynat ? Colors.white70 : null),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Secili varliklardan videosu olanlar.
  List<String> get _selWithVideo => _sel.where((id) {
        final i = _cur.where((x) => x.id == id).firstOrNull;
        return i != null && i.video;
      }).toList();

  /// Yalniz videoyu siler (jpg + json kalir) - yeniden video uretilebilsin.
  Future<void> _deleteVideo() async {
    final ids = _selWithVideo;
    if (ids.isEmpty) {
      _snack(l10n.jigsawFlowNoVideoInSelection);
      return;
    }
    final ok = await _confirm(l10n.jigsawFlowDeleteVideo,
        l10n.jigsawFlowDeleteVideoBody(ids.length),
        onay: l10n.jigsawFlowDeleteVideo);
    if (!ok) return;
    try {
      final n = await JigsawFlowService.removeVideo(
          rating: _rating, stage: _stage, ids: ids);
      setState(_sel.clear);
      _snack(l10n.flowFilesDeleted(n));
      _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Yeniden etiketle: secili varliklara EXIF etiketini tekrar yazdirir
  /// (etiketleme basarisiz olduysa ya da etiket yenilenecekse).
  Future<void> _retag() async {
    final ids = _sel.toList();
    try {
      final op = await JigsawFlowService.retag(ids: ids, rating: _rating);
      setState(_sel.clear);
      _watch(op);
      _snack(l10n.flowRetagStarted);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// #329: secili TEK ogedeki kiyafeti gardirop kutuphanesine cikarir
  /// (incoming/staging/pushed - kaynak rating/stage/id ile sunucuda cozulur).
  /// Op kaydi Jigsaw akisiyla ayni defterdedir, _watch ile izlenir.
  Future<void> _extractOutfit() async {
    if (_sel.length != 1) {
      _snack(l10n.jigsawFlowExtractNeedsOne);
      return;
    }
    final id = _sel.first;
    final secim = await showOutfitExtractDialog(context);
    if (secim == null || !mounted) return;
    try {
      final op = await CharacterFlowService.outfitExtract(
          name: secim.name,
          category: secim.category,
          kind: secim.kind,
          rating: _rating,
          stage: _stage,
          itemId: id,
          note: secim.note);
      setState(_sel.clear);
      if (op.isNotEmpty) _watch(op);
      _snack(l10n.outfitExtractStarted(secim.name));
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Etiket: secili varligin EXIF etiketleri + prompt yan dosyasi.
  Future<void> _showMeta() async {
    final id = _sel.first;
    Map<String, dynamic> m;
    try {
      m = await JigsawFlowService.meta(_rating, _stage, id);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    if (!mounted) return;
    String kv(Map<String, dynamic> d) =>
        d.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    final sc = (m['sidecar'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rows = <(String, String)>[
      (l10n.jigsawFlowMetaFile, '${m['file']}'),
      (l10n.jigsawFlowMetaTags, '${m['tags'] ?? ''}'),
      if ((m['description'] ?? '').toString().isNotEmpty) (l10n.commonDescription, '${m['description']}'),
      if ((m['subject'] as Map?)?.isNotEmpty ?? false) (l10n.jigsawFlowMetaSubject, kv((m['subject'] as Map).cast<String, dynamic>())),
      if ((m['policy'] as Map?)?.isNotEmpty ?? false) (l10n.jigsawFlowMetaPolicy, kv((m['policy'] as Map).cast<String, dynamic>())),
      if (sc['prompt'] != null) ('Prompt', '${sc['prompt']}'),
      if ((sc['prompt2'] ?? '').toString().isNotEmpty) (l10n.flowPositive2, '${sc['prompt2']}'),
      if ((sc['negative'] ?? '').toString().isNotEmpty) (l10n.flowNegative, '${sc['negative']}'),
      if (sc['seed'] != null) ('Seed', '${sc['seed']}'),
      ('Video', l10n.jigsawFlowMetaVideoValue(_yesNo(m['video'] == true), _yesNo(m['webp'] == true))),
    ];
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(id, style: const TextStyle(fontSize: 14)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in rows) ...[
                Text(r.$1,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                SelectableText(r.$2.isEmpty ? '-' : r.$2,
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l10n.close)),
        ],
      ),
    );
  }

  /// Alt cubuk: yalniz ikon + tooltip - yazili hali telefona sigmiyordu
  /// (gorev #276). QUE ALL secime bagli olmadigi icin ust satira tasindi.
  Widget _actionBar() {
    final butonlar = <Widget>[];
    if (_stage == 'incoming') {
      butonlar.addAll([
        _act(Icons.movie_creation_outlined, l10n.assetGenerateVideo, _makeVideos),
        _act(Icons.sell_outlined, l10n.jigsawFlowTagsMetadata, _showMeta),
        _act(Icons.new_label_outlined, l10n.flowRetag, _retag),
        _act(Icons.check_circle_outline, l10n.flowAccept, _accept),
        _act(Icons.checkroom_outlined, l10n.outfitExtractTitle,
            _sel.length == 1 ? _extractOutfit : null),  // #329
        _act(Icons.videocam_off_outlined, l10n.jigsawFlowDeleteVideoTooltip,
            _selWithVideo.isEmpty ? null : _deleteVideo),
        _act(Icons.delete_outline, l10n.flowReject, _delete),
      ]);
    } else if (_stage == 'staging') {
      butonlar.addAll([
        _act(Icons.animation, l10n.jigsawFlowMissingWebp, _webp),
        _act(Icons.music_note, l10n.queueKindMusic, _music),
        _act(Icons.sell_outlined, l10n.jigsawFlowTagsMetadata, _showMeta),
        _act(Icons.videocam_off_outlined, l10n.jigsawFlowDeleteVideoTooltip,
            _selWithVideo.isEmpty ? null : _deleteVideo),
        _act(Icons.cloud_upload_outlined, l10n.flowPush, _push),
        _act(Icons.checkroom_outlined, l10n.outfitExtractTitle,
            _sel.length == 1 ? _extractOutfit : null),  // #329
        _act(Icons.delete_outline, l10n.delete, _delete),
      ]);
    } else {
      butonlar.addAll([
        _act(Icons.sell_outlined, l10n.jigsawFlowTagsMetadata, _showMeta),
        _act(Icons.checkroom_outlined, l10n.outfitExtractTitle,
            _sel.length == 1 ? _extractOutfit : null),  // #329
      ]);
    }
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: butonlar,
      ),
    );
  }

  Widget _act(IconData ikon, String tooltip, VoidCallback? fn) => IconButton(
        onPressed: fn,
        tooltip: tooltip,
        icon: Icon(ikon, size: 24),
      );

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 44, color: AppColors.error),
              const SizedBox(height: 10),
              Text(l10n.flowReadFailed),
              const SizedBox(height: 6),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 14),
              FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retry)),
            ],
          ),
        ),
      );
}
