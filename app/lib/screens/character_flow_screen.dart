import 'dart:async';

import 'package:flutter/material.dart';

import '../services/character_flow_service.dart';
import '../services/jigsaw_flow_service.dart' show FlowOp;
import '../services/mode_service.dart';
import '../theme.dart';
import '../widgets/bottom_inset.dart';
import '../widgets/network_video.dart';

/// Asset Mod - Karakter hatti.
///
/// Jigsaw/CBN'deki 2-3-4 akisi burada YOKTUR. Karakter uc asamada olusur:
///   1 Karakter   Uretim'de "Karakter Modu" ile aday uret -> birini kabul et
///                (Gorunus / Base / Portre); card.md Ollama ile zenginlestirilir.
///   2 Yon        Yuvarlak duzen: ortada base, cevresinde 8 yon, altta portre.
///                Tek dokunus o yonun animasyon ekranini acar, basili tutma
///                buyutur. Her kucuk resmin altinda 4 ikon: anim (AI i2v),
///                Mixamo, yalniz bunu yeniden uret, sil.
///   3 Animasyon  Her yon AYRI kumedir (`anims/<yon>/<klip>/vNN`). Kartta
///                anim.webp doner; altinda videoyu izle / surumler / sprite /
///                sil. Uretim iki yoldan: saf AI i2v ya da Mixamo manken.
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
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? errorView(_error!, _load)
                : _items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: Text(
                            'Henuz karakter yok.\n\n"Uretilenler" ekraninda Karakter Modu\'na '
                            'gec, begendigin isi sec ve "Karakter yap" de.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
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
        content: const Text('Karakter klasoru, adaylari, yonleri ve butun '
            'animasyonlari silinir. GERI ALINAMAZ.'),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 66,
                  height: 117,
                  child: c.lookThumb.isEmpty
                      ? Container(
                          color: Colors.white10,
                          child: const Icon(Icons.person_outline, color: Colors.grey))
                      : ColoredBox(
                          color: Colors.black26,
                          child: Image.network(
                            CharacterFlowService.thumbUrl(c.name, c.lookThumb,
                                size: 300),
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
                    Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
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
                          'sprite $ok/$total',
                          'aday ${c.candidateCount}',
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
}

// ---------------------------------------------------------------- ortak

/// 8 yonu pusula duzeninde (3x3, orta hucre serbest) dizer. Sunucu listede
/// tanimadigimiz bir yon gonderirse izgaranin altina eklenir - hicbir yon
/// gozden kaybolmasin.
// #301: gercek pusula dizilimi - North ustte, South (kameraya bakan) altta.
const _compassGrid = [
  ['back_left', 'back', 'back_right'],      // NW  N  NE
  ['left', '', 'right'],                    // W  BASE E
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

/// Yuvarlak Yon ekranindaki tek kucuk resim: gorsel + kabul/ret rozeti +
/// altinda 4 ikon dugme (anim / mixamo / yenile / sil). Yazi yoktur.
class _ThumbCell extends StatelessWidget {
  const _ThumbCell({
    required this.label,
    required this.url,
    required this.accepted,
    required this.width,
    required this.thumbHeight,
    required this.onTap,
    required this.onLongPress,
    required this.onAnim,
    required this.onMixamo,
    required this.onRefresh,
    required this.onDelete,
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
  final VoidCallback onAnim;
  final VoidCallback onMixamo;
  final VoidCallback onRefresh;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // rev4: tek dokunus = o yonun animasyon ekrani, basili tutma = buyuk.
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
                _ico(Icons.movie_filter_outlined, 'Anim uret (AI i2v)', onAnim),
                _ico(Icons.accessibility_new, 'Mixamo ile uret', onMixamo),
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

// ---------------------------------------------------------------- detay

/// Tek karakterin uc asamali detayi: 1 Karakter / 2 Yon / 3 Animasyon.
class CharacterDetailPage extends StatefulWidget {
  const CharacterDetailPage({super.key, required this.name, required this.dirs});

  final String name;
  final List<CharacterDir> dirs;

  @override
  State<CharacterDetailPage> createState() => _CharacterDetailPageState();
}

class _CharacterDetailPageState extends State<CharacterDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });

  CharacterItem? _item;
  bool _loading = true;
  String? _error;

  FlowOp? _op;
  Timer? _opPoll;

  // 1 Karakter
  String? _candidate;
  /// #299: card.md icin bekleyen Ollama onerileri - pop-up yerine liste.
  List<CardProposal> _proposals = [];

  // 2 Yon
  int _dirCount = 2;

  // 3 Animasyon
  String? _animDir;
  String _animMode = 'i2v';           // i2v (saf AI) | mixamo (manken)
  List<CharacterClip> _clips = [];
  bool _clipsLoading = false;
  int _animCount = 1;
  /// rev5: yastiklama (0 / 0.1 / 0.2 / 0.3). Varsayilan character.json'dan
  /// gelir; butun klipler icin ayni tutulmali.
  double _padding = 0;
  bool _paddingInit = false;
  final _i2vPrompt = TextEditingController();
  final _i2vClip = TextEditingController();
  final _mixQuery = TextEditingController();
  List<MixamoClip> _mixResults = [];
  final Set<String> _mixSel = {};
  bool _mixBusy = false;
  // rev8: Ollama animasyon asistani
  final _mixWish = TextEditingController();      // kisa istek ("tekme", "zafer")
  List<MixamoClip> _mixSuggest = [];             // Ollama'nin onerdigi adaylar
  bool _wandBusy = false;
  bool _ollamaOff = false;                       // 503 gelince pasiflesir

  String get _name => widget.name;
  List<CharacterDir> get _dirs => widget.dirs;

  /// base ve portre de birer "yon" gibi ele alinir: kendi `anims/<dir>` kumeleri,
  /// kendi yenile/sil dugmeleri vardir.
  static const _baseDir = 'base';
  static const _portraitDir = 'portrait';

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
        if (it != null && !_paddingInit) {
          _padding = it.padding;
          _paddingInit = true;
        }
        if (_candidate != null && !(it?.candidates.contains(_candidate) ?? false)) {
          _candidate = null;
        }
      });
      // #299: oneriler de her tazelemede yenilenir (enrich op'u bitince
      // _watch zaten _load cagirir).
      await _loadProposals();
      if (_animDir != null) await _loadClips(_animDir!);
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

  Future<void> _loadClips(String dir) async {
    setState(() => _clipsLoading = true);
    try {
      final c = await CharacterFlowService.animsOf(_name, dir);
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

  /// CBN ekranindaki izleyicinin aynisi: bitene kadar 2 sn'de bir sorar,
  /// bittiginde listeyi tazeler.
  void _watch(String opId) {
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

  /// #299: is artik tek sunucu sirasina girer. Kullanici bu ekranda beklemek
  /// zorunda degil - snack Sira sekmesine yollar, ust cubuk yine doner.
  /// `adet` biliniyorsa kac is sirayaya girdigi yazilir.
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
        title: Text(_name),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), tooltip: 'Yenile', onPressed: _load),
        ],
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: '1 Karakter'),
          Tab(text: '2 Yon'),
          Tab(text: '3 Animasyon'),
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
                              _tabAnimasyon(it),
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

  // ------------------------------------------------------- 1 Karakter
  Widget _tabKarakter(CharacterItem it) {
    final adaylar = it.candidates;
    return ListView(
      // Tam ekran route, alt cubuk yok: sistem gezinme cubugunu ekle (gorev #289).
      padding: bottomSafePadding(context,
          left: 12, top: 12, right: 12, bottom: 12),
      children: [
        // #293: kutular sabit 72x104 idi, ustteki gorseller okunmuyordu.
        // Artik uc kutu genisligi paylasir (9:16), sinif/aday yazisi ALTA indi.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _lookBox('Gorunus', it.lookThumb)),
            const SizedBox(width: 8),
            Expanded(child: _lookBox('Base', it.baseThumb)),
            const SizedBox(width: 8),
            Expanded(child: _lookBox('Portre', it.portraitThumb)),
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
        const SizedBox(height: 12),
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
        // #299: "Hikaye onerileri" bolumu - zenginlestir dugmesinin hemen alti.
        const SizedBox(height: 12),
        _proposalsSection(),
        // #295: yastiklama secici buradan kaldirildi - asil yeri 3 Animasyon
        // sekmesindeki uretim panelleri (uretimden HEMEN once sorulur).
        const SizedBox(height: 14),
        _portraitRow(it),
        const SizedBox(height: 14),
        const Text('Adaylar - birini sec, sonra Gorunus ya da Base yap',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        if (adaylar.isEmpty)
          Text(
            it.candidateCount > 0
                ? '${it.candidateCount} aday var ama sunucu dosya listesini '
                    'gondermedi - listeyi yenile.'
                : 'Aday yok. "Uretilenler" ekraninda Karakter Modu\'nda is sec '
                    've "Adaylara ekle" de.',
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
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _candidate == null ? null : () => _pick('look'),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Gorunus yap'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _candidate == null ? null : () => _pick('base'),
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('Base yap'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Gorunus = animasyona giren kostumlu tam boy kare. Base = notr kimlik '
          'karesi (siyah bikini, beyaz fon). Portre = bas-omuz yakin plan.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
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
            // #293: portre serisi de kirpilmasin - 3:4 kutu + contain.
            SizedBox(
              height: 128,
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
                      width: 96,
                      child: ColoredBox(
                        color: Colors.black26,
                        child: Image.network(
                          CharacterFlowService.thumbUrl(_name, it.portraits[i],
                              size: 400),
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

  /// #293: kutu artik satirdaki payini kaplar (9:16), dokunmak tam boyu acar.
  /// Gorsel `contain` cizilir - kafa/ayak kirpilmaz.
  Widget _lookBox(String baslik, String rel) => GestureDetector(
        onTap: () => _big(baslik, rel),
        onLongPress: () => _big(baslik, rel),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: rel.isEmpty
                    ? Container(
                        color: Colors.white10,
                        alignment: Alignment.center,
                        child: const Text('yok',
                            style: TextStyle(fontSize: 12, color: Colors.grey)))
                    : ColoredBox(
                        color: Colors.black26,
                        child: Image.network(
                          CharacterFlowService.thumbUrl(_name, rel, size: 600),
                          headers: CharacterFlowService.authHeaders,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              Container(color: Colors.white10),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(baslik,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      );

  Widget _candidateTile(String rel) {
    final on = _candidate == rel;
    return GestureDetector(
      onTap: () => setState(() => _candidate = on ? null : rel),
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
                CharacterFlowService.thumbUrl(_name, rel),
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

  Future<void> _pick(String kind) async {
    final f = _candidate;
    if (f == null) return;
    await _pickFile(f, kind, kind == 'look' ? 'Gorunus secildi' : 'Base secildi');
  }

  Future<void> _pickFile(String rel, String kind, String mesaj) async {
    try {
      await CharacterFlowService.pick(name: _name, file: rel, kind: kind);
      _snack(mesaj);
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
  /// rev3/rev4: yuvarlak duzen. Ortada base, cevresinde pusula gibi 8 yon,
  /// altta portre. Tek dokunus o yonun animasyon ekranini acar, basili tutma
  /// buyuk gosterir; her kucuk resmin altinda 4 ikon dugme durur.
  Widget _tabYon(CharacterItem it) {
    final eksik = _dirs.where((d) => d.id != 'front' && it.dirs[d.id] != true).toList();
    return ListView(
      // Tam ekran route, alt cubuk yok: sistem gezinme cubugunu ekle (gorev #289).
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
              : 'Hepsini uret (${eksik.length} yon x $_dirCount)'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        ),
        const SizedBox(height: 10),
        // #292: yuvarlak duzen dar telefonda hucreleri ust uste bindiriyordu -
        // yerine 3x3 izgara: FL F FR / L BASE R / BL B BR, altinda PORTRE.
        LayoutBuilder(
          builder: (_, cons) {
            const bosluk = 8.0;
            final cellW = ((cons.maxWidth - 2 * bosluk) / 3).clamp(72.0, 150.0);
            return Column(
              children: [
                _dirGrid(it, cellW, bosluk),
                SizedBox(width: cellW, child: _portraitCell(it, cellW)),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'Tek dokunus o yonun animasyon ekranini acar, basili tutma buyutur. '
          'Ikonlar: anim uret (AI i2v), Mixamo ile uret, yalniz bunu yeniden '
          'uret, sil. S (South) = kameraya bakan durus, kabul edilen gorunusun kendisi.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  /// #292: pusulanin 3x3 izgara hali. Hucre genisligi disaridan gelir
  /// (mevcut genislik / 3), yukseklik 9:16 - hicbir hucre digerine binmez.
  /// Yon kimlikleri/etiketleri yine `_dirs` ve `_compassGrid`ten gelir.
  Widget _dirGrid(CharacterItem it, double cellW, double bosluk) {
    final byId = {for (final d in _dirs) d.id: d};
    final kullanilan = <String>{};
    final satirlar = <Widget>[];
    for (final row in _compassGrid) {
      final hucreler = <Widget>[];
      for (final id in row) {
        if (hucreler.isNotEmpty) hucreler.add(SizedBox(width: bosluk));
        if (id.isEmpty) {
          hucreler.add(_baseCell(it, cellW));
          continue;
        }
        final d = byId[id];
        if (d == null) {
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
    // rozeti; dokunma aday secicisini acar (yonler "uretiliyor ama gelmiyor"
    // sanilmasin). Kabul edilmis yonde dokunma yine animasyon ekranidir.
    final String? url = kabul
        ? CharacterFlowService.thumbUrl(
            _name, CharacterFlowService.turnaroundRel(d.id), size: 600)
        : (adaylar.isEmpty
            ? null
            : CharacterFlowService.thumbUrl(_name, adaylar.last, size: 600));
    return _ThumbCell(
        label: d.label,
        url: url,
        accepted: kabul,
        dimmed: !kabul && adaylar.isNotEmpty,
        badge: (!kabul && adaylar.isNotEmpty) ? '${adaylar.length} aday - sec' : null,
        width: cellW,
        thumbHeight: cellW * 16 / 9,
        onTap: () => (kabul || adaylar.isEmpty)
            ? _openAnim(d.id, 'i2v')
            : _dirBig(it, d),
        onLongPress: () => _dirBig(it, d),
        onAnim: () => _openAnim(d.id, 'i2v'),
        onMixamo: () => _openAnim(d.id, 'mixamo'),
        onRefresh: d.id == 'front'
            ? () => _snack('S (South) gorunusun kendisidir - 1. sekmeden secilir')
            : () => _run(
                '${d.label} uretimi',
                () => CharacterFlowService.dirs(
                    name: _name, dirs: [d.id], n: _dirCount),
                adet: _dirCount),
        onDelete: () => _deleteDir(d.id, d.label),
      );
  }

  Widget _baseCell(CharacterItem it, double cellW) => _ThumbCell(
        label: 'BASE',
        url: it.baseThumb.isEmpty
            ? null
            : CharacterFlowService.thumbUrl(_name, it.baseThumb, size: 600),
        accepted: it.baseThumb.isNotEmpty,
        width: cellW,
        thumbHeight: cellW * 16 / 9,
        onTap: () => _openAnim(_baseDir, 'i2v'),
        onLongPress: () => _big('Base', it.baseThumb),
        onAnim: () => _openAnim(_baseDir, 'i2v'),
        onMixamo: () => _openAnim(_baseDir, 'mixamo'),
        onRefresh: () => _run(
            'Base uretimi',
            () => CharacterFlowService.dirs(
                name: _name, dirs: [_baseDir], n: _dirCount),
            adet: _dirCount),
        onDelete: () => _deleteDir(_baseDir, 'Base'),
      );

  /// PORTRE bas-omuz yakin plandir: 3:4 kutu (gorsel yine `contain`).
  Widget _portraitCell(CharacterItem it, double cellW) => _ThumbCell(
        label: 'PORTRE',
        url: it.portraitThumb.isEmpty
            ? null
            : CharacterFlowService.thumbUrl(_name, it.portraitThumb, size: 600),
        accepted: it.portraitThumb.isNotEmpty,
        width: cellW,
        thumbHeight: cellW * 4 / 3,
        onTap: () => _openAnim(_portraitDir, 'i2v'),
        onLongPress: () => _big('Portre', it.portraitThumb),
        onAnim: () => _openAnim(_portraitDir, 'i2v'),
        onMixamo: () => _openAnim(_portraitDir, 'mixamo'),
        onRefresh: () => _run('Portre uretimi',
            () => CharacterFlowService.portrait(name: _name, n: _dirCount),
            adet: _dirCount),
        onDelete: () => _deleteDir(_portraitDir, 'Portre'),
      );

  /// Animasyon sekmesini o yon secili ve istenen uretim yolunda acar.
  void _openAnim(String dir, String mode) {
    setState(() {
      _animDir = dir;
      _animMode = mode;
      _clips = [];
      _mixResults = [];
      _mixSuggest = [];
      _mixSel.clear();
    });
    _tabs.animateTo(2);
    _loadClips(dir);
  }

  /// Basili tutma: tam boy onizleme.
  void _big(String baslik, String rel) {
    if (rel.isEmpty) {
      _snack('$baslik yok');
      return;
    }
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
                  CharacterFlowService.fileUrl(_name, rel),
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

  /// Yonun buyuk onizlemesi + adaylari (kabul = pick `dir:<yon>`).
  Future<void> _dirBig(CharacterItem it, CharacterDir d) async {
    final adaylar = it.dirCandidates[d.id] ?? const <String>[];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        // 240px onizleme + 150px aday seridi yatay ekranda tasiyordu (gorev #289).
        child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${d.label}  (${d.azimuth} derece)',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (it.dirs[d.id] == true)
                // #292: onizleme de kirpilmasin - contain.
                SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: Image.network(
                    CharacterFlowService.fileUrl(
                        _name, CharacterFlowService.turnaroundRel(d.id)),
                    headers: CharacterFlowService.authHeaders,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox(height: 120),
                  ),
                ),
              const SizedBox(height: 8),
              if (d.id == 'front')
                const Text('S (South) kabul edilen gorunusun kendisidir - kameraya bakan durus.',
                    style: TextStyle(fontSize: 12, color: Colors.grey))
              else if (adaylar.isEmpty)
                const Text('Aday yok - yenile ikonuyla uret.',
                    style: TextStyle(fontSize: 12, color: Colors.grey))
              else ...[
                const Text('Adaylar - dokunarak kabul et',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                // #292: aday seridi 9:16 + contain - tam boy kare kirpilmiyor.
                SizedBox(
                  height: 176,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: adaylar.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () {
                        Navigator.pop(c);
                        _pickFile(
                            adaylar[i], 'dir:${d.id}', '${d.label} kabul edildi');
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 99,
                          child: ColoredBox(
                            color: Colors.black26,
                            child: Image.network(
                              CharacterFlowService.thumbUrl(_name, adaylar[i],
                                  size: 400),
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

  // ------------------------------------------------------ 3 Animasyon
  Widget _tabAnimasyon(CharacterItem it) {
    final dir = _animDir;
    return ListView(
      // Tam ekran route, alt cubuk yok: sistem gezinme cubugunu ekle (gorev #289).
      padding: bottomSafePadding(context,
          left: 12, top: 10, right: 12, bottom: 24),
      children: [
        dirCompass(
          _dirs,
          spacing: 5,
          center: const Center(
              child: Text('yon', style: TextStyle(fontSize: 10, color: Colors.grey))),
          cell: (d) => _animDirButton(it, d),
        ),
        if (dir != null && !_dirs.any((d) => d.id == dir)) ...[
          const SizedBox(height: 8),
          Chip(
            avatar: const Icon(Icons.filter_alt_outlined, size: 16),
            label: Text(dir == _baseDir ? 'base kumesi' : 'portre kumesi'),
          ),
        ],
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
          if (_animMode == 'i2v') _i2vPanel(dir) else _mixamoPanel(dir),
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

  Widget _modeSwitch() => SegmentedButton<String>(
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
      );

  /// #295: yastiklama secici + aciklama. Asil yeri burasi: uretimden HEMEN
  /// once sorulur. Deger karakter basinadir (`character.json` -> `it.padding`)
  /// ve eskisi gibi `animate(padding: ...)` ile gonderilir, yani butun klipler
  /// icin ayni kalir.
  Widget _paddingRow(ValueChanged<double> onChanged) {
    final kabulVar = _clips.any((c) => c.accepted.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PaddingPicker(
            value: _padding,
            onChanged: (v) {
              onChanged(v);
              // #295: secim karakter basina kalici (character.json) - diger
              // yonler ve sonraki klipler ayni degerle acilir.
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

  /// Saf AI yolu: kullanicinin yazdigi hareket cumlesi + kipin video sablonu
  /// (sablon sunucuda eklenir - fon cumlesi hem still hem videoda ayni).
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

  /// rev8: kisa istegi Ollama ile genisletir. i2v'de metin kutusuna yazar
  /// (kullanici duzenler), mixamo'da aday listesi doldurur. 503 = Ollama
  /// kapali -> dugme pasiflesir, duz akis calismaya devam eder.
  Future<void> _wand(String dir, String mode) async {
    final istek =
        (mode == 'i2v' ? _i2vPrompt.text : _mixWish.text).trim();
    if (istek.isEmpty) {
      _snack('Once kisa bir istek yaz (orn. "tekme", "zafer")');
      return;
    }
    setState(() => _wandBusy = true);
    try {
      final r = await CharacterFlowService.expandPrompt(
          name: _name, dir: dir, text: istek, mode: mode);
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
  Widget _animDirButton(CharacterItem it, CharacterDir d) {
    var total = 0, ok = 0;
    it.anims.forEach((_, byDir) {
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
                          CharacterFlowService.fileUrl(_name, c.webpRel(dir)),
                          headers: CharacterFlowService.authHeaders,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => _noSprite(),
                        )
                      : kabul.isEmpty
                          ? _noSprite()
                          : Image.network(
                              CharacterFlowService.thumbUrl(
                                  _name, c.acceptedRel(dir),
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
                      : () => _playVideo(
                          c.acceptedRel(dir), '$dir / ${c.clip} / $kabul'),
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

  void _sprite(String dir, String clip) => _run('Sprite',
      () => CharacterFlowService.sprites(name: _name, dir: dir, clips: [clip]),
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
                url: CharacterFlowService.fileUrl(_name, rel),
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
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                              color: c.accepted == v.v ? Colors.green : Colors.grey),
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
                                onPressed: () => _playVideo(v.relFor(dir, c.clip),
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
                            mode: _animMode,
                            clips: _animMode == 'mixamo' ? [c.clip] : const [],
                            clip: _animMode == 'i2v' ? c.clip : '',
                            prompt: _animMode == 'i2v' ? _i2vPrompt.text.trim() : '',
                            n: _animCount,
                            padding: _padding,
                          ),
                      adet: _animCount);
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text('+ Uret ($_animCount)'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
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
          name: _name, dir: dir, clip: clip, version: v);
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
          name: _name, dir: dir, clip: clip, version: v);
      await _loadClips(dir);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Klibi bu yonden kaldirir: butun surumleri silinir. Klip seti anims.json'da
  /// durur - baska yonde kullanilabilir.
  Future<void> _deleteClip(String dir, CharacterClip c) async {
    if (!await _confirm('Klibi sil',
        '$dir / ${c.clip} altindaki ${c.versions.length} surum silinecek.')) {
      return;
    }

    try {
      await CharacterFlowService.deleteClip(name: _name, dir: dir, clip: c.clip);
      _snack('${c.clip} silindi');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
    await _loadClips(dir);
  }

  // -------------------------------------------------- klip seti (anims.json)
  /// Klip ekle / cikar. anims.json GET/PUT ile guncellenir - klip adi
  /// kutuphanedeki klasor adi, fbx arsivdeki tam ad.
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
                const Text('Klip seti (anims.json)',
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
                                title:
                                    Text(m.name, style: const TextStyle(fontSize: 13)),
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
