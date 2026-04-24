import 'package:flutter/material.dart';

class RandomChatPopup extends StatelessWidget {
  final int freeCards;
  final VoidCallback onStartChat;

  const RandomChatPopup({
    super.key,
    required this.freeCards,
    required this.onStartChat,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Text(
                  'You have $freeCards 🎴 for free trial.\nAre you sure to start?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF2D3142),
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
                // Random Chat Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onStartChat();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5FD3A6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'Random Chat',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Free',
                          style: TextStyle(fontSize: 14),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.videocam, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Floating Card Icon
          Positioned(
            top: -50,
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                // Simulating the golden cards look with a container or icon
                // In a real app, this would be an SVG or high-res PNG
                color: Colors.transparent,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: -0.2,
                    child: _buildCardIcon(const Color(0xFFFFD700)),
                  ),
                  Transform.rotate(
                    angle: 0.2,
                    child: _buildCardIcon(const Color(0xFFFFE082)),
                  ),
                ],
              ),
            ),
          ),
          // Optional Close button X on the top left of the button (as seen in screenshot)
          /*
          Positioned(
            left: 10,
            top: 10,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.grey),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          */
        ],
      ),
    );
  }

  Widget _buildCardIcon(Color color) {
    return Container(
      width: 60,
      height: 80,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Center(
        child: Text(
          '🎴',
          style: TextStyle(fontSize: 30),
        ),
      ),
    );
  }

  static void show(BuildContext context, {required int freeCards, required VoidCallback onStartChat}) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => RandomChatPopup(
        freeCards: freeCards,
        onStartChat: onStartChat,
      ),
    );
  }
}
