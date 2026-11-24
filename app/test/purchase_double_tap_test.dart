// Pro Jigsaw 1.0.174 TestFlight (2026-11-24): a double tap started two
// purchases of one product; StoreKit then refused every buy of it with
// `storekit_duplicate_product_object` until the app restarted. One purchase
// is now in flight at a time, and on iOS stale transactions are cleared first.

import 'dart:async';

import 'package:app_manager_mobile/services/billing_service.dart';
import 'package:app_manager_mobile/services/purchase_gate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

class _FakeStore extends InAppPurchasePlatform {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  final buys = <String>[];
  final completed = <String?>[];
  final failures = <Object>[];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: <ProductDetails>[
          for (final id in ids)
            ProductDetails(
              id: id,
              title: id,
              description: id,
              price: r'$1',
              rawPrice: 1,
              currencyCode: 'USD',
            ),
        ],
        notFoundIDs: const <String>[],
      );

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    buys.add(purchaseParam.productDetails.id);
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase.purchaseID);
  }
}

class _FakeStale implements StaleTransactionStore {
  final pending = <PurchaseDetails>[];
  final finished = <String?>[];

  @override
  Future<List<PurchaseDetails>> unfinished(String storeProductId) async => [
    for (final p in pending)
      if (p.productID == storeProductId) p,
  ];

  @override
  Future<void> finish(PurchaseDetails purchase) async {
    finished.add(purchase.purchaseID);
    pending.remove(purchase);
  }
}

PurchaseDetails _update(String id, PurchaseStatus status, {String? txId}) =>
    PurchaseDetails(
      purchaseID: txId,
      productID: id,
      status: status,
      transactionDate: null,
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: txId ?? '',
        source: 'test',
      ),
    )..pendingCompletePurchase = status == PurchaseStatus.purchased;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = _FakeStore();
  final stale = _FakeStale();
  // Read lazily: the singleton grabs the store facade when first created.
  BillingService billing() => BillingService.instance;
  const donate = 'donate_support';

  setUpAll(() async {
    // Create the plugin facade without registering a real store, then put
    // the fake behind it.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    InAppPurchase.instance;
    debugDefaultTargetPlatformOverride = null;
    InAppPurchasePlatform.instance = store;
    staleTransactionStore = stale;
    await billing().initialize();
    expect(billing().isAvailable, isTrue);
  });

  setUp(() {
    billing().purchaseGateForTesting.timeout = PurchaseGate.defaultTimeout;
    store.buys.clear();
    store.completed.clear();
    store.failures.clear();
    stale.pending.clear();
    stale.finished.clear();
  });

  Future<void> push(PurchaseDetails p) async {
    store.updates.add(<PurchaseDetails>[p]);
    await pumpEventQueue();
  }

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    billing().purchaseGateForTesting.reset();
  });

  test('a double tap starts one purchase', () async {
    await Future.wait(<Future<void>>[billing().donate(), billing().donate()]);
    await billing().donate();
    expect(store.buys, <String>[donate]);
    expect(billing().purchaseInFlight, isTrue);
  });

  test('after a cancel the next tap works', () async {
    await billing().donate();
    await push(_update(donate, PurchaseStatus.canceled));
    expect(billing().purchaseInFlight, isFalse);
    await billing().donate();
    expect(store.buys, <String>[donate, donate]);
  });

  test('after a store error the next tap works', () async {
    await billing().donate();
    // Play reports some errors without a product id.
    await push(_update('', PurchaseStatus.error));
    expect(billing().purchaseInFlight, isFalse);
    await billing().donate();
    expect(store.buys, hasLength(2));
  });

  test('a pending payment keeps the purchase in flight', () async {
    await billing().donate();
    await push(_update(donate, PurchaseStatus.pending));
    expect(billing().purchaseInFlight, isTrue);
    await billing().donate();
    expect(store.buys, <String>[donate]);
  });

  test('after a launch exception the next tap works', () async {
    store.failures.add(PlatformException(code: 'boom'));
    await expectLater(billing().donate(), throwsA(isA<PlatformException>()));
    expect(billing().purchaseInFlight, isFalse);
    await billing().donate();
    expect(store.buys, hasLength(2));
  });

  test('after a timeout the next tap works', () async {
    billing().purchaseGateForTesting.timeout = const Duration(
      milliseconds: 40,
    );
    await billing().donate();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(billing().purchaseInFlight, isFalse);
    await billing().donate();
    expect(store.buys, hasLength(2));
  });

  test('a completed donation opens the gate again', () async {
    await billing().donate();
    await push(_update(donate, PurchaseStatus.purchased, txId: 't1'));
    expect(store.completed, <String?>['t1']);
    expect(billing().purchaseInFlight, isFalse);
    await billing().donate();
    expect(store.buys, <String>[donate, donate]);
  });

  group('iOS', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

    test(
      'an unfinished donation goes through the normal path, then the buy runs',
      () async {
        stale.pending.add(
          _update(donate, PurchaseStatus.purchased, txId: '77'),
        );
        await billing().donate();
        expect(
          store.completed,
          <String?>['77'],
          reason: 'completed by the grant path, not just finished',
        );
        expect(stale.finished, isEmpty);
        expect(store.buys, <String>[donate]);
        expect(
          billing().purchaseInFlight,
          isTrue,
          reason: 'delivering the old sale keeps the new purchase in flight',
        );
      },
    );

    test('an unfinished donation completed earlier is only finished', () async {
      final old = _update(donate, PurchaseStatus.purchased, txId: '88');
      billing().purchaseGateForTesting.markGranted(old);
      stale.pending.add(old);
      await billing().donate();
      expect(store.completed, isEmpty);
      expect(stale.finished, <String?>['88']);
      expect(store.buys, <String>[donate]);
    });

    test('a duplicate-product error recovers once and retries', () async {
      store.failures.add(
        PlatformException(
          code: 'storekit_duplicate_product_object',
          details: donate,
        ),
      );
      await billing().donate();
      expect(store.buys, <String>[donate, donate]);
      expect(billing().purchaseInFlight, isTrue);
    });

    test('a second duplicate error fails and the next tap works', () async {
      for (var i = 0; i < 2; i++) {
        store.failures.add(
          PlatformException(
            code: 'storekit_duplicate_product_object',
            details: donate,
          ),
        );
      }
      await expectLater(billing().donate(), throwsA(isA<PlatformException>()));
      expect(store.buys, hasLength(2), reason: 'one retry, no more');
      expect(billing().purchaseInFlight, isFalse);
      await billing().donate();
      expect(store.buys, hasLength(3));
    });
  });
}
