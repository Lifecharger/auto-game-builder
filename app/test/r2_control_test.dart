import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_manager_mobile/services/r2_control_service.dart';

/// #381 Kovalar: sunucu govdelerinin cozulmesi ve sayacli hattin korkulugu.
///
/// Sunucu bir satirin onizlenebilir olup olmadigina karar verir; istemci bu
/// bayrak olmadan THUMB ISTEMEZ. Model katmanini burada dogruluyoruz - ekran
/// testi asagida, ag istegi acmadan.
void main() {
  group('govde cozumu', () {
    test('kova satiri rol, ikiz ve esleme tablosuyla birlikte okunuyor', () {
      final r = R2Registry.fromJson({
        'legacy_retires_on': '2026-10-20',
        'buckets': [
          {
            'name': 'icerik-kovasi',
            'files_domain': 'https://icerik.ornek.test',
            'role': 'content',
            'holds': 'paylasilan icerik',
            'twin': 'eski-kova',
            'twin_map': [
              {'bucket': 'eski-kova', 'from': 'cross-yeni/{rest...}', 'to': 'yeni/{rest...}'}
            ],
            'objects': 31,
            'bytes': 1024 * 1024,
          },
          {'name': 'eski-kova', 'role': 'legacy', 'twin': 'yeni-kova, icerik-kovasi'},
          {'name': 'ozel-kova', 'role': 'private'},
        ],
      });
      expect(r.legacyRetiresOn, '2026-10-20');
      expect(r.buckets.length, 3);
      final icerik = r.buckets.first;
      expect(icerik.isLegacy, isFalse);
      expect(icerik.twin, 'eski-kova');
      expect(icerik.twinMap.single.to, 'yeni/{rest...}');
      expect(r.buckets[1].isLegacy, isTrue);
      expect(r.buckets[2].isPrivate, isTrue);
      // Sayilmamis kova rakam uydurmaz.
      expect(r.buckets[1].objects, isNull);
    });

    test('nesne satiri onizleme bayragini sunucudan aliyor', () {
      final l = R2Listing.fromJson({
        'bucket': 'yeni-kova',
        'prefix': 'collections/a/',
        'folders': [
          {'prefix': 'collections/a/images/', 'name': 'images'}
        ],
        'objects': [
          {'key': 'collections/a/x.jpg', 'name': 'x.jpg', 'size': 300, 'preview': true},
          {'key': 'collections/a/x.mp4', 'name': 'x.mp4', 'size': 3000000},
        ],
        'truncated': true,
      });
      expect(l.folders.single.name, 'images');
      expect(l.objects.first.preview, isTrue);
      expect(l.objects.last.preview, isFalse, reason: 'bayrak yoksa onizleme istenmez');
      expect(l.truncated, isTrue);
    });

    test('baslik denetimi ve ikiz anahtari ayrinti sayfasina tasiniyor', () {
      final h = R2Head.fromJson({
        'key': 'collections/a/x.jpg',
        'size': 1234,
        'content_type': 'image/jpeg',
        'cache_control': 'public, max-age=60',
        'url': 'https://galeri.ornek.test/collections/a/x.jpg',
        'header': {
          'kind': 'asset',
          'ok': false,
          'expected': 'public, max-age=7776000, immutable',
          'actual': 'public, max-age=60'
        },
        'twin_bucket': 'eski-kova',
        'twin_key': 'collections/a/x.jpg',
      });
      expect(h.headerOk, isFalse);
      expect(h.headerExpected, 'public, max-age=7776000, immutable');
      expect(h.twinBucket, 'eski-kova');
    });

    test('silme plani iki kovadaki anahtarlari birlikte sayiyor', () {
      final p = R2DeletePlan.fromJson({
        'bucket': 'icerik-kovasi',
        'keys': ['cross-promo/a.webp', 'cross-promo/b.webp'],
        'twins': [
          {'bucket': 'eski-kova', 'keys': ['promo/a.webp', 'promo/b.webp']}
        ],
        'unmapped': [],
        'limit': 500,
      });
      expect(p.totalKeys, 4);
      expect(p.twins.single.bucket, 'eski-kova');
      expect(p.limit, 500);
    });

    test('islem ilerlemesi sinirlar icinde kaliyor', () {
      final o = R2Op.fromJson(
          {'id': 'abc', 'kind': 'r2copy', 'status': 'running', 'done': 3, 'total': 6});
      expect(o.running, isTrue);
      expect(o.progress, 0.5);
      final bitmis = R2Op.fromJson({'id': 'x', 'status': 'done', 'done': 9, 'total': 0});
      expect(bitmis.running, isFalse);
      expect(bitmis.progress, 0, reason: 'toplam yoksa cubuk tasmaz');
    });
  });

  group('boyut yazisi', () {
    test('sayilmamis kova tire gosterir, birimler buyur', () {
      expect(r2Size(null), '-');
      expect(r2Size(0), '0 B');
      expect(r2Size(999), '999 B');
      expect(r2Size(1536), '1.5 KB');
      expect(r2Size(300 * 1024), '300 KB');
      expect(r2Size(3 * 1024 * 1024), '3.0 MB');
      expect(r2Size(12 * 1024 * 1024 * 1024), '12 GB');
    });
  });

  group('ekran', () {
    testWidgets('kova karti rol ve ESKI rozetini emeklilik tarihiyle gosteriyor',
        (tester) async {
      // Ekranin kendisi ag ister; burada rozet/boyut ciziminin ayni verilerle
      // ne yazdigini dogruluyoruz - istek acilmadan.
      final b = R2Bucket.fromJson({
        'name': 'eski-kova',
        'role': 'legacy',
        'holds': 'ESKI kova',
        'twin': 'yeni-kova, icerik-kovasi',
        'objects': 4200,
        'bytes': 5 * 1024 * 1024 * 1024,
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListTile(
            title: Text('${b.name}${b.isLegacy ? '  ESKI  2026-10-20' : ''}'),
            subtitle: Text('${b.objects} nesne  ·  ${r2Size(b.bytes)}  ·  ikiz: ${b.twin}'),
          ),
        ),
      ));
      expect(find.text('eski-kova  ESKI  2026-10-20'), findsOneWidget);
      expect(find.text('4200 nesne  ·  5.0 GB  ·  ikiz: yeni-kova, icerik-kovasi'), findsOneWidget);
    });

    testWidgets('onizleme adresi kova ve anahtari kacisli tasiyor', (tester) async {
      final u = R2ControlService.thumbUrl('yeni-kova', 'collections/a b/x.jpg', size: 96);
      expect(u, contains('bucket=yeni-kova'));
      expect(u, contains('key=collections%2Fa%20b%2Fx.jpg'));
      expect(u, contains('size=96'));
    });
  });
}
