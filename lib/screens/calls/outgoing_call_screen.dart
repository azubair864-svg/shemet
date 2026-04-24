import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../services/call_service.dart';
import '../discover/random_match_call_screen.dart';

/// Outgoing call screen — shown as a compact TOP BANNER overlay.
/// The user can still use the app while waiting for the call to connect.
class OutgoingCallScreen extends StatefulWidget {
  final String callId;
  final String receiverId;
  final String receiverName;
  final String receiverPhoto;
  final int callRate;

  const OutgoingCallScreen({
    super.key,
    required this.callId,
    required this.receiverId,
    required this.receiverName,
    required this.receiverPhoto,
    required this.callRate,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen>
    with SingleTickerProviderStateMixin {
  final CallService _callService = CallService();
  bool _isCancelled = false;
  late Stream<DocumentSnapshot> _callStream;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _callStream = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .snapshots();

    // Pulsing animation for calling indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _cancelCall() async {
    if (_isCancelled) return;
    setState(() => _isCancelled = true);
    await _callService.cancelCall(widget.callId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _callStream,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] as String;

          // ✅ Call accepted → navigate to VideoCallScreen
          if (status == CallStatus.ongoing.name) {
            final token = data['agoraToken'] as String?;
            final channelId = data['agoraChannelId'] as String?;

            if (token != null && channelId != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final receiverUser = UserModel(
                  uid: widget.receiverId,
                  name: widget.receiverName,
                  email: '',
                  photoURL: widget.receiverPhoto,
                  photos: [widget.receiverPhoto],
                  createdAt: DateTime.now(),
                );
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RandomMatchCallScreen(
                      callId: widget.callId,
                      token: token,
                      otherUser: receiverUser,
                      isOutgoing: true,
                      ratePerMinute: widget.callRate,
                    ),
                  ),
                );
              });
            }
            return const SizedBox();
          }

          // ❌ Call rejected → dismiss
          if (status == CallStatus.rejected.name) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.call_end, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Call rejected'),
                      ],
                    ),
                    backgroundColor: Colors.red[700],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
                Navigator.pop(context);
              }
            });
            return const SizedBox();
          }
        }

        // ─── BANNER UI ──────────────────────────────────────────────────
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFFF1493).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Pulsing Avatar
                    ScaleTransition(
                      scale: _pulseAnim,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF1493),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundImage:
                              widget.receiverPhoto.isNotEmpty
                                  ? NetworkImage(widget.receiverPhoto)
                                  : null,
                          backgroundColor: Colors.grey[800],
                          onBackgroundImageError: widget.receiverPhoto.isNotEmpty
                              ? (_, __) {}
                              : null,
                          child: widget.receiverPhoto.isEmpty
                              ? Text(
                                  widget.receiverName.isNotEmpty
                                      ? widget.receiverName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Name + status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.receiverName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF1493),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'Calling...',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              if (widget.callRate > 0) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '💎 ${widget.callRate}/min',
                                  style: const TextStyle(
                                    color: Color(0xFFFF69B4),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Cancel button
                    GestureDetector(
                      onTap: _isCancelled ? null : _cancelCall,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.red.withOpacity(0.5), width: 1),
                        ),
                        child: _isCancelled
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.call_end,
                                color: Colors.red, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
