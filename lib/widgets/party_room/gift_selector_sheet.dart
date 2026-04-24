import 'package:flutter/material.dart';
import '../../models/gift_model.dart';

class GiftSelectorSheet extends StatefulWidget {
  final Function(GiftModel) onSendGift;
  final int userDiamonds;

  const GiftSelectorSheet({
    super.key,
    required this.onSendGift,
    required this.userDiamonds,
  });

  @override
  State<GiftSelectorSheet> createState() => _GiftSelectorSheetState();
}

class _GiftSelectorSheetState extends State<GiftSelectorSheet> {
  int _selectedCount = 1;
  GiftModel? _selectedGift;
  final List<GiftModel> _gifts = GiftModel.getDefaultGifts();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[900]!, Colors.black],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Send Gift', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Text('💎', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Text('${widget.userDiamonds}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _gifts.length,
              itemBuilder: (context, index) {
                final gift = _gifts[index];
                final isSelected = _selectedGift?.id == gift.id;
                final canAfford = widget.userDiamonds >= (gift.price * _selectedCount);

                return GestureDetector(
                  onTap: () => setState(() => _selectedGift = gift),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(colors: [Color(0xFFFF1493), Color(0xFFFF69B4)])
                          : LinearGradient(colors: [Colors.grey[800]!, Colors.grey[900]!]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.pink : Colors.white.withOpacity(0.1),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(gift.emoji, style: const TextStyle(fontSize: 36)),
                        const SizedBox(height: 8),
                        Text(gift.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('💎', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 2),
                            Text('${gift.price}', style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _selectedCount > 1 ? () => setState(() => _selectedCount--) : null,
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('x$_selectedCount', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        onPressed: _selectedCount < 99 ? () => setState(() => _selectedCount++) : null,
                        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _selectedGift != null && (widget.userDiamonds >= (_selectedGift!.price * _selectedCount))
                          ? () {
                        widget.onSendGift(_selectedGift!);
                        Navigator.pop(context);
                      }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink,
                        disabledBackgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      child: _selectedGift != null
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Send ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(_selectedGift!.emoji, style: const TextStyle(fontSize: 20)),
                          Text(' x$_selectedCount', style: const TextStyle(color: Colors.white, fontSize: 16)),
                          const SizedBox(width: 8),
                          const Text('💎', style: TextStyle(fontSize: 14)),
                          Text(' ${_selectedGift!.price * _selectedCount}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      )
                          : const Text('Select a Gift', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}