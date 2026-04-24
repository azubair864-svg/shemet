import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

class EntranceNotificationWidget extends StatefulWidget {
  final String userName;
  final String? userPhoto;
  final int userLevel;
  final bool isVip;
  final VoidCallback onComplete;

  const EntranceNotificationWidget({
    super.key,
    required this.userName,
    this.userPhoto,
    required this.userLevel,
    this.isVip = false,
    required this.onComplete,
  });

  @override
  State<EntranceNotificationWidget> createState() => _EntranceNotificationWidgetState();
}

class _EntranceNotificationWidgetState extends State<EntranceNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();

    // Auto-dismiss after 3 seconds
    Timer(const Duration(seconds: 3), () {
      _dismiss();
    });
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onComplete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Center(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: widget.isVip
                      ? const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  )
                      : LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.black.withOpacity(0.75),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: widget.isVip ? Colors.amber : Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.isVip
                          ? Colors.amber.withOpacity(0.5)
                          : Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Wave emoji
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.isVip
                            ? Colors.white.withOpacity(0.2)
                            : Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '👋',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // User photo
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.isVip ? Colors.amber : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: widget.userPhoto != null
                            ? CachedNetworkImage(
                          imageUrl: widget.userPhoto!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade800,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade800,
                            child: Center(
                              child: Text(
                                widget.userName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )
                            : Container(
                          color: Colors.grey.shade800,
                          child: Center(
                            child: Text(
                              widget.userName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // User info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name
                        Text(
                          widget.userName.length > 15
                              ? '${widget.userName.substring(0, 15)}...'
                              : widget.userName,
                          style: TextStyle(
                            color: widget.isVip ? Colors.white : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 2),

                        // Level and VIP badge
                        Row(
                          children: [
                            Text(
                              'Level ${widget.userLevel}',
                              style: TextStyle(
                                color: widget.isVip
                                    ? Colors.white.withOpacity(0.9)
                                    : Colors.white.withOpacity(0.7),
                                fontSize: 11,
                              ),
                            ),
                            if (widget.isVip) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '💎 VIP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(width: 10),

                    // "joined" text
                    Text(
                      'joined',
                      style: TextStyle(
                        color: widget.isVip
                            ? Colors.white.withOpacity(0.9)
                            : Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Manager class to handle multiple entrance notifications
class EntranceNotificationManager {
  static final List<OverlayEntry> _activeNotifications = [];
  static const int maxNotifications = 3;

  static void show({
    required BuildContext context,
    required String userName,
    String? userPhoto,
    required int userLevel,
    bool isVip = false,
  }) {
    // Remove oldest if max reached
    if (_activeNotifications.length >= maxNotifications) {
      final oldest = _activeNotifications.removeAt(0);
      oldest.remove();
    }

    // Adjust positions for existing notifications
    for (int i = 0; i < _activeNotifications.length; i++) {
      _activeNotifications[i].markNeedsBuild();
    }

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => EntranceNotificationWidget(
        userName: userName,
        userPhoto: userPhoto,
        userLevel: userLevel,
        isVip: isVip,
        onComplete: () {
          entry.remove();
          _activeNotifications.remove(entry);
        },
      ),
    );

    _activeNotifications.add(entry);
    overlay.insert(entry);
  }

  static void clear() {
    for (var entry in _activeNotifications) {
      entry.remove();
    }
    _activeNotifications.clear();
  }
}