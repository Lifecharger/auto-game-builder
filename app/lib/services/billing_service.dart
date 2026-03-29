import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';

class BillingService {
  BillingService._();
  static final BillingService instance = BillingService._();

  static const String _donateProductId = 'donate_support';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _initialized = false;
  bool _available = false;
  ProductDetails? _donateProduct;

  bool get isAvailable => _available && _donateProduct != null;
  String? get donatePrice => _donateProduct?.price;

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

  /// Launch the purchase flow for the donate product.
  Future<void> donate() async {
    if (_donateProduct == null) return;

    final purchaseParam = PurchaseParam(productDetails: _donateProduct!);
    // Use buyConsumable so the user can donate multiple times
    await _iap.buyConsumable(purchaseParam: purchaseParam);
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Complete the purchase (marks as consumed for consumables)
        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        // Complete even on error to clear the transaction
        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
