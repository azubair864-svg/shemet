import 'package:dating_live_app/screens/auth/email_login_screen.dart';
import 'package:dating_live_app/screens/auth/phone_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../home/main_screen.dart';
import '../onboarding/gender_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _agreedToTerms = true;
  bool _isLoading = false;

  void _authLog(String message) {
    final n = DateTime.now();
    final ts =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}.${n.millisecond.toString().padLeft(3, '0')}';
    debugPrint('[AUTH_TRACE][$ts][LOGIN_SCREEN] $message');
  }

  @override
  void initState() {
    super.initState();
    _authLog('initState');

    _controller = VideoPlayerController.asset('assets/videos/race_bg_loop.mp4')
      ..initialize()
          .then((_) {
            _controller.setLooping(true);
            _controller.setVolume(0);
            _controller.play();

            if (mounted) {
              setState(() {});
            }
          })
          .catchError((error) {
            _authLog('video init error=$error');
          });

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _authLog(
      'lifecycle=$state videoInitialized=${_controller.value.isInitialized}',
    );
    if (_controller.value.isInitialized) {
      if (state == AppLifecycleState.resumed) {
        _controller.play();
      } else if (state == AppLifecycleState.paused) {
        _controller.pause();
      }
    }
  }

  @override
  void dispose() {
    _authLog('dispose');
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();

    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    final sw = Stopwatch()..start();
    final userProvider = context.read<UserProvider>();
    _authLog(
      'google tap agreed=$_agreedToTerms loading=$_isLoading providerLoading=${userProvider.isLoading}',
    );
    if (!_agreedToTerms) {
      _authLog('google blocked: terms not agreed');
      _showErrorSnackBar('Please agree to terms and conditions');
      return;
    }

    setState(() => _isLoading = true);
    _authLog('google flow start');

    try {
      final authService = AuthService();
      final user = await authService.signInWithGoogle();
      _authLog(
        'google authService result uid=${user?.uid ?? "null"} elapsed=${sw.elapsedMilliseconds}ms',
      );
      if (user == null) {
        if (mounted) {
          _showErrorSnackBar('Google sign-in failed. Please try again.');
          setState(() => _isLoading = false);
        }
        return;
      }

      if (!mounted) {
        return;
      }

      if (!mounted) {
        return;
      }

      await userProvider.initUser();
      if (!mounted) {
        return;
      }
      _authLog(
        'userProvider.initUser done current=${userProvider.currentUser?.uid}',
      );

      // Check profile completion and navigate

      final isComplete = await authService.isProfileComplete();
      _authLog('profileComplete=$isComplete');

      if (!mounted) return;

      if (isComplete) {
        _authLog('navigate -> MainScreen');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      } else {
        _authLog('navigate -> GenderSelectionScreen');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GenderSelectionScreen()),
        );
      }
    } catch (e) {
      _authLog('CRITICAL: login_screen Google exception type=${e.runtimeType} error=$e');
      if (mounted) {
        _showErrorSnackBar('Login failed. Check console for error details.');
        setState(() => _isLoading = false);
      }
    } finally {
      _authLog('google flow end elapsed=${sw.elapsedMilliseconds}ms');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Future<void> _handleStartButton() async {
  //   if (!_agreedToTerms) {
  //     _showErrorSnackBar('Please agree to terms and conditions');
  //     return;
  //   }
  //
  //   setState(() => _isLoading = true);
  //
  //   try {
  //     final authService = AuthService();
  //     await authService.signInAnonymously();
  //
  //     // Wait for auth state
  //     await Future.delayed(const Duration(seconds: 1));
  //
  //     // Check Firebase Auth directly
  //     if (FirebaseAuth.instance.currentUser != null && mounted) {
  //       final isComplete = await authService.isProfileComplete();
  //
  //       if (!mounted) return;
  //
  //       if (isComplete) {
  //         Navigator.pushReplacementNamed(context, '/main');
  //       } else {
  //         Navigator.pushReplacement(
  //           context,
  //           MaterialPageRoute(builder: (_) => GenderSelectionScreen()),
  //         );
  //       }
  //     } else {
  //       _showErrorSnackBar('Failed to sign in');
  //     }
  //   } catch (e) {
  //     if (mounted) _showErrorSnackBar('Error: $e');
  //   } finally {
  //     if (mounted) setState(() => _isLoading = false);
  //   }
  // }

  Future<void> _handlePhoneButton() async {
    _authLog('phone tap agreed=$_agreedToTerms loading=$_isLoading');
    if (!_agreedToTerms) {
      _authLog('phone blocked: terms not agreed');
      _showErrorSnackBar('Please agree to terms and conditions');
      return;
    }

    if (_isLoading) {
      _authLog('phone blocked: loading=true');
      return;
    }

    _authLog('navigate -> PhoneLoginScreen');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
    );
  }

  Future<void> _handleEmailButton() async {
    _authLog('email tap agreed=$_agreedToTerms loading=$_isLoading');
    if (!_agreedToTerms) {
      _authLog('email blocked: terms not agreed');
      _showErrorSnackBar('Please agree to terms and conditions');
      return;
    }

    if (_isLoading) {
      _authLog('email blocked: loading=true');
      return;
    }

    _authLog('navigate -> EmailLoginScreen');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EmailLoginScreen()),
    );
  }

  Future<void> _navigateAfterLogin() async {
    try {
      final authService = AuthService();

      final isComplete = await authService.isProfileComplete();

      if (!mounted) {
        return;
      }

      if (isComplete) {
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => GenderSelectionScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Navigation error: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    _authLog('snackbar="$message"');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      body: Stack(
        children: [
          // Video Background
          _controller.value.isInitialized
              ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                )
              : Container(color: Colors.black),

          // Dark Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(),

                // App Title
                const Text(
                  'Shemet',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 20),

                const Spacer(),

                // Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Column(
                    children: [
                      // Start Button (Anonymous)
                      // _buildButton(
                      //   'Start',
                      //   Colors.white,
                      //   Colors.black,
                      //   _isLoading ? null : _handleStartButton,
                      // ),
                      const SizedBox(height: 16),

                      // Google Button
                      _buildButton(
                        'Google',
                        Colors.pink,
                        Colors.white,
                        (userProvider.isLoading || _isLoading)
                            ? null
                            : _handleGoogleSignIn,
                      ),

                      const SizedBox(height: 16),

                      // Phone Button
                      _buildButton(
                        'Phone',
                        Colors.purple,
                        Colors.white,
                        _isLoading ? null : _handlePhoneButton,
                      ),

                      const SizedBox(height: 16),

                      // Gmail Button
                      _buildButton(
                        'Gmail',
                        Colors.white.withOpacity(0.2),
                        Colors.white,
                        _isLoading ? null : _handleEmailButton,
                      ),

                      const SizedBox(height: 20),

                      // Agreement Checkbox
                      // Agreement Checkbox
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _agreedToTerms = !_agreedToTerms;
                              });
                            },
                            child: Icon(
                              _agreedToTerms
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                                children: [
                                  const TextSpan(text: 'Agree to '),
                                  TextSpan(
                                    text: 'User Agreement',
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Navigator.pushNamed(
                                          context,
                                          '/user_agreement',
                                        );
                                      },
                                  ),
                                  const TextSpan(text: ' & '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Navigator.pushNamed(
                                          context,
                                          '/privacy_policy',
                                        );
                                      },
                                  ),
                                  const TextSpan(
                                    text: ' and confirm I\'m over 18',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Loading Overlay
          if (userProvider.isLoading || _isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildButton(
    String text,
    Color bgColor,
    Color textColor,
    VoidCallback? onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
