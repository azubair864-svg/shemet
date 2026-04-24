import 'package:flutter/material.dart';

class LiveScanAnim extends StatefulWidget {
  const LiveScanAnim({super.key});

  @override
  State<LiveScanAnim> createState() => _LiveScanAnimState();
}

class _LiveScanAnimState extends State<LiveScanAnim> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Subtle pulse
            Opacity(
              opacity: 0.05 + (0.05 * _controller.value),
              child: Container(color: Colors.white),
            ),
            // Moving scan line
            Positioned(
              top: MediaQuery.of(context).size.height * _controller.value,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF1493).withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
