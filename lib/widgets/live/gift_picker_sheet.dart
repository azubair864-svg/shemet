
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/monetization_service.dart';
import '../../services/gift_service.dart';
import '../../models/gift_model.dart';

class GiftPickerSheet extends StatefulWidget {
  final String streamId;
  final String receiverId;
  final String context;
  final int? seatIndex; // Added for targeted party room gifting

  const GiftPickerSheet({
    super.key,
    required this.streamId,
    required this.receiverId,
    this.context = 'live_stream',
    this.seatIndex,
  });

  @override
  State<GiftPickerSheet> createState() => _GiftPickerSheetState();
}

class _GiftPickerSheetState extends State<GiftPickerSheet>
    with SingleTickerProviderStateMixin {
  final MonetizationService _monetizationService = MonetizationService();
  final GiftService _giftService = GiftService();
  GiftModel? _selectedGift;
  late TabController _tabController;

  final List<String> _categories = ['HOT', 'Lucky', 'Funny', 'Luxury'];
  bool _isSending = false;
  
  // Paging Support
  late PageController _hotPageController;
  int _currentPageIndex = 0;
  int _selectedQuantity = 1;

  final Map<int, List<int>> _pageQuantities = {
    0: [1, 17, 37, 77],
    1: [1, 9, 39, 99],
    2: [1, 17, 37, 77],
  };

  @override
  void initState() {
    super.initState();
    debugPrint('[GIFT_DEBUG] initState: GiftPickerSheet initialized');
    _tabController = TabController(length: _categories.length, vsync: this);
    _hotPageController = PageController();

    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      debugPrint('[GIFT_DEBUG] _onTabChanged: Index changing to ${_tabController.index}');
      if (mounted) {
        setState(() {
          _selectedGift = null;
          _selectedQuantity = 1;
          _currentPageIndex = 0;
          if (_hotPageController.hasClients) {
            _hotPageController.jumpToPage(0);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    debugPrint('[GIFT_DEBUG] dispose: Cleaning up controllers');
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _hotPageController.dispose();
    super.dispose();
  }

  void _sendGift() async {
    if (_selectedGift == null || _isSending) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;
    if (user == null) return;

    if (user.uid == widget.receiverId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot send gifts to yourself! 🚫'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Determine the actual price
    final giftPrice = (_selectedGift!.priceDiamonds > 0 ? _selectedGift!.priceDiamonds : _selectedGift!.price) * _selectedQuantity;
    final userBalance = user.diamonds;

    if (userBalance < giftPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient diamonds! Please Top Up. 💎'),
          backgroundColor: Color(0xFF1E90FF),
        ),
      );
      return;
    }

    if (mounted) {
      setState(() => _isSending = true);
    }

    try {
      final success = await _giftService.sendGift(
        fromUserId: user.uid,
        fromUserName: user.name,
        toUserId: widget.receiverId,
        toUserName: "User",
        gift: _selectedGift!,
        quantity: _selectedQuantity,
        context: widget.context,
        contextId: widget.streamId,
        seatIndex: widget.seatIndex,
      );

      if (mounted) {
        if (success) {
          userProvider.deductDiamondsLocal(giftPrice);
          Navigator.pop(context);
        } else {
          setState(() => _isSending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send gift. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = (screenHeight * 0.55).clamp(450.0, 550.0);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
              displayColor: Colors.white,
              bodyColor: Colors.white,
            ),
      ),
      child: Container(
        height: sheetHeight, 
        decoration: const BoxDecoration(
          color: Colors.transparent, 
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. Ultra-Premium Glass Background
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1A1B30).withOpacity(0.92),
                    const Color(0xFF0F1020).withOpacity(0.95),
                    const Color(0xFF050510).withOpacity(0.99),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 1.0,
                ),
              ),
            ),
          ),

          // 2. Mesh Gradient Detail
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7B2CBF).withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B2CBF).withOpacity(0.1),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelColor: const Color(0xFFFFD700), 
                        unselectedLabelColor: Colors.white54,
                        indicatorSize: TabBarIndicatorSize.label,
                        indicator: UnderlineTabIndicator(
                          borderSide: const BorderSide(color: Color(0xFFFFD700), width: 3),
                          borderRadius: BorderRadius.circular(2),
                          insets: const EdgeInsets.only(bottom: 6),
                        ),
                        dividerColor: Colors.transparent,
                        labelPadding: const EdgeInsets.only(right: 24),
                        tabAlignment: TabAlignment.start,
                        labelStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                        tabs: _categories.map((c) => Tab(text: c.toUpperCase())).toList(),
                      ),
                    ),

                    // REAL-TIME DIAMOND BALANCE
                    Consumer<UserProvider>(
                      builder: (context, provider, child) {
                        final liveUser = provider.currentUser;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.diamond_rounded, color: Color(0xFF00BFFF), size: 16),
                              const SizedBox(width: 8),
                              Text(
                                '${liveUser?.diamonds ?? 0}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.add_circle_outline_rounded, color: Colors.white.withOpacity(0.4), size: 12),
                            ],
                          ),
                        ).onTap(() => Navigator.pushNamed(context, '/diamond_purchase'));
                      },
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white10, height: 1),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _categories.map((category) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final iconSize = ((constraints.maxWidth - 64) / 4).clamp(45.0, 75.0);
                        
                        final allPagedGifts = GiftModel.getGiftsByCategory(category.toLowerCase());
                        final pages = <List<GiftModel>>[];
                        for (var i = 0; i < allPagedGifts.length; i += 8) {
                          pages.add(allPagedGifts.sublist(i, i + 8 > allPagedGifts.length ? allPagedGifts.length : i + 8));
                        }

                        if (pages.isEmpty) {
                          return const Center(child: Text('No gifts available.', style: TextStyle(color: Colors.white38)));
                        }

                        return Column(
                          children: [
                            Expanded(
                              child: PageView.builder(
                                controller: _hotPageController,
                                physics: const BouncingScrollPhysics(),
                                onPageChanged: (index) {
                                  if (mounted) setState(() => _currentPageIndex = index);
                                },
                                itemCount: pages.length,
                                itemBuilder: (context, pageIndex) {
                                  return _buildGiftGrid(pages[pageIndex], iconSize);
                                },
                              ),
                            ),
                            
                            if (pages.length > 1)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(pages.length, (index) {
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      width: _currentPageIndex == index ? 16 : 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(3),
                                        color: _currentPageIndex == index 
                                            ? const Color(0xFFFFD700) 
                                            : Colors.white12,
                                      ),
                                    );
                                  }),
                                ),
                              ),
                          ],
                        );
                      }
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          if (_selectedGift != null)
            positionedFloatingSendButton(),
        ],
      ),
    ),
  );
}

  Widget _buildGiftGrid(List<GiftModel> gifts, double iconSize) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.65, // Even more vertical space
        crossAxisSpacing: 10,
        mainAxisSpacing: 8, // Reduced spacing
      ),
      itemCount: gifts.length,
      itemBuilder: (context, index) {
        final gift = gifts[index];
        final isSelected = _selectedGift?.id == gift.id;

        return GestureDetector(
          onTap: () {
            if (mounted) {
              setState(() {
                if (_selectedGift?.id != gift.id) {
                  _selectedQuantity = 1;
                }
                _selectedGift = gift;
              });
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Premium Icon Container
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFFD700).withOpacity(0.5) : Colors.white.withOpacity(0.05),
                    width: 1.2,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 1,
                    )
                  ] : [],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Gift Icon/Asset
                    if (gift.iconUrl != null && gift.iconUrl!.isNotEmpty)
                      _buildGiftIcon(gift, iconSize * 0.9)
                    else
                      Text(gift.emoji, style: const TextStyle(fontSize: 32)),

                    // Big Gift Label
                    if (gift.isBigGift)
                      Positioned(
                        top: -10,
                        left: -10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF8A2BE2), Color(0xFF4B0082)]),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                            ]
                          ),
                          child: const Text('BIG', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 4),
              
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  gift.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 10, 
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 4),
              
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.diamond_rounded, size: 11, color: Color(0xFF00BFFF)),
                  const SizedBox(width: 4),
                  Text(
                    '${gift.priceDiamonds > 0 ? gift.priceDiamonds * _selectedQuantity : gift.price * _selectedQuantity}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGiftIcon(GiftModel gift, double size) {
    if (gift.iconUrl!.startsWith('assets/')) {
      return Image.asset(gift.iconUrl!, width: size, height: size, fit: BoxFit.contain);
    }
    return Image.network(
      gift.iconUrl!, 
      width: size, 
      height: size, 
      fit: BoxFit.contain,
      errorBuilder: (c, e, s) => Text(gift.emoji, style: const TextStyle(fontSize: 24)),
    );
  }

  Widget positionedFloatingSendButton() {
    final quantities = [1, 10, 33, 99];
    
    return Positioned(
      bottom: 24, 
      left: 20,
      right: 20,
      child: Row(
        children: [
          // 1. Quantity Pill
          Expanded(
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white10, width: 0.8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: quantities.map((qty) {
                  final isQtySelected = _selectedQuantity == qty;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedQuantity = qty),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // Reduced from 16
                      decoration: BoxDecoration(
                        color: isQtySelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isQtySelected ? const Color(0xFFFFD700).withOpacity(0.5) : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        'x$qty',
                        style: TextStyle(
                          color: isQtySelected ? const Color(0xFFFFD700) : Colors.white60,
                          fontSize: 14,
                          fontWeight: isQtySelected ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(width: 10), // Reduced from 16

          // 2. Send Action
          GestureDetector(
            onTap: _sendGift,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16), // Reduced from 28
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: _isSending
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                    : const Row(
                        children: [
                          Text(
                            'SEND',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.send_rounded, color: Colors.black, size: 20),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extension for easier onTap handling
extension OnTapWidget on Widget {
  Widget onTap(VoidCallback function) {
    return GestureDetector(
      onTap: function,
      child: this,
    );
  }
}
