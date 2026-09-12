import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'api_service.dart';
import 'generate_service.dart';
import 'jigsaw_flow_service.dart' show FlowOp;

/// #323 Kart hattinin istemcisi - `/api/card/flow/*` (design/kart_modu.md).
///
/// Hot Card Games koleksiyon kartlari. Jigsaw/CBN'in "kabul et -> insa -> push"
/// kalibi DEGILDIR; dokuman §0'daki DORT ASAMA vardir ve her rutbe bu dortten
/// gecer:
///   1 Still   koleksiyon acilinca 13 (+2 joker) rutbe icin 1'er still
///             (otomatik kabul); ✎ Duzenle / ↻ Yeniden uret.
///   2 Video   still'den LTX-2.5 i2v 6 sn, jest secimi; guard'lar.
///   3 WebP    SAM3 kesim + 12x6 sprite sheet + thumb; guard FAIL -> "kontrol".
///   4 Push    manifest bu adimin ICINDE uretilir; onayli, GERI ALINAMAZ.
///
/// Tur secimi iki secenektir (dokuman "Tur secimi"): `card` (koleksiyon =
/// 13 rutbe) ve `dealer` (krupiye = rutbesiz TEK oge). Avatar turu YOKTUR.
///
/// Sunucu (#321) bu uclari paralel yaziyor - eksik alanlara tahammul edilir,
/// 404'te ekran "yakinda" der ([CardNotReadyException]).

/// Sunucu ucu henuz yok (404) - ekran "yakinda" gosterir, hata basmaz.
class CardNotReadyException implements Exception {
  final String message;
  const CardNotReadyException([this.message = 'Sunucu ucu henuz hazir degil']);
  @override
  String toString() => message;
}

/// Bir rutbenin (ya da krupiyenin) dort asamadaki hali.
///
/// Sunucu alan adlarinda serbesttir: `sheet` yerine `webp`, `pushed` yerine
/// `push` gonderebilir - ikisi de okunur. Alan hic yoksa `false` sayilir.
class CardRankState {
  final bool still;
  final bool video;
  /// 3. asama ciktisi (sprite sheet WebP + thumb). Dokumandaki "sheet".
  final bool sheet;
  final bool pushed;
  /// Guard sonucu: `pass` | `fail` | '' (hic kosmadi). `fail` -> kontrol rozeti.
  final String verdict;
  /// Sabit adli gorsellerin surumu (ms) - URL onbellegini asar (#302 kalibi).
  final int rev;
  /// Bu rutbenin son animasyonunda kullanilan jest (bos olabilir).
  final String gesture;
  /// Guard olcumleri - kart detayinda duz metin gosterilir.
  final Map<String, dynamic> metrics;
  /// #345: bu karti ureten prompt (yerel LLM yazdi) + parcalari.
  final String prompt;
  final String look;
  final String pose;
  final int age;
  /// #357: havuzdaki video sayisi (atanmis olsun olmasin).
  final int videos;

  const CardRankState({
    this.still = false,
    this.video = false,
    this.sheet = false,
    this.pushed = false,
    this.verdict = '',
    this.rev = 0,
    this.gesture = '',
    this.metrics = const {},
    this.prompt = '',
    this.look = '',
    this.pose = '',
    this.age = 0,
    this.videos = 0,
  });

  factory CardRankState.fromJson(Map<String, dynamic> j) => CardRankState(
        still: j['still'] == true,
        video: j['video'] == true,
        // sunucu 3. asamayi `webp` ya da `sheet` diye adlandirabilir.
        sheet: j['sheet'] == true || j['webp'] == true,
        pushed: j['pushed'] == true || j['push'] == true,
        verdict: '${j['verdict'] ?? ''}',
        rev: (j['rev'] is num) ? (j['rev'] as num).toInt() : 0,
        gesture: '${j['gesture'] ?? ''}',
        metrics: j['metrics'] is Map
            ? Map<String, dynamic>.from(j['metrics'] as Map)
            : const {},
        prompt: '${j['prompt'] ?? ''}',
        look: '${j['look'] ?? ''}',
        pose: '${j['pose'] ?? ''}',
        age: (j['age'] is num) ? (j['age'] as num).toInt() : 0,
        videos: (j['videos'] is num) ? (j['videos'] as num).toInt() : 0,
      );

  /// Sunucu duz bool ya da metin de gonderebilir ("still", "video", ...).
  factory CardRankState.parse(dynamic v) {
    if (v is Map) return CardRankState.fromJson(Map<String, dynamic>.from(v));
    if (v is bool) return CardRankState(still: v);
    if (v is String) {
      final s = v.toLowerCase();
      return CardRankState(
        still: s.isNotEmpty && s != 'none' && s != 'yok',
        video: s == 'video' || s == 'webp' || s == 'sheet' || s == 'push' || s == 'pushed',
        sheet: s == 'webp' || s == 'sheet' || s == 'push' || s == 'pushed',
        pushed: s == 'push' || s == 'pushed',
      );
    }
    return const CardRankState();
  }

  /// Kac asama bitmis: 0 (bos) .. 4 (push edilmis).
  int get stage => pushed
      ? 4
      : sheet
          ? 3
          : video
              ? 2
              : still
                  ? 1
                  : 0;

  bool get warn => verdict == 'fail';
}

/// Bir kart koleksiyonu - 13 rutbe (+ istege bagli 2 joker).
class CardCollection {
  final String id;
  final String name;
  final String theme;
  final String style;                       // hep "realistic" (anime yok)
  final Map<String, CardRankState> ranks;   // 'A' | 'K' | ... | 'J1' | 'J2'
  final int jokers;                         // 0 | 2
  /// Kapak = A rutbesinin thumb'i. Sunucu vermezse ekran A'ya duser.
  final String cover;
  final int rev;
  /// #353: kart ARKASI - rutbe degildir (animasyon/kesim/push'a girmez), ama
  /// izgarada 16. hucre olarak gorunur; null = eski sunucu.
  final CardRankState? back;
  /// #357: koleksiyonun video motoru (ltx | wan) + kurulu motorlar.
  final String videoEngine;
  final List<CardEngine> videoEngines;

  const CardCollection({
    required this.id,
    required this.name,
    this.theme = '',
    this.style = 'realistic',
    this.ranks = const {},
    this.jokers = 0,
    this.cover = '',
    this.rev = 0,
    this.back,
    this.videoEngine = 'minimax',
    this.videoEngines = const [],
  });

  static const backRank = 'BACK';

  factory CardCollection.fromJson(Map<String, dynamic> j) {
    final ham = j['ranks'];
    final ranks = <String, CardRankState>{};
    if (ham is Map) {
      ham.forEach((k, v) => ranks['$k'] = CardRankState.parse(v));
    } else if (ham is List) {
      // sunucu liste gonderirse her ogede `rank` alani beklenir.
      for (final e in ham) {
        if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          final r = '${m['rank'] ?? m['id'] ?? ''}';
          if (r.isNotEmpty) ranks[r] = CardRankState.fromJson(m);
        }
      }
    }
    final id = '${j['id'] ?? j['name'] ?? ''}';
    return CardCollection(
      id: id,
      name: '${j['name'] ?? id}',
      theme: '${j['theme'] ?? ''}',
      style: '${j['style'] ?? 'realistic'}',
      ranks: ranks,
      jokers: (j['jokers'] is num) ? (j['jokers'] as num).toInt() : 0,
      cover: '${j['cover'] ?? ''}',
      rev: (j['rev'] is num) ? (j['rev'] as num).toInt() : 0,
      back: j['back'] is Map
          ? CardRankState.fromJson(Map<String, dynamic>.from(j['back'] as Map))
          : null,
      videoEngine: '${j['video_engine'] ?? 'minimax'}',
      videoEngines: CardEngine.list(j['video_engines']),
    );
  }

  /// Bu koleksiyonun rutbe sirasi - joker sayisina gore (A K Q J 10..2 [J1 J2]).
  List<String> get rankOrder => CardFlowService.rankOrder(jokers: jokers);

  CardRankState stateOf(String rank) => ranks[rank] ?? const CardRankState();

  /// Her asamayi kac rutbe bitirdi - (still, video, webp, push).
  (int, int, int, int) get progress {
    var s = 0, v = 0, w = 0, p = 0;
    for (final r in rankOrder) {
      final st = stateOf(r);
      if (st.still) s++;
      if (st.video) v++;
      if (st.sheet) w++;
      if (st.pushed) p++;
    }
    return (s, v, w, p);
  }

  int get total => rankOrder.length;
  bool get anyWarn => ranks.values.any((s) => s.warn);
}

/// Bir krupiye - rutbesiz TEK oge (`_Dealers/<ad>/`). Dort asamadan koleksiyon
/// kartlariyla ayni sekilde gecer, yalnizca izgarasi yoktur.
class CardDealer {
  final String id;
  final String name;
  final String theme;
  final String gesture;
  final CardRankState state;
  final int rev;

  const CardDealer({
    required this.id,
    required this.name,
    this.theme = '',
    this.gesture = '',
    this.state = const CardRankState(),
    this.rev = 0,
  });

  factory CardDealer.fromJson(Map<String, dynamic> j) {
    final id = '${j['id'] ?? j['name'] ?? ''}';
    // Krupiyede rutbe yok; sunucu durumu ya duz alanlarda ya `state` /
    // tek elemanli `ranks` icinde gonderebilir - ucu de okunur.
    var st = CardRankState.fromJson(j);
    if (j['state'] is Map) {
      st = CardRankState.fromJson(Map<String, dynamic>.from(j['state'] as Map));
    } else if (j['ranks'] is Map && (j['ranks'] as Map).isNotEmpty) {
      st = CardRankState.parse((j['ranks'] as Map).values.first);
    }
    return CardDealer(
      id: id,
      name: '${j['name'] ?? id}',
      theme: '${j['theme'] ?? ''}',
      gesture: '${j['gesture'] ?? ''}',
      state: st,
      rev: (j['rev'] is num) ? (j['rev'] as num).toInt() : st.rev,
    );
  }
}

/// #339: hazir koleksiyon karti - listeden secilince tema alanini doldurur.
class CardPreset {
  final String id;
  final String name;
  final String emoji;
  final String theme;

  const CardPreset(
      {required this.id, required this.name, this.emoji = '', this.theme = ''});

  factory CardPreset.fromJson(Map<String, dynamic> j) => CardPreset(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? j['id'] ?? ''}',
        emoji: '${j['emoji'] ?? ''}',
        theme: '${j['theme'] ?? ''}',
      );

  String get label => emoji.isEmpty ? name : '$emoji  $name';
}

/// #338: bir kartin animasyonu. `stage` 0 bos, 2 video, 3 sheet hazir.
class CardAnim {
  final String name;
  final bool video;
  final bool sheet;
  final bool thumb;
  final int stage;
  final String gesture;
  /// #357: etiket klasoru (card.root'a gore) - kucuk resim `dir/video.mp4`.
  final String dir;

  const CardAnim({
    required this.name,
    this.video = false,
    this.sheet = false,
    this.thumb = false,
    this.stage = 0,
    this.gesture = '',
    this.dir = '',
  });

  factory CardAnim.fromJson(Map<String, dynamic> j) => CardAnim(
        name: '${j['name'] ?? ''}',
        video: j['video'] == true,
        sheet: j['sheet'] == true,
        thumb: j['thumb'] == true,
        stage: (j['stage'] is num) ? (j['stage'] as num).toInt() : 0,
        gesture: '${j['gesture'] ?? ''}',
        dir: '${j['dir'] ?? ''}',
      );

  bool get isIdle => name == 'idle';
}

/// #357: video motoru (koleksiyon ayari) - liste sunucudan gelir (ltx, wan,
/// minimax). MiniMax etiketi lisans uyarisi tasir (#358, kullanici istedi).
class CardEngine {
  const CardEngine(this.id, this.label, {this.available = true});
  final String id;
  final String label;
  final bool available;

  static List<CardEngine> list(dynamic v) => v is List
      ? v
          .whereType<Map>()
          .map((e) => CardEngine('${e['id'] ?? ''}', '${e['label'] ?? e['id'] ?? ''}',
              available: e['available'] != false))
          .where((e) => e.id.isNotEmpty)
          .toList()
      : const [CardEngine('minimax', 'MiniMax H3')];
}

/// #357: havuzdaki bir video - prompt, motor, guard ve atandigi etiketler.
class CardVideo {
  const CardVideo({
    required this.id,
    this.rel = '',
    this.rev = 0,
    this.prompt = '',
    this.gesture = '',
    this.engine = '',
    this.at = '',
    this.guard = const {},
    this.tags = const [],
  });
  final String id;
  final String rel;
  final int rev;
  final String prompt;
  final String gesture;
  final String engine;
  final String at;
  final Map<String, dynamic> guard;
  final List<String> tags;

  factory CardVideo.fromJson(Map<String, dynamic> j) => CardVideo(
        id: '${j['id'] ?? ''}',
        rel: '${j['rel'] ?? ''}',
        rev: (j['rev'] is num) ? (j['rev'] as num).toInt() : 0,
        prompt: '${j['prompt'] ?? ''}',
        gesture: '${j['gesture'] ?? ''}',
        engine: '${j['engine'] ?? ''}',
        at: '${j['at'] ?? ''}',
        guard: j['guard'] is Map ? Map<String, dynamic>.from(j['guard'] as Map) : const {},
        tags: (j['tags'] as List? ?? const []).map((e) => '$e').toList(),
      );
}

/// #357: `/api/card/flow/videos` cevabi - havuz + etiketler birlikte.
class CardVideos {
  const CardVideos({this.videos = const [], this.anims = const []});
  final List<CardVideo> videos;
  final List<CardAnim> anims;
}

/// #347: bir rutbenin SABLONU - 9 eksen + kilitler + manuel metin.
/// LLM'in yerini aldi: Pozitif 3 bu sablondan kurulur.
class CardTemplate {
  final Map<String, String> axes;   // race, skin, hair, eyes, outfit_style, ...
  final Set<String> locked;         // karistirmada degismeyecek eksenler
  final String manual;              // kullanicinin serbest yazdigi ek

  const CardTemplate({
    this.axes = const {},
    this.locked = const {},
    this.manual = '',
  });

  factory CardTemplate.fromJson(Map<String, dynamic> j) {
    final a = <String, String>{};
    for (final e in j.entries) {
      if (e.key == 'locked' || e.key == 'manual') continue;
      a[e.key] = '${e.value ?? ''}';
    }
    return CardTemplate(
      axes: a,
      locked: (j['locked'] is List)
          ? (j['locked'] as List).map((e) => '$e').toSet()
          : const {},
      manual: '${j['manual'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() =>
      {...axes, 'locked': locked.toList(), 'manual': manual};

  CardTemplate copyWith(
          {Map<String, String>? axes, Set<String>? locked, String? manual}) =>
      CardTemplate(
          axes: axes ?? this.axes,
          locked: locked ?? this.locked,
          manual: manual ?? this.manual);
}

/// #347: `/api/card/flow/templates` cevabi.
class CardTemplates {
  final String theme;
  /// #353: uretim modeli - 'zimage' (hizli, temiz fon) | 'qwen' (kostum
  /// sadakati iyi, arka plana studyo ekipmani koyabilir).
  final String model;
  final List<String> models;
  /// #353: yuz rotusu - tam boy karede yuz kucuk kaliyor, ayri gecis netlestirir.
  final bool faceDetail;
  /// #357: video motoru (ltx | wan) + kurulu motorlar.
  final String videoEngine;
  final List<CardEngine> videoEngines;
  /// #348: 16 yuva - 13 rutbe + J1 + J2 + BACK (kart arkasi).
  final List<String> slots;
  final String backRank;
  final List<String> axes;              // kart eksenleri
  final Map<String, String> labels;
  final Map<String, List<String>> mixers;
  /// Kart ARKASI kadin degil desen: kendi eksenleri (motif/palet/yuzey).
  final List<String> backAxes;
  final Map<String, String> backLabels;
  final Map<String, List<String>> backMixers;
  final Map<String, CardTemplate> templates;   // YUVA -> sablon
  final Map<String, String> preview;           // YUVA -> prompt onizlemesi

  const CardTemplates({
    this.theme = '',
    this.model = 'zimage',
    this.models = const ['zimage', 'qwen'],
    this.faceDetail = false,
    this.videoEngine = 'minimax',
    this.videoEngines = const [],
    this.slots = const [],
    this.backRank = 'BACK',
    this.axes = const [],
    this.labels = const {},
    this.mixers = const {},
    this.backAxes = const [],
    this.backLabels = const {},
    this.backMixers = const {},
    this.templates = const {},
    this.preview = const {},
  });

  bool isBack(String slot) => slot.toUpperCase() == backRank.toUpperCase();
  List<String> axesFor(String slot) => isBack(slot) ? backAxes : axes;
  Map<String, String> labelsFor(String slot) => isBack(slot) ? backLabels : labels;
  Map<String, List<String>> mixersFor(String slot) =>
      isBack(slot) ? backMixers : mixers;

  static Map<String, List<String>> _mix(dynamic v) => {
        for (final e in (v as Map? ?? const {}).entries)
          '${e.key}': (e.value as List? ?? const []).map((x) => '$x').toList()
      };

  static Map<String, String> _lab(dynamic v) =>
      {for (final e in (v as Map? ?? const {}).entries) '${e.key}': '${e.value}'};

  factory CardTemplates.fromJson(Map<String, dynamic> j) => CardTemplates(
        theme: '${j['theme'] ?? ''}',
        model: '${j['model'] ?? 'zimage'}',
        models: (j['models'] as List? ?? const ['zimage', 'qwen'])
            .map((e) => '$e')
            .toList(),
        faceDetail: j['face_detail'] == true,
        videoEngine: '${j['video_engine'] ?? 'minimax'}',
        videoEngines: CardEngine.list(j['video_engines']),
        slots: (j['slots'] as List? ?? const []).map((e) => '$e').toList(),
        backRank: '${j['back_rank'] ?? 'BACK'}',
        backAxes: (j['back_axes'] as List? ?? const []).map((e) => '$e').toList(),
        backLabels: _lab(j['back_labels']),
        backMixers: _mix(j['back_mixers']),
        axes: (j['axes'] as List? ?? const []).map((e) => '$e').toList(),
        labels: _lab(j['labels']),
        mixers: _mix(j['mixers']),
        templates: {
          for (final e in (j['templates'] as Map? ?? const {}).entries)
            '${e.key}': CardTemplate.fromJson(Map<String, dynamic>.from(e.value as Map))
        },
        preview: {
          for (final e in (j['preview'] as Map? ?? const {}).entries)
            '${e.key}': '${e.value}'
        },
      );
}

/// `/api/card/flow/profiles` cevabi - jest listeleri ve rutbe sirasi.
/// Uc yoksa sabit listelere duser (dokuman §4 `gesture_prompts`).
class CardProfilesInfo {
  final List<String> gestures;         // kart jestleri
  final List<String> dealerGestures;   // krupiye jestleri
  final List<String> ranks;
  final List<String> cutModes;         // sam | hybrid
  /// #357: jest adi -> hareket cumlesi (sablon). Video penceresinde metin
  /// olarak gosterilir, kullanici duzenleyip gonderir.
  final Map<String, String> gestureTexts;
  final Map<String, String> dealerGestureTexts;

  const CardProfilesInfo({
    this.gestures = CardFlowService.defaultGestures,
    this.dealerGestures = CardFlowService.defaultDealerGestures,
    this.ranks = CardFlowService.baseRanks,
    this.cutModes = CardFlowService.cutModes,
    this.gestureTexts = const {},
    this.dealerGestureTexts = const {},
  });

  factory CardProfilesInfo.fromJson(Map<String, dynamic> j) {
    List<String> liste(dynamic v, List<String> yedek) {
      if (v is List) {
        final out = v
            .map((e) => e is Map ? '${e['id'] ?? e['name'] ?? ''}' : '$e')
            .where((e) => e.isNotEmpty)
            .toList();
        if (out.isNotEmpty) return out;
      }
      // #357: sunucu jestleri {ad: cumle} sozlugu olarak verir - anahtarlar.
      if (v is Map && v.isNotEmpty) return v.keys.map((e) => '$e').toList();
      return yedek;
    }

    Map<String, String> sozluk(dynamic v) => v is Map
        ? {for (final e in v.entries) '${e.key}': '${e.value}'}
        : const {};

    return CardProfilesInfo(
      gestureTexts: sozluk(j['gestures']),
      dealerGestureTexts: sozluk(j['dealer_gestures'] ?? j['gestures_dealer']),
      gestures: liste(j['gestures'], CardFlowService.defaultGestures),
      dealerGestures: liste(j['dealer_gestures'] ?? j['gestures_dealer'],
          CardFlowService.defaultDealerGestures),
      ranks: liste(j['ranks'] ?? j['rank_order'], CardFlowService.baseRanks),
      cutModes: liste(j['cut_modes'], CardFlowService.cutModes),
    );
  }
}

/// #356: aday still + degisiklik zamani (kucuk resim onbellek kiricisi).
class CardCandidate {
  const CardCandidate(this.file, this.rev);
  final String file;
  final int rev;
}

class CardFlowService {
  static const _timeout = Duration(seconds: 60);

  /// Tur secimi (dokuman "Tur secimi"): iki secenek - avatar YOK.
  static const kinds = <String, String>{'card': 'Normal', 'dealer': 'Krupiye'};

  /// Dort asama - ekranlardaki dugme ve rozet sirasi (dokuman §0).
  static const stages = <String>['still', 'video', 'webp', 'push'];
  static const stageTitles = <String>['1 Still', '2 Video', '3 WebP', '4 Push'];

  /// Rutbe sirasi A K Q J 10 9 8 7 6 5 4 3 2 (roster.json `rank_order`).
  static const baseRanks = <String>[
    'A', 'K', 'Q', 'J', '10', '9', '8', '7', '6', '5', '4', '3', '2',
  ];

  /// Joker rutbeleri - `jokers: 2` secilirse listeye eklenir.
  static const jokerRanks = <String>['J1', 'J2'];

  /// Krupiyede rutbe YOKTUR; uclar yine de `ranks` bekledigi icin tek ogeli
  /// bu sabit gonderilir (`kind=dealer` zaten ogeyi tek basina tanimlar).
  static const dealerRank = 'main';

  /// roster.json `gesture_prompts` (dokuman §4).
  static const defaultGestures = <String>['idle', 'victory', 'wave', 'wink', 'kiss', 'hair', 'pose', 'dance', 'spin'];   // #362

  /// Krupiye jestleri (dokuman "Tur secimi").
  static const defaultDealerGestures = <String>[
    'idle', 'victory', 'shuffle', 'deal', 'wink', 'smile', 'wave',   // #362
  ];

  /// Kesim kipleri: `sam` (varsayilan, duz gri fon) | `hybrid` (eski yesil
  /// Grok masterlari).
  static const cutModes = <String>['sam', 'hybrid'];

  /// Nadirlik - A epic, KQJ rare, 2-10 common, joker legendary (dokuman §1).
  static String rarityOf(String rank) {
    if (rank.startsWith('J') && rank.length > 1) return 'legendary';
    if (rank == 'A') return 'epic';
    if (rank == 'K' || rank == 'Q' || rank == 'J') return 'rare';
    return 'common';
  }

  static List<String> rankOrder({int jokers = 0}) =>
      jokers > 0 ? [...baseRanks, ...jokerRanks] : baseRanks;

  static String kindLabel(String kind) => kinds[kind] ?? kind;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AppConfig.apiKey.isNotEmpty) 'X-API-Key': AppConfig.apiKey,
      };

  static Map<String, String> get authHeaders => GenerateService.authHeaders;

  static Never _fail(http.Response r, String fallback) {
    if (r.statusCode == 404 || r.statusCode == 405 || r.statusCode == 501) {
      throw const CardNotReadyException();
    }
    try {
      final d = json.decode(r.body);
      throw Exception('${d['detail'] ?? fallback}');
    } catch (e) {
      if (e is CardNotReadyException) rethrow;
      throw Exception('$fallback (${r.statusCode})');
    }
  }

  static dynamic _decode(http.Response r) => json.decode(utf8.decode(r.bodyBytes));

  static Future<dynamic> _getAny(String path) async {
    final r = await http
        .get(Uri.parse('${ApiService.baseUrl}$path'), headers: _headers)
        .timeout(_timeout);
    if (r.statusCode != 200) _fail(r, 'Istek basarisiz');
    return _decode(r);
  }

  static Future<Map<String, dynamic>> _get(String path) async =>
      Map<String, dynamic>.from(await _getAny(path) as Map);

  static Future<Map<String, dynamic>> _post(String path,
      [Map<String, dynamic>? body]) async {
    final r = await http
        .post(Uri.parse('${ApiService.baseUrl}$path'),
            headers: _headers, body: json.encode(body ?? {}))
        .timeout(_timeout);
    if (r.statusCode != 200) _fail(r, 'Istek basarisiz');
    return Map<String, dynamic>.from(_decode(r) as Map);
  }

  static Future<Map<String, dynamic>> _delete(String path) async {
    final r = await http
        .delete(Uri.parse('${ApiService.baseUrl}$path'), headers: _headers)
        .timeout(_timeout);
    if (r.statusCode != 200) _fail(r, 'Istek basarisiz');
    return Map<String, dynamic>.from(_decode(r) as Map);
  }

  /// Liste / sozluk / bare liste - hangisi gelirse listeye cevirir.
  static List<Map<String, dynamic>> _rows(dynamic d, [List<String>? keys]) {
    if (d is List) {
      return d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (d is Map) {
      for (final k in keys ?? const ['collections', 'items', 'dealers']) {
        final v = d[k];
        if (v is List) {
          return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    }
    return const [];
  }

  static String _q(String v) => Uri.encodeQueryComponent(v);

  // ------------------------------------------------------------- okuma
  /// Koleksiyon listesi. `kind` = `card` (varsayilan) | `dealer`.
  static Future<List<CardCollection>> collections({String kind = 'card'}) async {
    final d = await _getAny('/api/card/flow/collections?kind=${_q(kind)}');
    return _rows(d)
        .map(CardCollection.fromJson)
        .where((c) => c.id.isNotEmpty)
        .toList();
  }

  /// Krupiye listesi - ayni uc, `kind=dealer`, tek ogeli kayitlar.
  static Future<List<CardDealer>> dealers() async {
    final d = await _getAny('/api/card/flow/collections?kind=dealer');
    return _rows(d)
        .map(CardDealer.fromJson)
        .where((c) => c.id.isNotEmpty)
        .toList();
  }

  /// Tek koleksiyonun ayrintisi. Sunucu `?id=` suzmesini desteklemiyorsa
  /// listeden ayni kimlik cekilir.
  static Future<CardCollection?> collection(String id,
      {String kind = 'card'}) async {
    try {
      final d = await _getAny(
          '/api/card/flow/collection?id=${_q(id)}&kind=${_q(kind)}');
      if (d is Map && '${d['id'] ?? ''}'.isNotEmpty) {
        return CardCollection.fromJson(Map<String, dynamic>.from(d));
      }
      final satirlar = _rows(d);
      if (satirlar.isNotEmpty) return CardCollection.fromJson(satirlar.first);
    } on CardNotReadyException {
      // eski/eksik sunucu: tam listeye dus
    }
    for (final c in await collections(kind: kind)) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Jest listeleri ve rutbe sirasi. Uc yoksa sabit listeler doner.
  static Future<CardProfilesInfo> profiles() async {
    try {
      return CardProfilesInfo.fromJson(await _get('/api/card/flow/profiles'));
    } catch (_) {
      return const CardProfilesInfo();
    }
  }

  /// Manifest ONIZLEME (salt okunur). Push manifesti kendi icinde uretir
  /// (dokuman §0/4), bu yalnizca "ne yazilacak" sorusunu yanitlar.
  static Future<Map<String, dynamic>> manifest({String kind = 'card'}) async =>
      _get('/api/card/flow/manifest?kind=${_q(kind)}&preview=1');

  static Future<FlowOp> op(String opId) async =>
      FlowOp.fromJson(await _get('/api/card/flow/op/$opId'));

  // -------------------------------------------------------------- dosya
  /// Kucuk resim. `kind` = `still` | `frame` (sheet ilk karesi) | `thumb`.
  /// `type` = `card` | `dealer`. `v` (rev) onbellegi asar.
  static String thumbUrl(
    String collection,
    String rank, {
    String kind = 'still',
    int size = 300,
    int v = 0,
    String type = 'card',
  }) =>
      '${ApiService.baseUrl}/api/card/flow/thumb'
      '?collection=${_q(collection)}&rank=${_q(rank)}'
      '&kind=${_q(kind)}&type=${_q(type)}&size=$size${v > 0 ? '&v=$v' : ''}';

  /// Tam dosya. `kind` = `video` | `sheet` | `still` | `thumb`.
  static String fileUrl(
    String collection,
    String rank, {
    String kind = 'video',
    int v = 0,
    String type = 'card',
  }) =>
      '${ApiService.baseUrl}/api/card/flow/file'
      '?collection=${_q(collection)}&rank=${_q(rank)}'
      '&kind=${_q(kind)}&type=${_q(type)}${v > 0 ? '&v=$v' : ''}';

  /// #336: aday still'in kucuk resmi - `rel` sunucudan gelen goreli yoldur.
  /// #356: `v` (dosya mtime) ZORUNLU sayilir: aday adlari yeniden kullanilir,
  /// Flutter kucuk resmi URL'ye gore bellekte tutar; v'siz URL eski gorseli
  /// gosterir. 0 ise cagiran taraf yukleme zamanini verir (onbellek yok).
  static String relThumbUrl(String rel, {int size = 200, int v = 0}) =>
      '${ApiService.baseUrl}/api/card/flow/thumb?rel=${_q(rel)}&size=$size'
      '${v > 0 ? '&v=$v' : ''}';

  /// #357: havuz videosunun ham dosyasi (oynatma) - `rel` card.root'a gore.
  static String relFileUrl(String rel, {int v = 0}) =>
      '${ApiService.baseUrl}/api/card/flow/file?rel=${_q(rel)}'
      '${v > 0 ? '&v=$v' : ''}';

  /// #339: hazir koleksiyon kartlari. Bos liste = sablon dosyasi yok, elle
  /// tema yazmak her zaman mumkun.
  static Future<List<CardPreset>> presets({String kind = 'card'}) async {
    try {
      final d = await _get('/api/card/flow/presets');
      final l = d[kind == 'dealer' ? 'dealer_presets' : 'presets'];
      return l is List
          ? l
              .whereType<Map>()
              .map((e) => CardPreset.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <CardPreset>[];
    } catch (_) {
      return const [];
    }
  }

  /// #338: rutbenin animasyonlari (idle once).
  static Future<List<CardAnim>> anims(String collection, String rank,
      {String kind = 'card'}) async {
    try {
      final d = await _get('/api/card/flow/anims'
          '?collection=${_q(collection)}&rank=${_q(rank)}&kind=${_q(kind)}');
      final l = d['anims'];
      return l is List
          ? l
              .whereType<Map>()
              .map((e) => CardAnim.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <CardAnim>[];
    } catch (_) {
      return const [];
    }
  }

  /// #338: bir animasyonu siler (idle silinemez).
  static Future<void> deleteAnim(String collection, String rank, String anim,
          {String kind = 'card'}) async =>
      _delete('/api/card/flow/anim?collection=${_q(collection)}&rank=${_q(rank)}'
          '&anim=${_q(anim)}&kind=${_q(kind)}');

  /// #357: rutbenin video havuzu + etiketleri. Eski sunucuda bos doner.
  static Future<CardVideos> videos(String collection, String rank,
      {String kind = 'card'}) async {
    try {
      final d = await _get('/api/card/flow/videos'
          '?collection=${_q(collection)}&rank=${_q(rank)}&kind=${_q(kind)}');
      List<T> oku<T>(dynamic l, T Function(Map<String, dynamic>) f) => l is List
          ? l.whereType<Map>().map((e) => f(Map<String, dynamic>.from(e))).toList()
          : <T>[];
      return CardVideos(
          videos: oku(d['videos'], CardVideo.fromJson),
          anims: oku(d['anims'], CardAnim.fromJson));
    } catch (_) {
      return const CardVideos();
    }
  }

  /// #357: havuzdaki videoyu bir etikete atar (idle = kartin ana animasyonu).
  static Future<void> assignVideo(String collection, String rank, String video,
          String tag, {String kind = 'card'}) async =>
      _post('/api/card/flow/video/assign', {
        'collection': collection,
        'rank': rank,
        'video': video,
        'tag': tag,
        'kind': kind,
      });

  /// #357: havuzdan video siler (etiketlere atanmis kopyalar kalir).
  static Future<void> deleteVideo(String collection, String rank, String video,
          {String kind = 'card'}) async =>
      _delete('/api/card/flow/video?collection=${_q(collection)}&rank=${_q(rank)}'
          '&video=${_q(video)}&kind=${_q(kind)}');

  /// #357: SECILI varligi tek basina siler - `what` = still | video | sheet.
  /// video/sheet secili animasyon etiketine gore (`anim`, bos = idle).
  static Future<void> deleteAsset(String collection, String rank, String what,
          {String kind = 'card', String anim = ''}) async =>
      _delete('/api/card/flow/asset?collection=${_q(collection)}&rank=${_q(rank)}'
          '&what=${_q(what)}&kind=${_q(kind)}${anim.isNotEmpty ? '&anim=${_q(anim)}' : ''}');

  /// #347: koleksiyonun 13 sablonu + karistirici listeleri.
  static Future<CardTemplates> templates(String collection,
          {String kind = 'card'}) async =>
      CardTemplates.fromJson(await _get(
          '/api/card/flow/templates?collection=${_q(collection)}&kind=${_q(kind)}'));

  /// #347: kilitli OLMAYAN eksenleri yeniden karistirir.
  static Future<void> rollTemplates(String collection,
          {String kind = 'card',
          List<String> ranks = const [],
          List<String> axes = const []}) async =>
      _post('/api/card/flow/templates/roll',
          {'collection': collection, 'kind': kind, 'ranks': ranks, 'axes': axes});

  /// #347: tek sablonu yazar (eksenler + kilitler + manuel metin).
  static Future<void> setTemplate(
          String collection, String rank, CardTemplate t,
          {String kind = 'card'}) async =>
      _post('/api/card/flow/templates', {
        'collection': collection,
        'rank': rank,
        'kind': kind,
        'template': t.toJson(),
      });

  /// #347: bir ekseni BUTUN rutbelere yazar ve (varsayilan) kilitler.
  static Future<void> setAxis(String collection, String axis, String value,
          {String kind = 'card', bool lock = true}) async =>
      _post('/api/card/flow/templates/axis', {
        'collection': collection,
        'axis': axis,
        'value': value,
        'kind': kind,
        'lock': lock,
      });

  /// #353: koleksiyonun uretim ayarlari - model ve yuz rotusu.
  static Future<void> setSettings(String collection,
          {String kind = 'card',
          String? model,
          bool? faceDetail,
          String? videoEngine}) async =>
      _post('/api/card/flow/settings', {
        'collection': collection,
        'kind': kind,
        if (model != null) 'model': model,
        if (faceDetail != null) 'face_detail': faceDetail,
        if (videoEngine != null) 'video_engine': videoEngine,   // #357
      });

  /// #346: koleksiyonun temasini degistirir (promptlara dokunmaz).
  static Future<void> setTheme(String collection, String theme,
          {String kind = 'card'}) async =>
      _post('/api/card/flow/theme',
          {'collection': collection, 'theme': theme, 'kind': kind});

  /// #337: koleksiyonun rutbe promptlarini yerel LLM'e yeniden yazdirir.
  /// Dosyalara dokunmaz - sonra "1 Still" ile yeniden uretilir.
  static Future<Map<String, dynamic>> rewriteLooks(String collection,
          {String kind = 'card', String theme = ''}) async =>
      _post('/api/card/flow/rewrite-looks',
          {'collection': collection, 'kind': kind, 'theme': theme});

  /// #343: bir adayin card.root'a gore yolu. Krupiyede rutbe klasoru YOKTUR -
  /// dosyalar dogrudan `_Dealers/<ad>/` icindedir.
  static String candidateRel(String collection, String rank, String file,
          {String kind = 'card'}) =>
      kind == 'dealer'
          ? '_Dealers/$collection/$file'
          : '$collection/${rank.toLowerCase()}/$file';

  /// #336: rutbenin aday still'leri (dosya adlari).
  static Future<List<CardCandidate>> candidates(String collection, String rank,
      {String kind = 'card'}) async {
    final j = await _get('/api/card/flow/candidates'
        '?collection=${_q(collection)}&rank=${_q(rank)}&kind=${_q(kind)}');
    final l = j['candidates'];
    final revs = j['revs'] is Map ? j['revs'] as Map : const {};
    // #356: eski sunucu `revs` vermez -> yukleme ani (her acilista taze).
    final simdi = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return l is List
        ? l.map((e) {
            final ad = '$e';
            final r = revs[ad];
            return CardCandidate(ad, r is num && r > 0 ? r.toInt() : simdi);
          }).toList()
        : <CardCandidate>[];
  }

  /// #336: adayi secili still yapar (onceki still aday olarak kalir).
  static Future<void> pickCandidate(String collection, String rank, String file,
          {String kind = 'card'}) async =>
      _post('/api/card/flow/pick', {
        'collection': collection,
        'rank': rank,
        'file': file,
        'kind': kind,
      });

  /// #336: adayi siler (secili still'e dokunmaz).
  static Future<void> deleteCandidate(
          String collection, String rank, String file,
          {String kind = 'card'}) async =>
      _delete('/api/card/flow/candidate'
          '?collection=${_q(collection)}&rank=${_q(rank)}'
          '&file=${_q(file)}&kind=${_q(kind)}');

  /// #352: rutbeyi BOSA dondurur - still/aday/video/sheet/animasyon silinir,
  /// klasor kalir ("1 Still" ile yeniden uretilir). Krupiyede rank = main.
  static Future<int> clearRank(String collection, String rank,
      {String kind = 'card'}) async {
    final d = await _delete('/api/card/flow/rank'
        '?collection=${_q(collection)}&rank=${_q(rank)}&kind=${_q(kind)}');
    return (d['deleted'] is num) ? (d['deleted'] as num).toInt() : 0;
  }

  /// #352: koleksiyonu / krupiyeyi klasoruyle siler. GERI ALINAMAZ; R2'ye
  /// push edilmis dosyalar kovada kalir.
  static Future<void> deleteCollection(String id, {String kind = 'card'}) async =>
      _delete('/api/card/flow/collection?id=${_q(id)}&kind=${_q(kind)}');

  // ------------------------------------------------------------- yazma
  /// Yeni koleksiyon acar: 13 (+2) rutbe icin 1'er still kuyruga girer.
  /// Op doner (bos gelebilir - o zaman izlenecek is yoktur).
  static Future<String> createCollection({
    required String id,
    required String name,
    required String theme,
    int jokers = 0,
    String kind = 'card',
  }) async =>
      '${(await _post('/api/card/flow/collections', {
            'id': id,
            'name': name,
            'theme': theme,
            'jokers': jokers,
            'kind': kind,
          }))['op'] ?? ''}';

  /// Yeni krupiye - rutbesiz tek oge. Jest krupiyeye ozeldir (idle/shuffle/
  /// deal/wink/smile).
  static Future<String> createDealer({
    required String id,
    required String name,
    required String theme,
    String gesture = 'idle',
  }) async =>
      '${(await _post('/api/card/flow/collections', {
            'id': id,
            'name': name,
            'theme': theme,
            'jokers': 0,
            'gesture': gesture,
            'kind': 'dealer',
          }))['op'] ?? ''}';

  /// Uretilenler'deki bir isi bir rutbenin still'i yapar (Uretilenler ->
  /// "Koleksiyona ekle").
  static Future<String> stage({
    required String collection,
    required String rank,
    required String jobId,
    String kind = 'card',
  }) async =>
      '${(await _post('/api/card/flow/stage', {
            'collection': collection,
            'rank': rank,
            'job_id': jobId,
            'kind': kind,
          }))['op'] ?? ''}';

  /// 1. asama: secili rutbeler icin still uretir (`n` adet aday).
  static Future<String> stills({
    required String collection,
    required List<String> ranks,
    int n = 1,
    String kind = 'card',
  }) async =>
      '${(await _post('/api/card/flow/stills', {
            'collection': collection,
            'ranks': ranks,
            'n': n,
            'kind': kind,
          }))['op'] ?? ''}';

  /// Ince ayar: kabul edilmis still'i kisa bir duzeltme cumlesiyle degistirir.
  static Future<String> edit({
    required String collection,
    required String rank,
    required String prompt,
    String kind = 'card',
    bool nsfw = false,           // #361: MCNL LoRA'li sinirsiz duzenleme
  }) async =>
      '${(await _post('/api/card/flow/edit', {
            'collection': collection,
            'rank': rank,
            'prompt': prompt,
            'kind': kind,
            if (nsfw) 'nsfw': true,
          }))['op'] ?? ''}';

  /// 2. asama: LTX-2.5 i2v, 6 sn, jest secimli.
  static Future<String> animate({
    required String collection,
    required List<String> ranks,
    String gesture = 'idle',     // hazir ad YA DA serbest hareket cumlesi
    String kind = 'card',
    String anim = '',            // #338: bos/idle = kartin ana animasyonu
    bool poolOnly = false,       // #357: yalniz havuza, etiket atama yok
    String engine = '',          // #357: ltx | wan (bos = koleksiyon ayari)
  }) async =>
      '${(await _post('/api/card/flow/animate', {
            'collection': collection,
            'ranks': ranks,
            'gesture': gesture,
            'kind': kind,
            if (anim.isNotEmpty) 'anim': anim,
            if (poolOnly) 'pool_only': true,
            if (engine.isNotEmpty) 'engine': engine,
          }))['op'] ?? ''}';

  /// #362: toplu 2 Video - her karta idle + victory (sunucudaki ANIM_SET).
  static Future<String> animateSet({
    required String collection,
    required List<String> ranks,
    String kind = 'card',
    String engine = '',
  }) async =>
      '${(await _post('/api/card/flow/animate-set', {
            'collection': collection,
            'ranks': ranks,
            'kind': kind,
            if (engine.isNotEmpty) 'engine': engine,
          }))['op'] ?? ''}';

  /// #362: kesimde `anim` = `*` -> videosu olan her animasyon (kart basina 2 webp).
  static const allAnims = '*';

  /// 3. asama: SAM3 kesim + sheet + thumb. `mode` = `sam` | `hybrid`.
  static Future<String> cut({
    required String collection,
    required List<String> ranks,
    String mode = 'sam',
    String kind = 'card',
    String anim = '',            // #338: bos/idle = kartin ana animasyonu
  }) async =>
      '${(await _post('/api/card/flow/cut', {
            'collection': collection,
            'ranks': ranks,
            'mode': mode,
            'kind': kind,
            if (anim.isNotEmpty) 'anim': anim,
          }))['op'] ?? ''}';

  /// Gece modu: mevcut still'lerden yeniden canlandirma (i2v -> kesim).
  /// `collection` = koleksiyon kimligi ya da `all`. `includeDealers` = krupiyeler
  /// de kuyruga girsin mi (dokuman §0: 54 kart + 3 krupiye).
  static Future<String> reanimate({
    String collection = 'all',
    String gesture = '',
    bool includeDealers = true,
  }) async =>
      '${(await _post('/api/card/flow/reanimate', {
            'collection': collection,
            if (gesture.isNotEmpty) 'gesture': gesture,
            'include_dealers': includeDealers,
          }))['op'] ?? ''}';

  /// #325: her still'in YESIL fonunu duz acik gri studyo fonuna cevirir
  /// (kadin aynen kalir). Ilk hal `still_green.png` olarak saklanir; zaten gri
  /// olan kartlar atlanir; SAM'in bulamadigi kart ELLE duzeltilir.
  static Future<String> restill({
    String collection = 'all',
    bool includeDealers = true,
    bool force = false,
  }) async =>
      '${(await _post('/api/card/flow/restill', {
            'collection': collection,
            'include_dealers': includeDealers,
            'force': force,
          }))['op'] ?? ''}';

  /// #325: anime still'leri gercekci kadina cevirir (edit_qwen). Koleksiyonun
  /// kimligi ve adi DEGISMEZ, yalniz gorseller + `style` alani.
  static Future<String> realify({
    required String collection,
    String kind = 'card',
  }) async =>
      '${(await _post('/api/card/flow/realify', {
            'collection': collection,
            'kind': kind,
          }))['op'] ?? ''}';

  /// Yedek yol: eski Grok videosunu hybrid kiple yeniden keser.
  static Future<String> recut({
    String collection = 'all',
    bool includeDealers = true,
  }) async =>
      '${(await _post('/api/card/flow/recut', {
            'collection': collection,
            'include_dealers': includeDealers,
          }))['op'] ?? ''}';

  /// 4. asama: R2'ye yukler - manifest bu adimin icinde uretilir.
  /// GERI ALINAMAZ.
  static Future<String> push({
    required String collection,
    String kind = 'card',
  }) async =>
      '${(await _post('/api/card/flow/push', {
            'collection': collection,
            'kind': kind,
          }))['op'] ?? ''}';
}
