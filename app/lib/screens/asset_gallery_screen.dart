import 'dart:async';

import 'package:flutter/material.dart';

import '../services/generate_service.dart';
import '../services/card_flow_service.dart';
import '../services/cbn_flow_service.dart';
import '../services/character_flow_service.dart';
import '../services/jigsaw_flow_service.dart';
import '../services/jigsaw_profiles.dart';
import 'character_flow_screen.dart' show characterCreateDialog;  // #306
import '../theme.dart';
import '../services/mode_service.dart';
import '../widgets/bottom_inset.dart';
import '../widgets/network_video.dart';
import '../widgets/flow_kind_switch.dart';
import '../widgets/outfit_extract_dialog.dart';  // #329

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

  /// Kendiliginden tazeleme (gorev #269): sirada/calisan is varken 3 sn'de
  /// bir, yoksa 15 sn'de bir sessizce yeniden yukler - Uretim ekranindan
  /// eklenen is de yenile dugmesine basmadan buraya duser.
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _tick++;
      final busy = _jobs.any((j) => j.isBusy);
      if (busy || _tick % 5 == 0) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

  Future<void> _load({bool silent = false}) async {
    if (silent && (_loading || _busy)) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));   // #352: sessiz kalmasin
    }
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

  /// Secili tamamlanmis gorseller - karakter eylemleri bunlarla calisir.
  List<GenerateJob> get _selectedImages => _sel
      .map((id) => _jobs.where((j) => j.id == id).firstOrNull)
      .whereType<GenerateJob>()
      .where((j) => j.isDone && !j.isVideo)
      .toList();

  /// #329: her kipte - secili TEK gorseldeki kiyafeti gardirop kutuphanesine
  /// cikarir (sunucuda edit_qwen, kuyruk). Kaynak gorsel is kimligiyle gider.
  Future<void> _extractOutfit() async {
    final gorseller = _selectedImages;
    if (gorseller.isEmpty) {
      _msg('Tamamlanmis gorsel sec');
      return;
    }
    if (gorseller.length > 1) {
      _msg('Kiyafet tek gorselden cikarilir - birini sec');
      return;
    }
    final secim = await showOutfitExtractDialog(context);
    if (secim == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await CharacterFlowService.outfitExtract(
          name: secim.name,
          category: secim.category,
          kind: secim.kind,
          jobId: gorseller.first.id,
          note: secim.note);
      if (!mounted) return;
      _msg('${secim.name} gardiroba cikariliyor - Karakter > Gardirop');
      setState(_sel.clear);
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Karakter Modu - "Karakter yap": secili TEK isten yeni bir karakter
  /// klasoru acar (isim + sinif + istege bagli kimlik cumlesi). #306: sunucu
  /// secili gorseli dogrudan base yapar ve otomatik hatti (portre, hikaye,
  /// yonler) baslatir - onay sorulmaz.
  Future<void> _makeCharacter() async {
    final gorseller = _selectedImages;
    if (gorseller.isEmpty) {
      _msg('Tamamlanmis gorsel sec');
      return;
    }
    if (gorseller.length > 1) {
      _msg('Karakter tek gorselden acilir - birini sec');
      return;
    }
    // #306: pencere Karakter hattiyla ortak (isim + sinif + kimlik cumlesi).
    final sonuc = await characterCreateDialog(
      context,
      baslik: 'Karakter yap',
      aciklama: 'Secili gorsel dogrudan base olur; portre, hikaye ve 7 yon '
          'kendiliginden uretilir - onay sorulmaz.',
      promptGerekli: false,
    );
    if (sonuc == null) return;
    setState(() => _busy = true);
    try {
      // #306: create artik otomatik hatti baslatir ve op doner - secili is
      // dogrudan base olur, portre/hikaye/yonler kendiliginden uretilir.
      // #314: pencerede secilen tur (Kadin/Erkek/Hayvan/Makine) sunucuya
      // gonderilir - prompt'lar, notr base ve animasyon yollari buna gore.
      await CharacterFlowService.create(
          name: sonuc.name,
          klass: sonuc.klass,
          prompt: sonuc.prompt,
          kind: sonuc.kind,
          jobId: gorseller.first.id);
      if (!mounted) return;
      _msg('${sonuc.name} siraya eklendi - pipeline Sira sekmesinde');
      setState(_sel.clear);
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Karakter Modu - "Adaylara ekle": secili isleri mevcut bir karakterin
  /// candidates/ klasorune kopyalar.
  Future<void> _stageToCharacter() async {
    final gorseller = _selectedImages;
    if (gorseller.isEmpty) {
      _msg('Tamamlanmis gorsel sec');
      return;
    }
    List<CharacterItem> karakterler;
    try {
      karakterler = await CharacterFlowService.list();
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    if (!mounted) return;
    if (karakterler.isEmpty) {
      _msg('Once "Karakter yap" ile bir karakter olustur');
      return;
    }
    final ad = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Adaylara ekle - ${gorseller.length} gorsel'),
        content: SizedBox(
          width: 380,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final k in karakterler)
                ListTile(
                  dense: true,
                  title: Text(k.name),
                  subtitle: Text(k.klass.isEmpty ? '-' : k.klass,
                      style: const TextStyle(fontSize: 11)),
                  onTap: () => Navigator.pop(c, k.name),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgec')),
        ],
      ),
    );
    if (ad == null) return;
    setState(() => _busy = true);
    try {
      final n = await CharacterFlowService.stage(
          name: ad, jobIds: gorseller.map((j) => j.id).toList());
      if (!mounted) return;
      _msg('$ad adaylarina $n gorsel eklendi');
      setState(_sel.clear);
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// #323 Kart Modu - "Koleksiyona ekle": secili TEK isi bir koleksiyonun
  /// (ya da krupiyenin) still'i yapar. Rutbe kullanicidan sorulur; krupiyede
  /// rutbe yoktur, tek oge dogrudan hedeftir.
  Future<void> _stageToCollection() async {
    final gorseller = _selectedImages;
    if (gorseller.isEmpty) {
      _msg('Tamamlanmis gorsel sec');
      return;
    }
    if (gorseller.length > 1) {
      _msg('Koleksiyona tek gorsel eklenir - birini sec');
      return;
    }
    List<CardCollection> koleksiyonlar;
    List<CardDealer> krupiyeler;
    try {
      koleksiyonlar = await CardFlowService.collections();
      krupiyeler = await CardFlowService.dealers();
    } on CardNotReadyException catch (e) {
      _msg(e.message);
      return;
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    if (!mounted) return;
    if (koleksiyonlar.isEmpty && krupiyeler.isEmpty) {
      _msg('Once Kart hattinda bir koleksiyon ya da krupiye olustur');
      return;
    }
    // 1) hedef sec (koleksiyon ya da krupiye)
    final hedef = await showDialog<(String, String)>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Koleksiyona ekle'),
        content: SizedBox(
          width: 380,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final k in koleksiyonlar)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.style_outlined, size: 20),
                  title: Text(k.name),
                  subtitle: Text(k.theme.isEmpty ? k.id : k.theme,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                  onTap: () => Navigator.pop(c, ('card', k.id)),
                ),
              for (final d in krupiyeler)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.person_outline, size: 20),
                  title: Text(d.name),
                  subtitle: const Text('krupiye (rutbe yok)',
                      style: TextStyle(fontSize: 11)),
                  onTap: () => Navigator.pop(c, ('dealer', d.id)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Vazgec')),
        ],
      ),
    );
    if (hedef == null || !mounted) return;
    final (tur, id) = hedef;

    // 2) rutbe sec (yalniz koleksiyonda)
    var rank = CardFlowService.dealerRank;
    if (tur == 'card') {
      final k = koleksiyonlar.firstWhere((e) => e.id == id);
      final secim = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('${k.name} - rutbe sec'),
          content: SizedBox(
            width: 360,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in k.rankOrder)
                  ActionChip(
                    label: Text(r),
                    // Dolu rutbe uzerine yazmak riskli - kullanici gorsun.
                    avatar: k.stateOf(r).still
                        ? const Icon(Icons.warning_amber_rounded, size: 14)
                        : null,
                    onPressed: () => Navigator.pop(c, r),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('Vazgec')),
          ],
        ),
      );
      if (secim == null) return;
      rank = secim;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await CardFlowService.stage(
          collection: id, rank: rank, jobId: gorseller.first.id, kind: tur);
      if (!mounted) return;
      _msg('Siraya eklendi (1 is) - Sira sekmesinden izle');
      setState(_sel.clear);
    } on CardNotReadyException catch (e) {
      _msg(e.message);
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
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
    final cbn = _mode == 'cbn';
    final ratings = cbn ? CbnFlowService.ratings : JigsawProfiles.ratings;
    final rating = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kabul et'),
        content: Text(cbn
            ? '${gorseller.length} gorsel CBN hattinin "Gelen" akisina tasinacak: '
                'jpg + EXIF etiketi. Insa (SAM, cizgi, bolgeler) orada baslatilir.\n\n'
                'Hangi derece?'
            : '${gorseller.length} gorsel 2. akisa tasinacak: '
                'jpg + EXIF etiketi, varsa videosu da yaninda.\n\n'
                'Hangi derece?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Vazgec')),
          for (final e in ratings.entries)
            FilledButton(
                onPressed: () => Navigator.pop(c, e.key), child: Text(e.value)),
        ],
      ),
    );
    if (rating == null) return;
    setState(() => _busy = true);
    try {
      final jobs = gorseller.map((j) => j.id).toList();
      if (cbn) {
        await CbnFlowService.stageJobs(jobs: jobs, rating: rating);
      } else {
        await JigsawFlowService.stageJobs(jobs: jobs, rating: rating);
      }
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
      builder: (_) => _ViewerPage(jobs: List.of(list), index: list.indexOf(j)),
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
                // #329: her kipte - secili tek gorselden kiyafet cikar.
                IconButton(
                  icon: const Icon(Icons.checkroom_outlined),
                  tooltip: 'Kiyafet cikar - gorseldeki kiyafeti gardiroba al',
                  onPressed: _busy ? null : _extractOutfit,
                ),
                if (_mode == 'character') ...[
                  IconButton(
                    icon: const Icon(Icons.person_add_alt),
                    tooltip: 'Karakter yap - yeni karakter olustur',
                    onPressed: _busy ? null : _makeCharacter,
                  ),
                  IconButton(
                    icon: const Icon(Icons.playlist_add),
                    tooltip: 'Adaylara ekle - mevcut karaktere kopyala',
                    onPressed: _busy ? null : _stageToCharacter,
                  ),
                ] else if (_mode == 'card')
                  // #323: secili is bir koleksiyonun rutbesine still olur.
                  IconButton(
                    icon: const Icon(Icons.style_outlined),
                    tooltip: 'Koleksiyona ekle - rutbe sec',
                    onPressed: _busy ? null : _stageToCollection,
                  )
                else if (_mode != 'free')
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
                  icon: const Icon(Icons.local_shipping_outlined),
                  tooltip: 'Delivery Mod',
                  onPressed: () => ModeService.setMode(ModeService.delivery),   // #363
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Yenile',
                  onPressed: _load,
                ),
              ],
        // #355: uc ekranda da AYNI kalip (kindSwitchBottom) - ayni yukseklik,
        // ayni yatay bosluk, ayni hiza.
        bottom: kindSwitchBottom(
          FlowKindSwitch(                               // #327
            items: kindLabels,                          // #355: tek kaynak
            selected: _mode,
            onChanged: (v) {
              setState(() {
                _mode = v;
                _sel.clear();
              });
              _load();
            },
          ),
          tabs: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: SingleChildScrollView(
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
            // Sigdir, kirpma: yatay/kare ciktilar hucrede butun gorunsun.
            const ColoredBox(color: Colors.black),
            if (j.isDone)
              Image.network(
                j.thumbUrl(),
                headers: GenerateService.authHeaders,
                fit: BoxFit.contain,
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

  /// Kabul: derece sor, isi hattin 2. akisina (Gelen) gonder, sonraki
  /// gorsele gec. Uretilenler'deki toplu "Kabul et" ile ayni yol; burada tek
  /// tek eleme icin (gorev #273 - "Havuza ekle" yerine Kabul / Red).
  Future<void> _accept() async {
    final j = _job;
    if (!j.isDone || j.isVideo) return;
    final cbn = j.mode == 'cbn';
    final ratings = cbn ? CbnFlowService.ratings : JigsawProfiles.ratings;
    final rating = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kabul et'),
        content: Text(cbn
            ? 'CBN hattinin "Gelen" akisina tasinacak (jpg + EXIF etiketi).\n\nHangi derece?'
            : '2. akisa tasinacak (jpg + EXIF etiketi).\n\nHangi derece?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgec')),
          for (final e in ratings.entries)
            FilledButton(
                onPressed: () => Navigator.pop(c, e.key), child: Text(e.value)),
        ],
      ),
    );
    if (rating == null) return;
    try {
      if (cbn) {
        await CbnFlowService.stageJobs(jobs: [j.id], rating: rating);
      } else {
        await JigsawFlowService.stageJobs(jobs: [j.id], rating: rating);
      }
      _snack('Kabul edildi - etiketleniyor, "Hat" sekmesinden izle');
      _advanceAfterRemoving();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Red: uretimi hemen siler ve sonraki gorsele gecer - eleme hizli olsun
  /// diye onay sorulmaz (yanlislikla basildiysa ayni prompt/seed ile
  /// yeniden uretilebilir; bilgi cubugunda seed yaziyor).
  Future<void> _reject() async {
    final j = _job;
    try {
      await GenerateService.delete(j.id);
      _snack('Reddedildi');
      _advanceAfterRemoving();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Gecerli isi listeden dusurur; kalan yoksa kapanir, varsa ayni konumdaki
  /// (yani bir sonraki) gorsele gecer.
  void _advanceAfterRemoving() {
    _changed = true;
    if (!mounted) return;
    widget.jobs.removeAt(_i);
    if (widget.jobs.isEmpty) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => _i = _i.clamp(0, widget.jobs.length - 1));
    _pages.jumpToPage(_i);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// Duzenle: bu gorseli kaynak alip edit motoruyla (Qwen Image Edit -
  /// kimlik korur) YENI bir uretim acar. Ek prompt sorulur; sonuc ayni kipin
  /// galerisine duser (gorev #274).
  Future<void> _edit() async {
    final j = _job;
    if (!j.isDone || j.isVideo) return;
    final ctl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        // 4 satirlik otomatik odakli prompt kutusu klavyeyle tasiyordu (gorev #289).
        scrollable: true,
        title: const Text('Duzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bu gorsel kaynak olur; edit motoru (Qwen Image Edit, kimlik korur) '
              'yeni bir uretim acar. Ne degissin?',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctl,
              autofocus: true,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Ek prompt',
                hintText: 'orn. change the dress to a red pleated miniskirt, keep face and pose',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgec')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(c, ctl.text.trim()),
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('Uret'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    try {
      await GenerateService.submit(
        task: 'edit_qwen',
        prompt: text,
        sourceJob: j.id,
        mode: j.mode.isEmpty ? 'free' : j.mode,
      );
      _changed = true;
      _snack('Duzenleme siraya eklendi - sonucu Uretilenler\'de gorursun');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
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
          if (j.isDone && !j.isVideo)
            IconButton(
              icon: const Icon(Icons.auto_fix_high),
              tooltip: 'Duzenle - edit motoruyla yeni uretim',
              onPressed: _edit,
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
          if ((j.mode == 'jigsaw' || j.mode == 'cbn') && j.isDone && !j.isVideo) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reddet'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _accept,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Kabul'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Tek bir video isini oynatir.
