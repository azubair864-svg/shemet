import 'package:flutter/material.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:deepar_flutter_plus/deepar_flutter_plus.dart' as deepar;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../services/live_stream_service.dart';
import '../../services/database_service.dart';
import '../../services/gift_service.dart';
import '../../models/live_stream_model.dart';
import '../../services/agora_service.dart';
import '../../services/aviator_game_service.dart';
import '../../services/dice_game_service.dart';
import '../../widgets/game_selection_widget.dart';
import '../../games/aviator_game_widget.dart';
import '../../games/dice_game_widget.dart';
import '../../games/car_racing_game_widget.dart';

class BroadcasterScreen extends StatefulWidget {
  final String? preCreatedStreamId;
  final String? title;
  final String? description;
  final List<String>? tags;

  const BroadcasterScreen({
    super.key,
    this.preCreatedStreamId,
    this.title,
    this.description,
    this.tags,
  });

  @override
  State<BroadcasterScreen> createState() => _BroadcasterScreenState();
}

class _BroadcasterScreenState extends State<BroadcasterScreen> {
  final LiveStreamService _liveStreamService = LiveStreamService();
  final DatabaseService _databaseService = DatabaseService();
  final GiftService _giftService = GiftService();
  final TextEditingController _messageController = TextEditingController();

  final AgoraService _agoraService = AgoraService();
  String? _streamId;
  LiveStreamModel? _currentStream;
  bool _isInitialized = false;
  bool _isBroadcasting = false;
  bool _isCameraOn = true;
  bool _isMicOn = true;
  bool _isFrontCamera = true;

  // Games Module State
  String? _activeGameId;
  bool _isGameOverlayVisible = false;
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _enableScreenshotProtection();
    _initializeBroadcaster();
  }

  Future<void> _enableScreenshotProtection() async {
    await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
  }

  Future<void> _initializeBroadcaster() async {
    try {
      final cameraPermission = await Permission.camera.request();
      final micPermission = await Permission.microphone.request();

      if (!cameraPermission.isGranted || !micPermission.isGranted) {
        _showError('Camera and microphone permissions required');
        return;
      }

      if (widget.preCreatedStreamId != null) {
        _streamId = widget.preCreatedStreamId;
      } else {
        _streamId = await _liveStreamService.createLiveStream(
          title: widget.title ?? 'Live Stream',
          description: widget.description,
          tags: widget.tags ?? [],
        );

        if (_streamId == null) {
          _showError('Failed to create live stream');
          return;
        }
      }

      _currentStream = await _liveStreamService.getLiveStream(_streamId!);
      if (_currentStream == null) {
        _showError('Failed to load stream');
        return;
      }

      await _initializeAgora();
      _listenToStreamUpdates();

      // 💰 CONNECT GAME SERVICES TO ROOM
      AviatorGameService().setRoomContext(_streamId, 'live_stream', isHost: true);
      DiceGameService().setRoomContext(_streamId, 'live_stream');

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      _showError('Initialization failed: $e');
    }
  }

  Future<void> _initializeAgora() async {
    if (!_agoraService.isInitialized) {
      await _agoraService.initialize();
    }

    await _agoraService.requestCameraControl(CameraOwner.deepAr);
    
    _agoraService.engine?.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() {
            _isBroadcasting = true;
          });
        },
      ),
    );
  }

  void _listenToStreamUpdates() {
    if (_streamId == null) return;
    _statusSubscription?.cancel();
    _statusSubscription = FirebaseFirestore.instance
        .collection('live_streams')
        .doc(_streamId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data();
      if (data == null) return;

      final activeGame = data['activeGame'] as Map<String, dynamic>?;
      if (activeGame != null) {
        setState(() {
          _activeGameId = activeGame['gameId'];
          _isGameOverlayVisible = true;
        });
      } else {
        if (_activeGameId == null) {
          setState(() {
            _isGameOverlayVisible = false;
          });
        }
      }
    });
  }

  Future<void> _startBroadcasting() async {
    try {
      if (_streamId == null || _currentStream == null) return;

      await _agoraService.requestCameraControl(CameraOwner.agora);
      final token = await _agoraService.generateAgoraToken(
        channelName: _currentStream!.channelName,
        uid: 0,
      );

      await _agoraService.joinChannel(
        token: token,
        channelId: _currentStream!.channelName,
        uid: 0, 
      );
      
      final success = await _liveStreamService.startBroadcasting(_streamId!);
      if (!success) {
        _showError('Failed to start broadcasting');
        return;
      }

      setState(() {
        _isBroadcasting = true;
      });
      _showSuccess('You are now LIVE!');
    } catch (e) {
      _showError('Failed to start: $e');
    }
  }

  Future<void> _stopBroadcasting() async {
    try {
      await _agoraService.engine?.leaveChannel();
      if (_streamId != null) {
        await _liveStreamService.stopBroadcasting(_streamId!);
      }
      
      setState(() {
        _isBroadcasting = false;
      });

      // Fetch Summary
      final summary = await _databaseService.getRoomSessionSummary(
        _streamId!,
        context: 'live_stream',
      );

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/party_end',
          (route) => false,
          arguments: summary.isNotEmpty ? summary : {
            'duration': '00:00:00',
            'totalVisitors': 0,
            'giftEarnings': 0,
            'gameEarnings': 0,
          },
        );
      }
    } catch (e) {
      debugPrint('Error stopping broadcast: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _switchCamera() async {
    if (!_isCameraOn) return;
    try {
      await _agoraService.engine?.switchCamera();
      setState(() {
        _isFrontCamera = !_isFrontCamera;
      });
    } catch (e) {
      debugPrint('Error switching camera: $e');
    }
  }

  Future<void> _toggleCamera() async {
    try {
      if (_isCameraOn) {
        await _agoraService.engine?.disableVideo();
      } else {
        await _agoraService.engine?.enableVideo();
      }
      setState(() {
        _isCameraOn = !_isCameraOn;
      });
    } catch (e) {
      debugPrint('Error toggling camera: $e');
    }
  }

  Future<void> _toggleMicrophone() async {
    try {
      if (_isMicOn) {
        await _agoraService.mute();
      } else {
        await _agoraService.unmute();
      }
      setState(() {
        _isMicOn = !_isMicOn;
      });
    } catch (e) {
      debugPrint('Error toggling mic: $e');
    }
  }

  void _showGamesMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GameSelectionWidget(
        onGameSelected: (gameId) async {
          if (_streamId != null) {
            await _databaseService.startRoomGame(
              roomId: _streamId!,
              gameId: gameId,
              crashPoint: 0.0,
              context: 'live_stream',
            );
          }
          setState(() {
            _activeGameId = gameId;
            _isGameOverlayVisible = true;
          });
        },
      ),
    );
  }

  void _closeGame() async {
    if (_streamId != null) {
      await _databaseService.stopRoomGame(
        roomId: _streamId!,
        context: 'live_stream',
      );
    }
    setState(() {
      _isGameOverlayVisible = false;
      _activeGameId = null;
    });
  }

  Widget _buildGameOverlay() {
    if (!_isGameOverlayVisible || _activeGameId == null) return const SizedBox.shrink();

    Widget? gameWidget;
    if (_activeGameId == 'aviator') {
      gameWidget = AviatorGameWidget(onClose: _closeGame);
    } else if (_activeGameId == 'dice') {
      gameWidget = DiceGameWidget(onClose: _closeGame);
    } else if (_activeGameId == 'racing') {
      gameWidget = CarRacingGameWidget(
        onClose: _closeGame,
        userDiamonds: 0, // Broadcaster doesn't play
        onDiamondUpdate: (_) {},
      );
    }

    if (gameWidget == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 120,
      left: 10,
      right: 10,
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: 350,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_activeGameId!.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: _closeGame, visualDensity: VisualDensity.compact),
                  ],
                ),
              ),
              Expanded(child: gameWidget),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _streamId == null) return;
    _messageController.clear();
    final currentUser = FirebaseAuth.instance.currentUser;
    await _databaseService.sendLiveStreamMessage(
      streamId: _streamId!,
      senderId: currentUser?.uid ?? '',
      senderName: currentUser?.displayName ?? 'Host',
      senderPhoto: currentUser?.photoURL ?? '',
      text: text,
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
    }
  }

  @override
  void dispose() {
    _disableScreenshotProtection();
    _statusSubscription?.cancel();
    _messageController.dispose();
    if (_isBroadcasting) {
      _stopBroadcasting();
    }
    _agoraService.requestCameraControl(CameraOwner.none);
    _agoraService.engine?.leaveChannel();
    super.dispose();
  }

  Future<void> _disableScreenshotProtection() async {
    await FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: !_isBroadcasting,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('End Live Stream?'),
            content: const Text('Are you sure you want to end this live stream?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('End Stream', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (confirm == true) await _stopBroadcasting();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Camera Preview
            if (_isCameraOn)
              SizedBox.expand(
                child: (_agoraService.currentOwner == CameraOwner.deepAr && _agoraService.deepArController != null)
                  ? deepar.DeepArPreviewPlus(_agoraService.deepArController!)
                  : AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _agoraService.engine!,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
              )
            else
              Container(color: Colors.black, child: const Center(child: Icon(Icons.videocam_off, size: 100, color: Colors.white54))),

            // Top Bar
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.7), Colors.transparent])),
                child: SafeArea(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: _isBroadcasting ? Colors.red : Colors.grey, borderRadius: BorderRadius.circular(20)),
                        child: Text(_isBroadcasting ? 'LIVE' : 'PREVIEW', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
              ),
            ),

            // Controls
            Positioned(
              right: 16, top: MediaQuery.of(context).size.height * 0.4,
              child: Column(
                children: [
                  _controlBtn(icon: Icons.flip_camera_ios, onTap: _switchCamera),
                  const SizedBox(height: 16),
                  _controlBtn(icon: _isCameraOn ? Icons.videocam : Icons.videocam_off, onTap: _toggleCamera),
                  const SizedBox(height: 16),
                  _controlBtn(icon: _isMicOn ? Icons.mic : Icons.mic_off, onTap: _toggleMicrophone),
                  const SizedBox(height: 16),
                  _controlBtn(icon: Icons.games, onTap: _showGamesMenu),
                ],
              ),
            ),

            // Bottom
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: SafeArea(
                  child: !_isBroadcasting
                    ? ElevatedButton(onPressed: _startBroadcasting, style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent), child: const Text('GO LIVE'))
                    : Row(
                        children: [
                          Expanded(child: TextField(controller: _messageController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Say something...', hintStyle: TextStyle(color: Colors.white54)))),
                          IconButton(icon: const Icon(Icons.send, color: Colors.pinkAccent), onPressed: _sendMessage),
                        ],
                      ),
                ),
              ),
            ),

            // Game Overlay
            _buildGameOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _controlBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
