import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import 'jigsaw_flow_service.dart' show JigsawFlowService;

/// Jigsaw kipinin derece profilleri (Hot Jigsaw / Kid Jigsaw).
///
/// Masaustundeki Uretim Studyosu ile ayni mantik: her derecenin kendi detay
/// alanlari, secenek listeleri ve Pozitif 2 sablonu vardir. Listeler koda
/// gomulu degil, `assets/jigsaw_secenekler.json` dosyasindan okunur - o dosya
/// masaustu studyosunun secenek dosyasinin kopyasidir (yolu sunucunun
/// settings.json'inda `jigsaw.options_file` altinda tutulur).
class JigsawField {
  final String key;
  final String label;
  const JigsawField(this.key, this.label);
}

class JigsawProfile {
  final String id;                       // 'hot' | 'kid'
  final String label;                    // 'Hot Jigsaw' | 'Kid Jigsaw'
  final List<JigsawField> fields;
  final Map<String, List<String>> options;
  final String template;                 // bossa AGB'nin kip sablonu kullanilir
  final String negative;

  const JigsawProfile({
    required this.id,
    required this.label,
    required this.fields,
    required this.options,
    required this.template,
    required this.negative,
  });

  List<String> optionsFor(String key) => options[key] ?? const [];
}

class JigsawProfiles {
  /// Derece kimlikleri ve ekran adlari - masaustundeki RATINGS ile ayni.
  static const ratings = <String, String>{
    'hot': 'Hot Jigsaw',
    'kid': 'Kid Jigsaw',
  };

  static Map<String, JigsawProfile>? _cache;
  static String? loadError;

  /// Birlikte tek ifade olmasi gereken alan ciftleri: renk + kiyafet
  /// "pastel pink pleated miniskirt" olarak gider, "pastel pink, pleated
  /// miniskirt" olarak degil (virgul modelin rengi baska seye baglamasina
  /// yol aciyor).
  static const mergePairs = <(String, String)>[
    ('outfit_color', 'outfit'),
  ];

  /// Ayni dosya bicimini kullanan baska bir kip (CBN) icin ortak yukleyici.
  static Future<Map<String, JigsawProfile>> loadFrom(
      String asset, Map<String, String> ratings) async {
    final raw = json.decode(await rootBundle.loadString(asset)) as Map<String, dynamic>;
    final out = <String, JigsawProfile>{};
    ratings.forEach((id, label) {
      final blok = (raw[id] as Map<String, dynamic>?) ?? const {};
      final fields = ((blok['alanlar'] as List?) ?? const [])
          .whereType<List>()
          .where((a) => a.length >= 2)
          .map((a) => JigsawField('${a[0]}', '${a[1]}'))
          .toList();
      final secenekler = (blok['secenekler'] as Map<String, dynamic>?) ?? const {};
      final opts = <String, List<String>>{
        for (final f in fields)
          f.key: ((secenekler[f.key] as List?) ?? const [])
              .map((e) => '$e'.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
      };
      out[id] = JigsawProfile(
          id: id, label: label, fields: fields, options: opts,
          template: '${blok['sablon'] ?? ''}', negative: '${blok['negatif'] ?? ''}');
    });
    return out;
  }

  /// Dropdown dolduysa Pozitif 2 sablonunun ayni seyi soyleyen parcasi
  /// gonderimden dusulur - yoksa sablon secimi eziyor ("close-up portrait"
  /// secip sablonda "full body ... composition" birakmak gibi.)
  static final Map<String, RegExp> coverage = {
    'pose': RegExp(r'\b(pose|composition)\b', caseSensitive: false),
    'hair': RegExp(r'\bhair\b', caseSensitive: false),
    'hairstyle': RegExp(r'\bhair\b', caseSensitive: false),
    // Aci secilince sablonun "full body ... composition" parcasi dusmeli,
    // yoksa "close-up portrait" ile "full body" ayni prompta biner.
    'angle': RegExp(r'\b(shot|angle|composition|framing|view)\b', caseSensitive: false),
    'outfit': RegExp(r'\b(outfit|dress|clothing|wearing|lingerie|bikini|nude|naked)\b',
        caseSensitive: false),
    'eyes': RegExp(r'\beyes?\b', caseSensitive: false),
  };

  static Future<Map<String, JigsawProfile>> load() async {
    if (_cache != null) return _cache!;
    try {
      // #353: once SUNUCU (C:/ComfyUI/scripts/jigsaw_secenekler.json - studyo ve
      // sunucu karistiricisiyla ayni dosya); alinamazsa gomulu kopya. Boylece
      // listeye eklenen secenek build beklemeden telefona gelir.
      final sunucu = await JigsawFlowService.profilesRaw();
      final raw = sunucu ??
          json.decode(await rootBundle.loadString('assets/jigsaw_secenekler.json'))
              as Map<String, dynamic>;
      final out = <String, JigsawProfile>{};
      final eksik = <String>[];
      ratings.forEach((id, label) {
        final blok = (raw[id] as Map<String, dynamic>?) ?? const {};
        final fields = ((blok['alanlar'] as List?) ?? const [])
            .whereType<List>()
            .where((a) => a.length >= 2)
            .map((a) => JigsawField('${a[0]}', '${a[1]}'))
            .toList();
        final secenekler = (blok['secenekler'] as Map<String, dynamic>?) ?? const {};
        final opts = <String, List<String>>{};
        for (final f in fields) {
          final list = ((secenekler[f.key] as List?) ?? const [])
              .map((e) => '$e'.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          opts[f.key] = list;
          if (list.isEmpty) eksik.add('$label/${f.key}');
        }
        if (fields.isEmpty) eksik.add('$label (alan tanimi yok)');
        out[id] = JigsawProfile(
          id: id,
          label: label,
          fields: fields,
          options: opts,
          template: '${blok['sablon'] ?? ''}',
          negative: '${blok['negatif'] ?? ''}',
        );
      });
      loadError = eksik.isEmpty ? null : 'secenek dosyasinda eksik: ${eksik.join(", ")}';
      _cache = out;
      return out;
    } catch (e) {
      // Sessizce bos gecmiyoruz: ekran bunu kullaniciya gosterir.
      loadError = 'secenek dosyasi okunamadi: $e';
      _cache = {
        for (final e in ratings.entries)
          e.key: JigsawProfile(
              id: e.key, label: e.value, fields: const [],
              options: const {}, template: '', negative: '')
      };
      return _cache!;
    }
  }
}

/// Bir derecenin ekrandaki secim + kilit durumu.
class DetailState {
  final JigsawProfile profile;
  final Map<String, String> values = {};
  final Map<String, bool> locks = {};
  final _rnd = Random();

  DetailState(this.profile) {
    for (final f in profile.fields) {
      values[f.key] = '';
      locks[f.key] = false;
    }
  }

  bool isLocked(String key) => locks[key] ?? false;
  String valueOf(String key) => values[key] ?? '';

  /// Kilitli alanlarin adlari (sunucu karistiricisina gider).
  List<String> get lockedKeys =>
      [for (final f in profile.fields) if (isLocked(f.key)) f.key];

  /// #353: TUTARLI karistirma - sunucu (`/api/jigsaw/roll`) etiket/kurallarla
  /// celismeyen secim doner; sunucu eskiyse/ulasilamazsa yerel `roll()`.
  Future<List<Map<String, String>>> rollServer({int n = 1}) async {
    try {
      final r = await JigsawFlowService.roll(
          rating: profile.id,
          values: Map<String, String>.from(values),
          locks: lockedKeys,
          n: n);
      if (r.length == n) return r;
    } catch (_) {
      // yerel karistirmaya dus
    }
    return [for (var i = 0; i < n; i++) roll()];
  }

  /// Kilitsiz alanlari yeniden ceker, kilitliler oldugu gibi kalir.
  /// (Yerel yedek - sunucu ulasilamazsa; kural gozetmez.)
  Map<String, String> roll() {
    final out = <String, String>{};
    for (final f in profile.fields) {
      final pool = profile.optionsFor(f.key);
      out[f.key] = (isLocked(f.key) || pool.isEmpty)
          ? valueOf(f.key)
          : pool[_rnd.nextInt(pool.length)];
    }
    return out;
  }

  void apply(Map<String, String> v) {
    for (final f in profile.fields) {
      values[f.key] = v[f.key] ?? '';
    }
  }

  /// Kilitlilere dokunmadan gerisini bosaltir.
  void clearUnlocked() {
    for (final f in profile.fields) {
      if (!isLocked(f.key)) values[f.key] = '';
    }
  }

  bool get hasAnyOption =>
      profile.fields.any((f) => profile.optionsFor(f.key).isNotEmpty);

  /// Secili detaylari alan sirasiyla virgullu tek metne cevirir; birlesik
  /// ciftler (kiyafet rengi + kiyafet) tek ifade olur.
  String detailsText([Map<String, String>? v]) {
    final src = v ?? values;
    final merged = <String, String>{};
    final skip = <String>{};
    for (final (a, b) in JigsawProfiles.mergePairs) {
      final va = (src[a] ?? '').trim(), vb = (src[b] ?? '').trim();
      if (va.isNotEmpty && vb.isNotEmpty) {
        merged[b] = '$va $vb';
        skip.add(a);
      }
    }
    return profile.fields
        .where((f) => !skip.contains(f.key))
        .map((f) => merged[f.key] ?? (src[f.key] ?? '').trim())
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  /// Konu prompt'u + detaylar.
  String promptWith(String konu, [Map<String, String>? v]) {
    final det = detailsText(v);
    konu = konu.trim();
    if (det.isEmpty) return konu;
    return konu.isEmpty ? det : '$konu, $det';
  }

  /// Sablondan, dropdown'un zaten soyledigi parcalari atar.
  ///
  /// Yalniz durgun gorsel sablonuna uygulanir - video sablonundaki "hair and
  /// clothing flowing naturally" bir hareket tarifi, sac rengiyle ilgisi yok.
  String templateFor(String p2, {required bool isVideo, Map<String, String>? v}) {
    p2 = p2.trim();
    if (p2.isEmpty || isVideo) return p2;
    final src = v ?? values;
    final pats = <RegExp>[];
    JigsawProfiles.coverage.forEach((key, rx) {
      if ((src[key] ?? '').trim().isNotEmpty) pats.add(rx);
    });
    if (pats.isEmpty) return p2;
    return p2
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !pats.any((rx) => rx.hasMatch(s)))
        .join(', ');
  }
}

/// CBN kipinin derece profilleri (Hot CBN / Kid CBN) - `assets/cbn_secenekler.json`
/// (sunucudaki `server/config/cbn_options.json` ile ayni dosya).
class CbnProfiles {
  static const ratings = <String, String>{
    'hot': 'Hot CBN',
    'kid': 'Kid CBN',
  };

  static Map<String, JigsawProfile>? _cache;
  static String? loadError;

  static Future<Map<String, JigsawProfile>> load() async {
    if (_cache != null) return _cache!;
    try {
      _cache = await JigsawProfiles.loadFrom('assets/cbn_secenekler.json', ratings);
      loadError = null;
    } catch (e) {
      loadError = 'CBN secenek dosyasi okunamadi: $e';
      _cache = {
        for (final e in ratings.entries)
          e.key: JigsawProfile(
              id: e.key, label: e.value, fields: const [],
              options: const {}, template: '', negative: '')
      };
    }
    return _cache!;
  }
}

/// Karakter kipinin profili - `assets/karakter_secenekler.json` (sunucudaki
/// `server/config/character_options.json` ile ayni dosya).
///
/// Jigsaw/CBN'den farki: derece (hot/kid) yoktur, tek profil vardir. Alanlar
/// sinif, set, sac, goz, ten, vucut, kostum ve aksesuardir; sinif listesi
/// ayrica "Karakter yap" penceresinde de kullanilir.
class CharacterProfiles {
  static const id = 'character';
  static const ratings = <String, String>{id: 'Karakter'};

  static Map<String, JigsawProfile>? _cache;
  static String? loadError;

  static Future<Map<String, JigsawProfile>> load() async {
    if (_cache != null) return _cache!;
    try {
      _cache = await JigsawProfiles.loadFrom('assets/karakter_secenekler.json', ratings);
      loadError = null;
    } catch (e) {
      loadError = 'Karakter secenek dosyasi okunamadi: $e';
      _cache = {
        id: const JigsawProfile(
            id: id, label: 'Karakter', fields: [],
            options: {}, template: '', negative: '')
      };
    }
    return _cache!;
  }

  /// "Karakter yap" penceresindeki sinif listesi. Dosya okunmadiysa bos doner
  /// ve pencere serbest metin alanina duser.
  static Future<List<String>> classes() async =>
      (await load())[id]?.optionsFor('class') ?? const [];
}

/// #323 Kart kipinin profili - `assets/kart_secenekler.json` (sunucudaki
/// `server/config/card_options.json` ile ayni dosya).
///
/// Karakter kipi gibi derecesi (hot/kid) YOKTUR, tek profil vardir. Alanlar
/// tema, ten, sac, kiyafet, poz ve jesttir (design/kart_modu.md §4); jest
/// listesi ayrica Kart hattindaki animasyon penceresinde kullanilir.
class CardProfiles {
  static const id = 'card';
  static const ratings = <String, String>{id: 'Kart Modu'};

  static Map<String, JigsawProfile>? _cache;
  static String? loadError;

  static Future<Map<String, JigsawProfile>> load() async {
    if (_cache != null) return _cache!;
    try {
      _cache = await JigsawProfiles.loadFrom('assets/kart_secenekler.json', ratings);
      loadError = null;
    } catch (e) {
      loadError = 'Kart secenek dosyasi okunamadi: $e';
      _cache = {
        id: const JigsawProfile(
            id: id, label: 'Kart Modu', fields: [],
            options: {}, template: '', negative: '')
      };
    }
    return _cache!;
  }

  /// Jest listesi (idle / wink / kiss / hair / pose). Dosya okunmadiysa bos
  /// doner ve cagiran taraf `CardFlowService.defaultGestures`'a duser.
  static Future<List<String>> gestures() async =>
      (await load())[id]?.optionsFor('gesture') ?? const [];
}
