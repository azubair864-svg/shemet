import 'package:flutter/material.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../../models/live_stream_model.dart';
import '../../models/user_model.dart';
import '../../services/agora_service.dart';
import '../../services/database_service.dart';
import '../../services/aviator_game_service.dart';
import '../../services/dice_game_service.dart';
import '../../widgets/game_selection_widget.dart';
import '../../games/aviator_game_widget.dart';
import '../../games/dice_game_widget.dart';

class LiveBroadcastScreen extends StatefulWidget {
  final String title;
  final String? description;

  const LiveBroadcastScreen({
    super.key,
    required this.title,
    this.description,
  });

  @override
  State<LiveBroadcastScreen> createState() => _LiveBroadcastScreenState();
}

class _LiveBroadcastScreenState extends State<LiveBroadcastScreen> {
  final AgoraService _agoraService = AgoraService();
  final DatabaseService _databaseService = DatabaseService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  LiveStreamModel? _liveStream;
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isMuted = false;
  bool _isCameraOn = true;
  int _viewerCount = 0;
  Timer? _durationTimer;
  int _streamDuration = 0;
  final List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  StreamSubscription? _viewerSubscription;
  
  // Games
  String? _activeGameId;
  bool _isGameOverlayVisible = false;

  @override
  void initState() {
    super.initState();
    _enableScreenshotProtection();
    _initializeBroadcast();
  }

  Future<void> _enableScreenshotProtection() async {
    await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
  }

  @override
  void dispose() {
    _disableScreenshotProtection();
    _durationTimer?.cancel();
    _viewerSubscription?.cancel();
    _chatController.dispose();
    _chatScrollController.dispose();
    _endBroadcast();
    super.dispose();
  }

  Future<void> _disableScreenshotProtection() async {
    await FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
  }

  Future<void> _initializeBroadcast() async {
    debugPrint('[LIVE_DEBUG] 🚀 _initializeBroadcast starting...');
    debugPrint('[LIVE_DEBUG]   - Current User ID: $_currentUserId');

    try {
      // Load current user
      
      _currentUser = await _databaseService.getUserById(_currentUserId);
      

      if (_currentUser == null) {
        
        if (mounted) Navigator.pop(context);
        return;
      }

      // Generate stream ID
      final streamId = 'live_${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}';
      

      // Create live stream model
      _liveStream = LiveStreamModel(
        streamId: streamId,
        hostId: _currentUserId,
        hostName: _currentUser!.name,
        hostPhoto: _currentUser!.photos.isNotEmpty ? _currentUser!.photos[0] : '',
        title: widget.title,
        description: widget.description,
        channelName: streamId,
        startedAt: DateTime.now(),
        viewerCount: 0,
        isActive: true,
      );

      

      // Save to Firestore
      
      await FirebaseFirestore.instance
          .collection('live_streams')
          .doc(streamId)
          .set(_liveStream!.toMap());
      

      // Update user isLive status
      await _databaseService.updateUser(_currentUserId, {'isLive': true});
      
      // VERIFICATION: Check if it actually stuck
      final verifyUser = await _databaseService.getUserById(_currentUserId);
      debugPrint('[LIVE_DEBUG] 📝 Broadcast started. Post-save User State:');
      debugPrint('[LIVE_DEBUG]   - ID: ${verifyUser?.uid}');
      debugPrint('[LIVE_DEBUG]   - isLive: ${verifyUser?.isLive} (type: ${verifyUser?.isLive.runtimeType})');
      debugPrint('[LIVE_DEBUG]   - gender: ${verifyUser?.gender}');
      debugPrint('[LIVE_DEBUG]   - profileComplete: ${verifyUser?.profileComplete}');
      

      // Initialize Agora
      
      await _agoraService.initialize();
      

      // Generate token (using empty token for testing)
      final token = ''; // TODO: Generate from your server
      

      // Join channel as broadcaster
      
      final success = await _agoraService.joinChannel(
        channelId: streamId,
        token: token,
        uid: _currentUserId.hashCode,
        isBroadcaster: true,
      );

      

      if (success) {
        
        _startDurationTimer();
        _listenToViewerCount();

        // 💰 CONNECT GAME SERVICES TO ROOM
        AviatorGameService().setRoomContext(streamId, 'live_stream', isHost: true);
        DiceGameService().setRoomContext(streamId, 'live_stream');

        if (mounted) {
          setState(() => _isLoading = false);
        }
      } else {
        
        throw Exception('Failed to join channel');
      }
    } catch (e) {
      
      
      

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start broadcast: $e')),
        );
        Navigator.pop(context);
      }
    }

    
  }

  void _startDurationTimer() {
    
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _streamDuration++);
      }
    });
  }

  void _listenToViewerCount() {
    

    _viewerSubscription = FirebaseFirestore.instance
        .collection('live_streams')
        .doc(_liveStream!.streamId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        final viewerCount = data?['viewerCount'] ?? 0;

        

        if (mounted) {
          setState(() => _viewerCount = viewerCount);
        }
      }
    });
  }

  Future<void> _endBroadcast() async {
    

    try {
      if (_liveStream != null) {
        

        // Update stream status
        await FirebaseFirestore.instance
            .collection('live_streams')
            .doc(_liveStream!.streamId)
            .update({
          'isActive': false,
          'endedAt': Timestamp.now(),
        });

        
      }

      // Update user isLive status
      
      await _databaseService.updateUser(_currentUserId, {'isLive': false});
      

      // Leave Agora channel
      
      await _agoraService.leaveChannel();
      
    } catch (e) {
      
      
      
    }

    
  }

  void _toggleMute() async {
    
    await _agoraService.toggleMute();
    setState(() => _isMuted = !_isMuted);
    
  }

  void _toggleCamera() async {
    
    // TODO: Implement camera toggle when video support is added
    setState(() => _isCameraOn = !_isCameraOn);
    
  }

  void _switchCamera() async {
    
    // TODO: Implement camera switch when video support is added
    
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Starting live stream...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video preview (full screen)
            _buildVideoPreview(),

            // Top bar
            _buildTopBar(),

            // Chat overlay
            _buildChatOverlay(),

            // Bottom controls
            _buildBottomControls(),

            // Game Overlay
            _buildGameOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverlay() {
    if (!_isGameOverlayVisible || _activeGameId == null) return const SizedBox.shrink();

    Widget? gameWidget;

    if (_activeGameId == 'aviator') {
      gameWidget = AviatorGameWidget(onClose: _closeGame);
    } else if (_activeGameId == 'dice') {
      gameWidget = DiceGameWidget(onClose: _closeGame);
    }

    if (gameWidget == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 80, 
      left: 10, 
      right: 10,
      child: gameWidget,
    );
  }

  void _closeGame() async {
    if (_liveStream != null) {
      await _databaseService.stopRoomGame(
        roomId: _liveStream!.streamId,
        context: 'live_stream',
      );
    }

    setState(() {
      _activeGameId = null;
      _isGameOverlayVisible = false;
    });
  }

  Widget _buildVideoPreview() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Center(
        child: Icon(
          _isCameraOn ? Icons.videocam : Icons.videocam_off,
          size: 100,
          color: Colors.white30,
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Row(
        children: [
          // Live indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Viewer count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.visibility, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$_viewerCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Duration
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _formatDuration(_streamDuration),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),

          // Close button
          IconButton(
            onPressed: () async {
              
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('End Live Stream?'),
                  content: const Text(
                    'Are you sure you want to end this live stream?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        
                        Navigator.pop(context, false);
                      },
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        
                        Navigator.pop(context, true);
                      },
                      child: const Text(
                        'End',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true && mounted) {
                
                await _endBroadcast();
                if (mounted) Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildChatOverlay() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 120,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 200),
        child: ListView.builder(
          controller: _chatScrollController,
          shrinkWrap: true,
          itemCount: _chatMessages.length,
          itemBuilder: (context, index) {
            final message = _chatMessages[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${message['userName']}: ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: message['message'],
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: Row(
          children: [
            // Mute button
            IconButton(
              onPressed: _toggleMute,
              icon: Icon(
                _isMuted ? Icons.mic_off : Icons.mic,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 8),

            // Camera toggle
            IconButton(
              onPressed: _toggleCamera,
              icon: Icon(
                _isCameraOn ? Icons.videocam : Icons.videocam_off,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 8),

            // Switch camera
            IconButton(
              onPressed: _switchCamera,
              icon: const Icon(
                Icons.flip_camera_android,
                color: Colors.white,
                size: 28,
              ),
            ),
            const Spacer(),

            // Game button
            IconButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => GameSelectionWidget(
                    onGameSelected: (gameId) async {
                      Navigator.pop(context); // Close bottom sheet
                      
                      if (_liveStream != null) {
                        // All Vieers will sync automatically via Firestore listener
                        await _databaseService.startRoomGame(
                          roomId: _liveStream!.streamId,
                          gameId: gameId,
                          crashPoint: 0.0,
                          context: 'live_stream',
                        );
                        
                        setState(() {
                          _activeGameId = gameId;
                          _isGameOverlayVisible = true;
                        });
                      }
                    },
                  ),
                );
              },
              icon: const Icon(
                Icons.games_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 8),

            // Gift button
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Viewers can send you gifts!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(
                Icons.card_giftcard,
                color: Colors.white54,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
