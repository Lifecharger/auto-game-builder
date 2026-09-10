import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/card_flow_service.dart';
import '../services/jigsaw_flow_service.dart' show FlowOp;
import '../services/mode_service.dart';
import '../theme.dart';
import '../widgets/bottom_inset.dart';
import '../widgets/network_video.dart';
import 'character_flow_screen.dart' show errorView;

/// Asset Mod - Kart hatti (#323, design/kart_modu.md).
///
/// Hot Card Games koleksiyon kartlari. Jigsaw/CBN'deki 2-3-4 akisi burada
/// YOKTUR; dokuman §0'daki DORT ASAMA vardir ve her rutbe bu dortten gecer:
///   1 Still   koleksiyon acilinca 13 (+2 joker) rutbe icin 1'er still
///   2 Video   still'den LTX-2.5 i2v 6 sn, jest secimli
///   3 WebP    SAM3 kesim + 12x6 sprite sheet + thumb
///   4 Push    manifest bu adimin ICINDE uretilir; onayli, GERI ALINAMAZ
///
/// Tur secimi iki secenektir: Normal (koleksiyon = 13 rutbe izgarasi) ve
/// Krupiye (rutbesiz TEK oge listesi). Avatar turu YOKTUR.
///
/// Uzun isler sunucuda kosar, `/api/card/flow/op/{id}` ile izlenir.

// ------------------------------------------------------------------ ortak

/// Dort asamanin rengi: bos / still / video / webp / push.
Color cardStageColor(int stage) => switch (stage) {
      4 => Colors.green.shade600,
      3 => Colors.blue.shade600,
      2 => Colors.orange.shade700,
      1 => Colors.blueGrey.shade400,
      _ => Colors.white10,
    };

/// Rozetin ustundeki kisa asama adi (ipucu metni).
String cardStageName(int stage) => switch (stage) {
      4 => 'push edilmis',
      3 => 'webp hazir',
      2 => 'video hazir',
      1 => 'still hazir',
      _ => 'bos',
    };

/// Bir rutbenin kucuk durum rozeti - liste kartinda 13 (+2) tane yan yana.
Widget cardRankBadge(String rank, CardRankState s, {double size = 9}) => Tooltip(
      message: '$rank - ${cardStageName(s.stage)}'
          '${s.warn ? " (kontrol)" : ""}',
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        decoration: BoxDecoration(
          color: cardStageColor(s.stage),
          borderRadius: BorderRadius.circular(4),
          border: s.warn
              ? Border.all(color: AppColors.error, width: 1)
              : null,
        ),
        child: Text(rank,
            style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.bold,
                color: s.stage == 0 ? Colors.grey : Colors.white)),
      ),
    );

/// Dort asamanin tek satirlik ozeti - krupiye kartinda ve kart detayinda.
Widget cardStageChips(CardRankState s) => Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < CardFlowService.stageTitles.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: s.stage > i ? cardStageColor(i + 1) : Colors.white10,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(CardFlowService.stageTitles[i],
                style: TextStyle(
                    fontSize: 9,
                    color: s.stage > i ? Colors.white : Colors.grey)),
          ),
      ],
    );

/// Seffaf zemin damasi - kesim onizlemesinde alfa gorunur olsun (dokuman §5).
class CheckerBackground extends StatelessWidget {
  const CheckerBackground({super.key, required this.child, this.cell = 12});

  final Widget child;
  final double cell;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _CheckerPainter(cell),
        child: child,
      );
}

class _CheckerPainter extends CustomPainter {
  const _CheckerPainter(this.cell);

  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final a = Paint()..color = const Color(0xFF6E6E6E);
    final b = Paint()..color = const Color(0xFF9A9A9A);
    canvas.drawRect(Offset.zero & size, a);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final tek = ((x / cell).floor() + (y / cell).floor()).isOdd;
        if (tek) canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), b);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter old) => old.cell != cell;
}

/// Jest secici - 2. asamada (ve ↻ Animasyon'da) hangi hareket uretilecek.
Future<String?> gestureDialog(BuildContext context, List<String> gestures,
    {String baslik = 'Animasyon - jest sec', String secili = ''}) async {
  var v = secili.isNotEmpty && gestures.contains(secili)
      ? secili
      : (gestures.isNotEmpty ? gestures.first : 'idle');
  // #335: hazir jestlerin disinda serbest metin - "hafifce kalca sallama,
  // ayaklar sabit" gibi. Sunucu bilinmeyen degeri dogrudan hareket cumlesi
  // olarak kullanir (card_flow.gesture_text).
  const ozel = '__ozel__';
  final ozelC = TextEditingController(
      text: secili.isNotEmpty && !gestures.contains(secili) ? secili : '');
  if (ozelC.text.isNotEmpty) v = ozel;
  return showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setLocal) => AlertDialog(
        scrollable: true,
        title: Text(baslik),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'LTX-2.5 i2v, 6 sn. Kamera kilitli kalir - kadraj, olcek ve '
                  'fon degismez.',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 10),
              // RadioListTile Flutter 3.32'de kullanimdan kalkti - duz
              // ListTile + isaret ayni isi gorur.
              for (final g in gestures)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                      g == v
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: g == v ? AppColors.accent : Colors.grey),
                  title: Text(g),
                  onTap: () => setLocal(() => v = g),
                ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    v == ozel
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: v == ozel ? AppColors.accent : Colors.grey),
                title: const Text('Ozel hareket'),
                onTap: () => setLocal(() => v = ozel),
              ),
              if (v == ozel)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: TextField(
                    controller: ozelC,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: 'ornek: hafifce kalca sallama, ayaklar sabit',
                      helperText: 'Kisa bir hareket cumlesi - kamera yine kilitli',
                      helperMaxLines: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Vazgec')),
          FilledButton(
              onPressed: () {
                final t = ozelC.text.trim();
                if (v == ozel && t.isEmpty) return;   // bos ozel metinle uretme
                Navigator.pop(c, v == ozel ? t : v);
              },
              child: const Text('Uret')),
        ],
      ),
    ),
  );
}

/// Kesim kipi secici - `sam` (duz gri fon) | `hybrid` (eski yesil masterlar).
Future<String?> cutModeDialog(BuildContext context, List<String> modes) async {
  var v = modes.isNotEmpty ? modes.first : 'sam';
  return showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setLocal) => AlertDialog(
        scrollable: true,
        title: const Text('3 WebP - kesim kipi'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final m in modes)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                      m == v
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: m == v ? AppColors.accent : Colors.grey),
                  title: Text(m),
                  subtitle: Text(
                      m == 'hybrid'
                          ? 'Eski yesil Grok masterlari - chroma + SAM birlikte'
                          : 'Varsayilan - yalniz SAM3, duz acik gri fon',
                      style: const TextStyle(fontSize: 11)),
                  onTap: () => setLocal(() => v = m),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Vazgec')),
          FilledButton(
              onPressed: () => Navigator.pop(c, v), child: const Text('Kes')),
        ],
      ),
    ),
  );
}

/// ✎ Duzenle penceresi - kisa duzeltme cumlesi (karakter hattiyla ayni kalip).
Future<String?> cardEditDialog(BuildContext context, String baslik) async {
  final ctl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      scrollable: true,
      title: Text('Duzenle - $baslik'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctl,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Duzeltme cumlesi',
                hintText: 'orn. sacini kisalt / eldivenleri cikar',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
                'Kabul edilen still bu cumleyle duzenlenir; kimlik, poz ve '
                'fon korunur. Yeni gorsel otomatik kabul edilir.',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false), child: const Text('Vazgec')),
        FilledButton(
            onPressed: () => Navigator.pop(c, true), child: const Text('Duzenle')),
      ],
    ),
  );
  if (ok != true) return null;
  final t = ctl.text.trim();
  return t.isEmpty ? null : t;
}

/// Kuyruk bildirimi - ev kurali: "Siraya eklendi (N is) - Sira sekmesinden izle".
String queueSnackText(int adet) =>
    'Siraya eklendi ($adet is) - Sira sekmesinden izle';

/// Sunucu ucu yoksa gosterilen "yakinda" gorunumu (#321 paralel yaziliyor).
Widget cardSoonView(String ne) => Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty, size: 36, color: Colors.grey),
            const SizedBox(height: 10),
            Text('$ne - yakinda',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
                'Sunucudaki kart uclari henuz acik degil. Uclar acilinca bu '
                'ekran kendiliginden calisir.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );

// -------------------------------------------------------------- liste

/// Kart hattinin ana ekrani: Normal (koleksiyonlar) / Krupiye (tek ogeler).
class CardFlowScreen extends StatefulWidget {
  const CardFlowScreen({super.key, this.kindSwitch});

  /// Ust cubuktaki Jigsaw | CBN | Kart | Karakter anahtari (FlowHub verir).
  final Widget? kindSwitch;

  @override
  State<CardFlowScreen> createState() => _CardFlowScreenState();
}

class _CardFlowScreenState extends State<CardFlowScreen>
    with WidgetsBindingObserver {
  // #340: uygulamaya donunce liste kendiliginden tazelenir - eskiden
  // arkaplandayken uretilen yeni gorseller listede bayat kaliyordu.

  String _kind = 'card';
  List<CardCollection> _colls = [];
  List<CardDealer> _dealers = [];
  CardProfilesInfo _profiles = const CardProfilesInfo();

  bool _loading = true;
  String? _error;
  bool _soon = false;
  FlowOp? _op;
  Timer? _opPoll;

  bool get _dealerMode => _kind == 'dealer';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _opPoll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // #340: uygulamaya donunce liste tazelenir - arkaplandayken uretilen yeni
    // gorseller eskiden listede bayat kaliyordu (kucuk resim baska, detay baska).
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _soon = false;
    });
    try {
      final p = await CardFlowService.profiles();
      if (_dealerMode) {
        final d = await CardFlowService.dealers();
        if (!mounted) return;
        setState(() {
          _profiles = p;
          _dealers = d;
          _loading = false;
        });
      } else {
        final c = await CardFlowService.collections();
        if (!mounted) return;
        setState(() {
          _profiles = p;
          _colls = c;
          _loading = false;
        });
      }
    } on CardNotReadyException {
      if (!mounted) return;
      setState(() {
        _soon = true;
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

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// Sunucudaki arka plan islemini bitene kadar izler (CBN kalibi).
  void _watch(String opId) {
    if (opId.isEmpty) return;
    _opPoll?.cancel();
    _opPoll = Timer.periodic(const Duration(seconds: 3), (t) async {
      try {
        final o = await CardFlowService.op(opId);
        if (!mounted) return;
        setState(() => _op = o);
        if (!o.running) {
          t.cancel();
          _snack(o.status == 'error'
              ? 'Islem hatasi: ${o.message}'
              : '${o.ok} tamam${o.failed > 0 ? ", ${o.failed} hata" : ""}');
          _load();
        }
      } catch (_) {
        t.cancel();
      }
    });
  }

  // ------------------------------------------------------------- eylem
  /// "+ Yeni koleksiyon" - id / ad / tema / joker anahtari.
  Future<void> _newCollection() async {
    final idC = TextEditingController();
    final adC = TextEditingController();
    final temaC = TextEditingController();
    var jokers = false;
    // #339: hazir koleksiyon kartlari - secilince id/ad/tema dolar, sonra
    // her alan ELLE degistirilebilir. Sablon yoksa serit hic cizilmez.
    final sablonlar = await CardFlowService.presets();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          // #289: uzun icerik + klavye kucuk ekranda tasiyordu.
          scrollable: true,
          title: const Text('Yeni koleksiyon'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: idC,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Kimlik (id)',
                    hintText: 'orn. police_royale',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: adC,
                  decoration: const InputDecoration(
                    labelText: 'Ad',
                    hintText: 'orn. Police Royale',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                if (sablonlar.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Hazir kart sec (istege bagli)',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final sb in sablonlar)
                        ActionChip(
                          label: Text(sb.label,
                              style: const TextStyle(fontSize: 11)),
                          onPressed: () => setLocal(() {
                            temaC.text = sb.theme;
                            if (idC.text.trim().isEmpty) idC.text = sb.id;
                            if (adC.text.trim().isEmpty) adC.text = sb.name;
                          }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: temaC,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Tema',
                    hintText: 'orn. sexy police costume with badge and duty belt',
                    helperText: 'Formul: kimlik + STRICT PALETTE + Signature pieces',
                    helperMaxLines: 2,
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: jokers,
                  title: const Text('Joker (2 adet)'),
                  subtitle: const Text('13 rutbe yerine 15',
                      style: TextStyle(fontSize: 11)),
                  onChanged: (v) => setLocal(() => jokers = v),
                ),
                const Text(
                    'Her rutbe icin 1 still kuyruga girer (ten/sac/kiyafet/poz '
                    'rotasyonu). Onay sorulmaz - ince ayar ✎ / ↻ ile yapilir.',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Vazgec')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Olustur')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final id = idC.text.trim();
    final ad = adC.text.trim();
    if (id.isEmpty || ad.isEmpty) {
      _snack('Kimlik ve ad bos olamaz');
      return;
    }
    final adet = jokers ? 15 : 13;
    try {
      final op = await CardFlowService.createCollection(
          id: id, name: ad, theme: temaC.text.trim(), jokers: jokers ? 2 : 0);
      _watch(op);
      _snack(queueSnackText(adet));
    } on CardNotReadyException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
    _load();
  }

  /// "+ Yeni krupiye" - ad / tema (kiyafet) / jest. Rutbe YOK, tek oge.
  Future<void> _newDealer() async {
    final idC = TextEditingController();
    final adC = TextEditingController();
    final temaC = TextEditingController();
    var jest = _profiles.dealerGestures.isNotEmpty
        ? _profiles.dealerGestures.first
        : 'idle';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          scrollable: true,
          title: const Text('Yeni krupiye'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: idC,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Kimlik (id)',
                    hintText: 'orn. scarlett',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: adC,
                  decoration: const InputDecoration(
                    labelText: 'Ad',
                    hintText: 'orn. Scarlett',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: temaC,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Tema / kiyafet',
                    hintText: 'orn. kumarhane yelegi ve papyon, noir kirmizi elbise',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: jest,
                  decoration: const InputDecoration(
                    labelText: 'Jest',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final g in _profiles.dealerGestures)
                      DropdownMenuItem(value: g, child: Text(g)),
                  ],
                  onChanged: (v) => setLocal(() => jest = v ?? jest),
                ),
                const SizedBox(height: 8),
                const Text(
                    'Krupiye bel ustu kadrajda uretilir (eller masada, kameraya '
                    'bakiyor). Rutbe yoktur - tek oge dort asamadan gecer.',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Vazgec')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Olustur')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final id = idC.text.trim();
    final ad = adC.text.trim();
    if (id.isEmpty || ad.isEmpty) {
      _snack('Kimlik ve ad bos olamaz');
      return;
    }
    try {
      final op = await CardFlowService.createDealer(
          id: id, name: ad, theme: temaC.text.trim(), gesture: jest);
      _watch(op);
      _snack(queueSnackText(1));
    } on CardNotReadyException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
    _load();
  }

  Future<bool> _confirm(String baslik, String metin,
          {String onay = 'Devam'}) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          scrollable: true,
          title: Text(baslik),
          content: Text(metin),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Vazgec')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true), child: Text(onay)),
          ],
        ),
      ) ??
      false;

  /// Gece modu: butun koleksiyonlar + krupiyeler tek dugmeyle yeniden
  /// canlandirilir (dokuman §0). Sabaha 3. asamaya kadar biter, push elle.
  Future<void> _reanimateAll() async {
    final jest = await gestureDialog(context, _profiles.gestures,
        baslik: 'Gece modu - jest sec');
    if (jest == null) return;
    if (!mounted) return;
    final ok = await _confirm(
        'Gece modu',
        'Butun kartlar VE krupiyeler yeniden canlandirilir: mevcut still -> '
            'LTX-2.5 i2v ($jest) -> SAM kesim -> sheet.\n\n'
            'Uzun surer, hepsi kuyruga girer. Push YAPILMAZ.',
        onay: 'Kuyruga ekle');
    if (!ok) return;
    try {
      final op = await CardFlowService.reanimate(
          collection: 'all', gesture: jest, includeDealers: true);
      _watch(op);
      _snack(op.isEmpty
          ? 'Siraya eklendi - Sira sekmesinden izle'
          : 'Siraya eklendi (op $op) - Sira sekmesinden izle');
    } on CardNotReadyException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }


  /// #325: butun kartlarin (ve krupiyelerin) YESIL fonunu duz acik gri studyo
  /// fonuna cevirir - yeniden canlandirmadan once bir kez calistirilir.
  Future<void> _restillAll() async {
    final ok = await _confirm(
        'Fonlari griye al',
        'Butun kartlarin VE krupiyelerin still fonu duz acik griye cevrilir '
            '(kadin aynen kalir). Ilk hal still_green.png olarak saklanir, '
            'zaten gri olanlar atlanir.\n\nVideo uretilmez.',
        onay: 'Kuyruga ekle');
    if (!ok) return;
    try {
      final op = await CardFlowService.restill(
          collection: 'all', includeDealers: true);
      _watch(op);
      _snack('Siraya eklendi - Sira sekmesinden izle');
    } on CardNotReadyException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Salt okunur manifest onizlemesi - push manifesti kendi icinde uretir.
  Future<void> _manifestPreview() async {
    Map<String, dynamic> m;
    try {
      m = await CardFlowService.manifest(kind: _kind);
    } on CardNotReadyException catch (e) {
      _snack(e.message);
      return;
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    if (!mounted) return;
    final koleksiyonlar = (m['collections'] as List?)?.length ?? 0;
    final krupiyeler = (m['dealers'] as List?)?.length ?? 0;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        scrollable: true,
        title: const Text('Manifest onizleme'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$koleksiyonlar koleksiyon, $krupiyeler krupiye',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'Manifest dosyasi PUSH sirasinda yazilir (once dosyalar, '
                  'sonra manifest). Bu yalnizca onizlemedir.',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 10),
              SelectableText(m.toString(),
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Kapat')),
        ],
      ),
    );
  }

  /// Bir koleksiyona basili tutunca: yalniz onu yeniden canlandir.
  Future<void> _collectionMenu(String id, String ad) async {
    final secim = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                dense: true,
                title: Text(ad, style: const TextStyle(fontWeight: FontWeight.bold))),
            ListTile(
              leading: const Icon(Icons.autorenew),
              title: const Text('Yeniden canlandir'),
              subtitle: const Text('still -> i2v -> kesim (bu koleksiyon)',
                  style: TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(c, 'reanimate'),
            ),
            // #325: anime koleksiyonu gercekci kadina cevirir (id/ad degismez).
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Anime -> gercekci (koleksiyon)'),
              subtitle: const Text('her still edit_qwen ile gercekci fotografa',
                  style: TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(c, 'realify'),
            ),
          ],
        ),
      ),
    );
    if (secim == null || !mounted) return;
    try {
      // Eski Grok videosunu yeniden kesme yolu kaldirildi (kullanici: yeniden
      // canlandirma zaten still'den yeni video uretiyor).
      if (secim == 'reanimate') {
        final jest = await gestureDialog(context, _profiles.gestures);
        if (jest == null) return;
        final op = await CardFlowService.reanimate(
            collection: id, gesture: jest, includeDealers: false);
        _watch(op);
      } else if (secim == 'realify') {
        _watch(await CardFlowService.realify(collection: id, kind: _kind));
      }
      _snack('Siraya eklendi - Sira sekmesinden izle');
    } on CardNotReadyException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ------------------------------------------------------------ gorunum
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: widget.kindSwitch ?? const Text('Kart hatti'),
          actions: [
            IconButton(
              icon: const Icon(Icons.code),
              tooltip: 'Code Mod',
              onPressed: () => ModeService.set(false),
            ),
            IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Yenile',
                onPressed: _load),
            PopupMenuButton<String>(
              tooltip: 'Toplu islemler',
              onSelected: (v) => switch (v) {
                'night' => _reanimateAll(),
                'restill' => _restillAll(),          // #325
                _ => _manifestPreview(),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'night',
                    child: Text('Gece modu: hepsini yeniden canlandir')),
                PopupMenuItem(
                    value: 'restill',
                    child: Text('Fonlari griye al (hepsi)')),
                PopupMenuItem(
                    value: 'manifest', child: Text('Manifest onizle')),
              ],
            ),
          ],
        ),
        floatingActionButton: _soon
            ? null
            : FloatingActionButton.extended(
                onPressed: _dealerMode ? _newDealer : _newCollection,
                icon: const Icon(Icons.add),
                label: Text(_dealerMode ? 'Yeni krupiye' : 'Yeni koleksiyon'),
              ),
        body: Column(
          children: [
            _kindBar(),
            if (_op != null && _op!.running) _opBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _soon
                      ? cardSoonView(_dealerMode ? 'Krupiyeler' : 'Kart hatti')
                      : _error != null
                          ? errorView(_error!, _load)
                          : _dealerMode
                              ? _dealerList()
                              : _collectionList(),
            ),
          ],
        ),
      );

  /// Tur secimi: Normal (kart) | Krupiye. Avatar YOK.
  Widget _kindBar() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: SegmentedButton<String>(
          segments: CardFlowService.kinds.entries
              .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
              .toList(),
          selected: {_kind},
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onSelectionChanged: (v) {
            HapticFeedback.selectionClick();
            setState(() => _kind = v.first);
            _load();
          },
        ),
      );

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

  Widget _collectionList() {
    if (_colls.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'Henuz koleksiyon yok.\n\n"+ Yeni koleksiyon" ile kimlik, ad ve '
            'tema ver - 13 (istersen 15) rutbe icin 1\'er still kuyruga girer, '
            'sonra 2 Video ve 3 WebP asamalari.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding:
            bottomSafePadding(context, left: 12, top: 8, right: 12, bottom: 88),
        itemCount: _colls.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _collectionCard(_colls[i]),
      ),
    );
  }

  Widget _collectionCard(CardCollection c) {
    final (s, v, w, p) = c.progress;
    // Kapak = A rutbesinin thumb'i; A'nin still'i yoksa (#327: Jokers'ta
    // yalniz J1/J2 var) still'i olan ILK rutbe. Hicbiri yoksa yer tutucu.
    final kapakRutbe = c.stateOf('A').still
        ? 'A'
        : c.ranks.entries
            .where((e) => e.value.still)
            .map((e) => e.key)
            .firstOrNull;
    final kr = kapakRutbe == null ? null : c.stateOf(kapakRutbe);
    final kapak = kapakRutbe == null
        ? ''
        : CardFlowService.thumbUrl(c.id, kapakRutbe,
            kind: kr!.sheet ? 'thumb' : 'still',
            size: 300,
            v: kr.rev > 0 ? kr.rev : c.rev);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCollection(c),
        onLongPress: () => _collectionMenu(c.id, c.name),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 66,
                  height: 99,          // 2:3
                  child: ColoredBox(
                    color: Colors.black26,
                    child: kapak.isEmpty
                        ? const _KapakYok()
                        : Image.network(
                            kapak,
                            headers: CardFlowService.authHeaders,
                            // #289/#292: contain - tam boy kare kirpilmaz.
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const _KapakYok(),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        if (c.anyWarn)
                          Icon(Icons.warning_amber_rounded,
                              size: 16, color: AppColors.error),
                      ],
                    ),
                    Text(c.theme.isEmpty ? c.id : c.theme,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 6),
                    // 13 (+2) rutbe rozeti - dort asama rengi.
                    Wrap(
                      spacing: 3,
                      runSpacing: 3,
                      children: [
                        for (final r in c.rankOrder)
                          SizedBox(
                              width: 22, child: cardRankBadge(r, c.stateOf(r))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        for (final t in [
                          'still $s/${c.total}',
                          'video $v/${c.total}',
                          'webp $w/${c.total}',
                          'push $p/${c.total}',
                        ])
                          Text(t,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dealerList() {
    if (_dealers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'Henuz krupiye yok.\n\n"+ Yeni krupiye" ile ad, tema ve jest ver - '
            'bel ustu kadrajda tek oge uretilir ve dort asamadan gecer.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding:
            bottomSafePadding(context, left: 12, top: 8, right: 12, bottom: 88),
        itemCount: _dealers.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _dealerCard(_dealers[i]),
      ),
    );
  }

  Widget _dealerCard(CardDealer d) {
    final s = d.state;
    final url = CardFlowService.thumbUrl(d.id, CardFlowService.dealerRank,
        kind: s.sheet ? 'thumb' : 'still',
        size: 300,
        v: s.rev > 0 ? s.rev : d.rev,
        type: 'dealer');
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDealer(d),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 66,
                  height: 99,
                  child: ColoredBox(
                    color: Colors.black26,
                    child: Image.network(
                      url,
                      headers: CardFlowService.authHeaders,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        color: Colors.white10,
                        alignment: Alignment.center,
                        child: const Icon(Icons.person_outline,
                            size: 20, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(d.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        if (s.warn)
                          Icon(Icons.warning_amber_rounded,
                              size: 16, color: AppColors.error),
                      ],
                    ),
                    Text(d.theme.isEmpty ? d.id : d.theme,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 6),
                    cardStageChips(s),
                    if (d.gesture.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('jest ${d.gesture}',
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCollection(CardCollection c) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CardCollectionPage(id: c.id, title: c.name),
    ));
    _load();
  }

  Future<void> _openDealer(CardDealer d) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CardDetailPage(
        collection: d.id,
        rank: CardFlowService.dealerRank,
        title: d.name,
        kind: 'dealer',
      ),
    ));
    _load();
  }
}

// ------------------------------------------------------------ koleksiyon

/// Koleksiyon detayi: 13 (+2) rutbenin 2:3 izgarasi + dort asama dugmeleri.
class CardCollectionPage extends StatefulWidget {
  const CardCollectionPage({super.key, required this.id, required this.title});

  final String id;
  final String title;

  @override
  State<CardCollectionPage> createState() => _CardCollectionPageState();
}

class _CardCollectionPageState extends State<CardCollectionPage> {
  CardCollection? _c;
  CardProfilesInfo _profiles = const CardProfilesInfo();
  final Set<String> _sel = {};

  bool _loading = true;
  String? _error;
  FlowOp? _op;
  Timer? _opPoll;

  bool get _selecting => _sel.isNotEmpty;
  List<String> get _ranks => _c?.rankOrder ?? CardFlowService.baseRanks;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _opPoll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await CardFlowService.profiles();
      final c = await CardFlowService.collection(widget.id);
      if (!mounted) return;
      setState(() {
        _profiles = p;
        _c = c;
        _sel.removeWhere((r) => !(c?.ranks.containsKey(r) ?? true));
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

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _watch(String opId) {
    if (opId.isEmpty) return;
    _opPoll?.cancel();
    _opPoll = Timer.periodic(const Duration(seconds: 3), (t) async {
      try {
        final o = await CardFlowService.op(opId);
        if (!mounted) return;
        setState(() => _op = o);
        if (!o.running) {
          t.cancel();
          _snack(o.status == 'error'
              ? 'Islem hatasi: ${o.message}'
              : '${o.ok} tamam${o.failed > 0 ? ", ${o.failed} hata" : ""}');
          _load();
        }
      } catch (_) {
        t.cancel();
      }
    });
  }

  Future<bool> _confirm(String baslik, String metin,
          {String onay = 'Devam'}) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          scrollable: true,
          title: Text(baslik),
          content: Text(metin),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Vazgec')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true), child: Text(onay)),
          ],
        ),
      ) ??
      false;

  // -------------------------------------------------------------- eylem
  /// Hedef rutbeler: secim varsa secililer, yoksa hepsi (koleksiyon dugmeleri).
  List<String> _targets({bool hepsi = false}) =>
      (hepsi || _sel.isEmpty) ? _ranks : (_sel.toList()..sort());

  Future<void> _stills({bool hepsi = false}) async {
    final r = _targets(hepsi: hepsi);
    try {
      final op = await CardFlowService.stills(collection: widget.id, ranks: r);
      setState(_sel.clear);
      _watch(op);
      _snack(queueSnackText(r.length));
    } on CardNotReadyException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _animate({bool hepsi = false}) async {
    final r = _targets(hepsi: hepsi);
    final jest = await gestureDialog(context, _profiles.gestures);
    if (jest == null) return;
    try {
      final op = await CardFlowService.animate(
          collection: widget.id, ranks: r, gesture: jest);
      setState(_sel.clear);
      _watch(op);
      _snack(queueSnackText(r.length));
    } on CardNotReadyException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _cut({bool hepsi = false}) async {
    final r = _targets(hepsi: hepsi);
    final mode = await cutModeDialog(context, _profiles.cutModes);
    if (mode == null) return;
    try {
      final op = await CardFlowService.cut(
          collection: widget.id, ranks: r, mode: mode);
      setState(_sel.clear);
      _watch(op);
      _snack(queueSnackText(r.length));
    } on CardNotReadyException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _edit() async {
    if (_sel.length != 1) {
      _snack('Duzenleme tek rutbe icin - bir kart sec');
      return;
    }
    final rank = _sel.first;
    final prompt = await cardEditDialog(context, '${widget.title} $rank');
    if (prompt == null) return;
    try {
      final op = await CardFlowService.edit(
          collection: widget.id, rank: rank, prompt: prompt);
      setState(_sel.clear);
      _watch(op);
      _snack(queueSnackText(1));
    } on CardNotReadyException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// 4. asama - manifest bu adimin icinde uretilir, GERI ALINAMAZ.
  Future<void> _push() async {
    final (_, _, w, _) = _c?.progress ?? (0, 0, 0, 0);
    final ok = await _confirm(
        'Push - ${widget.title}',
        'Sheet ve thumb dosyalari R2 (hotcardgames) uzerine yuklenir, sonra '
            'manifest yazilir. Su an $w/${_ranks.length} rutbenin webp\'i hazir.'
            '\n\nBu bir YAYIN islemidir, GERI ALINAMAZ.',
        onay: 'Push');
    if (!ok) return;
    try {
      final op = await CardFlowService.push(collection: widget.id);
      setState(_sel.clear);
      _watch(op);
      _snack('Push siraya eklendi - Sira sekmesinden izle');
    } on CardNotReadyException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ------------------------------------------------------------ gorunum
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: _selecting
              ? IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Secimi birak',
                  onPressed: () => setState(_sel.clear))
              : null,
          title: Text(_selecting ? '${_sel.length} secili' : widget.title),
          actions: [
            if (_selecting)
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: 'Tumunu sec',
                onPressed: () => setState(() => _sel.addAll(_ranks)),
              ),
            IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Yenile',
                onPressed: _load),
          ],
        ),
        bottomNavigationBar: _selecting ? _actionBar() : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? errorView(_error!, _load)
                : Column(
                    children: [
                      if (_op != null && _op!.running) _opBar(),
                      _stageButtons(),
                      Expanded(child: _grid()),
                    ],
                  ),
      );

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

  /// Koleksiyon duzeyinde dort asama: 1 Still · 2 Video · 3 WebP · 4 Push.
  Widget _stageButtons() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            _stageButton(Icons.image_outlined, '1 Still uret',
                () => _stills(hepsi: true)),
            const SizedBox(width: 8),
            _stageButton(Icons.movie_creation_outlined, '2 Video uret',
                () => _animate(hepsi: true)),
            const SizedBox(width: 8),
            _stageButton(Icons.content_cut, '3 WebP uret', () => _cut(hepsi: true)),
            const SizedBox(width: 8),
            _stageButton(Icons.cloud_upload_outlined, '4 Push', _push,
                vurgulu: true),
          ],
        ),
      );

  Widget _stageButton(IconData i, String t, VoidCallback f,
          {bool vurgulu = false}) =>
      vurgulu
          ? FilledButton.icon(
              onPressed: f, icon: Icon(i, size: 16), label: Text(t))
          : FilledButton.tonalIcon(
              onPressed: f, icon: Icon(i, size: 16), label: Text(t));

  /// Secim cubugu - #317: ikonun altinda kisa etiket.
  Widget _actionBar() => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              _act(Icons.image_outlined, '1 Still', () => _stills()),
              _act(Icons.movie_creation_outlined, '2 Video', () => _animate()),
              _act(Icons.content_cut, '3 WebP', () => _cut()),
              _act(Icons.edit_outlined, 'Duzenle', _edit),
              _act(Icons.auto_awesome, 'Prompt', _rewriteLooks),
            ],
          ),
        ),
      );

  /// #337: rutbe promptlarini yerel LLM'e yeniden yazdirir. Dosyalara
  /// DOKUNMAZ - sonra "1 Still" ile yeniden uretilir.
  Future<void> _rewriteLooks() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Promptlari yeniden yaz'),
        content: const Text(
            'Yerel LLM koleksiyonun temasina gore her rutbeye yeni gorunus '
            '(yas 20-26, ten, sac, kiyafet, poz) yazar. Mevcut still / video / '
            'sheet dosyalarina DOKUNULMAZ - yeni promptlarla uretmek icin '
            'sonra "1 Still" calistir.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: const Text('Vazgec')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: const Text('Yaz')),
        ],
      ),
    );
    if (onay != true) return;
    _snack('Promptlar yaziliyor - yerel LLM biraz surebilir');
    try {
      // Bu sayfa yalniz kart koleksiyonlarini acar; krupiyenin kendi sayfasi var.
      final d = await CardFlowService.rewriteLooks(widget.id, kind: 'card');
      if (!mounted) return;
      _snack('Promptlar yazildi (${d['written_by'] ?? 'llm'})');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _act(IconData i, String t, VoidCallback? f) => Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                onPressed: f,
                tooltip: t,
                icon: Icon(i, size: 22),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact),
            Text(t,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 9, color: f == null ? Colors.grey : Colors.white70)),
          ],
        ),
      );

  Widget _grid() {
    final c = _c;
    if (c == null) {
      return cardSoonView(widget.title);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding:
            bottomSafePadding(context, left: 10, top: 4, right: 10, bottom: 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 132,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2 / 3,
        ),
        itemCount: _ranks.length,
        itemBuilder: (_, i) => _cell(c, _ranks[i]),
      ),
    );
  }

  Widget _cell(CardCollection c, String rank) {
    final s = c.stateOf(rank);
    final secili = _sel.contains(rank);
    final url = CardFlowService.thumbUrl(c.id, rank,
        kind: 'still', size: 300, v: s.rev > 0 ? s.rev : c.rev);
    return GestureDetector(
      onTap: () {
        if (_selecting) {
          setState(() => secili ? _sel.remove(rank) : _sel.add(rank));
        } else {
          _open(rank);
        }
      },
      onLongPress: () {
        HapticFeedback.selectionClick();
        setState(() => secili ? _sel.remove(rank) : _sel.add(rank));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: secili ? AppColors.accent : Colors.white24,
              width: secili ? 2 : 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black26),
              if (s.still)
                Image.network(
                  url,
                  headers: CardFlowService.authHeaders,
                  // #292: contain - 2:3 kare kirpilmadan gorunur.
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(color: Colors.white10),
                )
              else
                Container(
                  color: Colors.white10,
                  alignment: Alignment.center,
                  child: const Icon(Icons.add_photo_alternate_outlined,
                      size: 22, color: Colors.grey),
                ),
              // Rutbe etiketi (sol ust).
              Positioned(
                left: 3,
                top: 3,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: cardStageColor(s.stage),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(rank,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: s.stage == 0 ? Colors.grey : Colors.white)),
                ),
              ),
              // Asama isaretleri (sag ust): oynatma / ✓ webp / ✓ push / kontrol.
              Positioned(
                right: 3,
                top: 3,
                child: Column(
                  children: [
                    if (s.video)
                      const Icon(Icons.play_circle_fill,
                          size: 16, color: Colors.white70),
                    if (s.sheet)
                      Icon(Icons.check_circle,
                          size: 15, color: Colors.blue.shade300),
                    if (s.pushed)
                      Icon(Icons.cloud_done,
                          size: 15, color: Colors.green.shade400),
                    if (s.warn)
                      Icon(Icons.warning_amber_rounded,
                          size: 15, color: AppColors.error),
                  ],
                ),
              ),
              if (secili)
                Positioned(
                  left: 3,
                  bottom: 3,
                  child: Icon(Icons.check_circle,
                      size: 16, color: AppColors.accent),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(String rank) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CardDetailPage(
        collection: widget.id,
        rank: rank,
        title: '${widget.title} - $rank',
      ),
    ));
    _load();
  }
}

// ----------------------------------------------------------------- detay

/// Tek kartin (ya da krupiyenin) detayi: Still | Video | Kesim.
class CardDetailPage extends StatefulWidget {
  const CardDetailPage({
    super.key,
    required this.collection,
    required this.rank,
    required this.title,
    this.kind = 'card',
  });

  final String collection;
  final String rank;
  final String title;
  /// `card` | `dealer` - krupiyede rutbe yoktur (`dealerRank`).
  final String kind;

  @override
  State<CardDetailPage> createState() => _CardDetailPageState();
}

class _CardDetailPageState extends State<CardDetailPage> {
  String _view = 'still';
  CardRankState _state = const CardRankState();
  CardProfilesInfo _profiles = const CardProfilesInfo();

  bool _loading = true;
  String? _error;
  FlowOp? _op;
  Timer? _opPoll;

  /// #336: bu rutbenin aday still'leri (secilebilir/silinebilir).
  List<String> _adaylar = const [];
  /// #338: bu rutbenin animasyonlari (idle + zafer gibi ekler).
  List<CardAnim> _anims = const [];
  /// Uzerinde calisilan animasyon - 2 Video ve 3 WebP buna yazar.
  String _anim = 'idle';

  bool get _dealer => widget.kind == 'dealer';
  List<String> get _gestures =>
      _dealer ? _profiles.dealerGestures : _profiles.gestures;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _opPoll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await CardFlowService.profiles();
      CardRankState s = const CardRankState();
      if (_dealer) {
        final liste = await CardFlowService.dealers();
        for (final d in liste) {
          if (d.id == widget.collection) s = d.state;
        }
      } else {
        final c = await CardFlowService.collection(widget.collection);
        s = c?.stateOf(widget.rank) ?? const CardRankState();
      }
      var adaylar = const <String>[];
      try {
        adaylar = await CardFlowService.candidates(widget.collection, widget.rank,
            kind: widget.kind);
      } catch (_) {
        // eski sunucuda uc yok - aday seridi gosterilmez
      }
      var anims = const <CardAnim>[];
      try {
        anims = await CardFlowService.anims(widget.collection, widget.rank,
            kind: widget.kind);
      } catch (_) {
        // eski sunucuda uc yok - serit gosterilmez
      }
      if (!mounted) return;
      setState(() {
        _profiles = p;
        _state = s;
        _adaylar = adaylar;
        _anims = anims;
        if (!anims.any((a) => a.name == _anim)) _anim = 'idle';
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

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _watch(String opId) {
    if (opId.isEmpty) return;
    _opPoll?.cancel();
    _opPoll = Timer.periodic(const Duration(seconds: 3), (t) async {
      try {
        final o = await CardFlowService.op(opId);
        if (!mounted) return;
        setState(() => _op = o);
        if (!o.running) {
          t.cancel();
          _snack(o.status == 'error'
              ? 'Islem hatasi: ${o.message}'
              : '${o.ok} tamam${o.failed > 0 ? ", ${o.failed} hata" : ""}');
          _load();
        }
      } catch (_) {
        t.cancel();
      }
    });
  }

  List<String> get _ranks => [widget.rank];

  Future<void> _run(String ad, Future<String> Function() f) async {
    try {
      final op = await f();
      _watch(op);
      _snack(queueSnackText(1));
    } on CardNotReadyException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('$ad: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _edit() async {
    final prompt = await cardEditDialog(context, widget.title);
    if (prompt == null) return;
    await _run(
        'Duzenle',
        () => CardFlowService.edit(
            collection: widget.collection,
            rank: widget.rank,
            prompt: prompt,
            kind: widget.kind));
  }

  Future<void> _redoStill() async => _run(
      '1 Still',
      () => CardFlowService.stills(
          collection: widget.collection, ranks: _ranks, kind: widget.kind));

  Future<void> _redoAnim() async {
    final jest = await gestureDialog(context, _gestures,
        secili: _state.gesture);
    if (jest == null) return;
    await _run(
        '2 Video',
        () => CardFlowService.animate(
            collection: widget.collection,
            ranks: _ranks,
            gesture: jest,
            kind: widget.kind,
            anim: _anim));
  }

  Future<void> _redoCut() async {
    final mode = await cutModeDialog(context, _profiles.cutModes);
    if (mode == null) return;
    await _run(
        '3 WebP',
        () => CardFlowService.cut(
            collection: widget.collection,
            ranks: _ranks,
            mode: mode,
            kind: widget.kind,
            anim: _anim));
  }

  // ------------------------------------------------------------ gorunum
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Yenile',
                onPressed: _load),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? errorView(_error!, _load)
                : Column(
                    children: [
                      if (_op != null && _op!.running)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: LinearProgressIndicator(value: _op!.progress),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'still', label: Text('Still')),
                            ButtonSegment(value: 'video', label: Text('Video')),
                            ButtonSegment(value: 'cut', label: Text('Kesim')),
                          ],
                          selected: {_view},
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onSelectionChanged: (v) {
                            HapticFeedback.selectionClick();
                            setState(() => _view = v.first);
                          },
                        ),
                      ),
                      Expanded(child: _preview()),
                      _info(),
                      _animSeridi(),
                      _adaylarSeridi(),
                      _buttons(),
                    ],
                  ),
      );

  Widget _preview() {
    switch (_view) {
      case 'video':
        if (!_state.video) return _bos('Video yok - "2 Video" ile uret');
        return NetworkVideo(
          url: CardFlowService.fileUrl(widget.collection, widget.rank,
              kind: 'video', v: _state.rev, type: widget.kind),
          headers: CardFlowService.authHeaders,
        );
      case 'cut':
        if (!_state.sheet) return _bos('Kesim yok - "3 WebP" ile uret');
        // Sheet'in ILK karesi damali zeminde - alfa gorunur olsun.
        return CheckerBackground(
          child: InteractiveViewer(
            child: Center(
              child: Image.network(
                CardFlowService.thumbUrl(widget.collection, widget.rank,
                    kind: 'frame', size: 900, v: _state.rev, type: widget.kind),
                headers: CardFlowService.authHeaders,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Center(child: Text('Kesim karesi okunamadi')),
              ),
            ),
          ),
        );
      default:
        if (!_state.still) return _bos('Still yok - "1 Still" ile uret');
        return InteractiveViewer(
          child: Center(
            child: Image.network(
              CardFlowService.thumbUrl(widget.collection, widget.rank,
                  kind: 'still', size: 900, v: _state.rev, type: widget.kind),
              headers: CardFlowService.authHeaders,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Center(child: Text('Still okunamadi')),
            ),
          ),
        );
    }
  }

  Widget _bos(String m) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(m,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
        ),
      );

  /// Asama rozetleri + guard olcumleri (FAIL ise kirmizi "kontrol" satiri).
  Widget _info() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cardStageChips(_state),
            // #345: bu gorseli ureten prompt - dokununca tamami acilir.
            if (_state.prompt.isNotEmpty) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (c) => AlertDialog(
                    scrollable: true,
                    title: Text('Prompt${_state.age > 0 ? '  ·  ${_state.age} yas' : ''}'),
                    content: SelectableText(_state.prompt,
                        style: const TextStyle(fontSize: 12)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Kapat')),
                    ],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(_state.prompt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            ],
            if (_state.gesture.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('jest: ${_state.gesture}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
            if (_state.metrics.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                  _state.metrics.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join('  ·  '),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
            if (_state.warn) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 14, color: AppColors.error),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                        'Guard FAIL - kadraj kaymasi / zoom / maske kopmasi. '
                        'Videoyu ya da kesimi yeniden uret.',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.error)),
                  ),
                ],
              ),
            ],
          ],
        ),
      );

  /// #338: animasyon seridi - hangi animasyon uzerinde calisildigi buradan
  /// secilir; "+ Yeni" ile zafer gibi ek animasyon acilir, cop ile silinir.
  Widget _animSeridi() {
    if (_anims.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Animasyonlar - secili olana uretilir',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final a in _anims)
                InputChip(
                  selected: a.name == _anim,
                  label: Text(
                      '${a.name}${a.stage >= 3 ? '  ✓' : (a.stage == 2 ? '  ▶' : '')}',
                      style: const TextStyle(fontSize: 11)),
                  onSelected: (_) => setState(() => _anim = a.name),
                  onDeleted: a.isIdle ? null : () => _animSil(a.name),
                  deleteIcon: a.isIdle ? null : const Icon(Icons.close, size: 15),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 15),
                label: const Text('Yeni', style: TextStyle(fontSize: 11)),
                onPressed: _animEkle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _animEkle() async {
    final c = TextEditingController();
    final ad = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni animasyon'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Ad',
            hintText: 'orn. zafer',
            helperText: 'Secip "2 Video" calistir - bu ada ayri video/sheet uretilir',
            helperMaxLines: 2,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Vazgec')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Ekle')),
        ],
      ),
    );
    final t = (ad ?? '').trim().toLowerCase();
    if (t.isEmpty || t == 'idle') return;
    // Klasor ilk video uretiminde acilir; simdilik secili yapmak yeter.
    setState(() {
      _anims = [..._anims, CardAnim(name: t)];
      _anim = t;
    });
    _snack('"$t" secildi - simdi 2 Video calistir');
  }

  Future<void> _animSil(String ad) async {
    try {
      await CardFlowService.deleteAnim(widget.collection, widget.rank, ad,
          kind: widget.kind);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// #336: aday still seridi - dokun = sec, cop = sil. Birden fazla gorsel
  /// varken telefondan hangisinin secilecegi buradan belirlenir.
  Widget _adaylarSeridi() {
    if (_adaylar.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Adaylar (${_adaylar.length}) - dokun = sec',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 6),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _adaylar.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (c, i) {
                final ad = _adaylar[i];
                final rel = CardFlowService.candidateRel(
                    widget.collection, widget.rank, ad, kind: widget.kind);
                return Stack(
                  children: [
                    InkWell(
                      onTap: () => _adaySec(ad),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          CardFlowService.relThumbUrl(rel, size: 200),
                          // #343: kimlik basligi ZORUNLU - onsuz sunucu 401
                          // doner ve butun adaylar kirik gorsel olarak cikar.
                          headers: CardFlowService.authHeaders,
                          width: 80,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                              width: 80,
                              height: 120,
                              color: Colors.black26,
                              child: const Icon(Icons.broken_image, size: 18)),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: InkWell(
                        onTap: () => _adaySil(ad),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          color: Colors.black54,
                          child: const Icon(Icons.delete_outline,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _adaySec(String file) async {
    try {
      await CardFlowService.pickCandidate(widget.collection, widget.rank, file,
          kind: widget.kind);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aday secili still oldu')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _adaySil(String file) async {
    try {
      await CardFlowService.deleteCandidate(
          widget.collection, widget.rank, file,
          kind: widget.kind);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    }
  }

  Widget _buttons() => Padding(
        // #289: alt gezinme cubugunun altinda kalmasin.
        padding:
            bottomSafePadding(context, left: 8, top: 6, right: 8, bottom: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilledButton.tonalIcon(
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Duzenle')),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                  onPressed: _redoStill,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('1 Still')),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                  onPressed: _redoAnim,
                  icon: const Icon(Icons.movie_creation_outlined, size: 16),
                  label: const Text('2 Video')),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                  onPressed: _redoCut,
                  icon: const Icon(Icons.content_cut, size: 16),
                  label: const Text('3 WebP')),
            ],
          ),
        ),
      );
}

/// #327: kapak yer tutucusu (henuz still yok / yuklenemedi).
class _KapakYok extends StatelessWidget {
  const _KapakYok();

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white10,
        alignment: Alignment.center,
        child: const Icon(Icons.style_outlined, size: 20, color: Colors.grey),
      );
}
