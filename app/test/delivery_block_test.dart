import 'package:flutter_test/flutter_test.dart';

import 'package:app_manager_mobile/services/delivery_service.dart';

/// #385: engel listesinin ve normalizer durumunun ayristirilmasi.
/// Kurallar zaten worker testlerinde; burada istemcinin worker govdesini dogru
/// okudugu ve GERI AYNI SEKILDE yazdigi sinaniyor - sekil kayarsa engel
/// worker'a bos gider ve kimse farketmez.
void main() {
  group('DeliveryBlock', () {
    const govde = {
      'updated': 1700,
      'global': {
        'pictures': ['generic/1.jpg'],
        'collections': ['ice_queen'],
        'cards': <String>[],
        'decks': <String>[],
        'hostLevels': <String>[],
      },
      'apps': {
        'com.lifecharger.hotidle': {
          'pictures': ['generic/2.jpg'],
          'collections': <String>[],
          'cards': <String>[],
          'decks': <String>[],
          'hostLevels': <String>[],
        },
      },
      'lists': ['pictures', 'collections'],
    };

    test('worker govdesi okunur ve global + uygulama BIRLESIMI sorgulanir', () {
      final b = DeliveryBlock.fromJson(govde);
      expect(b.updated, 1700);
      expect(b.lists, ['pictures', 'collections']);
      // Global engel her uygulamada gecerlidir.
      expect(b.isBlocked('', 'pictures', 'generic/1.jpg'), isTrue);
      expect(b.isBlocked('com.lifecharger.hotidle', 'pictures', 'generic/1.jpg'), isTrue);
      // Uygulamaya ozel engel yalniz o uygulamada.
      expect(b.isBlocked('com.lifecharger.hotidle', 'pictures', 'generic/2.jpg'), isTrue);
      expect(b.isBlocked('', 'pictures', 'generic/2.jpg'), isFalse);
      expect(b.isBlocked('com.lifecharger.hotjigsaw', 'pictures', 'generic/2.jpg'), isFalse);
      expect(b.count(''), 2);
      expect(b.count('com.lifecharger.hotidle'), 1);
    });

    test('ac/kapa ve toJson worker\'in bekledigi sekli verir', () {
      final b = DeliveryBlock.fromJson(govde);
      b.toggle('', 'collections', 'ice_queen', false);
      b.toggle('com.lifecharger.hotcharm', 'pictures', 'miko/3.jpg', true);
      final j = b.toJson();
      expect((j['global'] as Map)['collections'], isEmpty);
      expect((j['global'] as Map)['pictures'], ['generic/1.jpg']);
      expect(((j['apps'] as Map)['com.lifecharger.hotcharm'] as Map)['pictures'], ['miko/3.jpg']);
      // `updated` damgasini worker koyar - istemci ASLA gondermez.
      expect(j.containsKey('updated'), isFalse);
    });

    test('bos kalan uygulama kaydi worker\'a gitmez', () {
      final b = DeliveryBlock.fromJson(govde);
      b.toggle('com.lifecharger.hotidle', 'pictures', 'generic/2.jpg', false);
      expect((b.toJson()['apps'] as Map).containsKey('com.lifecharger.hotidle'), isFalse);
    });

    test('kopya bagimsizdir - Kaydet basilmadan sunucu degeri bozulmaz', () {
      final b = DeliveryBlock.fromJson(govde);
      final k = b.copy();
      k.toggle('', 'collections', 'ice_queen', false);
      expect(b.isBlocked('', 'collections', 'ice_queen'), isTrue);
      expect(k.isBlocked('', 'collections', 'ice_queen'), isFalse);
    });

    test('eksik / bozuk govde bos listeye duser, patlamaz', () {
      final b = DeliveryBlock.fromJson(null);
      expect(b.updated, 0);
      expect(b.count(''), 0);
      expect(DeliveryBlock.fromJson({'global': 'yok', 'apps': 5}).count(''), 0);
    });
  });

  group('Genel bakis', () {
    test('overview govdesindeki engel listesi de okunur', () {
      final o = DeliveryOverview.fromJson({
        'pool': 'cards',
        'worker': 'https://w',
        'rules': {'updated': 9, 'default': {}, 'apps': {}},
        'values': {'total': 4, 'tagged': 3, 'untagged': 1, 'fields': {}, 'order': [], 'labels': {}},
        'apps': [
          {'package': 'com.x', 'name': 'X', 'served': 2, 'total': 4, 'blocks': 1},
        ],
        'block': {'updated': 11, 'global': {'decks': ['gothic_vampire']}, 'apps': {}},
      });
      expect(o.block, isNotNull);
      expect(o.block!.updated, 11);
      expect(o.block!.isBlocked('', 'decks', 'gothic_vampire'), isTrue);
      expect(o.apps.single.served, 2);
    });
  });

  group('NormalizePool', () {
    test('calisan op ilerlemesi ve son rapor ozeti okunur', () {
      final p = NormalizePool.fromJson('gallery-hot', {
        'label': 'Jigsaw koleksiyonlari',
        'bucket': 'gallery-hot',
        'index': 'EXIF (jpg) + KV serve_index_<collection>',
        'running': true,
        'op': {'id': 'abc123', 'done': 40, 'total': 2140, 'message': 'Generic etiketleniyor'},
        'last': {'status': 'completed', 'total': 54, 'valid': 10, 'tagged': 43, 'failed': 1},
      });
      expect(p.pool, 'gallery-hot');
      expect(p.running, isTrue);
      expect(p.opId, 'abc123');
      expect(p.done, 40);
      expect(p.total, 2140);
      expect(p.index, contains('serve_index'));
      expect(p.summary, contains('43 etiketlendi'));
      expect(p.summary, contains('1 basarisiz'));
    });

    test('hic calismamis havuz ve deneme kosusu ayirt edilir', () {
      expect(NormalizePool.fromJson('cards', {'last': null}).summary, 'hic calismadi');
      final deneme = NormalizePool.fromJson('cards', {
        'last': {'status': 'completed', 'dry_run': true, 'total': 3, 'valid': 0, 'tagged': 0, 'failed': 0},
      });
      expect(deneme.summary, contains('(deneme)'));
      expect(deneme.running, isFalse);
    });
  });

  group('DeliveryCatalogItem', () {
    test('engel tarayicisinin satiri ve ogeleri okunur', () {
      final i = DeliveryCatalogItem.fromJson({
        'id': 'gothic_vampire',
        'name': 'Gothic Vampire',
        'kind': 'deck',
        'count': 2,
        'tagged': 1,
        'cover': 'https://c/thumb.webp',
        'images': [
          {'id': 'gothic_vampire_a', 'name': 'a', 'cover': 'https://c/a.webp', 'tagged': true},
          {'id': 'gothic_vampire_k', 'name': 'k', 'tagged': false},
        ],
      });
      expect(i.id, 'gothic_vampire');
      expect(i.count, 2);
      expect(i.tagged, 1);
      expect(i.images.map((e) => e.id), ['gothic_vampire_a', 'gothic_vampire_k']);
      expect(i.images.last.cover, isNull);
      expect(i.images.last.tagged, isFalse, reason: 'etiketsiz oge isaretlenmeli');
      // gallery-hot kapaklarini `url` alaninda verir - ikisi de kabul edilir.
      expect(DeliveryCatalogEntry.fromJson({'name': '1.jpg', 'url': 'https://g/1.jpg'}).cover,
          'https://g/1.jpg');
      expect(DeliveryCatalogEntry.fromJson({'name': '1.jpg'}).id, '1.jpg');
    });
  });
}
