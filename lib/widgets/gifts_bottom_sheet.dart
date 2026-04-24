import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/gift_model.dart';

class GiftsBottomSheet extends StatefulWidget {
  final Function(GiftModel, int) onSendGift;

  const GiftsBottomSheet({super.key, required this.onSendGift});

  // Static show method
  static void show(
      BuildContext context, {
        required Function(GiftModel, int) onSendGift,
      }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GiftsBottomSheet(onSendGift: onSendGift),
    );
  }

  @override
  State<GiftsBottomSheet> createState() => _GiftsBottomSheetState();
}

class _GiftsBottomSheetState extends State<GiftsBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  GiftModel? _selectedGift;
  int _quantity = 1;

  // Use central models
  final List<GiftModel> _popularGifts = GiftModel.getGiftsByCategory('hot');
  final List<GiftModel> _luxuryGifts = GiftModel.getGiftsByCategory('luxury');
  final List<GiftModel> _luckyGifts = GiftModel.getGiftsByCategory('lucky');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).currentUser;
    if (user == null) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = (screenHeight * 0.7).clamp(500.0, 650.0);

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF1A1B30).withOpacity(0.98),
                    const Color(0xFF0F1020).withOpacity(0.96),
                    const Color(0xFF050510).withOpacity(0.98),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.12), width: 0.8),
                ),
              ),
            ),
          ),

          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🎁', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send Gift',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Win diamonds when Big Win starts!',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close, color: Colors.white70, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFFFD700),
                indicatorWeight: 2,
                dividerColor: Colors.transparent,
                labelColor: const Color(0xFFFFD700),
                unselectedLabelColor: Colors.white38,
                indicatorPadding: const EdgeInsets.symmetric(horizontal: 20),
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
                tabs: [
                  Tab(text: 'HOT (${_popularGifts.length})'),
                  Tab(text: 'LUXURY (${_luxuryGifts.length})'),
                  Tab(text: 'LUCKY (${_luckyGifts.length})'),
                ],
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGiftGrid(_popularGifts),
                    _buildGiftGrid(_luxuryGifts),
                    _buildGiftGrid(_luckyGifts),
                  ],
                ),
              ),

              // Bottom Bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.8),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.withOpacity(0.25), width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.diamond, color: Colors.blueAccent, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            '${user.diamonds}',
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 4),

                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildQuantityPill('1'),
                              _buildQuantityPill('9'),
                              _buildQuantityPill('39'),
                              _buildQuantityPill('99'),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    GestureDetector(
                      onTap: _selectedGift != null ? _sendGift : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: _selectedGift != null
                              ? const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: _selectedGift == null ? Colors.white10 : null,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: _selectedGift != null
                              ? [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'SEND',
                              style: TextStyle(
                                color: _selectedGift != null ? Colors.black : Colors.white24,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.send_rounded,
                              color: _selectedGift != null ? Colors.black : Colors.white24,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGiftGrid(List<GiftModel> gifts) {
    final sorted = List<GiftModel>.from(gifts)
      ..sort((a, b) => a.price.compareTo(b.price));
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        return _buildGiftItem(sorted[index]);
      },
    );
  }

  Color _tierColor(int price) {
    if (price <= 1000) return const Color(0xFF4CAF50);
    if (price <= 50000) return const Color(0xFFFFC107);
    return const Color(0xFFFF5252);
  }

  Widget _buildGiftItem(GiftModel gift) {
    final isSelected = _selectedGift?.id == gift.id;
    final tierColor = _tierColor(gift.price);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGift = gift;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF1493) : Colors.white.withOpacity(0.05),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF1493).withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isSelected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF1493),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 10),
                ),
              ),

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    gift.emoji,
                    style: TextStyle(
                      fontSize: 32,
                      shadows: isSelected ? [
                        Shadow(color: Colors.white.withOpacity(0.5), blurRadius: 15)
                      ] : null,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  gift.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withOpacity(0.15) : Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.diamond, color: tierColor, size: 10),
                      const SizedBox(width: 3),
                      Text(
                        _formatPrice(gift.price),
                        style: TextStyle(
                          color: isSelected ? Colors.white : tierColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityPill(String quantity) {
    final isSelected = _quantity.toString() == quantity;

    return GestureDetector(
      onTap: () {
        setState(() {
          _quantity = int.parse(quantity);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          quantity,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white60,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(1)}K';
    }
    return price.toString();
  }

  void _sendGift() {
    if (_selectedGift != null) {
      debugPrint('[GIFT_UI_DEBUG] 🎉 User clicked SEND. Gift: ${_selectedGift!.name}, Qty: $_quantity, Total Price: ${_selectedGift!.price * _quantity}');
      widget.onSendGift(_selectedGift!, _quantity);
      Navigator.pop(context);
    } else {
      debugPrint('[GIFT_UI_DEBUG] ⚠️ SEND clicked but no gift selected.');
    }
  }
}