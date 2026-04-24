import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/agora_service.dart';

class DiscoverLivePreview extends StatefulWidget {
  final String streamId;
  final String? coverImage;
  final bool isActive; // Only join if this card is currently visible

  const DiscoverLivePreview({
    super.key,
    required this.streamId,
    this.coverImage,
    this.isActive = false,
  });

  @override
  State<DiscoverLivePreview> createState() => _DiscoverLivePreviewState();
}

class _DiscoverLivePreviewState extends State<DiscoverLivePreview> {
  final AgoraService _agoraService = AgoraService();
  bool _isJoined = false;
  int? _remoteUid;
  int _localUid = 0;
  bool _isConnecting = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _startPreview();
    }
  }

  @override
  void didUpdateWidget(DiscoverLivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startPreview();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopPreview();
    }
  }

  Future<void> _startPreview() async {
    if (_isConnecting || _isJoined) return;

    setState(() => _isConnecting = true);
    debugPrint(
      '[PREVIEW_DEBUG] 📺 Starting Permanent Live Preview for ${widget.streamId}',
    );

    try {
      await _agoraService.initialize();

      // 🚀 REGISTER HANDLERS BEFORE JOINING:
      _agoraService.registerEventHandlers(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint(
            '[PREVIEW_DEBUG] ✅ Joined channel: ${widget.streamId} as local UID: ${connection.localUid}',
          );
          if (mounted) {
            setState(() {
              _isJoined = true;
              _localUid = connection.localUid ?? 0;
              _isConnecting = false;
              _startTime = DateTime.now();
            });
          }
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('[PREVIEW_DEBUG] 👤 Remote User Joined: $remoteUid');
          if (mounted) setState(() => _remoteUid = remoteUid);
        },
        onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
          debugPrint(
            '[PREVIEW_DEBUG] 📹 Remote Video state changed: $remoteUid -> ${state.name}',
          );
          if (state == RemoteVideoState.remoteVideoStateDecoding && mounted) {
            setState(() => _remoteUid = remoteUid);
          }
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('[PREVIEW_DEBUG] 👤 Remote User Offline: $remoteUid');
          if (mounted) setState(() => _remoteUid = null);
        },
        onError: (err, msg) {
          debugPrint('[PREVIEW_DEBUG] ❌ Agora Error in Preview: $msg');
          if (mounted) setState(() => _isConnecting = false);
        },
      );

      final token = await _agoraService.generateAgoraToken(
        channelName: widget.streamId,
        uid: 0,
      );

      final success = await _agoraService.joinChannel(
        channelId: widget.streamId,
        token: token,
        uid: 0,
        isBroadcaster: false,
      );

      if (!success && mounted) {
        setState(() => _isConnecting = false);
      }
    } catch (e) {
      debugPrint('[PREVIEW_DEBUG] ❌ preview Error: $e');
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _stopPreview() async {
    debugPrint(
      '[PREVIEW_DEBUG] 🛑 Stopping Live Preview for ${widget.streamId}',
    );
    await _agoraService.leaveChannel();
    if (mounted) {
      setState(() {
        _isJoined = false;
        _remoteUid = null;
        _isConnecting = false;
      });
    }
  }

  @override
  void dispose() {
    if (_isJoined) {
      _agoraService.leaveChannel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Static Cover (Base) - Now padded and clipped
        if (widget.coverImage != null)
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: widget.coverImage!,
                fit: BoxFit.cover,
                memCacheHeight: 1200,
                errorWidget: (context, url, error) =>
                    Container(color: Colors.black),
              ),
            ),
          ),

        // 2. Agora Video View - Padded and clipped to match card shape
        if (_isJoined && _remoteUid != null && _agoraService.engine != null)
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20), // 24 (card) - 4 (padding)
              child: AgoraVideoView(
                key: ValueKey('preview_${widget.streamId}_$_remoteUid'),
                controller: VideoViewController.remote(
                  rtcEngine: _agoraService.engine!,
                  canvas: VideoCanvas(
                    uid: _remoteUid!,
                    renderMode: RenderModeType.renderModeFit,
                  ),
                  connection: RtcConnection(
                    channelId: widget.streamId,
                    localUid: _localUid,
                  ),
                ),
              ),
            ),
          )
        else if (_isConnecting)
          const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),

        // 3. Status Label
        if (widget.isActive)
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isJoined ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isJoined ? 'LIVE' : 'CONNECTING',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
