import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/iap_service.dart';
import '../../services/coin_service.dart';
import '../../services/diamond_dealer_service.dart';
import '../payments/payment_history_screen.dart';
import '../payments/payment_success_screen.dart';

class CoinPurchaseScreen extends StatefulWidget {
  const CoinPurchaseScreen({super.key});

  @override
  State<CoinPurchaseScreen> createState() => _CoinPurchaseScreenState();
}

class _CoinPurchaseScreenState extends State<CoinPurchaseScreen> with SingleTickerProviderStateMixin {
  final IapService _iapService = IapService();
  final CoinService _coinService = CoinService();
  final DiamondDealerService _dealerService = DiamondDealerService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  late TabController _tabController;
  bool _isLoading = false;
  int _currentBalance = 0;
  String? _pendingProductId;

  List<ProductDetails> _products = [];
  List<DiamondDealer> _dealers = [];
  List<Map<String, dynamic>> _localPackages = [];
  
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _balanceSubscription;
  StreamSubscription<PurchaseFlowUpdate>? _purchaseUpdatesSubscription;

  // Vivid Night Premium Theme Colors
  static const Color nightIndigo = Color(0xFF1A0B2E);
  static const Color vividPurple = Color(0xFF7B2FF7);
  static const Color vividMagenta = Color(0xFFE91E63);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color premiumAmber = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _listenToBalance();
    _listenToPurchaseUpdates();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _balanceSubscription?.cancel();
    _purchaseUpdatesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _iapService.initialize();
      _products = _iapService.products;
      _currentBalance = await _coinService.getCoinBalance(_currentUserId);
      _dealers = await _dealerService.getAuthorizedDealers();
      
      _localPackages = [
        {'diamonds': '5,000', 'bonus': '4,000', 'priceLabel': 'Rs 300.00', 'featured': false},
        {'diamonds': '14,200', 'bonus': '12,000', 'priceLabel': 'Rs 925.00', 'featured': false},
        {'diamonds': '55,000', 'bonus': '40,000', 'priceLabel': 'Rs 2,975.00', 'featured': true},
        {'diamonds': '65,000', 'bonus': '40,000', 'priceLabel': 'Rs 3,075.00', 'featured': false},
        {'diamonds': '150,000', 'bonus': '120,000', 'priceLabel': 'Rs 9,200.00', 'featured': false},
        {'diamonds': '520,000', 'bonus': '400,000', 'priceLabel': 'Rs 30,750.00', 'featured': false},
      ];
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
        _currentBalance = (snapshot.data()?['diamonds'] as num?)?.toInt() ?? 0;
      });
    });
  }

  void _listenToPurchaseUpdates() {
    _purchaseUpdatesSubscription = _iapService.purchaseUpdates.listen((update) {
      if (!mounted || _pendingProductId == null) return;
      if (update.status == PurchaseFlowStatus.success) {
        setState(() { _pendingProductId = null; });
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentSuccessScreen(
          paymentId: update.purchaseId ?? 'Wallet Top-up',
          coinsReceived: update.coinsGranted,
          amountPaid: update.priceValue,
          priceLabel: update.priceLabel,
          packageName: update.packageName,
        )));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('💎 [UI_TRACE] build: isLoading=$_isLoading, products=${_products.length}');
    
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: vividPurple),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildGoogleTab(),
            _buildRecommendTab(),
            _buildHelperTab(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBanner(),
    );
  }

  Widget _buildGoogleTab() {
    if (_products.isEmpty) {
      return const Center(child: Text('No Google Play products available'));
    }
    return _buildPackageList(_products.map((p) => {
      'diamonds': p.id.split('_').last,
      'bonus': _saveParseBonus(p.id),
      'priceLabel': p.price,
      'featured': p.id.contains('10000'),
    }).toList());
  }

  String _saveParseBonus(String productId) {
    try {
      final part = productId.split('_').last;
      final amount = int.tryParse(part) ?? 0;
      return (amount * 0.8).toInt().toString();
    } catch (_) {
      return "0";
    }
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 220.0,
      floating: false,
      pinned: true,
      backgroundColor: vividPurple,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history_edu, color: Colors.white, size: 24),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentHistoryScreen())),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(74),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F8),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(colors: [vividPurple, vividMagenta]),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
              colors: [vividPurple, vividMagenta],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 85),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Top-up Diamonds', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('💎', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Text(
                      _currentBalance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
                      style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold, letterSpacing: -1.0),
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
            children: [
              const Icon(Icons.flash_on, color: accentCyan, size: 20),
              const SizedBox(width: 8),
              const Text('Instant Local Recharge', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00838F))),
              const Spacer(),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
      _buildPackageList(_localPackages),
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
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Secure Top-up Helpers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange)),
                SizedBox(height: 4),
                Text('Contact verified dealers for high-value top-ups with manual bonuses.', style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.4)),
              ],
            )),
          ],
        ),
      ),
      ..._dealers.map((dealer) => _buildDealerItem(dealer)),
    ],
  );

  Widget _buildPackageList(List<Map<String, dynamic>> packages) => GridView.builder(
    padding: const EdgeInsets.all(16),
    physics: const NeverScrollableScrollPhysics(),
    shrinkWrap: true,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2, 
      childAspectRatio: 0.82, 
      crossAxisSpacing: 16, 
      mainAxisSpacing: 16
    ),
    itemCount: packages.length,
    itemBuilder: (context, index) => _buildPackageCard(packages[index]),
  );

  Widget _buildPackageCard(Map<String, dynamic> data) {
    bool isHot = data['featured'] ?? false;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 8)),
          if (isHot) BoxShadow(color: vividPurple.withOpacity(0.1), blurRadius: 20, spreadRadius: 2)
        ],
        border: isHot ? Border.all(color: vividMagenta.withOpacity(0.3), width: 1.5) : null,
      ),
      child: Stack(
        children: [
          Column(
            children: [
              const Spacer(),
              const Text('💎', style: TextStyle(fontSize: 46)),
              const SizedBox(height: 12),
              Text(data['diamonds'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2E2E2E))),
              Text(data['bonus'], style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough)),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isHot 
                    ? const LinearGradient(colors: [vividPurple, vividMagenta]) 
                    : LinearGradient(colors: [Colors.grey.shade100, Colors.grey.shade200]),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))
                ),
                child: Center(
                  child: Text(
                    data['priceLabel'], 
                    style: TextStyle(color: isHot ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)
                  )
                ),
              ),
            ],
          ),
          if (isHot) 
            Positioned(
              top: 12, 
              right: 12, 
              child: Container(
                padding: const EdgeInsets.all(5), 
                decoration: const BoxDecoration(color: vividMagenta, shape: BoxShape.circle), 
                child: const Icon(Icons.star, color: Colors.white, size: 12)
              )
            ),
        ],
      ),
    );
  }

  Widget _buildDealerItem(DiamondDealer dealer) => Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Row(
      children: [
        CircleAvatar(radius: 28, backgroundImage: dealer.photoURL != null ? CachedNetworkImageProvider(dealer.photoURL!) : null, child: dealer.photoURL == null ? const Icon(Icons.person) : null),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dealer.officialName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF333333))),
              const SizedBox(height: 4),
              Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.green, size: 12),
                  SizedBox(width: 4),
                  Text('Official Dealer', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () async {
            final Uri uri = Uri.parse(dealer.contactLink);
            if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), 
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00C853), Color(0xFF64DD17)]),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8)]
            ), 
            child: const Text('CONTACT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))
          ),
        ),
      ],
    ),
  );

  Widget _buildBottomBanner() => SafeArea(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.verified_user, color: Colors.blueAccent, size: 14),
          SizedBox(width: 8),
          Text('Safe and encrypted payment environment', style: TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    ),
  );
}
