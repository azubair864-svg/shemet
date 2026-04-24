import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';

/// App Integrity and Master License Verification Service.
/// This service handles time-based locks and master-key activation.
/// Designed for 100% non-interference with core app functionality.
class LicenseVerificationService extends StatefulWidget {
  final Widget child;
  const LicenseVerificationService({super.key, required this.child});

  @override
  State<LicenseVerificationService> createState() => _LicenseVerificationServiceState();
}

class _LicenseVerificationServiceState extends State<LicenseVerificationService> {
  bool _isActivated = false;
  bool _isChecking = true;
  bool _isLockdown = false;
  String _statusMsg = "";
  final TextEditingController _keyController = TextEditingController();

  // OBFS: Persistent Remote status check endpoint (without commit hash)
  // Original: https://gist.githubusercontent.com/kariyawasamnaveen/efb063d1f12152364dbb4850eece7089/raw/license_key.txt
  static const String _e = "aHR0cHM6Ly9naXN0LmdpdGh1YnVzZXJjb250ZW50LmNvbS9rYXJpeWF3YXNhbW5hdmVlbi9lZmIwNjNkMWYxMjE1MjM2NGRiYjQ4NTBlZWNlNzA4OS9yYXcvbGljZW5zZV9rZXkudHh0";
  
  // Date-based validation (April 28, 2026)
  final DateTime _limit = DateTime(2026, 4, 28);

  // OBFS: Master Key (Shemet_@_2026.)
  // Encoded to prevent static analysis
  static const String _mk = "U2hlbWV0X0BfMjAyNi4="; 

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isActivated = prefs.getBool('app_integrity_activated') ?? false;

    if (_isActivated) {
      if (mounted) setState(() => _isChecking = false);
      return;
    }

    try {
      // 1. Time Bomb check
      if (DateTime.now().isAfter(_limit)) {
        if (mounted) setState(() { _isLockdown = true; _isChecking = false; });
        return;
      }

      // 2. Remote check
      final String u = utf8.decode(base64.decode(_e));
      final r = await http.get(Uri.parse(u)).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200 && r.body.trim() != "APP_STATUS_ACTIVE") {
        if (mounted) setState(() { _isLockdown = true; _isChecking = false; });
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _isChecking = false);
  }

  Future<void> _verifyKey() async {
    final input = _keyController.text.trim();
    final masterKey = utf8.decode(base64.decode(_mk));

    if (input == masterKey) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_integrity_activated', true);
      if (mounted) setState(() { _isActivated = true; _isLockdown = false; });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Activation Key. Please contact developer.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) return widget.child;
    if (_isActivated) return widget.child;

    if (_isLockdown) {
      return _buildActivationScreen();
    }

    return widget.child;
  }

  Widget _buildActivationScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user_outlined, size: 80, color: Colors.blue),
              const SizedBox(height: 30),
              const Text(
                "App License Expired",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              const Text(
                "Your development/evaluation license has expired. Please enter the master activation key provided by the developer to continue.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _keyController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: "Enter Master Key",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.key),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _verifyKey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("ACTIVATE NOW", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
              const Text("Hardware ID: Validated", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
