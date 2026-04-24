import 'package:agora_rtc_engine/agora_rtc_engine.dart';
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
import '../../widgets/gifts_bottom_sheet.dart';
import '../../widgets/game_selection_widget.dart';
import '../../games/aviator_game_widget.dart';
import '../../games/dice_game_widget.dart';
import '../../games/car_racing_game_widget.dart';

class LiveViewerScreen extends StatefulWidget {
  final LiveStreamModel liveStream;

  const LiveViewerScreen({super.key, required this.liveStream});

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> {
  final AgoraService _agoraService = AgoraService();
  final DatabaseService _databaseService = DatabaseService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  UserModel? _currentUser;
  UserModel? _hostUser;
  bool _isLoading = true;
  bool _isMuted = false;
  int _viewerCount = 0;

  // Games
  String? _activeGameId;
  bool _isGameOverlayVisible = false;

  final List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  StreamSubscription? _streamSubscription;
  StreamSubscription? _chatSubscription;
  Timer? _viewerUpdateTimer;

  @override
  void initState() {
    super.initState();
    _enableScreenshotProtection();
    _initializeViewer();
  }

  Future<void> _enableScreenshotProtection() async {
    await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
  }

  @override
  void dispose() {
    _disableScreenshotProtection();
    _streamSubscription?.cancel();
    _chatSubscription?.cancel();
    _viewerUpdateTimer?.cancel();
    _chatController.dispose();
    _chatScrollController.dispose();
    _leaveStream();
    super.dispose();
  }

  Future<void> _disableScreenshotProtection() async {
    await FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
  }

  Future<void> _initializeViewer() async {
    try {
      // Load current user

      _currentUser = await _databaseService.getUserById(_currentUserId);

      // Load host user

      _hostUser = await _databaseService.getUserById(widget.liveStream.hostId);

      if (_currentUser == null || _hostUser == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      // Increment viewer count

      await _incrementViewerCount();

      // Initialize Agora

      await _agoraService.initialize();

      // Generate token
      final token = ''; // TODO: Generate from server

      // Join channel as audience

      final success = await _agoraService.joinChannel(
        channelId: widget.liveStream.streamId,
        token: token,
        uid: _currentUserId.hashCode,
        isBroadcaster: false, // Viewer = audience
      );

      if (success) {
        // 💰 CONNECT GAME SERVICES TO ROOM
        AviatorGameService().setRoomContext(
          widget.liveStream.streamId,
          'live_stream',
          isHost: false,
        );
        DiceGameService().setRoomContext(
          widget.liveStream.streamId,
          'live_stream',
        );

        _listenToStreamUpdates();
        _listenToChat();
        _startViewerUpdateTimer();

        if (mounted) {
          setState(() => _isLoading = false);
        }
      } else {
        throw Exception('Failed to join stream');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to join stream: $e')));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _incrementViewerCount() async {
    try {
      await FirebaseFirestore.instance
          .collection('live_streams')
          .doc(widget.liveStream.streamId)
          .update({'viewerCount': FieldValue.increment(1)});
    } catch (e) {}
  }

  Future<void> _decrementViewerCount() async {
    try {
      await FirebaseFirestore.instance
          .collection('live_streams')
          .doc(widget.liveStream.streamId)
          .update({'viewerCount': FieldValue.increment(-1)});
    } catch (e) {}
  }

  void _startViewerUpdateTimer() {
    // Update presence every 30 seconds
    _viewerUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateViewerPresence();
    });
  }

  Future<void> _updateViewerPresence() async {
    try {
      await FirebaseFirestore.instance
          .collection('live_streams')
          .doc(widget.liveStream.streamId)
          .collection('viewers')
          .doc(_currentUserId)
          .set({
            'userId': _currentUserId,
            'userName': _currentUser?.name ?? 'Unknown',
            'userPhoto': _currentUser?.photos.isNotEmpty == true
                ? _currentUser!.photos[0]
                : '',
            'lastSeen': Timestamp.now(),
          }, SetOptions(merge: true));
    } catch (e) {}
  }

  void _listenToStreamUpdates() {
    _streamSubscription = FirebaseFirestore.instance
        .collection('live_streams')
        .doc(widget.liveStream.streamId)
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists) {
            _onStreamEnded();
            return;
          }

          final data = snapshot.data();
          final isActive = data?['isActive'] ?? false;
          final viewerCount = data?['viewerCount'] ?? 0;

          if (!isActive) {
            _onStreamEnded();
            return;
          }

          // --- NEW: Gaming Sync ---
          if (mounted) {
            final dynamic rawActiveGame = data?['activeGame'];
            if (rawActiveGame != null && rawActiveGame is Map) {
              final String? gameId = rawActiveGame['gameId']?.toString();
              if (gameId != null && gameId.isNotEmpty) {
                if (_activeGameId != gameId) {
                  debugPrint(
                    '[DEBUG_SYNC] 🎮 Game Found in Live Stream: $gameId',
                  );
                  setState(() {
                    _activeGameId = gameId;
                    _isGameOverlayVisible = true;
                  });
                }

                // 🚀 TRIGGER SYNC IN SERVICES
                if (gameId == 'aviator') {
                  AviatorGameService().syncWithFirestore(
                    rawActiveGame as Map<String, dynamic>,
                  );
                }
              }
            } else {
              if (_activeGameId != null) {
                debugPrint('[DEBUG_SYNC] 🛑 Game Cleared in Live Stream');
                setState(() {
                  _activeGameId = null;
                  _isGameOverlayVisible = false;
                });
              }
            }
            setState(() => _viewerCount = viewerCount);
          }
        });
  }

  void _listenToChat() {
    _chatSubscription = FirebaseFirestore.instance
        .collection('live_streams')
        .doc(widget.liveStream.streamId)
        .collection('chat')
        .orderBy('timestamp', descending: false)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _chatMessages.clear();
              for (var doc in snapshot.docs) {
                _chatMessages.add(doc.data());
              }
            });

            // Scroll to bottom
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_chatScrollController.hasClients) {
                _chatScrollController.animateTo(
                  _chatScrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        });
  }

  Future<void> _sendChatMessage() async {
    final message = _chatController.text.trim();

    if (message.isEmpty) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('live_streams')
          .doc(widget.liveStream.streamId)
          .collection('chat')
          .add({
            'userId': _currentUserId,
            'userName': _currentUser?.name ?? 'Unknown',
            'userPhoto': _currentUser?.photos.isNotEmpty == true
                ? _currentUser!.photos[0]
                : '',
            'message': message,
            'timestamp': Timestamp.now(),
          });

      _chatController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  Future<void> _sendGift(GiftModel gift) async {
    // 🚫 Self-gift block: Host cannot send gift to themselves
    if (_currentUserId == widget.liveStream.hostId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.block, color: Colors.white),
                SizedBox(width: 8),
                Text('You cannot send gifts to your own live stream!'),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    try {
      // Check if user has enough coins
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();

      final userDiamonds = userDoc.data()?['diamonds'] ?? 0;

      if (userDiamonds < gift.price) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Not enough diamonds! You need ${gift.price} diamonds.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Deduct diamonds from user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .update({'diamonds': FieldValue.increment(-gift.price)});

      // 💰 60/40 Split: 60% → host points, 40% → platform profit (vanished)
      final pointsEarned = (gift.price * 0.6).toInt();
      final platformCut = gift.price - pointsEarned; // 40% profit
      debugPrint(
        'Gift split: total=${gift.price} points=$pointsEarned platform=$platformCut',
      );

      // Add 60% as points to host
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.liveStream.hostId)
          .update({'points': FieldValue.increment(pointsEarned)});

      // Save gift transaction with split details
      await FirebaseFirestore.instance.collection('gift_transactions').add({
        'fromUserId': _currentUserId,
        'fromUserName': _currentUser?.name ?? 'Unknown',
        'toUserId': widget.liveStream.hostId,
        'toUserName': _hostUser?.name ?? 'Unknown',
        'giftId': gift.id,
        'giftName': gift.name,
        'giftEmoji': gift.icon,
        'giftPrice': gift.price,
        'pointsEarned': pointsEarned, // 60% to host
        'platformCut': platformCut, // 40% platform profit
        'context': 'live_stream',
        'streamId': widget.liveStream.streamId,
        'timestamp': Timestamp.now(),
      });

      // Update stream stats

      await FirebaseFirestore.instance
          .collection('live_streams')
          .doc(widget.liveStream.streamId)
          .update({
            'totalDiamondsReceived': FieldValue.increment(gift.price),
            'totalGiftsReceived': FieldValue.increment(1),
          });

      // Send gift message to chat

      await FirebaseFirestore.instance
          .collection('live_streams')
          .doc(widget.liveStream.streamId)
          .collection('chat')
          .add({
            'userId': _currentUserId,
            'userName': _currentUser?.name ?? 'Unknown',
            'userPhoto': _currentUser?.photos.isNotEmpty == true
                ? _currentUser!.photos[0]
                : '',
            'message': 'sent ${gift.icon} ${gift.name}',
            'isGift': true,
            'giftId': gift.id,
            'giftName': gift.name,
            'giftEmoji': gift.icon,
            'giftPrice': gift.price,
            'timestamp': Timestamp.now(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent ${gift.icon} ${gift.name}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send gift: $e')));
      }
    }
  }

  Future<void> _onStreamEnded() async {
    if (!mounted) return;

    // 1. If we are the host, fetch session summary
    if (_currentUserId == widget.liveStream.hostId) {
      final summary = await _databaseService.getRoomSessionSummary(
        widget.liveStream.streamId,
        context: 'live_stream',
      );

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/party_end',
          (route) => false,
          arguments: summary.isNotEmpty
              ? summary
              : {
                  'duration': '00:00:00',
                  'totalVisitors': 0,
                  'giftEarnings': 0,
                  'gameEarnings': 0,
                },
        );
      }
      return;
    }

    // 2. If we are a viewer, show regular dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Stream Ended'),
          content: const Text('The host has ended the live stream.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close viewer screen
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _leaveStream() async {
    try {
      // Decrement viewer count
      await _decrementViewerCount();

      // Remove viewer presence

      await FirebaseFirestore.instance
          .collection('live_streams')
          .doc(widget.liveStream.streamId)
          .collection('viewers')
          .doc(_currentUserId)
          .delete();

      // Leave Agora channel

      await _agoraService.leaveChannel();
    } catch (e) {}
  }

  void _toggleMute() async {
    await _agoraService.toggleMute();
    setState(() => _isMuted = !_isMuted);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Joining stream...', style: TextStyle(color: Colors.white)),
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
            // Video view (full screen)
            _buildVideoView(),

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
    if (!_isGameOverlayVisible || _activeGameId == null) {
      return const SizedBox.shrink();
    }

    Widget? gameWidget;

    if (_activeGameId == 'aviator') {
      gameWidget = AviatorGameWidget(onClose: _closeGame);
    } else if (_activeGameId == 'dice') {
      gameWidget = DiceGameWidget(onClose: _closeGame);
    } else if (_activeGameId == 'racing') {
      final userDiamonds = _currentUser?.diamonds ?? 0;
      gameWidget = CarRacingGameWidget(
        onClose: _closeGame,
        userDiamonds: userDiamonds,
        onDiamondUpdate: (newBalance) {
          setState(() {
            _currentUser = _currentUser?.copyWith(diamonds: newBalance);
          });
        },
      );
    }

    if (gameWidget == null) return const SizedBox.shrink();

    // Show game just above the bottom controls
    return Positioned(bottom: 80, left: 10, right: 10, child: gameWidget);
  }

  void _closeGame() async {
    // If we are the host, sync to database
    if (_currentUserId == widget.liveStream.hostId) {
      await _databaseService.stopRoomGame(
        roomId: widget.liveStream.streamId,
        context: 'live_stream',
      );
    }

    setState(() {
      _activeGameId = null;
      _isGameOverlayVisible = false;
    });
  }

  Widget _buildVideoView() {
    final engine = _agoraService.engine;
    // If Agora engine is initialized, show real video. Pinch zoom is blocked.
    if (engine != null) {
      return GestureDetector(
        // Absorb all scale gestures to prevent zoom
        onScaleStart: (_) {},
        onScaleUpdate: (_) {},
        onScaleEnd: (_) {},
        child: SizedBox.expand(
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: engine,
              canvas: VideoCanvas(
                uid: widget.liveStream.hostId.hashCode & 0xFFFFFFFF,
              ),
              connection: RtcConnection(channelId: widget.liveStream.streamId),
            ),
          ),
        ),
      );
    }
    // Fallback while loading
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFF1493)),
            const SizedBox(height: 16),
            Text(
              'Connecting to ${_hostUser?.name ?? "host"}...',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
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
          // Host info
          GestureDetector(
            onTap: () {
              // TODO: Navigate to host profile
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: _hostUser?.photos.isNotEmpty == true
                        ? NetworkImage(_hostUser!.photos[0])
                        : null,
                    child: _hostUser?.photos.isEmpty == true
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _hostUser?.name ?? 'Host',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
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
          const Spacer(),

          // Close button
          IconButton(
            onPressed: () async {
              await _leaveStream();
              if (mounted) Navigator.pop(context);
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
        constraints: const BoxConstraints(maxHeight: 250),
        child: ListView.builder(
          controller: _chatScrollController,
          shrinkWrap: true,
          itemCount: _chatMessages.length,
          itemBuilder: (context, index) {
            final chat = _chatMessages[index];
            final isGift = chat['isGift'] ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isGift
                    ? Colors.pink.withValues(alpha: 0.3)
                    : Colors.black45,
                borderRadius: BorderRadius.circular(20),
                border: isGift
                    ? Border.all(color: Colors.pink, width: 1)
                    : null,
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${chat['userName']}: ',
                      style: TextStyle(
                        color: isGift ? Colors.pink[100] : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: chat['message'],
                      style: TextStyle(
                        color: isGift ? Colors.white : Colors.white,
                        fontWeight: isGift
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
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
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
          ),
        ),
        child: Row(
          children: [
            // Chat input
            Expanded(
              child: TextField(
                controller: _chatController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Say something...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black45,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendChatMessage(),
              ),
            ),
            const SizedBox(width: 8),

            // Send button
            IconButton(
              onPressed: _sendChatMessage,
              icon: const Icon(Icons.send, color: Colors.white, size: 28),
            ),

            // Gift button — only visible for viewers (not the host)
            if (_currentUserId != widget.liveStream.hostId)
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF1493), Color(0xFFFF69B4)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () {
                    GiftsBottomSheet.show(context, onSendGift: _sendGift);
                  },
                  icon: const Icon(
                    Icons.card_giftcard,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),

            // Game button
            IconButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => GameSelectionWidget(
                    onGameSelected: (gameId) async {
                      // If we are the host, sync to database
                      if (_currentUserId == widget.liveStream.hostId) {
                        await _databaseService.startRoomGame(
                          roomId: widget.liveStream.streamId,
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
              },
              icon: const Icon(Icons.games, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 8),

            // Mute button
            IconButton(
              onPressed: _toggleMute,
              icon: Icon(
                _isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
