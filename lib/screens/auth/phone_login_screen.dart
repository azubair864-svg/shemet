import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import '../../services/ip_location_service.dart';
import '../../services/auth_service.dart';
import '../onboarding/gender_selection_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  String _selectedCountry = 'Sri Lanka';
  String _selectedFlag = '🇱🇰';
  String _countryCode = '+94';
  String? _verificationId;
  bool _isLoading = false;
  bool _otpSent = false;

  void _authLog(String message) {
    final n = DateTime.now();
    final ts =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}.${n.millisecond.toString().padLeft(3, '0')}';
    debugPrint('[AUTH_TRACE][$ts][PHONE_LOGIN] $message');
  }

  String _normalizePhone(String input) {
    var value = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (value.startsWith('0')) {
      value = value.substring(1);
    }
    return value;
  }

  @override
  void initState() {
    super.initState();
    _authLog('initState');
    _autoDetectCountry();
  }

  Future<void> _autoDetectCountry() async {
    final details = await IpLocationService.detectCountryDetails();
    if (mounted && details['name'] != 'Unknown') {
      setState(() {
        _selectedCountry = details['name']!;
        _countryCode = details['dialCode']!;
        // Extract flag if possible or leave default
      });
    }
  }

  @override
  void dispose() {
    _authLog('dispose');
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final sw = Stopwatch()..start();
    final normalized = _normalizePhone(_phoneController.text.trim());
    _authLog(
      'sendOTP start country=$_selectedCountry code=$_countryCode rawLen=${_phoneController.text.trim().length} normLen=${normalized.length}',
    );
    if (normalized.isEmpty) {
      _authLog('sendOTP validation failed: empty');
      _showSnackBar('Please enter your phone number');
      return;
    }
    if (normalized.length < 7 || normalized.length > 12) {
      _authLog('sendOTP validation failed: invalid length');
      _showSnackBar('Please enter a valid phone number');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final phoneNumber = '$_countryCode$normalized';
    _authLog('verifyPhoneNumber call phone=$phoneNumber');

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          _authLog('verificationCompleted auto credential received');
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _authLog(
            'verificationFailed code=${e.code} message=${e.message} elapsed=${sw.elapsedMilliseconds}ms',
          );
          setState(() {
            _isLoading = false;
          });
          _showSnackBar(_mapPhoneAuthError(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          _authLog(
            'codeSent verificationIdLen=${verificationId.length} resendToken=$resendToken elapsed=${sw.elapsedMilliseconds}ms',
          );
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _isLoading = false;
          });
          _showSnackBar('OTP sent successfully');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _authLog(
            'codeAutoRetrievalTimeout verificationIdLen=${verificationId.length}',
          );
          setState(() {
            _verificationId = verificationId;
          });
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      if (e is FirebaseAuthException) {
        _authLog('sendOTP exception code=${e.code} message=${e.message}');
      } else {
        _authLog('sendOTP exception type=${e.runtimeType} error=$e');
      }

      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error: ${e is FirebaseAuthException ? e.message : e}');
    }
  }

  String _mapPhoneAuthError(FirebaseAuthException e) {
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').toLowerCase();

    if (code == 'operation-not-allowed' ||
        message.contains('region enabled') ||
        message.contains('unable to be sent')) {
      return 'Phone login is not configured for this region yet. Enable Phone Auth and allow this country in Firebase SMS settings.';
    }

    if (code == 'invalid-phone-number') {
      return 'Invalid phone number format.';
    }

    if (code == 'too-many-requests') {
      return 'Too many attempts. Please try again later.';
    }

    return 'Verification failed: ${e.message ?? e.code}';
  }

  Future<void> _verifyOTP() async {
    _authLog(
      'verifyOTP start otpLen=${_otpController.text.trim().length} verificationIdPresent=${_verificationId != null}',
    );
    if (_otpController.text.trim().isEmpty) {
      _authLog('verifyOTP validation failed: empty otp');
      _showSnackBar('Please enter OTP');
      return;
    }

    if (_verificationId == null) {
      _authLog('verifyOTP validation failed: verificationId null');
      _showSnackBar('Verification ID not found. Please resend OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      await _signInWithCredential(credential);
    } catch (e) {
      _authLog('verifyOTP exception type=${e.runtimeType} error=$e');
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Invalid OTP: $e');
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    final sw = Stopwatch()..start();
    _authLog('signInWithCredential start provider=${credential.providerId}');
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      _authLog(
        'signInWithCredential success uid=${userCredential.user?.uid} isNew=${userCredential.additionalUserInfo?.isNewUser} elapsed=${sw.elapsedMilliseconds}ms',
      );

      // Check if new user
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _authService.ensureUserDocument(userCredential.user!);
      } else {
        await _updateLastSeen(userCredential.user!.uid);
      }

      // Check profile complete
      if (mounted) {
        await _navigateAfterLogin();
      }
    } catch (e) {
      _authLog(
        'signInWithCredential exception type=${e.runtimeType} error=$e elapsed=${sw.elapsedMilliseconds}ms',
      );
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Sign in failed: $e');
    }
  }

  Future<void> _updateLastSeen(String userId) async {
    _authLog('_updateLastSeen uid=$userId');
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      });
      _authLog('_updateLastSeen success uid=$userId');
    } catch (e) {
      _authLog('_updateLastSeen exception type=${e.runtimeType} error=$e');
    }
  }

  Future<void> _navigateAfterLogin() async {
    _authLog('_navigateAfterLogin start');
    try {
      final isComplete = await _authService.isProfileComplete();
      _authLog('profileComplete=$isComplete');

      if (!mounted) {
        return;
      }

      if (isComplete) {
        _authLog('navigate -> /main');
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        _authLog('navigate -> GenderSelectionScreen');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => GenderSelectionScreen()),
        );
      }
    } catch (e) {
      _authLog('navigate exception type=${e.runtimeType} error=$e');
    }
  }

  void _showSnackBar(String message) {
    _authLog('snackbar="$message"');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      onSelect: (Country country) {
        setState(() {
          _selectedCountry = country.name;
          _selectedFlag = country.flagEmoji;
          _countryCode = '+${country.phoneCode}';
        });
        _authLog(
          'country selected name=${country.name} code=$_countryCode flag=${country.flagEmoji}',
        );
      },
      countryListTheme: CountryListThemeData(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        inputDecoration: InputDecoration(
          hintText: 'Search country',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
        ),
      ),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                const Text(
                  'Hello',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 120),

                if (!_otpSent) ...[
                  // Country Selector
                  GestureDetector(
                    onTap: _showCountryPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        children: [
                          Text(_selectedFlag, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedCountry,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 15,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Phone Input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _countryCode,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 20,
                          color: Colors.grey.withOpacity(0.3),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(12),
                            ],
                            decoration: InputDecoration(
                              hintText: '00 000 0000',
                              hintStyle: TextStyle(
                                color: Colors.grey.withOpacity(0.6),
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // OTP Input
                  const Text(
                    'Enter OTP',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 22,
                        letterSpacing: 6,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        hintText: '------',
                        hintStyle: TextStyle(
                          color: Colors.grey.withOpacity(0.6),
                          fontSize: 22,
                          letterSpacing: 6,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _isLoading ? null : _sendOTP,
                      child: Text(
                        'Resend OTP',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                // Next Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_otpSent ? _verifyOTP : _sendOTP),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink.withOpacity(0.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _otpSent ? 'Verify' : 'Send OTP',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
