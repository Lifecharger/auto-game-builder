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

  /// Bir ekseni butun rutbelere yazar + kilitler.
  Future<void> _eksenHepsine(String axis) async {
    final secenekler = _d.mixers[axis] ?? const <String>[];
    if (secenekler.isEmpty) return;
    final secim = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        scrollable: true,
        title: Text('${_d.labels[axis] ?? axis} - hepsine uygula'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                    'Secilen deger 13 rutbeye birden yazilir ve KILITLENIR - '
                    'karistirmada degismez.',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
              for (final v in secenekler)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(v, style: const TextStyle(fontSize: 12)),
                  onTap: () => Navigator.pop(c, v),
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
    await _sarmala(
        () => CardFlowService.setAxis(widget.collection, axis, secim,
            kind: widget.kind),
        '${_d.labels[axis] ?? axis} hepsine yazildi ve kilitlendi');
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
                for (final a in _d.axes) ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: (_d.mixers[a] ?? const [])
                                  .contains(yerel[a])
                              ? yerel[a]
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: _d.labels[a] ?? a,
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            for (final v in _d.mixers[a] ?? const <String>[])
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

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('Sablonlar - ${widget.title}'),
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

  Widget _temaSatiri() => Padding(
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
              child: Text(_d.theme.isEmpty ? 'Tema yok' : _d.theme,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
          ],
        ),
      );

  /// Eksen basliklari - dokununca o eksen 13 rutbeye birden yazilir.
  Widget _eksenSeridi() => SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 6),
                child: Text('hepsine uygula:',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            ),
            for (final a in _d.axes)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Center(
                  child: ActionChip(
                    label: Text(_d.labels[a] ?? a,
                        style: const TextStyle(fontSize: 11)),
                    onPressed: _busy ? null : () => _eksenHepsine(a),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _liste() {
    final rutbeler = _d.templates.keys.toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: rutbeler.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (c, i) {
          final r = rutbeler[i];
          final t = _d.templates[r] ?? const CardTemplate();
          final ozet = [
            for (final a in _d.axes)
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
                  tooltip: 'Bu satiri karistir',
                  icon: const Icon(Icons.casino_outlined, size: 18),
                  onPressed: _busy ? null : () => _satiriKaristir(r),
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
