import 'package:flutter/material.dart';

import '../services/generate_service.dart';
import '../services/jigsaw_flow_service.dart';
import '../services/jigsaw_profiles.dart';
import '../theme.dart';
import '../services/mode_service.dart';
import '../widgets/bottom_inset.dart';
import '../widgets/network_video.dart';

/// Asset Mod - Uretilenler ekrani.
///
/// Isleri kucuk onizleme kareleri halinde gosterir; karta dokununca tam ekran
/// goruntuleyici acilir (video ise oynatir). Metin listesi degil, gorsel secim.
class AssetGalleryScreen extends StatefulWidget {
  const AssetGalleryScreen({super.key});

  @override
  State<AssetGalleryScreen> createState() => _AssetGalleryScreenState();
}

enum _Filter { all, image, video, favorite }

class _AssetGalleryScreenState extends State<AssetGalleryScreen> {
  List<GenerateJob> _jobs = [];
  bool _loading = true;
  String? _error;
  _Filter _filter = _Filter.all;

  /// Galeri kipe ozeldir: Free kipinde free isleri, Jigsaw kipinde jigsaw
  /// isleri gorunur - masaustundeki studyo ile ayni.
  String _mode = 'jigsaw';

  /// Coklu secim: uzun basinca acilir, toplu silme icin.
  final Set<String> _sel = {};
  bool get _selecting => _sel.isNotEmpty;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Videolar AYRI kart degildir: uretildikleri gorselin kartina baglanir ve
  /// kartta bir oynat dugmesi cikar. Kaynagi listede olmayan video kendi
  /// karti olarak gorunur ki kaybolmasin.
  Map<String, List<GenerateJob>> get _videosByImage {
    final gorseller = _jobs.where((j) => !j.isVideo).map((j) => j.id).toSet();
    final out = <String, List<GenerateJob>>{};
    for (final j in _jobs) {
      if (j.isVideo && gorseller.contains(j.sourceJob)) {
        out.putIfAbsent(j.sourceJob!, () => []).add(j);
      }
    }
    return out;
  }

  List<GenerateJob> get _cards {
    final gorseller = _jobs.where((j) => !j.isVideo).map((j) => j.id).toSet();
    return _jobs
        .where((j) => !(j.isVideo && gorseller.contains(j.sourceJob)))
        .toList();
  }

  List<GenerateJob> _videosOf(GenerateJob j) => _videosByImage[j.id] ?? const [];

  /// Kartta oynatilacak is: bagli video varsa o, kart zaten videoysa kendisi.
  GenerateJob? _playable(GenerateJob j) {
    final v = _videosOf(j);
    if (v.isNotEmpty) return v.first;
    return j.isVideo ? j : null;
  }

  List<GenerateJob> get _visible {
    final c = _cards;
    return switch (_filter) {
      _Filter.all => c,
      _Filter.image => c
          .where((j) => j.isDone && !j.isVideo && _videosOf(j).isEmpty)
          .toList(),
      _Filter.video =>
        c.where((j) => _playable(j) != null && j.isDone).toList(),
      _Filter.favorite => c.where((j) => j.favorite).toList(),
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final j = await GenerateService.list(limit: 80, mode: _mode);
      if (!mounted) return;
      setState(() {
        _jobs = j;
        _sel.removeWhere((id) => !j.any((x) => x.id == id));
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

  Future<void> _toggleFav(GenerateJob j) async {
    try {
      await GenerateService.setFavorite(j.id, !j.favorite);
      _load();
    } catch (_) {}
  }

  void _toggleSel(GenerateJob j) {
    setState(() => _sel.contains(j.id) ? _sel.remove(j.id) : _sel.add(j.id));
  }

  /// Secili tum uretimleri siler.
  Future<void> _deleteSelected() async {
    final n = _sel.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sil'),
        content: Text('$n uretim ve dosyasi silinsin mi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgec')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    // Video gorselin kartinda duruyor; karti silmek videosunu da siler.
    final idler = <String>[];
    for (final id in _sel) {
      idler.add(id);
      final j = _jobs.where((x) => x.id == id).firstOrNull;
      if (j != null) idler.addAll(_videosOf(j).map((v) => v.id));
    }
    var hata = 0;
    for (final id in idler) {
      try {
        await GenerateService.delete(id);
      } catch (_) {
        hata++;
      }
    }
    if (!mounted) return;
    setState(() {
      _sel.clear();
      _busy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(hata == 0 ? '$n uretim silindi' : '$hata silinemedi')));
    _load();
  }

  /// Oynat dugmesi: gorselin videosunu acar.
  Future<void> _play(GenerateJob j) async {
    final v = _playable(j);
    if (v == null) return;
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _ViewerPage(jobs: [v], index: 0),
    ));
    if (changed == true) _load();
  }

  /// 1 -> 2. Secili gorselleri sunucuda _Incoming'e tasitir ve etiketletir.
  Future<void> _acceptSelected() async {
    final gorseller = _sel
        .map((id) => _jobs.where((j) => j.id == id).firstOrNull)
        .whereType<GenerateJob>()
        .where((j) => j.isDone && !j.isVideo)
        .toList();
    if (gorseller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tamamlanmis gorsel sec')));
      return;
    }
    final rating = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kabul et'),
        content: Text('${gorseller.length} gorsel 2. akisa tasinacak: '
            '720x1280 jpg + EXIF etiketi, varsa videosu da yaninda.\n\n'
            'Hangi derece?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Vazgec')),
          for (final e in JigsawProfiles.ratings.entries)
            FilledButton(
                onPressed: () => Navigator.pop(c, e.key), child: Text(e.value)),
        ],
      ),
    );
    if (rating == null) return;
    setState(() => _busy = true);
    try {
      await JigsawFlowService.stageJobs(
          jobs: gorseller.map((j) => j.id).toList(), rating: rating);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Basladi - ilerlemeyi "Hat" sekmesinden izle')));
      setState(_sel.clear);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(GenerateJob j) async {
    if (_selecting) {
      _toggleSel(j);
      return;
    }
    if (!j.isDone) return;
    final list = _visible;
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _ViewerPage(jobs: list, index: list.indexOf(j)),
    ));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _selecting
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Secimi birak',
                onPressed: () => setState(_sel.clear),
              )
            : null,
        title: Text(_selecting ? '${_sel.length} secili' : 'Uretilenler'),
        actions: _selecting
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Tumunu sec',
                  onPressed: () =>
                      setState(() => _sel.addAll(_visible.map((j) => j.id))),
                ),
                if (_mode == 'jigsaw')
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    tooltip: 'Kabul et - 2. akisa gonder',
                    onPressed: _busy ? null : _acceptSelected,
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Secilenleri sil',
                  onPressed: _busy ? null : _deleteSelected,
                ),
              ]
            : [
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(92),
          child: Column(
            children: [
              // Galeri kipe ozel - masaustundeki studyo ile ayni davranis.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'free', label: Text('Free Mod')),
                    ButtonSegment(value: 'jigsaw', label: Text('Jigsaw Modu')),
                  ],
                  selected: {_mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) {
                    setState(() {
                      _mode = v.first;
                      _sel.clear();
                    });
                    _load();
                  },
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    _chip('Hepsi', _Filter.all),
                    _chip('Gorsel', _Filter.image),
                    _chip('Video', _Filter.video),
                    _chip('Favori', _Filter.favorite),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _visible.isEmpty
                  ? _emptyView()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(10),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 9 / 16,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _visible.length,
                        itemBuilder: (_, i) => _tile(_visible[i]),
                      ),
                    ),
    );
  }

  Widget _chip(String label, _Filter f) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _filter == f,
          onSelected: (_) => setState(() => _filter = f),
        ),
      );

  Widget _tile(GenerateJob j) {
    final on = _sel.contains(j.id);
    return GestureDetector(
      onTap: () => _open(j),
      onLongPress: () => _toggleSel(j),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: on ? AppColors.accent : Colors.transparent, width: 3),
        ),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (j.isDone)
              Image.network(
                j.thumbUrl(),
                headers: GenerateService.authHeaders,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(j),
              )
            else
              _placeholder(j),
            if (j.isDone && _playable(j) != null)
              Positioned.fill(
                child: Center(
                  child: GestureDetector(
                    onTap: () =>
                        _selecting ? _toggleSel(j) : _play(j),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.play_arrow,
                          size: 26, color: Colors.white),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: Icon(j.favorite ? Icons.star : Icons.star_border,
                    color: j.favorite ? Colors.amber : Colors.white70),
                onPressed: () => _toggleFav(j),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                  ),
                ),
                child: Text(
                  j.prompt.isEmpty ? j.task : j.prompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: Colors.white),
                ),
              ),
            ),
            if (_selecting)
              Positioned(
                left: 6,
                bottom: 6,
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

  Widget _placeholder(GenerateJob j) => Container(
        color: Colors.white10,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: j.isBusy
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(height: 8),
                  Text(
                    j.isRunning ? '%${j.progress}' : 'sirada ${j.position ?? ''}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(j.isFailed ? Icons.error_outline : Icons.image_outlined,
                      size: 22, color: Colors.grey),
                  const SizedBox(height: 6),
                  Text(
                    (j.error ?? j.status),
                    maxLines: 3,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                ],
              ),
      );

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
}

/// Tam ekran goruntuleyici - gorseller yakinlastirilabilir, videolar oynar.
class _ViewerPage extends StatefulWidget {
  const _ViewerPage({required this.jobs, required this.index});

  final List<GenerateJob> jobs;
  final int index;

  @override
  State<_ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<_ViewerPage> {
  late final PageController _pages = PageController(initialPage: widget.index);
  late int _i = widget.index;
  bool _changed = false;

  GenerateJob get _job => widget.jobs[_i];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sil'),
        content: const Text('Bu uretim ve dosyasi silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgec')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GenerateService.delete(_job.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  Future<void> _jigsawExport() async {
    final j = _job;
    final imageJob = j.isVideo ? j.sourceJob : j.id;
    if (imageJob == null) {
      _snack('Bu videonun kaynak gorseli kayitli degil');
      return;
    }
    List<JigsawCategory> cats;
    try {
      cats = await GenerateService.jigsawCategories();
    } catch (e) {
      _snack('Kategoriler alinamadi');
      return;
    }
    if (!mounted) return;
    final chosen = await showModalBottomSheet<JigsawCategory>(
      context: context,
      showDragHandle: true,
      builder: (c) => ListView.builder(
        itemCount: cats.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(cats[i].name),
          subtitle: Text('${cats[i].count} varlik  ·  siradaki: ${cats[i].next}'),
          onTap: () => Navigator.pop(c, cats[i]),
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    _snack('havuza yaziliyor...');
    try {
      final r = await GenerateService.jigsawExport(
        imageJob: imageJob,
        videoJob: j.isVideo ? j.id : null,
        category: chosen.name,
      );
      _snack('Eklendi: ${r.category}/${r.number} — ${r.written.join(", ")}'
          '${r.warnings.isEmpty ? "" : "  (${r.warnings.join(" | ")})"}');
      _changed = true;
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final j = _job;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('${_i + 1} / ${widget.jobs.length}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, _changed),
        ),
        actions: [
          IconButton(
            icon: Icon(j.favorite ? Icons.star : Icons.star_border,
                color: j.favorite ? Colors.amber : null),
            onPressed: () async {
              try {
                await GenerateService.setFavorite(j.id, !j.favorite);
                _changed = true;
                if (mounted) setState(() {});
              } catch (_) {}
            },
          ),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.jobs.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) {
                final job = widget.jobs[i];
                return job.isVideo
                    ? NetworkVideo(
                        key: ValueKey(job.id),
                        url: job.fileUrl,
                        headers: GenerateService.authHeaders)
                    : InteractiveViewer(
                        child: Center(
                          child: Image.network(job.fileUrl,
                              headers: GenerateService.authHeaders),
                        ),
                      );
              },
            ),
          ),
          _infoBar(j),
        ],
      ),
    );
  }

  Widget _infoBar(GenerateJob j) {
    final bits = <String>[
      j.task,
      if (j.mode.isNotEmpty) j.mode,
      if (j.seconds != null) '${j.seconds!.toStringAsFixed(0)} sn',
      if (j.width > 0) '${j.width}x${j.height}',
      if (j.seed != null) 'seed ${j.seed}',
      if (j.exported != null) 'havuz ${j.exported}',
    ];
    // Tam ekran route: ust Scaffold'un nav cubugu yok, sistem gezinme
    // cubugunun yerini kimse birakmiyor. Sabit 20px yetmiyordu - "Havuza ekle"
    // 3 tuslu cubugun altinda kaliyordu (gorev #266).
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: bottomSafePadding(context, left: 16, top: 10, right: 16, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            j.combined.isNotEmpty ? j.combined : j.prompt,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(bits.join('  ·  '),
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          if (j.mode == 'jigsaw' && j.isDone) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _jigsawExport,
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: const Text('Havuza ekle'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tek bir video isini oynatir.
