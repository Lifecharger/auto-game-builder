import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_manager_mobile/widgets/flow_kind_switch.dart';

// #354: anahtar bir FittedBox icindeyken expandedInsets ile sonsuz genislige
// yayilmaya calisip HICBIR ekranda cizilmiyordu. Bu test, anahtarin
// kullanildigi uc kalipta (govde/ListView, app bar alti, Column) gercekten
// genislik kaplayip butun etiketleri gosterdigini garanti eder.
void main() {
  const items = {
    'free': 'Free',
    'jigsaw': 'Jigsaw',
    'cbn': 'CBN',
    'card': 'Kart',
    'character': 'Karakter',
  };

  // Dar telefon yuzeyi (360 dp).
  void darEkran(WidgetTester t) {
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  Widget app(Widget body, {PreferredSizeWidget? bottom}) => MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(title: const Text('t'), bottom: bottom),
            body: body,
          ),
        ),
      );

  testWidgets('ListView icinde (Uretim) tam genislik cizilir', (t) async {
    darEkran(t);
    await t.pumpWidget(app(ListView(children: [
      SizedBox(
        width: double.infinity,
        child: FlowKindSwitch(items: items, selected: 'free', onChanged: (_) {}),
      ),
    ])));
    final size = t.getSize(find.byType(SegmentedButton<String>));
    expect(size.width, greaterThan(300));
    expect(size.height, greaterThan(20));
    for (final l in items.values) {
      expect(find.text(l), findsOneWidget);
    }
  });

  testWidgets('kindSwitchBottom (Hat ekranlari) app bar altinda cizilir',
      (t) async {
    darEkran(t);
    String? secilen;
    await t.pumpWidget(app(
      const SizedBox(),
      bottom: kindSwitchBottom(
        FlowKindSwitch(
            items: items, selected: 'jigsaw', onChanged: (v) => secilen = v),
        tabs: const TabBar(tabs: [Text('a'), Text('b')]),
      ),
    ));
    final size = t.getSize(find.byType(SegmentedButton<String>));
    expect(size.width, greaterThan(300));
    await t.tap(find.text('Kart'));
    await t.pump();
    expect(secilen, 'card');
  });

  testWidgets('Column + Padding icinde (Uretilenler) cizilir', (t) async {
    darEkran(t);
    await t.pumpWidget(app(Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: FlowKindSwitch(items: items, selected: 'cbn', onChanged: (_) {}),
      ),
    ])));
    final size = t.getSize(find.byType(SegmentedButton<String>));
    expect(size.width, closeTo(360 - 24, 1));
  });

  // #355: "Jigsaw Modu" -> " Mod" kirpilinca "Jigsawu" kaliyordu.
  test('kindLabel: tablo + Mod/Modu eki kirpma', () {
    expect(kindLabel('jigsaw', 'Jigsaw Modu'), 'Jigsaw');
    expect(kindLabel('cbn', 'CBN Modu'), 'CBN');
    expect(kindLabel('card', 'Kart Modu'), 'Kart');
    expect(kindLabel('character', 'Karakter Modu'), 'Karakter');
    expect(kindLabel('free', 'Free Mod'), 'Free');
    expect(kindLabel('yeni', 'Yeni Kip Modu'), 'Yeni Kip');
    expect(kindLabel('yeni', 'Yeni Mod'), 'Yeni');
    expect(kindLabel('yeni'), 'yeni');
  });
}
