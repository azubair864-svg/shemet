import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../config/payment_config.dart';

enum PurchaseFlowStatus { pending, success, error }

class PurchaseFlowUpdate {
  final PurchaseFlowStatus status;
  final String productId;
  final String? purchaseId;
  final int diamondsGranted;
  final double priceValue;
  final String? priceLabel;
  final String? packageName;
  final String? errorMessage;
  final bool alreadyGranted;

  const PurchaseFlowUpdate({
    required this.status,
    required this.productId,
    this.purchaseId,
    this.diamondsGranted = 0,
    this.priceValue = 0,
    this.priceLabel,
    this.packageName,
    this.errorMessage,
    this.alreadyGranted = false,
  });
}

class PurchaseVerificationResult {
  final bool success;
  final int diamondsGranted;
  final bool alreadyGranted;
  final String? errorMessage;

  const PurchaseVerificationResult({
    required this.success,
    this.diamondsGranted = 0,
    this.alreadyGranted = false,
    this.errorMessage,
  });
}

/// ⭐⭐⭐ GOOGLE PLAY IAP SERVICE ⭐⭐⭐
/// Handles connection to Google Play Store, loading products, and processing purchases.
class IapService {
  // Singleton pattern
  static final IapService _instance = IapService._internal();
  factory IapService() => _instance;
  IapService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Streams for UI to listen to
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final StreamController<PurchaseFlowUpdate> _purchaseUpdatesController =
      StreamController<PurchaseFlowUpdate>.broadcast();
  
  // Public streams / getters
  List<ProductDetails> get products => _products;
  Stream<PurchaseFlowUpdate> get purchaseUpdates =>
      _purchaseUpdatesController.stream;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;
  bool _isInitialized = false;
  bool _isInitializing = false;

  /// Initialize IAP Service
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    while (_isInitializing) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_isInitialized) {
        return;
      }
    }

    _isInitializing = true;

    try {
    // Check store availability
      _isAvailable = await _inAppPurchase.isAvailable();

      if (!_isAvailable) {
        return;
      }

      if (_subscription == null) {
        final Stream<List<PurchaseDetails>> purchaseUpdated =
            _inAppPurchase.purchaseStream;
        _subscription = purchaseUpdated.listen(
          (purchaseDetailsList) {
            _listenToPurchaseUpdated(purchaseDetailsList);
          },
          onDone: () => _subscription?.cancel(),
          onError: (_) {},
        );
      }

      // Load products immediately
      await loadProducts();
      _isInitialized = true;
    } finally {
      _isInitializing = false;
    }
  }

  /// Load Products from Google Play Console
  Future<void> loadProducts() async {
    print('IapService: Loading products... isAvailable: $_isAvailable');
    if (!_isAvailable) {
      _products = [];
      return;
    }

    print('IapService: Querying IDs: ${PaymentConfig.productIds}');
    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(PaymentConfig.productIds);

    if (response.error != null) {
      print('IapService Error: ${response.error!.message}');
      _products = [];
      return;
    }

    print('IapService: Query complete. Found ${response.productDetails.length} products.');
    for (var p in response.productDetails) {
      print('  - Product: ${p.id}, Price: ${p.price}');
    }

    if (response.notFoundIDs.isNotEmpty) {
      print('IapService Warning: IDs not found in Store: ${response.notFoundIDs}');
    }

    _products = response.productDetails;

    // Sort products by price (lowest to highest)
    _products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
  }

  /// Initiate Purchase Flow
  Future<void> buyProduct(ProductDetails product) async {
    if (!_isAvailable) {
      _emitPurchaseUpdate(
        PurchaseFlowUpdate(
          status: PurchaseFlowStatus.error,
          productId: product.id,
          priceValue: product.rawPrice,
          priceLabel: product.price,
          packageName: _cleanProductTitle(product.title),
          errorMessage: 'Google Play Store is not available on this device.',
        ),
      );
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);

    try {
      await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _emitPurchaseUpdate(
        PurchaseFlowUpdate(
          status: PurchaseFlowStatus.error,
          productId: product.id,
          priceValue: product.rawPrice,
          priceLabel: product.price,
          packageName: _cleanProductTitle(product.title),
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Handle Purchase Updates from the Stream
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    unawaited(updatePurchases(purchaseDetailsList));
  }

  Future<void> updatePurchases(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      final product = _findProductById(purchaseDetails.productID);

      if (purchaseDetails.status == PurchaseStatus.pending) {
        _emitPurchaseUpdate(
          PurchaseFlowUpdate(
            status: PurchaseFlowStatus.pending,
            productId: purchaseDetails.productID,
            purchaseId: purchaseDetails.purchaseID,
            diamondsGranted: _diamondsFromProductId(purchaseDetails.productID),
            priceValue: product?.rawPrice ?? 0,
            priceLabel: product?.price,
            packageName: _cleanProductTitle(
              product?.title ?? purchaseDetails.productID,
            ),
          ),
        );
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          _emitPurchaseUpdate(
            PurchaseFlowUpdate(
              status: PurchaseFlowStatus.error,
              productId: purchaseDetails.productID,
              purchaseId: purchaseDetails.purchaseID,
              diamondsGranted: _diamondsFromProductId(purchaseDetails.productID),
              priceValue: product?.rawPrice ?? 0,
              priceLabel: product?.price,
              packageName: _cleanProductTitle(
                product?.title ?? purchaseDetails.productID,
              ),
              errorMessage:
                  purchaseDetails.error?.message ?? 'Purchase failed.',
            ),
          );
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // Verify and Deliver
          final PurchaseVerificationResult result = await _verifyPurchase(
            purchaseDetails,
            product,
          );
          if (result.success) {
            await _deliverProduct(purchaseDetails);
            _emitPurchaseUpdate(
              PurchaseFlowUpdate(
                status: PurchaseFlowStatus.success,
                productId: purchaseDetails.productID,
                purchaseId: purchaseDetails.purchaseID,
                diamondsGranted: result.diamondsGranted,
                priceValue: product?.rawPrice ?? 0,
                priceLabel: product?.price,
                packageName: _cleanProductTitle(
                  product?.title ?? purchaseDetails.productID,
                ),
                alreadyGranted: result.alreadyGranted,
              ),
            );
          } else {
            _emitPurchaseUpdate(
              PurchaseFlowUpdate(
                status: PurchaseFlowStatus.error,
                productId: purchaseDetails.productID,
                purchaseId: purchaseDetails.purchaseID,
                diamondsGranted: _diamondsFromProductId(purchaseDetails.productID),
                priceValue: product?.rawPrice ?? 0,
                priceLabel: product?.price,
                packageName: _cleanProductTitle(
                  product?.title ?? purchaseDetails.productID,
                ),
                errorMessage:
                    result.errorMessage ?? 'Purchase verification failed.',
              ),
            );
          }
        }

        // Complete the purchase (Consume it so it can be bought again)
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  /// Verify Purchase (Client-side or Server-side)
  Future<PurchaseVerificationResult> _verifyPurchase(
    PurchaseDetails purchaseDetails,
    ProductDetails? product,
  ) async {
    try {
      final callable = _functions.httpsCallable('verifyAndGrantDiamonds');
      final purchaseToken = purchaseDetails.verificationData.serverVerificationData;
      final source = purchaseDetails.verificationData.source;
      final payload = {
        'productId': purchaseDetails.productID,
        'purchaseId': purchaseDetails.purchaseID,
        'purchaseToken': purchaseToken,
        'source': source,
        'packageName': _cleanProductTitle(
          product?.title ?? purchaseDetails.productID,
        ),
        'priceValue': product?.rawPrice ?? 0,
        'priceLabel': product?.price,
        'currencyCode': product?.currencyCode,
      };
      final result = await callable.call<Map<String, dynamic>>(payload);
      final data = Map<String, dynamic>.from(result.data);
      return PurchaseVerificationResult(
        success: data['success'] == true,
        diamondsGranted:
            (data['diamondsGranted'] as num?)?.toInt() ??
            (data['coinsGranted'] as num?)?.toInt() ??
            _diamondsFromProductId(purchaseDetails.productID),
        alreadyGranted: data['alreadyGranted'] == true,
        errorMessage: data['message'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      return PurchaseVerificationResult(
        success: false,
        errorMessage: e.message ?? 'Payment verification failed.',
      );
    } catch (_) {
      return const PurchaseVerificationResult(
        success: false,
        errorMessage: 'Unexpected payment verification error.',
      );
    }
  }

  /// Delivery is done server-side in `verifyAndGrantCoins`.
  /// We keep this method to preserve call flow.
  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    await _firestore.collection('iap_audit').add({
      'productId': purchaseDetails.productID,
      'purchaseId': purchaseDetails.purchaseID,
      'status': 'verified_server_side',
      'at': FieldValue.serverTimestamp(),
    });
  }

  /// Dispose
  void dispose() {
    _subscription?.cancel();
  }

  ProductDetails? _findProductById(String productId) {
    for (final product in _products) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
  }

  int _diamondsFromProductId(String productId) {
    // New mappings based on Google Play Console updates (April 2026)
    switch (productId) {
      case 'coins_5000': return 14000;
      case 'coins_14200': return 49000;
      case 'coins_55000': return 110000;
      case 'coins_65000': return 156000;
      case 'coins_150000': return 540000;
      case 'coins_520000': return 1680000;
      default:
        final match = RegExp(r'^coins_(\d+)$').firstMatch(productId);
        if (match == null) {
          return 0;
        }
        return int.tryParse(match.group(1) ?? '') ?? 0;
    }
  }

  String _cleanProductTitle(String title) {
    return title.replaceAll(RegExp(r'\s*\(.*\)$'), '').trim();
  }

  void _emitPurchaseUpdate(PurchaseFlowUpdate update) {
    if (!_purchaseUpdatesController.isClosed) {
      _purchaseUpdatesController.add(update);
    }
  }
}
