import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/lifecharger_analytics.dart';
import '../services/mode_service.dart';
import '../services/r2_control_service.dart';
import '../theme.dart';

/// #381 Kovalar: R2 kovalarinin kendisi - Dagitim'in yanindaki ikinci sekme.
///
/// Dagitim NE sunulacagini secer; burasi kovada NE VAR sorusunun cevabi:
/// gezinme, basliklar, silme / takedown (ESKI ikizden de siler), sunucu tarafi
/// kopya, onbellek basligi onarimi ve iki fark gorunumu.
///
/// Sayacli hat kurali: onizleme YALNIZ sunucunun "bu satir onizlenebilir"
/// dedigi kucuk duragan gorseller icin ve yalniz satir ekranda gorunurken
/// istenir. Video, hareketli webp ve 2 MB ustu nesne indirilmez - ikon + boyut.
class BucketsScreen extends StatefulWidget {
  const BucketsScreen({super.key});

  @override
  State<BucketsScreen> createState() => _BucketsScreenState();
}

class _BucketsScreenState extends State<BucketsScreen> {
  R2Registry? _reg;
  bool _loading = true;
  String? _error;

  /// Acik kova ve klasor. Kova bos = kova listesi.
  String _bucket = '';
  String _prefix = '';
  R2Listing? _listing;
  bool _listLoading = false;

  final Set<String> _selected = {};
  List<R2Op> _ops = const [];

  @override
  void initState() {
    super.initState();
    Analytics.log('feature_use', {'feature': 'buckets'});
    _loadRegistry();
  }

  R2Bucket? get _info {
    for (final b in _reg?.buckets ?? const <R2Bucket>[]) {
      if (b.name == _bucket) return b;
    }
    return null;
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 4)));

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _loadRegistry({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await R2ControlService.buckets(refresh: refresh);
      if (!mounted) return;
      setState(() {
        _reg = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _clean(e);
        _loading = false;
      });
    }
  }

  Future<void> _open(String bucket, String prefix) async {
    setState(() {
      _bucket = bucket;
      _prefix = prefix;
      _selected.clear();
      _listLoading = true;
      _listing = null;
      _error = null;
    });
    try {
      final l = await R2ControlService.list(bucket, prefix: prefix);
      if (!mounted) return;
      setState(() {
        _listing = l;
        _listLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _clean(e);
        _listLoading = false;
      });
    }
  }

  void _up() {
    if (_prefix.isEmpty) {
      setState(() {
        _bucket = '';
        _listing = null;
        _selected.clear();
      });
      return;
    }
    final parts = _prefix.split('/')..removeWhere((p) => p.isEmpty);
    parts.removeLast();
    _open(_bucket, parts.isEmpty ? '' : '${parts.join('/')}/');
  }

  // ---------------------------------------------------------------- eylemler
  Future<void> _refreshCount(String bucket) async {
    _snack('$bucket sayiliyor...');
    try {
      final r = await R2ControlService.buckets(refresh: true, bucket: bucket);
      if (!mounted) return;
      setState(() => _reg = r);
    } catch (e) {
      if (mounted) _snack(_clean(e));
    }
  }

  /// Yazili onay: kullanici kova adini AYNEN yazmadan hicbir sey silinmez.
  /// Pencere once sunucudan plani alir ve hangi kovada hangi anahtarlarin
  /// gidecegini gosterir.
  Future<void> _deleteSelected({required bool takedown}) async {
    final keys = _selected.toList()..sort();
    if (keys.isEmpty) return;
    R2DeletePlan plan;
    try {
      plan = await R2ControlService.deletePlan(_bucket, keys);
    } catch (e) {
      _snack(_clean(e));
      return;
    }
    if (!mounted) return;
    final c = TextEditingController();
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          icon: Icon(takedown ? Icons.gavel : Icons.delete_forever,
              color: AppColors.error, size: 34),
          title: Text(takedown ? 'Takedown (yeni + eski)' : 'Kalici olarak sil'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text('${plan.totalKeys} nesne silinecek. GERI ALINAMAZ.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.error)),
                const SizedBox(height: 8),
                _planBlok(plan.bucket, plan.keys),
                for (final t in plan.twins) _planBlok(t.bucket, t.keys, legacy: true),
                if (takedown && plan.unmapped.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                        '${plan.unmapped.length} anahtarin eski ikizde karsiligi yok - '
                        'yalniz bu kovadan silinir.',
                        style: const TextStyle(fontSize: 11, color: Colors.orange)),
                  ),
                const SizedBox(height: 12),
                Text("Onaylamak icin kova adini yaz: $_bucket",
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: c,
                  autocorrect: false,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  onChanged: (_) => setLocal(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgec')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: c.text == _bucket ? () => Navigator.pop(ctx, true) : null,
              child: Text(takedown ? 'Takedown' : 'Sil'),
            ),
          ],
        ),
      ),
    );
    if (onay != true) return;
    Analytics.log('feature_use', {'feature': takedown ? 'buckets_takedown' : 'buckets_delete'});
    try {
      final r = await R2ControlService.delete(_bucket, keys,
          takedown: takedown, confirm: c.text);
      if (!mounted) return;
      final ikiz = (r['twins'] as List? ?? const [])
          .whereType<Map>()
          .fold<int>(0, (a, t) => a + ((t['deleted'] as num?)?.toInt() ?? 0));
      _snack('${r['deleted']} nesne silindi'
          '${takedown ? ', eski ikizden $ikiz' : ''}');
      await _open(_bucket, _prefix);
    } catch (e) {
      if (mounted) _snack(_clean(e));
    }
  }

  Widget _planBlok(String bucket, List<String> keys, {bool legacy = false}) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(legacy ? Icons.history : Icons.folder_delete,
                    size: 14, color: legacy ? Colors.orange : AppColors.error),
                const SizedBox(width: 4),
                Text('$bucket  (${keys.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            for (final k in keys.take(12))
              Text('  $k', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (keys.length > 12)
              Text('  ... +${keys.length - 12}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      );

  Future<void> _copyTo() async {
    final hedefler = (_reg?.buckets ?? const <R2Bucket>[])
        .where((b) => !b.isPrivate)
        .map((b) => b.name)
        .toList();
    var hedef = hedefler.isEmpty ? '' : hedefler.first;
    final onek = TextEditingController(text: _prefix);
    final tek = _selected.length == 1 ? _selected.first : '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Kopyala'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  tek.isNotEmpty
                      ? 'Kaynak: $_bucket/$tek'
                      : 'Kaynak agac: $_bucket/${_prefix.isEmpty ? "(tum kova)" : _prefix}',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              const Text('Kopya Cloudflare icinde calisir - telefondan bayt gecmez.',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: hedef.isEmpty ? null : hedef,
                isExpanded: true,
                items: [for (final h in hedefler) DropdownMenuItem(value: h, child: Text(h))],
                onChanged: (v) => setLocal(() => hedef = v ?? hedef),
              ),
              TextField(
                controller: onek,
                decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    labelText: tek.isNotEmpty ? 'Hedef anahtar' : 'Hedef onek'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgec')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kopyala')),
          ],
        ),
      ),
    );
    if (ok != true || hedef.isEmpty) return;
    Analytics.log('feature_use', {'feature': 'buckets_copy'});
    try {
      final op = await R2ControlService.copy(
        srcBucket: _bucket,
        dstBucket: hedef,
        srcKey: tek,
        dstKey: tek.isNotEmpty ? onek.text.trim() : '',
        srcPrefix: tek.isNotEmpty ? '' : _prefix,
        dstPrefix: tek.isNotEmpty ? '' : onek.text.trim(),
      );
      if (!mounted) return;
      _snack('Kopya basladi ($op)');
      _showOps();
    } catch (e) {
      if (mounted) _snack(_clean(e));
    }
  }

  Future<void> _fixHeaders() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Basliklari duzelt'),
        content: Text(
            '$_bucket/${_prefix.isEmpty ? "(tum kova)" : _prefix} altindaki nesnelerin '
            'Cache-Control basligi denetlenir; standarttan sapan nesne yerinde '
            'yeniden yazilir (Content-Type korunur). Bayt inmez.\n\n'
            'Bilerek degisken birakilan onekler atlanir.',
            style: const TextStyle(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgec')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Basla')),
        ],
      ),
    );
    if (ok != true) return;
    Analytics.log('feature_use', {'feature': 'buckets_fix_headers'});
    try {
      final op = await R2ControlService.fixHeaders(_bucket, _prefix);
      if (!mounted) return;
      _snack('Baslik onarimi basladi ($op)');
      _showOps();
    } catch (e) {
      if (mounted) _snack(_clean(e));
    }
  }

  // ------------------------------------------------------------------ sheetler
  Future<void> _showObject(R2Object o) async {
    Analytics.log('feature_use', {'feature': 'buckets_object'});
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ObjectSheet(bucket: _bucket, object: o, onSnack: _snack),
    );
  }

  Future<void> _showOps() async {
    await _pollOps();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  const Expanded(
                      child: Text('Islemler',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: () async {
                      await _pollOps();
                      setLocal(() {});
                    },
                  ),
                ],
              ),
              if (_ops.isEmpty)
                const Text('Henuz islem yok', style: TextStyle(fontSize: 12, color: Colors.grey)),
              for (final o in _ops)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${o.kind}  ${o.done}/${o.total}',
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: o.running ? o.progress : 1),
                      Text(
                          '${o.status}  ·  ok ${o.ok}  ·  hata ${o.failed}'
                          '${o.message.isEmpty ? '' : '  ·  ${o.message}'}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  trailing: o.running
                      ? IconButton(
                          icon: const Icon(Icons.cancel, size: 18),
                          onPressed: () async {
                            await R2ControlService.cancelOp(o.id);
                            await _pollOps();
                            setLocal(() {});
                          },
                        )
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pollOps() async {
    try {
      final o = await R2ControlService.ops();
      if (mounted) setState(() => _ops = o);
    } catch (e) {
      if (mounted) _snack(_clean(e));
    }
  }

  Future<void> _showDiff({required bool twin}) async {
    Analytics.log('feature_use', {'feature': twin ? 'buckets_twin_diff' : 'buckets_diff'});
    _snack(twin ? 'Ikiz farki hesaplaniyor...' : 'Yerel fark hesaplaniyor...');
    Map<String, dynamic> d;
    try {
      d = twin
          ? await R2ControlService.twinDiff(_bucket)
          : await R2ControlService.diff(rating: _bucket == 'gallery-family' ? 'kid' : 'hot');
    } catch (e) {
      if (mounted) _snack(_clean(e));
      return;
    }
    if (!mounted) return;
    List<String> liste(String k) =>
        (d[k] as List? ?? const []).map((e) => e is Map ? '${e['key']}' : '$e').toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(12),
          children: [
            Text(twin ? '${d['bucket']} <-> ${d['twin']} (eski ikiz)' : 'Yerel Pushed <-> ${d['bucket']}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _diffBlok(twin ? 'Eski ikizde eksik' : 'Kovada eksik',
                liste(twin ? 'missing_in_legacy' : 'missing_in_bucket'), AppColors.error),
            _diffBlok(twin ? 'Yalniz eski ikizde' : 'Yalniz kovada',
                liste(twin ? 'only_in_legacy' : 'missing_locally'), Colors.orange),
            _diffBlok('Boyut farki', liste('size_mismatch'), Colors.orange),
            if (twin)
              _diffBlok('Eslesmeyen (kural yok)', liste('unmapped'), Colors.grey)
            else
              // Gri thumb'lar kovada uretilir, yerelde hic olmaz - eksik degil.
              _diffBlok('Kovada uretilen (thumbs)', liste('derived_in_bucket'), Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _diffBlok(String baslik, List<String> satirlar, Color renk) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$baslik: ${satirlar.length}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: renk)),
            for (final s in satirlar.take(60))
              Text(s, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (satirlar.length > 60)
              Text('... +${satirlar.length - 60}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      );

  // ------------------------------------------------------------------ gorunum
  @override
  Widget build(BuildContext context) {
    final info = _info;
    return PopScope(
      canPop: _bucket.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _up();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _bucket.isEmpty
              ? null
              : IconButton(icon: const Icon(Icons.arrow_back), onPressed: _up),
          title: Text(_bucket.isEmpty ? 'Kovalar' : _bucket,
              style: const TextStyle(fontSize: 17)),
          actions: [
            IconButton(
                icon: const Icon(Icons.local_shipping_outlined),
                tooltip: 'Dagitim',
                onPressed: () => ModeService.setMode(ModeService.delivery)),
            IconButton(
              icon: const Icon(Icons.playlist_play),
              tooltip: 'Islemler',
              onPressed: _showOps,
            ),
            if (_bucket.isNotEmpty && info != null) ...[
              IconButton(
                icon: const Icon(Icons.cleaning_services),
                tooltip: 'Bu klasorun basliklarini duzelt',
                onPressed: _fixHeaders,
              ),
              PopupMenuButton<String>(
                tooltip: 'Farklar',
                icon: const Icon(Icons.compare_arrows),
                onSelected: (v) => _showDiff(twin: v == 'twin'),
                itemBuilder: (_) => [
                  if (info.twin.isNotEmpty)
                    const PopupMenuItem(value: 'twin', child: Text('Eski ikiz farki')),
                  if (_bucket == 'gallery-hot' || _bucket == 'gallery-family')
                    const PopupMenuItem(value: 'local', child: Text('Yerel Pushed farki')),
                ],
              ),
            ],
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Yenile',
              onPressed: _bucket.isEmpty
                  ? () => _loadRegistry()
                  : () => _open(_bucket, _prefix),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _listing == null && _bucket.isEmpty
                ? _hata()
                : (_bucket.isEmpty ? _kovaListesi() : _gezgin()),
        bottomNavigationBar: _selected.isEmpty ? null : _secimCubugu(),
      ),
    );
  }

  Widget _hata() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: () => _bucket.isEmpty ? _loadRegistry() : _open(_bucket, _prefix),
                  child: const Text('Tekrar dene')),
            ],
          ),
        ),
      );

  Widget _kovaListesi() {
    final reg = _reg;
    if (reg == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      children: [
        const Text(
            'Kova = icerigin adiyla anilan depo. Sayilar istek uzerine hesaplanir '
            '(yalniz listeleme, bayt inmez).',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 8),
        for (final b in reg.buckets) _kovaKarti(b, reg.legacyRetiresOn),
      ],
    );
  }

  Widget _kovaKarti(R2Bucket b, String emeklilik) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: b.isPrivate ? null : () => _open(b.name, ''),
          title: Row(
            children: [
              Flexible(
                child: Text(b.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              _rozet(b.isLegacy ? 'ESKI' : (b.isPrivate ? 'ozel' : 'icerik'),
                  b.isLegacy ? AppColors.error : (b.isPrivate ? Colors.grey : AppColors.success)),
              if (b.isLegacy && emeklilik.isNotEmpty) ...[
                const SizedBox(width: 4),
                _rozet(emeklilik, Colors.orange),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.holds, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(
                  '${b.objects == null ? 'sayilmadi' : '${b.objects} nesne'}'
                  '  ·  ${r2Size(b.bytes)}'
                  '${b.twin.isEmpty ? '' : '  ·  ikiz: ${b.twin}'}',
                  style: const TextStyle(fontSize: 11)),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.calculate_outlined, size: 20),
            tooltip: 'Say',
            onPressed: () => _refreshCount(b.name),
          ),
        ),
      );

  Widget _rozet(String metin, Color renk) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
        child: Text(metin, style: TextStyle(fontSize: 10, color: renk)),
      );

  Widget _gezgin() {
    if (_listLoading) return const Center(child: CircularProgressIndicator());
    final l = _listing;
    if (l == null) return _hata();
    final satirlar = l.folders.length + l.objects.length;
    return Column(
      children: [
        _izYolu(),
        Expanded(
          child: satirlar == 0
              ? const Center(
                  child: Text('Bu klasor bos', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: satirlar + (l.truncated ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i < l.folders.length) return _klasorSatiri(l.folders[i]);
                    if (i < satirlar) return _nesneSatiri(l.objects[i - l.folders.length]);
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Liste kesildi - daha dar bir klasore gir',
                          style: TextStyle(fontSize: 11, color: Colors.orange)),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _izYolu() {
    final parts = _prefix.split('/')..removeWhere((p) => p.isEmpty);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkWell(
            onTap: () => _open(_bucket, ''),
            child: Text(_bucket,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          for (var i = 0; i < parts.length; i++) ...[
            const Text(' / ', style: TextStyle(fontSize: 12, color: Colors.grey)),
            InkWell(
              onTap: () => _open(_bucket, '${parts.sublist(0, i + 1).join('/')}/'),
              child: Text(parts[i], style: const TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _klasorSatiri(R2Folder f) => ListTile(
        dense: true,
        leading: const Icon(Icons.folder, size: 26),
        title: Text(f.name, style: const TextStyle(fontSize: 13)),
        onTap: () => _open(_bucket, f.prefix),
      );

  Widget _nesneSatiri(R2Object o) {
    final secili = _selected.contains(o.key);
    return ListTile(
      dense: true,
      selected: secili,
      leading: SizedBox(
        width: 40,
        height: 40,
        child: _onizleme(o),
      ),
      title: Text(o.name, style: const TextStyle(fontSize: 13)),
      subtitle: Text(r2Size(o.size), style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: Checkbox(
        value: secili,
        onChanged: (v) => setState(() {
          if (v == true) {
            _selected.add(o.key);
          } else {
            _selected.remove(o.key);
          }
        }),
      ),
      onTap: () => _selected.isEmpty
          ? _showObject(o)
          : setState(() => secili ? _selected.remove(o.key) : _selected.add(o.key)),
      onLongPress: () => setState(() => _selected.add(o.key)),
    );
  }

  /// Onizleme yalniz sunucunun onayladigi satirlar icin istenir; digerlerinde
  /// tur ikonu cizilir ve AG ISTEGI ACILMAZ.
  Widget _onizleme(R2Object o) {
    if (!o.preview) return Icon(_ikon(o.name), size: 24, color: Colors.grey);
    return Image.network(
      R2ControlService.thumbUrl(_bucket, o.key),
      headers: R2ControlService.thumbHeaders,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Icon(_ikon(o.name), size: 24, color: Colors.grey),
    );
  }

  static IconData _ikon(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.mp4') || n.endsWith('.mov') || n.endsWith('.webm')) {
      return Icons.movie_outlined;
    }
    if (n.endsWith('.mp3') || n.endsWith('.wav')) return Icons.music_note;
    if (n.endsWith('.json')) return Icons.data_object;
    if (n.endsWith('.webp')) return Icons.animation;
    return Icons.insert_drive_file_outlined;
  }

  Widget _secimCubugu() => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text('${_selected.length} secili',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Secimi birak',
                onPressed: () => setState(() => _selected.clear()),
              ),
              IconButton(
                icon: const Icon(Icons.copy_all),
                tooltip: 'Kopyala',
                onPressed: _copyTo,
              ),
              IconButton(
                icon: Icon(Icons.gavel, color: AppColors.error),
                tooltip: 'Takedown (eski ikizden de sil)',
                onPressed: () => _deleteSelected(takedown: true),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => _deleteSelected(takedown: false),
                icon: const Icon(Icons.delete_forever, size: 16),
                label: const Text('Sil'),
              ),
            ],
          ),
        ),
      );
}

/// Nesne ayrinti sayfasi: basliklar, onbellek uygunlugu, ikiz anahtari,
/// genel adresi kopyala / ac.
class _ObjectSheet extends StatefulWidget {
  const _ObjectSheet({required this.bucket, required this.object, required this.onSnack});
  final String bucket;
  final R2Object object;
  final void Function(String) onSnack;

  @override
  State<_ObjectSheet> createState() => _ObjectSheetState();
}

class _ObjectSheetState extends State<_ObjectSheet> {
  R2Head? _h;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final h = await R2ControlService.head(widget.bucket, widget.object.key);
      if (mounted) setState(() => _h = h);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _h;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.object.key,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_error != null)
              Text(_error!, style: TextStyle(fontSize: 12, color: AppColors.error))
            else if (h == null)
              const Center(child: Padding(
                  padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
            else ...[
              _satir('Boyut', r2Size(h.size)),
              _satir('Tur', h.contentType),
              _satir('Degisiklik', h.lastModified),
              _satir('ETag', h.etag),
              _satir('Cache-Control', h.cacheControl.isEmpty ? '(yok)' : h.cacheControl),
              Row(
                children: [
                  Icon(h.headerOk ? Icons.check_circle : Icons.warning,
                      size: 14, color: h.headerOk ? AppColors.success : Colors.orange),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                        h.headerKind == 'mutable'
                            ? 'Bilerek degisken - standart aranmaz'
                            : (h.headerOk
                                ? 'Onbellek standardina uygun (${h.headerKind})'
                                : 'Standart: ${h.headerExpected}'),
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                ],
              ),
              if (h.twinKey.isNotEmpty)
                _satir('Eski ikiz', '${h.twinBucket}/${h.twinKey}'),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (h.url.isNotEmpty) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: h.url));
                        widget.onSnack('Adres kopyalandi');
                      },
                      icon: const Icon(Icons.link, size: 16),
                      label: const Text('Adresi kopyala'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse(h.url),
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Ac'),
                    ),
                  ] else
                    const Text('Bu kova ozel - genel adresi yok',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _satir(String ad, String deger) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(ad, style: const TextStyle(fontSize: 11, color: Colors.grey))),
            Expanded(child: Text(deger, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );
}
