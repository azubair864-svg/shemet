import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user_model.dart';

class MatchPopup {
  static void show(
    BuildContext context, {
    required UserModel currentUser,
    required UserModel matchedUser,
    VoidCallback? onSendMessage,
    VoidCallback? onKeepSwiping,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => _MatchPopupContent(
        currentUser: currentUser,
        matchedUser: matchedUser,
        onSendMessage: onSendMessage,
        onKeepSwiping: onKeepSwiping,
      ),
    );
  }
}

class _MatchPopupContent extends StatefulWidget {
  final UserModel currentUser;
  final UserModel matchedUser;
  final VoidCallback? onSendMessage;
  final VoidCallback? onKeepSwiping;

  const _MatchPopupContent({
    required this.currentUser,
    required this.matchedUser,
    this.onSendMessage,
    this.onKeepSwiping,
  });

  @override
  State<_MatchPopupContent> createState() => _MatchPopupContentState();
}

class _MatchPopupContentState extends State<_MatchPopupContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            width: size.width * 0.9,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF6B9D),
                  Color(0xFFFF8FAB),
                  Color(0xFFFFA3C7),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 30),

                // "IT'S A MATCH!" Text
                const Text(
                  "IT'S A MATCH!",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 10),

                // Subtitle
                Text(
                  'You and ${widget.matchedUser.name} liked each other!',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 30),

                // Photos Section
                SizedBox(
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Current User Photo (Left)
                      Positioned(
                        left: 20,
                        child: _buildPhotoCircle(
                          widget.currentUser.mainPhoto ??
                              'https://via.placeholder.com/150',
                          isLeft: true,
                        ),
                      ),

                      // Matched User Photo (Right)
                      Positioned(
                        right: 20,
                        child: _buildPhotoCircle(
                          widget.matchedUser.mainPhoto ??
                              'https://via.placeholder.com/150',
                          isLeft: false,
                        ),
                      ),

                      // Heart Icon in Center
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.pink.withOpacity(0.5),
                              blurRadius: 15,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Color(0xFFFF6B9D),
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Send Message Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onSendMessage?.call();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFFF6B9D),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'SEND MESSAGE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Keep Swiping Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onKeepSwiping?.call();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                              side: const BorderSide(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                          child: const Text(
                            'KEEP SWIPING',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCircle(String imageUrl, {required bool isLeft}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(isLeft ? -50 * (1 - value) : 50 * (1 - value), 0),
          child: Transform.scale(scale: value, child: child),
        );
      },
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.person, size: 60),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple version without animations (lightweight)
class SimpleMatchPopup {
  static void show(
    BuildContext context, {
    required String currentUserPhoto,
    required String matchedUserName,
    required String matchedUserPhoto,
    VoidCallback? onSendMessage,
    VoidCallback? onKeepSwiping,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFF6B9D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "IT'S A MATCH!",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You matched with $matchedUserName',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Icon(Icons.favorite, color: Colors.white, size: 60),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onSendMessage?.call();
            },
            child: const Text(
              'SEND MESSAGE',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onKeepSwiping?.call();
            },
            child: const Text(
              'KEEP SWIPING',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
