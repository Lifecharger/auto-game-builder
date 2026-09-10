import 'dart:async';

import 'package:flutter/material.dart';

import '../services/generate_service.dart';
import '../services/mode_service.dart';
import '../theme.dart';

/// Asset Mod - Sira ekrani.
///
/// #299: BUTUN isler (comfy uretimi, karakter yon/animasyon/sprite/hikaye,
/// etiketleme, CBN, muzik) sunucuda TEK sirali kuyruga girer ve burada
/// izlenir - kullanici isi baslattigi ekranda beklemek zorunda degildir.
/// Duzen: "Su an" (calisan is + ilerleme), "Bekleyen" (sira), sonra comfy
/// uretim kartlari (tasima/iptal). Eski sunucuda `/api/queue` yoksa ekran
/// otomatik olarak eski `/api/generate/queue` ucuna duser.
class AssetQueueScreen extends StatefulWidget {
  const AssetQueueScreen({super.key});

  @override
  State<AssetQueueScreen> createState() => _AssetQueueScreenState();
}

class _AssetQueueScreenState extends State<AssetQueueScreen> {
  QueueState? _q;
  /// #299: birlesik sira - `/api/queue` varsa bu doludur.
  UnifiedQueue? _u;
  /// Sunucu birlesik ucu bilmiyorsa bir daha denenmez (eski sunucu).
  bool _unifiedOff = false;
  String? _error;
  Timer? _timer;

  /// #299: is turu -> ikon + ekran adi.
  static const _kinds = <String, (IconData, String)>{
    'comfy': (Icons.auto_awesome, 'Uretim'),
    'character': (Icons.person_outline, 'Karakter'),
    'tag': (Icons.sell_outlined, 'Etiket'),
    'cbn': (Icons.format_paint_outlined, 'CBN'),
    'music': (Icons.music_note, 'Muzik'),
    'cpu': (Icons.memory, 'CPU'),
    'gpu': (Icons.developer_board, 'GPU'),
  };

  static (IconData, String) _kindOf(String k) =>
      _kinds[k] ?? (Icons.play_circle_outline, k.isEmpty ? 'Is' : k);

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// #299: once birlesik sira denenir; sunucu bilmiyorsa eski uca dusulur.
  Future<void> _load({bool silent = false}) async {
    try {
      if (!_unifiedOff) {
        final u = await QueueService.unified();
        if (u != null) {
          if (!mounted) return;
          setState(() {
            _u = u;
            _q = null;
            _error = null;
          });
          return;
        }
        _unifiedOff = true;
      }
      final q = await GenerateService.queue();
      if (!mounted) return;
      setState(() {
        _q = q;
        _u = null;
        _error = null;
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _act(Future<void> Function() f) async {
    try {
      await f();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  /// #352: birlesik siradaki HER satir iptal edilebilir - bekleyen karakter/CBN/
  /// kart op'u da, calisan op da. Sunucu op'un actigi comfy islerini de keser.
  Future<void> _cancelTicket(QueueTicket t, {required bool running}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(running ? 'Calisan isi iptal et' : 'Sıradan cikar'),
        content: Text(t.label.isEmpty ? t.kind : t.label),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgec')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Iptal et')),
        ],
      ),
    );
    if (ok == true) _act(() => QueueService.cancelTicket(t));
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sirayi temizle'),
        content: const Text('Bekleyen tum isler iptal edilsin mi? '
            'Calisan is devam eder.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgec')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Iptal et')),
        ],
      ),
    );
    if (ok == true) _act(GenerateService.clearQueue);
  }

  @override
  Widget build(BuildContext context) {
    final u = _u;
    final q = _q;
    // Eski sunucu yolu: calisan + bekleyen tek liste.
    final eski = q?.all ?? const <GenerateJob>[];
    final bos = u != null ? u.isEmpty : eski.isEmpty;
    // "Bekleyenleri iptal et" yalniz comfy kuyrugunu bosaltir.
    final temizlenebilir =
        u != null ? u.comfyPending.isNotEmpty : eski.length > 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sira'),
        actions: [
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'Code Mod',
            onPressed: () => ModeService.set(false),
          ),
          if (temizlenebilir)
            IconButton(
              icon: const Icon(Icons.playlist_remove),
              tooltip: 'Bekleyenleri iptal et',
              onPressed: _clear,
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _error != null && u == null && q == null
          ? _errorView()
          : RefreshIndicator(
              onRefresh: _load,
              child: bos
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        const Center(
                          child: Column(
                            children: [
                              Icon(Icons.done_all, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('Sira bos'),
                              SizedBox(height: 4),
                              Text('Uretim sekmesinden is ekleyebilirsin',
                                  style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: _rows(u, q),
                    ),
            ),
    );
  }

  /// #299: ekranin govdesi. Birlesik sira varsa "Su an" / "Bekleyen" /
  /// "Uretim isleri"; yoksa eski duz is listesi.
  List<Widget> _rows(UnifiedQueue? u, QueueState? q) {
    final out = <Widget>[];
    if (u != null) {
      out.add(_uHeader(u));
      final r = u.running;
      if (r != null) {
        out.add(_section('Su an'));
        out.add(_ticketCard(r, running: true));
      }
      if (u.waiting.isNotEmpty) {
        out.add(_section('Bekleyen (${u.waiting.length})'));
        for (var i = 0; i < u.waiting.length; i++) {
          out.add(_ticketCard(u.waiting[i], running: false, sira: i + 1));
        }
      }
      if (u.comfyPending.isNotEmpty) {
        out.add(_section('Uretim isleri (${u.comfyPending.length})'));
        for (final j in u.comfyPending) {
          out.add(_card(j, u.comfyPending.length));
        }
      }
      return out;
    }
    if (q != null) {
      out.add(_header(q));
      final items = q.all;
      for (final j in items) {
        out.add(_card(j, items.length - 1));
      }
    }
    return out;
  }

  Widget _section(String baslik) => Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 6),
        child: Text(baslik,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
      );

  /// #299: birlesik sira basligi - toplam is sayisi.
  Widget _uHeader(UnifiedQueue u) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(Icons.circle,
                size: 9,
                color: u.running != null ? AppColors.success : Colors.grey),
            const SizedBox(width: 8),
            const Text('Tek sira - butun isler',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Spacer(),
            Text('${u.depth} is',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  /// #299: kuyruktaki tek is. Calisan iste ilerleme cubugu ve mesaj gorunur,
  /// bekleyende sira numarasi ve bekleme suresi.
  Widget _ticketCard(QueueTicket t, {required bool running, int? sira}) {
    final (ikon, tur) = _kindOf(t.kind);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: running ? AppColors.accent : Colors.transparent,
          width: running ? 1.4 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: running ? AppColors.accent : Colors.white10,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: running
                      ? Icon(ikon, size: 16, color: Colors.white)
                      : Text('${sira ?? ''}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(t.label.isEmpty ? tur : t.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                if (!running) ...[
                  Icon(ikon, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                ],
                Text(tur, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            if (t.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(t.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
            ],
            if (running) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: t.progress, minHeight: 5),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                if (t.total > 0)
                  Text('${t.done}/${t.total}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                const Spacer(),
                if (t.elapsedLabel.isNotEmpty)
                  Text(
                      running
                          ? 'gecen ${t.elapsedLabel}'
                          : 'bekliyor ${t.elapsedLabel}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(width: 6),
                // #352: her bilet iptal edilebilir (op / comfy isi / serit bileti).
                TextButton.icon(
                  onPressed: () => _cancelTicket(t, running: running),
                  icon: Icon(Icons.close, size: 16, color: AppColors.error),
                  label: Text('Iptal',
                      style: TextStyle(fontSize: 12, color: AppColors.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(QueueState q) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(Icons.circle,
                size: 9, color: q.comfyUp ? AppColors.success : AppColors.error),
            const SizedBox(width: 8),
            Text(q.comfyUp ? 'ComfyUI hazir' : 'ComfyUI kapali',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Spacer(),
            Text('${q.depth} is',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _card(GenerateJob j, int pendingCount) {
    final running = j.isRunning;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: running ? AppColors.accent : Colors.transparent,
          width: running ? 1.4 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: running ? AppColors.accent : Colors.white10,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: running
                      ? const Icon(Icons.play_arrow, size: 16, color: Colors.white)
                      : Text('${j.position ?? ''}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(j.task,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                // #299: kategori (karakter isleri icin karakter adi) - hangi
                // isin kime ait oldugu kuyrukta ayirt edilsin.
                if (j.category.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(j.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  running ? (j.node.isEmpty ? 'calisiyor' : j.node) : 'bekliyor',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              j.prompt.isEmpty ? j.combined : j.prompt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            if (running) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: j.progress > 0 ? j.progress / 100 : null,
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 4),
              Text('%${j.progress}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (!running) ...[
                  TextButton.icon(
                    onPressed: (j.position ?? 1) > 1
                        ? () => _act(() => GenerateService.move(j.id, -1))
                        : null,
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    label: const Text('Yukari', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton.icon(
                    onPressed: (j.position ?? 0) < pendingCount
                        ? () => _act(() => GenerateService.move(j.id, 1))
                        : null,
                    icon: const Icon(Icons.arrow_downward, size: 16),
                    label: const Text('Asagi', style: TextStyle(fontSize: 12)),
                  ),
                ],
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _act(() => GenerateService.cancel(j.id)),
                  icon: Icon(Icons.close, size: 16, color: AppColors.error),
                  label: Text('Iptal',
                      style: TextStyle(fontSize: 12, color: AppColors.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
}
