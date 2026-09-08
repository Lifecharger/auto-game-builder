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

  const CardRankState({
    this.still = false,
    this.video = false,
    this.sheet = false,
    this.pushed = false,
    this.verdict = '',
    this.rev = 0,
    this.gesture = '',
    this.metrics = const {},
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

  const CardCollection({
    required this.id,
    required this.name,
    this.theme = '',
    this.style = 'realistic',
    this.ranks = const {},
    this.jokers = 0,
    this.cover = '',
    this.rev = 0,
  });

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

/// `/api/card/flow/profiles` cevabi - jest listeleri ve rutbe sirasi.
/// Uc yoksa sabit listelere duser (dokuman §4 `gesture_prompts`).
class CardProfilesInfo {
  final List<String> gestures;         // kart jestleri
  final List<String> dealerGestures;   // krupiye jestleri
  final List<String> ranks;
  final List<String> cutModes;         // sam | hybrid

  const CardProfilesInfo({
    this.gestures = CardFlowService.defaultGestures,
    this.dealerGestures = CardFlowService.defaultDealerGestures,
    this.ranks = CardFlowService.baseRanks,
    this.cutModes = CardFlowService.cutModes,
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
      return yedek;
    }

    return CardProfilesInfo(
      gestures: liste(j['gestures'], CardFlowService.defaultGestures),
      dealerGestures: liste(j['dealer_gestures'] ?? j['gestures_dealer'],
          CardFlowService.defaultDealerGestures),
      ranks: liste(j['ranks'] ?? j['rank_order'], CardFlowService.baseRanks),
      cutModes: liste(j['cut_modes'], CardFlowService.cutModes),
    );
  }
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
  static const defaultGestures = <String>['idle', 'wink', 'kiss', 'hair', 'pose'];

  /// Krupiye jestleri (dokuman "Tur secimi").
  static const defaultDealerGestures = <String>[
    'idle', 'shuffle', 'deal', 'wink', 'smile',
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
  }) async =>
      '${(await _post('/api/card/flow/edit', {
            'collection': collection,
            'rank': rank,
            'prompt': prompt,
            'kind': kind,
          }))['op'] ?? ''}';

  /// 2. asama: LTX-2.5 i2v, 6 sn, jest secimli.
  static Future<String> animate({
    required String collection,
    required List<String> ranks,
    String gesture = 'idle',
    String kind = 'card',
  }) async =>
      '${(await _post('/api/card/flow/animate', {
            'collection': collection,
            'ranks': ranks,
            'gesture': gesture,
            'kind': kind,
          }))['op'] ?? ''}';

  /// 3. asama: SAM3 kesim + sheet + thumb. `mode` = `sam` | `hybrid`.
  static Future<String> cut({
    required String collection,
    required List<String> ranks,
    String mode = 'sam',
    String kind = 'card',
  }) async =>
      '${(await _post('/api/card/flow/cut', {
            'collection': collection,
            'ranks': ranks,
            'mode': mode,
            'kind': kind,
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
