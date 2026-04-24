import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../../models/user_model.dart';
import '../../models/call_model.dart';
import '../../providers/user_provider.dart';
import '../../services/call_service.dart';
import '../../services/agora_service.dart';
import '../../services/database_service.dart';
import '../../widgets/common/insufficient_balance_popup.dart';
import 'random_match_call_screen.dart';
import '../profile/user_profile_detail_screen.dart';
import '../live/live_stream_view_screen.dart';

class HostLivePreviewScreen extends StatefulWidget {
  final UserModel host;

  const HostLivePreviewScreen({super.key, required this.host});

  @override
  State<HostLivePreviewScreen> createState() => _HostLivePreviewScreenState();
}

class _HostLivePreviewScreenState extends State<HostLivePreviewScreen> {
  final CallService _callService = CallService();
  final AgoraService _agoraService = AgoraService();
  final DatabaseService _databaseService = DatabaseService();
  bool _isProcessingLink = false;
  bool _isHostStreamJoined = false;
  int? _remoteUid;

  @override
  void initState() {
    super.initState();
    _initPreview();
  }

  Future<void> _initPreview() async {
    try {
      final success = await _callService.initialize();
      if (success && mounted) {
        
        // 1. Join Host's Live stream if she is currently Live
        if (widget.host.isLive == true && widget.host.currentStreamId != null) {
          final currentUser = Provider.of<UserProvider>(context, listen: false).currentUser;
          if (currentUser != null) {
            
            // 🛡️ Register event handler to catch the host's UID
            _agoraService.registerEventHandlers(
              onUserJoined: (connection, remoteUid, elapsed) {
                if (mounted) {
                  debugPrint('[PREVIEW_DEBUG] 👥 Host found! UID: $remoteUid');
                  setState(() {
                    _remoteUid = remoteUid;
                  });
                }
              },
              onUserOffline: (connection, remoteUid, reason) {
                if (mounted) {
                  setState(() {
                    if (_remoteUid == remoteUid) _remoteUid = null;
                  });
                }
              },
              onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
                if (state == RemoteVideoState.remoteVideoStateDecoding && mounted) {
                  debugPrint('[PREVIEW_DEBUG] 📹 Rendering host video: $remoteUid');
                  setState(() {
                    _remoteUid = remoteUid;
                  });
                }
              },
            );

            // 🔑 IMPORTANT: Generate actual token for the live channel
            // Use UID 0 to match production spectator pattern
            final token = await _agoraService.generateAgoraToken(
              channelName: widget.host.currentStreamId!,
              uid: 0,
            );

            // 🔗 Join as audience to see the host in the small PIP box
            final joinSuccess = await _agoraService.joinChannel(
              channelId: widget.host.currentStreamId!,
              token: token, 
              uid: 0, 
              isBroadcaster: false,
            );
            
            if (mounted && joinSuccess) {
              setState(() {
                _isHostStreamJoined = true;
                // Note: We WAIT for onUserJoined to set _remoteUid
              });
              
              // 🔄 Progressive Retry Logic:
              // If after 3s we don't have a UID, it might be an engine glitch or stale state.
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted && _isHostStreamJoined && _remoteUid == null) {
                  debugPrint('[PREVIEW_DEBUG] 🔄 UI Timeout: Retrying Agora Listener...');
                  
                  // Re-apply handlers and trigger a re-render
                  _agoraService.registerEventHandlers(
                    onUserJoined: (connection, remoteUid, elapsed) {
                      if (mounted) {
                        debugPrint('[PREVIEW_DEBUG] 👥 Recovery: Host found! UID: $remoteUid');
                        setState(() => _remoteUid = remoteUid);
                      }
                    },
                    onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
                      if (state == RemoteVideoState.remoteVideoStateDecoding && mounted) {
                        debugPrint('[PREVIEW_DEBUG] 📹 Recovery: Rendering host video: $remoteUid');
                        setState(() => _remoteUid = remoteUid);
                      }
                    },
                  );
                  setState(() {}); 
                }
              });

              // 🔄 Final Fallback (6s): If still black, try a hard re-join
              Future.delayed(const Duration(seconds: 6), () {
                if (mounted && _isHostStreamJoined && _remoteUid == null) {
                   debugPrint('[PREVIEW_DEBUG] 🚨 Hard Recovery: Re-joining channel...');
                   _initPreview(); // Recursive call to re-init
                }
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[PREVIEW_ERROR] Error joining host stream: $e');
    }
  }

  @override
  void dispose() {
    if (_isHostStreamJoined) {
      _agoraService.leaveChannel();
    }
    super.dispose();
  }

  void _handleCallPress(UserModel liveHost) async {
    if (_isProcessingLink) return;

    final currentUser = Provider.of<UserProvider>(context, listen: false).currentUser;
    if (currentUser == null) return;

    final int requiredDiamonds = liveHost.callRate ?? 1200;
    if (currentUser.diamonds < requiredDiamonds) {
      _showInsufficientBalance(requiredDiamonds);
      return;
    }

    setState(() => _isProcessingLink = true);
    try {
      final callId = await _callService.initiateCall(
        callerId: currentUser.uid,
        callerName: currentUser.name,
        callerPhoto: currentUser.mainPhoto,
        receiverId: widget.host.uid,
        receiverName: widget.host.name,
        receiverPhoto: widget.host.mainPhoto,
        type: CallType.video,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RandomMatchCallScreen(
              callId: callId,
              otherUser: widget.host,
              isOutgoing: true,
              ratePerMinute: requiredDiamonds,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start call: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingLink = false);
    }
  }

  void _showInsufficientBalance(int rate) {
    showDialog(
      context: context,
      builder: (context) => InsufficientBalancePopup(
        callRate: rate,
        onTopUp: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/recharge');
        },
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileDetailScreen(user: widget.host),
      ),
    );
  }

  void _navigateToLiveStream() {
    if (widget.host.currentStreamId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LiveStreamViewScreen(
            streamId: widget.host.currentStreamId,
            isBroadcaster: false,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: _databaseService.getUserStream(widget.host.uid),
      initialData: widget.host,
      builder: (context, snapshot) {
        final liveHost = snapshot.data ?? widget.host;
        final photoUrl = liveHost.photos.isNotEmpty ? liveHost.photos[0] : '';

        return Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: _navigateToProfile, // 👈 FULL SCREEN NAVIGATION TO PROFILE
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                // 🎥 Static Background (Host Image)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),
                ),

                // 🌑 Vertical Gradient
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                        stops: const [0, 0.2, 0.7, 1],
                      ),
                    ),
                  ),
                ),

                // ⬅️ Back Button
                Positioned(
                  top: 50,
                  left: 20,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    ),
                  ),
                ),

                // 🔴 Live Badge
                if (liveHost.isLive == true)
                  Positioned(
                    top: 55,
                    left: 70,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bar_chart, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Live',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 📹 HOST LIVE STREAM PREVIEW (PIP Box)
                Positioned(
                  top: 55,
                  right: 20,
                  child: GestureDetector(
                    onTap: _navigateToLiveStream, // 👈 TAP TO JOIN LIVE STREAM
                    child: Container(
                      width: 100,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _isHostStreamJoined && _callService.engine != null && _remoteUid != null && _remoteUid != 0
                            ? AgoraVideoView(
                                controller: VideoViewController.remote(
                                  rtcEngine: _callService.engine!,
                                  canvas: VideoCanvas(
                                    uid: _remoteUid!,
                                    renderMode: RenderModeType.renderModeHidden,
                                  ), 
                                  connection: RtcConnection(channelId: liveHost.currentStreamId),
                                ),
                              )
                            : Container(
                                color: Colors.black87,
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF1493)),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),

                // 👤 Host Info
                Positioned(
                  bottom: 60,
                  left: 24,
                  right: 100, // Leave space for call button
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            liveHost.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFF1493), Color(0xFFFF69B4)]),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '★ Lv.${liveHost.level}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            liveHost.countryFlag,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${liveHost.country} | ${liveHost.language}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 📞 CALL BUTTON
                Positioned(
                  bottom: 60,
                  right: 24,
                  child: GestureDetector(
                    onTap: () => _handleCallPress(liveHost),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF1493), Color(0xFFFF69B4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF1493).withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _isProcessingLink
                              ? const Center(child: CircularProgressIndicator(color: Colors.white))
                              : const Icon(Icons.call, color: Colors.white, size: 35),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.diamond, color: Colors.yellow, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${liveHost.callRate ?? 1200}/min',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
