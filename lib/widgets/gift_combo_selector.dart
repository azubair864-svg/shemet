import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../models/gift_model.dart';
import '../services/gift_service.dart';

/// ⭐⭐⭐ PRODUCTION-READY GIFT COMBO SELECTOR ⭐⭐⭐
/// Advanced gift selector with quantity multiplier (x1, x10, x99, x520)
/// Features: Categories, animations, combo preview, balance check
class GiftComboSelector extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String recipientId;
  final String recipientName;
  final int userDiamonds;
  final String context; // 'live_stream', 'chat', 'profile'
  final String? contextId;
  final VoidCallback onGiftSent;

  const GiftComboSelector({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.recipientId,
    required this.recipientName,
    required this.userDiamonds,
    required this.context,
    this.contextId,
    required this.onGiftSent,
  });

  @override
  State<GiftComboSelector> createState() => _GiftComboSelectorState();
}

class _GiftComboSelectorState extends State<GiftComboSelector>
    with SingleTickerProviderStateMixin {
  final GiftService _giftService = GiftService();

  late TabController _tabController;
  final List<String> _categories = ['Basic', 'Premium', 'Luxury'];
  List<GiftModel> _allGifts = [];
  GiftModel? _selectedGift;
  int _selectedQuantity = 1;
  final List<int> _quantityOptions = [1, 10, 99, 520];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    
    
    
    
    
    

    _tabController = TabController(length: _categories.length, vsync: this);
    _loadGifts();
  }

  void _loadGifts() {
    
    _allGifts = _giftService.getAvailableGifts();
    
  }

  List<GiftModel> _getGiftsByCategory(String category) {
    if (category == 'Basic') {
      return _allGifts.where((g) => g.price <= 50).toList();
    } else if (category == 'Premium') {
      return _allGifts.where((g) => g.price > 50 && g.price <= 200).toList();
    } else {
      return _allGifts.where((g) => g.price > 200).toList();
    }
  }

  int get _totalCost => (_selectedGift?.price ?? 0) * _selectedQuantity;

  bool get _canAfford => widget.userDiamonds >= _totalCost;

  Future<void> _sendGift() async {
    if (_selectedGift == null) {
      return;
    }

    if (!_canAfford) {
      _showError('Insufficient diamonds! You need $_totalCost diamonds.');
      return;
    }

    setState(() {
      _isSending = true;
    });

    
    
    
    

    try {
      // Send gift multiple times based on quantity
      bool allSuccessful = true;
      for (int i = 0; i < _selectedQuantity; i++) {
        final success = await _giftService.sendGift(
          fromUserId: widget.currentUserId,
          fromUserName: widget.currentUserName,
          toUserId: widget.recipientId,
          toUserName: widget.recipientName,
          gift: _selectedGift!,
          context: widget.context,
          contextId: widget.contextId,
        );

        if (!success) {
          allSuccessful = false;
          
          break;
        }

        
      }

      if (allSuccessful) {
        
        

        if (mounted) {
          _showSuccess('Sent ${_selectedGift!.name} x$_selectedQuantity!');
          Navigator.pop(context);
          widget.onGiftSent();
        }
      } else {
        
        if (mounted) {
          _showError('Some gifts failed to send. Please try again.');
        }
      }
    } catch (e) {
      
      
      
      

      if (mounted) {
        _showError('Failed to send gift: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Send Gift',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Diamond balance
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00BFFF), Color(0xFF1E90FF)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.userDiamonds}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Category Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF1493), Color(0xFFFF69B4)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.5),
              dividerColor: Colors.transparent,
              tabs: _categories.map((cat) => Tab(text: cat)).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Gift Grid
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories.map((category) {
                final gifts = _getGiftsByCategory(category);
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: gifts.length,
                  itemBuilder: (context, index) {
                    final gift = gifts[index];
                    final isSelected = _selectedGift?.id == gift.id;

                    return GestureDetector(
                      onTap: () {
                        
                        setState(() {
                          _selectedGift = gift;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF1493).withOpacity(0.3)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFF1493)
                                : Colors.white.withOpacity(0.1),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Gift icon with Lottie or emoji
                            if (gift.animationUrl != null)
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: Lottie.asset(
                                  gift.animationUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Text(
                                      gift.emoji,
                                      style: const TextStyle(fontSize: 32),
                                    );
                                  },
                                ),
                              )
                            else
                              Text(
                                gift.emoji,
                                style: const TextStyle(fontSize: 32),
                              ),
                            const SizedBox(height: 4),
                            // Gift name
                            Text(
                              gift.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Price
                            const SizedBox(height: 2),
                            Text(
                              '${gift.price}',
                              style: TextStyle(
                                color: const Color(0xFFFFA500),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),

          // Quantity Selector
          if (_selectedGift != null) ...[
            const Divider(color: Colors.white24, height: 1),
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Selected gift preview
                  Row(
                    children: [
                      // Gift icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF1493), Color(0xFFFF69B4)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _selectedGift!.emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Gift info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedGift!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_selectedGift!.price} diamonds each',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quantity options
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _quantityOptions.map((quantity) {
                      final isSelected = _selectedQuantity == quantity;
                      final totalCost = (_selectedGift?.price ?? 0) * quantity;
                      final canAfford = widget.userDiamonds >= totalCost;

                      return Expanded(
                        child: GestureDetector(
                          onTap: canAfford
                              ? () {
                                  setState(() {
                                    _selectedQuantity = quantity;
                                  });
                                }
                              : () {
                                  _showError('Not enough diamonds for x$quantity!');
                                },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF00BFFF),
                                        Color(0xFF1E90FF)
                                      ],
                                    )
                                  : null,
                              color: isSelected
                                  ? null
                                  : canAfford
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF00BFFF)
                                    : canAfford
                                        ? Colors.white.withOpacity(0.2)
                                        : Colors.red.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'x$quantity',
                                  style: TextStyle(
                                    color: canAfford
                                        ? Colors.white
                                        : Colors.red.shade300,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('💎', style: TextStyle(fontSize: 10)),
                                    const SizedBox(width: 2),
                                    Text(
                                      '$totalCost',
                                      style: TextStyle(
                                        color: canAfford
                                            ? Colors.white.withOpacity(0.8)
                                            : Colors.red.shade300,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Send button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canAfford && !_isSending ? _sendGift : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: _canAfford
                            ? const Color(0xFFFF1493)
                            : Colors.grey,
                        disabledBackgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _canAfford
                                  ? 'Send Gift (💎$_totalCost)'
                                  : 'Insufficient Diamonds',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
