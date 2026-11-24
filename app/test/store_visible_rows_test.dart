import 'package:flutter_test/flutter_test.dart';
import 'package:app_manager_mobile/models/store_status.dart';

StoreEntry p(String t, String v, int c, [String s = 'completed']) =>
    StoreEntry(track: t, version: v, code: c, status: s);
StoreEntry a(String t, String v, String b, [String s = '']) =>
    StoreEntry(track: t, version: v, build: b, status: s);

void main() {
  test('Play: older test tracks under production are hidden', () {
    final rows = visibleEntries('play', [
      p('production', '1.0.172', 172),
      p('alpha', '1.0.167', 167),
      p('internal', '1.0.168', 168),
    ]);
    expect(rows.map((e) => e.track), ['production']);
  });

  test('Play: a newer test build shows under production; halted drops', () {
    final rows = visibleEntries('play', [
      p('production', '1.0.111', 111),
      p('alpha', '1.0.115', 115, 'halted'),
      p('internal', '1.0.114', 114),
    ]);
    expect(rows.map((e) => '${e.track} ${e.version}'), ['production 1.0.111', 'internal 1.0.114']);
  });

  test('Apple: only the newest TestFlight build; the prepared version is no row', () {
    final rows = visibleEntries('apple', [
      a('testflight', '1.0.112', '113'),
      a('testflight', '1.0.111', '112'),
      a('prepare', '1.0.111', '112', 'PREPARE_FOR_SUBMISSION'),
      a('testflight', '1.0.108', '109'),
      a('testflight', '1.0.108', '108'),
    ]);
    expect(rows.map((e) => '${e.track} ${e.label}'),
        ['testflight 1.0.112 (113)']);
  });

  test('Apple: live stays, older TestFlight and the prepared version hide', () {
    final rows = visibleEntries('apple', [
      a('live', '1.0.5', '6', 'READY_FOR_SALE'),
      a('prepare', '1.0.5', '6'),
      a('testflight', '1.0.4', '5'),
    ]);
    expect(rows.map((e) => e.track), ['live']);
  });
}
