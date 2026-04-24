import 'dart:ui' as ui; // Updated import alias
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../main.dart'; // Import for AuthWrapper if needed, but we use named routes usually or direct widget

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _bgFadeAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _liveTextFadeAnimation;

  void _authLog(String message) {
    final n = DateTime.now();
    final ts =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}.${n.millisecond.toString().padLeft(3, '0')}';
    debugPrint('[AUTH_TRACE][$ts][SPLASH] $message');
  }

  @override
  void initState() {
    super.initState();
    _authLog('initState');

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // 1. Background Shapes Fade In (0.5s - 1.5s)
    _bgFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.1, 0.4, curve: Curves.easeIn),
      ),
    );

    // 2. "Dating" Text Slide Up (1.0s - 2.0s)
    _textSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _mainController,
            curve: const Interval(0.25, 0.5, curve: Curves.easeOutCubic),
          ),
        );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.25, 0.5, curve: Curves.easeIn),
      ),
    );

    // 3. "Live" Text Fade In (1.5s - 2.5s)
    _liveTextFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.5, 0.75, curve: Curves.easeIn),
      ),
    );

    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    _authLog('checkAuth start');
    // Wait for the animation to explicitly complete so it's not skipped during engine lag
    await _mainController.forward();
    // Removed 500ms delay to improve startup speed

    if (!mounted) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _authLog('calling userProvider.initUser');
    await userProvider.initUser(); // Ensure init checks are done

    if (!mounted) return;
    _authLog(
      'initUser done isLoggedIn=${userProvider.isLoggedIn} uid=${userProvider.currentUser?.uid}',
    );

    // Smooth Fade Transition
    _authLog('navigate -> AuthWrapper');
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthWrapper(),
        transitionDuration: const Duration(milliseconds: 800),
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
      ),
    );
  }

  @override
  void dispose() {
    _authLog('dispose');
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Abstract Blurred Background Shapes
          FadeTransition(
            opacity: _bgFadeAnimation,
            child: Stack(
              children: [
                Positioned(
                  top: -100,
                  right: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(
                        0xFFFF1493,
                      ).withOpacity(0.15), // Soft Pink
                    ),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  left: -50,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(
                        0xFFFFD700,
                      ).withOpacity(0.1), // Soft Gold
                    ),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Main Typography
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // "She"
                SlideTransition(
                  position: _textSlideAnimation,
                  child: FadeTransition(
                    opacity: _textFadeAnimation,
                    child: const Text(
                      'She',
                      style: TextStyle(
                        fontFamily: 'Inter', // Modern sans-serif
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // "met"
                FadeTransition(
                  opacity: _liveTextFadeAnimation,
                  child: const Text(
                    'met',
                    style: TextStyle(
                      fontFamily: 'GrapeNuts', // Elegant style
                      fontSize: 32,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFFFF1493), // Pink accent
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Minimal Bottom Indicator
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _liveTextFadeAnimation, // Fade in with "Live" text
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
