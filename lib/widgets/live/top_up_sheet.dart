import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/iap_service.dart';
import '../../providers/user_provider.dart';
import '../../screens/payments/payment_failed_screen.dart';
import '../../screens/payments/payment_history_screen.dart';
import '../../screens/payments/payment_success_screen.dart';
import '../../services/monetization_service.dart';
import '../../models/diamond_package_model.dart';
import '../../models/payment_method_model.dart';
import '../../models/user_model.dart';
import 'package:url_launcher/url_launcher_string.dart';

class TopUpSheet extends StatefulWidget {
  final int currentDiamonds;

  const TopUpSheet({
    super.key,
    required this.currentDiamonds, // Kept for initial display, but Provider is better for updates
  });

  @override
  State<TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<TopUpSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // IAP Service
  final IapService _iapService = IapService();
  bool _isLoadingIAP = false;
  bool _isStoreAvailable = false;
  List<ProductDetails> _products = [];
  String? _errorMessage;
  bool _isPurchaseInProgress = false;
  String? _pendingProductId;
  StreamSubscription<PurchaseFlowUpdate>? _purchaseUpdatesSubscription;

  // Manual & Agents
  final MonetizationService _monetizationService = MonetizationService();
  late Future<List<DiamondPackageModel>> _packagesFuture;
  late Future<List<PaymentMethodModel>> _methodsFuture;
  late Future<List<UserModel>> _agentsFuture;
  PaymentMethodModel? _selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _packagesFuture = _monetizationService.getDiamondPackages();
    _methodsFuture = _monetizationService.getPaymentMethods().then((methods) {
      if (methods.isNotEmpty) {
        setState(() {
          _selectedPaymentMethod = methods.first;
        });
      }
      return methods;
    });
    _agentsFuture = _monetizationService.getAgents();

    _listenToPurchaseUpdates();
    _initializeIAP();
  }

  Future<void> _initializeIAP() async {
    if (!mounted) return;
    setState(() {
      _isLoadingIAP = true;
      _errorMessage = null;
    });

    try {
      await _iapService.initialize();
      bool available = await InAppPurchase.instance.isAvailable();

      if (!available) {
        if (mounted) {
          setState(() {
            _isStoreAvailable = false;
            _isLoadingIAP = false;
            _errorMessage =
                "Google Play Store is not available on this device.";
          });
        }
        return;
      }

      // Wait a moment for products to load if they're not immediately available
      // Ideally IapService would provide a reactive stream for products list changes
      // For now, we poll or rely on initialize() having done the work.
      // Let's try to get products from the service.

      // Checking if IapService has a way to expose products.
      // Based on previous reads, IapService has a public `products` list.
      // We might need a small delay if the stream update is async inside initialize.
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _isStoreAvailable = true;
          _products = _iapService.products;
          _isLoadingIAP = false;
          if (_products.isEmpty) {
            _errorMessage = "No products found. Check configuration.";
          }
        });
      }
    } catch (e) {
      debugPrint("Error initializing IAP: $e");
      if (mounted) {
        setState(() {
          _isLoadingIAP = false;
          _errorMessage = "Failed to load products: $e";
        });
      }
    }
  }

  void _handlePurchase(ProductDetails product) {
    if (!_isStoreAvailable) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Store not available')));
      return;
    }
    setState(() {
      _isPurchaseInProgress = true;
      _pendingProductId = product.id;
    });
    _iapService.buyProduct(product);
  }

  @override
  void dispose() {
    _purchaseUpdatesSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _listenToPurchaseUpdates() {
    _purchaseUpdatesSubscription = _iapService.purchaseUpdates.listen((update) {
      if (!mounted) return;
      if (_pendingProductId == null) return;
      if (update.productId != _pendingProductId) return;

      switch (update.status) {
        case PurchaseFlowStatus.pending:
          break;
        case PurchaseFlowStatus.success:
          final diamondsReceived = _diamondsFromProductId(update.productId);

          final product = _productById(update.productId);
          setState(() {
            _isPurchaseInProgress = false;
            _pendingProductId = null;
          });

          if (update.alreadyGranted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This Google Play purchase was already granted.'),
              ),
            );
            return;
          }

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PaymentSuccessScreen(
                paymentId: update.purchaseId ?? 'Google Play',
                diamondsReceived:
                    update.diamondsGranted > 0 ? update.diamondsGranted : diamondsReceived,
                amountPaid: update.priceValue,
                priceLabel: update.priceLabel,
                packageName: update.packageName ?? product?.title,
              ),
            ),
          );
          break;
        case PurchaseFlowStatus.error:
          final selectedProduct = _productById(update.productId);

          setState(() {
            _isPurchaseInProgress = false;
            _pendingProductId = null;
          });

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PaymentFailedScreen(
                errorMessage:
                    update.errorMessage ?? 'Google Play payment failed.',
                attemptedAmount: update.priceValue > 0 ? update.priceValue : null,
                priceLabel: update.priceLabel,
                packageName: update.packageName ?? selectedProduct?.title,
                onRetry:
                    selectedProduct == null ? null : () => _handlePurchase(selectedProduct),
              ),
            ),
          );
          break;
      }
    });
  }

  ProductDetails? _productById(String productId) {
    for (final product in _products) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
  }

  int _diamondsFromProductId(String productId) {
    final match = RegExp(r'^coins_(\d+)$').firstMatch(productId);
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    // Listen to UserProvider for real-time coin balance updates
    final userProvider = Provider.of<UserProvider>(context);
    final int diamondBalance =
        userProvider.currentUser?.diamonds ?? widget.currentDiamonds; // Fallback

    return Container(
      height: 600, // Fixed height for consistency
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark theme base
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        children: [
          // 1. Header (Coin Count)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E0B2D), Colors.black],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "MY DIAMOND BALANCE",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Icon(
                          Icons.diamond,
                          color: Color(0xFF00BFFF), // Diamond Blue
                          size: 36,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          NumberFormat.decimalPattern().format(diamondBalance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PaymentHistoryScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF1493), Color(0xFFFF69B4)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF1493).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.history, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          "History",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Tabs
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFFF1493), // Neon Pink
              unselectedLabelColor: Colors.white54,
              indicatorColor: const Color(0xFFFF1493),
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Google Play'),
                Tab(text: 'Agents'),
              ],
            ),
          ),

          // 3. Tab Views
          Expanded(
            child: Container(
              color: Colors.black, // Dark background for tabs
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGoogleTab(),
                  _buildHelperTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleTab() {
    if (_isLoadingIAP) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF1493)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white.withValues(alpha: 0.2),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeIAP,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF1493),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Retry Connection',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Text(
          "No packages available.",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75, // Adjust aspect ratio for better fit
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(ProductDetails product) {
    String title = product.title.replaceAll(RegExp(r'\(.*\)'), '').trim();
    String displayDiamonds = title;

    // Attempt fallback from id
    if (title.isEmpty || title.toLowerCase().contains('coin')) {
      final match = RegExp(r'coins_(\d+)').firstMatch(product.id);
      if (match != null) {
        displayDiamonds = '${match.group(1)} Diamonds';
      }
    }

    return GestureDetector(
      onTap: _isPurchaseInProgress ? null : () => _handlePurchase(product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05), // Glass base
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            const Icon(
              Icons.diamond,
              color: Color(0xFF00BFFF),
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              displayDiamonds.replaceAll(RegExp(r'[^0-9]'), ''),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF1493), Color(0xFFFF69B4)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                _isPurchaseInProgress && _pendingProductId == product.id
                    ? '...'
                    : product.price,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // --- REUSED TABS (HELPER) ---



  Widget _buildMockPackageCard({
    required int diamonds,
    required String price,
    bool isBonus = false,
    bool isHot = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHot
              ? const Color(0xFFFFD700)
              : Colors.white.withValues(alpha: 0.1),
          width: isHot ? 1.5 : 1,
        ),
        boxShadow: isHot
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              const Icon(
                Icons.diamond,
                color: Color(0xFF00BFFF),
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                diamonds.toString().replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (Match m) => '${m[1]},',
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isHot
                        ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                        : [const Color(0xFFFF1493), const Color(0xFFFF69B4)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  price,
                  style: TextStyle(
                    color: isHot ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (isBonus || isHot)
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.black,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHelperTab() {
    return FutureBuilder<List<UserModel>>(
      future: _agentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF1493)));
        }

        final agents = snapshot.data ?? [];

        if (agents.isEmpty) {
          return const Center(child: Text("No agents available right now.", style: TextStyle(color: Colors.white54)));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: agents.length,
          separatorBuilder: (context, index) =>
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          itemBuilder: (context, index) {
            final agent = agents[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF1493), Color(0xFFFF69B4)],
                  ),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundImage: agent.mainPhoto != null ? NetworkImage(agent.mainPhoto!) : null,
                  backgroundColor: const Color(0xFF1E1E1E),
                  child: agent.mainPhoto == null
                      ? Text(
                          agent.displayName[0].toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
              title: Text(
                agent.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              subtitle: Row(
                children: [
                  const Icon(
                    Icons.phone,
                    size: 14,
                    color: Color(0xFF00E676),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      agent.phoneNumber ?? 'No Phone',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              onTap: () async {
                if (agent.phoneNumber != null && agent.phoneNumber!.isNotEmpty) {
                  final url = "https://wa.me/${agent.phoneNumber!.replaceAll('+', '')}?text=Hi, I want to buy diamonds.";
                  try {
                    if (await canLaunchUrlString(url)) {
                      await launchUrlString(url, mode: LaunchMode.externalApplication);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
                    }
                  } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('This agent has no phone number.')),
                  );
                }
              },
            );
          },
        );
      }
    );
  }
}
