import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class GuestApplySheet extends StatefulWidget {
  final String roomId;
  final String userId;
  final VoidCallback onApply;

  const GuestApplySheet({
    super.key,
    required this.roomId,
    required this.userId,
    required this.onApply,
  });

  @override
  State<GuestApplySheet> createState() => _GuestApplySheetState();
}

class _GuestApplySheetState extends State<GuestApplySheet> {
  bool _isCameraOn = true;
  bool _isAlreadyRequested = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkExistingRequest();
  }

  Future<void> _checkExistingRequest() async {
    final databaseService = DatabaseService();
    final hasRequest = await databaseService.hasPendingSeatRequest(
      roomId: widget.roomId,
      userId: widget.userId,
    );
    if (mounted) {
      setState(() {
        _isAlreadyRequested = hasRequest;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          // 1. Glass Background
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1A1033).withOpacity(0.95), // Deep Purple
                      const Color(0xFF000000).withOpacity(0.98),
                    ],
                  ),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
                  ),
                ),
              ),
            ),
          ),

          // 2. Content
          Column(
            children: [
              // Handle Bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 24),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              const Text(
                'Apply to be a guest',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              // Camera Toggle Option
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  children: [
                    // Visual check icon
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFA000), // Gold/Orange
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Turn on the camera',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    // Actual Switch
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: _isCameraOn,
                        onChanged: (val) {
                          setState(() {
                            _isCameraOn = val;
                          });
                        },
                        activeThumbColor: const Color(0xFFFFA000),
                        activeTrackColor: const Color(0xFFFFA000).withOpacity(0.3),
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: Colors.white10,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Apply Button
              GestureDetector(
                onTap: (_isChecking || _isAlreadyRequested) ? null : widget.onApply,
                child: Container(
                  margin: const EdgeInsets.all(24),
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: (_isChecking || _isAlreadyRequested)
                        ? [Colors.grey, Colors.grey.shade700]
                        : [const Color(0xFF9C27B0), const Color(0xFF673AB7)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: (_isChecking || _isAlreadyRequested) ? null : [
                      BoxShadow(
                        color: const Color(0xFF9C27B0).withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _isChecking 
                      ? 'Checking...' 
                      : (_isAlreadyRequested ? 'Requested' : 'Apply'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }
}
