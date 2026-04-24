import 'package:flutter/material.dart';
import '../../models/gift_model.dart';
import '../../core/constants/app_colors.dart';

class ChatGiftSelectorSheet extends StatefulWidget {
  final int userDiamonds;
  final Function(GiftModel gift) onSendGift;

  const ChatGiftSelectorSheet({
    super.key,
    required this.userDiamonds,
    required this.onSendGift,
  });

  @override
  State<ChatGiftSelectorSheet> createState() => _ChatGiftSelectorSheetState();
}

class _ChatGiftSelectorSheetState extends State<ChatGiftSelectorSheet> {
  final List<GiftModel> _gifts = [
    GiftModel(id: '1', name: 'Rose', emoji: '🌹', price: 10, category: 'romantic'),
    GiftModel(id: '2', name: 'Heart', emoji: '❤️', price: 20, category: 'romantic'),
    GiftModel(id: '3', name: 'Kiss', emoji: '💋', price: 30, category: 'romantic'),
    GiftModel(id: '4', name: 'Diamond', emoji: '💎', price: 50, category: 'luxury'),
    GiftModel(id: '5', name: 'Crown', emoji: '👑', price: 100, category: 'luxury'),
    GiftModel(id: '6', name: 'Ring', emoji: '💍', price: 200, category: 'luxury'),
    GiftModel(id: '7', name: 'Cake', emoji: '🎂', price: 15, category: 'fun'),
    GiftModel(id: '8', name: 'Ice Cream', emoji: '🍦', price: 12, category: 'fun'),
    GiftModel(id: '9', name: 'Pizza', emoji: '🍕', price: 25, category: 'fun'),
    GiftModel(id: '10', name: 'Coffee', emoji: '☕', price: 8, category: 'casual'),
    GiftModel(id: '11', name: 'Wine', emoji: '🍷', price: 40, category: 'casual'),
    GiftModel(id: '12', name: 'Champagne', emoji: '🍾', price: 80, category: 'luxury'),
    GiftModel(id: '13', name: 'Sports Car', emoji: '🏎️', price: 500, category: 'luxury'),
    GiftModel(id: '14', name: 'Yacht', emoji: '🛥️', price: 1000, category: 'luxury'),
    GiftModel(id: '15', name: 'Castle', emoji: '🏰', price: 5000, category: 'luxury'),
  ];

  String _selectedCategory = 'all';
  GiftModel? _selectedGift;

  List<GiftModel> get _filteredGifts {
    if (_selectedCategory == 'all') return _gifts;
    return _gifts.where((gift) => gift.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2D1B69), Color(0xFF1A0F3D)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Send Gift',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          const Text('💎', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.userDiamonds}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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

          // Categories
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip('all', 'All', '🎁'),
                _buildCategoryChip('romantic', 'Romantic', '❤️'),
                _buildCategoryChip('luxury', 'Luxury', '💎'),
                _buildCategoryChip('fun', 'Fun', '🎉'),
                _buildCategoryChip('casual', 'Casual', '☕'),
              ],
            ),
          ),

          // Gifts Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _filteredGifts.length,
              itemBuilder: (context, index) {
                final gift = _filteredGifts[index];
                final canAfford = widget.userDiamonds >= gift.price;
                return _buildGiftItem(gift, canAfford);
              },
            ),
          ),

          // Send Button
          if (_selectedGift != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onSendGift(_selectedGift!);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _selectedGift!.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Send ${_selectedGift!.name}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${_selectedGift!.price} 💎)',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category, String label, String emoji) {
    final isSelected = _selectedCategory == category;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: [AppColors.primary, Color(0xFFFF1493)])
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftItem(GiftModel gift, bool canAfford) {
    final isSelected = _selectedGift?.id == gift.id;

    return GestureDetector(
      onTap: canAfford
          ? () => setState(() => _selectedGift = gift)
          : null,
      child: Container(
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: [AppColors.primary, Color(0xFFFF1493)])
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: canAfford ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: canAfford ? 0.2 : 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              gift.emoji,
              style: TextStyle(
                fontSize: 32,
                color: canAfford ? null : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              gift.name,
              style: TextStyle(
                color: canAfford ? Colors.white : Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('💎', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 2),
                Text(
                  '${gift.price}',
                  style: TextStyle(
                    color: canAfford ? Colors.amber : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}