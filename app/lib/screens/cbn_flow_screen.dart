import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/cbn_flow_service.dart';
import '../services/jigsaw_flow_service.dart' show FlowCollection, FlowOp;
import '../services/mode_service.dart';
import '../widgets/bottom_inset.dart';
import '../widgets/network_video.dart';
import '../widgets/flow_kind_switch.dart' show kindSwitchBottom;
import '../theme.dart';

/// Asset Mod - CBN (Color-By-Number) yayin hatti (2-3-4. akis).
///
///   2 Gelen        Uretilenler'den KABUL ET ile dusen, EXIF etiketli kaynaklar.
///                  Buradan "Insa et": Opus nesne listesi + SAM3 bolgeler
///                  (+ hot'ta Qwen cizgi sayfasi ve reveal videosu).
///   3 Hazir        Koleksiyona <n>/ olarak insa edilmis varliklar - incele, push.
///   4 Push edilmis R2'ye yuklenmis olanlar (salt gorunum).
class CbnFlowScreen extends StatefulWidget {
  const CbnFlowScreen({super.key, this.kindSwitch});

  /// Ust cubuktaki Jigsaw | CBN anahtari (FlowHub verir).
  final Widget? kindSwitch;

  @override
  State<CbnFlowScreen> createState() => _CbnFlowScreenState();
}

class _CbnFlowScreenState extends State<CbnFlowScreen>
    with SingleTickerProviderStateMixin {
  static const _stages = ['incoming', 'staging', 'pushed'];

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  List<String> get _titles =>
      [l10n.cbnFlowTabIncoming, l10n.cbnFlowTabReady, l10n.flowTabPushed];

  late final TabController _tabs;
  String _rating = 'hot';
  String _collection = '';

  final Map<String, List<CbnItem>> _items = {};
  final Map<String, int> _totals = {};
  Map<String, List<FlowCollection>> _colls = {};
  final Set<String> _sel = {};

  bool _loading = true;
  String? _error;
  FlowOp? _op;
  Timer? _opPoll;

  String get _stage => _stages[_tabs.index];
  List<CbnItem> get _cur => _items[_stage] ?? const [];
  bool get _selecting => _sel.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!_tabs.indexIsChanging) {
          setState(() {
            _sel.clear();
            _collection = '';
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
    super.dispose();
  }

  // ------------------------------------------------------------- yukleme
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await CbnFlowService.collections(_rating);
      final r = await CbnFlowService.list(
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

  /// Sunucudaki arka plan islemini bitene kadar izler; insa uzun surdugu
  /// icin liste her turda tazelenir (biten varlik hemen 3. akista gorunur).
  void _watch(String opId) {
    _opPoll?.cancel();
    var tick = 0;
    var hata = 0;
    _opPoll = Timer.periodic(const Duration(seconds: 2), (t) async {
      try {
        final o = await CbnFlowService.op(opId);
        if (!mounted) return;
        hata = 0;
        setState(() => _op = o);
        tick++;
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
        } else if (o.kind.startsWith('cbn-') && tick % 10 == 0) {
          _load();
        }
      } catch (_) {
        // #352: gecici ag hatasi cubugu donmus birakmasin - 3 ardisik hatada birak.
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

  Future<bool> _confirm(String baslik, String metin, {required String onay}) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          // Uzun onay metni kucuk ekranda tasiyordu (gorev #289).
          scrollable: true,
          title: Text(baslik),
          content: Text(metin),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(onay)),
          ],
        ),
      ) ??
      false;

  // -------------------------------------------------------------- eylem
  Future<void> _build() async {
    final ids = _sel.toList();
    final mevcut = (_colls['staging'] ?? const [])
        .map((c) => c.name)
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final ctl = TextEditingController(text: 'Generic');
    final coll = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        // Uzun aciklama + koleksiyon kutusu + chip listesi klavyeyle tasiyordu
        // (gorev #289).
        scrollable: true,
        title: Text(l10n.cbnFlowBuildTitle(ids.length)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _rating == 'hot'
                  ? l10n.cbnFlowBuildBodyHot
                  : l10n.cbnFlowBuildBodyKid,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              decoration: InputDecoration(
                labelText: l10n.flowCollection,
                border: const OutlineInputBorder(),
              ),
            ),
            if (mevcut.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final m in mevcut)
                    ActionChip(label: Text(m), onPressed: () => ctl.text = m),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctl.text.trim()),
              child: Text(l10n.cbnFlowBuild)),
        ],
      ),
    );
    if (coll == null || coll.isEmpty) return;
    try {
      final op = await CbnFlowService.build(rating: _rating, ids: ids, collection: coll);
      setState(_sel.clear);
      _watch(op);
      _snack(l10n.cbnFlowBuildStarted);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Asamali hat (gorev #281): her asama secili varliklarin HEPSINDE
  /// arka arkaya kosar - model bir kez yuklenir. Sira: nesneler -> SAM ->
  /// (hot) cizgi -> insa.
  Future<void> _runStage(String ad, Future<String> Function(List<String>) f) async {
    final ids = _sel.toList();
    try {
      final op = await f(ids);
      setState(_sel.clear);
      _watch(op);
      _snack(l10n.cbnFlowStageStarted(ad, ids.length));
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Yeniden etiketle: etiketi dusmemis Gelen varliklari icin.
  Future<void> _retag() async {
    final ids = _sel.toList();
    try {
      final op = await CbnFlowService.retag(ids: ids, rating: _rating);
      setState(_sel.clear);
      _watch(op);
      _snack(l10n.flowRetagStarted);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _push() async {
    final ids = _sel.toList();
    final ok = await _confirm(
        l10n.cbnFlowPushTitle(ids.length),
        l10n.cbnFlowPushBody,
        onay: l10n.flowPush);
    if (!ok) return;
    try {
      final op = await CbnFlowService.push(rating: _rating, ids: ids);
      setState(_sel.clear);
      _watch(op);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete() async {
    final ids = _sel.toList();
    final ok = await _confirm(l10n.delete, l10n.cbnFlowDeleteBody(ids.length), onay: l10n.delete);
    if (!ok) return;
    try {
      final n = await CbnFlowService.remove(rating: _rating, stage: _stage, ids: ids);
      setState(_sel.clear);
      _snack(l10n.cbnFlowDeleted(n));
      _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ------------------------------------------------------------- gorunum
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _selecting
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(_sel.clear))
            : null,
        title: Text(_selecting ? l10n.bucketsSelectedCount(_sel.length) : l10n.cbnFlowTitle),
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
                segments: CbnFlowService.ratings.entries
                    .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
                    .toList(),
                selected: {_rating},
                showSelectedIcon: false,
                onSelectionChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _rating = v.first;
                    _sel.clear();
                    _collection = '';
                  });
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
              ? l10n.cbnFlowEmptyIncoming
              : _stage == 'staging'
                  ? l10n.cbnFlowEmptyStaging
                  : l10n.cbnFlowEmptyPushed,
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
                Text('${_cur.length} / ${_totals[_stage] ?? _cur.length}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const Spacer(),
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

  Widget _tile(CbnItem it) {
    final on = _sel.contains(it.id);
    // 3-4. akista karta numarali sablon konur: varligin asil yuzu odur.
    final kind = _stage == 'incoming' ? 'image' : 'numbered';
    return GestureDetector(
      // Tek dokunus acar, basili tutma secer; secim acikken dokunus secer/birakir.
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
              const ColoredBox(color: Colors.black),
              Image.network(
                CbnFlowService.thumbUrl(_rating, _stage, it.id, kind: kind),
                headers: CbnFlowService.authHeaders,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(color: Colors.white10),
              ),
              Positioned(
                left: 4,
                right: 4,
                bottom: 4,
                child: Text(
                  it.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: Colors.white,
                      shadows: [Shadow(blurRadius: 3, color: Colors.black)]),
                ),
              ),
              Positioned(
                left: 4,
                top: 4,
                child: Row(
                  children: [
                    if (it.tagged == false) _rozet(l10n.flowBadgeNoTags, AppColors.error),
                    if (it.tagged == true) _rozet(l10n.cbnFlowBadgeTagged, Colors.teal),
                    if (it.objects) _rozet(l10n.cbnFlowBadgeObjects, Colors.blueGrey),
                    if (it.masks) _rozet('SAM', Colors.deepOrange),
                    if (it.lineart) _rozet('C', Colors.brown),
                    if (it.built) _rozet(l10n.cbnFlowBadgeBuilt(it.regions, it.colors),
                        it.verdict == 'pass' ? Colors.green.shade700 : Colors.orange.shade800),
                    if (it.video) _rozet('video', Colors.purple),
                    if (it.svg) _rozet('svg', Colors.indigo),
                  ],
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
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

  /// Onizleme: 2. akista kaynak; 3-4. akista katmanlar arasinda gecis
  /// (numarali / bitmis / cizgi / kaynak / SAM bolumleri) + hot'ta reveal video.
  void _preview(CbnItem it) {
    if (_stage == 'incoming') {
      // #318: rozet yerine ARA CIKTILAR gorulsun - Kaynak / Nesneler / SAM / Cizgi.
      showDialog(
        context: context,
        builder: (_) => _IncomingPreview(rating: _rating, item: it),
      );
      return;
    }
    final katmanlar = [
      ('numbered', l10n.cbnFlowLayerNumbered),
      ('preview', l10n.cbnFlowLayerFinished),
      ('lineart', l10n.cbnFlowLineart),
      ('image', l10n.cbnFlowLayerSource),
      ('segments', 'SAM'),
    ];
    var kind = 'numbered';
    var video = false;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (c, setD) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: video ? Colors.black : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: video
                    ? NetworkVideo(
                        url: CbnFlowService.fileUrl(_rating, _stage, it.id, kind: 'video'),
                        headers: CbnFlowService.authHeaders,
                      )
                    : Image.network(
                        CbnFlowService.thumbUrl(_rating, _stage, it.id,
                            kind: kind, size: 1024),
                        headers: CbnFlowService.authHeaders,
                        errorBuilder: (_, _, _) => const SizedBox(height: 120),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Wrap(
                  spacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final k in katmanlar)
                      ChoiceChip(
                        label: Text(k.$2, style: const TextStyle(fontSize: 11)),
                        selected: !video && kind == k.$1,
                        onSelected: (_) => setD(() {
                          kind = k.$1;
                          video = false;
                        }),
                      ),
                    if (it.video)
                      ChoiceChip(
                        label: const Text('Reveal', style: TextStyle(fontSize: 11)),
                        selected: video,
                        onSelected: (_) => setD(() => video = true),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Text(
                  '${l10n.cbnFlowInfo(it.label, it.regions, it.colors, it.verdict.toUpperCase())}'
                  '${it.tags.isEmpty ? "" : "\n${it.tags}"}',
                  style: TextStyle(
                      fontSize: 12, color: video ? Colors.white70 : null),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// #318: secim cubugundaki "On izleme" - secilenlerden ilkini acar.
  void _previewSelected() {
    final secili = _cur.where((i) => _sel.contains(i.id)).toList();
    if (secili.isEmpty) {
      _snack(l10n.flowSelectAssetFirst);
      return;
    }
    _preview(secili.first);
  }

  Widget _actionBar() {
    final butonlar = <Widget>[];
    if (_stage == 'incoming') {
      butonlar.addAll([
        // #318: insa etmeden once A/B/C ciktilarini goster (ilk secili varlik).
        _act(Icons.visibility_outlined, l10n.flowPreview, l10n.flowPreview, _previewSelected),
        _act(Icons.new_label_outlined, l10n.flowRetagShort, l10n.flowRetag, _retag),
        _act(Icons.manage_search, 'A)', l10n.cbnFlowFindObjects,
            () => _runStage(l10n.cbnFlowStageObjects, (ids) => CbnFlowService.objects(rating: _rating, ids: ids))),
        _act(Icons.blur_on, 'B)', l10n.cbnFlowSamMasks,
            () => _runStage('SAM', (ids) => CbnFlowService.sam(rating: _rating, ids: ids))),
        if (_rating == 'hot')
          _act(Icons.gesture, 'C)', l10n.cbnFlowLineartPage,
              () => _runStage(l10n.cbnFlowLineart, (ids) => CbnFlowService.lineart(rating: _rating, ids: ids))),
        _act(Icons.auto_awesome, 'D)', l10n.cbnFlowBuildStep, _build),
        _act(Icons.delete_outline, l10n.delete, l10n.delete, _delete),
      ]);
    } else if (_stage == 'staging') {
      butonlar.addAll([
        _act(Icons.cloud_upload_outlined, l10n.flowPush, l10n.flowPush, _push),
        _act(Icons.delete_outline, l10n.delete, l10n.delete, _delete),
      ]);
    } else {
      butonlar.add(_act(Icons.info_outline, l10n.flowReadOnly, l10n.flowReadOnly, null));
    }
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: Theme.of(context).colorScheme.surface,
        child: Row(children: butonlar),
      ),
    );
  }

  // #317: ikonun altinda kisa etiket (A) / B) / C) / D) ...) - asama hangisi
  // belli olsun. Kisa etiket [kisa], tam aciklama [t] (tooltip).
  Widget _act(IconData i, String kisa, String t, VoidCallback? f) => Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                onPressed: f,
                tooltip: t,
                icon: Icon(i, size: 22),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact),
            Text(
              kisa,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 9, color: f == null ? Colors.grey : Colors.white70),
            ),
          ],
        ),
      );

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 36),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
}

/// #318: Gelen (2. akis) on izlemesi - "İnşa et"e basmadan ONCE A/B/C
/// asamalarinin ciktilarini gosterir.
///
///   Kaynak    kaynak jpg
///   Nesneler  A adimi: objects.json listesi (chip'ler)
///   SAM       B adimi: masks.npz'den uretilen bolum kaplamasi (segments.jpg)
///   Cizgi     C adimi: Qwen cizgi sayfasi (yalniz hot)
///
/// Yapilmamis adim icin "A/B/C adimi yapilmamis" yazar. Gorseller
/// InteractiveViewer icinde - parmakla yakinlastirilabilir (3-4. akistaki
/// katman onizlemesiyle ayni his).
class _IncomingPreview extends StatefulWidget {
  const _IncomingPreview({required this.rating, required this.item});

  final String rating;
  final CbnItem item;

  @override
  State<_IncomingPreview> createState() => _IncomingPreviewState();
}

class _IncomingPreviewState extends State<_IncomingPreview> {
  String _view = 'image';
  CbnMeta? _meta;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await CbnFlowService.meta(widget.rating, 'incoming', widget.item.id);
      if (mounted) setState(() => _meta = m);
    } catch (e) {
      if (mounted) {
        setState(() => _err = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  bool get _hasObjects => _meta?.hasObjects ?? widget.item.objects;
  bool get _hasMasks => _meta?.hasMasks ?? widget.item.masks;
  bool get _hasLineart => _meta?.hasLineart ?? widget.item.lineart;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context)!;
    final gorunumler = <(String, String)>[
      ('image', l10n.cbnFlowLayerSource),
      ('objects', l10n.cbnFlowLayerObjects),
      ('segments', 'SAM'),
      // kid'de cizgi sayfasi yok (C adimi yalniz hot).
      if (widget.rating == 'hot') ('lineart', l10n.cbnFlowLineart),
    ];
    return Dialog(
      // #289: alt gezinme cubugunun altinda kalmasin.
      insetPadding: EdgeInsets.fromLTRB(12, 12, 12, 12 + systemBottomInset(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: mq.size.height * 0.6),
            child: _body(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Wrap(
              spacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final g in gorunumler)
                  ChoiceChip(
                    label: Text(_etiket(g.$1, g.$2),
                        style: const TextStyle(fontSize: 11)),
                    selected: _view == g.$1,
                    onSelected: (_) => setState(() => _view = g.$1),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Text(
              '${l10n.cbnFlowTagLine(widget.item.label, widget.item.tagged == true ? l10n.flowYes : l10n.flowMissingUpper)}'
              '${widget.item.prompt.isEmpty ? "" : "\n${widget.item.prompt}"}',
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Chip etiketi: yapilmis adimin yaninda kucuk bir isaret.
  String _etiket(String kind, String ad) {
    final ok = switch (kind) {
      'objects' => _hasObjects,
      'segments' => _hasMasks,
      'lineart' => _hasLineart,
      _ => true,
    };
    if (kind == 'segments' && ok && (_meta?.maskCount ?? 0) > 0) {
      return '$ad (${_meta!.maskCount})';
    }
    return ok ? ad : '$ad ·';
  }

  Widget _body() {
    final l10n = AppLocalizations.of(context)!;
    if (_view == 'objects') return _objects();
    final eksik = switch (_view) {
      'segments' => !_hasMasks ? l10n.cbnFlowStepMissingB : null,
      'lineart' => !_hasLineart ? l10n.cbnFlowStepMissingC : null,
      _ => null,
    };
    if (eksik != null) return _bos(eksik);
    return InteractiveViewer(
      maxScale: 5,
      child: Image.network(
        CbnFlowService.thumbUrl(widget.rating, 'incoming', widget.item.id,
            kind: _view, size: 900),
        headers: CbnFlowService.authHeaders,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, p) => p == null
            ? child
            : const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
        errorBuilder: (_, _, _) => _bos(l10n.cbnFlowImageFailed),
      ),
    );
  }

  Widget _objects() {
    final l10n = AppLocalizations.of(context)!;
    if (_meta == null) {
      return Padding(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: _err == null
              ? const CircularProgressIndicator()
              : Text(_err!, textAlign: TextAlign.center),
        ),
      );
    }
    if (!_meta!.hasObjects || _meta!.objects.isEmpty) {
      return _bos(l10n.cbnFlowStepMissingA);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.bucketsObjectCount(_meta!.objects.length)}'
            '${_meta!.objectsAgent.isEmpty ? "" : "  ·  ${_meta!.objectsAgent}"}'
            '${_meta!.objectsAt.isEmpty ? "" : "  ·  ${_meta!.objectsAt}"}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final o in _meta!.objects)
                Chip(
                  label: Text(o, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bos(String m) => Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text(m,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      );
}
