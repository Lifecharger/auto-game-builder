import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Studio rule: no SnackBars anywhere. Short messages use AppToast (a brief
/// top toast), blocking errors use a dialog.
void main() {
  test('lib/ has no SnackBar or ScaffoldMessenger usage', () {
    final RegExp banned = RegExp(
      r'(?<![A-Za-z0-9_])(SnackBar\w*|ScaffoldMessenger\w*)(?![A-Za-z0-9_])'
      r'|showSnackBar|hideCurrentSnackBar|removeCurrentSnackBar'
      r'|clearSnackBars|snackBarTheme',
    );
    final List<String> hits = <String>[];
    final Iterable<File> files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'));
    for (final File file in files) {
      final List<String> lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i];
        final int comment = line.indexOf('//');
        final String code = comment < 0 ? line : line.substring(0, comment);
        if (banned.hasMatch(code)) {
          hits.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: 'Use AppToast or a dialog instead.');
  });
}
