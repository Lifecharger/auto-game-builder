import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_manager_mobile/widgets/bottom_inset.dart';

/// Gorev #266: tam ekran goruntuleyicideki "Havuza ekle" dugmesi sistem
/// gezinme cubugunun altinda kaliyordu. Sabit alt bosluk 3 tuslu cubugun
/// yuksekligini karsilamiyordu.
void main() {
  const navCubugu = 48.0;   // 3 tuslu Android gezinme cubugu

  /// Test yuzeyinin yuksekligi sabit degil; beklentileri ondan turetiyoruz.
  Future<(Rect, double)> dugmeAlani(WidgetTester tester, Widget govde) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: tester.view.physicalSize / tester.view.devicePixelRatio,
          viewPadding: const EdgeInsets.only(bottom: navCubugu),
          padding: const EdgeInsets.only(bottom: navCubugu),
        ),
        child: Scaffold(backgroundColor: Colors.black, body: govde),
      ),
    ));
    final ekran = tester.getSize(find.byType(Scaffold)).height;
    return (tester.getRect(find.byKey(const ValueKey('dugme'))), ekran);
  }

  Widget altCubuk({required EdgeInsets Function(BuildContext) bosluk}) =>
      Builder(
        builder: (c) => Column(
          children: [
            const Expanded(child: SizedBox.expand()),
            Container(
              width: double.infinity,
              color: Colors.black,
              padding: bosluk(c),
              child: const SizedBox(
                key: ValueKey('dugme'), height: 40, width: double.infinity),
            ),
          ],
        ),
      );

  testWidgets('sabit alt bosluk dugmeyi gezinme cubugunun altinda birakir '
      '(eski davranis)', (tester) async {
    final (r, ekran) = await dugmeAlani(
        tester, altCubuk(bosluk: (_) => const EdgeInsets.fromLTRB(16, 10, 16, 20)));
    expect(r.bottom, ekran - 20);
    expect(r.bottom, greaterThan(ekran - navCubugu),
        reason: 'eski hatanin tekrar uretilebildigini gosterir');
  });

  testWidgets('bottomSafePadding dugmeyi gezinme cubugunun ustune tasir',
      (tester) async {
    final (r, ekran) = await dugmeAlani(
        tester,
        altCubuk(
            bosluk: (c) => bottomSafePadding(c,
                left: 16, top: 10, right: 16, bottom: 20)));
    expect(r.bottom, ekran - (20 + navCubugu));
    expect(r.bottom, lessThanOrEqualTo(ekran - navCubugu),
        reason: 'dugmenin alt kenari gezinme cubuguna girmemeli');
  });

  testWidgets('gezinme cubugu yokken fazladan bosluk eklenmez', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
            size: tester.view.physicalSize / tester.view.devicePixelRatio),
        child: Scaffold(
          body: altCubuk(
              bosluk: (c) => bottomSafePadding(c,
                  left: 16, top: 10, right: 16, bottom: 20)),
        ),
      ),
    ));
    final ekran = tester.getSize(find.byType(Scaffold)).height;
    final r = tester.getRect(find.byKey(const ValueKey('dugme')));
    expect(r.bottom, ekran - 20,
        reason: 'inset 0 iken taban bosluk aynen kalmali');
  });

  testWidgets('systemBottomInset viewPadding.bottom degerini verir',
      (tester) async {
    late double olculen;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          viewPadding: EdgeInsets.only(bottom: navCubugu),
        ),
        child: Builder(builder: (c) {
          olculen = systemBottomInset(c);
          return const SizedBox();
        }),
      ),
    ));
    expect(olculen, navCubugu);
  });
}
