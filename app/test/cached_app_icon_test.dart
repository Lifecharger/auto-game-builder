import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:app_manager_mobile/services/cache_constants.dart';
import 'package:app_manager_mobile/services/cache_service.dart';
import 'package:app_manager_mobile/widgets/cached_app_icon.dart';

/// The dashboard used to show one app's icon on another app's row, and keep
/// showing it: a slow icon download finished after its list slot had been
/// given a different app, and the bytes were saved under the new app's id.
void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('agb_icon_test');
    Hive.init(dir.path);
    await CacheService.instance.openBoxes();
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Widget host(int appId, String path) => MaterialApp(
        home: CachedAppIcon(
          appId: appId,
          iconPath: path,
          size: 48,
          errorBuilder: (_) => const SizedBox(),
        ),
      );

  testWidgets('a late download is stored under the app it was asked for',
      (tester) async {
    final slow = Completer<void>();
    final asked = <String>[];
    final client = MockClient((req) async {
      asked.add('${req.url.path}?${req.url.query}');
      if (req.url.path.endsWith('/apps/1/icon')) {
        await slow.future;
        return http.Response.bytes([1, 1, 1], 200);
      }
      return http.Response.bytes([2, 2, 2], 200);
    });

    await tester.runAsync(() => http.runWithClient(() async {
          // Slot shows app 1; its download hangs.
          await tester.pumpWidget(host(1, r'C:\a\icon.png?v=10'));
          // Same slot is handed app 2 (the list reordered); it loads at once.
          await tester.pumpWidget(host(2, r'C:\b\icon.png?v=20'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
          // Now app 1's picture arrives.
          slow.complete();
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }, () => client));

    final cache = CacheService.instance;
    expect(cache.getAppIcon(1, r'C:\a\icon.png?v=10'), [1, 1, 1]);
    expect(cache.getAppIcon(2, r'C:\b\icon.png?v=20'), [2, 2, 2]);
    expect(asked.any((u) => u.endsWith('/apps/1/icon?v=10')), isTrue);
    expect(asked.any((u) => u.endsWith('/apps/2/icon?v=20')), isTrue);
  });

  test('icons saved by the old builds are thrown away on start', () async {
    final box = Hive.box<Uint8List>(CacheBoxes.appIcons);
    await box.put('app_7', Uint8List.fromList([9]));
    await box.put('app_7_path', Uint8List.fromList([9]));
    await CacheService.instance.setAppIcon(7, 'p', Uint8List.fromList([5]));
    await Hive.close();
    await CacheService.instance.openBoxes();
    final reopened = Hive.box<Uint8List>(CacheBoxes.appIcons);
    expect(reopened.get('app_7'), isNull);
    expect(reopened.get('app_7_path'), isNull);
    expect(CacheService.instance.getAppIcon(7, 'p'), [5]);
  });
}
