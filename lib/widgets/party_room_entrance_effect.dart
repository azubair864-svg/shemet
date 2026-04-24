import 'package:flutter/material.dart';

class PartyRoomEntranceEffect extends StatefulWidget {
  final String userName;
  final String? userPhoto;
  final int userLevel;
  final bool isVip;
  final VoidCallback? onComplete;

  const PartyRoomEntranceEffect({
    super.key,
    required this.userName,
    this.userPhoto,
    required this.userLevel,
    this.isVip = false,
    this.onComplete,
  });

  @override
  State<PartyRoomEntranceEffect> createState() =>
      _PartyRoomEntranceEffectState();
}

class _PartyRoomEntranceEffectState extends State<PartyRoomEntranceEffect>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Slide from right
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    // Fade out
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeIn,
      ),
    );

    _startAnimation();
  }

  void _startAnimation() async {
    await _slideController.forward();
    await Future.delayed(const Duration(milliseconds: 2000));
    await _fadeController.forward();

    if (widget.onComplete != null) {
      widget.onComplete!();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 100),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: widget.isVip
                  ? const LinearGradient(
                colors: [
                  Color(0xFFFFD700),
                  Color(0xFFFFA500),
                ],
              )
                  : LinearGradient(
                colors: [
                  const Color(0xFF9B6FD7).withOpacity(0.9),
                  const Color(0xFFFF69B4).withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: widget.isVip
                      ? const Color(0xFFFFD700).withOpacity(0.6)
                      : const Color(0xFF9B6FD7).withOpacity(0.6),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // User avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.purple.shade300,
                    backgroundImage: widget.userPhoto != null &&
                        widget.userPhoto!.isNotEmpty
                        ? NetworkImage(widget.userPhoto!)
                        : null,
                    child: widget.userPhoto == null || widget.userPhoto!.isEmpty
                        ? const Icon(Icons.person, color: Colors.white, size: 22)
                        : null,
                  ),
                ),

                const SizedBox(width: 12),

                // User info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Username
                    Text(
                      widget.userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            offset: Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 2),

                    // "joined the room"
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Level badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Lv${widget.userLevel}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),

                        Text(
                          'joined the room',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(width: 12),

                // VIP icon or entrance icon
                if (widget.isVip)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
                      color: Colors.white,
                      size: 20,
                    ),
                  )
                else
                  const Text('✨', style: TextStyle(fontSize: 20)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void show({
    required BuildContext context,
    required String userName,
    String? userPhoto,
    required int userLevel,
    bool isVip = false,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => PartyRoomEntranceEffect(
        userName: userName,
        userPhoto: userPhoto,
        userLevel: userLevel,
        isVip: isVip,
        onComplete: () {
          entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }
}