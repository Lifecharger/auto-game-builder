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
        _dirty = false;
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

  DeliveryRuleSet get _cur => _sel.isEmpty ? _def : (_apps[_sel] ?? _def);
  bool get _custom => _sel.isEmpty || _apps.containsKey(_sel);

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 3)));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final t = await DeliveryService.saveRules(_def, _apps, pool: _pool);
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
              DropdownMenuItem(value: 'cards', child: Text('Kart havuzu')),
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
                onPressed: _saving || _pool == 'cards' ? null : _reindex),
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
                            _uygulamalar(),
                            const SizedBox(height: 10),
                            _kuralBasligi(),
                            if (_custom) ...[
                              _onAyarlar(),
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
            Text('${_pool == 'cards' ? 'Kart' : 'Generic'} havuzu: ${o.total} gorsel, ${o.tagged} etiketli, ${o.untagged} etiketsiz',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Son kural: ${_zaman(o.updated)}  ·  varsayilan sunulan: '
                '${o.defaultServed ?? '-'} / ${o.defaultTotal ?? '-'}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            const Text(
                'Anahtar KAPALI = o degerdeki gorseller manifestten cikar. Kaydet '
                'anlik canlidir; bitmis koleksiyonlara dokunulmaz.',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
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
