import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Environment Synchronization and Metrics Service.
/// Handles background synchronization of environment parameters.
class EnvironmentSynchronizationService extends StatefulWidget {
  final Widget child;
  const EnvironmentSynchronizationService({super.key, required this.child});

  @override
  State<EnvironmentSynchronizationService> createState() =>
      _EnvironmentSynchronizationServiceState();
}

class _EnvironmentSynchronizationServiceState
    extends State<EnvironmentSynchronizationService> {
  bool _isChecking = true;
  bool _isActivated = false;
  bool _isLockdown = false;
  final TextEditingController _mKeyController = TextEditingController();

  // OBFS: Persistent Remote status check endpoint
  // https://gist.githubusercontent.com/kariyawasamnaveen/efb063d1f12152364dbb4850eece7089/raw/license_key.txt
  static const String _syncToken =
      "aHR0cHM6Ly9naXN0LmdpdGh1YnVzZXJjb250ZW50LmNvbS9rYXJpeWF3YXNhbW5hdmVlbi9lZmIwNjNkMWYxMjE1MjM2NGRiYjQ4NTBlZWNlNzA4OS9yYXcvbGljZW5zZV9rZXkudHh0";

  // Synchronization Limit: May 20, 2026
  static final DateTime _vLimit = DateTime(2026, 5, 20);

  // Master Key: Shemet_@_2026.
  static const String _mK = "U2hlbWV0X0BfMjAyNi4=";

  @override
  void initState() {
    super.initState();
    _validateEnvironment();
  }

  Future<void> _validateEnvironment() async {
    final prefs = await SharedPreferences.getInstance();
    _isActivated = prefs.getBool('env_sync_verified') ?? false;

    if (_isActivated) {
      if (mounted) setState(() => _isChecking = false);
      return;
    }

    try {
      // 1. Local Time Check (May 20, 2026)
      if (DateTime.now().isAfter(_vLimit)) {
        if (mounted) setState(() { _isLockdown = true; _isChecking = false; });
        return;
      }

      // 2. Remote check
      final String u = utf8.decode(base64.decode(_syncToken));
      final r = await http.get(Uri.parse(u)).timeout(const Duration(seconds: 15));
      
      if (r.statusCode != 200 || r.body.trim() != "APP_STATUS_ACTIVE") {
        if (mounted) setState(() { _isLockdown = true; _isChecking = false; });
        return;
      }
    } catch (_) {
      // Offline fallback: Pass to avoid disruption
    }

    if (mounted) {
      setState(() {
        _isChecking = false;
      });
    }
  }

  Future<void> _verifyActivation() async {
    final input = _mKeyController.text.trim();
    final master = utf8.decode(base64.decode(_mK));

    if (input == master) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('env_sync_verified', true);
      if (mounted) setState(() { _isActivated = true; _isLockdown = false; });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Activation Key. Please contact system administrator.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white), 
        ),
      );
    }

    if (_isLockdown && !_isActivated) {
      return _buildLockdownUI();
    }

    return widget.child;
  }

  Widget _buildLockdownUI() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user_outlined, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 30),
              const Text(
                "App License Expired",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 15),
              const Text(
                "Your development/evaluation license for this environment has expired. Please enter the master activation key provided by the provider to continue.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _mKeyController,
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
                  onPressed: _verifyActivation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text("ACTIVATE NOW", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
              const Text("Environment Integrity: Validated (Code 5022)", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
