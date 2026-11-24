import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'purchase_gate.dart';

class BillingService {
  BillingService._();
  static final BillingService instance = BillingService._();

  static const String _donateProductId = 'donate_support';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _initialized = false;
  bool _available = false;
  ProductDetails? _donateProduct;

  // One store purchase at a time: a double tap must not start a second one
  // (on iOS that leaves StoreKit refusing the product until a restart).
  late final PurchaseGate _gate = PurchaseGate(
    deliver: (p) => _handlePurchaseUpdates(<PurchaseDetails>[p]),
  );

  bool get isAvailable => _available && _donateProduct != null;
  String? get donatePrice => _donateProduct?.price;

  /// True while a store purchase is in flight; further taps are ignored.
  bool get purchaseInFlight => _gate.active;

  @visibleForTesting
  PurchaseGate get purchaseGateForTesting => _gate;

  /// Initialize billing. Safe to call multiple times — only runs once.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _available = await _iap.isAvailable();
    if (!_available) return;

    // Listen for purchase updates
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (_) {},
    );

    // Load product details
    final response = await _iap.queryProductDetails({_donateProductId});
    if (response.productDetails.isNotEmpty) {
      _donateProduct = response.productDetails.first;
    }
  }

  /// Launch the purchase flow for the donate product. Does nothing while a
  /// purchase is already in flight (a double tap).
  Future<void> donate() async {
    final product = _donateProduct;
    if (product == null) return;
    if (!_gate.tryBegin(product.id)) return;

    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      // Use buyConsumable so the user can donate multiple times
      final launched = await _gate.launch(
        product.id,
        () => _iap.buyConsumable(purchaseParam: purchaseParam),
      );
      if (!launched) _gate.end(product.id);
    } catch (_) {
      _gate.end(product.id);
      // The settings screen shows the failure.
      rethrow;
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        // Still on its way: the purchase stays in flight (the gate's timeout
        // covers an answer that never comes).
        continue;
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // A donation grants nothing: it is delivered once the store hears
        // "done", so a later recovery of it only finishes it.
        _gate.markGranted(purchase);
      }
      // Complete purchases (marks consumables consumed) and also errors and
      // cancels, to clear the transaction.
      if (purchase.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchase);
        } catch (e) {
          debugPrint('[Billing] completePurchase failed: $e');
        }
      }
      // Purchased, restored, canceled or failed: the purchase is over. An
      // error without a product (Play) ends whatever is in flight.
      _gate.end(purchase.productID);
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
