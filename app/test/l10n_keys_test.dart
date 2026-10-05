import 'dart:convert';
import 'dart:io';

import 'package:app_manager_mobile/services/locale_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every text the app shows comes from the ARB bundle, and every language the
/// app ships carries every key - a key missing from one language would fall
/// back to English there without anyone noticing.
void main() {
  Map<String, dynamic> arb(String code) =>
      jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
          as Map<String, dynamic>;

  Iterable<String> textKeys(Map<String, dynamic> bundle) =>
      bundle.keys.where((k) => !k.startsWith('@'));

  final en = arb('en');

  test('the app ships seven languages', () {
    expect(LocaleService.supportedCodes.toSet(),
        {'en', 'de', 'es', 'fr', 'ja', 'pt', 'tr'});
  });

  test('the keys of the tabs, the banner, the errors and Buckets exist', () {
    const fixed = [
      'navGenerate',
      'navGallery',
      'navFlow',
      'navQueue',
      'navDelivery',
      'navBuckets',
      'assetModeTooltip',
      'deliveryModeTooltip',
      'videoPlaybackFailed',
      'apiKeyRefusedBanner',
      'errOffline',
      'errTimeout',
      'errGatewayTimeout',
      'errGateway',
      'errServer',
      'errUnauthorized',
      'errNotFound',
      'errRateLimited',
      'errTooLarge',
      'errRejected',
      'errBadResponse',
      'errUnknown',
    ];
    final buckets = textKeys(en).where((k) => k.startsWith('buckets')).toList();
    expect(buckets.length, greaterThanOrEqualTo(60));
    for (final code in LocaleService.supportedCodes) {
      final bundle = arb(code);
      for (final key in [...fixed, ...buckets]) {
        final value = bundle[key];
        expect(value, isA<String>(), reason: '$key is missing in $code');
        expect((value as String).trim(), isNotEmpty,
            reason: '$key is empty in $code');
      }
    }
  });

  test('every language carries every key of the English bundle', () {
    final wanted = textKeys(en).toSet();
    for (final code in LocaleService.supportedCodes) {
      final have = textKeys(arb(code)).toSet();
      expect(wanted.difference(have), isEmpty,
          reason: 'keys missing in $code');
      expect(have.difference(wanted), isEmpty,
          reason: 'keys in $code that English does not have');
    }
  });

  test('a translation keeps the placeholders of the English text', () {
    final placeholder = RegExp(r'\{(\w+)\}');
    Set<String> names(String text) =>
        placeholder.allMatches(text).map((m) => m.group(1)!).toSet();
    for (final key in textKeys(en)) {
      final value = en[key];
      if (value is! String || value.contains('plural,')) continue;
      for (final code in LocaleService.supportedCodes) {
        expect(names(arb(code)[key] as String), names(value),
            reason: '$key in $code');
      }
    }
  });

  test('the new texts are really translated, not copied from English', () {
    const sample = [
      'errOffline',
      'errUnauthorized',
      'apiKeyRefusedBanner',
      'bucketsDeleteWarning',
      'bucketsEmptyFolder',
      'navQueue',
      'queueEmpty',
      'freeFlowEmpty',
      'cbnFlowBuildStarted',
      'jigsawFlowPushBody',
      'deliverySavePublish',
      'galleryEmpty',
      'genFootnote',
      'cardTplShuffled',
      'cardEmptyCollections',
      'outfitExtractBody',
      'equipSlotNoOutfits',
    ];
    for (final code in LocaleService.supportedCodes.where((c) => c != 'en')) {
      final bundle = arb(code);
      for (final key in sample) {
        expect(bundle[key], isNot(en[key]), reason: '$key in $code');
      }
    }
  });
}
