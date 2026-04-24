import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/iap_service.dart';
import '../../services/diamond_service.dart';
import '../../services/diamond_dealer_service.dart';
import '../payments/payment_history_screen.dart';
import '../payments/payment_success_screen.dart';


class DiamondPurchaseScreen extends StatefulWidget {
  const DiamondPurchaseScreen({super.key});

  @override
  State<DiamondPurchaseScreen> createState() => _DiamondPurchaseScreenState();
}

class _DiamondPurchaseScreenState extends State<DiamondPurchaseScreen>
    with TickerProviderStateMixin {
  final IapService _iapService = IapService();
  final DiamondService _diamondService = DiamondService();
  final DiamondDealerService _dealerService = DiamondDealerService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  late TabController _tabController;
  late AnimationController _shimmerController;
  bool _isLoading = false;
  int _currentBalance = 0;
  String? _selectedProductId;

  List<ProductDetails> _products = [];
  List<DiamondDealer> _dealers = [];
  List<Map<String, dynamic>> _localPackages = [];

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _balanceSubscription;
  StreamSubscription<PurchaseFlowUpdate>? _purchaseUpdatesSubscription;

  // Premium Elite Theme Colors
  static const Color nightIndigo = Color(0xFF020202);
  static const Color premiumGold = Color(0xFFFFD700);
  static const Color electricCyan = Color(0xFF00E5FF);
  static const Color accentCyan = Color(0xFF00B8D4);
  static const Color premiumAmber = Color(0xFFFFAB00);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _listenToBalance();
    _listenToPurchaseUpdates();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _shimmerController.dispose();
    _balanceSubscription?.cancel();
    _purchaseUpdatesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _iapService.initialize();
      _products = _iapService.products;
      _currentBalance = await _diamondService.getDiamondBalance(_currentUserId);
      _dealers = await _dealerService.getAuthorizedDealers();

      _localPackages = [
        {
          'id': 'coins_5000',
          'diamonds': '14,000',
          'image': 'assets/images/diamond_1_package.png',
        },
        {
          'id': 'coins_14200',
          'diamonds': '49,000',
          'image': 'assets/images/diamond_2_package.png',
        },
        {
          'id': 'coins_55000',
          'diamonds': '110,000',
          'image': 'assets/images/diamond_3_package.png',
        },
        {
          'id': 'coins_65000',
          'diamonds': '156,000',
          'featured': true,
          'image': 'assets/images/diamond_4_package.png',
        },
        {
          'id': 'coins_150000',
          'diamonds': '540,000',
          'image': 'assets/images/diamond_5_package.png',
        },
        {
          'id': 'coins_520000',
          'diamonds': '1,680,000',
          'image': 'assets/images/diamond_5_package.png',
        },
      ];
      if (_localPackages.isNotEmpty) {
        _selectedProductId = _localPackages.first['id'] as String;
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenToBalance() {
    if (_currentUserId.isEmpty) return;
    _balanceSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .snapshots()
        .listen((snapshot) {
          if (!mounted || !snapshot.exists) return;
          setState(() {
            _currentBalance =
                (snapshot.data()?['diamonds'] as num?)?.toInt() ?? 0;
          });
        });
  }

  void _listenToPurchaseUpdates() {
    _purchaseUpdatesSubscription = _iapService.purchaseUpdates.listen((update) {
      if (!mounted) return;
      if (update.status == PurchaseFlowStatus.success) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaymentSuccessScreen(
              paymentId: update.purchaseId ?? 'Wallet Top-up',
              diamondsReceived: update.diamondsGranted,
              amountPaid: update.priceValue,
              priceLabel: update.priceLabel,
              packageName: update.packageName,
            ),
          ),
        );
      }
    });
  }

  void _onPackageTap(Map<String, dynamic> data) {
    setState(() {
      _selectedProductId = data['id'];
    });

    final product = _products.firstWhere(
      (p) => p.id == data['id'],
      orElse: () => _products.first,
    );
    _iapService.buyProduct(product);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF020202),
        body: Center(child: CircularProgressIndicator(color: premiumGold)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF020202),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPackageGrid(_localPackages),
            _buildRecommendTab(),
            _buildHelperTab(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBanner(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 220.0,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF030303),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history_edu, color: Colors.white, size: 24),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(74),
        child: Container(
          color: const Color(0xFF030303),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
              colors: [premiumGold, Color(0xFFFFAB00)],
                ),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              tabs: const [
                Tab(text: 'Google'),
                Tab(text: 'Recommend'),
                Tab(text: 'Helper'),
              ],
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [premiumGold, electricCyan],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 85),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top-up Diamonds',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('💎', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Text(
                      _currentBalance.toString().replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]},',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPackageGrid(List<Map<String, dynamic>> packages) =>
      GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: packages.length,
        itemBuilder: (context, index) => _buildPackageCard(packages[index]),
      );

  Widget _buildPackageCard(Map<String, dynamic> data) {
    final isHot = data['featured'] ?? false;
    final isSelected = _selectedProductId == data['id'];

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return GestureDetector(
          onTap: () => _onPackageTap(data),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            transform: Matrix4.identity()..scale(isSelected ? 1.04 : 1.0),
            decoration: BoxDecoration(
              color: const Color(0xFF020202),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected ? premiumGold : (isHot ? Color(0xFFFFAB00).withOpacity(0.5) : Colors.white.withOpacity(0.12)),
                width: isSelected ? 2.5 : (isHot ? 1.5 : 1),
              ),
              boxShadow: isSelected 
                ? [
                    BoxShadow(color: premiumGold.withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
                    BoxShadow(color: premiumGold.withOpacity(0.1), blurRadius: 40, spreadRadius: 5),
                  ]
                : [
                    BoxShadow(
                      color: isHot ? premiumGold.withOpacity(0.15) : Colors.black.withOpacity(0.4),
                      blurRadius: isHot ? 15 : 10,
                      spreadRadius: isHot ? 1 : 0,
                      offset: isHot ? Offset.zero : const Offset(0, 5),
                    ),
                    const BoxShadow(color: Colors.transparent, blurRadius: 0.1, spreadRadius: 0),
                  ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // Shimmer Effect Overlay
                  Positioned.fill(
                    child: FractionallySizedBox(
                      widthFactor: 2.0,
                      alignment: Alignment(
                        _shimmerController.value * 3 - 1.5,
                        0,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0),
                              Colors.white.withOpacity(0.04),
                              Colors.white.withOpacity(0),
                            ],
                            stops: const [0.4, 0.5, 0.6],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Image.asset(
                                data['image'],
                                fit: BoxFit.contain,
                              ),
                            ),
                            if (isHot)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: premiumGold, 
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: premiumGold, blurRadius: 10, spreadRadius: 1)],
                                  ),
                                  child: const Icon(
                                    Icons.flash_on,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        data['diamonds'] ?? '...',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (data['bonus'] != null)
                        Text(
                          data['bonus']!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white60,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.white60,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? premiumGold.withOpacity(0.2) : (isHot ? const Color(0xFF020202) : const Color(0xFF020202)),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(22),
                          ),
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _getPriceForProduct(data['id']),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isHot ? Colors.white : Colors.white70),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getPriceForProduct(String productId) {
    try {
      final product = _products.firstWhere((p) => p.id == productId);
      return product.price;
    } catch (_) {
      // Safe fallback while loading
      if (productId == 'coins_5000') return 'LKR 300.00';
      if (productId == 'coins_14200') return 'LKR 925.00';
      if (productId == 'coins_55000') return 'LKR 3,075.00';
      if (productId == 'coins_65000') return 'LKR 3,075.00';
      if (productId == 'coins_150000') return 'LKR 9,200.00';
      if (productId == 'coins_520000') return 'LKR 30,750.00';
      return '...';
    }
  }

  Widget _buildRecommendTab() => ListView(
    padding: EdgeInsets.zero,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentCyan.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentCyan.withOpacity(0.2)),
          ),
          child: Row(
            children: const [
              Icon(Icons.flash_on, color: accentCyan, size: 20),
              SizedBox(width: 8),
              Text(
                'Instant Local Recharge',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00838F),
                ),
              ),
              Spacer(),
              Icon(Icons.chevron_right, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
      _buildPackageGrid(_localPackages),
    ],
  );

  Widget _buildHelperTab() => ListView(
    padding: EdgeInsets.zero,
    children: [
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: premiumAmber.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: premiumAmber.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield, color: premiumAmber, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Secure Top-up Helpers',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Contact verified dealers for high-value top-ups with manual bonuses.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ..._dealers.map((dealer) => _buildDealerItem(dealer)),
    ],
  );

  Widget _buildDealerItem(DiamondDealer dealer) => Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundImage: dealer.photoURL != null
              ? CachedNetworkImageProvider(dealer.photoURL!)
              : null,
          child: dealer.photoURL == null ? const Icon(Icons.person) : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dealer.officialName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.green, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'Official Dealer',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () async {
            final Uri uri = Uri.parse(dealer.contactLink);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00C853), Color(0xFF64DD17)],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8),
              ],
            ),
            child: const Text(
              'CONTACT',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  bool _isAgreed = true; // Default to true as seen in Image 1

  Widget _buildBottomBanner() => SafeArea(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF020202),
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => setState(() => _isAgreed = !_isAgreed),
                child: Icon(
                  _isAgreed ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: _isAgreed ? premiumGold : Colors.white24,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                    children: [
                      TextSpan(text: 'Please agree to the '),
                      TextSpan(
                        text: 'User Agreement',
                        style: TextStyle(
                          color: premiumGold,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: premiumGold,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(text: ' first!'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    ),
  );
}
