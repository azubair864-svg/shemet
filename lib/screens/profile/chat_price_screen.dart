import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

class ChatPriceScreen extends StatefulWidget {
  const ChatPriceScreen({super.key});

  @override
  State<ChatPriceScreen> createState() => _ChatPriceScreenState();
}

class _ChatPriceScreenState extends State<ChatPriceScreen> {
  bool _updating = false;

  final List<Map<String, dynamic>> _priceTiers = [
    {'price': 300, 'minLevel': 0},
    {'price': 600, 'minLevel': 0},
    {'price': 1200, 'minLevel': 0},
    {'price': 1800, 'minLevel': 0},
    {'price': 2400, 'minLevel': 5},
    {'price': 3000, 'minLevel': 6},
    {'price': 3600, 'minLevel': 7},
    {'price': 4200, 'minLevel': 8},
    {'price': 4800, 'minLevel': 8},
    {'price': 5400, 'minLevel': 9},
    {'price': 6000, 'minLevel': 9},
  ];

  Future<void> _updatePrice(int newPrice) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    setState(() => _updating = true);
    
    final success = await userProvider.updateUser({'callRate': newPrice});
    
    if (mounted) {
      setState(() => _updating = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Price updated successfully!'), 
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update price.'), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showPricePicker(BuildContext context, int currentPrice, int userLevel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(top: BorderSide(color: Color(0xFFFF1493), width: 1)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Video Call Price',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _priceTiers.length,
                  itemBuilder: (context, index) {
                    final tier = _priceTiers[index];
                    final int price = tier['price'];
                    final int minLevel = tier['minLevel'];
                    final bool isLocked = userLevel < minLevel;
                    final bool isSelected = currentPrice == price;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFF1493).withOpacity(0.1) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFF1493) : Colors.white10,
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        enabled: !isLocked,
                        onTap: () {
                          Navigator.pop(context);
                          _updatePrice(price);
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isLocked ? Colors.white.withOpacity(0.05) : const Color(0xFFFFD700).withOpacity(0.15),
                          ),
                          child: Text(
                            '🫘', 
                            style: TextStyle(fontSize: 18, color: isLocked ? Colors.grey : null)
                          ),
                        ),
                        title: Text(
                          '$price beans/min',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                            color: isLocked ? Colors.white30 : (isSelected ? const Color(0xFFFF1493) : Colors.white),
                          ),
                        ),
                        trailing: isLocked 
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'LV$minLevel', 
                                style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)
                              ),
                            )
                          : (isSelected ? const Icon(Icons.check_circle, color: Color(0xFFFF1493)) : null),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white38, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;
    final int currentPrice = user?.callRate ?? 1200;
    final int userLevel = user?.level ?? 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Chat Price',
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.5, -0.6),
            radius: 1.5,
            colors: [
              Color(0xFF2D1B4E),
              Color(0xFF000000),
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: [
              // 1. Animated Price Header
              _buildPriceHeader(currentPrice),

              const SizedBox(height: 40),

              // 2. Price Selection Card (Glassmorphic)
              _buildGlassCard(
                onTap: _updating ? null : () => _showPricePicker(context, currentPrice, userLevel),
                child: Column(
                  children: [
                    const Text(
                      'Video Call Price',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF1493),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🫘', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Text(
                          '$currentPrice',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '/min',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white38,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                          ),
                          child: const Icon(Icons.edit_rounded, color: Color(0xFFFFD700), size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    _buildStatusText(),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // 3. The Highest Call Price (Glass Table)
              const Center(
                child: Text(
                  'THE HIGHEST CALL PRICE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFF1493),
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _buildPriceTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceHeader(int currentPrice) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Glow
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF1493).withOpacity(0.2),
                  blurRadius: 50,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
          
          // Bean Icon
          const Text('🫘', style: TextStyle(fontSize: 90)),

          // Floating Price Label
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10, width: 0.5),
              ),
              child: Text(
                '$currentPrice',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16, // Smaller font
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusText() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BulletItem(text: 'Earn beans per second.'),
          _BulletItem(text: 'You can set a higher price when you level up.'),
          _BulletItem(text: 'Determined by the system based on evaluation.'),
        ],
      ),
    );
  }

  Widget _buildPriceTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildTableRow('≤LV4', '1800', isFirst: true),
          _buildTableRow('LV5', '2400'),
          _buildTableRow('LV6', '3000'),
          _buildTableRow('LV7', '3600'),
          _buildTableRow('LV8', '4800'),
          _buildTableRow('≥LV9', '6000', isLast: true),
        ],
      ),
    );
  }

  Widget _buildTableRow(String level, String price, {bool isFirst = false, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast ? BorderSide.none : BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            level,
            style: const TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.bold, 
              color: Colors.white70,
              letterSpacing: 1,
            ),
          ),
          Row(
            children: [
              const Text('🫘', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.w900, 
                  color: Color(0xFFFFD700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, color: Color(0xFFFF1493), size: 6),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13, 
                color: Colors.white.withOpacity(0.6), 
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
