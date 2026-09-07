import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/cbn_flow_service.dart';
import '../services/jigsaw_flow_service.dart' show FlowCollection, FlowOp;
import '../services/mode_service.dart';
import '../widgets/network_video.dart';
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
  static const _titles = ['2 Gelen', '3 Hazir', '4 Push edilmis'];

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
    _opPoll = Timer.periodic(const Duration(seconds: 2), (t) async {
      try {
        final o = await CbnFlowService.op(opId);
        if (!mounted) return;
        setState(() => _op = o);
        tick++;
        if (!o.running) {
          t.cancel();
          _snack(o.status == 'error'
              ? 'Islem hatasi: ${o.message}'
              : '${o.ok} tamam${o.failed > 0 ? ", ${o.failed} hata" : ""}');
          _load();
        } else if (o.kind == 'cbn-build' && tick % 15 == 0) {
          _load();
        }
      } catch (_) {
        t.cancel();
      }
    });
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<bool> _confirm(String baslik, String metin, {String onay = 'Devam'}) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(baslik),
          content: Text(metin),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Vazgec')),
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
        title: Text('Insa et - ${ids.length} varlik'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _rating == 'hot'
                  ? 'Her varlik icin: Opus nesne listesi, Qwen cizgi sayfasi, '
                      'SAM3 bolgeler, palet ve reveal videosu (~4 dk).'
                  : 'Her varlik icin: Opus nesne listesi, SAM3 bolgeler, palet ve '
                      'SVG (~2 dk).',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              decoration: const InputDecoration(
                labelText: 'Koleksiyon',
                border: OutlineInputBorder(),
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
              onPressed: () => Navigator.pop(c), child: const Text('Vazgec')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctl.text.trim()),
              child: const Text('Insa et')),
        ],
      ),
    );
    if (coll == null || coll.isEmpty) return;
    try {
      final op = await CbnFlowService.build(rating: _rating, ids: ids, collection: coll);
      setState(_sel.clear);
      _watch(op);
      _snack('Insa basladi - ilerleme ustte');
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
      _snack('Etiketleme basladi');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _push() async {
    final ids = _sel.toList();
    final ok = await _confirm(
        'Push - ${ids.length} varlik',
        'Varlik klasorleri R2\'ye yuklenecek ve "Push edilmis"e tasinacak.\n\n'
        'Bu bir YAYIN islemidir, geri alinamaz.',
        onay: 'Push');
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
    final ok = await _confirm('Sil', '${ids.length} varlik silinecek.', onay: 'Sil');
    if (!ok) return;
    try {
      final n = await CbnFlowService.remove(rating: _rating, stage: _stage, ids: ids);
      setState(_sel.clear);
      _snack('$n silindi');
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
        title: _selecting
            ? Text('${_sel.length} secili')
            : (widget.kindSwitch ?? const Text('CBN hatti')),
        actions: [
          if (!_selecting)
            IconButton(
              icon: const Icon(Icons.code),
              tooltip: 'Code Mod',
              onPressed: () => ModeService.set(false),
            ),
          IconButton(
              icon: const Icon(Icons.refresh), tooltip: 'Yenile', onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [for (final t in _titles) Tab(text: t)],
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
      tooltip: 'Koleksiyon',
      onSelected: (v) {
        setState(() {
          _collection = v;
          _sel.clear();
        });
        _load();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: '', child: Text('(hepsi)')),
        for (final k in liste)
          PopupMenuItem(value: k.name, child: Text('${k.name}  (${k.count})')),
      ],
      child: Chip(
        avatar: const Icon(Icons.folder_outlined, size: 16),
        label: Text(_collection.isEmpty ? 'hepsi' : _collection,
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
              ? 'Bu akista varlik yok.\n"Uretilenler" ekraninda CBN Modu\'nda '
                  'KABUL ET ile buraya dusur.'
              : _stage == 'staging'
                  ? 'Henuz insa edilmis varlik yok.\n"Gelen" sekmesinden sec ve INSA ET.'
                  : 'Push edilmis varlik yok.',
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
                  child: const Text('Tumunu sec'),
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
      onTap: () => setState(() => on ? _sel.remove(it.id) : _sel.add(it.id)),
      onLongPress: () => _preview(it),
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
                    if (it.tagged == false) _rozet('etiket yok', AppColors.error),
                    if (it.tagged == true) _rozet('etiketli', Colors.teal),
                    if (it.built) _rozet('${it.regions}b ${it.colors}r',
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
      showDialog(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Image.network(
                  CbnFlowService.thumbUrl(_rating, _stage, it.id, size: 900),
                  headers: CbnFlowService.authHeaders,
                  errorBuilder: (_, _, _) => const SizedBox(height: 120),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  '${it.label}\netiket: ${it.tagged == true ? "var" : "YOK"}'
                  '${it.prompt.isEmpty ? "" : "\n${it.prompt}"}',
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }
    const katmanlar = [
      ('numbered', 'Numarali'),
      ('preview', 'Bitmis'),
      ('lineart', 'Cizgi'),
      ('image', 'Kaynak'),
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
                  '${it.label}   ${it.regions} bolge · ${it.colors} renk · '
                  '${it.verdict.toUpperCase()}'
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

  Widget _actionBar() {
    final butonlar = <Widget>[];
    if (_stage == 'incoming') {
      butonlar.addAll([
        _act(Icons.new_label_outlined, 'Yeniden etiketle', _retag),
        _act(Icons.auto_awesome, 'Insa et', _build),
        _act(Icons.delete_outline, 'Sil', _delete),
      ]);
    } else if (_stage == 'staging') {
      butonlar.addAll([
        _act(Icons.cloud_upload_outlined, 'Push', _push),
        _act(Icons.delete_outline, 'Sil', _delete),
      ]);
    } else {
      butonlar.add(_act(Icons.info_outline, 'Salt gorunum', null));
    }
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: Theme.of(context).colorScheme.surface,
        child: Row(children: butonlar),
      ),
    );
  }

  Widget _act(IconData i, String t, VoidCallback? f) => Expanded(
        child: IconButton(onPressed: f, tooltip: t, icon: Icon(i, size: 24)),
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
              FilledButton(onPressed: _load, child: const Text('Tekrar dene')),
            ],
          ),
        ),
      );
}
