import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

/// Jigsaw kipinin derece profilleri (Hot Jigsaw / Kid Jigsaw).
///
/// Masaustundeki Uretim Studyosu ile ayni mantik: her derecenin kendi detay
/// alanlari, secenek listeleri ve Pozitif 2 sablonu vardir. Listeler koda
/// gomulu degil, `assets/jigsaw_secenekler.json` dosyasindan okunur - o dosya
/// masaustundeki `C:\ComfyUI\scripts\jigsaw_secenekler.json` kopyasidir.
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

  /// Dropdown dolduysa Pozitif 2 sablonunun ayni seyi soyleyen parcasi
  /// gonderimden dusulur - yoksa sablon secimi eziyor ("close-up portrait"
  /// secip sablonda "full body ... composition" birakmak gibi.)
  static final Map<String, RegExp> coverage = {
    'pose': RegExp(r'\b(pose|composition)\b', caseSensitive: false),
    'hair': RegExp(r'\bhair\b', caseSensitive: false),
    'eyes': RegExp(r'\beyes?\b', caseSensitive: false),
  };

  static Future<Map<String, JigsawProfile>> load() async {
    if (_cache != null) return _cache!;
    try {
      final raw = json.decode(
          await rootBundle.loadString('assets/jigsaw_secenekler.json'))
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

  /// Kilitsiz alanlari yeniden ceker, kilitliler oldugu gibi kalir.
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

  /// Secili detaylari alan sirasiyla virgullu tek metne cevirir.
  String detailsText([Map<String, String>? v]) {
    final src = v ?? values;
    return profile.fields
        .map((f) => (src[f.key] ?? '').trim())
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
