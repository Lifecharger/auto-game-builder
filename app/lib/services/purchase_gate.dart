// One store purchase at a time, and recovery from App Store transactions left
// unfinished.
//
// Pro Jigsaw 1.0.174 on TestFlight (2026-11-24): a double tap started two
// purchases of coins_100 three seconds apart. StoreKit then refused every
// later buy of that product with `storekit_duplicate_product_object` until
// the app was restarted. [PurchaseGate] refuses a second buy while one is in
// flight, and on iOS clears what blocks the product before it buys.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

/// True when purchases go through StoreKit (the App Store).
bool get purchasesUseStoreKit =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// True for the StoreKit error a buy raises while a transaction for the same
/// product is still unfinished.
bool isDuplicateProductError(Object error) =>
    error is PlatformException &&
    error.code == 'storekit_duplicate_product_object';

/// The StoreKit transactions left unfinished for a product.
abstract class StaleTransactionStore {
  /// Unfinished transactions for [storeProductId], as purchase details.
  Future<List<PurchaseDetails>> unfinished(String storeProductId);

  /// Finishes [purchase] with the store without granting anything.
  Future<void> finish(PurchaseDetails purchase);
}

/// StoreKit 2 (the plugin default): `Transaction.unfinished` and `finish`.
class StoreKitStaleTransactions implements StaleTransactionStore {
  const StoreKitStaleTransactions();

  @override
  Future<List<PurchaseDetails>> unfinished(String storeProductId) async {
    final all = await SK2Transaction.unfinishedTransactions();
    return <PurchaseDetails>[
      for (final t in all)
        if (t.productId == storeProductId)
          SK2PurchaseDetails(
            productID: t.productId,
            purchaseID: t.id,
            verificationData: PurchaseVerificationData(
              localVerificationData: t.jsonRepresentation ?? '',
              serverVerificationData: t.receiptData ?? '',
              source: kIAPSource,
            ),
            transactionDate: t.purchaseDate,
            // Transaction.unfinished only holds verified sales.
            status: PurchaseStatus.purchased,
          ),
    ];
  }

  @override
  Future<void> finish(PurchaseDetails purchase) async {
    final id = int.tryParse(purchase.purchaseID ?? '');
    if (id == null || id <= 0) return;
    await SK2Transaction.finish(id);
  }
}

/// Where [PurchaseGate] reads unfinished StoreKit transactions. Tests swap in
/// a fake.
StaleTransactionStore staleTransactionStore = const StoreKitStaleTransactions();

/// Allows one store purchase at a time.
///
/// A purchase is in flight from [tryBegin] until the app calls [end] on a
/// terminal store answer (purchased and granted, restored, canceled, error),
/// on a launch that failed, or until [timeout] passes without an answer, so a
/// lost callback can never lock buying for good.
class PurchaseGate {
  PurchaseGate({
    this.timeout = defaultTimeout,
    this.onTimeout,
    this.deliver,
  });

  static const Duration defaultTimeout = Duration(minutes: 2);

  /// How long a purchase may stay in flight without a store answer.
  Duration timeout;

  /// Called after a purchase timed out; the gate is already open again.
  void Function(String productId)? onTimeout;

  /// The app's normal grant path. An unfinished StoreKit sale the app has not
  /// granted in this session goes through it (it grants, then finishes the
  /// transaction) instead of being finished with nothing delivered.
  Future<void> Function(PurchaseDetails purchase)? deliver;

  String? _productId;
  Timer? _timer;
  bool _delivering = false;
  final Set<String> _granted = <String>{};

  /// True while a purchase is in flight.
  bool get active => _productId != null;

  /// The product of the purchase in flight, if any.
  String? get productId => _productId;

  /// Starts a purchase of [productId]. False, with nothing changed, while
  /// another purchase is in flight.
  bool tryBegin(String productId) {
    if (_productId != null) return false;
    _productId = productId;
    _timer = Timer(timeout, _timedOut);
    return true;
  }

  void _timedOut() {
    final id = _productId;
    _timer = null;
    _productId = null;
    if (id != null) {
      debugPrint('[PurchaseGate] no store answer for $id within $timeout');
      onTimeout?.call(id);
    }
  }

  /// Ends the purchase in flight. With a [productId], only a purchase of that
  /// product ends (a restore of another product does not open the gate); an
  /// empty id (store errors without a product) always ends it.
  void end([String? productId]) {
    if (_productId == null || _delivering) return;
    if (productId != null && productId.isNotEmpty && productId != _productId) {
      return;
    }
    _timer?.cancel();
    _timer = null;
    _productId = null;
  }

  /// Records that the grant path delivered [purchase], so a later recovery
  /// finishes it instead of granting it twice.
  void markGranted(PurchaseDetails purchase) {
    final id = purchase.purchaseID;
    if (id != null && id.isNotEmpty) _granted.add(id);
  }

  /// Runs [buy] for [storeProductId]. On StoreKit it first clears unfinished
  /// transactions of that product and, if the store still reports a
  /// duplicate, clears them again and retries once. Elsewhere it only runs
  /// [buy].
  Future<bool> launch(
    String storeProductId,
    Future<bool> Function() buy,
  ) async {
    if (!purchasesUseStoreKit) return buy();
    await clearStale(storeProductId);
    try {
      return await buy();
    } on PlatformException catch (e) {
      if (!isDuplicateProductError(e)) rethrow;
      debugPrint('[PurchaseGate] $storeProductId still blocked: retrying once');
      await clearStale(storeProductId);
      return buy();
    }
  }

  /// Clears the unfinished StoreKit transactions of [storeProductId]: a sale
  /// not granted yet goes through [deliver]; one already granted is finished.
  Future<void> clearStale(String storeProductId) async {
    if (!purchasesUseStoreKit) return;
    final List<PurchaseDetails> stale;
    try {
      stale = await staleTransactionStore.unfinished(storeProductId);
    } catch (e) {
      debugPrint('[PurchaseGate] reading unfinished transactions failed: $e');
      return;
    }
    for (final p in stale) {
      final sale = p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored;
      final grant = deliver;
      try {
        if (sale && !_granted.contains(p.purchaseID)) {
          // Never finish a sale nobody delivered.
          if (grant == null) continue;
          debugPrint('[PurchaseGate] delivering unfinished ${p.productID}');
          _delivering = true;
          try {
            await grant(p);
          } finally {
            _delivering = false;
          }
        } else {
          debugPrint('[PurchaseGate] finishing stale ${p.productID}');
          await staleTransactionStore.finish(p);
        }
      } catch (e) {
        debugPrint('[PurchaseGate] clearing ${p.productID} failed: $e');
      }
    }
  }

  /// Opens the gate and forgets the session's grants (tests).
  @visibleForTesting
  void reset() {
    _timer?.cancel();
    _timer = null;
    _productId = null;
    _delivering = false;
    _granted.clear();
  }
}
