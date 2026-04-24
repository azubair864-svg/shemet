import 'package:flutter/material.dart';

class GlobalGiftOverlay extends StatefulWidget {
  final Map<String, dynamic> event;
  final VoidCallback onComplete;

  const GlobalGiftOverlay({
    super.key,
    required this.event,
    required this.onComplete,
  });

  @override
  State<GlobalGiftOverlay> createState() => _GlobalGiftOverlayState();
}

class _GlobalGiftOverlayState extends State<GlobalGiftOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: -0.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.easeOutBack)), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.2), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 20),
    ]).animate(_controller);

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 80),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)), weight: 10),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final senderName = widget.event['senderName'] ?? 'User';
    final receiverName = widget.event['receiverName'] ?? 'Someone';
    final giftName = widget.event['giftName'] ?? 'Gift';
    final quantity = widget.event['quantity'] ?? 1;
    final iconUrl = widget.event['iconUrl'];

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return IgnorePointer(
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Align(
                alignment: Alignment(0, _slideAnimation.value),
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF1493).withOpacity(0.8),
                              const Color(0xFFFFD700).withOpacity(0.8),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF1493).withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$senderName sent $giftName to $receiverName!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (iconUrl != null && iconUrl.isNotEmpty && iconUrl.startsWith('http'))
                                  Image.network(iconUrl, width: 48, height: 48)
                                else
                                  Text(
                                    iconUrl ?? '🎁',
                                    style: const TextStyle(fontSize: 48),
                                  ),
                                const SizedBox(width: 12),
                                Text(
                                  'x$quantity',
                                  style: const TextStyle(
                                    color: Colors.yellowAccent,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                    shadows: [Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(2, 2))],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
