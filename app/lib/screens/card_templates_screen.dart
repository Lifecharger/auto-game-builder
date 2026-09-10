import 'package:flutter/material.dart';

import '../services/card_flow_service.dart';
import '../theme.dart';

/// #347: Koleksiyon kartinin sablon ekrani.
///
/// LLM prompt yazarinin yerini alir. Katmanlar:
///   Pozitif 1  koleksiyonun temasi (ustte, salt okunur - koleksiyon ekraninda duzenlenir)
///   Pozitif 2  guzellik sablonu (sunucuda sabit)
///   Pozitif 3  BU EKRAN - her rutbenin 9 ekseni + manuel metni
///
/// Her eksen ayri ayri kilitlenir: kilitli eksen "Karistir" ile degismez.
/// Bir ekseni 13 rutbeye birden yazmak icin eksen basligindaki "hepsine" dugmesi.
class CardTemplatesScreen extends StatefulWidget {
  const CardTemplatesScreen({
    super.key,
    required this.collection,
    required this.title,
    this.kind = 'card',
  });

  final String collection;
  final String title;
  final String kind;

  @override
  State<CardTemplatesScreen> createState() => _CardTemplatesScreenState();
}

class _CardTemplatesScreenState extends State<CardTemplatesScreen> {
  CardTemplates _d = const CardTemplates();
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await CardTemplatesLoader.load(widget.collection, widget.kind);
      if (!mounted) return;
      setState(() {
        _d = d;
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

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));

  Future<void> _sarmala(Future<void> Function() f, String ad) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
      await _load();
      if (mounted) _snack(ad);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Tum kilitsiz eksenleri, tum rutbelerde karistirir.
  Future<void> _hepsiniKaristir() => _sarmala(
      () => CardFlowService.rollTemplates(widget.collection, kind: widget.kind),
      'Karistirildi - kilitli eksenlere dokunulmadi');

  /// Tek rutbenin kilitsiz eksenlerini karistirir.
  Future<void> _satiriKaristir(String rank) => _sarmala(
      () => CardFlowService.rollTemplates(widget.collection,
          kind: widget.kind, ranks: [rank]),
      '$rank karistirildi');

  /// Bir ekseni butun yuvalara yazar + kilitler. Deger ACILIR LISTEDEN secilir.
  Future<void> _eksenHepsine(String axis) async {
    final arka = _d.backAxes.contains(axis);
    final secenekler =
        (arka ? _d.backMixers[axis] : _d.mixers[axis]) ?? const <String>[];
    if (secenekler.isEmpty) return;
    String? secim;
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: Text(
              '${(arka ? _d.backLabels[axis] : _d.labels[axis]) ?? axis} - hepsine'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    arka
                        ? 'Kart arkasina yazilir ve KILITLENIR.'
                        : '13 kart + 2 jokere birden yazilir ve KILITLENIR - '
                            'karistirmada degismez.',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: secim,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      labelText: 'Deger'),
                  items: [
                    for (final v in secenekler)
                      DropdownMenuItem(
                          value: v,
                          child: Text(v,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) => setLocal(() => secim = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Vazgec')),
            FilledButton(
                onPressed: secim == null ? null : () => Navigator.pop(c, true),
                child: const Text('Uygula')),
          ],
        ),
      ),
    );
    if (onay != true || secim == null) return;
    await _sarmala(
        () => CardFlowService.setAxis(widget.collection, axis, secim!,
            kind: widget.kind),
        'Hepsine yazildi ve kilitlendi');
  }

  Future<void> _satirDuzenle(String rank) async {
    final t = _d.templates[rank] ?? const CardTemplate();
    final yerel = Map<String, String>.from(t.axes);
    final kilit = Set<String>.from(t.locked);
    final manuelC = TextEditingController(text: t.manual);
    final kaydet = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          scrollable: true,
          title: Text('$rank sablonu'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final a in _d.axesFor(rank)) ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: (_d.mixersFor(rank)[a] ?? const [])
                                  .contains(yerel[a])
                              ? yerel[a]
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: _d.labelsFor(rank)[a] ?? a,
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            for (final v in _d.mixersFor(rank)[a] ?? const <String>[])
                              DropdownMenuItem(
                                  value: v,
                                  child: Text(v,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12))),
                          ],
                          onChanged: (v) =>
                              setLocal(() => yerel[a] = v ?? ''),
                        ),
                      ),
                      IconButton(
                        tooltip: kilit.contains(a) ? 'Kilitli' : 'Kilitle',
                        icon: Icon(
                            kilit.contains(a)
                                ? Icons.lock
                                : Icons.lock_open_outlined,
                            size: 18,
                            color: kilit.contains(a)
                                ? AppColors.accent
                                : Colors.grey),
                        onPressed: () => setLocal(() => kilit.contains(a)
                            ? kilit.remove(a)
                            : kilit.add(a)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: manuelC,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Manuel ek (serbest metin)',
                    hintText: 'orn. holding a golden card fan',
                    helperText: 'Sablonun sonuna eklenir - karistirma silmez',
                    helperMaxLines: 2,
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Vazgec')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (kaydet != true) return;
    await _sarmala(
        () => CardFlowService.setTemplate(
            widget.collection,
            rank,
            CardTemplate(
                axes: yerel, locked: kilit, manual: manuelC.text.trim()),
            kind: widget.kind),
        '$rank kaydedildi');
  }

  /// Tek yuvayi uretime yollar - sablon degistikten sonra sonucu hemen gormek
  /// icin; koleksiyon ekranina donmek gerekmez.
  Future<void> _yuvayiUret(String slot) async {
    try {
      await CardFlowService.stills(
          collection: widget.collection, ranks: [slot], kind: widget.kind, n: 1);
      if (mounted) _snack('$slot kuyruga girdi');
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('Koleksiyon Karti - ${widget.title}'),
          actions: [
            IconButton(
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _busy ? null : _hepsiniKaristir,
          icon: const Icon(Icons.casino),
          label: const Text('Karistir'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ))
                : Column(
                    children: [
                      if (_busy) const LinearProgressIndicator(minHeight: 2),
                      _temaSatiri(),
                      _eksenSeridi(),
                      const Divider(height: 1),
                      Expanded(child: _liste()),
                    ],
                  ),
      );

  /// P1 - koleksiyonun temasi. Dokununca hazir kart listesinden secilir ya da
  /// elle yazilir; kart kimligi bu ekranin icinde kalir (#348).
  Widget _temaSatiri() => InkWell(
        onTap: _busy ? null : _temaDuzenle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('P1',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_d.theme.isEmpty ? 'Tema yok - dokun ve yaz' : _d.theme,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        color: _d.theme.isEmpty ? AppColors.error : Colors.grey)),
              ),
              const Icon(Icons.edit, size: 14, color: Colors.grey),
            ],
          ),
        ),
      );

  Future<void> _temaDuzenle() async {
    final c = TextEditingController(text: _d.theme);
    final sablonlar = await CardFlowService.presets(kind: widget.kind);
    if (!mounted) return;
    String? secili;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          scrollable: true,
          title: const Text('Tema (P1)'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sablonlar.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: secili,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        labelText: 'Hazir kart'),
                    items: [
                      for (final sb in sablonlar)
                        DropdownMenuItem(
                            value: sb.id,
                            child: Text(sb.label,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12))),
                    ],
                    onChanged: (v) => setLocal(() {
                      secili = v;
                      final sb = sablonlar.firstWhere((x) => x.id == v,
                          orElse: () => const CardPreset(id: '', name: ''));
                      if (sb.theme.isNotEmpty) c.text = sb.theme;
                    }),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: c,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Tema',
                    helperText: 'kimlik + STRICT PALETTE + Signature pieces',
                    helperMaxLines: 2,
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgec')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final t = c.text.trim();
    if (t.isEmpty) {
      _snack('Tema bos olamaz');
      return;
    }
    await _sarmala(
        () => CardFlowService.setTheme(widget.collection, t, kind: widget.kind),
        'Tema kaydedildi');
  }

  /// #348: eksen secici artik CIP degil ACILIR LISTE - "hepsine uygula".
  Widget _eksenSeridi() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
        child: Row(
          children: [
            const Text('Hepsine uygula:',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: null,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  hintText: 'eksen sec',
                ),
                items: [
                  for (final a in _d.axes)
                    DropdownMenuItem(
                        value: a,
                        child: Text(_d.labels[a] ?? a,
                            style: const TextStyle(fontSize: 12))),
                  for (final a in _d.backAxes)
                    DropdownMenuItem(
                        value: a,
                        child: Text('${_d.backLabels[a] ?? a}  (arka)',
                            style: const TextStyle(fontSize: 12))),
                ],
                onChanged: _busy ? null : (a) => a == null ? null : _eksenHepsine(a),
              ),
            ),
          ],
        ),
      );

  Widget _liste() {
    final rutbeler = _d.slots.isNotEmpty
        ? _d.slots
        : _d.templates.keys.toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: rutbeler.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (c, i) {
          final r = rutbeler[i];
          final t = _d.templates[r] ?? const CardTemplate();
          final ozet = [
            for (final a in _d.axesFor(r))
              if ((t.axes[a] ?? '').isNotEmpty) t.axes[a]!
          ].join(' · ');
          return ListTile(
            dense: true,
            leading: CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                child: Text(r, style: const TextStyle(fontSize: 11))),
            title: Text(ozet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11)),
            subtitle: t.manual.isEmpty
                ? (t.locked.isEmpty
                    ? null
                    : Text('${t.locked.length} eksen kilitli',
                        style: const TextStyle(fontSize: 10, color: Colors.grey)))
                : Text('+ ${t.manual}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: AppColors.accent)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (t.locked.isNotEmpty)
                  Icon(Icons.lock, size: 14, color: AppColors.accent),
                IconButton(
                  tooltip: 'Bu yuvayi karistir',
                  icon: const Icon(Icons.casino_outlined, size: 18),
                  onPressed: _busy ? null : () => _satiriKaristir(r),
                ),
                IconButton(
                  tooltip: 'Bu yuvayi uret',
                  icon: const Icon(Icons.play_arrow, size: 18),
                  onPressed: _busy ? null : () => _yuvayiUret(r),
                ),
              ],
            ),
            onTap: _busy ? null : () => _satirDuzenle(r),
          );
        },
      ),
    );
  }
}

/// Servisteki cagriyi ekrandan ayirir - test/mock kolayligi icin.
class CardTemplatesLoader {
  static Future<CardTemplates> load(String collection, String kind) =>
      CardFlowService.templates(collection, kind: kind);
}
