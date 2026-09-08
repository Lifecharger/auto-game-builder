import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'api_service.dart';
import 'generate_service.dart';
import 'jigsaw_flow_service.dart' show FlowOp;

/// Karakter hattinin istemcisi - `/api/character/flow/*`.
///
/// Jigsaw/CBN'in kabul-etiket-push kalibi DEGILDIR. Uc asamalidir:
///   1 Karakter    Uretim'de "Karakter Modu" ile aday uret, birini kabul et,
///                 isim ver -> kutuphanede karakter klasoru acilir.
///   2 Yon         Kabul edilen gorunusten 8 yon (Qwen Image Edit); front
///                 gorunusun kendisidir, kalan 7 yon icin aday secilir.
///   3 Animasyon   Yon -> klip -> sinirsiz surum (v01, v02...). Tek surum
///                 kabul edilir, sprite yalniz kabul edilenden cikar.
///
/// Uzun isler sunucuda arka planda kosar, `op()` ile izlenir (CBN ekranindaki
/// ilerleme cubugunun aynisi).

/// Bir yon: kimlik, ekran adi ve manken kamera azimutu.
class CharacterDir {
  final String id;
  final String label;
  final int azimuth;
  const CharacterDir(this.id, this.label, this.azimuth);

  factory CharacterDir.fromJson(Map<String, dynamic> j) => CharacterDir(
        '${j['id']}',
        '${j['label'] ?? j['id']}',
        (j['azimuth'] ?? 0) as int,
      );

  /// Rozet metni - F, FR, R, BR, B, BL, L, FL.
  String get short =>
      CharacterFlowService.shortOf(id);
}

/// Bir klibin bir yondeki hazirlik durumu (liste kartindaki ilerleme).
class ClipDirState {
  final bool manken;
  final bool wan;
  final bool sprite;
  const ClipDirState({this.manken = false, this.wan = false, this.sprite = false});

  factory ClipDirState.fromJson(Map<String, dynamic> j) => ClipDirState(
        manken: j['manken'] == true,
        wan: j['wan'] == true,
        sprite: j['sprite'] == true,
      );
}

/// Kutuphanedeki bir karakter.
class CharacterItem {
  final String name;
  final String klass;
  final String lookThumb;              // rel yol, bos olabilir
  final String baseThumb;              // notr kimlik karesi (rel), bos olabilir
  final String portraitThumb;          // bas-omuz portre (rel), bos olabilir
  /// Portre adaylari (rel). Sunucu gondermiyorsa bos kalir.
  final List<String> portraits;
  final Map<String, bool> dirs;        // yon id -> secilmis mi
  final Map<String, Map<String, ClipDirState>> anims;  // klip -> yon -> durum
  final int candidateCount;
  /// Aday dosyalari (rel). Sunucu yalniz sayi gonderiyorsa bos kalir.
  final List<String> candidates;
  /// Yon adaylari: yon id -> rel listesi. Sunucu gondermiyorsa bos kalir.
  final Map<String, List<String>> dirCandidates;
  /// character.json'daki yastiklama varsayilani (0 .. 0.3).
  final double padding;
  /// #299: bekleyen hikaye onerisi sayisi (card_proposals.json).
  final int proposals;

  const CharacterItem({
    required this.name,
    required this.klass,
    required this.lookThumb,
    this.baseThumb = '',
    this.portraitThumb = '',
    this.portraits = const [],
    required this.dirs,
    required this.anims,
    required this.candidateCount,
    this.candidates = const [],
    this.dirCandidates = const {},
    this.padding = 0,
    this.proposals = 0,
  });

  factory CharacterItem.fromJson(Map<String, dynamic> j) {
    final raw = j['candidate_files'] ?? j['candidates'];
    final list = raw is List
        ? raw.map(_relOf).where((e) => e.isNotEmpty).toList()
        : const <String>[];
    final anims = <String, Map<String, ClipDirState>>{};
    final a = j['anims'];
    if (a is Map) {
      a.forEach((clip, byDir) {
        if (byDir is Map) {
          anims['$clip'] = {
            for (final e in byDir.entries)
              '${e.key}': e.value is Map
                  ? ClipDirState.fromJson(Map<String, dynamic>.from(e.value as Map))
                  : const ClipDirState(),
          };
        }
      });
    }
    // Sunucu yon adaylarini SAYI olarak gonderir (dir_candidates: {yon: n});
    // dosya adlari kutuphane kuralindan gelir: turnaround/<yon>_NN.png.
    final dirCand = <String, List<String>>{};
    for (final key in ['dir_candidates', 'turnaround', 'turnaround_candidates']) {
      final t = j[key];
      if (t is Map) {
        t.forEach((dir, v) {
          if (v is List) {
            dirCand['$dir'] = v.map(_relOf).where((e) => e.isNotEmpty).toList();
          } else if (v is int && v > 0) {
            dirCand['$dir'] = [
              for (var i = 1; i <= v; i++)
                'turnaround/${dir}_${i.toString().padLeft(2, '0')}.png',
            ];
          }
        });
        if (dirCand.isNotEmpty) break;
      }
    }
    // Portre adaylari: liste gelmezse sayidan portrait/portrait_NN.png turetilir.
    final portreRaw = j['portraits'] ?? j['portrait_candidates'];
    return CharacterItem(
      name: '${j['name']}',
      klass: '${j['class'] ?? j['klass'] ?? ''}',
      lookThumb: '${j['look_thumb'] ?? j['look'] ?? ''}',
      baseThumb: '${j['base_thumb'] ?? j['base'] ?? ''}',
      portraitThumb: '${j['portrait_thumb'] ?? j['portrait'] ?? ''}',
      portraits: portreRaw is List
          ? portreRaw.map(_relOf).where((e) => e.isNotEmpty).toList()
          : portreRaw is int
              ? [
                  for (var i = 1; i <= portreRaw; i++)
                    'portrait/portrait_${i.toString().padLeft(2, '0')}.png',
                ]
              : const [],
      dirs: {
        for (final e in ((j['dirs'] as Map?) ?? const {}).entries)
          '${e.key}': e.value == true || (e.value is String && '${e.value}'.isNotEmpty),
      },
      anims: anims,
      candidateCount: raw is int ? raw : list.length,
      candidates: list,
      dirCandidates: dirCand,
      padding: ((j['padding'] as num?) ?? 0).toDouble().clamp(0.0, 0.3),
      // #299: sunucu sayi yerine liste gonderirse uzunlugu alinir, hic
      // gondermiyorsa 0.
      proposals: j['proposals'] is num
          ? (j['proposals'] as num).toInt()
          : (j['proposals'] is List ? (j['proposals'] as List).length : 0),
    );
  }

  /// Kac yon secilmis.
  int dirsDone(List<CharacterDir> all) =>
      all.where((d) => dirs[d.id] == true).length;

  /// Sprite'i cikmis klip x yon sayisi / toplam.
  (int, int) get spriteProgress {
    var ok = 0, total = 0;
    for (final byDir in anims.values) {
      for (final s in byDir.values) {
        total++;
        if (s.sprite) ok++;
      }
    }
    return (ok, total);
  }

  static String _relOf(dynamic e) {
    if (e is String) return e;
    if (e is Map) return '${e['rel'] ?? e['file'] ?? e['name'] ?? ''}';
    return '';
  }
}

/// #299: card.md icin bekleyen bir Ollama onerisi. Oneriler sunucuda
/// `card_proposals.json`da durur; kullanici birini kabul edene kadar card.md
/// degismez (eskiden onay penceresiyle sorulurdu).
class CardProposal {
  final String id;
  final String created;   // ISO
  final String model;     // orn. gemma3:12b
  final String card;      // markdown
  final bool accepted;
  const CardProposal({
    required this.id,
    required this.created,
    required this.model,
    required this.card,
    required this.accepted,
  });

  factory CardProposal.fromJson(Map<String, dynamic> j) => CardProposal(
        id: '${j['id'] ?? ''}',
        created: '${j['created'] ?? j['created_at'] ?? ''}',
        model: '${j['model'] ?? ''}',
        card: '${j['card'] ?? j['text'] ?? j['md'] ?? ''}',
        accepted: j['accepted'] == true,
      );

  /// Baslikta gosterilen kisa tarih - `dd.MM HH:mm` (yerel saat).
  String get whenLabel {
    final t = DateTime.tryParse(created)?.toLocal();
    if (t == null) return created;
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(t.day)}.${p(t.month)} ${p(t.hour)}:${p(t.minute)}';
  }

  /// Kapali kartta gosterilen ozet: "Hikaye" maddesinin ilk satiri, yoksa
  /// baslik olmayan ilk satir.
  String get headline {
    final satirlar = card
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final temizle = RegExp(r'^[#\-*>\s]+');
    var bekle = false;            // "Hikaye" basligi gorundu, govde sonraki satir
    for (final s in satirlar) {
      final d = s.replaceFirst(temizle, '').trim();
      if (d.isEmpty) continue;
      if (bekle) return d;
      if (d.toLowerCase().startsWith('hikaye')) {
        final k = d.indexOf(':');
        final t = k >= 0 ? d.substring(k + 1).trim() : '';
        if (t.isNotEmpty) return t;
        bekle = true;
      }
    }
    for (final s in satirlar) {
      final d = s.replaceFirst(temizle, '').trim();
      if (d.isNotEmpty) return d;
    }
    return '(bos metin)';
  }
}

/// Mixamo arsivindeki bir klip - ad, hash ve tam dosya adi.
class MixamoClip {
  final String name;    // 'Great Sword Slash'
  final String hash;    // 'c9cc7d9c'
  final String fbx;     // 'Great Sword Slash [c9cc7d9c].fbx'
  /// rev8: Ollama onerisinde bu klibin neden secildigi.
  final String why;
  const MixamoClip(this.name, this.hash, this.fbx, {this.why = ''});

  /// Sunucu duz metin gonderirse ad ve hash dosya adindan cikarilir.
  factory MixamoClip.fromFile(String fbx) {
    final i = fbx.indexOf(' [');
    final ad = i < 0 ? fbx.replaceAll('.fbx', '') : fbx.substring(0, i);
    final h = i < 0
        ? ''
        : fbx.substring(i + 2).replaceAll(']', '').replaceAll('.fbx', '');
    return MixamoClip(ad, h, fbx);   // gerekce yok - duz arama sonucu
  }

  factory MixamoClip.fromJson(Map<String, dynamic> j) {
    final fbx = '${j['fbx'] ?? j['file'] ?? j['filename'] ?? j['name'] ?? ''}';
    final t = MixamoClip.fromFile(fbx);
    return MixamoClip(
      '${j['name'] ?? j['label'] ?? t.name}',
      '${j['hash'] ?? t.hash}',
      fbx,
      why: '${j['why'] ?? ''}',
    );
  }
}

/// Bir klibin bir surumu.
class CharacterVersion {
  final String v;
  final bool hasWan;
  final bool hasManken;
  final int? seed;
  /// Sunucunun verdigi rel yollar - istemci yol hesaplamaz (rev4).
  final String relWan;
  final String relManken;
  const CharacterVersion(this.v, this.hasWan, this.seed,
      {this.hasManken = false, this.relWan = '', this.relManken = ''});

  factory CharacterVersion.fromJson(Map<String, dynamic> j) => CharacterVersion(
        '${j['v'] ?? j['version'] ?? ''}',
        j['has_wan'] == true,
        (j['seed'] as num?)?.toInt(),
        hasManken: j['has_manken'] == true,
        relWan: '${j['rel_wan'] ?? ''}',
        relManken: '${j['rel_manken'] ?? ''}',
      );

  /// Oynatilacak dosya: wan varsa o, yoksa manken.
  String relFor(String dir, String clip) {
    if (hasWan) {
      return relWan.isNotEmpty
          ? relWan
          : CharacterFlowService.versionVideoRel(dir, clip, v);
    }
    return relManken.isNotEmpty
        ? relManken
        : CharacterFlowService.versionVideoRel(dir, clip, v, manken: true);
  }
}

/// Bir yondeki tek klip: surumleri, kabul edileni, sprite durumu.
class CharacterClip {
  final String clip;
  final String dir;
  final List<CharacterVersion> versions;
  final String accepted;
  final bool hasSprite;
  final String relWebp;          // anims/<yon>/<klip>/anim.webp
  final String relSheet;
  final String relAcceptedWan;   // kabul edilen surumun videosu
  final String fbx;
  final String pose;
  const CharacterClip({
    required this.clip,
    required this.versions,
    required this.accepted,
    required this.hasSprite,
    this.dir = '',
    this.relWebp = '',
    this.relSheet = '',
    this.relAcceptedWan = '',
    this.fbx = '',
    this.pose = '',
  });

  factory CharacterClip.fromJson(Map<String, dynamic> j) => CharacterClip(
        clip: '${j['clip'] ?? j['name'] ?? ''}',
        dir: '${j['dir'] ?? ''}',
        versions: ((j['versions'] ?? []) as List)
            .map((e) => CharacterVersion.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        accepted: '${j['accepted'] ?? ''}',
        hasSprite: j['has_sprite'] == true,
        relWebp: '${j['rel_webp'] ?? ''}',
        relSheet: '${j['rel_sheet'] ?? ''}',
        relAcceptedWan: '${j['rel_accepted_wan'] ?? ''}',
        fbx: '${j['fbx'] ?? ''}',
        pose: '${j['pose'] ?? ''}',
      );

  /// anim.webp yolu - sunucu vermezse kutuphane kuralindan.
  String webpRel(String d) =>
      relWebp.isNotEmpty ? relWebp : CharacterFlowService.spriteRel(d, clip);

  /// Kabul edilen surumun videosu - sunucu vermezse kutuphane kuralindan.
  String acceptedRel(String d) => relAcceptedWan.isNotEmpty
      ? relAcceptedWan
      : (accepted.isEmpty
          ? ''
          : CharacterFlowService.versionVideoRel(d, clip, accepted));
}

/// rev8: yerel Ollama kapaliyken sunucu 503 doner - sihirli degnek pasiflesir,
/// duz akis calismaya devam eder.
class OllamaOffException implements Exception {
  final String message;
  const OllamaOffException([this.message = 'Ollama kapali']);
  @override
  String toString() => message;
}

class CharacterFlowService {
  static const _timeout = Duration(seconds: 60);

  /// Sunucu `dirs_list` vermezse kullanilan sabit sira (design/karakter_modu.md).
  static const defaultDirs = <CharacterDir>[
    CharacterDir('front', 'On', 0),
    CharacterDir('front_right', 'On-Sag', 45),
    CharacterDir('right', 'Sag', 90),
    CharacterDir('back_right', 'Arka-Sag', 135),
    CharacterDir('back', 'Arka', 180),
    CharacterDir('back_left', 'Arka-Sol', 225),
    CharacterDir('left', 'Sol', 270),
    CharacterDir('front_left', 'On-Sol', 315),
  ];

  static const _shorts = <String, String>{
    'front': 'F',
    'front_right': 'FR',
    'right': 'R',
    'back_right': 'BR',
    'back': 'B',
    'back_left': 'BL',
    'left': 'L',
    'front_left': 'FL',
  };

  static String shortOf(String id) =>
      _shorts[id] ??
      id.split('_').map((p) => p.isEmpty ? '' : p[0].toUpperCase()).join();

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AppConfig.apiKey.isNotEmpty) 'X-API-Key': AppConfig.apiKey,
      };

  static Map<String, String> get authHeaders => GenerateService.authHeaders;

  static Never _fail(http.Response r, String fallback) {
    try {
      final d = json.decode(r.body);
      throw Exception('${d['detail'] ?? fallback}');
    } catch (_) {
      throw Exception('$fallback (${r.statusCode})');
    }
  }

  static dynamic _decode(http.Response r) =>
      json.decode(utf8.decode(r.bodyBytes));

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

  static Future<Map<String, dynamic>> _put(String path,
      Map<String, dynamic> body) async {
    final r = await http
        .put(Uri.parse('${ApiService.baseUrl}$path'),
            headers: _headers, body: json.encode(body))
        .timeout(_timeout);
    if (r.statusCode != 200) _fail(r, 'Istek basarisiz');
    return Map<String, dynamic>.from(_decode(r) as Map);
  }

  static Future<Map<String, dynamic>> _delete(String path,
      Map<String, dynamic> body) async {
    final req = http.Request('DELETE', Uri.parse('${ApiService.baseUrl}$path'))
      ..headers.addAll(_headers)
      ..body = json.encode(body);
    final r = await http.Response.fromStream(await req.send()).timeout(_timeout);
    if (r.statusCode != 200) _fail(r, 'Silinemedi');
    return Map<String, dynamic>.from(_decode(r) as Map);
  }

  /// Liste / sozluk / bare liste - hangisi gelirse listeye cevirir.
  static List<Map<String, dynamic>> _rows(dynamic d, [List<String>? keys]) {
    if (d is List) {
      return d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (d is Map) {
      for (final k in keys ?? const ['items', 'clips', 'dirs', 'results', 'files']) {
        final v = d[k];
        if (v is List) {
          return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    }
    return const [];
  }

  // ------------------------------------------------------------- okuma
  /// Sabit yon listesi. Sunucu ucu yoksa `defaultDirs`'e duser.
  static Future<List<CharacterDir>> dirsList() async {
    try {
      final rows = _rows(await _getAny('/api/character/flow/dirs_list'));
      final out = rows.map(CharacterDir.fromJson).where((d) => d.id.isNotEmpty).toList();
      return out.isEmpty ? defaultDirs : out;
    } catch (_) {
      return defaultDirs;
    }
  }

  static Future<List<CharacterItem>> list() async {
    final rows = _rows(await _getAny('/api/character/flow/list'));
    return rows.map(CharacterItem.fromJson).toList();
  }

  /// Tek karakterin ayrintisi. Sunucu `?name=` suzmesini desteklemiyorsa
  /// tum listeden ayni ismi ceker (ayni govde, ayni ucu kullanir).
  static Future<CharacterItem?> detail(String name) async {
    try {
      final rows = _rows(
          await _getAny('/api/character/flow/list?name=${Uri.encodeQueryComponent(name)}'));
      final hit = rows
          .map(CharacterItem.fromJson)
          .where((c) => c.name == name)
          .toList();
      if (hit.isNotEmpty) return hit.first;
    } catch (_) {
      // sunucu suzme desteklemiyorsa asagidaki tam liste denenir
    }
    final all = await list();
    for (final c in all) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// Bir yonun klipleri ve surumleri.
  static Future<List<CharacterClip>> animsOf(String name, String dir) async {
    final rows = _rows(await _getAny(
        '/api/character/flow/anims_of?name=${Uri.encodeQueryComponent(name)}'
        '&dir=${Uri.encodeQueryComponent(dir)}'));
    return rows.map(CharacterClip.fromJson).toList();
  }

  /// anims.json (klip seti).
  static Future<Map<String, dynamic>> anims(String name) async {
    final d = await _get('/api/character/flow/anims?name=${Uri.encodeQueryComponent(name)}');
    final inner = d['anims'];
    return inner is Map ? Map<String, dynamic>.from(inner) : d;
  }

  static Future<void> saveAnims(String name, Map<String, dynamic> data) =>
      _put('/api/character/flow/anims', {'name': name, 'anims': data});

  /// Mixamo arsivinde klip arama (1975 FBX) - ad, hash, dosya adi.
  static Future<List<MixamoClip>> mixamo(String q, {int limit = 60}) async {
    final d = await _getAny('/api/character/flow/mixamo'
        '?q=${Uri.encodeQueryComponent(q)}&limit=$limit');
    List<dynamic>? liste;
    if (d is List) {
      liste = d;
    } else if (d is Map) {
      for (final k in ['items', 'clips', 'results', 'files']) {
        if (d[k] is List) {
          liste = d[k] as List;
          break;
        }
      }
    }
    if (liste == null) return const [];
    return liste
        .map((e) => e is String
            ? MixamoClip.fromFile(e)
            : MixamoClip.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((c) => c.fbx.isNotEmpty)
        .toList();
  }

  /// #297: uzun sunucu isini bekler. Istek/cevap 100 sn'de kesen tunelden
  /// gecmesin diye is arka planda kosar, burada 2 sn'de bir /op/{id} sorulur.
  /// Sonuc op kaydinin `result` alanindadir.
  static Future<Map<String, dynamic>> _awaitOp(
    String opId, {
    String hata = 'Islem basarisiz',
    Duration limit = const Duration(minutes: 10),
  }) async {
    final son = DateTime.now().add(limit);
    var artarda = 0;                       // ust uste ag hatasi (gecici olabilir)
    while (DateTime.now().isBefore(son)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      FlowOp o;
      try {
        o = await op(opId);
        artarda = 0;
      } catch (e) {
        if (++artarda >= 5) throw Exception('$hata ($e)');
        continue;
      }
      if (o.running) continue;
      if (o.status == 'done' && o.failed == 0 && o.result.isNotEmpty) {
        return o.result;
      }
      throw Exception(o.message.isNotEmpty
          ? o.message
          : (o.log.isNotEmpty ? o.log.last : hata));
    }
    throw Exception('$hata (zaman asimi)');
  }

  /// rev8: kisa istegi Ollama ile genisletir.
  ///   mode 'i2v'     -> {prompt}: tam hareket tarifi (duzenlenebilir doner)
  ///   mode 'mixamo'  -> {clips}: en iyi 8 aday (name, hash, filename, why)
  /// Ollama kapaliysa 503 -> [OllamaOffException].
  /// #297: sunucu artik {"op": id} doner, sonuc op'un `result` alanindan gelir
  /// (eski sunucu metni dogrudan dondururse o da kabul edilir).
  static Future<({String prompt, List<MixamoClip> clips})> expandPrompt({
    required String name,
    required String dir,
    required String text,
    required String mode,
  }) async {
    final r = await http
        .post(Uri.parse('${ApiService.baseUrl}/api/character/flow/prompt/expand'),
            headers: _headers,
            body: json.encode(
                {'name': name, 'dir': dir, 'text': text, 'mode': mode}))
        .timeout(_timeout);
    if (r.statusCode == 503) throw const OllamaOffException();
    if (r.statusCode != 200) _fail(r, 'Genisletme basarisiz');
    var d = Map<String, dynamic>.from(_decode(r) as Map);
    final opId = '${d['op'] ?? ''}';
    if (opId.isNotEmpty) {
      d = await _awaitOp(opId, hata: 'Genisletme basarisiz');
    }
    final ham = d['clips'];
    return (
      prompt: '${d['prompt'] ?? d['text'] ?? ''}',
      clips: ham is List
          ? ham
              .map((e) => e is String
                  ? MixamoClip.fromFile(e)
                  : MixamoClip.fromJson(Map<String, dynamic>.from(e as Map)))
              .where((c) => c.fbx.isNotEmpty)
              .toList()
          : const <MixamoClip>[],
    );
  }

  /// card.md metni.
  static Future<String> card(String name) async {
    final d = await _get('/api/character/flow/card?name=${Uri.encodeQueryComponent(name)}');
    for (final k in ['card', 'text', 'md', 'content']) {
      final v = d[k];
      if (v is String) return v;
    }
    return '';
  }

  static Future<void> saveCard(String name, String text) =>
      _put('/api/character/flow/card', {'name': name, 'card': text, 'text': text});

  /// Karakter basina yastiklama varsayilani (character.json). Uretim
  /// ekranindaki secici degisince yazilir; butun klipler ayni degeri gorur (#295).
  static Future<void> savePadding(String name, double padding) =>
      _put('/api/character/flow/settings', {'name': name, 'padding': padding});

  // -------------------------------------------------------------- dosya
  static String thumbUrl(String name, String rel, {int size = 360}) =>
      '${ApiService.baseUrl}/api/character/flow/thumb'
      '?name=${Uri.encodeQueryComponent(name)}'
      '&rel=${Uri.encodeQueryComponent(rel)}&size=$size';

  static String fileUrl(String name, String rel) =>
      '${ApiService.baseUrl}/api/character/flow/file'
      '?name=${Uri.encodeQueryComponent(name)}'
      '&rel=${Uri.encodeQueryComponent(rel)}';

  /// Kutuphane duzenindeki sabit yollar - ekran bunlari uydurmasin.
  static String turnaroundRel(String dir) => 'turnaround/$dir.png';
  static String versionVideoRel(String dir, String clip, String v,
          {bool manken = false}) =>
      'anims/$dir/$clip/$v/${manken ? "manken" : "wan"}.mp4';
  static String spriteRel(String dir, String clip) => 'anims/$dir/$clip/anim.webp';
  static String sheetRel(String dir, String clip) => 'anims/$dir/$clip/sheet.png';

  // ------------------------------------------------------------- yazma
  /// Uretilenler'deki bir isten yeni karakter acar.
  static Future<String> create(
      {required String name, required String klass, required String jobId}) async {
    final d = await _post('/api/character/flow/create',
        {'name': name, 'class': klass, 'job_id': jobId});
    return '${d['name'] ?? name}';
  }

  /// Uretilenler'deki isleri mevcut karakterin `candidates/` klasorune kopyalar.
  static Future<int> stage({required String name, required List<String> jobIds}) async {
    final d = await _post('/api/character/flow/stage', {'name': name, 'job_ids': jobIds});
    final eklenen = d['added'];
    if (eklenen is List) return eklenen.length;
    return (d['staged'] ?? d['ok'] ?? jobIds.length) as int;
  }

  /// kind: `look` | `base` | `dir:<yon>`
  static Future<void> pick(
          {required String name, required String file, required String kind}) =>
      _post('/api/character/flow/pick', {'name': name, 'file': file, 'kind': kind});

  /// Yon adaylari uretir (Qwen Image Edit) - op doner.
  static Future<String> dirs(
          {required String name, required List<String> dirs, required int n}) async =>
      '${(await _post('/api/character/flow/dirs',
          {'name': name, 'dirs': dirs, 'n': n}))['op']}';

  /// Blender manken render'i (CPU, gpu seridi almaz) - op doner.
  static Future<String> manken(
          {required String name,
          required List<String> clips,
          required List<String> dirs}) async =>
      '${(await _post('/api/character/flow/manken',
          {'name': name, 'clips': clips, 'dirs': dirs}))['op']}';

  /// Animasyon uretimi - iki yol vardir (rev3):
  ///   mode 'mixamo'  Blender manken -> Wan Animate 2 (klipler arsivden secilir)
  ///   mode 'i2v'     saf AI i2v (Wan 2.2 / LTX) - hareket cumlesi kullanicidan
  /// Her cagri her klip icin n YENI surum acar; eskiler silinmez. Op doner.
  static Future<String> animate({
    required String name,
    required String dir,
    required int n,
    String mode = 'mixamo',
    List<String> clips = const [],
    String prompt = '',
    String clip = '',
    String engine = '',
    double padding = 0,
  }) async =>
      '${(await _post('/api/character/flow/animate', {
        'name': name,
        'dir': dir,
        'mode': mode,
        'n': n,
        if (clips.isNotEmpty) 'clips': clips,
        if (prompt.isNotEmpty) 'prompt': prompt,
        if (clip.isNotEmpty) 'clip': clip,
        if (engine.isNotEmpty) 'engine': engine,
        'padding': padding,
      }))['op']}';

  /// Bas-omuz portre adaylari (Qwen Image Edit, look'tan) - op doner.
  static Future<String> portrait({required String name, required int n}) async =>
      '${(await _post('/api/character/flow/portrait', {'name': name, 'n': n}))['op']}';

  /// card.md icin n oneri uretir (yerel Ollama). #299: artik metin beklenmez -
  /// OP KIMLIGI doner, oneriler sunucuda `card_proposals.json`a yazilir ve
  /// ekranda listelenir; kart yalniz `acceptProposal` ile degisir.
  static Future<String> enrichCard(String name, {int n = 2}) async =>
      '${(await _post('/api/character/flow/card/enrich',
          {'name': name, 'n': n}))['op']}';

  /// #299: bekleyen oneriler (yeniden eskiye).
  static Future<List<CardProposal>> cardProposals(String name) async {
    final d = await _getAny(
        '/api/character/flow/card/proposals?name=${Uri.encodeQueryComponent(name)}');
    return _rows(d, const ['proposals', 'items'])
        .map(CardProposal.fromJson)
        .where((p) => p.id.isNotEmpty)
        .toList();
  }

  /// #299: oneriyi kabul eder - sunucu card.md'yi yazar, yeni metni doner.
  static Future<String> acceptProposal(String name, String id) async {
    final d = await _post(
        '/api/character/flow/card/proposals/accept', {'name': name, 'id': id});
    return '${d['card'] ?? ''}';
  }

  /// #299: oneriyi siler (card.md'ye dokunmaz).
  static Future<void> deleteProposal(String name, String id) => _delete(
      '/api/character/flow/card/proposal?name=${Uri.encodeQueryComponent(name)}'
      '&id=${Uri.encodeQueryComponent(id)}',
      const {});

  /// Bir klibin o yondeki butun surumlerini siler.
  static Future<void> deleteClip(
          {required String name, required String dir, required String clip}) =>
      _delete('/api/character/flow/clip',
          {'name': name, 'dir': dir, 'clip': clip});

  /// Karakteri komple siler - GERI ALINAMAZ.
  static Future<void> removeCharacter(String name) =>
      _delete('/api/character/flow/character', {'name': name});

  /// Bir yonun secili gorselini ve adaylarini siler.
  static Future<void> deleteDir({required String name, required String dir}) =>
      _delete('/api/character/flow/dir', {'name': name, 'dir': dir});

  /// Tek kabul edilen surum (yeniden kabul serbest, eski sprite silinir).
  static Future<void> accept(
          {required String name,
          required String dir,
          required String clip,
          required String version}) =>
      _post('/api/character/flow/accept',
          {'name': name, 'dir': dir, 'clip': clip, 'version': version});

  static Future<void> deleteVersion(
          {required String name,
          required String dir,
          required String clip,
          required String version}) =>
      _delete('/api/character/flow/version',
          {'name': name, 'dir': dir, 'clip': clip, 'version': version});

  /// Kabul edilmis surumlerden kare kare SAM3 -> anim.webp + sheet.png. Op doner.
  static Future<String> sprites(
          {required String name,
          required String dir,
          required List<String> clips}) async =>
      '${(await _post('/api/character/flow/sprites',
          {'name': name, 'dir': dir, 'clips': clips}))['op']}';

  static Future<FlowOp> op(String opId) async =>
      FlowOp.fromJson(await _get('/api/character/flow/op/$opId'));
}
