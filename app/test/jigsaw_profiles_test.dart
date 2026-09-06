import 'package:flutter_test/flutter_test.dart';

import 'package:app_manager_mobile/services/jigsaw_profiles.dart';

/// Jigsaw detay dropdown'larinin mantigi - masaustundeki Uretim Studyosu ile
/// ayni davranmasi gerekiyor: kilitli alan karisimda asla degismez, dropdown
/// dolu olan alanin sablondaki karsiligi gonderimden dusulur.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sablon =
      'a breathtakingly beautiful young woman, {}, flawless symmetrical face, '
      'perfect makeup, big expressive eyes, full lips, long silky hair, '
      'slim toned figure, confident alluring pose, shot on 85mm lens, '
      'full body vertical 9:16 composition';
  const motion =
      '{}, she moves slowly and gracefully, hair and clothing flowing '
      'naturally, cinematic';

  late Map<String, JigsawProfile> profiller;

  setUpAll(() async {
    profiller = await JigsawProfiles.load();
  });

  test('varlik dosyasi okunuyor, iki profil de dolu', () {
    expect(JigsawProfiles.loadError, isNull);
    expect(profiller.keys, containsAll(['hot', 'kid']));
    final hot = profiller['hot']!;
    final kid = profiller['kid']!;
    expect(hot.fields.map((f) => f.key),
        containsAll(['pose', 'hair', 'eyes', 'race', 'location', 'weather', 'fantasy']));
    expect(kid.fields.map((f) => f.key),
        containsAll(['subject', 'style', 'location', 'mood', 'palette']));
    for (final f in hot.fields) {
      expect(hot.optionsFor(f.key), isNotEmpty, reason: 'hot/${f.key} bos');
    }
    for (final f in kid.fields) {
      expect(kid.optionsFor(f.key), isNotEmpty, reason: 'kid/${f.key} bos');
    }
    // Kid'in kendi sablonu var, hot AGB'nin sablonunu kullanir.
    expect(kid.template, isNotEmpty);
    expect(kid.negative, contains('scary'));
    expect(hot.template, isEmpty);
  });

  test('kilitli alan 200 cekiliste hic degismiyor', () {
    final d = DetailState(profiller['hot']!);
    d.values['hair'] = 'SABIT SAC';
    d.locks['hair'] = true;
    d.values['race'] = 'SABIT IRK';
    d.locks['race'] = true;

    final pozlar = <String>{};
    for (var i = 0; i < 200; i++) {
      final r = d.roll();
      expect(r['hair'], 'SABIT SAC');
      expect(r['race'], 'SABIT IRK');
      pozlar.add(r['pose']!);
    }
    expect(pozlar.length, greaterThan(5), reason: 'kilitsiz alan cesitlenmeli');
  });

  test('bos + kilitli alan dolmuyor', () {
    final d = DetailState(profiller['hot']!);
    d.locks['fantasy'] = true;
    for (var i = 0; i < 100; i++) {
      expect(d.roll()['fantasy'], '');
    }
  });

  test('Temizle kilitliye dokunmuyor', () {
    final d = DetailState(profiller['hot']!);
    d.apply(d.roll());
    d.locks['eyes'] = true;
    final goz = d.valueOf('eyes');
    d.clearUnlocked();
    expect(d.valueOf('eyes'), goz);
    expect(d.valueOf('pose'), '');
  });

  test('detaylar konu prompt\'unun arkasina virgulle ekleniyor', () {
    final d = DetailState(profiller['hot']!);
    d.values['pose'] = 'close-up portrait';
    d.values['hair'] = 'blonde hair';
    expect(d.promptWith('police officer'),
        'police officer, close-up portrait, blonde hair');
    expect(d.promptWith(''), 'close-up portrait, blonde hair');
  });

  test('dolu dropdown sablondaki karsiligini dusuruyor', () {
    final d = DetailState(profiller['hot']!);

    // hicbiri secili degilken sablon aynen gider
    expect(d.templateFor(sablon, isVideo: false), sablon);

    d.values['pose'] = 'close-up portrait';
    var out = d.templateFor(sablon, isVideo: false);
    expect(out, isNot(contains('confident alluring pose')));
    expect(out, isNot(contains('full body vertical 9:16 composition')));
    expect(out, contains('shot on 85mm lens'), reason: 'poz sanip silmemeli');
    expect(out, contains('long silky hair'));

    d.values['hair'] = 'blonde hair';
    d.values['eyes'] = 'green eyes';
    out = d.templateFor(sablon, isVideo: false);
    expect(out, isNot(contains('long silky hair')));
    expect(out, isNot(contains('big expressive eyes')));
    expect(out, contains('flawless symmetrical face'));
    expect(out, contains('{}'), reason: 'prompt yer tutucusu korunmali');
  });

  test('video sablonuna dokunulmuyor', () {
    final d = DetailState(profiller['hot']!);
    d.apply(d.roll());
    expect(d.templateFor(motion, isVideo: true), motion);
  });

  test('rastgele uretim her is icin ayri cekilis veriyor', () {
    final d = DetailState(profiller['hot']!);
    d.values['hair'] = 'platinum blonde hair';
    d.locks['hair'] = true;
    final promptlar = <String>{};
    for (var i = 0; i < 40; i++) {
      final v = d.roll();
      final p = d.promptWith('nurse', v);
      expect(p, contains('platinum blonde hair'));
      promptlar.add(p);
    }
    expect(promptlar.length, greaterThan(30), reason: 'isler cesitlenmeli');
  });

  test('kid profili kendi alanlariyla calisiyor', () {
    final d = DetailState(profiller['kid']!);
    d.apply(d.roll());
    final p = d.promptWith('');
    expect(p, isNotEmpty);
    expect(d.profile.fields.length, 5);
    // Hot'a ozgu alanlar kid'de yok
    expect(d.values.containsKey('hair'), isFalse);
  });
}
