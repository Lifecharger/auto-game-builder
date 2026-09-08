import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'api_service.dart';
import 'generate_service.dart';
import 'jigsaw_flow_service.dart' show FlowOp;

/// Karakter hattinin istemcisi - `/api/character/flow/*`.
///
/// Jigsaw/CBN'in kabul-etiket-push kalibi DEGILDIR. #306 (karakter hatti v2):
///   1 Karakter    "Karakter olustur" otomatik hatti baslatir: base adaylari ->
///                 portre -> hikaye -> 7 yon, hepsi onaysiz. Kullanici sonra
///                 base'i degistirir, portre/hikaye adaylarindan secer.
///   2 Yon         BASE'in 8 yonu (`base/dirs/`). Burada animasyon YOKTUR.
///   3 Skinler     Skin = kiyafet. `base` de bir skindir. Her skinin kendi 8
///                 yonu ve animasyonlari vardir; animasyon skin ustunde yapilir
///                 (yon -> klip -> sinirsiz surum, tek kabul, sprite).
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

  /// Rozet metni - S, SE, E, NE, N, NW, W, SW (#301 pusula).
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

// #306: sunucudan gelen rel yol - duz metin ya da {rel|file|name} olabilir.
String _relOf(dynamic e) {
  if (e is String) return e;
  if (e is Map) return '${e['rel'] ?? e['file'] ?? e['name'] ?? ''}';
  return '';
}

// #306: `anims` ozeti (klip -> yon -> durum) - hem karakter hem skin kullanir.
Map<String, Map<String, ClipDirState>> _parseAnims(dynamic a) {
  final out = <String, Map<String, ClipDirState>>{};
  if (a is Map) {
    a.forEach((clip, byDir) {
      if (byDir is Map) {
        out['$clip'] = {
          for (final e in byDir.entries)
            '${e.key}': e.value is Map
                ? ClipDirState.fromJson(Map<String, dynamic>.from(e.value as Map))
                : const ClipDirState(),
        };
      }
    });
  }
  return out;
}

// #314: `anim_modes` - hangi animasyon yollari acik. Sunucu alani
// gondermiyorsa deger TURDEN turetilir (dokuman §3c): insan turlerinde
// manken/Mixamo + i2v, hayvan/makinede yalniz i2v (manken insansi).
List<String> _parseAnimModes(dynamic v, String kind) {
  if (v is List) {
    final out = v.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    if (out.isNotEmpty) return out;
  }
  return CharacterFlowService.defaultAnimModes(kind);
}

// #306: yon id -> secilmis mi. Sunucu bool ya da rel yol gonderebilir.
Map<String, bool> _parseDirs(dynamic v) => {
      for (final e in ((v as Map?) ?? const {}).entries)
        '${e.key}':
            e.value == true || (e.value is String && '${e.value}'.isNotEmpty),
    };

// #306: yon id -> kabul edilen dosyanin rel yolu (`dir_files`). Sunucu
// gondermiyorsa bos kalir, ekran kutuphane kuralina duser.
Map<String, String> _parseDirFiles(dynamic v) {
  final out = <String, String>{};
  if (v is Map) {
    v.forEach((k, e) {
      final rel = _relOf(e);
      if (rel.isNotEmpty) out['$k'] = rel;
    });
  }
  return out;
}

// #306: yon adaylari. Sunucu liste ya da SAYI gonderebilir; sayi gelirse
// dosya adlari kutuphane kuralindan turetilir (`<kok>/<yon>_NN.png`).
Map<String, List<String>> _parseDirCandidates(
    Map<String, dynamic> j, String kok) {
  final out = <String, List<String>>{};
  for (final key in ['dir_candidates', 'turnaround', 'turnaround_candidates']) {
    final t = j[key];
    if (t is Map) {
      t.forEach((dir, v) {
        if (v is List) {
          out['$dir'] = v.map(_relOf).where((e) => e.isNotEmpty).toList();
        } else if (v is int && v > 0) {
          out['$dir'] = [
            for (var i = 1; i <= v; i++)
              '$kok/${dir}_${i.toString().padLeft(2, '0')}.png',
          ];
        }
      });
      if (out.isNotEmpty) break;
    }
  }
  return out;
}

/// #306: `character.json.pipeline` - "karakter olustur" dedikten sonra base,
/// portre, hikaye ve yonleri kendiliginden kuran otomatik hat.
class PipelineState {
  final String status;   // idle | running | done | error
  final String step;     // suren adimin adi
  final String op;       // izlenecek op kimligi
  final int done;
  final int total;
  const PipelineState({
    this.status = '',
    this.step = '',
    this.op = '',
    this.done = 0,
    this.total = 0,
  });

  factory PipelineState.fromJson(Map<String, dynamic> j) => PipelineState(
        status: '${j['status'] ?? ''}',
        step: '${j['step'] ?? j['message'] ?? ''}',
        op: '${j['op'] ?? ''}',
        done: (j['done'] is num) ? (j['done'] as num).toInt() : 0,
        total: (j['total'] is num) ? (j['total'] as num).toInt() : 0,
      );

  bool get running => status == 'running';
  double? get progress =>
      total > 0 ? (done / total).clamp(0, 1).toDouble() : null;
}

/// Kutuphanedeki bir karakter.
class CharacterItem {
  final String name;
  final String klass;
  /// #314: karakter turu - `female` (varsayilan) | `male` | `animal` |
  /// `machine`. Sunucu alani gondermiyorsa `female` sayilir (dokuman §3c).
  final String kind;
  /// #314: prompt'larda kullanilan ozne ("woman", "man", "dog", "robot").
  /// Sunucu gondermiyorsa bos - ekran tur etiketine duser.
  final String subject;
  /// #314: acik animasyon yollari - `i2v` ve/veya `mixamo`. `mixamo` yoksa
  /// manken/Mixamo dugmeleri gizlenir (hayvan/makine).
  final List<String> animModes;
  /// #306: kart gorseli = base'in SOUTH karesi (`base/base.png`). Eski
  /// sunucuda `look_thumb` gelirse o kullanilir - liste yine cizilir.
  final String southThumb;
  final String portraitThumb;          // KARE vesikalik (rel), bos olabilir
  /// Portre adaylari (rel). Sunucu gondermiyorsa bos kalir.
  final List<String> portraits;
  final Map<String, bool> dirs;        // yon id -> secilmis mi (base'in yonleri)
  /// #306: yon id -> kabul edilen dosyanin rel yolu (`dir_files`).
  final Map<String, String> dirFiles;
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
  /// #302: sabit adli gorsellerin surumu (ms) - URL onbellegini asar.
  final int rev;
  /// #306: otomatik hattin durumu. Sunucu gondermiyorsa bos (idle) kalir.
  final PipelineState pipeline;
  /// #306: skin slug'lari (ilk eleman `base`).
  final List<String> skins;

  const CharacterItem({
    required this.name,
    required this.klass,
    this.kind = 'female',                       // #314
    this.subject = '',                          // #314
    this.animModes = const ['i2v', 'mixamo'],   // #314
    this.southThumb = '',
    this.portraitThumb = '',
    this.portraits = const [],
    required this.dirs,
    this.dirFiles = const {},
    required this.anims,
    required this.candidateCount,
    this.candidates = const [],
    this.dirCandidates = const {},
    this.padding = 0,
    this.proposals = 0,
    this.rev = 0,
    this.pipeline = const PipelineState(),
    this.skins = const [],
  });

  factory CharacterItem.fromJson(Map<String, dynamic> j) {
    final raw = j['candidate_files'] ?? j['candidates'];
    final list = raw is List
        ? raw.map(_relOf).where((e) => e.isNotEmpty).toList()
        : const <String>[];
    // Portre adaylari: liste gelmezse sayidan portrait/portrait_NN.png turetilir.
    final portreRaw = j['portraits'] ?? j['portrait_candidates'];
    final skinRaw = j['skins'];
    // #314: tur alani yoksa (eski sunucu / eski character.json) `female`.
    final tur = '${j['kind'] ?? ''}'.trim();
    final kind = tur.isEmpty ? 'female' : tur;
    return CharacterItem(
      name: '${j['name']}',
      klass: '${j['class'] ?? j['klass'] ?? ''}',
      kind: kind,                                          // #314
      subject: '${j['subject'] ?? ''}',                    // #314
      animModes: _parseAnimModes(j['anim_modes'], kind),   // #314
      // #306: south_thumb = base; look_thumb yalniz eski sunucu icin okunur.
      southThumb: '${j['south_thumb'] ?? j['base'] ?? j['base_thumb'] ?? j['look_thumb'] ?? j['look'] ?? ''}',
      portraitThumb: '${j['portrait_thumb'] ?? j['portrait'] ?? ''}',
      portraits: portreRaw is List
          ? portreRaw.map(_relOf).where((e) => e.isNotEmpty).toList()
          : portreRaw is int
              ? [
                  for (var i = 1; i <= portreRaw; i++)
                    'portrait/portrait_${i.toString().padLeft(2, '0')}.png',
                ]
              : const [],
      dirs: _parseDirs(j['dirs']),
      dirFiles: _parseDirFiles(j['dir_files']),
      anims: _parseAnims(j['anims']),
      candidateCount: raw is int ? raw : list.length,
      candidates: list,
      // #306: base yonleri artik base/dirs/ altinda.
      dirCandidates: _parseDirCandidates(j, 'base/dirs'),
      padding: ((j['padding'] as num?) ?? 0).toDouble().clamp(0.0, 0.3),
      // #299: sunucu sayi yerine liste gonderirse uzunlugu alinir, hic
      // gondermiyorsa 0.
      proposals: j['proposals'] is num
          ? (j['proposals'] as num).toInt()
          : (j['proposals'] is List ? (j['proposals'] as List).length : 0),
      rev: (j['rev'] is num) ? (j['rev'] as num).toInt() : 0,
      pipeline: j['pipeline'] is Map
          ? PipelineState.fromJson(Map<String, dynamic>.from(j['pipeline'] as Map))
          : const PipelineState(),
      skins: skinRaw is List
          ? skinRaw
              .map((e) => e is Map ? '${e['slug'] ?? ''}' : '$e')
              .where((e) => e.isNotEmpty)
              .toList()
          : const [],
    );
  }

  /// Kac yon secilmis.
  int dirsDone(List<CharacterDir> all) =>
      all.where((d) => dirs[d.id] == true).length;

  /// #306: skin sayaci - sunucu `base`i de listeledigi icin en az 1.
  int get skinCount => skins.isEmpty ? 1 : skins.length;

  /// #314: turun ekranda gorunen adi (Kadin / Erkek / Hayvan / Makine).
  String get kindTitle => CharacterFlowService.kindLabel(kind);

  /// #314: manken/Mixamo yolu bu turde acik mi (hayvan/makine: hayir).
  bool get mixamoOn => animModes.contains('mixamo');

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
}

/// #306: kiyafet kutuphanesi ogesi - KARAKTERDEN BAGIMSIZ. `<root>/_outfits/`
/// altinda durur, ayni kiyafet bircok karaktere giydirilebilir. Skin = kiyafet
/// + karakterin base'i, skin slug'i kiyafet slug'idir.
class OutfitItem {
  final String slug;
  final String name;
  final String prompt;
  final String created;              // ISO
  final String rel;                  // `_outfits/<slug>.png`
  /// #311: png henuz yoksa (kuyrukta ya da basarisiz) false.
  final bool ready;
  /// #313 gardirop v2: kategori kimligi - `set` (tum takim), `top`, `bottom`,
  /// `shoes`, `socks`, `hat`, `headgear`, `accessory`, `weapon`, `other`.
  /// Kategorisi olmayan ESKI kayit `set` sayilir (dokuman §3b).
  final String category;
  /// #314: kiyafet turu - `female` (varsayilan) | `male` | `animal` |
  /// `machine`. Gardirop tur icinde kilitlidir: bir karaktere yalniz kendi
  /// turunun kiyafetleri giydirilir (dokuman §3c). Turu olmayan ESKI kayit
  /// `female` sayilir.
  final String kind;
  const OutfitItem({
    required this.slug,
    required this.name,
    this.prompt = '',
    this.created = '',
    this.rel = '',
    this.ready = true,
    this.category = 'set',
    this.kind = 'female',
  });

  factory OutfitItem.fromJson(Map<String, dynamic> j) {
    final slug = '${j['slug'] ?? j['name'] ?? ''}';
    // #313: sunucu alani henuz gondermiyorsa (eski surum) `set`e duser.
    final kat = '${j['category'] ?? ''}'.trim();
    // #314: tur alani yoksa (eski kayit / eski sunucu) `female`.
    final tur = '${j['kind'] ?? ''}'.trim();
    return OutfitItem(
      slug: slug,
      name: '${j['name'] ?? slug}',
      prompt: '${j['prompt'] ?? ''}',
      created: '${j['created'] ?? j['created_at'] ?? ''}',
      rel: '${j['rel'] ?? '_outfits/$slug.png'}',
      ready: j['ready'] != false,
      category: kat.isEmpty ? 'set' : kat,
      kind: tur.isEmpty ? 'female' : tur,      // #314
    );
  }

  /// #313: kategorinin ekranda gorunen kisa adi (bilinmeyen id oldugu gibi).
  String get categoryLabel => CharacterFlowService.categoryLabel(category);

  /// #314: turun ekranda gorunen adi.
  String get kindLabel => CharacterFlowService.kindLabel(kind);
}

/// #306: bir skin - kiyafet. `base` de bir skindir (slug `base`, yonleri
/// `base/dirs/`, animasyonlari `anims/`). Diger skinler `skins/<slug>/` ve
/// slug'lari kiyafet slug'idir.
class SkinItem {
  final String slug;
  final String name;
  final String prompt;               // kiyafet tarifi
  final String south;                // South (front) gorselinin rel yolu
  /// Kaynak kiyafetin slug'i (base icin bos).
  final String outfitSlug;
  final String outfit;               // kiyafet referansi (rel)
  final Map<String, bool> dirs;      // yon id -> giydirilmis mi
  final Map<String, String> dirFiles;
  final Map<String, List<String>> dirCandidates;
  final Map<String, Map<String, ClipDirState>> anims;
  final int rev;
  /// #313: skin bir SET yerine parca kombinasyonundan da uretilebilir -
  /// `skin.json.pieces` = uygulanan kiyafet slug'lari (kategori sirasiyla).
  /// Sunucu gondermiyorsa bos kalir (eski skinler).
  final List<String> pieces;

  const SkinItem({
    required this.slug,
    required this.name,
    this.prompt = '',
    this.south = '',
    this.outfitSlug = '',
    this.outfit = '',
    this.dirs = const {},
    this.dirFiles = const {},
    this.dirCandidates = const {},
    this.anims = const {},
    this.rev = 0,
    this.pieces = const [],
  });

  factory SkinItem.fromJson(Map<String, dynamic> j) {
    final slug = '${j['slug'] ?? j['name'] ?? ''}';
    final base = slug.isEmpty || slug == 'base';
    return SkinItem(
      slug: slug,
      name: '${j['name'] ?? slug}',
      prompt: '${j['prompt'] ?? ''}',
      south: '${j['south'] ?? j['south_thumb'] ?? j['front'] ?? ''}',
      // #306: sunucu `outfit` alaninda kiyafet SLUG'ini gonderir; eski surumde
      // rel yol gelebilir - ikisi de tasinir.
      outfitSlug: base ? '' : '${j['outfit'] ?? ''}'.split('/').last.replaceAll('.png', ''),
      outfit: '${j['outfit_rel'] ?? j['outfit'] ?? ''}',
      dirs: _parseDirs(j['dirs']),
      dirFiles: _parseDirFiles(j['dir_files']),
      dirCandidates:
          _parseDirCandidates(j, base ? 'base/dirs' : 'skins/$slug/dirs'),
      anims: _parseAnims(j['anims']),
      rev: (j['rev'] is num) ? (j['rev'] as num).toInt() : 0,
      // #313: parca listesi - duz slug ya da {slug} sozlugu gelebilir.
      pieces: j['pieces'] is List
          ? (j['pieces'] as List)
              .map((e) => e is Map ? '${e['slug'] ?? ''}' : '$e')
              .where((e) => e.isNotEmpty)
              .toList()
          : const <String>[],
    );
  }

  bool get isBase => slug.isEmpty || slug == 'base';

  /// Animasyon uclarina gonderilen `skin` degeri - base icin BOS (anims/).
  String get animSkin => isBase ? '' : slug;

  int dirsDone(List<CharacterDir> all) =>
      all.where((d) => dirs[d.id] == true).length;

  /// Kac klip tanimli (yon farketmeksizin).
  int get clipCount => anims.length;

  /// Wan videosu cikmis klip x yon / toplam.
  (int, int) get animProgress {
    var ok = 0, total = 0;
    for (final byDir in anims.values) {
      for (final s in byDir.values) {
        total++;
        if (s.wan) ok++;
      }
    }
    return (ok, total);
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
  /// #306: `skin` bos = base kumesi (`anims/`), doluysa `skins/<slug>/anims/`.
  String relFor(String dir, String clip, {String skin = ''}) {
    if (hasWan) {
      return relWan.isNotEmpty
          ? relWan
          : CharacterFlowService.versionVideoRel(dir, clip, v, skin: skin);
    }
    return relManken.isNotEmpty
        ? relManken
        : CharacterFlowService.versionVideoRel(dir, clip, v,
            manken: true, skin: skin);
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

  /// anim.webp yolu - sunucu vermezse kutuphane kuralindan (#306: skin kokü).
  String webpRel(String d, {String skin = ''}) => relWebp.isNotEmpty
      ? relWebp
      : CharacterFlowService.spriteRel(d, clip, skin: skin);

  /// Kabul edilen surumun videosu - sunucu vermezse kutuphane kuralindan.
  String acceptedRel(String d, {String skin = ''}) => relAcceptedWan.isNotEmpty
      ? relAcceptedWan
      : (accepted.isEmpty
          ? ''
          : CharacterFlowService.versionVideoRel(d, clip, accepted, skin: skin));
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
    // #301: pusula adlari - kameraya bakan = South, arka = North.
    CharacterDir('front', 'S South', 0),
    CharacterDir('front_right', 'SE South-East', 45),
    CharacterDir('right', 'E East', 90),
    CharacterDir('back_right', 'NE North-East', 135),
    CharacterDir('back', 'N North', 180),
    CharacterDir('back_left', 'NW North-West', 225),
    CharacterDir('left', 'W West', 270),
    CharacterDir('front_left', 'SW South-West', 315),
  ];

  // #301: kisa rozet = pusula kodu (S, SE, E, NE, N, NW, W, SW).
  static const _compassShort = {
    'front': 'S', 'front_right': 'SE', 'right': 'E', 'back_right': 'NE',
    'back': 'N', 'back_left': 'NW', 'left': 'W', 'front_left': 'SW',
  };
  static String shortOf(String id) =>
      _compassShort[id] ?? id.toUpperCase();

  // ------------------------------------------------------ #314 karakter turu
  /// Karakter turleri (dokuman §3c). Varsayilan `female`; sunucu `KIND_PROFILES`
  /// ile ayni id'leri kullanir. Sunucu tur listesi gonderirse (templates
  /// ucundaki `kinds`) o kullanilir, yoksa bu sabit liste.
  static const characterKinds = <Map<String, String>>[
    {'id': 'female', 'label': 'Kadin'},
    {'id': 'male', 'label': 'Erkek'},
    {'id': 'animal', 'label': 'Hayvan'},
    {'id': 'machine', 'label': 'Makine'},
  ];

  static const _kindLabels = {
    'female': 'Kadin', 'male': 'Erkek', 'animal': 'Hayvan', 'machine': 'Makine',
  };

  /// #314: tur id -> gorunen ad (bilinmeyen id oldugu gibi doner).
  static String kindLabel(String id) => _kindLabels[id] ?? id;

  /// #314: insan turleri - manken/Mixamo, hayalet manken kiyafeti ve Hot
  /// modifier yalniz bunlarda anlamlidir.
  static bool isHumanKind(String kind) => kind == 'female' || kind == 'male';

  /// #314: insan olmayan turlerin sinif listesi (dokuman §3c). Insan turleri
  /// icin sinif kaynagi `assets/karakter_secenekler.json`dir
  /// (`CharacterProfiles.classes()`), burada tekrarlanmaz.
  static const kindClasses = <String, List<String>>{
    'animal': ['pet', 'mount', 'beast'],
    'machine': ['drone', 'mech', 'turret'],
  };

  /// #314: turun sinif listesi - insan turlerinde BOS doner (cagiran taraf
  /// profil dosyasindaki listeyi kullanir).
  static List<String> classesFor(String kind) =>
      kindClasses[kind] ?? const <String>[];

  /// #314: sunucu `anim_modes` gondermezse turun varsayilan yollari.
  static List<String> defaultAnimModes(String kind) =>
      isHumanKind(kind) ? const ['i2v', 'mixamo'] : const ['i2v'];

  /// #314: Hot modifier yalniz insan turlerinin GIYSI kategorilerinde acik.
  static bool hotAllowed(String kind, String category) =>
      isHumanKind(kind) && hotCategories.contains(category);

  // ------------------------------------------------ #313 gardirop kategorileri
  /// Sunucu `outfits/templates` ucunda `categories` gondermezse kullanilan
  /// sabit sira (dokuman §3b). `other` serit ciplerinde gosterilmez ama
  /// sunucudan gelirse etiketi vardir.
  static const defaultOutfitCategories = <Map<String, String>>[
    {'id': 'set', 'label': 'Set'},
    {'id': 'top', 'label': 'Ust'},
    {'id': 'bottom', 'label': 'Alt'},
    {'id': 'shoes', 'label': 'Ayakkabi'},
    {'id': 'socks', 'label': 'Corap'},
    {'id': 'hat', 'label': 'Sapka'},
    {'id': 'headgear', 'label': 'Kafalik'},
    {'id': 'accessory', 'label': 'Aksesuar'},
    {'id': 'weapon', 'label': 'Silah'},
  ];

  /// #313: skin birlestiricide TEK secimli kategoriler (sira = giydirme sirasi).
  static const singlePieceCategories = <String>[
    'top', 'bottom', 'socks', 'shoes', 'hat', 'headgear',
  ];

  /// #313: coklu secimli kategoriler.
  static const multiPieceCategories = <String>['accessory', 'weapon'];

  /// #313: Hot modifier YALNIZ giysi kategorilerinde anlamlidir (§3b).
  static const hotCategories = <String>{
    'set', 'top', 'bottom', 'shoes', 'socks', 'hat',
  };

  static const _categoryLabels = {
    'set': 'Set', 'top': 'Ust', 'bottom': 'Alt', 'shoes': 'Ayakkabi',
    'socks': 'Corap', 'hat': 'Sapka', 'headgear': 'Kafalik',
    'accessory': 'Aksesuar', 'weapon': 'Silah', 'other': 'Diger',
  };

  /// #313: kategori id -> gorunen ad (bilinmeyen id oldugu gibi doner).
  static String categoryLabel(String id) => _categoryLabels[id] ?? id;

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

  /// Bir yonun klipleri ve surumleri. #306: `skin` bos = base kumesi.
  static Future<List<CharacterClip>> animsOf(String name, String dir,
      {String skin = ''}) async {
    final rows = _rows(await _getAny(
        '/api/character/flow/anims_of?name=${Uri.encodeQueryComponent(name)}'
        '&dir=${Uri.encodeQueryComponent(dir)}'
        '&skin=${Uri.encodeQueryComponent(skin)}'));
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
    String skin = '',                    // #306: skin baglami
  }) async {
    final r = await http
        .post(Uri.parse('${ApiService.baseUrl}/api/character/flow/prompt/expand'),
            headers: _headers,
            body: json.encode({
              'name': name,
              'dir': dir,
              'skin': skin,
              'text': text,
              'mode': mode,
            }))
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
  // #302: v = karakterin rev'i; secim degisince URL degisir, onbellek asilir.
  static String thumbUrl(String name, String rel, {int size = 360, int v = 0}) =>
      '${ApiService.baseUrl}/api/character/flow/thumb'
      '?name=${Uri.encodeQueryComponent(name)}'
      '&rel=${Uri.encodeQueryComponent(rel)}&size=$size${v > 0 ? '&v=$v' : ''}';

  static String fileUrl(String name, String rel, {int v = 0}) =>
      '${ApiService.baseUrl}/api/character/flow/file'
      '?name=${Uri.encodeQueryComponent(name)}'
      '&rel=${Uri.encodeQueryComponent(rel)}${v > 0 ? '&v=$v' : ''}';

  /// Kutuphane duzenindeki sabit yollar - ekran bunlari uydurmasin.
  // #306: layout 2 - base yonleri base/dirs/, skin yonleri skins/<slug>/dirs/.
  static String baseDirRel(String dir) => 'base/dirs/$dir.png';
  static String skinDirRel(String slug, String dir) =>
      'skins/$slug/dirs/$dir.png';

  /// Bir yonun kabul edilmis gorseli. `skin` bos ya da `base` = base yonleri.
  static String dirRel(String skin, String dir) =>
      (skin.isEmpty || skin == 'base') ? baseDirRel(dir) : skinDirRel(skin, dir);

  /// #306: animasyon koku - base `anims/`, skin `skins/<slug>/anims/`.
  static String animRoot(String skin) =>
      (skin.isEmpty || skin == 'base') ? 'anims' : 'skins/$skin/anims';

  static String versionVideoRel(String dir, String clip, String v,
          {bool manken = false, String skin = ''}) =>
      '${animRoot(skin)}/$dir/$clip/$v/${manken ? "manken" : "wan"}.mp4';
  static String spriteRel(String dir, String clip, {String skin = ''}) =>
      '${animRoot(skin)}/$dir/$clip/anim.webp';
  static String sheetRel(String dir, String clip, {String skin = ''}) =>
      '${animRoot(skin)}/$dir/$clip/sheet.png';

  // ------------------------------------------------------------- yazma
  /// #306: yeni karakter acar. BASE'I KULLANICI SECER:
  ///   - `jobId` verilirse o gorsel dogrudan base olur ve otomatik hat
  ///     (portre -> hikaye -> 7 yon, her birinden 1 adet) hemen baslar.
  ///   - Yalniz `prompt` verilirse SADECE 1 base adayi kuyruga girer, otomatik
  ///     secilmez; kullanici adayi "Base yap" ile secince hat baslar.
  ///   - Ikisi de yoksa bos karakter acilir.
  /// Op doner (aday isi ya da pipeline).
  /// #314: `kind` = karakter turu (`female` varsayilan). Sunucu prompt'lari,
  /// notr base setini ve animasyon yollarini bu alandan secer.
  static Future<String> create({
    required String name,
    required String klass,
    String prompt = '',
    String jobId = '',
    String kind = 'female',
  }) async {
    final d = await _post('/api/character/flow/create', {
      'name': name,
      'class': klass,
      'kind': kind,                     // #314
      if (prompt.isNotEmpty) 'prompt': prompt,
      if (jobId.isNotEmpty) 'job_id': jobId,
    });
    return '${d['op'] ?? ''}';
  }

  /// #306 ince ayar: KABUL EDILMIS gorseli kisa bir duzeltme cumlesiyle
  /// duzenler (edit_qwen). `target`: `base` | `portrait` | `dir:<yon>` |
  /// `skin:<slug>:<yon>`. Sonuc sunucuda otomatik kabul edilir, eski gorsel
  /// aday olarak saklanir (aday seciciden geri alinabilir). Op doner.
  static Future<String> edit(
          {required String name,
          required String target,
          required String prompt}) async =>
      '${(await _post('/api/character/flow/edit',
          {'name': name, 'target': target, 'prompt': prompt}))['op'] ?? ''}';

  /// #306: portre / hikaye / yon adimlarini yeniden kosar - op doner.
  static Future<String> pipelineRebuild(String name,
          {List<String> steps = const []}) async =>
      '${(await _post('/api/character/flow/pipeline/rebuild', {
            'name': name,
            if (steps.isNotEmpty) 'steps': steps,
          }))['op'] ?? ''}';

  /// Uretilenler'deki isleri mevcut karakterin `candidates/` klasorune kopyalar.
  static Future<int> stage({required String name, required List<String> jobIds}) async {
    final d = await _post('/api/character/flow/stage', {'name': name, 'job_ids': jobIds});
    final eklenen = d['added'];
    if (eklenen is List) return eklenen.length;
    return (d['staged'] ?? d['ok'] ?? jobIds.length) as int;
  }

  /// kind: `base` | `portrait` | `dir:<yon>` | `skin:<slug>:<yon>`
  /// #306: `base` secimi sunucuda portre/hikaye/yon adimlarini yeniden kosar,
  /// bu yuzden op DONER (bos gelirse izlenecek is yok demektir). `look` kalkti.
  static Future<String> pick(
      {required String name, required String file, required String kind}) async {
    final d = await _post('/api/character/flow/pick',
        {'name': name, 'file': file, 'kind': kind});
    return '${d['op'] ?? ''}';
  }

  /// Yon adaylari uretir (Qwen Image Edit) - op doner.
  /// #306: `dirs: ["base"]` yeni BASE adayi uretir.
  static Future<String> dirs(
          {required String name,
          required List<String> dirs,
          required int n}) async =>
      '${(await _post('/api/character/flow/dirs',
          {'name': name, 'dirs': dirs, 'n': n, 'skin': ''}))['op']}';

  /// #306: skinler - `base` her zaman ilk siradadir.
  static Future<List<SkinItem>> skins(String name) async {
    final d = await _getAny(
        '/api/character/flow/skins?name=${Uri.encodeQueryComponent(name)}');
    return _rows(d, const ['skins', 'items'])
        .map(SkinItem.fromJson)
        .where((s) => s.slug.isNotEmpty)
        .toList();
  }

  // ------------------------------------------------------ kiyafetler (#306)
  /// Kiyafet kutuphanesi - KARAKTERDEN BAGIMSIZ (`<root>/_outfits/`).
  /// #313: `category` bos = hepsi; dolu ise sunucu suzer (eski sunucu alani
  /// yok sayar, o zaman suzme istemcide yapilir).
  /// #314: `kind` bos = hepsi; dolu ise sunucu tura gore suzer (eski sunucu
  /// alani yok sayar, o zaman suzme istemcide yapilir).
  static Future<List<OutfitItem>> outfits(
      {String category = '', String kind = ''}) async {
    final d = await _getAny('/api/character/flow/outfits'
        '?category=${Uri.encodeQueryComponent(category)}'
        '&kind=${Uri.encodeQueryComponent(kind)}');
    return _rows(d, const ['outfits', 'items'])
        .map(OutfitItem.fromJson)
        .where((o) => o.slug.isNotEmpty)
        .toList();
  }

  /// Kiyafetin kucuk resmi. `v` (ms) duzenlemeden sonra onbellegi asar.
  static String outfitThumbUrl(String slug, {int size = 360, int v = 0}) =>
      '${ApiService.baseUrl}/api/character/flow/outfits/thumb'
      '?slug=${Uri.encodeQueryComponent(slug)}&size=$size${v > 0 ? '&v=$v' : ''}';

  /// Yeni kiyafet uretir (hayalet manken uzerinde onden urun fotografi) - op.
  /// #312: hazir sablonlar (id, label, group, prompt); uc yoksa bos liste.
  /// #313: sunucu `{categories, templates (category alanli), styles}` doner;
  /// eski sunucu yalniz `templates` gonderirse kategoriler sabit listeye
  /// duser ve sablonlar `set` sayilir.
  /// #314: `kind` sorguya eklenir (sunucu sablonlari tura gore suzer) ve cevap
  /// `kinds` tasiyorsa tur listesi oradan gelir; her sablon `kind` alanini
  /// tasir (yoksa `female`) - eski sunucuda suzme istemcide yapilir.
  static Future<
      ({
        List<Map<String, String>> categories,
        List<Map<String, String>> templates,
        List<Map<String, String>> kinds,
        List<String> styles,
      })> outfitTemplates({String kind = ''}) async {
    try {
      final d = await _get('/api/character/flow/outfits/templates'
          '?kind=${Uri.encodeQueryComponent(kind)}');
      final rawT = d['templates'];
      final rawC = d['categories'];
      final rawK = d['kinds'];
      final rawS = d['styles'];
      final templates = rawT is! List
          ? const <Map<String, String>>[]
          : [
              for (final e in rawT)
                if (e is Map)
                  {
                    'id': '${e['id'] ?? ''}',
                    'label': '${e['label'] ?? e['id'] ?? ''}',
                    'group': '${e['group'] ?? ''}',
                    'prompt': '${e['prompt'] ?? ''}',
                    // #313: kategorisi olmayan sablon = set (eski sunucu).
                    'category': '${e['category'] ?? ''}'.trim().isEmpty
                        ? 'set'
                        : '${e['category']}',
                    // #314: turu olmayan sablon = female (eski sunucu).
                    'kind': '${e['kind'] ?? ''}'.trim().isEmpty
                        ? 'female'
                        : '${e['kind']}',
                  }
            ];
      final categories = rawC is! List
          ? defaultOutfitCategories
          : [
              for (final e in rawC)
                if (e is Map && '${e['id'] ?? ''}'.isNotEmpty)
                  {
                    'id': '${e['id']}',
                    'label': '${e['label'] ?? categoryLabel('${e['id']}')}',
                  }
                else if (e is String && e.isNotEmpty)
                  {'id': e, 'label': categoryLabel(e)}
            ];
      // #314: sunucu tur listesi gonderirse o kullanilir, yoksa sabit liste.
      final kinds = rawK is! List
          ? characterKinds
          : [
              for (final e in rawK)
                if (e is Map && '${e['id'] ?? ''}'.isNotEmpty)
                  {
                    'id': '${e['id']}',
                    'label': '${e['label'] ?? kindLabel('${e['id']}')}',
                  }
                else if (e is String && e.isNotEmpty)
                  {'id': e, 'label': kindLabel(e)}
            ];
      return (
        categories:
            categories.isEmpty ? defaultOutfitCategories : categories,
        templates: templates,
        kinds: kinds.isEmpty ? characterKinds : kinds,
        styles: rawS is List
            ? rawS.map((e) => '$e').where((e) => e.isNotEmpty).toList()
            : const <String>[],
      );
    } catch (_) {
      return (
        categories: defaultOutfitCategories,
        templates: const <Map<String, String>>[],
        kinds: characterKinds,
        styles: const <String>[],
      );
    }
  }

  /// #312: style '' | 'hot' (seksi sablon), template = sablon id'si (opsiyonel;
  /// sablon secildiyse ad ve prompt bos birakilabilir).
  /// #313: `category` = gardirop kategorisi; sablon secildiyse sunucu
  /// kategoriyi sablondan alir.
  /// #314: `kind` = kiyafetin turu (varsayilan `female`); uretim prompt'u
  /// (hayalet manken / hayvan kostumu / robot montaj kiti) buna gore secilir.
  static Future<String> outfitCreate(String name, String prompt,
          {String style = '',
          String template = '',
          String category = '',
          String kind = 'female'}) async =>
      '${(await _post('/api/character/flow/outfits/create', {
        'name': name,
        'prompt': prompt,
        'style': style,
        'template': template,
        'category': category,
        'kind': kind,
      }))['op'] ?? ''}';

  /// Kiyafeti kisa bir duzeltme cumlesiyle duzenler (edit_qwen) - op.
  static Future<String> outfitEdit(String slug, String prompt) async =>
      '${(await _post('/api/character/flow/outfits/edit',
          {'slug': slug, 'prompt': prompt}))['op'] ?? ''}';

  static Future<void> deleteOutfit(String slug) => _delete(
      '/api/character/flow/outfit?slug=${Uri.encodeQueryComponent(slug)}',
      {'slug': slug});

  /// #306/#313: skin uret = SET ve/veya PARCA kombinasyonu + karakterin base'i.
  ///   `outfit`   set kiyafetin slug'i (bos birakilabilir)
  ///   `pieces`   ust/alt/corap/ayakkabi/sapka/kafalik/aksesuar/silah slug'lari
  ///              (sunucu kategori sirasiyla sirayla giydirir)
  ///   `skinName` skin adi; bos ise slug set ya da parcalardan turetilir
  /// Op doner: 1 (set) + parca sayisi + 7 yon.
  static Future<({String slug, String op})> skinCreate(
    String name, {
    String skinName = '',
    String outfit = '',
    List<String> pieces = const [],
  }) async {
    final d = await _post('/api/character/flow/skins/create', {
      'name': name,
      'skin_name': skinName,
      'outfit': outfit,
      'pieces': pieces,
    });
    return (
      slug: '${d['slug'] ?? (outfit.isNotEmpty ? outfit : skinName)}',
      op: '${d['op'] ?? ''}'
    );
  }

  /// #306: skinin secili yonlerini yeniden giydirir (aday uretir) - op doner.
  static Future<String> skinDirs(
          {required String name,
          required String skin,
          required List<String> dirs,
          required int n}) async =>
      '${(await _post('/api/character/flow/skins/dirs',
          {'name': name, 'skin': skin, 'dirs': dirs, 'n': n}))['op']}';

  /// #306: skini siler (`base` silinemez).
  static Future<void> deleteSkin(String name, String skin) => _delete(
      '/api/character/flow/skin?name=${Uri.encodeQueryComponent(name)}'
      '&skin=${Uri.encodeQueryComponent(skin)}',
      {'name': name, 'skin': skin});

  /// Blender manken render'i (CPU, gpu seridi almaz) - op doner.
  static Future<String> manken(
          {required String name,
          required List<String> clips,
          required List<String> dirs,
          String skin = ''}) async =>
      '${(await _post('/api/character/flow/manken',
          {'name': name, 'clips': clips, 'dirs': dirs, 'skin': skin}))['op']}';

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
    String skin = '',            // #306: bos = base skini (anims/)
  }) async =>
      '${(await _post('/api/character/flow/animate', {
        'name': name,
        'dir': dir,
        'skin': skin,
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

  /// Bir klibin o yondeki butun surumlerini siler. #306: skin baglami.
  static Future<void> deleteClip(
          {required String name,
          required String dir,
          required String clip,
          String skin = ''}) =>
      _delete('/api/character/flow/clip',
          {'name': name, 'dir': dir, 'clip': clip, 'skin': skin});

  /// Karakteri komple siler - GERI ALINAMAZ.
  static Future<void> removeCharacter(String name) =>
      _delete('/api/character/flow/character', {'name': name});

  /// Bir yonun secili gorselini ve adaylarini siler.
  /// #306: `skin` bos = base yonu (`base/dirs/`), doluysa o skinin yonu.
  /// #310: candidates/ altindaki bir base adayini siler.
  static Future<void> deleteCandidate(
          {required String name, required String file}) =>
      _delete('/api/character/flow/candidate', {'name': name, 'file': file});

  static Future<void> deleteDir(
          {required String name, required String dir, String skin = ''}) =>
      _delete('/api/character/flow/dir',
          {'name': name, 'dir': dir, 'skin': skin});

  /// Tek kabul edilen surum (yeniden kabul serbest, eski sprite silinir).
  static Future<void> accept(
          {required String name,
          required String dir,
          required String clip,
          required String version,
          String skin = ''}) =>          // #306: skin baglami
      _post('/api/character/flow/accept', {
        'name': name,
        'dir': dir,
        'clip': clip,
        'version': version,
        'skin': skin,
      });

  static Future<void> deleteVersion(
          {required String name,
          required String dir,
          required String clip,
          required String version,
          String skin = ''}) =>          // #306: skin baglami
      _delete('/api/character/flow/version', {
        'name': name,
        'dir': dir,
        'clip': clip,
        'version': version,
        'skin': skin,
      });

  /// Kabul edilmis surumlerden kare kare SAM3 -> anim.webp + sheet.png. Op doner.
  static Future<String> sprites(
          {required String name,
          required String dir,
          required List<String> clips,
          String skin = ''}) async =>    // #306: skin baglami
      '${(await _post('/api/character/flow/sprites',
          {'name': name, 'dir': dir, 'clips': clips, 'skin': skin}))['op']}';

  static Future<FlowOp> op(String opId) async =>
      FlowOp.fromJson(await _get('/api/character/flow/op/$opId'));
}
