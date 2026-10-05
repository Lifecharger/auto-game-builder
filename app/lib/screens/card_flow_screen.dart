import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/app_l10n.dart';
import '../services/card_flow_service.dart';
import '../services/jigsaw_flow_service.dart' show FlowOp;
import '../services/mode_service.dart';
import '../theme.dart';
import '../widgets/bottom_inset.dart';
import '../widgets/network_video.dart';
import 'character_flow_screen.dart' show errorView;
import 'card_templates_screen.dart';
import '../widgets/flow_kind_switch.dart' show kindSwitchBottom;

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
      4 => appL10n.cardStagePushed,
      3 => appL10n.cardStageWebp,
      2 => appL10n.cardStageVideo,
      1 => appL10n.cardStageStill,
      _ => appL10n.cardStageEmpty,
    };

/// Bir rutbenin kucuk durum rozeti - liste kartinda 13 (+2) tane yan yana.
Widget cardRankBadge(String rank, CardRankState s, {double size = 9}) => Tooltip(
      message: s.warn
          ? appL10n.cardRankTooltipWarn(rank, cardStageName(s.stage))
          : appL10n.cardRankTooltip(rank, cardStageName(s.stage)),
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
/// #357: "2 Video" istegi - hareket cumlesi (sablondan ya da elle), hangi
/// etikete atanacagi (bos = yalniz havuza) ve motor.
class VideoIstek {
  const VideoIstek(this.gesture, {this.tag = '', this.engine = ''});
  final String gesture;   // sunucuya giden hareket cumlesi (ya da hazir ad)
  final String tag;       // '' = yalniz havuza (atama yok)
  final String engine;    // '' = koleksiyon ayari
  bool get poolOnly => tag.isEmpty;
}

/// #357: video penceresi. Kullanicinin tarifi: "idle/wink sablon olarak kendi
/// gidiyordu; artik promptu kendi yazsin ya da sablondan gondersin, etiketi
/// (idle / victory ...) ayrica atasin." Sablon secilince metin kutusuna
/// cumlesi dolar; kullanici duzenler, giden metin KUTUDAKIDIR.
Future<VideoIstek?> videoDialog(
  BuildContext context, {
  required List<String> gestures,
  Map<String, String> gestureTexts = const {},
  List<String> anims = const ['idle'],
  List<CardEngine> engines = const [],
  String engine = '',
  String tag = 'idle',
  String secili = '',
  String baslik = '2 Video',
}) async {
  final l10n = AppLocalizations.of(context)!;
  const havuz = '__havuz__';
  const yeni = '__yeni__';
  final ilkSablon = secili.isNotEmpty && gestures.contains(secili)
      ? secili
      : (gestures.isNotEmpty ? gestures.first : 'idle');
  final metinC = TextEditingController(
      text: secili.isNotEmpty && !gestures.contains(secili)
          ? secili
          : (gestureTexts[ilkSablon] ?? ilkSablon));
  final yeniC = TextEditingController();
  var sablon = ilkSablon;
  var hedef = anims.contains(tag) ? tag : (tag.isEmpty ? havuz : anims.first);
  var motor = engines.any((e) => e.id == engine)
      ? engine
      : (engines.isNotEmpty ? engines.first.id : '');
  return showDialog<VideoIstek>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setLocal) => AlertDialog(
        scrollable: true,
        title: Text(baslik),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.cardVideoIntro,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: sablon,
                isExpanded: true,
                decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    labelText: l10n.cardVideoTemplate),
                items: [
                  for (final g in gestures)
                    DropdownMenuItem(
                        value: g,
                        child: Text(g, style: const TextStyle(fontSize: 13))),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setLocal(() {
                    sablon = v;
                    metinC.text = gestureTexts[v] ?? v;
                  });
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: metinC,
                minLines: 2,
                maxLines: 5,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  labelText: l10n.cardVideoMotion,
                  helperText: l10n.cardVideoMotionHelp,
                  helperMaxLines: 3,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: hedef,
                isExpanded: true,
                decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    labelText: l10n.cardVideoAssignTag),
                items: [
                  DropdownMenuItem(
                      value: havuz,
                      child: Text(l10n.cardVideoPoolOnly,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13))),
                  for (final a in anims)
                    DropdownMenuItem(
                        value: a,
                        child: Text(a, style: const TextStyle(fontSize: 13))),
                  DropdownMenuItem(
                      value: yeni,
                      child: Text(l10n.cardVideoNewTag,
                          style: const TextStyle(fontSize: 13))),
                ],
                onChanged: (v) => setLocal(() => hedef = v ?? havuz),
              ),
              if (hedef == yeni)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: yeniC,
                    autofocus: true,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                        isDense: true,
                        border: const OutlineInputBorder(),
                        labelText: l10n.cardVideoNewTagName,
                        hintText: l10n.cardTagHint),
                  ),
                ),
              if (engines.length > 1) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: motor,
                  isExpanded: true,
                  decoration: InputDecoration(
                      isDense: true,
                      border: const OutlineInputBorder(),
                      labelText: l10n.engine),
                  items: [
                    for (final e in engines)
                      DropdownMenuItem(
                          value: e.id,
                          enabled: e.available,
                          child: Text(e.available ? e.label : l10n.cardTplEngineUnavailable(e.label),
                              style: const TextStyle(fontSize: 13))),
                  ],
                  onChanged: (v) => setLocal(() => motor = v ?? motor),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () {
              final metin = metinC.text.trim();
              if (metin.isEmpty) return;
              var t = hedef == havuz ? '' : hedef;
              if (hedef == yeni) {
                t = yeniC.text.trim().toLowerCase();
                if (t.isEmpty) return;
              }
              Navigator.pop(c, VideoIstek(metin, tag: t, engine: motor));
            },
            child: Text(l10n.generate),
          ),
        ],
      ),
    ),
  );
}

Future<String?> gestureDialog(BuildContext context, List<String> gestures,
    {String? baslik, String secili = ''}) async {
  final l10n = AppLocalizations.of(context)!;
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
        title: Text(baslik ?? l10n.cardGestureTitle),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.cardGestureIntro,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
                title: Text(l10n.cardGestureCustom),
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
                    decoration: InputDecoration(
                      isDense: true,
                      border: const OutlineInputBorder(),
                      hintText: l10n.cardGestureCustomHint,
                      helperText: l10n.cardGestureCustomHelp,
                      helperMaxLines: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () {
                final t = ozelC.text.trim();
                if (v == ozel && t.isEmpty) return;   // bos ozel metinle uretme
                Navigator.pop(c, v == ozel ? t : v);
              },
              child: Text(l10n.generate)),
        ],
      ),
    ),
  );
}

/// Kesim kipi secici - `sam` (duz gri fon) | `hybrid` (eski yesil masterlar).
Future<String?> cutModeDialog(BuildContext context, List<String> modes) async {
  final l10n = AppLocalizations.of(context)!;
  var v = modes.isNotEmpty ? modes.first : 'sam';
  return showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setLocal) => AlertDialog(
        scrollable: true,
        title: Text(l10n.cardCutTitle),
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
                          ? l10n.cardCutHybrid
                          : l10n.cardCutSam,
                      style: const TextStyle(fontSize: 11)),
                  onTap: () => setLocal(() => v = m),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, v), child: Text(l10n.cardCutAction)),
        ],
      ),
    ),
  );
}

/// ✎ Duzenle penceresi - kisa duzeltme cumlesi (karakter hattiyla ayni kalip).
/// #361: duzenleme istegi - cumle + sinirsiz (NSFW LoRA) anahtari.
class CardEditIstek {
  const CardEditIstek(this.prompt, {this.nsfw = false});
  final String prompt;
  final bool nsfw;
}

Future<CardEditIstek?> cardEditDialog(BuildContext context, String baslik) async {
  final l10n = AppLocalizations.of(context)!;
  final ctl = TextEditingController();
  var nsfw = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setLocal) => AlertDialog(
        scrollable: true,
        title: Text(l10n.cardEditTitle(baslik)),
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
                decoration: InputDecoration(
                  labelText: l10n.cardEditSentence,
                  hintText: l10n.cardEditSentenceHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.cardEditBody,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              // #361: temel Qwen bir noktadan sonra reddediyor (etek kisaltma
              // vb.); MCNL LoRA'li akis sinirsiz duzenler.
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: nsfw,
                title: Text(l10n.cardEditUnrestricted,
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(l10n.cardEditUnrestrictedHint,
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                onChanged: (v) => setLocal(() => nsfw = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(l10n.edit)),
        ],
      ),
    ),
  );
  if (ok != true) return null;
  final t = ctl.text.trim();
  return t.isEmpty ? null : CardEditIstek(t, nsfw: nsfw);
}

/// Kuyruk bildirimi - ev kurali: "Siraya eklendi (N is) - Sira sekmesinden izle".
String queueSnackText(int adet) => appL10n.cardQueuedJobs(adet);

/// Sunucu ucu yoksa gosterilen "yakinda" gorunumu (#321 paralel yaziliyor).
Widget cardSoonView(String ne) => Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty, size: 36, color: Colors.grey),
            const SizedBox(height: 10),
            Text(appL10n.cardSoonTitle(ne),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(appL10n.cardSoonBody,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
  AppLocalizations get l10n => AppLocalizations.of(context)!;

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
    var hata = 0;
    _opPoll = Timer.periodic(const Duration(seconds: 3), (t) async {
      try {
        final o = await CardFlowService.op(opId);
        if (!mounted) return;
        hata = 0;
        setState(() => _op = o);
        if (!o.running) {
          t.cancel();
          _snack(o.status == 'error'
              ? l10n.flowOpError(o.message)
              : o.status == 'cancelled'
                  ? l10n.flowOpCancelled
                  : o.failed > 0
                      ? l10n.flowOpDoneWithFailed(o.ok, o.failed)
                      : l10n.flowOpDone(o.ok));
          _load();
        }
      } catch (_) {
        // #352: gecici ag hatasi cubugu donmus birakmasin - 3 ardisik hatada birak.
        if (++hata >= 3) {
          t.cancel();
          if (mounted) setState(() => _op = null);
        }
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
          title: Text(l10n.cardNewCollection),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: idC,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.cardIdLabel,
                    hintText: l10n.cardIdHintCollection,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: adC,
                  decoration: InputDecoration(
                    labelText: l10n.commonName,
                    hintText: l10n.cardNameHintCollection,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                if (sablonlar.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(l10n.cardPickPreset,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
                  decoration: InputDecoration(
                    labelText: l10n.cardTplTheme,
                    hintText: l10n.cardThemeHint,
                    hintMaxLines: 2,
                    helperText: l10n.cardThemeFormula,
                    helperMaxLines: 2,
                    border: const OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: jokers,
                  title: Text(l10n.cardJokers),
                  subtitle: Text(l10n.cardJokersHint,
                      style: const TextStyle(fontSize: 11)),
                  onChanged: (v) => setLocal(() => jokers = v),
                ),
                Text(l10n.cardNewCollectionNote,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(l10n.create)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final id = idC.text.trim();
    final ad = adC.text.trim();
    if (id.isEmpty || ad.isEmpty) {
      _snack(l10n.cardIdNameRequired);
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
          title: Text(l10n.cardNewDealer),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: idC,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.cardIdLabel,
                    hintText: l10n.cardIdHintDealer,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: adC,
                  decoration: InputDecoration(
                    labelText: l10n.commonName,
                    hintText: l10n.cardNameHintDealer,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: temaC,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.cardDealerTheme,
                    hintText: l10n.cardDealerThemeHint,
                    hintMaxLines: 2,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: jest,
                  decoration: InputDecoration(
                    labelText: l10n.fieldGesture,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final g in _profiles.dealerGestures)
                      DropdownMenuItem(value: g, child: Text(g)),
                  ],
                  onChanged: (v) => setLocal(() => jest = v ?? jest),
                ),
                const SizedBox(height: 8),
                Text(l10n.cardDealerNote,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(l10n.create)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final id = idC.text.trim();
    final ad = adC.text.trim();
    if (id.isEmpty || ad.isEmpty) {
      _snack(l10n.cardIdNameRequired);
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
          {String? onay}) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          scrollable: true,
          title: Text(baslik),
          content: Text(metin),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(onay ?? l10n.continueLabel)),
          ],
        ),
      ) ??
      false;

  /// Gece modu: butun koleksiyonlar + krupiyeler tek dugmeyle yeniden
  /// canlandirilir (dokuman §0). Sabaha 3. asamaya kadar biter, push elle.
  Future<void> _reanimateAll() async {
    final jest = await gestureDialog(context, _profiles.gestures,
        baslik: l10n.cardNightPickGesture);
    if (jest == null) return;
    if (!mounted) return;
    final ok = await _confirm(
        l10n.cardNightMode,
        l10n.cardNightBody(jest),
        onay: l10n.flowAddToQueue);
    if (!ok) return;
    try {
      final op = await CardFlowService.reanimate(
          collection: 'all', gesture: jest, includeDealers: true);
      _watch(op);
      _snack(op.isEmpty
          ? l10n.cardQueued
          : l10n.cardQueuedOp(op));
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
        l10n.cardRestillTitle,
        l10n.cardRestillBody,
        onay: l10n.flowAddToQueue);
    if (!ok) return;
    try {
      final op = await CardFlowService.restill(
          collection: 'all', includeDealers: true);
      _watch(op);
      _snack(l10n.cardQueued);
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
        title: Text(l10n.cardManifestPreview),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.cardManifestCounts(koleksiyonlar, krupiyeler),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(l10n.cardManifestNote,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 10),
              SelectableText(m.toString(),
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: Text(l10n.close)),
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
            // #352: koleksiyon ayarlari listeden de acilir.
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(l10n.cardCollectionCardSettings),
              subtitle: Text(l10n.cardCollectionCardSettingsHint,
                  style: const TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(c, 'card'),
            ),
            ListTile(
              leading: const Icon(Icons.autorenew),
              title: Text(l10n.cardReanimate),
              subtitle: Text(l10n.cardReanimateHint,
                  style: const TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(c, 'reanimate'),
            ),
            // #325: anime koleksiyonu gercekci kadina cevirir (id/ad degismez).
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.cardRealify),
              subtitle: Text(l10n.cardRealifyHint,
                  style: const TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(c, 'realify'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(l10n.cardDeleteCollection,
                  style: TextStyle(color: AppColors.error)),
              subtitle: Text(l10n.cardDeleteCollectionHint,
                  style: const TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(c, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (secim == null || !mounted) return;
    if (secim == 'card') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CardTemplatesScreen(collection: id, title: ad, kind: 'card'),
      ));
      _load();
      return;
    }
    if (secim == 'delete') {
      await _deleteEntry(id, ad, kind: 'card');
      return;
    }
    try {
      // Eski Grok videosunu yeniden kesme yolu kaldirildi (kullanici: yeniden
      // canlandirma zaten still'den yeni video uretiyor).
      if (secim == 'reanimate') {
        final jest = await gestureDialog(context, _profiles.gestures);
        if (jest == null || !mounted) return;
        final op = await CardFlowService.reanimate(
            collection: id, gesture: jest, includeDealers: false);
        _watch(op);
      } else if (secim == 'realify') {
        _watch(await CardFlowService.realify(collection: id, kind: _kind));
      }
      _snack(l10n.cardQueued);
    } on CardNotReadyException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// #352: koleksiyonu ya da krupiyeyi klasoruyle siler - GERI ALINAMAZ.
  Future<void> _deleteEntry(String id, String ad, {required String kind}) async {
    final krupiye = kind == 'dealer';
    final ok = await _confirm(
        krupiye
            ? l10n.cardDeleteDealerTitle(ad)
            : l10n.cardDeleteCollectionTitle(ad),
        krupiye ? l10n.cardDeleteDealerBody : l10n.cardDeleteCollectionBody,
        onay: l10n.delete);
    if (!ok) return;
    try {
      await CardFlowService.deleteCollection(id, kind: kind);
      _snack(l10n.cardDeletedNamed(ad));
    } on CardNotReadyException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
    _load();
  }

  /// #352: krupiye satirina basili tutunca - ayarlar / sil.
  Future<void> _dealerMenu(CardDealer d) async {
    final secim = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                dense: true,
                title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold))),
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(l10n.cardDealerCardSettings),
              subtitle: Text(l10n.cardDealerCardSettingsHint,
                  style: const TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(c, 'card'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(l10n.cardDeleteDealer, style: TextStyle(color: AppColors.error)),
              subtitle: Text(l10n.cardDeleteDealerHint,
                  style: const TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(c, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (secim == null || !mounted) return;
    if (secim == 'card') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            CardTemplatesScreen(collection: d.id, title: d.name, kind: 'dealer'),
      ));
      _load();
    } else if (secim == 'delete') {
      await _deleteEntry(d.id, d.name, kind: 'dealer');
    }
  }

  // ------------------------------------------------------------ gorunum
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(l10n.cardFlowTitle),
          // #353: hat anahtari app bar'in altinda tam genislikte.
          bottom: kindSwitchBottom(widget.kindSwitch),
          actions: [
            IconButton(
              icon: const Icon(Icons.code),
              tooltip: l10n.assetCodeMode,
              onPressed: () => ModeService.set(false),
            ),
            IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: l10n.refresh,
                onPressed: _load),
            PopupMenuButton<String>(
              tooltip: l10n.cardBulkActions,
              onSelected: (v) => switch (v) {
                'night' => _reanimateAll(),
                'restill' => _restillAll(),          // #325
                _ => _manifestPreview(),
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'night', child: Text(l10n.cardNightMenu)),
                PopupMenuItem(
                    value: 'restill', child: Text(l10n.cardRestillMenu)),
                PopupMenuItem(
                    value: 'manifest', child: Text(l10n.cardManifestMenu)),
              ],
            ),
          ],
        ),
        floatingActionButton: _soon
            ? null
            : FloatingActionButton.extended(
                onPressed: _dealerMode ? _newDealer : _newCollection,
                icon: const Icon(Icons.add),
                label: Text(_dealerMode ? l10n.cardNewDealer : l10n.cardNewCollection),
              ),
        body: Column(
          children: [
            _kindBar(),
            if (_op != null && _op!.running) _opBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _soon
                      ? cardSoonView(_dealerMode ? l10n.cardDealers : l10n.cardFlowTitle)
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            l10n.cardEmptyCollections,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            l10n.cardEmptyDealers,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
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
        onLongPress: () => _dealerMenu(d),          // #352: ayarlar / sil
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
                      Text(l10n.cardGestureLine(d.gesture),
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
  AppLocalizations get l10n => AppLocalizations.of(context)!;

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
    var hata = 0;
    _opPoll = Timer.periodic(const Duration(seconds: 3), (t) async {
      try {
        final o = await CardFlowService.op(opId);
        if (!mounted) return;
        hata = 0;
        setState(() => _op = o);
        if (!o.running) {
          t.cancel();
          _snack(o.status == 'error'
              ? l10n.flowOpError(o.message)
              : o.status == 'cancelled'
                  ? l10n.flowOpCancelled
                  : o.failed > 0
                      ? l10n.flowOpDoneWithFailed(o.ok, o.failed)
                      : l10n.flowOpDone(o.ok));
          _load();
        }
      } catch (_) {
        // #352: gecici ag hatasi cubugu donmus birakmasin - 3 ardisik hatada birak.
        if (++hata >= 3) {
          t.cancel();
          if (mounted) setState(() => _op = null);
        }
      }
    });
  }

  Future<bool> _confirm(String baslik, String metin,
          {String? onay}) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          scrollable: true,
          title: Text(baslik),
          content: Text(metin),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(onay ?? l10n.continueLabel)),
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
      if (!mounted) return;
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
    // #362: her kart = 2 animasyon (idle + victory). Toplu dugme ikisini de
    // acar; tek etiket / serbest prompt icin kart detayindaki 2 Video kalir.
    final motorlar = _c?.videoEngines ?? const <CardEngine>[];
    var motor = _c?.videoEngine ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: Text(l10n.cardAnimateTitle(r.length)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.cardAnimateBody(r.length * 2),
                  style: const TextStyle(fontSize: 12)),
              if (motorlar.length > 1) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: motorlar.any((e) => e.id == motor) ? motor : motorlar.first.id,
                  isExpanded: true,
                  decoration: InputDecoration(
                      isDense: true,
                      border: const OutlineInputBorder(),
                      labelText: l10n.engine),
                  items: [
                    for (final e in motorlar)
                      DropdownMenuItem(
                          value: e.id,
                          enabled: e.available,
                          child: Text(e.label, style: const TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) => setLocal(() => motor = v ?? motor),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l10n.generate)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final op = await CardFlowService.animateSet(
          collection: widget.id, ranks: r, engine: motor);
      if (!mounted) return;
      setState(_sel.clear);
      _watch(op);
      _snack(queueSnackText(r.length * 2));
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
      // #362: videosu olan her animasyon kesilir (kart basina 2 webp).
      final op = await CardFlowService.cut(
          collection: widget.id, ranks: r, mode: mode, anim: CardFlowService.allAnims);
      if (!mounted) return;
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
      _snack(l10n.cardEditNeedsOne);
      return;
    }
    final rank = _sel.first;
    final ist = await cardEditDialog(context, '${widget.title} $rank');
    if (ist == null) return;
    try {
      final op = await CardFlowService.edit(
          collection: widget.id, rank: rank, prompt: ist.prompt, nsfw: ist.nsfw);
      if (!mounted) return;
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
        l10n.cardPushTitle(widget.title),
        l10n.cardPushBody(w, _ranks.length),
        onay: l10n.flowPush);
    if (!ok) return;
    try {
      final op = await CardFlowService.push(collection: widget.id);
      if (!mounted) return;
      setState(_sel.clear);
      _watch(op);
      _snack(l10n.cardPushQueued);
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
                  tooltip: l10n.bucketsClearSelection,
                  onPressed: () => setState(_sel.clear))
              : null,
          title: Text(_selecting ? l10n.bucketsSelectedCount(_sel.length) : widget.title),
          actions: [
            if (_selecting)
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: l10n.flowSelectAll,
                onPressed: () => setState(() => _sel.addAll(_ranks)),
              ),
            // #352: Koleksiyon Karti (16 yuva + model + yuz rotusu) artik
            // DOGRUDAN erisilir - eskiden yalniz bir kart secince cikan alt
            // cubuktaki "Kart" dugmesinin arkasindaydi, bulunamiyordu.
            IconButton(
                icon: const Icon(Icons.tune),
                tooltip: l10n.cardCollectionCardTooltip,
                onPressed: _sablonlariAc),
            IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: l10n.refresh,
                onPressed: _load),
            PopupMenuButton<String>(
              tooltip: l10n.commonMore,
              onSelected: (v) => switch (v) {
                'delete' => _deleteCollection(),
                _ => _sablonlariAc(),
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'card', child: Text(l10n.cardCollectionCardSettings)),
                PopupMenuItem(
                    value: 'delete', child: Text(l10n.cardDeleteCollection)),
              ],
            ),
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
                      _temaSeridi(),
                      _stageButtons(),
                      Expanded(child: _grid()),
                    ],
                  ),
      );

  /// #347: sablon ekrani - 13 rutbenin eksenleri, kilitleri ve manuel metni.
  Future<void> _sablonlariAc() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CardTemplatesScreen(
          collection: widget.id, title: widget.title, kind: 'card'),
    ));
    if (mounted) _load();
  }

  /// #346/#352: koleksiyonun KARTI - temasi en ustte durur; dokununca
  /// Koleksiyon Karti EKRANI acilir (tema + 16 yuva + model + yuz rotusu).
  /// Eskiden buradan eski kucuk tema penceresi aciliyordu, yeni ekran
  /// baska bir yolun arkasinda kaliyordu.
  Widget _temaSeridi() {
    final tema = _c?.theme ?? '';
    return InkWell(
      onTap: _sablonlariAc,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.style_outlined, size: 15, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  tema.isEmpty
                      ? l10n.cardNoThemeTap
                      : l10n.cardThemeTap(tema),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      color: tema.isEmpty ? AppColors.error : Colors.grey)),
            ),
            const Icon(Icons.tune, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  /// #352: koleksiyonu klasoruyle siler - GERI ALINAMAZ.
  Future<void> _deleteCollection() async {
    final (s, _, _, p) = _c?.progress ?? (0, 0, 0, 0);
    final ok = await _confirm(
        l10n.cardDeleteCollectionTitle(widget.title),
        p > 0
            ? l10n.cardDeleteCollectionStillsPushed(s, p)
            : l10n.cardDeleteCollectionStills(s),
        onay: l10n.delete);
    if (!ok) return;
    try {
      await CardFlowService.deleteCollection(widget.id, kind: 'card');
      if (!mounted) return;
      Navigator.of(context).pop();
    } on CardNotReadyException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// #352: secili kartlari BOSA dondurur (still/aday/video/sheet silinir,
  /// rutbe kalir) - begenilmeyen kart atilip "1 Still" ile yeniden uretilir.
  Future<void> _clearSelected() async {
    final r = _sel.toList()..sort();
    if (r.isEmpty) return;
    final ok = await _confirm(
        l10n.cardClearCards,
        l10n.cardClearCardsBody(r.join(', ')),
        onay: l10n.clear);
    if (!ok) return;
    var hata = 0;
    for (final rank in r) {
      try {
        await CardFlowService.clearRank(widget.id, rank, kind: 'card');
      } catch (_) {
        hata++;
      }
    }
    if (!mounted) return;
    setState(_sel.clear);
    _snack(hata == 0 ? l10n.cardsCleared(r.length) : l10n.cardsClearFailed(hata));
    _load();
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

  /// Koleksiyon duzeyinde dort asama: 1 Still · 2 Video · 3 WebP · 4 Push.
  Widget _stageButtons() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            _stageButton(Icons.image_outlined, l10n.cardGenerateStill,
                () => _stills(hepsi: true)),
            const SizedBox(width: 8),
            _stageButton(Icons.movie_creation_outlined, l10n.cardGenerateVideo,
                () => _animate(hepsi: true)),
            const SizedBox(width: 8),
            _stageButton(Icons.content_cut, l10n.cardGenerateWebp, () => _cut(hepsi: true)),
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
              _act(Icons.edit_outlined, l10n.edit, _edit),
              // #352: begenilmeyen karti at (rutbe bosa doner).
              _act(Icons.delete_sweep_outlined, l10n.clear, _clearSelected),
            ],
          ),
        ),
      );

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
        // #353: son hucre kart ARKASI (sunucu `back` veriyorsa). Secime
        // girmez - yalniz still/duzenle/aday; video/kesim/push'a dahil degil.
        itemCount: _ranks.length + (c.back != null ? 1 : 0),
        itemBuilder: (_, i) => i < _ranks.length
            ? _cell(c, _ranks[i])
            : _cell(c, CardCollection.backRank, arka: true),
      ),
    );
  }

  Widget _cell(CardCollection c, String rank, {bool arka = false}) {
    final s = arka ? (c.back ?? const CardRankState()) : c.stateOf(rank);
    final secili = !arka && _sel.contains(rank);
    if (arka) {
      final url = CardFlowService.thumbUrl(c.id, rank,
          kind: 'still', size: 300, v: s.rev > 0 ? s.rev : c.rev);
      return GestureDetector(
        onTap: () => _open(rank),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black26),
                if (s.still)
                  Image.network(url,
                      headers: CardFlowService.authHeaders,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(color: Colors.white10))
                else
                  Container(
                    color: Colors.white10,
                    alignment: Alignment.center,
                    child: const Icon(Icons.style_outlined, size: 22, color: Colors.grey),
                  ),
                Positioned(
                  left: 3,
                  top: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: s.still ? Colors.deepPurple.shade400 : Colors.white10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(l10n.cardBackUpper,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: s.still ? Colors.white : Colors.grey)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
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
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  String _view = 'still';
  CardRankState _state = const CardRankState();
  CardProfilesInfo _profiles = const CardProfilesInfo();

  bool _loading = true;
  String? _error;
  FlowOp? _op;
  Timer? _opPoll;

  /// #336: bu rutbenin aday still'leri (secilebilir/silinebilir).
  List<CardCandidate> _adaylar = const [];
  /// #338: bu rutbenin animasyonlari (idle + zafer gibi ekler).
  List<CardAnim> _anims = const [];
  /// Uzerinde calisilan animasyon - 2 Video ve 3 WebP buna yazar.
  String _anim = 'idle';
  /// #357: bu rutbenin video HAVUZU - uretilen her video once buraya duser,
  /// kullanici secip etikete atar.
  List<CardVideo> _videos = const [];
  String _engine = '';
  List<CardEngine> _engines = const [];

  bool get _dealer => widget.kind == 'dealer';
  /// #353: kart ARKASI - yalniz still / duzenle / aday (video-kesim yok).
  bool get _arka => !_dealer && widget.rank.toUpperCase() == CardCollection.backRank;
  List<String> get _gestures =>
      _dealer ? _profiles.dealerGestures : _profiles.gestures;
  Map<String, String> get _gestureTexts =>
      _dealer ? _profiles.dealerGestureTexts : _profiles.gestureTexts;

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
        s = _arka
            ? (c?.back ?? const CardRankState())
            : (c?.stateOf(widget.rank) ?? const CardRankState());
        _engine = c?.videoEngine ?? '';
        _engines = c?.videoEngines ?? const [];
      }
      var adaylar = const <CardCandidate>[];
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
      // #357: havuz (eski sunucuda bos doner).
      final havuz = _arka
          ? const CardVideos()
          : await CardFlowService.videos(widget.collection, widget.rank,
              kind: widget.kind);
      if (!mounted) return;
      setState(() {
        _profiles = p;
        _state = s;
        _adaylar = adaylar;
        _anims = anims;
        _videos = havuz.videos;
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
    var hata = 0;
    _opPoll = Timer.periodic(const Duration(seconds: 3), (t) async {
      try {
        final o = await CardFlowService.op(opId);
        if (!mounted) return;
        hata = 0;
        setState(() => _op = o);
        if (!o.running) {
          t.cancel();
          _snack(o.status == 'error'
              ? l10n.flowOpError(o.message)
              : o.status == 'cancelled'
                  ? l10n.flowOpCancelled
                  : o.failed > 0
                      ? l10n.flowOpDoneWithFailed(o.ok, o.failed)
                      : l10n.flowOpDone(o.ok));
          _load();
        }
      } catch (_) {
        // #352: gecici ag hatasi cubugu donmus birakmasin - 3 ardisik hatada birak.
        if (++hata >= 3) {
          t.cancel();
          if (mounted) setState(() => _op = null);
        }
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
      _snack(l10n.cardRunFailed(ad, e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _edit() async {
    final ist = await cardEditDialog(context, widget.title);
    if (ist == null) return;
    await _run(
        l10n.edit,
        () => CardFlowService.edit(
            collection: widget.collection,
            rank: widget.rank,
            prompt: ist.prompt,
            kind: widget.kind,
            nsfw: ist.nsfw));
  }

  Future<void> _redoStill() async => _run(
      '1 Still',
      () => CardFlowService.stills(
          collection: widget.collection, ranks: _ranks, kind: widget.kind));

  Future<void> _redoAnim() async {
    // #357: prompt ile etiket ayri - pencereden hem cumle hem hedef secilir.
    final ist = await videoDialog(context,
        gestures: _gestures,
        gestureTexts: _gestureTexts,
        anims: [for (final a in _anims) a.name],
        engines: _engines,
        engine: _engine,
        tag: _anim,
        secili: _state.gesture);
    if (ist == null) return;
    await _run(
        '2 Video',
        () => CardFlowService.animate(
            collection: widget.collection,
            ranks: _ranks,
            gesture: ist.gesture,
            kind: widget.kind,
            anim: ist.tag,
            poolOnly: ist.poolOnly,
            engine: ist.engine));
  }

  /// #357: SECILI gorunumu (still / video / kesim) tek basina siler.
  /// Ust bardaki cop butun rutbeyi temizler; bu yalniz bakilan varligi.
  Future<void> _deleteAsset() async {
    final what = _view == 'cut' ? 'sheet' : _view;
    final ad = switch (what) {
      'video' => l10n.cardAssetVideo(_anim),
      'sheet' => l10n.cardAssetSheet(_anim),
      _ => 'Still',
    };
    final var_ = switch (what) {
      'video' => _anims.any((a) => a.name == _anim && a.video) || _state.video,
      'sheet' => _anims.any((a) => a.name == _anim && a.sheet) || _state.sheet,
      _ => _state.still,
    };
    if (!var_) {
      _snack(l10n.cardAssetMissing(ad));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.cardAssetDeleteConfirm(ad)),
        content: Text(switch (what) {
          'video' => l10n.cardAssetDeleteVideoBody,
          'sheet' => l10n.cardAssetDeleteSheetBody,
          _ => l10n.cardAssetDeleteStillBody,
        }),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CardFlowService.deleteAsset(widget.collection, widget.rank, what,
          kind: widget.kind, anim: what == 'still' ? '' : _anim);
      if (!mounted) return;
      _snack(l10n.cardDeletedNamed(ad));
      await _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ------------------------------------------------------ #357 video havuzu
  Future<void> _videoAta(CardVideo v, String tag) async {
    try {
      await CardFlowService.assignVideo(widget.collection, widget.rank, v.id, tag,
          kind: widget.kind);
      if (!mounted) return;
      _snack('$tag <- ${v.id}');
      setState(() => _anim = tag);
      await _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _videoSil(CardVideo v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.cardPoolDelete),
        content: Text(l10n.cardPoolDeleteBody(
            v.id, v.tags.isEmpty ? l10n.cardNone : v.tags.join(', '))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CardFlowService.deleteVideo(widget.collection, widget.rank, v.id,
          kind: widget.kind);
      if (!mounted) return;
      await _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<String?> _yeniEtiketAdi() async {
    final c = TextEditingController();
    final ad = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cardNewAnimTag),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.commonName,
            hintText: l10n.cardTagHint,
            helperText: l10n.cardNewAnimTagHelp,
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: Text(l10n.add)),
        ],
      ),
    );
    final t = (ad ?? '').trim().toLowerCase();
    return t.isEmpty ? null : t;
  }

  /// Havuz videosuna dokununca: onizle / etikete ata / yeni etiket / sil.
  Future<void> _videoMenu(CardVideo v) async {
    final secim = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(c).bottom + 8),
          children: [
            ListTile(
              dense: true,
              title: Text(v.id, style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                  '${v.engine.isNotEmpty ? '${v.engine} · ' : ''}'
                  '${v.tags.isEmpty ? l10n.cardUnassigned : l10n.cardAssignedTo(v.tags.join(', '))}'
                  '${v.prompt.isNotEmpty ? '\n${v.prompt}' : ''}',
                  style: const TextStyle(fontSize: 11)),
            ),
            const Divider(height: 8),
            ListTile(
              dense: true,
              leading: const Icon(Icons.play_circle_outline),
              title: Text(l10n.flowPreview),
              onTap: () => Navigator.pop(c, 'play'),
            ),
            for (final a in _anims)
              ListTile(
                dense: true,
                leading: Icon(v.tags.contains(a.name)
                    ? Icons.check_box
                    : Icons.label_outline),
                title: Text(l10n.cardAssignTo(a.name)),
                onTap: () => Navigator.pop(c, 'ata:${a.name}'),
              ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.add),
              title: Text(l10n.cardAssignNewTag),
              onTap: () => Navigator.pop(c, 'yeni'),
            ),
            ListTile(
              dense: true,
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(l10n.cardPoolDelete),
              onTap: () => Navigator.pop(c, 'sil'),
            ),
          ],
        ),
      ),
    );
    if (secim == null || !mounted) return;
    if (secim == 'play') {
      await showDialog<void>(
        context: context,
        builder: (c) => Dialog(
          child: AspectRatio(
            aspectRatio: _dealer ? 3 / 2 : 2 / 3,
            child: NetworkVideo(
              url: CardFlowService.relFileUrl(v.rel, v: v.rev),
              headers: CardFlowService.authHeaders,
            ),
          ),
        ),
      );
    } else if (secim.startsWith('ata:')) {
      await _videoAta(v, secim.substring(4));
    } else if (secim == 'yeni') {
      final t = await _yeniEtiketAdi();
      if (t != null) await _videoAta(v, t);
    } else if (secim == 'sil') {
      await _videoSil(v);
    }
  }

  /// Animasyon kutusuna uzun basinca: havuzdan ata / video sil / webp sil / etiket sil.
  Future<void> _animMenu(CardAnim a) async {
    final secim = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(c).bottom + 8),
          children: [
            ListTile(
                dense: true,
                title: Text(a.name, style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                    a.stage >= 3 ? l10n.cardAnimReady : (a.video ? l10n.cardAnimVideoOnly : l10n.cardStageEmpty),
                    style: const TextStyle(fontSize: 11))),
            const Divider(height: 8),
            for (final v in _videos)
              ListTile(
                dense: true,
                leading: Icon(v.tags.contains(a.name) ? Icons.check_box : Icons.movie_outlined),
                title: Text(l10n.cardAssignTo(v.id), style: const TextStyle(fontSize: 13)),
                subtitle: v.prompt.isEmpty
                    ? null
                    : Text(v.prompt, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11)),
                onTap: () => Navigator.pop(c, 'ata:${v.id}'),
              ),
            if (_videos.isEmpty)
              ListTile(
                  dense: true,
                  title: Text(l10n.cardPoolEmpty,
                      style: const TextStyle(fontSize: 12, color: Colors.grey))),
            if (a.video)
              ListTile(
                dense: true,
                leading: Icon(Icons.delete_outline, color: AppColors.error),
                title: Text(l10n.cardDeleteVideoKeepTag),
                onTap: () => Navigator.pop(c, 'video'),
              ),
            if (a.sheet)
              ListTile(
                dense: true,
                leading: Icon(Icons.delete_outline, color: AppColors.error),
                title: Text(l10n.cardDeleteSheet),
                onTap: () => Navigator.pop(c, 'sheet'),
              ),
            if (!a.isIdle)
              ListTile(
                dense: true,
                leading: Icon(Icons.label_off_outlined, color: AppColors.error),
                title: Text(l10n.cardDeleteTag),
                onTap: () => Navigator.pop(c, 'etiket'),
              ),
          ],
        ),
      ),
    );
    if (secim == null || !mounted) return;
    if (secim.startsWith('ata:')) {
      final v = _videos.where((x) => x.id == secim.substring(4)).firstOrNull;
      if (v != null) await _videoAta(v, a.name);
    } else if (secim == 'video' || secim == 'sheet') {
      try {
        await CardFlowService.deleteAsset(widget.collection, widget.rank, secim,
            kind: widget.kind, anim: a.name);
        if (!mounted) return;
        await _load();
      } catch (e) {
        _snack(e.toString().replaceFirst('Exception: ', ''));
      }
    } else if (secim == 'etiket') {
      await _animSil(a.name);
    }
  }

  /// #357: havuz seridi - videolar yan yana, altinda atandigi etiketler.
  Widget _videolarSeridi() {
    if (_videos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.cardVideosHeader(_videos.length),
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          SizedBox(
            height: 138,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _videos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (c, i) {
                final v = _videos[i];
                final atandi = v.tags.isNotEmpty;
                return InkWell(
                  onTap: () => _videoMenu(v),
                  child: SizedBox(
                    width: 76,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 72,
                            height: 108,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: atandi ? AppColors.accent : Colors.white24,
                                  width: atandi ? 2 : 1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Image.network(
                              CardFlowService.relThumbUrl(v.rel, size: 200, v: v.rev),
                              headers: CardFlowService.authHeaders,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Center(
                                  child: Icon(Icons.movie_outlined, size: 18)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(atandi ? v.tags.join(', ') : l10n.cardUnassigned,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 10,
                                color: atandi ? AppColors.accent : Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
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

  /// #352: kart -> rutbeyi bosa dondur (still/aday/video/sheet silinir);
  /// krupiye -> krupiyeyi klasoruyle sil. Ikisi de onaylidir.
  Future<void> _deleteThis() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        scrollable: true,
        title: Text(_dealer ? l10n.cardDeleteDealer : l10n.cardClearCard),
        content: Text(_dealer
            ? l10n.cardDeleteThisDealerBody(widget.title)
            : l10n.cardClearCardBody(widget.title)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(_dealer ? l10n.delete : l10n.clear)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (_dealer) {
        await CardFlowService.deleteCollection(widget.collection, kind: 'dealer');
      } else {
        await CardFlowService.clearRank(widget.collection, widget.rank,
            kind: widget.kind);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
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
          title: Text(widget.title),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: l10n.refresh,
                onPressed: _load),
            IconButton(
                icon: Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: _dealer ? l10n.cardDeleteDealer : l10n.cardClearCardTooltip,
                onPressed: _deleteThis),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? errorView(_error!, _load)
                : Column(
                    children: [
                      // #361: govde KAYDIRILIR - havuz + animasyon kutulari +
                      // adaylar eklenince onizleme minicik kaliyordu.
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                      if (_op != null && _op!.running)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: LinearProgressIndicator(value: _op!.progress),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: SegmentedButton<String>(
                                segments: [
                                  const ButtonSegment(value: 'still', label: Text('Still')),
                                  // #353: kart arkasinin videosu/kesimi yoktur.
                                  if (!_arka) ...[
                                    const ButtonSegment(value: 'video', label: Text('Video')),
                                    ButtonSegment(value: 'cut', label: Text(l10n.cardViewCut)),
                                  ],
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
                            // #357: YALNIZ bakilan varligi sil (ust bardaki cop
                            // butun rutbeyi temizler).
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: AppColors.error),
                              tooltip: switch (_view) {
                                'video' => l10n.cardDeleteThisVideo(_anim),
                                'cut' => l10n.cardDeleteSheetTag(_anim),
                                _ => l10n.cardDeleteStill,
                              },
                              visualDensity: VisualDensity.compact,
                              onPressed: _deleteAsset,
                            ),
                          ],
                        ),
                      ),
                      // Onizleme: ekranin yarisi (en fazla 2:3 kadraj).
                      SizedBox(
                        height: (MediaQuery.sizeOf(context).height * 0.5)
                            .clamp(240.0, MediaQuery.sizeOf(context).width * 1.5),
                        child: _preview(),
                      ),
                      _info(),
                      if (!_arka) _videolarSeridi(),    // #357: havuz
                      if (!_arka) _animSeridi(),        // #353: arkada animasyon yok
                      _adaylarSeridi(),
                      const SizedBox(height: 8),
                          ],
                        ),
                      ),
                      _buttons(),
                    ],
                  ),
      );

  Widget _preview() {
    switch (_view) {
      case 'video':
        if (!_state.video) return _bos(l10n.cardNoVideo);
        return NetworkVideo(
          url: CardFlowService.fileUrl(widget.collection, widget.rank,
              kind: 'video', v: _state.rev, type: widget.kind),
          headers: CardFlowService.authHeaders,
        );
      case 'cut':
        if (!_state.sheet) return _bos(l10n.cardNoCut);
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
                    Center(child: Text(l10n.cardCutFrameFailed)),
              ),
            ),
          ),
        );
      default:
        if (!_state.still) return _bos(l10n.cardNoStill);
        return InteractiveViewer(
          child: Center(
            child: Image.network(
              CardFlowService.thumbUrl(widget.collection, widget.rank,
                  kind: 'still', size: 900, v: _state.rev, type: widget.kind),
              headers: CardFlowService.authHeaders,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Center(child: Text(l10n.cardStillFailed)),
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
                    title: Text(_state.age > 0 ? l10n.cardPromptTitleAge(_state.age) : 'Prompt'),
                    content: SelectableText(_state.prompt,
                        style: const TextStyle(fontSize: 12)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: Text(l10n.close)),
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
              Text(l10n.cardGestureLine(_state.gesture),
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
                        l10n.cardGuardFail,
                        style:
                            TextStyle(fontSize: 11, color: AppColors.error)),
                  ),
                ],
              ),
            ],
          ],
        ),
      );

  /// #338/#357: animasyon KUTULARI - her etiket (idle, wink, victory ...) bir
  /// kutu: atanmis videonun ilk karesi + ad + asama. Dokun = sec (2 Video /
  /// 3 WebP buna calisir), uzun bas = havuzdan ata / sil. "+ Yeni" etiket acar.
  Widget _animSeridi() {
    final liste = _anims.isEmpty ? const [CardAnim(name: 'idle')] : _anims;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.cardAnimsHeader,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          SizedBox(
            height: 118,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final a in liste) ...[
                  _animKutu(a),
                  const SizedBox(width: 8),
                ],
                InkWell(
                  onTap: _animEkle,
                  child: Container(
                    width: 64,
                    height: 96,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, size: 20),
                        Text(l10n.flowNew,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _animKutu(CardAnim a) {
    final secili = a.name == _anim;
    final thumb = a.video && a.dir.isNotEmpty
        ? CardFlowService.relThumbUrl('${a.dir}/video.mp4', size: 200, v: _state.rev)
        : '';
    return InkWell(
      onTap: () => setState(() => _anim = a.name),
      onLongPress: () => _animMenu(a),
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 96,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                border: Border.all(
                    color: secili ? AppColors.accent : Colors.white24,
                    width: secili ? 2 : 1),
                borderRadius: BorderRadius.circular(6),
                color: Colors.black26,
              ),
              child: thumb.isEmpty
                  ? const Center(
                      child: Icon(Icons.movie_creation_outlined,
                          size: 18, color: Colors.grey))
                  : Image.network(thumb,
                      headers: CardFlowService.authHeaders,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.movie_outlined, size: 18))),
            ),
            const SizedBox(height: 2),
            Text(
                '${a.name}${a.stage >= 3 ? ' ✓' : (a.stage == 2 ? ' ▶' : '')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: secili ? FontWeight.bold : FontWeight.normal,
                    color: secili ? AppColors.accent : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Future<void> _animEkle() async {
    final t = await _yeniEtiketAdi();
    if (!mounted || t == null || _anims.any((a) => a.name == t)) return;
    // Klasor ilk atamada/uretimde acilir; simdilik kutuyu gosterip secmek yeter.
    setState(() {
      _anims = [..._anims, CardAnim(name: t)];
      _anim = t;
    });
    if (_videos.isEmpty) {
      _snack(l10n.cardAnimOpened(t));
      return;
    }
    // #357: havuzda video varsa hemen sec-ata.
    final v = await showModalBottomSheet<CardVideo>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(c).bottom + 8),
          children: [
            ListTile(
                dense: true,
                title: Text(l10n.cardPickPoolVideo(t),
                    style: const TextStyle(fontSize: 13))),
            for (final v in _videos)
              ListTile(
                dense: true,
                leading: const Icon(Icons.movie_outlined),
                title: Text(v.id, style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                    v.tags.isEmpty ? l10n.cardUnassigned : v.tags.join(', '),
                    style: const TextStyle(fontSize: 11)),
                onTap: () => Navigator.pop(c, v),
              ),
          ],
        ),
      ),
    );
    if (v != null) await _videoAta(v, t);
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
          Text(l10n.cardCandidatesHeader(_adaylar.length),
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 6),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _adaylar.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (c, i) {
                final ad = _adaylar[i].file;
                final rel = CardFlowService.candidateRel(
                    widget.collection, widget.rank, ad, kind: widget.kind);
                return Stack(
                  children: [
                    InkWell(
                      onTap: () => _adaySec(ad),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          // #356: v = dosya zamani; ad yeniden kullanilinca
                          // bellekteki eski kucuk resim gelmesin.
                          CardFlowService.relThumbUrl(rel,
                              size: 200, v: _adaylar[i].rev),
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
      _snack(l10n.cardCandidatePicked);
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
                  label: Text(l10n.edit)),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                  onPressed: _redoStill,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('1 Still')),
              // #353: kart arkasinin videosu/kesimi yoktur.
              if (!_arka) ...[
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
