import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/delivery_service.dart';
import '../services/mode_service.dart';
import '../theme.dart';

/// #363 Delivery Mod: uygulamalara NE sunulacaginin ac/kapa anahtarlari.
///
/// Kullanicinin amaci: olasi bir Google Play strike'ina hizli tepki. Generic
/// havuzundaki her gorselin EXIF'inde rating / safety / voyeur / skin / risk
/// ... alanlari var; burada her degerin yanindaki anahtar o degerdeki
/// gorselleri sunar ya da gizler. "Kaydet" worker'a yazar - sonraki manifest
/// isteginde canli, uygulama guncellemesi gerekmez. Uygulama basina ayri
/// kural seti acilabilir; `?app=` gondermeyen eski surumler varsayilani alir.
class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  DeliveryOverview? _o;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  /// Duzenlenen kopyalar - kaydedene kadar sunucuya gitmez.
  DeliveryRuleSet _def = DeliveryRuleSet();
  final Map<String, DeliveryRuleSet> _apps = {};
  /// '' = varsayilan, aksi halde paket adi.
  String _sel = '';
  bool _dirty = false;
  final Set<String> _acik = {'rating', 'safety', 'voyeur'};

  /// #385 engel listesi - kurallarla AYNI Kaydet dugmesine baglidir.
  DeliveryBlock _block = DeliveryBlock();
  List<DeliveryCatalogItem> _katalog = const [];
  bool _katalogYuklendi = false;
  List<NormalizePool> _norm = const [];
  Timer? _normTimer;

  /// Havuz -> engel listesi adi (worker bu adlari bekler).
  static const _grupListe = {'jigsaw': 'collections', 'cards': 'decks', 'events': 'hostLevels'};
  static const _ogeListe = {'jigsaw': 'pictures', 'cards': 'cards', 'events': 'hostLevels'};

  @override
  void dispose() {
    _normTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _pool = 'jigsaw';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final o = await DeliveryService.overview(pool: _pool);
      if (!mounted) return;
      setState(() {
        _o = o;
        _def = o.defaultRules.copy();
        _apps
          ..clear()
          ..addEntries(o.appRules.entries.map((e) => MapEntry(e.key, e.value.copy())));
        _block = (o.block ?? DeliveryBlock()).copy();
        _katalog = const [];
        _katalogYuklendi = false;
        _dirty = false;
        _loading = false;
      });
      _normYenile();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  static const _havuzAdlari = {'jigsaw': 'Jigsaw', 'cards': 'Kart', 'events': 'Etkinlik'};
  String get _havuzAdi => _havuzAdlari[_pool] ?? _pool;

  DeliveryRuleSet get _cur => _sel.isEmpty ? _def : (_apps[_sel] ?? _def);
  bool get _custom => _sel.isEmpty || _apps.containsKey(_sel);

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 3)));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final t = await DeliveryService.saveRules(_def, _apps, pool: _pool);
      // #385: kurallar ve engel listesi tek Kaydet ile birlikte yayina girer -
      // ikisi ayri kaydedilirse arada bir istek eski engeli gorurdu.
      await DeliveryService.saveBlock(_block, pool: _pool);
      if (!mounted) return;
      _snack('Kaydedildi ve CANLI (${_zaman(t)}) - sayilar yenileniyor');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// #363b: worker yalniz YENI gorsellerin EXIF'ini okur; degistirilen bir
  /// gorsel icin KV ezilmeli. Ad listesi (virgulle) ya da bos = hepsi.
  Future<void> _reindex() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Metadata'yi yeniden oku"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                "Bucket'ta EXIF'i degisen gorseller icin. Dosya adlarini virgulle "
                "yaz (orn. 12.jpg, 340.jpg); bos birakirsan Generic'in TAMAMI "
                'yeniden okunur (~1500 dosya, birkac dakika).',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: c,
              decoration: const InputDecoration(
                  isDense: true, border: OutlineInputBorder(), labelText: 'Dosya adlari'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgec')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oku')),
        ],
      ),
    );
    if (ok != true) return;
    final adlar = c.text.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    setState(() => _saving = true);
    try {
      final r = await DeliveryService.reindex(names: adlar, all: adlar.isEmpty);
      if (!mounted) return;
      final eksik = (r['missing'] as List? ?? const []).length;
      _snack('${r['reindexed']} gorsel yeniden okundu'
          '${eksik > 0 ? ', $eksik bulunamadi' : ''} - manifestler tazelendi');
      await _load();
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _preset(String name) async {
    try {
      final p = await DeliveryService.preset(name);
      if (!mounted) return;
      setState(() {
        final hedef = _cur;
        hedef.values
          ..clear()
          ..addAll(p.values);
        hedef.enabled = true;
        _dirty = true;
      });
      HapticFeedback.selectionClick();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ------------------------------------------------------ #385 normalize
  Future<void> _normYenile() async {
    try {
      final n = await DeliveryService.normalizeStatus();
      if (!mounted) return;
      setState(() => _norm = n);
      final calisan = n.any((x) => x.running);
      _normTimer?.cancel();
      if (calisan) {
        _normTimer = Timer(const Duration(seconds: 5), _normYenile);
      }
    } catch (e) {
      if (mounted) setState(() => _norm = const []);
    }
  }

  NormalizePool? get _normCur {
    // Dagitim havuzu adi ile normalizer havuz adi ayni degil (jigsaw -> gallery-hot).
    const ad = {'jigsaw': 'gallery-hot', 'cards': 'cards', 'events': 'events'};
    for (final p in _norm) {
      if (p.pool == ad[_pool]) return p;
    }
    return null;
  }

  Future<void> _normBaslat({required bool dryRun}) async {
    const ad = {'jigsaw': 'gallery-hot', 'cards': 'cards', 'events': 'events'};
    try {
      await DeliveryService.normalizeRun(ad[_pool]!, dryRun: dryRun);
      _snack(dryRun ? 'Deneme kosusu basladi - yalniz rapor uretir' : 'Normalizasyon basladi');
      await _normYenile();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _normDurdur(String opId) async {
    try {
      await DeliveryService.normalizeCancel(opId);
      _snack('Iptal istendi');
      await _normYenile();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ------------------------------------------------------ #385 engel
  Future<void> _katalogYukle() async {
    setState(() => _katalogYuklendi = true);
    try {
      final k = await DeliveryService.catalog(pool: _pool);
      if (!mounted) return;
      setState(() => _katalog = k);
    } catch (e) {
      if (!mounted) return;
      setState(() => _katalogYuklendi = false);
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  static String _zaman(int ms) {
    if (ms <= 0) return 'hic kaydedilmedi';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String iki(int x) => x.toString().padLeft(2, '0');
    return '${iki(d.day)}.${iki(d.month)} ${iki(d.hour)}:${iki(d.minute)}';
  }

  // ------------------------------------------------------------ gorunum
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: DropdownButton<String>(
            value: _pool,
            items: const [
              DropdownMenuItem(value: 'jigsaw', child: Text('Jigsaw havuzu')),
              DropdownMenuItem(value: 'cards', child: Text('Kartlar')),
              DropdownMenuItem(value: 'events', child: Text('Etkinlikler')),
            ],
            onChanged: _loading || _saving ? null : (value) async {
              if (value == null || value == _pool) return;
              if (_dirty) {
                _snack('Havuz degistirmeden once degisiklikleri kaydet.');
                return;
              }
              setState(() { _pool = value; _sel = ''; });
              await _load();
            },
          ),
          actions: [
            IconButton(
                icon: const Icon(Icons.code),
                tooltip: 'Code Mod',
                onPressed: () => ModeService.setMode(ModeService.code)),
            IconButton(
                icon: const Icon(Icons.auto_awesome),
                tooltip: 'Asset Mod',
                onPressed: () => ModeService.setMode(ModeService.asset)),
            IconButton(
                icon: const Icon(Icons.refresh), tooltip: 'Yenile', onPressed: _load),
            // #363b: bucket'ta EXIF degistiyse worker KV'sini yeniden oku
            IconButton(
                icon: const Icon(Icons.manage_search),
                tooltip: "Metadata'yi yeniden oku (EXIF degistiyse)",
                onPressed: _saving || _pool != 'jigsaw' ? null : _reindex),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(onPressed: _load, child: const Text('Tekrar dene')),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          children: [
                            _ozet(),
                            const SizedBox(height: 10),
                            _normalizeKarti(),
                            const SizedBox(height: 10),
                            _uygulamalar(),
                            const SizedBox(height: 10),
                            _engelKarti(),
                            const SizedBox(height: 10),
                            _kuralBasligi(),
                            if (_custom) ...[
                              _onAyarlar(),
                              if (_pool == 'cards') ...[
                                const SizedBox(height: 6),
                                _kapsam(),
                              ],
                              const SizedBox(height: 6),
                              for (final f in _o!.order) _alan(f),
                            ],
                          ],
                        ),
                      ),
                      _kaydetCubugu(),
                    ],
                  ),
      );

  Widget _ozet() {
    final o = _o!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$_havuzAdi havuzu: ${o.total} gorsel, ${o.tagged} etiketli, ${o.untagged} etiketsiz',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Son kural: ${_zaman(o.updated)}  ·  varsayilan sunulan: '
                '${o.defaultServed ?? '-'} / ${o.defaultTotal ?? '-'}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            const Text(
                'Anahtar KAPALI = o degerdeki gorseller manifestten cikar. Kaydet '
                'anlik canlidir ve artik HER koleksiyon/deste filtrelenir; kuralin '
                'kacirdigi tek bir ogeyi Engelle listesiyle kapatirsin.',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  /// #385 Normalize: havuzdaki her gorseli ayni semayla etiketler (yerel
  /// Ollama), EXIF'i yazar ve worker'in okudugu indeksi yayinlar.
  Widget _normalizeKarti() {
    final n = _normCur;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Normalize - eksik etiketleri uret',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                if (n != null && n.running)
                  TextButton.icon(
                      onPressed: () => _normDurdur(n.opId),
                      icon: const Icon(Icons.stop, size: 16),
                      label: const Text('Durdur'))
                else ...[
                  TextButton(
                      onPressed: _saving ? null : () => _normBaslat(dryRun: true),
                      child: const Text('Deneme')),
                  FilledButton.icon(
                      onPressed: _saving ? null : () => _normBaslat(dryRun: false),
                      icon: const Icon(Icons.auto_fix_high, size: 16),
                      label: const Text('Calistir')),
                ],
              ],
            ),
            if (n == null)
              const Text('Durum alinamadi - sunucu /api/normalize/status yanit vermedi',
                  style: TextStyle(fontSize: 11, color: Colors.orange))
            else ...[
              Text('Indeks: ${n.index}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              if (n.running) ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(
                    value: n.total > 0 ? n.done / n.total : null, minHeight: 4),
                const SizedBox(height: 4),
                Text('${n.done}/${n.total} · ${n.message}',
                    style: const TextStyle(fontSize: 11)),
              ] else
                Text('Son kosu: ${n.summary}', style: const TextStyle(fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }

  /// #385 Engelle: kural bir seyi kacirirsa bu liste tek tek kapatir.
  /// Secili kural seti '' ise GLOBAL (her uygulama), aksi halde o uygulama.
  Widget _engelKarti() {
    final grupListe = _grupListe[_pool]!;
    final ogeListe = _ogeListe[_pool]!;
    final kapsam = _sel.isEmpty ? 'her uygulama (global)' : _sel;
    final adet = _block.count(_sel);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Engelle · $kapsam',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                if (adet > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('$adet engelli',
                        style: TextStyle(fontSize: 10, color: AppColors.error)),
                  ),
                if (!_katalogYuklendi)
                  TextButton(onPressed: _katalogYukle, child: const Text('Listeyi ac')),
              ],
            ),
            Text(
                'Global engel HER uygulamada gecerlidir; bir uygulama secince '
                'yalniz o uygulama icin engellersin. Kurallardan SONRA uygulanir.',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (_katalogYuklendi && _katalog.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Bu havuzda engellenecek oge yok (kova bos).',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            for (final g in _katalog) _engelGrubu(g, grupListe, ogeListe),
          ],
        ),
      ),
    );
  }

  Widget _engelGrubu(DeliveryCatalogItem g, String grupListe, String ogeListe) {
    final grupEngel = _block.isBlocked(_sel, grupListe, g.id.toLowerCase());
    return ExpansionTile(
      key: PageStorageKey('engel-$_pool-${g.id}'),
      dense: true,
      leading: _kapak(g.cover),
      title: Text(g.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      subtitle: Text(
          '${g.count} oge · ${g.tagged}/${g.count} etiketli'
          '${grupEngel ? ' · TAMAMI ENGELLI' : ''}',
          style: TextStyle(fontSize: 10, color: grupEngel ? AppColors.error : Colors.grey)),
      trailing: Switch(
        value: !grupEngel,
        onChanged: (acik) => setState(() {
          _block.toggle(_sel, grupListe, g.id.toLowerCase(), !acik);
          _dirty = true;
        }),
      ),
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final e in g.images)
              _engelOgesi(g, e, ogeListe),
          ],
        ),
      ],
    );
  }

  /// Tek oge: engel kimligi havuza gore kurulur - resim `<koleksiyon>/<dosya>`,
  /// kart `<deste>_<rank>` (katalog zaten kart id'sini verir), host seviyesi `<n>`.
  Widget _engelOgesi(DeliveryCatalogItem g, DeliveryCatalogEntry e, String ogeListe) {
    final id = _pool == 'jigsaw' ? '${g.id.toLowerCase()}/${e.id.toLowerCase()}' : e.id.toLowerCase();
    final engelli = _block.isBlocked(_sel, ogeListe, id);
    return InkWell(
      onTap: () => setState(() {
        _block.toggle(_sel, ogeListe, id, !engelli);
        _dirty = true;
      }),
      child: Container(
        width: 64,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
            border: Border.all(color: engelli ? AppColors.error : Colors.transparent, width: 2),
            borderRadius: BorderRadius.circular(6)),
        child: Column(
          children: [
            Stack(
              children: [
                _kapak(e.cover, size: 56),
                if (engelli)
                  Positioned(
                      right: 0,
                      top: 0,
                      child: Icon(Icons.block, size: 16, color: AppColors.error)),
                if (!e.tagged)
                  const Positioned(
                      left: 0, bottom: 0, child: Icon(Icons.label_off, size: 14, color: Colors.orange)),
              ],
            ),
            Text(e.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _kapak(String? url, {double size = 36}) {
    if (url == null || url.isEmpty) {
      return Container(
          width: size,
          height: size,
          color: Colors.black26,
          child: const Icon(Icons.image_not_supported, size: 14, color: Colors.grey));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
              width: size,
              height: size,
              color: Colors.black26,
              child: const Icon(Icons.broken_image, size: 14, color: Colors.grey))),
    );
  }

  Widget _uygulamalar() {
    final o = _o!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Uygulamalar - dokun = o uygulamanin kuralini duzenle',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: Text('Varsayilan  ${o.defaultServed ?? '-'}/${o.defaultTotal ?? '-'}',
                  style: const TextStyle(fontSize: 11)),
              selected: _sel.isEmpty,
              onSelected: (_) => setState(() => _sel = ''),
            ),
            for (final a in o.apps)
              ChoiceChip(
                avatar: a.custom
                    ? const Icon(Icons.tune, size: 14)
                    : const Icon(Icons.link, size: 14, color: Colors.grey),
                label: Text('${a.name}  ${a.served ?? '-'}/${a.total ?? '-'}',
                    style: const TextStyle(fontSize: 11)),
                selected: _sel == a.package,
                onSelected: (_) => setState(() => _sel = a.package),
              ),
          ],
        ),
      ],
    );
  }

  Widget _kuralBasligi() {
    if (_sel.isEmpty) {
      return const Text('Varsayilan kural - ?app= gondermeyen eski surumler ve ozel kurali olmayan uygulamalar',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold));
    }
    final ad = _o!.apps.where((a) => a.package == _sel).map((a) => a.name).firstOrNull ?? _sel;
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: _apps.containsKey(_sel),
      title: Text('$ad icin ozel kural', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      subtitle: Text(_apps.containsKey(_sel)
          ? 'Kapatirsan varsayilana doner'
          : 'Kapali: varsayilan kural uygulanir. Acinca varsayilanin kopyasiyla baslar.',
          style: const TextStyle(fontSize: 11, color: Colors.grey)),
      onChanged: (v) => setState(() {
        if (v) {
          _apps[_sel] = _def.copy();
        } else {
          _apps.remove(_sel);
        }
        _dirty = true;
      }),
    );
  }

  /// Kart havuzu: bu uygulama hangi KOLEKSIYONLARI gorsun.
  ///
  /// "Yalniz secilenler" acikken liste sabittir - manifest'e sonradan giren bir
  /// koleksiyon bu uygulamaya gecmez. Hot Idle minigame kadinlarini boyle
  /// dondurduk: bugunku desteler kalir, yeni desteler yalniz Hot Card Games'e gider.
  Widget _kapsam() {
    final rs = _cur;
    final o = _o!;
    if (o.collections.isEmpty) return const SizedBox.shrink();
    final secili = rs.scopeOnly ? rs.collections.length : o.collections.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: rs.scopeOnly,
              title: const Text('Yalniz secili koleksiyonlar', style: TextStyle(fontSize: 13)),
              subtitle: Text(
                  rs.scopeOnly
                      ? '$secili/${o.collections.length} koleksiyon - yeni yayinlananlar bu uygulamaya GITMEZ'
                      : 'Kapali: yeni yayinlanan her koleksiyon bu uygulamaya da gider',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              onChanged: (v) => setState(() {
                rs.scopeOnly = v;
                // Acilirken bugunku katalog yakalanir: mevcut desteler kalir,
                // bundan SONRA yayinlananlar disarida kalir.
                if (v && rs.collections.isEmpty) {
                  rs.collections.addAll(o.collections.map((c) => c.id));
                }
                _dirty = true;
              }),
            ),
            if (rs.scopeOnly)
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: [
                  for (final c in o.collections)
                    FilterChip(
                      label: Text('${c.name} (${c.cards})', style: const TextStyle(fontSize: 11)),
                      selected: rs.collections.contains(c.id),
                      onSelected: (on) => setState(() {
                        if (on) {
                          rs.collections.add(c.id);
                        } else {
                          rs.collections.remove(c.id);
                        }
                        _dirty = true;
                      }),
                    ),
                ],
              ),
            if (rs.scopeOnly && rs.collections.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Hicbiri secili degil - bos liste kaydedilmez, kural "hepsi"ne doner.',
                    style: TextStyle(fontSize: 11, color: Colors.orange)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _onAyarlar() {
    final rs = _cur;
    final o = _o!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          children: [
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: rs.enabled,
              title: const Text('Kurallar etkin', style: TextStyle(fontSize: 13)),
              subtitle: const Text('Kapali = bu kural seti hic filtrelemez',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              onChanged: (v) => setState(() {
                rs.enabled = v;
                _dirty = true;
              }),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: rs.untagged,
              title: const Text('Etiketsiz gorselleri sun', style: TextStyle(fontSize: 13)),
              subtitle: Text('${o.untagged} gorselin metadata\'si yok',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              onChanged: (v) => setState(() {
                rs.untagged = v;
                _dirty = true;
              }),
            ),
            const Divider(height: 8),
            Row(
              children: [
                const Text('Hizli:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 6),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final e in o.presets.entries)
                        ActionChip(
                          label: Text(e.value, style: const TextStyle(fontSize: 11)),
                          avatar: e.key == 'siki'
                              ? Icon(Icons.shield, size: 14, color: AppColors.error)
                              : null,
                          onPressed: () => _preset(e.key),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _alan(String f) {
    final o = _o!;
    final rs = _cur;
    final degerler = o.fields[f] ?? const <String, int>{};
    if (degerler.isEmpty) return const SizedBox.shrink();
    final kapali = rs.offCount(f);
    final sirali = degerler.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ExpansionTile(
        key: PageStorageKey('delivery-$f'),
        initiallyExpanded: _acik.contains(f),
        onExpansionChanged: (v) => v ? _acik.add(f) : _acik.remove(f),
        dense: true,
        title: Row(
          children: [
            Expanded(
              child: Text(o.labels[f] ?? f,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            if (kapali > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('$kapali kapali',
                    style: TextStyle(fontSize: 10, color: AppColors.error)),
              ),
          ],
        ),
        subtitle: Text('$f · ${degerler.length} deger',
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        childrenPadding: const EdgeInsets.only(bottom: 6),
        children: [
          for (final e in sirali)
            SwitchListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              value: rs.isOn(f, e.key),
              title: Text(e.key, style: const TextStyle(fontSize: 12)),
              secondary: Text('${e.value}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              onChanged: (v) => setState(() {
                rs.setOn(f, e.key, v);
                _dirty = true;
              }),
            ),
        ],
      ),
    );
  }

  Widget _kaydetCubugu() => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                    _dirty ? 'Kaydedilmemis degisiklik var' : 'Sunucuyla ayni',
                    style: TextStyle(
                        fontSize: 11, color: _dirty ? AppColors.error : Colors.grey)),
              ),
              FilledButton.icon(
                onPressed: _saving || !_dirty ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.publish, size: 16),
                label: const Text('Kaydet ve yayinla'),
              ),
            ],
          ),
        ),
      );
}
