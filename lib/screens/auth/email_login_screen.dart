import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../onboarding/gender_selection_screen.dart';
import '../home/main_screen.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  void _authLog(String message) {
    final n = DateTime.now();
    final ts =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}.${n.millisecond.toString().padLeft(3, '0')}';
    debugPrint('[AUTH_TRACE][$ts][EMAIL_LOGIN] $message');
  }

  @override
  void initState() {
    super.initState();
    _authLog('initState');
  }

  @override
  void dispose() {
    _authLog('dispose');
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final sw = Stopwatch()..start();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    _authLog(
      'submit email=$email passLen=${password.length} localLoading=$_isLoading',
    );

    // Validation
    if (email.isEmpty) {
      _authLog('validation failed: empty email');
      _showSnackBar('Please enter your email');
      return;
    }

    if (!email.contains('@')) {
      _authLog('validation failed: invalid email format');
      _showSnackBar('Please enter a valid email');
      return;
    }

    if (password.isEmpty) {
      _authLog('validation failed: empty password');
      _showSnackBar('Please enter your password');
      return;
    }

    if (password.length < 6) {
      _authLog('validation failed: short password');
      _showSnackBar('Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      _authLog('signInWithEmailPassword call');
      final success = await authProvider.signInWithEmailPassword(
        email,
        password,
      );
      _authLog(
        'signInWithEmailPassword result=$success providerError=${authProvider.errorMessage}',
      );

      if (success) {
        if (mounted) {
          await _navigateAfterLogin();
        }
      } else {
        final lowerError = (authProvider.errorMessage ?? '').toLowerCase();
        final shouldAutoRegister =
            lowerError.contains('user-not-found') ||
            lowerError.contains('no user record') ||
            lowerError.contains('invalid-credential') ||
            lowerError.contains('invalid login credentials') ||
            lowerError.contains('account not found') ||
            lowerError.contains('malformed or has expired');

        if (shouldAutoRegister) {
          _authLog('auto-register path triggered');
          final name = email.split('@')[0];
          final registered = await authProvider.signUpWithEmailPassword(
            email,
            password,
            name,
          );
          _authLog(
            'signUpWithEmailPassword result=$registered providerError=${authProvider.errorMessage}',
          );
          if (registered) {
            if (mounted) {
              await _navigateAfterLogin();
            }
          } else if (mounted) {
            setState(() => _isLoading = false);
            _showSnackBar(
              authProvider.errorMessage ??
                  'Login failed. If this account is new, try Sign Up.',
            );
          }
        } else if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar(
            authProvider.errorMessage ?? 'Invalid email or password',
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _authLog(
        'FirebaseAuthException code=${e.code} message=${e.message} elapsed=${sw.elapsedMilliseconds}ms',
      );
      if (mounted) {
        setState(() => _isLoading = false);

        String errorMessage = 'An error occurred';
        if (e.code == 'wrong-password') {
          errorMessage = 'Incorrect password';
        } else if (e.code == 'user-not-found') {
          errorMessage = 'No account found with this email';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'Email already in use';
        } else if (e.code == 'weak-password') {
          errorMessage = 'Password is too weak';
        } else {
          errorMessage = e.message ?? 'An error occurred';
        }

        _showSnackBar(errorMessage);
      }
    } catch (e) {
      _authLog(
        'exception type=${e.runtimeType} error=$e elapsed=${sw.elapsedMilliseconds}ms',
      );
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error: $e');
      }
    }
    _authLog('submit end elapsed=${sw.elapsedMilliseconds}ms');
  }

  Future<void> _navigateAfterLogin() async {
    _authLog('_navigateAfterLogin start');
    try {
      final isComplete = await _authService.isProfileComplete();
      _authLog('profileComplete=$isComplete');

      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);

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
      _authLog('navigate exception type=${e.runtimeType} error=$e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    _authLog('snackbar="$message"');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB565D8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Title
              const Text(
                'Hello',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Sign in with email or create new account',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),

              const SizedBox(height: 60),

              // Email Input
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Email',
                    hintStyle: const TextStyle(
                      color: Colors.black45,
                      fontSize: 16,
                    ),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Colors.black54,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Password Input
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: const TextStyle(
                      color: Colors.black45,
                      fontSize: 16,
                    ),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Colors.black54,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.black54,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Info Text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.white.withOpacity(0.8),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enter your email and password.\nNew users will be registered automatically.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 60),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF69B4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: Colors.pink.withOpacity(0.4),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
