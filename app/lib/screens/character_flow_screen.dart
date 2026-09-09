import 'dart:async';

import 'package:flutter/material.dart';

import '../services/character_flow_service.dart';
import '../services/jigsaw_flow_service.dart' show FlowOp;
import '../services/jigsaw_profiles.dart';
import '../services/mode_service.dart';
import '../theme.dart';
import '../widgets/bottom_inset.dart';
import '../widgets/network_video.dart';
import '../widgets/equip_panel.dart';           // #331
import '../widgets/outfit_extract_dialog.dart'; // #329

/// Asset Mod - Karakter hatti (#306, design/karakter_hatti_v2.md).
///
/// Jigsaw/CBN'deki 2-3-4 akisi burada YOKTUR. Uc asama vardir:
///   1 Karakter   "Yeni karakter" otomatik hatti baslatir: base adaylari ->
///                portre -> hikaye -> 7 yon; hepsi onaysiz, tek tek kuyruga
///                girer. Kullanici bitince base'i degistirir, portre/hikaye
///                adaylarindan secer.
///   2 Yon        BASE'in 8 yonu (`base/dirs/`). Burada ANIMASYON YOKTUR -
///                yalniz yenile / sil / aday sec.
///   3 Skinler    Skin = kiyafet. `base` de bir skindir. Her skinin kendi 8
///                yonu ve animasyonlari olur; animasyon skin ustunde yapilir.
///
/// Uzun isler sunucuda kosar, `/op/{id}` ile izlenir (CBN ekranindaki cubuk).
class CharacterFlowScreen extends StatefulWidget {
  const CharacterFlowScreen({super.key, this.kindSwitch});

  /// Ust cubuktaki Jigsaw | CBN | Karakter anahtari (FlowHub verir).
  final Widget? kindSwitch;

  @override
  State<CharacterFlowScreen> createState() => _CharacterFlowScreenState();
}

class _CharacterFlowScreenState extends State<CharacterFlowScreen> {
  List<CharacterItem> _items = [];
  List<CharacterDir> _dirs = CharacterFlowService.defaultDirs;
  bool _loading = true;
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
      final dirs = await CharacterFlowService.dirsList();
      final items = await CharacterFlowService.list();
      if (!mounted) return;
      setState(() {
        _dirs = dirs;
        _items = items;
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

  Future<void> _open(CharacterItem c) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CharacterDetailPage(name: c.name, dirs: _dirs),
    ));
    _load();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// #306: "+ Yeni karakter" - isim + sinif + kimlik promptu. Sunucu otomatik
  /// hatti kurar (base -> portre -> hikaye -> yonler), onay sorulmaz.
  Future<void> _newCharacter() async {
    final sonuc = await characterCreateDialog(context);
    if (sonuc == null) return;
    try {
      await CharacterFlowService.create(
          name: sonuc.name,
          klass: sonuc.klass,
          prompt: sonuc.prompt,
          kind: sonuc.kind);            // #314
      // #306: base secimi kullanicida - burada yalniz aday uretilir.
      _snack('Base adayi siraya eklendi - aday gelince "Base yap" de');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: widget.kindSwitch ?? const Text('Karakter hatti'),
          actions: [
            IconButton(
              icon: const Icon(Icons.code),
              tooltip: 'Code Mod',
              onPressed: () => ModeService.set(false),
            ),
            IconButton(
                icon: const Icon(Icons.refresh), tooltip: 'Yenile', onPressed: _load),
          ],
        ),
        // #306: karakter artik Uretilenler'e bagli degil - buradan da acilir.
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _newCharacter,
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Yeni karakter'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? errorView(_error!, _load)
                : _items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: Text(
                            'Henuz karakter yok.\n\n"+ Yeni karakter" ile isim, sinif ve '
                            'kimlik cumlesi ver - 1 base adayi uretilir, "Base yap" '
                            'dedigin anda portre, hikaye ve yonler kendiliginden '
                            'kosar.\n\nYa da "Uretilenler" ekraninda Karakter '
                            'Modu\'nda bir isi secip "Karakter yap" de - o gorsel '
                            'dogrudan base olur.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: bottomSafePadding(context,
                              left: 12, top: 12, right: 12, bottom: 88),
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _card(_items[i]),
                        ),
                      ),
      );

  /// Basili tutma: karakteri komple siler (geri alinamaz).
  Future<void> _deleteCharacter(CharacterItem c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${c.name} silinsin mi?'),
        content: const Text('Karakter klasoru, adaylari, yonleri, skinleri ve '
            'butun animasyonlari silinir. GERI ALINAMAZ.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgec')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CharacterFlowService.removeCharacter(c.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
    _load();
  }

  Widget _card(CharacterItem c) {
    final (ok, total) = c.spriteProgress;
    final dirsOk = c.dirsDone(_dirs);
    final p = c.pipeline;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(c),
        onLongPress: () => _deleteCharacter(c),
        // #294: dar telefonda tasmasin, daha cok kart sigsin - dikey bosluk
        // kucultuldu, yazilar ellipsis, sayaclar Wrap.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // #294: kucuk resim 9:16 + contain - tam boy kare kirpilmiyor.
              // #306: kart gorseli artik base'in SOUTH karesi.
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 66,
                  height: 117,
                  child: c.southThumb.isEmpty
                      ? Container(
                          color: Colors.white10,
                          child: const Icon(Icons.person_outline, color: Colors.grey))
                      : ColoredBox(
                          color: Colors.black26,
                          child: Image.network(
                            CharacterFlowService.thumbUrl(c.name, c.southThumb,
                                v: c.rev, size: 300),
                            headers: CharacterFlowService.authHeaders,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                Container(color: Colors.white10),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // #314: isim + kucuk tur rozeti (Kadin/Erkek/Hayvan/Makine).
                    Row(
                      children: [
                        Expanded(
                          child: Text(c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        kindBadge(c.kind),
                      ],
                    ),
                    Text(c.klass.isEmpty ? '-' : c.klass,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 6),
                    dirCompass(
                      _dirs,
                      cell: (d) => dirBadge(d, c.dirs[d.id] == true),
                      spacing: 3,
                    ),
                    const SizedBox(height: 6),
                    // #294: tek satir yerine Wrap - dar ekranda alta sarar.
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        for (final t in [
                          'yon $dirsOk/${_dirs.length}',
                          // #306: skin sayaci (base dahil).
                          'skin ${c.skinCount}',
                          'sprite $ok/$total',
                          'aday ${c.candidateCount}',
                        ])
                          Text(t,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    // #306: otomatik hat kosuyorsa kartta ilerleme cubugu.
                    if (p.running) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: p.progress, minHeight: 3),
                      const SizedBox(height: 2),
                      Text(
                          p.step.isEmpty
                              ? 'pipeline calisiyor (${p.done}/${p.total})'
                              : '${p.step} (${p.done}/${p.total})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10, color: AppColors.accent)),
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
}

// ---------------------------------------------------------------- ortak

/// #306: "Yeni karakter" penceresinin sonucu. #314: `kind` = karakter turu.
typedef CharacterCreateResult = ({
  String name,
  String klass,
  String prompt,
  String kind,
});

/// #314: tur ikonlari - liste karti, detay basligi ve pencere segmentleri.
IconData kindIcon(String kind) => switch (kind) {
      'male' => Icons.man,
      'animal' => Icons.pets,
      'machine' => Icons.smart_toy,
      _ => Icons.woman,
    };

/// #314: kucuk tur rozeti (ikon + ad) - karakter kartinda ve detay basliginda.
Widget kindBadge(String kind, {double size = 13, bool label = true}) => Container(
      padding: EdgeInsets.symmetric(horizontal: label ? 5 : 3, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(kindIcon(kind), size: size, color: AppColors.accent),
          if (label) ...[
            const SizedBox(width: 3),
            Text(CharacterFlowService.kindLabel(kind),
                style: TextStyle(fontSize: size - 3, color: AppColors.accent)),
          ],
        ],
      ),
    );

/// #314: ortak "Tur" secici (Kadin · Erkek · Hayvan · Makine). Dar telefonda
/// 4 etiketli segment pencere genisligini asiyordu - o durumda ikon-only'ye
/// duser, ad ipucunda kalir (#289 tasma kurali).
Widget kindSelector({
  required String value,
  required ValueChanged<String> onChanged,
  List<Map<String, String>> kinds = CharacterFlowService.characterKinds,
}) =>
    LayoutBuilder(
      builder: (_, cons) {
        // Etiketli segment ~86px (ikon + ad + ic bosluk); sigmiyorsa ikon-only.
        final dar = cons.maxWidth < 86.0 * kinds.length;
        return SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: [
              for (final k in kinds)
                ButtonSegment(
                  value: '${k['id']}',
                  icon: Icon(kindIcon('${k['id']}'), size: 16),
                  label: dar
                      ? null
                      : Text('${k['label']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11)),
                  tooltip: '${k['label']}',
                ),
            ],
            selected: {value},
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onSelectionChanged: (v) => onChanged(v.first),
          ),
        );
      },
    );

/// #314: turun kimlik cumlesi ipucu (dokuman §3c ozneleri).
String _kindPromptHint(String kind) => switch (kind) {
      'male' => 'orn. kisa siyah sacli, sakalli, atletik savasci adam',
      'animal' => 'orn. a golden retriever dog, short golden fur',
      'machine' => 'orn. a bipedal combat robot, matte white panels, blue optics',
      _ => 'orn. gumus sacli, yesil gozlu, atletik savasci kadin',
    };

/// #314: turun notr base aciklamasi (dokuman §3c "base notr set" satiri).
String _kindBaseNote(String kind) => switch (kind) {
      'male' => 'Base notr sette, siyah boxer + ciplak govde seviyesindedir; '
          'kiyafet 3. sekmedeki skinlerle verilir.',
      'animal' => 'Base giysisizdir: dogal tuy/deri, dogal durus. Tasma, kosum, '
          'pelerin gibi parcalar 3. sekmedeki skinlerle verilir.',
      'machine' => 'Base ciplak govde/sasidir: ek zirh ve boya yok. Zirh plakasi, '
          'boya kiti, silah montaji 3. sekmedeki skinlerle verilir.',
      _ => 'Base her zaman notr set + bikini/ic camasiri seviyesindedir; '
          'kiyafet 3. sekmedeki skinlerle verilir.',
    };

/// #306: isim + sinif + kimlik promptu soran ortak pencere. Hem Karakter
/// hattindaki "+ Yeni karakter" hem Uretilenler'deki "Karakter yap" kullanir
/// (orada prompt yerine secili is gonderilir, alan yine de doldurulabilir).
/// #314: en ustte TUR secimi (Kadin · Erkek · Hayvan · Makine, varsayilan
/// Kadin); sinif listesi ve kimlik ipucu ture gore degisir.
Future<CharacterCreateResult?> characterCreateDialog(
  BuildContext context, {
  String baslik = 'Yeni karakter',
  // #306: base'i KULLANICI secer - prompt yalniz 1 aday kuyruga koyar.
  String aciklama = 'Kimlik cumlesi verilince 1 base adayi kuyruga girer; '
      'otomatik secilmez. Adayi "Base yap" ile sectiginde portre, hikaye ve '
      '7 yon kendiliginden uretilir.',
  bool promptGerekli = true,
}) async {
  // #314: insan turlerinin sinif kaynagi profil dosyasi; hayvan/makine
  // siniflari serviste sabit listede durur.
  final insanSiniflar = await CharacterProfiles.classes();
  if (!context.mounted) return null;
  final ad = TextEditingController();
  final prompt = TextEditingController();
  var tur = 'female';
  List<String> siniflarOf(String k) => CharacterFlowService.isHumanKind(k)
      ? insanSiniflar
      : CharacterFlowService.classesFor(k);
  var siniflar = siniflarOf(tur);
  var sinif = siniflar.isNotEmpty ? siniflar.first : '';
  final sonuc = await showDialog<CharacterCreateResult>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c2, setS) => AlertDialog(
        // Isim alani otomatik odakli: klavye acilinca icerik tasmasin (#289).
        scrollable: true,
        title: Text(baslik),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(aciklama,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              // #314: ONCE tur - sinif listesi, kimlik ipucu ve base notu
              // buna baglidir.
              const Text('Tur',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              kindSelector(
                value: tur,
                onChanged: (v) => setS(() {
                  tur = v;
                  // Tur degisince sinif listesi de degisir - eski deger yeni
                  // listede yoksa ilk siniftan devam edilir.
                  siniflar = siniflarOf(tur);
                  if (!siniflar.contains(sinif)) {
                    sinif = siniflar.isNotEmpty ? siniflar.first : '';
                  }
                }),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ad,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Isim',
                  hintText: 'orn. Freya',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              if (siniflar.isEmpty)
                TextField(
                  // #314: tur degisince serbest metin alani sifirdan kurulur.
                  key: ValueKey('sinif-serbest-$tur'),
                  onChanged: (v) => sinif = v,
                  decoration: const InputDecoration(
                    labelText: 'Sinif',
                    hintText: 'warrior',
                    border: OutlineInputBorder(),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  // #314: tur degisince liste degisir - FormField initialValue'yu
                  // yeniden okumaz, alan sifirdan kurulmali (#313 ile ayni tuzak).
                  key: ValueKey('sinif-$tur'),
                  initialValue: sinif,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sinif',
                    border: OutlineInputBorder(),
                  ),
                  items: siniflar
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setS(() => sinif = v ?? sinif),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: prompt,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: promptGerekli
                      ? 'Kimlik cumlesi'
                      : 'Kimlik cumlesi (istege bagli)',
                  // #314: ipucu ture gore.
                  hintText: _kindPromptHint(tur),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              // #314: notr base aciklamasi da ture gore.
              Text(_kindBaseNote(tur),
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgec')),
          FilledButton(
            onPressed: () => Navigator.pop(
                c,
                (
                  name: ad.text.trim(),
                  klass: sinif.trim(),
                  prompt: prompt.text.trim(),
                  kind: tur,                      // #314
                )),
            child: const Text('Olustur'),
          ),
        ],
      ),
    ),
  );
  if (sonuc == null || sonuc.name.isEmpty) return null;
  if (promptGerekli && sonuc.prompt.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kimlik cumlesi bos olamaz')));
    }
    return null;
  }
  return sonuc;
}

/// 8 yonu pusula duzeninde (3x3, orta hucre serbest) dizer. Sunucu listede
/// tanimadigimiz bir yon gonderirse izgaranin altina eklenir - hicbir yon
/// gozden kaybolmasin.
// #301: gercek pusula dizilimi - North ustte, South (kameraya bakan) altta.
const _compassGrid = [
  ['back_left', 'back', 'back_right'],      // NW  N  NE
  ['left', '', 'right'],                    // W   -  E
  ['front_left', 'front', 'front_right'],   // SW  S  SE
];

Widget dirCompass(
  List<CharacterDir> dirs, {
  required Widget Function(CharacterDir) cell,
  Widget? center,
  double spacing = 6,
}) {
  final byId = {for (final d in dirs) d.id: d};
  final used = <String>{};
  final rows = <Widget>[];
  for (final row in _compassGrid) {
    final cells = <Widget>[];
    for (final id in row) {
      final d = byId[id];
      if (id.isEmpty || d == null) {
        cells.add(Expanded(
            child: Padding(
          padding: EdgeInsets.all(spacing / 2),
          child: center != null && id.isEmpty ? center : const SizedBox.shrink(),
        )));
        continue;
      }
      used.add(id);
      cells.add(Expanded(
        child: Padding(padding: EdgeInsets.all(spacing / 2), child: cell(d)),
      ));
    }
    // stretch DEGIL: pusula ListView icinde durur, sinirsiz yukseklikte
    // stretch sonsuz kisit hatasi verir.
    rows.add(Row(children: cells));
  }
  final extra = dirs.where((d) => !used.contains(d.id)).toList();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ...rows,
      if (extra.isNotEmpty)
        Padding(
          padding: EdgeInsets.only(top: spacing),
          // #294: sabit 90 genislik dar kartta tasiyordu - hucre genisligi
          // artik mevcut genislikten (3 sutun) hesaplanir.
          child: LayoutBuilder(
            builder: (_, cons) {
              final w = ((cons.maxWidth - 2 * spacing) / 3).clamp(40.0, 120.0);
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final d in extra) SizedBox(width: w, child: cell(d)),
                ],
              );
            },
          ),
        ),
    ],
  );
}

/// Karakter kartindaki kucuk yon rozeti - dolu = o yon secilmis.
Widget dirBadge(CharacterDir d, bool on) => Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: on ? AppColors.accent : Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(d.short,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: on ? Colors.white : Colors.grey)),
    );

Widget errorView(String message, VoidCallback retry) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 36),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: retry, child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );

/// Yastiklama secici - yok / %10 / %20 / %30 (`animate.padding`).
class PaddingPicker extends StatelessWidget {
  const PaddingPicker({super.key, required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  static const secenekler = <(double, String)>[
    (0.0, 'Yok'),
    (0.1, '%10'),
    (0.2, '%20'),
    (0.3, '%30'),
  ];

  static String labelOf(double v) =>
      secenekler.firstWhere((e) => (e.$1 - v).abs() < 0.001,
          orElse: () => secenekler.first).$2;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Text('Yastiklama',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(
            child: SegmentedButton<double>(
              segments: [
                for (final s in secenekler)
                  ButtonSegment(
                      value: s.$1,
                      label: Text(s.$2, style: const TextStyle(fontSize: 11))),
              ],
              selected: {value},
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onSelectionChanged: (v) => onChanged(v.first),
            ),
          ),
        ],
      );
}

/// Pusula izgarasindaki tek kucuk resim: gorsel + kabul/ret rozeti + altinda
/// ikon dugmeler (anim / mixamo / duzenle / yenile / sil). Yazi yoktur.
/// #306: anim ve Mixamo ikonlari OPSIYONEL - 2 Yon sekmesinde animasyon yok,
/// yalniz skin detayinda gorunurler. Duzenle (✎) ince ayar icindir.
class _ThumbCell extends StatelessWidget {
  const _ThumbCell({
    required this.label,
    required this.url,
    required this.accepted,
    required this.width,
    required this.thumbHeight,
    required this.onTap,
    required this.onLongPress,
    required this.onRefresh,
    required this.onDelete,
    this.onAnim,
    this.onMixamo,
    this.onEdit,
    this.badge,
    this.dimmed = false,
  });

  final String label;
  final String? url;
  final bool accepted;
  /// #300: kabul edilmemis ama adayi olan hucrede "N aday" rozeti.
  final String? badge;
  /// #300: aday onizlemesi soluk cizilir - kabul edilmisle karismasin.
  final bool dimmed;
  final double width;
  final double thumbHeight;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onAnim;
  final VoidCallback? onMixamo;
  /// #306: ✎ Duzenle - kisa duzeltme cumlesiyle kabul edilen gorseli degistirir.
  final VoidCallback? onEdit;
  final VoidCallback onRefresh;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // rev4: tek dokunus = aday secici / animasyon, basili tutma = buyuk.
            GestureDetector(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Container(
                height: thumbHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: accepted ? Colors.green.shade600 : Colors.white24,
                      width: accepted ? 2 : 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Colors.black26),
                      if (url != null)
                        // #292: cover kirpiyordu - contain, tam boy kare butun
                        // gorunur (kenarlarda koyu serit kalir).
                        Opacity(
                          opacity: dimmed ? 0.55 : 1,
                          child: Image.network(
                            url!,
                            headers: CharacterFlowService.authHeaders,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.white10,
                              alignment: Alignment.center,
                              child: const Icon(Icons.image_not_supported_outlined,
                                  size: 22, color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        Container(
                          color: Colors.white10,
                          alignment: Alignment.center,
                          child: const Icon(Icons.add_photo_alternate_outlined,
                              size: 22, color: Colors.grey),
                        ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Icon(
                          accepted ? Icons.check_circle : Icons.cancel_outlined,
                          size: 14,
                          color: accepted ? Colors.green : Colors.white38,
                        ),
                      ),
                      if (badge != null)
                        // #300: aday sayisi - dokununca secici acilir.
                        Positioned(
                          left: 3,
                          top: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade800,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(badge!,
                                style: const TextStyle(
                                    fontSize: 9, color: Colors.white)),
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          color: Colors.black54,
                          // #292: hucreler buyudu, etiket de okunur olsun.
                          child: Text(label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // #292: Row tasabiliyordu - Wrap hucreye sigmayinca alt satira sarar.
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                if (onAnim != null)
                  _ico(Icons.movie_filter_outlined, 'Anim uret (AI i2v)', onAnim!),
                if (onMixamo != null)
                  _ico(Icons.accessibility_new, 'Mixamo ile uret', onMixamo!),
                if (onEdit != null)
                  _ico(Icons.edit_outlined, 'Duzenle (prompt ile)', onEdit!),
                _ico(Icons.refresh, 'Bunu yeniden uret', onRefresh),
                _ico(Icons.delete_outline, 'Sil', onDelete, color: AppColors.error),
              ],
            ),
          ],
        ),
      );

  Widget _ico(IconData i, String t, VoidCallback f, {Color? color}) => IconButton(
        tooltip: t,
        onPressed: f,
        icon: Icon(i, color: color),
        iconSize: 18,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      );
}

/// Tam boy onizleme penceresi (ortak - detay ve skin ekrani kullanir).
void showBigImage(BuildContext context, String url, String baslik) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: InteractiveViewer(
              child: Image.network(
                url,
                headers: CharacterFlowService.authHeaders,
                errorBuilder: (_, _, _) => const SizedBox(height: 120),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(baslik, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    ),
  );
}

/// #306 ince ayar: "✎ Duzenle" penceresi - kisa duzeltme cumlesi ister.
/// Sonuc sunucuda otomatik kabul edilir; eski gorsel aday olarak kalir, yani
/// begenilmezse aday seciciden geri alinir.
Future<String?> editPromptDialog(BuildContext context, String baslik) async {
  final ctl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      scrollable: true,
      title: Text('Duzenle - $baslik'),
      content: SizedBox(
        width: 460,
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
                hintText: 'orn. sacini kisalt / kilici sol eline al',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
                'Kabul edilen gorsel bu cumleyle duzenlenir; kimlik, poz ve fon '
                'korunur. Yeni gorsel otomatik kabul edilir, eskisi aday olarak '
                'kalir - begenmezsen aday seciciden geri alabilirsin.',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgec')),
        FilledButton(
            onPressed: () => Navigator.pop(c, true), child: const Text('Duzenle')),
      ],
    ),
  );
  if (ok != true) return null;
  final t = ctl.text.trim();
  return t.isEmpty ? null : t;
}

// ---------------------------------------------------------------- detay

/// Tek karakterin uc asamali detayi: 1 Karakter / 2 Yon / 3 Skinler (#306).
class CharacterDetailPage extends StatefulWidget {
  const CharacterDetailPage({super.key, required this.name, required this.dirs});

  final String name;
  final List<CharacterDir> dirs;

  @override
  State<CharacterDetailPage> createState() => _CharacterDetailPageState();
}

class _CharacterDetailPageState extends State<CharacterDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });

  CharacterItem? _item;
  // #302: gorsel URL'lerine karakter rev'i eklenir - secim degisince yenilenir.
  int get _rev => _item?.rev ?? 0;
  String _thumb(String rel, {int size = 360}) =>
      CharacterFlowService.thumbUrl(_name, rel, size: size, v: _rev);
  String _file(String rel) => CharacterFlowService.fileUrl(_name, rel, v: _rev);
  bool _loading = true;
  String? _error;

  FlowOp? _op;
  Timer? _opPoll;
  String _watchedOp = '';

  // 1 Karakter
  String? _candidate;
  /// #299: card.md icin bekleyen Ollama onerileri - pop-up yerine liste.
  List<CardProposal> _proposals = [];

  // 1/2: kac aday uretilecek. #306: ilk tur her seyden BIR adet uretir ve
  // otomatik secer - yeniden uretimde de varsayilan 1'dir (tek aday gelirse
  // sunucu otomatik kabul eder).
  int _dirCount = 1;

  // 3 Skinler (#306)
  List<SkinItem> _skins = [];
  /// #306: kiyafet kutuphanesi - karakterden bagimsiz, her acilista tazelenir.
  List<OutfitItem> _outfits = [];
  bool _outfitsLoading = true;
  /// #313: serit kategori cipi - bos = "Hepsi".
  String _outfitCat = '';

  // 3 Gardirop (#331): RPG giydirme secimi + hedef base (hangi karakter).
  final EquipSelection _equip = EquipSelection();
  List<CharacterItem> _chars = [];
  String _equipTarget = '';

  /// #314: karakterin turu - gardirop ve animasyon buna kilitlidir. Sunucu
  /// alani gondermiyorsa `female`.
  String get _kind => _item?.kind ?? 'female';

  /// #314: gardirop TUR icinde kilitli - bu karakterin turundeki kiyafetler.
  /// Sunucu `?kind=` suzmesini desteklemese de burada tekrar suzulur (turu
  /// olmayan eski kayit `female` sayilir).
  List<OutfitItem> get _kindOutfits =>
      _outfits.where((o) => o.kind == _kind).toList();

  /// #313: secili kategoriye gore suzulmus kiyafet seridi. Sunucu `?category=`
  /// suzmesini desteklemese de burada tekrar suzulur.
  List<OutfitItem> get _visibleOutfits => _outfitCat.isEmpty
      ? _kindOutfits
      : _kindOutfits.where((o) => o.category == _outfitCat).toList();

  /// #313: slug -> kiyafet (skin satirinda parca adlarini yazmak icin).
  OutfitItem? _outfitOf(String slug) {
    for (final o in _outfits) {
      if (o.slug == slug) return o;
    }
    return null;
  }

  /// #313: skin satirindaki parca ozeti - "parca 3: tisort, etek, kilic".
  /// Kutuphanede olmayan slug oldugu gibi yazilir.
  String _piecesLabel(List<String> pieces) =>
      'parca ${pieces.length}: '
      '${pieces.map((p) => _outfitOf(p)?.name ?? p).join(", ")}';

  String get _name => widget.name;
  List<CharacterDir> get _dirs => widget.dirs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _opPoll?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final it = await CharacterFlowService.detail(_name);
      if (!mounted) return;
      setState(() {
        _item = it;
        _loading = false;
        if (_candidate != null && !(it?.candidates.contains(_candidate) ?? false)) {
          _candidate = null;
        }
      });
      // #299: oneriler de her tazelemede yenilenir (enrich op'u bitince
      // _watch zaten _load cagirir).
      await _loadProposals();
      await _loadSkins();
      await _loadOutfits();
      // #306: otomatik hat kosuyorsa op'u kendiliginden izle.
      final p = it?.pipeline;
      if (p != null && p.running && p.op.isNotEmpty && _watchedOp != p.op) {
        _watch(p.op);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// #299: bekleyen hikaye onerilerini ceker. Eski sunucuda uc yoksa bolum
  /// bos kalir - akis bozulmaz.
  Future<void> _loadProposals() async {
    try {
      final p = await CharacterFlowService.cardProposals(_name);
      if (!mounted) return;
      setState(() => _proposals = p);
    } catch (_) {
      // sunucu ucu yok / gecici hata - liste oldugu gibi kalir
    }
  }

  /// #306: skin listesi. Sunucu ucu yoksa liste bos kalir ve ekran base'i
  /// karakterin kendi alanlarindan uydurur (`_skinList`).
  Future<void> _loadSkins() async {
    try {
      final s = await CharacterFlowService.skins(_name);
      if (!mounted) return;
      // base her zaman ilk sirada.
      s.sort((a, b) => (a.isBase ? 0 : 1).compareTo(b.isBase ? 0 : 1));
      setState(() => _skins = s);
    } catch (_) {
      // eski sunucu - `_skinList` yedegi devreye girer
    }
  }

  /// #306: kiyafet kutuphanesi. Sunucu ucu yoksa serit bos kalir - skin
  /// listesi ve animasyon akisi bozulmaz.
  /// #314: karakterin turuyle istenir (`?kind=`); eski sunucu alani yok
  /// sayarsa suzme `_kindOutfits` ile istemcide yapilir.
  Future<void> _loadOutfits() async {
    try {
      final o = await CharacterFlowService.outfits(kind: _kind);
      // #331: base secici icin karakter listesi (ayni turdekiler).
      List<CharacterItem> chars = _chars;
      try {
        chars = (await CharacterFlowService.list())
            .where((c) => c.kind == _kind)
            .toList();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _outfits = o;
        _chars = chars;
        if (_equipTarget.isEmpty) _equipTarget = _name;
        _outfitsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _outfitsLoading = false);
    }
  }

  /// Ekranda gosterilecek skinler. Sunucu `/skins` vermezse en azindan base
  /// satiri cizilir (karakterin base yonleri + anims'i ile).
  List<SkinItem> get _skinList {
    if (_skins.isNotEmpty) return _skins;
    final it = _item;
    if (it == null) return const [];
    return [
      SkinItem(
        slug: 'base',
        name: 'Base',
        south: it.southThumb,
        dirs: it.dirs,
        dirFiles: it.dirFiles,
        dirCandidates: it.dirCandidates,
        anims: it.anims,
        rev: it.rev,
      ),
    ];
  }

  /// CBN ekranindaki izleyicinin aynisi: bitene kadar 2 sn'de bir sorar,
  /// bittiginde listeyi tazeler.
  void _watch(String opId) {
    if (opId.isEmpty) return;
    _opPoll?.cancel();
    _watchedOp = opId;
    var tick = 0;
    _opPoll = Timer.periodic(const Duration(seconds: 2), (t) async {
      try {
        final o = await CharacterFlowService.op(opId);
        if (!mounted) return;
        setState(() => _op = o);
        tick++;
        if (!o.running) {
          t.cancel();
          _watchedOp = '';
          _snack(o.status == 'error'
              ? 'Islem hatasi: ${o.message}'
              : '${o.ok} tamam${o.failed > 0 ? ", ${o.failed} hata" : ""}');
          _load();
        } else if (tick % 10 == 0) {
          _load();
        }
      } catch (_) {
        t.cancel();
        _watchedOp = '';
      }
    });
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// #299: is artik tek sunucu sirasina girer. Kullanici bu ekranda beklemek
  /// zorunda degil - snack Sira sekmesine yollar, ust cubuk yine doner.
  Future<void> _run(String ad, Future<String> Function() f, {int adet = 0}) async {
    try {
      final op = await f();
      _watch(op);
      _snack(adet > 0
          ? '$ad siraya eklendi ($adet is) - Sira sekmesinden izle'
          : '$ad siraya eklendi - Sira sekmesinden izle');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<bool> _confirm(String baslik, String metin) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(baslik),
          content: Text(metin),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Vazgec')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final it = _item;
    return Scaffold(
      appBar: AppBar(
        // #314: baslikta tur rozeti - gardirop ve animasyon buna kilitli.
        title: Row(
          children: [
            Flexible(
                child: Text(_name,
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            kindBadge(_kind),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), tooltip: 'Yenile', onPressed: _load),
          // #306: portre / hikaye / yon adimlarini elle yeniden kosturma.
          PopupMenuButton<String>(
            tooltip: 'Pipeline',
            onSelected: (v) => _run(
                'Pipeline',
                () => CharacterFlowService.pipelineRebuild(_name,
                    steps: v == 'all' ? const [] : [v]),
                adet: v == 'all' ? 9 : 1),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'all', child: Text('Pipeline yeniden kos')),
              PopupMenuItem(value: 'portrait', child: Text('Yalniz portre')),
              PopupMenuItem(value: 'story', child: Text('Yalniz hikaye')),
              PopupMenuItem(value: 'dirs', child: Text('Yalniz yonler')),
            ],
          ),
        ],
        // #330: 4 sekme - Gardirop ayri; skin Gardirop'tan uretilir.
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: '1 Karakter'),
          Tab(text: '2 Yon'),
          Tab(text: '3 Gardirop'),
          Tab(text: '4 Skinler'),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? errorView(_error!, _load)
              : it == null
                  ? errorView('Karakter bulunamadi', _load)
                  : Column(
                      children: [
                        if (_op != null && _op!.running) _opBar(),
                        Expanded(
                          child: TabBarView(
                            controller: _tabs,
                            children: [
                              _tabKarakter(it),
                              _tabYon(it),
                              _tabGardirop(it),      // #330/#331
                              _tabSkinler(it),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _opBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  Widget _countSlider(String etiket) => Row(
        children: [
          Text('$etiket: $_dirCount',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Expanded(
            child: Slider(
              value: _dirCount.toDouble(),
              min: 1,
              max: 6,
              divisions: 5,
              label: '$_dirCount',
              onChanged: (v) => setState(() => _dirCount = v.round()),
            ),
          ),
        ],
      );

  // ------------------------------------------------------- 1 Karakter
  Widget _tabKarakter(CharacterItem it) {
    final adaylar = it.candidates;
    final p = it.pipeline;
    return ListView(
      // Tam ekran route, alt cubuk yok: sistem gezinme cubugunu ekle (#289).
      padding: bottomSafePadding(context,
          left: 12, top: 12, right: 12, bottom: 12),
      children: [
        // #306: solda KARE vesikalik portre, sagda base (South) 9:16.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // #306: her kutuda ✎ Duzenle + ↻ Yeniden uret.
            Expanded(
              // #309: portre kabul edilmemisse en yeni aday soluk + rozet,
              // dokunma aday secicisini acar (asagi kaydirmak gerekmesin).
              child: _imageBox('Portre', it.portraitThumb, 1,
                  previewRel: it.portraits.isEmpty ? '' : it.portraits.last,
                  badge: (it.portraitThumb.isEmpty && it.portraits.isNotEmpty)
                      ? '${it.portraits.length} aday - sec'
                      : '',
                  onTap: (it.portraitThumb.isEmpty && it.portraits.isNotEmpty)
                      ? () => _portraitPicker(it)
                      : null,
                  onEdit: () => _edit('portrait', 'Portre'),
                  onRefresh: () => _run(
                      'Portre uretimi',
                      () =>
                          CharacterFlowService.portrait(name: _name, n: _dirCount),
                      adet: _dirCount)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _imageBox('Base (S)', it.southThumb, 9 / 16,
                  onEdit: () => _edit('base', 'Base'),
                  onRefresh: () => _run(
                      'Base adayi',
                      () => CharacterFlowService.dirs(
                          name: _name, dirs: const ['base'], n: _dirCount),
                      adet: _dirCount)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(it.klass.isEmpty ? 'sinif yok' : it.klass,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13)),
            ),
            Text('${it.candidateCount} aday',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        // #306: otomatik hattin ilerleme cubugu (character.json.pipeline).
        if (p.running) ...[
          const SizedBox(height: 10),
          Text(
              p.step.isEmpty
                  ? 'Pipeline calisiyor (${p.done}/${p.total})'
                  : 'Pipeline: ${p.step} (${p.done}/${p.total})',
              style: TextStyle(fontSize: 12, color: AppColors.accent)),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: p.progress),
        ] else if (p.status == 'error') ...[
          const SizedBox(height: 10),
          Text('Pipeline hatasi: ${p.step}',
              style: TextStyle(fontSize: 12, color: AppColors.error)),
        ],
        const SizedBox(height: 12),
        _countSlider('Aday'),
        // ------------------------------------------------ base adaylari
        const Text('Base adaylari - birini sec, "Base yap" de',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        if (adaylar.isEmpty)
          Text(
            it.candidateCount > 0
                ? '${it.candidateCount} aday var ama sunucu dosya listesini '
                    'gondermedi - listeyi yenile.'
                : 'Aday yok. "Yeni base adayi uret" ya da "Uretilenler" '
                    'ekraninda Karakter Modu\'nda is secip "Adaylara ekle" de.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 9 / 16,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: adaylar.length,
            itemBuilder: (_, i) => _candidateTile(adaylar[i]),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            // #310: secili adayi sil.
            IconButton(
              tooltip: 'Secili adayi sil',
              onPressed: _candidate == null ? null : _deleteCandidate,
              icon: const Icon(Icons.delete_outline),
              color: AppColors.error,
            ),
            Expanded(
              // #306: tek dugme - "Gorunus yap" kaldirildi.
              child: FilledButton.icon(
                onPressed: _candidate == null ? null : _pickBase,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Base yap'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _run(
                    'Base adayi',
                    () => CharacterFlowService.dirs(
                        name: _name, dirs: const ['base'], n: _dirCount),
                    adet: _dirCount),
                icon: const Icon(Icons.person_outline, size: 18),
                label: Text('Base adayi uret ($_dirCount)',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Base = karakterin notr kimlik karesi (South) ve kart gorseli; her '
          'zaman bikini/ic camasiri seviyesindedir. BASE\'I SEN SECERSIN: '
          '"Base yap" dedigin anda portre, hikaye ve 7 yon (her birinden 1 '
          'adet) kendiliginden kuyruga girer ve otomatik kabul edilir. '
          '"Base adayi uret" yalniz aday ekler, secmez.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        _portraitRow(it),
        const SizedBox(height: 16),
        // ------------------------------------------------ hikaye
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _editCard,
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Kart duzenle'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _enrichCard,
                icon: const Icon(Icons.auto_stories_outlined, size: 18),
                label: const Text('Hikayeyi zenginlestir'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // #299: oneri artik pop-up degil - asagidaki listeye duser.
        const Text(
            'Zenginlestirme yerel Ollama ile calisir; oneriler asagida '
            'listelenir, birini kabul edince kart degisir.',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 12),
        _proposalsSection(),
        // #295: yastiklama secici burada YOK - asil yeri skin animasyon
        // panelleri (uretimden HEMEN once sorulur).
      ],
    );
  }

  // ------------------------------------------------- #299 hikaye onerileri
  /// Ollama onerileri listesi. Her oneri acilir bir kart: baslikta tarih,
  /// model ve hikayenin ilk satiri; icinde tam metin + Kabul et / Sil.
  Widget _proposalsSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              _proposals.isEmpty
                  ? 'Hikaye onerileri'
                  : 'Hikaye onerileri (${_proposals.length})',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          if (_proposals.isEmpty)
            const Text('Oneri yok - Hikayeyi zenginlestir ile 2 oneri uretilir.',
                style: TextStyle(fontSize: 12, color: Colors.grey))
          else
            for (final p in _proposals) ...[
              _proposalCard(p),
              const SizedBox(height: 8),
            ],
        ],
      );

  Widget _proposalCard(CardProposal p) => Card(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          title: Text(p.headline,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13)),
          subtitle: Row(
            children: [
              Expanded(
                child: Text(
                    '${p.whenLabel}${p.model.isEmpty ? "" : "  -  ${p.model}"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
              if (p.accepted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Kabul edildi',
                      style: TextStyle(fontSize: 10, color: Colors.green)),
                ),
            ],
          ),
          children: [
            SelectableText(p.card, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: p.accepted ? null : () => _acceptProposal(p),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Kabul et'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteProposal(p),
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: AppColors.error),
                    label: Text('Sil',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Future<void> _acceptProposal(CardProposal p) async {
    try {
      await CharacterFlowService.acceptProposal(_name, p.id);
      _snack('Kart kaydedildi');
      await _load();          // karakter + oneri listesi tazelenir
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteProposal(CardProposal p) async {
    try {
      await CharacterFlowService.deleteProposal(_name, p.id);
      await _loadProposals();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// #309: portre adaylarini alt sayfada gosterir; dokunulan kabul edilir.
  Future<void> _portraitPicker(CharacterItem it) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Portre adaylari - dokunarak kabul et',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: it.portraits.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () {
                      Navigator.pop(c);
                      _pickFile(it.portraits[i], 'portrait', 'Portre secildi');
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 150,
                        child: ColoredBox(
                          color: Colors.black26,
                          child: Image.network(
                            _thumb(it.portraits[i], size: 400),
                            headers: CharacterFlowService.authHeaders,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                Container(color: Colors.white10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// #310: secili base adayini siler (onayli).
  Future<void> _deleteCandidate() async {
    final rel = _candidate;
    if (rel == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Adayi sil'),
        content: Text('${rel.split('/').last} silinsin mi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgec')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CharacterFlowService.deleteCandidate(name: _name, file: rel);
      setState(() => _candidate = null);
      _snack('Aday silindi');
      await _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _portraitRow(CharacterItem it) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Portre adaylari',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
              ),
              // #294: dugme dar ekranda satiri tasirmasin.
              Flexible(
                child: OutlinedButton.icon(
                  onPressed: () => _run(
                      'Portre uretimi',
                      () => CharacterFlowService.portrait(name: _name, n: _dirCount),
                      adet: _dirCount),
                  icon: const Icon(Icons.face_retouching_natural, size: 18),
                  label: Text('Portre uret ($_dirCount)',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (it.portraits.isEmpty)
            const Text('Portre adayi yok.',
                style: TextStyle(fontSize: 12, color: Colors.grey))
          else
            // #306: portre KARE - aday seridi de 1:1 + contain.
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: it.portraits.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () =>
                      _pickFile(it.portraits[i], 'portrait', 'Portre secildi'),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 104,
                      child: ColoredBox(
                        color: Colors.black26,
                        child: Image.network(
                          _thumb(it.portraits[i], size: 400),
                          headers: CharacterFlowService.authHeaders,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              Container(color: Colors.white10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );

  /// #306: kutu satirdaki payini kaplar; en/boy disaridan gelir (portre 1:1,
  /// base 9:16). Gorsel `contain` cizilir - kafa/ayak kirpilmaz. Altinda
  /// ✎ Duzenle / ↻ Yeniden uret ikonlari durur (ince ayar).
  Widget _imageBox(String baslik, String rel, double oran,
          {VoidCallback? onEdit,
          VoidCallback? onRefresh,
          String previewRel = '',
          String badge = '',
          VoidCallback? onTap}) =>
      Column(
        children: [
          GestureDetector(
            onTap: onTap ?? (rel.isEmpty ? null : () => _big(baslik, rel)),
            onLongPress: rel.isEmpty ? null : () => _big(baslik, rel),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: oran,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (rel.isEmpty && previewRel.isEmpty)
                      Container(
                          color: Colors.white10,
                          alignment: Alignment.center,
                          child: const Text('yok',
                              style: TextStyle(fontSize: 12, color: Colors.grey)))
                    else
                      ColoredBox(
                        color: Colors.black26,
                        // #309: kabul edilmemis aday soluk gosterilir.
                        child: Opacity(
                          opacity: rel.isEmpty ? 0.55 : 1,
                          child: Image.network(
                            _thumb(rel.isEmpty ? previewRel : rel, size: 600),
                            headers: CharacterFlowService.authHeaders,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                Container(color: Colors.white10),
                          ),
                        ),
                      ),
                    if (badge.isNotEmpty)
                      Positioned(
                        left: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade800,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(badge,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(baslik,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Duzenle (prompt ile)',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints.tightFor(width: 28, height: 28),
                ),
              if (onRefresh != null)
                IconButton(
                  tooltip: 'Yeniden uret',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints.tightFor(width: 28, height: 28),
                ),
            ],
          ),
        ],
      );

  Widget _candidateTile(String rel) {
    final on = _candidate == rel;
    return GestureDetector(
      onTap: () => setState(() => _candidate = on ? null : rel),
      onLongPress: () => _big('Aday', rel),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: on ? AppColors.accent : Colors.transparent, width: 3),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              Image.network(
                _thumb(rel),
                headers: CharacterFlowService.authHeaders,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(color: Colors.white10),
              ),
              Positioned(
                left: 4,
                right: 4,
                bottom: 3,
                child: Text(
                  rel.split('/').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 3, color: Colors.black)]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// #306: base secimi sunucuda portre/hikaye/yon adimlarini yeniden kosar -
  /// donen op izlenir.
  Future<void> _pickBase() async {
    final f = _candidate;
    if (f == null) return;
    await _pickFile(f, 'base', 'Base secildi - portre, hikaye ve yonler yenileniyor');
  }

  Future<void> _pickFile(String rel, String kind, String mesaj) async {
    try {
      final op =
          await CharacterFlowService.pick(name: _name, file: rel, kind: kind);
      _snack(mesaj);
      if (op.isNotEmpty) _watch(op);   // #306: pick op dondurur
      _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _editCard() async {
    String metin;
    try {
      metin = await CharacterFlowService.card(_name);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    if (!mounted) return;
    await _cardDialog('card.md', metin);
  }

  /// #306 ince ayar: ✎ Duzenle - hedefin kabul edilmis gorselini kisa bir
  /// duzeltme cumlesiyle degistirir (op Sira'da izlenir).
  Future<void> _edit(String target, String baslik) async {
    final p = await editPromptDialog(context, baslik);
    if (p == null) return;
    await _run('$baslik duzenleme',
        () => CharacterFlowService.edit(name: _name, target: target, prompt: p),
        adet: 1);
  }

  /// #299: 2 oneri uretir. Pop-up YOKTUR - is sunucu sirasina girer, op
  /// cubugu ustte doner, biten oneriler asagidaki listeye duser.
  Future<void> _enrichCard() =>
      _run('Hikaye onerisi', () => CharacterFlowService.enrichCard(_name, n: 2),
          adet: 2);

  Future<void> _cardDialog(String baslik, String metin) async {
    final ctl = TextEditingController(text: metin);
    final yeni = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        // 16 satirlik metin kutusu klavye acikken sigmiyordu (gorev #289).
        scrollable: true,
        title: Text(baslik),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: ctl,
            maxLines: 16,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgec')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctl.text),
              child: const Text('Kaydet')),
        ],
      ),
    );
    if (yeni == null) return;
    try {
      await CharacterFlowService.saveCard(_name, yeni);
      _snack('Kart kaydedildi');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ------------------------------------------------------------ 2 Yon
  /// #306: BASE'in 8 yonu (`base/dirs/`). Pusula izgarasi (#292/#300 hucreleri,
  /// aday onizleme + rozet); her yonde yenile / sil. ANIMASYON IKONU YOKTUR -
  /// animasyon 3 Skinler sekmesindeki skin detayinda yapilir.
  Widget _tabYon(CharacterItem it) {
    final eksik = _dirs.where((d) => it.dirs[d.id] != true).toList();
    return ListView(
      // Tam ekran route, alt cubuk yok: sistem gezinme cubugunu ekle (#289).
      padding: bottomSafePadding(context,
          left: 12, top: 12, right: 12, bottom: 12),
      children: [
        _countSlider('Aday'),
        FilledButton.icon(
          onPressed: eksik.isEmpty
              ? null
              : () => _run(
                  'Yon uretimi',
                  () => CharacterFlowService.dirs(
                      name: _name,
                      dirs: eksik.map((d) => d.id).toList(),
                      n: _dirCount),
                  adet: eksik.length * _dirCount),
          icon: const Icon(Icons.blur_circular, size: 18),
          label: Text(eksik.isEmpty
              ? 'Butun yonler secili'
              : 'Eksikleri uret (${eksik.length} yon x $_dirCount)'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        ),
        const SizedBox(height: 10),
        // #292: yuvarlak duzen dar telefonda hucreleri ust uste bindiriyordu -
        // yerine 3x3 izgara: NW N NE / W - E / SW S SE.
        LayoutBuilder(
          builder: (_, cons) {
            const bosluk = 8.0;
            final cellW = ((cons.maxWidth - 2 * bosluk) / 3).clamp(72.0, 150.0);
            return _dirGrid(it, cellW, bosluk);
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'Kabul edilmemis yonde dokunma aday secicisini acar, kabul edilmis '
          'yonde buyuk gosterir; basili tutma her zaman buyutur. Ikonlar: '
          '✎ duzenle (kisa duzeltme cumlesi), ↻ yeniden uret, sil. Duzenlemede '
          'eski gorsel aday olarak kalir - geri alabilirsin. S (South) = base\'in kendisi, '
          '1. sekmeden secilir. Animasyon burada yok - 3 Skinler sekmesinde.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  /// #292: pusulanin 3x3 izgara hali. Hucre genisligi disaridan gelir
  /// (mevcut genislik / 3), yukseklik 9:16 - hicbir hucre digerine binmez.
  Widget _dirGrid(CharacterItem it, double cellW, double bosluk) {
    final byId = {for (final d in _dirs) d.id: d};
    final kullanilan = <String>{};
    final satirlar = <Widget>[];
    for (final row in _compassGrid) {
      final hucreler = <Widget>[];
      for (final id in row) {
        if (hucreler.isNotEmpty) hucreler.add(SizedBox(width: bosluk));
        final d = id.isEmpty ? null : byId[id];
        if (d == null) {
          // #306: orta hucre bos - base artik S (South) hucresinin kendisi.
          hucreler.add(SizedBox(width: cellW));
          continue;
        }
        kullanilan.add(id);
        hucreler.add(_dirCell(it, d, cellW));
      }
      satirlar.add(Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: hucreler,
      ));
    }
    // Tanimadigimiz bir yon gelirse izgaranin altina sarar - kaybolmasin.
    final ekstra = _dirs.where((d) => !kullanilan.contains(d.id)).toList();
    return Column(
      children: [
        for (final s in satirlar) ...[s, SizedBox(height: bosluk)],
        if (ekstra.isNotEmpty) ...[
          Wrap(
            spacing: bosluk,
            runSpacing: bosluk,
            alignment: WrapAlignment.center,
            children: [for (final d in ekstra) _dirCell(it, d, cellW)],
          ),
          SizedBox(height: bosluk),
        ],
      ],
    );
  }

  Widget _dirCell(CharacterItem it, CharacterDir d, double cellW) {
    final kabul = it.dirs[d.id] == true;
    final adaylar = it.dirCandidates[d.id] ?? const <String>[];
    // #300: kabul edilmemis yonde EN YENI aday soluk gosterilir + "N aday"
    // rozeti; dokunma aday secicisini acar.
    final String? url = kabul
        ? _thumb(it.dirFiles[d.id] ?? CharacterFlowService.baseDirRel(d.id),
            size: 600)
        : (adaylar.isEmpty ? null : _thumb(adaylar.last, size: 600));
    return _ThumbCell(
      label: d.label,
      url: url,
      accepted: kabul,
      dimmed: !kabul && adaylar.isNotEmpty,
      badge: (!kabul && adaylar.isNotEmpty) ? '${adaylar.length} aday - sec' : null,
      width: cellW,
      thumbHeight: cellW * 16 / 9,
      // #306: bu sekmede animasyon yok - onAnim/onMixamo verilmez.
      onTap: () => _dirBig(it, d),
      onLongPress: () => _dirBig(it, d),
      // #306 ince ayar: S (South) base'in kendisidir, hedefi `base` olur.
      onEdit: () => _edit(d.id == 'front' ? 'base' : 'dir:${d.id}', d.label),
      onRefresh: d.id == 'front'
          ? () => _snack('S (South) base\'in kendisidir - 1. sekmeden secilir')
          : () => _run(
              '${d.label} uretimi',
              () => CharacterFlowService.dirs(
                  name: _name, dirs: [d.id], n: _dirCount),
              adet: _dirCount),
      onDelete: () => _deleteDir(d.id, d.label),
    );
  }

  /// Basili tutma: tam boy onizleme.
  void _big(String baslik, String rel) {
    if (rel.isEmpty) {
      _snack('$baslik yok');
      return;
    }
    showBigImage(context, _file(rel), baslik);
  }

  /// Yonun buyuk onizlemesi + adaylari (kabul = pick `dir:<yon>`).
  Future<void> _dirBig(CharacterItem it, CharacterDir d) async {
    final adaylar = it.dirCandidates[d.id] ?? const <String>[];
    final kabul = it.dirs[d.id] == true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        // 240px onizleme + 150px aday seridi yatay ekranda tasiyordu (#289).
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${d.label}  (${d.azimuth} derece)',
                    style:
                        const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (kabul)
                  // #292: onizleme de kirpilmasin - contain.
                  SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: Image.network(
                      _file(it.dirFiles[d.id] ??
                          CharacterFlowService.baseDirRel(d.id)),
                      headers: CharacterFlowService.authHeaders,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox(height: 120),
                    ),
                  ),
                const SizedBox(height: 8),
                if (d.id == 'front')
                  const Text(
                      'S (South) base\'in kendisidir - 1. sekmeden secilir.',
                      style: TextStyle(fontSize: 12, color: Colors.grey))
                else if (adaylar.isEmpty)
                  const Text('Aday yok - yenile ikonuyla uret.',
                      style: TextStyle(fontSize: 12, color: Colors.grey))
                else ...[
                  const Text('Adaylar - dokunarak kabul et',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  // #292: aday seridi 9:16 + contain.
                  SizedBox(
                    height: 176,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: adaylar.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () {
                          Navigator.pop(c);
                          _pickFile(adaylar[i], 'dir:${d.id}',
                              '${d.label} kabul edildi');
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 99,
                            child: ColoredBox(
                              color: Colors.black26,
                              child: Image.network(
                                _thumb(adaylar[i], size: 400),
                                headers: CharacterFlowService.authHeaders,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    Container(color: Colors.white10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteDir(String dir, String ad) async {
    if (!await _confirm('$ad sil', '$ad gorseli silinecek. Adaylar kalir.')) return;
    try {
      await CharacterFlowService.deleteDir(name: _name, dir: dir);
      _snack('$ad silindi');
      _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // -------------------------------------------------------- 3 Skinler
  /// #306: skin = kiyafet. Ilk satir her zaman Base'dir. Satira dokunma skin
  /// detayini acar (yonler + animasyon).
  // ------------------------------------------------------- 4 Skinler
  /// #330: yalniz base + skinler. Kiyafet seridi ve skin uretimi 3 Gardirop'ta.
  Widget _tabSkinler(CharacterItem it) {
    final skinler = _skinList;
    return ListView(
      padding: bottomSafePadding(context,
          left: 12, top: 12, right: 12, bottom: 12),
      children: [
        const Text(
            'Base + skinler. Yeni skin 3 Gardirop sekmesinden uretilir '
            '(yalniz South); yonler skinin sayfasindaki "Eksikleri uret" ile '
            'South\'tan uretilir. Animasyon skin ustunde yapilir.',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 12),
        if (skinler.isEmpty)
          const Text('Skin yok.',
              style: TextStyle(fontSize: 12, color: Colors.grey))
        else
          for (final s in skinler) ...[
            _skinCard(it, s),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  // ------------------------------------------------------- 3 Gardirop
  /// #330/#331: ustte RPG giydirme (ortada base, yanlarda yuvalar, base
  /// secici), altinda "Skin uret" + "Kiyafet cikar", altinda 3'lu katalog.
  Widget _tabGardirop(CharacterItem it) {
    final hazir = _kindOutfits;
    final hedef = _chars.where((c) => c.name == _equipTarget).firstOrNull;
    final baseUrl = hedef == null
        ? (it.southThumb.isEmpty ? '' : _thumb(it.southThumb, size: 300))
        : (hedef.southThumb.isEmpty
            ? ''
            : CharacterFlowService.thumbUrl(hedef.name, hedef.southThumb,
                size: 300, v: hedef.rev));
    final n = (_equip.set.isEmpty ? 0 : 1) + _equip.pieces.length;
    return ListView(
      padding: bottomSafePadding(context,
          left: 12, top: 12, right: 12, bottom: 12),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                  'Giydirme - ${CharacterFlowService.kindLabel(_kind)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
            Flexible(
              child: OutlinedButton.icon(
                onPressed: _newOutfit,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('+ Kiyafet uret',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        EquipPanel(
          outfits: hazir,
          selection: _equip,
          characters: _chars.isEmpty
              ? [if (_item != null) _item!]
              : _chars,
          selectedName: _equipTarget.isEmpty ? _name : _equipTarget,
          onCharacter: (v) => setState(() => _equipTarget = v),
          baseThumbUrl: baseUrl,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                onPressed: _equip.isEmpty ? null : _makeSkinFromEquip,
                icon: const Icon(Icons.checkroom, size: 18),
                label: Text(n == 0 ? 'Skin uret (South)' : 'Skin uret (South, $n is)',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: _extractFromWardrobe,
                icon: const Icon(Icons.content_cut, size: 16),
                label: const Text('Kiyafet cikar',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
            'Yuvaya dokun: kiyafet sec - basili tut: buyut. Skin uret = secili '
            'base + giyilenlerle yeni skinin South\'u (yalniz South; yonler '
            'skin sayfasindan). Skin, base secicideki karakterin olur.',
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 12),
        Text('Gardirop - ${hazir.length} kiyafet',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 4),
        _outfitCategoryChips(),
        const SizedBox(height: 4),
        if (_outfitsLoading && _outfits.isEmpty)
          const SizedBox(
              height: 40, child: Center(child: CircularProgressIndicator()))
        else if (hazir.isEmpty)
          Text(
              'Bu turde (${CharacterFlowService.kindLabel(_kind)}) kiyafet '
              'yok - "+ Kiyafet uret" ya da "Kiyafet cikar".',
              style: const TextStyle(fontSize: 12, color: Colors.grey))
        else if (_visibleOutfits.isEmpty)
          Text(
              '"${CharacterFlowService.categoryLabel(_outfitCat)}" '
              'kategorisinde kiyafet yok.',
              style: const TextStyle(fontSize: 12, color: Colors.grey))
        else
          OutfitCatalogGrid(
            outfits: _visibleOutfits,
            shrinkWrap: true,
            selected: (o) => _equip.of(o.category).contains(o.slug),
            onTap: (o) => o.ready
                ? _outfitMenu(o)
                : _snack('Kiyafet henuz hazir degil - kuyrukta ya da uretim basarisiz'),
            onLongPress: (o) => showOutfitPreview(context, o),
          ),
      ],
    );
  }

  /// #331: Skin uret = secili base + giyilenler -> yalniz South (1 op).
  Future<void> _makeSkinFromEquip() async {
    if (_equip.isEmpty) {
      _snack('Once bir yuvaya kiyafet giydir');
      return;
    }
    final hedef = _equipTarget.isEmpty ? _name : _equipTarget;
    final ad = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('$hedef icin skin uret'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ad,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Skin adi (bos: setten / parcalardan turetilir)',
                  hintText: 'orn. Kirmizi savasci'),
            ),
            const SizedBox(height: 8),
            Text(
                'base + ${[
                  if (_equip.set.isNotEmpty) 'set ${_outfitOf(_equip.set)?.name ?? _equip.set}',
                  for (final p in _equip.pieces) _outfitOf(p)?.name ?? p,
                ].join(" + ")}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgec')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Uret')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final n = (_equip.set.isEmpty ? 0 : 1) + _equip.pieces.length;
    await _run(
        '${ad.text.trim().isEmpty ? "Skin" : ad.text.trim()} ($hedef, South)',
        () async => (await CharacterFlowService.skinCreate(
              hedef,
              skinName: ad.text.trim(),
              outfit: _equip.set,
              pieces: _equip.pieces,
            ))
                .op,
        adet: n);
    if (hedef != _name) {
      _snack('Skin $hedef karakterine yaziliyor - onun sayfasinda gorunur');
    }
  }

  /// #329: Gardirop'tan kiyafet cikar - kaynak son uretimlerden secilir.
  Future<void> _extractFromWardrobe() async {
    final j = await pickGeneratedImage(context);
    if (j == null || !mounted) return;
    final secim = await showOutfitExtractDialog(context, kind: _kind);
    if (secim == null || !mounted) return;
    await _run(
        '${secim.name} cikarma',
        () => CharacterFlowService.outfitExtract(
            name: secim.name,
            category: secim.category,
            kind: secim.kind,
            jobId: j.id,
            note: secim.note),
        adet: 1);
  }

  Widget _skinCard(CharacterItem it, SkinItem s) {
    final (animOk, animTotal) = s.animProgress;
    final rel = s.south.isNotEmpty
        ? s.south
        : (s.isBase ? it.southThumb : CharacterFlowService.skinDirRel(s.slug, 'front'));
    final rev = s.rev > 0 ? s.rev : it.rev;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openSkin(s),
        onLongPress: s.isBase ? null : () => _deleteSkin(s),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 66,
                  height: 117,
                  child: rel.isEmpty
                      ? Container(
                          color: Colors.white10,
                          child:
                              const Icon(Icons.checkroom, color: Colors.grey))
                      : ColoredBox(
                          color: Colors.black26,
                          child: Image.network(
                            CharacterFlowService.thumbUrl(_name, rel,
                                size: 300, v: rev),
                            headers: CharacterFlowService.authHeaders,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                Container(color: Colors.white10),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.isBase ? 'Base' : s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                        s.isBase
                            ? 'notr set - bikini / ic camasiri'
                            : (s.prompt.isNotEmpty
                                ? s.prompt
                                : 'kiyafet: ${s.outfitSlug.isEmpty ? s.slug : s.outfitSlug}'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    // #313: parca kombinasyonundan uretilmis skinde parcalar.
                    if (s.pieces.isNotEmpty)
                      Text(_piecesLabel(s.pieces),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: AppColors.accent)),
                    const SizedBox(height: 6),
                    dirCompass(
                      _dirs,
                      cell: (d) => dirBadge(d, s.dirs[d.id] == true),
                      spacing: 3,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        for (final t in [
                          'yon ${s.dirsDone(_dirs)}/${_dirs.length}',
                          'klip ${s.clipCount}',
                          'anim $animOk/$animTotal',
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

  Future<void> _openSkin(SkinItem s) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SkinDetailPage(
        name: _name,
        initial: s,
        dirs: _dirs,
        padding: _item?.padding ?? 0,
        // #314: hayvan/makine turunde `mixamo` yoktur - manken/Mixamo
        // dugmeleri ve paneli gizlenir, i2v kalir.
        animModes: _item?.animModes ?? const ['i2v', 'mixamo'],
      ),
    ));
    _load();
  }

  // ---------------------------------------------- #306 kiyafet kutuphanesi
  /// Kiyafet seridi: karakterden BAGIMSIZ kutuphane. Dokunma = o kiyafetten
  /// skin uret; basili tutma = skin uret / duzenle / sil menusu.
  Widget _outfitCategoryChips() => SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final k in [
              const {'id': '', 'label': 'Hepsi'},
              ...CharacterFlowService.defaultOutfitCategories,
            ])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text('${k['label']}',
                      style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  selected: _outfitCat == k['id'],
                  onSelected: (_) =>
                      setState(() => _outfitCat = '${k['id']}'),
                ),
              ),
          ],
        ),
      );

  /// Basili tutma menusu - skin uret / duzenle / sil.
  Future<void> _outfitMenu(OutfitItem o) async {
    final secim = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(o.name),
              subtitle: Text(o.prompt.isEmpty ? o.slug : o.prompt,
                  maxLines: 3, style: const TextStyle(fontSize: 11)),
            ),
            const Divider(height: 1),
            // #331: giydirme yuvasina tak / cikar.
            ListTile(
              leading: Icon(
                  _equip.of(o.category).contains(o.slug)
                      ? Icons.remove_circle_outline
                      : Icons.add_circle_outline),
              title: Text(_equip.of(o.category).contains(o.slug)
                  ? 'Yuvadan cikar (${CharacterFlowService.categoryLabel(o.category)})'
                  : 'Giydir - ${CharacterFlowService.categoryLabel(o.category)} yuvasi'),
              onTap: () => Navigator.pop(c, 'equip'),
            ),
            ListTile(
              leading: const Icon(Icons.zoom_in),
              title: const Text('Buyut'),
              onTap: () => Navigator.pop(c, 'preview'),
            ),
            ListTile(
              leading: const Icon(Icons.checkroom),
              // #313: set = dogrudan skin, parca = birlestirici.
              title: Text(o.category == 'set'
                  ? 'Bu setten skin uret (South)'
                  : 'Bu parcayla skin uret (birlestirici)'),
              onTap: () => Navigator.pop(c, 'skin'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Duzenle (prompt ile)'),
              onTap: () => Navigator.pop(c, 'edit'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text('Sil', style: TextStyle(color: AppColors.error)),
              onTap: () => Navigator.pop(c, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (secim == 'equip') {
      setState(() => _equip.toggle(o.category, o.slug));
      if (_tabs.index != 2) _tabs.animateTo(2);
    } else if (secim == 'preview') {
      if (!mounted) return;
      await showOutfitPreview(context, o);
    } else if (secim == 'skin') {
      // #313: parca kategorileri birlestiriciye gider.
      if (o.category == 'set') {
        await _makeSkin(o);
      } else {
        await _openComposer(preselect: o);
      }
    } else if (secim == 'edit') {
      await _editOutfit(o);
    } else if (secim == 'delete') {
      await _deleteOutfit(o);
    }
  }

  /// "+ Kiyafet uret" - #313: once KATEGORI, sonra o kategorinin sablonu,
  /// ad + prompt ve Normal|Hot (Hot yalniz giysi kategorilerinde acik).
  /// #314: en ustte TUR secici (varsayilan karakterin turu). Tur degistirmek
  /// serbesttir - kutuphane boylece diger turler icin de doldurulabilir; ama
  /// serit ve skin birlestirici yalniz karakterin turunu gosterir.
  Future<void> _newOutfit() async {
    final ad = TextEditingController();
    final prompt = TextEditingController();
    // #312: Hot modifier + hazir sablon (sunucudan; uc yoksa dropdown gizli).
    // #313: sablonlar artik kategori tasir, kategoriler de sunucudan gelir.
    var hot = false;
    var sablon = '';
    var kategori = _outfitCat.isEmpty ? 'set' : _outfitCat;
    var tur = _kind;                    // #314: varsayilan karakterin turu
    // #314: pencerede tur degistirilebildigi icin sablonlar TUM turler icin
    // cekilir (`kind: ''` = hepsi) ve asagida tur + kategoriye gore suzulur.
    final veri = await CharacterFlowService.outfitTemplates(kind: '');
    if (!mounted) return;
    final kategoriler = veri.categories;
    final sablonlar = veri.templates;
    // #314: sunucu tur listesi bos ya da karakterin turunu icermiyorsa sabit
    // listeye duseriz - SegmentedButton secili degeri segmentlerde arar.
    final turler = veri.kinds.isEmpty
        ? CharacterFlowService.characterKinds
        : veri.kinds;
    if (!turler.any((k) => k['id'] == tur)) {
      tur = '${turler.first['id']}';
    }
    // #313: bilinmeyen kategori id'si gelirse ilk kategoriye duser.
    if (!kategoriler.any((k) => k['id'] == kategori)) {
      kategori = kategoriler.isEmpty ? 'set' : '${kategoriler.first['id']}';
    }
    const grupAd = {
      'gunluk': 'Gunluk',
      'fantastik': 'Fantastik',
      'etkinlik': 'Etkinlik',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) {
          // #313: sablon listesi secili kategoriye gore suzulur (kategorisi
          // olmayan eski sablonlar serviste `set` sayilir).
          // #314: TUR de suzer - turu olmayan eski sablonlar `female` sayilir.
          final suzulmus = sablonlar
              .where((t) => t['category'] == kategori && t['kind'] == tur)
              .toList();
          // #314: Hot yalniz insan turlerinin giysi kategorilerinde.
          final hotAcik = CharacterFlowService.hotAllowed(tur, kategori);
          if (!hotAcik && hot) hot = false;
          return AlertDialog(
            scrollable: true,
            title: const Text('Kiyafet uret'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Kiyafet karakterden bagimsizdir: duz gri fonda urun '
                      'karesi olarak uretilir ve AYNI TURDEKI butun '
                      'karakterlerde tekrar kullanilir.',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  // #314: ONCE tur - sablon listesi ve Hot buna da bagli.
                  const Text('Tur',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  kindSelector(
                    kinds: turler,
                    value: tur,
                    onChanged: (v) => setLocal(() {
                      tur = v;
                      // tur degisince eski sablon gecersiz olur.
                      sablon = '';
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                      tur == _kind
                          ? 'Bu karakterin turu - serit ve skin birlestirici '
                              'yalniz bu turdeki kiyafetleri gosterir.'
                          : 'DIKKAT: farkli tur - uretilen kiyafet bu '
                              'karakterin seridinde gorunmez, '
                              '${CharacterFlowService.kindLabel(tur)} '
                              'karakterlerde kullanilir.',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 10),
                  // #313: sonra kategori - sablon listesi ve Hot buna bagli.
                  DropdownButtonFormField<String>(
                    initialValue: kategori,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final k in kategoriler)
                        DropdownMenuItem(
                          value: k['id'],
                          child: Text('${k['label']}',
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (x) => setLocal(() {
                      kategori = x ?? 'set';
                      // kategori degisince eski sablon gecersiz olur.
                      sablon = '';
                    }),
                  ),
                  const SizedBox(height: 10),
                  if (suzulmus.isNotEmpty) ...[
                    // #312: sablon secilince ad ve prompt bos birakilabilir;
                    // yazilan prompt sablonun arkasina eklenir.
                    DropdownButtonFormField<String>(
                      // #313: kategori degisince sablon alani SIFIRDAN kurulur
                      // (FormField initialValue'yu yeniden okumaz - eski deger
                      // yeni listede yoksa assert atardi).
                      // #314: tur de anahtara girer - tur degisince liste degisir.
                      key: ValueKey('sablon-$tur-$kategori'),
                      initialValue: sablon,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Sablon',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: '',
                            child: Text('(sablon yok - serbest prompt)')),
                        for (final t in suzulmus)
                          DropdownMenuItem(
                            value: t['id'],
                            child: Text(
                                (t['group'] ?? '').isEmpty
                                    ? '${t['label']}'
                                    : '${grupAd[t['group']] ?? t['group']} - ${t['label']}',
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (x) => setLocal(() => sablon = x ?? ''),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: ad,
                    decoration: const InputDecoration(
                      labelText: 'Kiyafet adi (sablon secildiyse bos kalabilir)',
                      hintText: 'orn. Sovalye zirhi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: prompt,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Kiyafet promptu / ek (sablona eklenir)',
                      hintText:
                          'orn. polished steel plate armor with a red tabard',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // #312: Normal | Hot. #313: Hot yalniz giysi kategorilerinde
                  // (set/ust/alt/ayakkabi/corap/sapka) anlamlidir.
                  SegmentedButton<bool>(
                    segments: [
                      const ButtonSegment(value: false, label: Text('Normal')),
                      ButtonSegment(
                          value: true,
                          label: const Text('Hot'),
                          enabled: hotAcik,
                          icon: const Icon(Icons.local_fire_department,
                              size: 16)),
                    ],
                    selected: {hot},
                    showSelectedIcon: false,
                    onSelectionChanged: (sel) =>
                        setLocal(() => hot = sel.first),
                  ),
                  Text(
                      hotAcik
                          ? 'Hot: acik, vucudu saran, derin yaka / yuksek '
                              'yirtmac sablonu prompta eklenir (yetiskin '
                              'kiyafeti).'
                          // #314: hayvan/makine turlerinde Hot hic acilmaz.
                          : CharacterFlowService.isHumanKind(tur)
                              ? 'Hot yalniz giysi kategorilerinde kullanilir '
                                  '(set, ust, alt, ayakkabi, corap, sapka).'
                              : 'Hot yalniz Kadin/Erkek giysilerinde '
                                  'kullanilir.',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Vazgec')),
              FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Uret')),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    // #312: sablon secildiyse ad/prompt bos kalabilir.
    if (sablon.isEmpty &&
        (ad.text.trim().isEmpty || prompt.text.trim().isEmpty)) {
      _snack('Kiyafet adi ve promptu bos olamaz (ya da bir sablon sec)');
      return;
    }
    await _run(
        'Kiyafet uretimi',
        () => CharacterFlowService.outfitCreate(
            ad.text.trim(), prompt.text.trim(),
            style: hot ? 'hot' : '',
            template: sablon,
            category: kategori,
            kind: tur),                 // #314
        adet: 1);
  }

  Future<void> _editOutfit(OutfitItem o) async {
    final p = await editPromptDialog(context, o.name);
    if (p == null) return;
    await _run('${o.name} duzenleme',
        () => CharacterFlowService.outfitEdit(o.slug, p),
        adet: 1);
  }

  Future<void> _deleteOutfit(OutfitItem o) async {
    if (!await _confirm('${o.name} sil',
        'Kiyafet kutuphaneden silinir. Uretilmis skinler durur.')) {
      return;
    }
    try {
      await CharacterFlowService.deleteOutfit(o.slug);
      _snack('${o.name} silindi');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
    await _loadOutfits();
  }

  /// #313: "Skin uret" artik bir BIRLESTIRICI sayfa acar (set + parcalar).
  /// `preselect` verilirse o kiyafet secili gelir (serit dokunusu).
  Future<void> _openComposer({OutfitItem? preselect}) async {
    // #311: yalniz hazir (png cikmis) kiyafetler giydirilebilir.
    // #314: ve yalniz karakterin TURUNDEKI kiyafetler.
    final hazir = _kindOutfits.where((o) => o.ready).toList();
    if (hazir.isEmpty) {
      _snack('Bu turde (${CharacterFlowService.kindLabel(_kind)}) hazir '
          'kiyafet yok - once "+ Kiyafet uret"');
      return;
    }
    final sonuc = await Navigator.of(context).push<SkinComposeResult>(
      MaterialPageRoute(
        builder: (_) => SkinComposerPage(
            outfits: hazir, preselect: preselect, kind: _kind),   // #314
      ),
    );
    if (sonuc == null || !mounted) return;
    // Ayni slug'tan ikinci skin olmaz - sunucu slug'i ad/set/parcadan turetir,
    // burada yalnizca belirgin cakismayi onceden yakalariz.
    final beklenen = sonuc.skinName.trim().isNotEmpty
        ? sonuc.skinName.trim().toLowerCase()
        : sonuc.outfit;
    if (beklenen.isNotEmpty &&
        _skinList.any((s) =>
            s.slug == beklenen || s.name.toLowerCase() == beklenen)) {
      _snack('Bu adda skin zaten var - yeniden uretmek icin once sil');
      return;
    }
    await _run(
        sonuc.skinName.trim().isEmpty ? 'Skin' : '${sonuc.skinName.trim()} skini',
        () async => (await CharacterFlowService.skinCreate(
              _name,
              skinName: sonuc.skinName.trim(),
              outfit: sonuc.outfit,
              pieces: sonuc.pieces,
            ))
                .op,
        adet: sonuc.jobs);
  }

  /// Skin uret = SET kiyafet + bu karakterin base'i (South + 7 yon otomatik).
  /// Skin slug'i kiyafet slug'idir - ayni kiyafetten tek skin olur.
  /// #313: yalniz `set` kategorisindeki kiyafetin hizli yolu; parcalar
  /// birlestiriciden gecer.
  Future<void> _makeSkin(OutfitItem o) async {
    if (_skinList.any((s) => s.slug == o.slug)) {
      _snack('${o.name} skini zaten var - yeniden uretmek icin once sil');
      return;
    }
    // #329: skin olusturma yalniz South'u uretir (1 adim); yonler skin
    // sayfasindaki "Eksikleri uret" ile South'tan uretilir.
    await _run('${o.name} skini (South)',
        () async => (await CharacterFlowService.skinCreate(_name, outfit: o.slug)).op,
        adet: 1);
  }

  Future<void> _deleteSkin(SkinItem s) async {
    if (s.isBase) {
      _snack('Base silinemez');
      return;
    }
    if (!await _confirm('${s.name} sil',
        'Skinin yonleri ve animasyonlari silinir. GERI ALINAMAZ.')) {
      return;
    }
    try {
      await CharacterFlowService.deleteSkin(_name, s.slug);
      _snack('${s.name} silindi');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
    _load();
  }
}

// ------------------------------------------------------ #313 birlestirici

/// #313: birlestiricinin sonucu - skin adi, set slug'i ve parca slug'lari
/// (giydirme sirasiyla). `jobs` = kuyruga girecek is sayisi.
class SkinComposeResult {
  final String skinName;
  final String outfit;              // set slug'i ('' = set yok)
  final List<String> pieces;        // kategori sirasiyla parca slug'lari
  const SkinComposeResult({
    this.skinName = '',
    this.outfit = '',
    this.pieces = const [],
  });

  /// Set (1) + parcalar (#329: yon yok - skin sayfasindan).
  int get jobs => (outfit.isEmpty ? 0 : 1) + pieces.length;
}

/// #313: "Skin uret" birlestiricisi (dokuman §3b). Base uzerine bir SET ve/veya
/// kategori kategori parcalar secilir: ust/alt/ayakkabi/corap/sapka/kafalik tek
/// secim, aksesuar/silah coklu. Uretim burada BASLATILMAZ - secim geri dondurulur,
/// isi karakter detayi kuyruga verir.
class SkinComposerPage extends StatefulWidget {
  const SkinComposerPage(
      {super.key,
      required this.outfits,
      this.preselect,
      this.kind = 'female'});

  /// Yalniz HAZIR kiyafetler (png cikmis) - kuyruktaki kiyafet giydirilemez.
  /// #314: liste zaten karakterin turune gore suzulmus gelir.
  final List<OutfitItem> outfits;

  /// Serit dokunusundan gelen, acilista secili olacak kiyafet.
  final OutfitItem? preselect;

  /// #314: karakterin turu - baslikta rozet olarak gorunur.
  final String kind;

  @override
  State<SkinComposerPage> createState() => _SkinComposerPageState();
}

class _SkinComposerPageState extends State<SkinComposerPage> {
  final _ad = TextEditingController();
  String _set = '';                            // set slug'i
  final Map<String, String> _tek = {};         // kategori -> tek slug
  final Map<String, List<String>> _coklu = {}; // kategori -> slug listesi

  @override
  void initState() {
    super.initState();
    final p = widget.preselect;
    if (p == null) return;
    if (p.category == 'set') {
      _set = p.slug;
    } else if (CharacterFlowService.singlePieceCategories.contains(p.category)) {
      _tek[p.category] = p.slug;
    } else if (CharacterFlowService.multiPieceCategories.contains(p.category)) {
      _coklu[p.category] = [p.slug];
    }
  }

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  List<OutfitItem> _of(String cat) =>
      widget.outfits.where((o) => o.category == cat).toList();

  OutfitItem? _find(String slug) {
    for (final o in widget.outfits) {
      if (o.slug == slug) return o;
    }
    return null;
  }

  /// Giydirme sirasiyla parca slug'lari (sunucu da bu sirayi uygular).
  List<String> get _pieces => [
        for (final c in CharacterFlowService.singlePieceCategories)
          if ((_tek[c] ?? '').isNotEmpty) _tek[c]!,
        for (final c in CharacterFlowService.multiPieceCategories)
          ...(_coklu[c] ?? const <String>[]),
      ];

  /// Ozet satiri - "base + set X + tisort + etek + kilic".
  String get _summary {
    final parcalar = <String>[];
    if (_set.isNotEmpty) parcalar.add('set ${_find(_set)?.name ?? _set}');
    for (final s in _pieces) {
      parcalar.add(_find(s)?.name ?? s);
    }
    return parcalar.isEmpty ? 'base (parca secilmedi)' : 'base + ${parcalar.join(" + ")}';
  }

  int get _jobs => (_set.isEmpty ? 0 : 1) + _pieces.length;   // #329

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // #314: baslikta tur rozeti - serit yalniz bu turun kiyafetlerini gosterir.
      appBar: AppBar(
        title: Row(
          children: [
            const Flexible(child: Text('Skin uret')),
            const SizedBox(width: 8),
            kindBadge(widget.kind),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              children: [
                TextField(
                  controller: _ad,
                  decoration: const InputDecoration(
                    labelText: 'Skin adi (bos ise setten / parcalardan turetilir)',
                    hintText: 'orn. Yaz kombini',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                    'Base uzerine once set, sonra parcalar sirayla giydirilir; '
                    'her adim bir is (yalniz South; yonler skin sayfasindan).',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 10),
                _setRow(),
                for (final c in CharacterFlowService.singlePieceCategories)
                  _pieceRow(c, multi: false),
                for (final c in CharacterFlowService.multiPieceCategories)
                  _pieceRow(c, multi: true),
              ],
            ),
          ),
          // #289: tam ekran route - alt cubugu sistem gezinme cubugu kadar it.
          Container(
            width: double.infinity,
            color: AppColors.bgCard,
            padding: bottomSafePadding(context,
                left: 12, top: 10, right: 12, bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.checkroom, size: 18),
                  label: Text('Uret ($_jobs is)'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (_set.isEmpty && _pieces.isEmpty) {
      _snack('En az bir set ya da bir parca sec');
      return;
    }
    Navigator.pop(
      context,
      SkinComposeResult(
        skinName: _ad.text.trim(),
        outfit: _set,
        pieces: _pieces,
      ),
    );
  }

  /// "Set" satiri - tek secim ya da bos (parcalarla birlikte de kullanilabilir).
  Widget _setRow() {
    final list = _of('set');
    return _strip(
      baslik: 'Set (tam takim - bos birakilabilir)',
      list: list,
      secili: (o) => _set == o.slug,
      onTap: (o) => setState(() => _set = _set == o.slug ? '' : o.slug),
    );
  }

  Widget _pieceRow(String cat, {required bool multi}) {
    final list = _of(cat);
    final etiket = CharacterFlowService.categoryLabel(cat);
    return _strip(
      baslik: multi ? '$etiket (coklu secim)' : '$etiket (tek secim)',
      list: list,
      secili: (o) => multi
          ? (_coklu[cat] ?? const <String>[]).contains(o.slug)
          : _tek[cat] == o.slug,
      onTap: (o) => setState(() {
        if (multi) {
          final l = List<String>.from(_coklu[cat] ?? const <String>[]);
          l.contains(o.slug) ? l.remove(o.slug) : l.add(o.slug);
          _coklu[cat] = l;
        } else {
          _tek[cat] = _tek[cat] == o.slug ? '' : o.slug;
        }
      }),
    );
  }

  /// Bir kategorinin yatay kiyafet seridi (9:16 contain, secili = yesil cerceve).
  Widget _strip({
    required String baslik,
    required List<OutfitItem> list,
    required bool Function(OutfitItem) secili,
    required void Function(OutfitItem) onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(baslik,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 4),
            if (list.isEmpty)
              const Text('(bu kategoride kiyafet yok)',
                  style: TextStyle(fontSize: 11, color: Colors.grey))
            else
              SizedBox(
                height: 158,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final o = list[i];
                    final on = secili(o);
                    return GestureDetector(
                      onTap: () => onTap(o),
                      child: SizedBox(
                        width: 78,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 78,
                              height: 132,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: on
                                        ? AppColors.success
                                        : Colors.white24,
                                    width: on ? 2.5 : 1),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: ColoredBox(
                                color: Colors.black26,
                                child: Image.network(
                                  CharacterFlowService.outfitThumbUrl(o.slug,
                                      size: 300),
                                  headers: CharacterFlowService.authHeaders,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => Container(
                                    color: Colors.white10,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.checkroom,
                                        size: 20, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                            Text(o.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        on ? AppColors.success : Colors.grey)),
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


// ----------------------------------------------------------- skin detayi

/// #306: tek skinin detayi - Yonler (giydirilmis pusula) + Animasyon.
/// Base skini icin `slug == 'base'`, servise gonderilen `skin` degeri BOS'tur
/// (base animasyonlari `anims/` altinda durur).
class SkinDetailPage extends StatefulWidget {
  const SkinDetailPage({
    super.key,
    required this.name,
    required this.initial,
    required this.dirs,
    this.padding = 0,
    this.animModes = const ['i2v', 'mixamo'],
  });

  final String name;
  /// Liste satirindan gelen skin - sunucu `/skins` vermese de ekran cizilir.
  final SkinItem initial;
  final List<CharacterDir> dirs;
  /// character.json'daki yastiklama varsayilani (#295).
  final double padding;

  /// #314: karakterin acik animasyon yollari (`character.anim_modes`).
  /// `mixamo` yoksa (hayvan/makine) manken/Mixamo yolu ekranda hic gorunmez.
  final List<String> animModes;

  @override
  State<SkinDetailPage> createState() => _SkinDetailPageState();
}

class _SkinDetailPageState extends State<SkinDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });

  late SkinItem _skin = widget.initial;
  bool _loading = false;

  FlowOp? _op;
  Timer? _opPoll;

  // Yonler. #306: varsayilan 1 - tek aday sunucuda otomatik kabul edilir.
  int _dirCount = 1;

  // Animasyon
  String? _animDir;
  String _animMode = 'i2v';           // i2v (saf AI) | mixamo (manken)
  List<CharacterClip> _clips = [];
  bool _clipsLoading = false;
  int _animCount = 1;
  /// #295: yastiklama (0 / 0.1 / 0.2 / 0.3) - karakter basina kalicidir.
  late double _padding = widget.padding;
  final _i2vPrompt = TextEditingController();
  final _i2vClip = TextEditingController();
  final _mixQuery = TextEditingController();
  List<MixamoClip> _mixResults = [];
  final Set<String> _mixSel = {};
  bool _mixBusy = false;
  // rev8: Ollama animasyon asistani
  final _mixWish = TextEditingController();
  List<MixamoClip> _mixSuggest = [];
  bool _wandBusy = false;
  bool _ollamaOff = false;

  String get _name => widget.name;
  List<CharacterDir> get _dirs => widget.dirs;
  /// #314: manken/Mixamo yolu bu karakterde acik mi (hayvan/makine: hayir).
  bool get _mixamoOn => widget.animModes.contains('mixamo');
  /// Servise gonderilen skin degeri - base icin BOS.
  String get _skinArg => _skin.animSkin;
  int get _rev => _skin.rev;

  String _thumb(String rel, {int size = 360}) =>
      CharacterFlowService.thumbUrl(_name, rel, size: size, v: _rev);
  String _file(String rel) => CharacterFlowService.fileUrl(_name, rel, v: _rev);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _opPoll?.cancel();
    _i2vPrompt.dispose();
    _i2vClip.dispose();
    _mixQuery.dispose();
    _mixWish.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final hepsi = await CharacterFlowService.skins(_name);
      final bulunan = hepsi.where((s) => s.slug == _skin.slug).toList();
      if (!mounted) return;
      setState(() {
        if (bulunan.isNotEmpty) _skin = bulunan.first;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);   // eski sunucu - gelen skin kullanilir
    }
    if (_animDir != null) await _loadClips(_animDir!);
  }

  Future<void> _loadClips(String dir) async {
    setState(() => _clipsLoading = true);
    try {
      final c =
          await CharacterFlowService.animsOf(_name, dir, skin: _skinArg);
      if (!mounted) return;
      setState(() {
        _clips = c;
        _clipsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _clips = [];
        _clipsLoading = false;
      });
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _watch(String opId) {
    if (opId.isEmpty) return;
    _opPoll?.cancel();
    var tick = 0;
    _opPoll = Timer.periodic(const Duration(seconds: 2), (t) async {
      try {
        final o = await CharacterFlowService.op(opId);
        if (!mounted) return;
        setState(() => _op = o);
        tick++;
        if (!o.running) {
          t.cancel();
          _snack(o.status == 'error'
              ? 'Islem hatasi: ${o.message}'
              : '${o.ok} tamam${o.failed > 0 ? ", ${o.failed} hata" : ""}');
          _load();
        } else if (tick % 10 == 0) {
          _load();
        }
      } catch (_) {
        t.cancel();
      }
    });
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(String ad, Future<String> Function() f, {int adet = 0}) async {
    try {
      final op = await f();
      _watch(op);
      _snack(adet > 0
          ? '$ad siraya eklendi ($adet is) - Sira sekmesinden izle'
          : '$ad siraya eklendi - Sira sekmesinden izle');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<bool> _confirm(String baslik, String metin) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(baslik),
          content: Text(metin),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Vazgec')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('$_name - ${_skin.isBase ? "Base" : _skin.name}'),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Yenile',
                onPressed: _load),
          ],
          bottom: TabBar(controller: _tabs, tabs: const [
            Tab(text: 'Yonler'),
            Tab(text: 'Animasyon'),
          ]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_op != null && _op!.running) _opBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [_tabYonler(), _tabAnimasyon()],
                    ),
                  ),
                ],
              ),
      );

  Widget _opBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  // ------------------------------------------------------------ Yonler
  /// Yon uretimi: base skininde `/dirs`, diger skinlerde `/skins/dirs`
  /// (giydirme). Ikisi de op doner.
  Future<String> _genDirs(List<String> ids) => _skin.isBase
      ? CharacterFlowService.dirs(name: _name, dirs: ids, n: _dirCount)
      : CharacterFlowService.skinDirs(
          name: _name, skin: _skin.slug, dirs: ids, n: _dirCount);

  Widget _tabYonler() {
    final eksik = _dirs.where((d) => _skin.dirs[d.id] != true).toList();
    return ListView(
      padding: bottomSafePadding(context,
          left: 12, top: 12, right: 12, bottom: 12),
      children: [
        Row(
          children: [
            Text('Aday: $_dirCount',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Expanded(
              child: Slider(
                value: _dirCount.toDouble(),
                min: 1,
                max: 6,
                divisions: 5,
                label: '$_dirCount',
                onChanged: (v) => setState(() => _dirCount = v.round()),
              ),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: eksik.isEmpty
              ? null
              : () => _run('Yon uretimi',
                  () => _genDirs(eksik.map((d) => d.id).toList()),
                  adet: eksik.length * _dirCount),
          icon: const Icon(Icons.blur_circular, size: 18),
          label: Text(eksik.isEmpty
              ? 'Butun yonler hazir'
              : 'Eksikleri uret (${eksik.length} yon x $_dirCount)'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (_, cons) {
            const bosluk = 8.0;
            final cellW = ((cons.maxWidth - 2 * bosluk) / 3).clamp(72.0, 150.0);
            return _dirGrid(cellW, bosluk);
          },
        ),
        const SizedBox(height: 12),
        Text(
          // #314: Mixamo ikonu yalniz insan turlerinde vardir.
          'Ikonlar: anim uret (AI i2v), '
          '${_mixamoOn ? "Mixamo ile uret, " : ""}'
          '✎ duzenle, ↻ yeniden uret, sil. Animasyon o yonun '
          '${_skin.isBase ? "base" : _skin.name} gorselinden uretilir.',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _dirGrid(double cellW, double bosluk) {
    final byId = {for (final d in _dirs) d.id: d};
    final kullanilan = <String>{};
    final satirlar = <Widget>[];
    for (final row in _compassGrid) {
      final hucreler = <Widget>[];
      for (final id in row) {
        if (hucreler.isNotEmpty) hucreler.add(SizedBox(width: bosluk));
        final d = id.isEmpty ? null : byId[id];
        if (d == null) {
          hucreler.add(SizedBox(width: cellW));
          continue;
        }
        kullanilan.add(id);
        hucreler.add(_dirCell(d, cellW));
      }
      satirlar.add(Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: hucreler,
      ));
    }
    final ekstra = _dirs.where((d) => !kullanilan.contains(d.id)).toList();
    return Column(
      children: [
        for (final s in satirlar) ...[s, SizedBox(height: bosluk)],
        if (ekstra.isNotEmpty) ...[
          Wrap(
            spacing: bosluk,
            runSpacing: bosluk,
            alignment: WrapAlignment.center,
            children: [for (final d in ekstra) _dirCell(d, cellW)],
          ),
          SizedBox(height: bosluk),
        ],
      ],
    );
  }

  Widget _dirCell(CharacterDir d, double cellW) {
    final kabul = _skin.dirs[d.id] == true;
    final adaylar = _skin.dirCandidates[d.id] ?? const <String>[];
    final rel = _skin.dirFiles[d.id] ??
        CharacterFlowService.dirRel(_skin.slug, d.id);
    final String? url = kabul
        ? _thumb(rel, size: 600)
        : (adaylar.isEmpty ? null : _thumb(adaylar.last, size: 600));
    return _ThumbCell(
      label: d.label,
      url: url,
      accepted: kabul,
      dimmed: !kabul && adaylar.isNotEmpty,
      badge: (!kabul && adaylar.isNotEmpty) ? '${adaylar.length} aday - sec' : null,
      width: cellW,
      thumbHeight: cellW * 16 / 9,
      onTap: () => (kabul || adaylar.isEmpty)
          ? _openAnim(d.id, _animMode)
          : _dirSheet(d),
      onLongPress: () => _dirSheet(d),
      onAnim: () => _openAnim(d.id, 'i2v'),
      // #314: hayvan/makine turunde Mixamo ikonu hic cizilmez.
      onMixamo: _mixamoOn ? () => _openAnim(d.id, 'mixamo') : null,
      // #306 ince ayar: base skininde S = base'in kendisi.
      onEdit: () => _edit(
          _skin.isBase
              ? (d.id == 'front' ? 'base' : 'dir:${d.id}')
              : 'skin:${_skin.slug}:${d.id}',
          d.label),
      onRefresh: () => _run('${d.label} uretimi', () => _genDirs([d.id]),
          adet: _dirCount),
      onDelete: () => _deleteDir(d),
    );
  }

  /// #306 ince ayar: ✎ Duzenle - kabul edilen gorseli kisa bir duzeltme
  /// cumlesiyle degistirir; sonuc otomatik kabul edilir, eskisi aday kalir.
  Future<void> _edit(String target, String baslik) async {
    final p = await editPromptDialog(context, baslik);
    if (p == null) return;
    await _run('$baslik duzenleme',
        () => CharacterFlowService.edit(name: _name, target: target, prompt: p),
        adet: 1);
  }

  /// Yonun buyuk onizlemesi + adaylari. Kabul kind'i skine gore degisir:
  /// base -> `dir:<yon>`, skin -> `skin:<slug>:<yon>` (#306).
  Future<void> _dirSheet(CharacterDir d) async {
    final adaylar = _skin.dirCandidates[d.id] ?? const <String>[];
    final kabul = _skin.dirs[d.id] == true;
    final rel =
        _skin.dirFiles[d.id] ?? CharacterFlowService.dirRel(_skin.slug, d.id);
    final kind = _skin.isBase ? 'dir:${d.id}' : 'skin:${_skin.slug}:${d.id}';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${d.label}  (${d.azimuth} derece)',
                    style:
                        const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (kabul)
                  SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: Image.network(
                      _file(rel),
                      headers: CharacterFlowService.authHeaders,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox(height: 120),
                    ),
                  ),
                const SizedBox(height: 8),
                if (adaylar.isEmpty)
                  const Text('Aday yok - yenile ikonuyla uret.',
                      style: TextStyle(fontSize: 12, color: Colors.grey))
                else ...[
                  const Text('Adaylar - dokunarak kabul et',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 176,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: adaylar.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () {
                          Navigator.pop(c);
                          _pickFile(adaylar[i], kind, '${d.label} kabul edildi');
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 99,
                            child: ColoredBox(
                              color: Colors.black26,
                              child: Image.network(
                                _thumb(adaylar[i], size: 400),
                                headers: CharacterFlowService.authHeaders,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    Container(color: Colors.white10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile(String rel, String kind, String mesaj) async {
    try {
      final op =
          await CharacterFlowService.pick(name: _name, file: rel, kind: kind);
      _snack(mesaj);
      if (op.isNotEmpty) _watch(op);
      _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteDir(CharacterDir d) async {
    if (!await _confirm(
        '${d.label} sil', '${d.label} gorseli silinecek. Adaylar kalir.')) {
      return;
    }
    try {
      await CharacterFlowService.deleteDir(
          name: _name, dir: d.id, skin: _skinArg);
      _snack('${d.label} silindi');
      _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Animasyon sekmesini o yon secili ve istenen uretim yolunda acar.
  void _openAnim(String dir, String mode) {
    setState(() {
      _animDir = dir;
      // #314: mixamo kapaliysa kip her zaman i2v kalir.
      _animMode = (!_mixamoOn || mode != 'mixamo') ? 'i2v' : 'mixamo';
      _clips = [];
      _mixResults = [];
      _mixSuggest = [];
      _mixSel.clear();
    });
    _tabs.animateTo(1);
    _loadClips(dir);
  }

  // --------------------------------------------------------- Animasyon
  Widget _tabAnimasyon() {
    final dir = _animDir;
    return ListView(
      padding: bottomSafePadding(context,
          left: 12, top: 10, right: 12, bottom: 24),
      children: [
        dirCompass(
          _dirs,
          spacing: 5,
          center: const Center(
              child: Text('yon', style: TextStyle(fontSize: 10, color: Colors.grey))),
          cell: _animDirButton,
        ),
        const SizedBox(height: 10),
        if (dir == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Bir yon sec - her yon ayri bir animasyon kumesidir '
              '(anims / yon / klip / vNN).',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          )
        else ...[
          _modeSwitch(),
          const SizedBox(height: 10),
          // #314: mixamo kapaliysa yalniz i2v paneli cizilir.
          if (!_mixamoOn || _animMode == 'i2v')
            _i2vPanel(dir)
          else
            _mixamoPanel(dir),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text('${_clips.length} klip - $dir',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              TextButton.icon(
                onPressed: _clipSetSheet,
                icon: const Icon(Icons.list_alt, size: 16),
                label: const Text('Klip seti'),
              ),
            ],
          ),
          if (_clipsLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_clips.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Bu yonde henuz animasyon yok.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            )
          else
            for (final c in _clips) ...[
              _clipCard(dir, c),
              const SizedBox(height: 10),
            ],
        ],
      ],
    );
  }

  /// #314: kip anahtari yalniz manken/Mixamo acikken cizilir; hayvan/makinede
  /// yerine kisa bir aciklama satiri durur (yol tek: i2v).
  Widget _modeSwitch() => _mixamoOn
      ? SegmentedButton<String>(
          segments: const [
            ButtonSegment(
                value: 'i2v',
                icon: Icon(Icons.movie_filter_outlined, size: 16),
                label: Text('AI i2v')),
            ButtonSegment(
                value: 'mixamo',
                icon: Icon(Icons.accessibility_new, size: 16),
                label: Text('Mixamo')),
          ],
          selected: {_animMode},
          showSelectedIcon: false,
          onSelectionChanged: (v) => setState(() => _animMode = v.first),
        )
      : const Text(
          'Bu turde animasyon yalniz AI i2v ile uretilir - manken/Mixamo '
          'insansi iskelet ister.',
          style: TextStyle(fontSize: 11, color: Colors.grey));

  /// #295: yastiklama secici + aciklama. Asil yeri burasi: uretimden HEMEN
  /// once sorulur. Deger karakter basinadir (`character.json`) ve
  /// `animate(padding: ...)` ile gonderilir, yani butun klipler icin ayni kalir.
  Widget _paddingRow(ValueChanged<double> onChanged) {
    final kabulVar = _clips.any((c) => c.accepted.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PaddingPicker(
            value: _padding,
            onChanged: (v) {
              onChanged(v);
              // #295: secim karakter basina kalici (character.json).
              CharacterFlowService.savePadding(_name, v).catchError(
                  (e) => _snack(e.toString().replaceFirst('Exception: ', '')));
            }),
        Text(
          'Yastiklama referans gorseli kuculterek kadraj payi birakir; '
          'butun klipler icin ayni kalmali.'
          '${kabulVar ? " Bu yonde kabul edilmis klip var - degistirirsen bundan sonraki klipler yeni degerle uretilir." : ""}',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _countSlider() => Row(
        children: [
          Text('Surum: $_animCount',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Expanded(
            child: Slider(
              value: _animCount.toDouble(),
              min: 1,
              max: 6,
              divisions: 5,
              label: '$_animCount',
              onChanged: (v) => setState(() => _animCount = v.round()),
            ),
          ),
        ],
      );

  /// Saf AI yolu: kullanicinin yazdigi hareket cumlesi + kipin video sablonu.
  Widget _i2vPanel(String dir) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hareket - saf AI (i2v)',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _i2vPrompt,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Ne yapsin',
                        hintText: 'orn. tekme  ->  degnek tam tarife cevirir',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  _wandButton(dir, 'i2v'),
                ],
              ),
              const Text(
                  'Degnek kisa istegi karakterin sinifina/silahina gore tam '
                  'hareket tarifine cevirir; metin duzenlenebilir.',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _i2vClip,
                decoration: const InputDecoration(
                  labelText: 'Klip adi (bos birakilirsa prompttan turetilir)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              // #295: yastiklama uretim dugmesinin hemen ustunde sorulur.
              _paddingRow((v) => setState(() => _padding = v)),
              _countSlider(),
              FilledButton.icon(
                onPressed: () {
                  if (_i2vPrompt.text.trim().isEmpty) {
                    _snack('Hareket cumlesi bos olamaz');
                    return;
                  }
                  _run(
                      'i2v animasyonu',
                      () => CharacterFlowService.animate(
                            name: _name,
                            dir: dir,
                            skin: _skinArg,          // #306
                            mode: 'i2v',
                            prompt: _i2vPrompt.text.trim(),
                            clip: _i2vClip.text.trim(),
                            n: _animCount,
                            padding: _padding,
                          ),
                      adet: _animCount);
                },
                icon: const Icon(Icons.movie_filter_outlined, size: 18),
                label: Text('Uret ($_animCount surum)'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              ),
            ],
          ),
        ),
      );

  /// Mixamo yolu: arsivden klip secmek ZORUNLU (Blender manken -> Wan Animate 2).
  Widget _mixamoPanel(String dir) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mixamo arsivi - 1975 FBX',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mixWish,
                      decoration: const InputDecoration(
                        labelText: 'Kisa istek (Ollama)',
                        hintText: 'orn. tekme, zafer, olum',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  _wandButton(dir, 'mixamo'),
                ],
              ),
              if (_mixSuggest.isNotEmpty) ...[
                const SizedBox(height: 6),
                const Text('Ollama onerileri',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _mixSuggest.length,
                    itemBuilder: (_, i) {
                      final m = _mixSuggest[i];
                      final on = _mixSel.contains(m.fbx);
                      return CheckboxListTile(
                        dense: true,
                        value: on,
                        contentPadding: EdgeInsets.zero,
                        title: Text(m.name, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(m.why.isEmpty ? m.fbx : m.why,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10)),
                        onChanged: (_) => setState(
                            () => on ? _mixSel.remove(m.fbx) : _mixSel.add(m.fbx)),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _mixQuery,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Ara',
                  hintText: 'orn. great sword slash',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: _mixBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search),
                    onPressed: _searchMixamo,
                  ),
                ),
                onSubmitted: (_) => _searchMixamo(),
              ),
              const SizedBox(height: 8),
              if (_mixResults.isEmpty)
                const Text('Arama yap ve klip sec.',
                    style: TextStyle(fontSize: 12, color: Colors.grey))
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _mixResults.length,
                    itemBuilder: (_, i) {
                      final m = _mixResults[i];
                      final on = _mixSel.contains(m.fbx);
                      return CheckboxListTile(
                        dense: true,
                        value: on,
                        contentPadding: EdgeInsets.zero,
                        title: Text(m.name, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                            m.hash.isEmpty ? m.fbx : '${m.hash}  -  ${m.fbx}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10)),
                        onChanged: (_) => setState(
                            () => on ? _mixSel.remove(m.fbx) : _mixSel.add(m.fbx)),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              // #295: yastiklama uretim dugmesinin hemen ustunde sorulur.
              _paddingRow((v) => setState(() => _padding = v)),
              _countSlider(),
              FilledButton.icon(
                onPressed: _mixSel.isEmpty
                    ? null
                    : () => _run(
                        'Mixamo animasyonu',
                        () => CharacterFlowService.animate(
                              name: _name,
                              dir: dir,
                              skin: _skinArg,        // #306
                              mode: 'mixamo',
                              clips: _mixSel.toList(),
                              n: _animCount,
                              padding: _padding,
                            ),
                        adet: _mixSel.length * _animCount),
                icon: const Icon(Icons.accessibility_new, size: 18),
                label: Text('Uret (${_mixSel.length} klip x $_animCount)'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              ),
            ],
          ),
        ),
      );

  /// rev8: kisa istegi Ollama ile genisletir. 503 = Ollama kapali -> dugme
  /// pasiflesir, duz akis calismaya devam eder.
  Future<void> _wand(String dir, String mode) async {
    final istek = (mode == 'i2v' ? _i2vPrompt.text : _mixWish.text).trim();
    if (istek.isEmpty) {
      _snack('Once kisa bir istek yaz (orn. "tekme", "zafer")');
      return;
    }
    setState(() => _wandBusy = true);
    try {
      final r = await CharacterFlowService.expandPrompt(
          name: _name, dir: dir, text: istek, mode: mode, skin: _skinArg);
      if (!mounted) return;
      setState(() {
        _wandBusy = false;
        if (mode == 'i2v') {
          if (r.prompt.isNotEmpty) _i2vPrompt.text = r.prompt;
        } else {
          _mixSuggest = r.clips;
        }
      });
      if (mode == 'i2v' && r.prompt.isEmpty) _snack('Ollama bos cevap dondu');
      if (mode == 'mixamo' && r.clips.isEmpty) _snack('Oneri gelmedi');
    } on OllamaOffException {
      if (!mounted) return;
      setState(() {
        _wandBusy = false;
        _ollamaOff = true;
      });
      _snack('Ollama kapali - duz akis calisiyor');
    } catch (e) {
      if (!mounted) return;
      setState(() => _wandBusy = false);
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Sihirli degnek dugmesi - Ollama kapaliysa pasif, ipucu metni degisir.
  Widget _wandButton(String dir, String mode) => IconButton(
        tooltip: _ollamaOff ? 'Ollama kapali' : 'Ollama ile genislet',
        onPressed: (_ollamaOff || _wandBusy) ? null : () => _wand(dir, mode),
        icon: _wandBusy
            ? const SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.auto_fix_high),
      );

  Future<void> _searchMixamo() async {
    final q = _mixQuery.text.trim();
    if (q.isEmpty) return;
    setState(() => _mixBusy = true);
    try {
      final r = await CharacterFlowService.mixamo(q);
      if (!mounted) return;
      setState(() {
        _mixResults = r;
        _mixBusy = false;
      });
      if (r.isEmpty) _snack('Sonuc yok');
    } catch (e) {
      if (!mounted) return;
      setState(() => _mixBusy = false);
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Yon dugmesi - uzerinde o yonun kabul edilmis / toplam klip sayaci.
  Widget _animDirButton(CharacterDir d) {
    var total = 0, ok = 0;
    _skin.anims.forEach((_, byDir) {
      final s = byDir[d.id];
      if (s != null) {
        total++;
        if (s.wan) ok++;
      }
    });
    if (_animDir == d.id && _clips.isNotEmpty) {
      total = _clips.length;
      ok = _clips.where((c) => c.accepted.isNotEmpty).length;
    }
    final on = _animDir == d.id;
    return InkWell(
      onTap: () => _openAnim(d.id, _animMode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: on ? AppColors.accent : Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // #294: dar sutunda yazi tasmasin.
            Text(d.short,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: on ? Colors.white : Colors.white70)),
            Text('$ok/$total',
                style: TextStyle(
                    fontSize: 10, color: on ? Colors.white70 : Colors.grey)),
          ],
        ),
      ),
    );
  }

  /// rev4: kart anim.webp'yi donguyle gosterir; sprite yoksa kabul edilen
  /// surumun ilk karesi ve one cikan "Sprite cikar" dugmesi.
  Widget _clipCard(String dir, CharacterClip c) {
    final kabul = c.accepted;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // #294: uzun klip/surum adinda satir tasiyordu - baslik ellipsis,
            // rozetler Wrap ile alta sarar.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(c.clip,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Flexible(
                  flex: 2,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    runSpacing: 2,
                    children: [
                      if (kabul.isNotEmpty)
                        _rozet('kabul $kabul', Colors.green.shade700)
                      else
                        _rozet('kabul yok', Colors.orange.shade800),
                      _rozet('${c.versions.length} surum', Colors.blueGrey),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: Colors.black,
                  height: 168,
                  width: 168,
                  child: c.hasSprite
                      ? Image.network(
                          _file(c.webpRel(dir, skin: _skinArg)),
                          headers: CharacterFlowService.authHeaders,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => _noSprite(),
                        )
                      : kabul.isEmpty
                          ? _noSprite()
                          : Image.network(
                              _thumb(c.acceptedRel(dir, skin: _skinArg),
                                  size: 400),
                              headers: CharacterFlowService.authHeaders,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => _noSprite(),
                            ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: kabul.isEmpty
                      ? null
                      : () => _playVideo(c.acceptedRel(dir, skin: _skinArg),
                          '$dir / ${c.clip} / $kabul'),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Videoyu izle'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _versionsSheet(dir, c),
                  icon: const Icon(Icons.layers_outlined, size: 18),
                  label: Text('Surumler (${c.versions.length})'),
                ),
                c.hasSprite
                    ? OutlinedButton.icon(
                        onPressed: kabul.isEmpty ? null : () => _sprite(dir, c.clip),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Sprite yeniden'),
                      )
                    : FilledButton.icon(
                        onPressed: kabul.isEmpty ? null : () => _sprite(dir, c.clip),
                        icon: const Icon(Icons.grid_on, size: 18),
                        label: const Text('Sprite cikar'),
                      ),
                OutlinedButton.icon(
                  onPressed: () => _deleteClip(dir, c),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Sil'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _noSprite() => Container(
        color: Colors.white10,
        alignment: Alignment.center,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Text('sprite yok',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ),
      );

  void _sprite(String dir, String clip) => _run(
      'Sprite',
      () => CharacterFlowService.sprites(
          name: _name, dir: dir, clips: [clip], skin: _skinArg),
      adet: 1);

  /// Videoyu oynatir - yol sunucudan gelen rel'dir (istemci yol uydurmaz).
  void _playVideo(String rel, String baslik) {
    if (rel.isEmpty) {
      _snack('Video yok');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: NetworkVideo(
                url: _file(rel),
                headers: CharacterFlowService.authHeaders,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(baslik,
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  /// Surum listesi: oynat / kabul et (tek) / sil / + uret.
  Future<void> _versionsSheet(String dir, CharacterClip c) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // #295: yastiklama secici sayfada oldugu icin StatefulBuilder gerekli.
      builder: (sheet) => StatefulBuilder(
        builder: (_, setS) => SafeArea(
          // Liste + "+ Uret" dugmesi yatay ekranda tasiyordu (gorev #289).
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$dir / ${c.clip}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (c.versions.isEmpty)
                    const Text('Surum yok.',
                        style: TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final v in c.versions)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                  c.accepted == v.v
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: c.accepted == v.v
                                      ? Colors.green
                                      : Colors.grey),
                              title: Text(v.v,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                  '${v.hasWan ? "wan" : "yalniz manken"}'
                                  '${v.seed == null ? "" : "  -  seed ${v.seed}"}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11)),
                              // #294: uc dugme dar ekranda ListTile'i tasiriyordu.
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Oynat',
                                    icon: const Icon(Icons.play_arrow, size: 20),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints.tightFor(
                                        width: 34, height: 34),
                                    onPressed: () => _playVideo(
                                        v.relFor(dir, c.clip, skin: _skinArg),
                                        '$dir / ${c.clip} / ${v.v}'),
                                  ),
                                  IconButton(
                                    tooltip: 'Kabul et',
                                    icon: const Icon(Icons.check, size: 20),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints.tightFor(
                                        width: 34, height: 34),
                                    onPressed: v.hasWan
                                        ? () {
                                            Navigator.pop(sheet);
                                            _accept(dir, c.clip, v.v);
                                          }
                                        : null,
                                  ),
                                  IconButton(
                                    tooltip: 'Sil',
                                    icon: Icon(Icons.delete_outline,
                                        size: 20, color: AppColors.error),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints.tightFor(
                                        width: 34, height: 34),
                                    onPressed: () {
                                      Navigator.pop(sheet);
                                      _deleteVersion(dir, c.clip, v.v);
                                    },
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  // #295: burada da uretim var - yastiklama dugmenin hemen ustunde.
                  _paddingRow((v) {
                    setState(() => _padding = v);
                    setS(() {});
                  }),
                  const SizedBox(height: 6),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheet);
                      _run(
                          '${c.clip} animasyonu',
                          () => CharacterFlowService.animate(
                                name: _name,
                                dir: dir,
                                skin: _skinArg,      // #306
                                mode: _animMode,
                                clips:
                                    _animMode == 'mixamo' ? [c.clip] : const [],
                                clip: _animMode == 'i2v' ? c.clip : '',
                                prompt: _animMode == 'i2v'
                                    ? _i2vPrompt.text.trim()
                                    : '',
                                n: _animCount,
                                padding: _padding,
                              ),
                          adet: _animCount);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('+ Uret ($_animCount)'),
                    style:
                        FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _accept(String dir, String clip, String v) async {
    try {
      await CharacterFlowService.accept(
          name: _name, dir: dir, clip: clip, version: v, skin: _skinArg);
      _snack('$clip -> $v kabul edildi');
      await _loadClips(dir);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteVersion(String dir, String clip, String v) async {
    if (!await _confirm('Surumu sil', '$dir / $clip / $v silinecek.')) return;
    try {
      await CharacterFlowService.deleteVersion(
          name: _name, dir: dir, clip: clip, version: v, skin: _skinArg);
      await _loadClips(dir);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Klibi bu yonden kaldirir: butun surumleri silinir. Klip seti anims.json'da
  /// durur - baska yonde/skinde kullanilabilir.
  Future<void> _deleteClip(String dir, CharacterClip c) async {
    if (!await _confirm('Klibi sil',
        '$dir / ${c.clip} altindaki ${c.versions.length} surum silinecek.')) {
      return;
    }
    try {
      await CharacterFlowService.deleteClip(
          name: _name, dir: dir, clip: c.clip, skin: _skinArg);
      _snack('${c.clip} silindi');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
    await _loadClips(dir);
  }

  // -------------------------------------------------- klip seti (anims.json)
  /// Klip ekle / cikar. anims.json GET/PUT ile guncellenir - klip seti butun
  /// skinlerde ortaktir (design/karakter_hatti_v2.md §1).
  Future<void> _clipSetSheet() async {
    Map<String, dynamic> data;
    try {
      data = await CharacterFlowService.anims(_name);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    if (!mounted) return;
    final clips = Map<String, dynamic>.from((data['clips'] as Map?) ?? {});
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet2, setS) => SafeArea(
          // Liste + dugme satiri yatay ekranda tasiyordu (gorev #289).
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Klip seti (anims.json - butun skinler ortak)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final e in clips.entries)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            // #294: uzun klip adi tasmasin.
                            title: Text(e.key,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                                '${(e.value is Map ? (e.value as Map)['fbx'] : '') ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11)),
                            trailing: IconButton(
                              icon: Icon(Icons.remove_circle_outline,
                                  color: AppColors.error, size: 20),
                              onPressed: () => setS(() => clips.remove(e.key)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // #314: Mixamo arsivi yalniz insan turlerinde acilir -
                      // hayvan/makinede klip seti yalniz duzenlenir.
                      if (_mixamoOn) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final yeni = await _clipFromMixamo();
                              if (yeni != null) {
                                setS(() => clips[yeni.$1] = {
                                      'fbx': yeni.$2,
                                      'pose': yeni.$3,
                                    });
                              }
                            },
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text('Mixamo ara / ekle'),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else
                        const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          Navigator.pop(sheet);
                          try {
                            data['clips'] = clips;
                            await CharacterFlowService.saveAnims(_name, data);
                            _snack('Klip seti kaydedildi');
                            if (_animDir != null) await _loadClips(_animDir!);
                          } catch (e) {
                            _snack(e.toString().replaceFirst('Exception: ', ''));
                          }
                        },
                        child: const Text('Kaydet'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mixamo arsivinde arar; secilen fbx icin klip adi ve poz cumlesi sorar.
  Future<(String, String, String)?> _clipFromMixamo() async {
    final q = TextEditingController();
    var sonuc = <MixamoClip>[];
    final secilen = await showDialog<MixamoClip>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c2, setS) => AlertDialog(
          // Otomatik odakli arama kutusu + 280px sonuc listesi klavyeyle
          // tasiyordu (gorev #289).
          scrollable: true,
          title: const Text('Mixamo arsivi'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: q,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Ara',
                    hintText: 'orn. great sword slash',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (v) async {
                    try {
                      final r = await CharacterFlowService.mixamo(v);
                      setS(() => sonuc = r);
                    } catch (e) {
                      _snack(e.toString().replaceFirst('Exception: ', ''));
                    }
                  },
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: sonuc.isEmpty
                      ? const Text('Arama yap.',
                          style: TextStyle(fontSize: 12, color: Colors.grey))
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final m in sonuc)
                              ListTile(
                                dense: true,
                                title: Text(m.name,
                                    style: const TextStyle(fontSize: 13)),
                                subtitle: Text(m.hash,
                                    style: const TextStyle(fontSize: 10)),
                                onTap: () => Navigator.pop(c, m),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgec')),
          ],
        ),
      ),
    );
    if (secilen == null || !mounted) return null;
    final ad =
        TextEditingController(text: secilen.name.toLowerCase().replaceAll(' ', '_'));
    final poz = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        // Iki metin kutusu (biri 3 satir) klavyeyle tasiyordu (gorev #289).
        scrollable: true,
        title: const Text('Klip ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(secilen.fbx, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: ad,
              decoration: const InputDecoration(
                  labelText: 'Klip adi', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: poz,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Poz cumlesi (Wan prompt)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: const Text('Vazgec')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: const Text('Ekle')),
        ],
      ),
    );
    if (ok != true || ad.text.trim().isEmpty) return null;
    return (ad.text.trim(), secilen.fbx, poz.text.trim());
  }

  Widget _rozet(String t, Color c) => Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
        child: Text(t, style: const TextStyle(fontSize: 9, color: Colors.white)),
      );
}
