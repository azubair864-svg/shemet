import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:provider/provider.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/user_provider.dart';
import '../../services/database_service.dart';
import '../../services/agora_service.dart';
import '../../models/user_model.dart';
import '../../widgets/live/beauty_settings_sheet.dart';
import '../../widgets/live/gift_picker_sheet.dart';
import '../../widgets/live/floating_hearts_overlay.dart';
import '../../widgets/live/global_gift_overlay.dart';
import '../../widgets/gift_animation_overlay.dart';
import '../../models/gift_model.dart';
import '../profile/user_profile_detail_screen.dart';

class LiveStreamViewScreen extends StatefulWidget {
  final String? streamId;
  final bool isBroadcaster;

  const LiveStreamViewScreen({
    super.key,
    this.streamId,
    this.isBroadcaster = false,
  });

  @override
  State<LiveStreamViewScreen> createState() => _LiveStreamViewScreenState();
}

class _LiveStreamViewScreenState extends State<LiveStreamViewScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final AgoraService _agoraService = AgoraService();
  final DatabaseService _databaseService = DatabaseService();

  late AnimationController _vinylController;
  late AnimationController _pulseController;

  bool _isReady = false;
  String? _streamId;
  String? _hostId;
  Map<String, dynamic>? _hostInfo;
  final List<int> _remoteUids = [];
  int _hostTotalDiamonds = 0;
  StreamSubscription? _hostUserSubscription;

  // Games Module State
  bool _isFollowingHost = false;
  final StreamController<void> _heartTrigger =
      StreamController<void>.broadcast();
  final List<Map<String, dynamic>> _activeGifts = [];

  int _manualCount = 0;
  Timer? _countPoller;
  UserModel? _currentUser;
  
  // Premium Management
  bool _isPremiumLocked = false;
  int _previewSecondsRemaining = 30;
  Timer? _previewTimer;
  bool _hasUnlockedPremium = false;
  String _premiumMode = 'none';
  int _entryFee = 0;
  int _sessionEarnings = 0;
  StreamSubscription? _streamDocSubscription;
  StreamSubscription? _viewerCountSubscription;


  @override
  void initState() {
    super.initState();
    _enableScreenshotProtection();
    _streamId = widget.streamId;
    _currentUser = Provider.of<UserProvider>(
      context,
      listen: false,
    ).currentUser;
    WidgetsBinding.instance.addObserver(this);
    _initializeLive();
    _fetchStreamInfo();
    _startViewerSession();
    _startCountListener();
    _vinylController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  Future<void> _enableScreenshotProtection() async {
    await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
  }

  void _startCountListener() {
    _viewerCountSubscription?.cancel();
    if (_streamId == null) return;

    _viewerCountSubscription = FirebaseFirestore.instance
        .collection('live_streams')
        .doc(_streamId)
        .collection('viewer_sessions')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _manualCount = snapshot.docs.length;
        });
      }
    }, onError: (e) {
      debugPrint('[LIVE_DEBUG] ❌ Viewer Listener Error: $e');
    });
  }

  void _startViewerSession() async {
    if (widget.isBroadcaster || _streamId == null) return;

    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    if (user != null) {
      await _databaseService.updateViewerSession(
        streamId: _streamId!,
        userId: user.uid,
        name: user.name,
        photo: user.photos.isNotEmpty ? user.photos[0] : (user.photoURL ?? ''),
        isJoining: true,
      );

      await _databaseService.sendLiveMessage(
        streamId: _streamId!,
        userId: 'system',
        userName: user.displayName,
        message: 'joined the live',
        userPhoto: user.photos.isNotEmpty
            ? user.photos[0]
            : (user.photoURL ?? ''),
        type: 'social',
        userLevel: user.level,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.isBroadcaster && state == AppLifecycleState.detached) {
      _endStream();
    }
  }

  Future<void> _fetchStreamInfo() async {
    if (_streamId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('live_streams')
          .doc(_streamId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _hostId = doc.data()?['hostId'];
          _hostInfo = doc.data();
        });

        // Initialize Host User Stream for Diamond Tracking
        if (_hostId != null && _hostUserSubscription == null) {
          _hostUserSubscription = _databaseService
              .getUserStream(_hostId!)
              .listen((user) {
                if (mounted && user != null) {
                  setState(() {
                    _hostTotalDiamonds = user.diamonds;
                  });
                }
              });
        }
      }
    } catch (e) {
      debugPrint('[LIVE_DEBUG] ❌ Fetch Error: $e');
    }

    if (!widget.isBroadcaster && _hostId != null) {
      final currentUser = Provider.of<UserProvider>(
        context,
        listen: false,
      ).currentUser;
      if (currentUser != null) {
        final following = await _databaseService.isFollowing(
          followerId: currentUser.uid,
          followingId: _hostId!,
        );
        if (mounted) {
          setState(() => _isFollowingHost = following);
        }
      }
    }
  }

  Timer? _premiumDeductionTimer;

  Future<void> _initializeLive() async {
    if (_streamId == null) return;

    // 1. Fetch Latest Stream Data to check Premium Status
    final streamDoc = await FirebaseFirestore.instance.collection('live_streams').doc(_streamId).get();
    final streamData = streamDoc.data()!;
    _premiumMode = streamData['premiumMode'] ?? 'none';
    _entryFee = streamData['entryFee'] ?? 0;

    // 2. Premium Management for Audience
    if (!widget.isBroadcaster && _premiumMode != 'none') {
      if (_premiumMode == 'entrance') {
        // Persistent Unlock Check for Fixed Fee Rooms
        final hasPaid = await _databaseService.hasPaidEntranceFee(_currentUser!.uid, _streamId!);
        if (hasPaid) {
          setState(() {
            _isPremiumLocked = false;
            _hasUnlockedPremium = true;
          });
        } else {
          setState(() => _isPremiumLocked = true);
        }
      } else if (_premiumMode == 'minute') {
        // Start 30s Preview for Pay-Per-Minute Rooms
        _startPreviewTimer();
      }
    }


    // 3. Start Stream Doc Listener for Session Stats
    _streamDocSubscription?.cancel();
    _streamDocSubscription = FirebaseFirestore.instance.collection('live_streams').doc(_streamId).snapshots().listen((doc) {
      if (mounted && doc.exists) {
        final data = doc.data()!;
        final newMode = data['premiumMode'] ?? 'none';
        final newFee = data['entryFee'] ?? 0;

        setState(() {
          _sessionEarnings = data['totalDiamondsReceived'] ?? 0;
          
          // 🌩️ REAL-TIME SYNC: Detect mode change for viewers
          if (!widget.isBroadcaster && newMode != 'none' && newMode != _premiumMode) {
              debugPrint('[PREMIUM_DEBUG] Mode changed mid-stream to: $newMode');
              _premiumMode = newMode;
              _entryFee = newFee;
              _handleMidStreamPremiumChange();
          } else {
              _premiumMode = newMode;
              _entryFee = newFee;
          }
        });
      }
    });

    await _agoraService.initialize();

    _agoraService.registerEventHandlers(
      onUserJoined: (connection, remoteUid, elapsed) {
        if (mounted) {
          setState(() {
            if (!_remoteUids.contains(remoteUid)) {
              _remoteUids.add(remoteUid);
            }
          });
        }
      },
      onUserOffline: (connection, remoteUid, reason) {
        if (mounted) {
          setState(() {
            _remoteUids.remove(remoteUid);
          });
        }
      },
      onError: (err, msg) {},
    );

    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    if (user != null) {
      if (widget.isBroadcaster) {
        await _agoraService.requestCameraControl(CameraOwner.agora);
      }

      final token = await _agoraService.generateAgoraToken(
        channelName: _streamId!,
        uid: 0,
      );

      final joined = await _agoraService.joinChannel(
        channelId: _streamId!,
        token: token,
        uid: 0,
        isBroadcaster: widget.isBroadcaster,
      );

      if (joined) {
        if (mounted) {
          setState(() => _isReady = true);
        }
        if (widget.isBroadcaster && _hostId != null) {
          _databaseService.startLiveGlobalStatus(_hostId!);
        }
      }
    }
  }

  void _startPreviewTimer() {
    _previewTimer?.cancel();
    _previewTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_previewSecondsRemaining > 0) {
          _previewSecondsRemaining--;
        } else {
          timer.cancel();
          if (!_hasUnlockedPremium) {
            _isPremiumLocked = true;
          }
        }
      });
    });
  }

  Future<void> _handlePremiumUnlock() async {
    final success = await _deductPremiumFee(_entryFee);
    if (success) {
      // 🚀 Immediate UI Feedback: Deduct locally
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.deductDiamondsLocal(_entryFee);

      setState(() {
        _isPremiumLocked = false;
        _hasUnlockedPremium = true;
      });

      // 👑 Social Proof: Send system message
      await _databaseService.sendLiveMessage(
        streamId: _streamId!,
        userId: 'system',
        userName: _currentUser?.displayName ?? 'User',
        message: 'Unlocked Premium! 👑',
        userPhoto: _currentUser?.photos.isNotEmpty == true ? _currentUser!.photos[0] : (_currentUser?.photoURL ?? ''),
        type: 'social',
        userLevel: _currentUser?.level ?? 1,
      );

      if (_premiumMode == 'minute') {
        _startMinuteBillingTimer();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('👑 Stream Unlocked! Enjoy.')),
        );
      }
    } else {
      if (mounted) {
        final currentBal = _currentUser?.diamonds ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Insufficient diamonds! (Your UI balance: $currentBal)')),
        );
      }
    }
  }

  void _startMinuteBillingTimer() {
    _premiumDeductionTimer?.cancel();
    _premiumDeductionTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final success = await _deductPremiumFee(_entryFee);
      if (success) {
        // 🚀 Continuous local deduction for sync
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.deductDiamondsLocal(_entryFee);
      } else {
        timer.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Disconnected: Insufficient diamonds for Premium Live')),
          );
          Navigator.pop(context);
        }
      }
    });
  }

  // 🔔 Handle Mid-Stream Premium Mode Switch
  void _handleMidStreamPremiumChange() {
    if (_premiumMode == 'entrance') {
      // LOYALTY RULE: We don't kick existing viewers for Entrance Fee
      debugPrint('[PREMIUM_DEBUG] Entrance Fee set mid-stream. Existing viewers stay free.');
    } else if (_premiumMode == 'minute') {
      // ENFORCEMENT RULE: Minute billing applies to everyone
      if (!_hasUnlockedPremium) {
        debugPrint('[PREMIUM_DEBUG] Minute Billing enabled. Starting preview timer.');
        _startPreviewTimer();
      }
    }
  }

  Future<bool> _deductPremiumFee(int fee) async {
    if (_currentUser == null || _hostId == null || _streamId == null) return false;
    
    return await _databaseService.processPremiumBilling(
      viewerId: _currentUser!.uid,
      hostId: _hostId!,
      streamId: _streamId!,
      amount: fee,
      mode: _premiumMode,
    );
  }

  Future<void> _handleExit() async {
    if (widget.isBroadcaster) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'End Party Room?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to end this party room?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'End',
                style: TextStyle(
                  color: Color(0xFFFF1493),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _endStream();
      }
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _endStream() async {
    if (widget.isBroadcaster && _streamId != null) {
      final user = Provider.of<UserProvider>(
        context,
        listen: false,
      ).currentUser;
      final cleanupUid = user?.uid ?? _hostId;
      await _databaseService.endLiveStream(_streamId!, hostId: cleanupUid);
    }

    await _agoraService.leaveChannel();
    if (mounted) Navigator.pop(context);
  }

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  Future<void> _disableScreenshotProtection() async {
    await FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
  }

  @override
  void dispose() {
    _disableScreenshotProtection();
    WidgetsBinding.instance.removeObserver(this);

    if (widget.isBroadcaster && _streamId != null) {
      final cleanupUid = _currentUser?.uid ?? _hostId;
      if (cleanupUid != null) {
        _databaseService
            .endLiveStream(_streamId!, hostId: cleanupUid)
            .catchError((e) {
              debugPrint('[LIVE_DEBUG] ⚠️ endLiveStream cleanup failed: $e');
            });
      }
    } else if (!widget.isBroadcaster && _streamId != null) {
      if (_currentUser != null && _streamId != null) {
        _databaseService
            .updateViewerSession(
              streamId: _streamId!,
              userId: _currentUser!.uid,
              name: _currentUser!.name,
              photo: _currentUser!.mainPhoto ?? '',
              isJoining: false,
            )
            .catchError((e) {
              debugPrint(
                '[LIVE_DEBUG] ⚠️ updateViewerSession cleanup failed: $e',
              );
            });
      }
    }

    _hostUserSubscription?.cancel();
    _streamDocSubscription?.cancel();
    _viewerCountSubscription?.cancel();

    _premiumDeductionTimer?.cancel();
    _messageController.dispose();
    _chatScrollController.dispose();
    _agoraService.leaveChannel();
    _agoraService.requestCameraControl(CameraOwner.none);
    _heartTrigger.close();
    _vinylController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _streamId == null) return;

    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    if (user == null) return;

    _messageController.clear();
    await _databaseService.sendLiveMessage(
      streamId: _streamId!,
      userId: user.uid,
      userName: user.displayName,
      userLevel: user.level,
      userPhoto: user.photos.isNotEmpty ? user.photos[0] : null,
      message: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🛡️ REFINEMENT: Watch UserProvider for real-time balance updates in Premium Overlay
    final watchedUser = context.watch<UserProvider>().currentUser;
    _currentUser = watchedUser; 

    return PopScope(
      canPop: !widget.isBroadcaster,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        if (widget.isBroadcaster) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text(
                'End Party Room?',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Are you sure you want to end this party room?',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'End',
                    style: TextStyle(
                      color: Color(0xFFFF1493),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );

          if (confirm == true) {
            await _endStream();
          }
        }
      },
      child: !_isReady
          ? const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFFF1493)),
              ),
            )
          : Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () => _heartTrigger.add(null),
                    behavior: HitTestBehavior.translucent,
                    child: _buildVideoView(),
                  ),
                  FloatingHeartsOverlay(triggerStream: _heartTrigger),
                  SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(),
                        _buildSocialStatusRow(),
                        const Spacer(),
                        _buildBottomControls(),
                      ],
                    ),
                  ),
                  if (_activeGifts.isNotEmpty)
                    GlobalGiftOverlay(
                      event: _activeGifts.first,
                      onComplete: () {
                        setState(() {
                          _activeGifts.removeAt(0);
                        });
                      },
                    ),
                    // Right-Side Action Pillar
                    Positioned(
                      right: 16,
                      top: MediaQuery.of(context).size.height * 0.35,
                      child: _buildActionPillar(),
                    ),

                    // Premium Locked Overlay (Glassmorphism)
                    if (_isPremiumLocked) _buildPremiumOverlay(),

                    // Free Preview Countdown (Subtle)
                    if (!widget.isBroadcaster && _premiumMode == 'minute' && !_hasUnlockedPremium && !_isPremiumLocked)
                      Positioned(
                        top: 100,
                        right: 16,
                        child: _buildPreviewCountdown(),
                      ),
                  ],
              ),
            ),
    );
  }

  Widget _buildVideoView() {
    if (widget.isBroadcaster) {
      if (_agoraService.engine != null) {
        return AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _agoraService.engine!,
            canvas: const VideoCanvas(
              uid: 0,
              renderMode: RenderModeType.renderModeHidden,
            ),
          ),
        );
      }
    } else {
      if (_remoteUids.isNotEmpty && _agoraService.engine != null) {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _agoraService.engine!,
            canvas: VideoCanvas(
              uid: _remoteUids.first,
              renderMode: RenderModeType.renderModeHidden,
            ),
            connection: RtcConnection(channelId: _streamId),
          ),
        );
      }
    }
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.videocam_off, color: Colors.white54, size: 50),
      ),
    );
  }

  Widget _buildSocialStatusRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 16, top: 4, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Keep it tight
        children: [
          // Top Fan Slot (Slim & High Gloss - Real-time Aggregation)
          StreamBuilder<Map<String, dynamic>?>(
            stream: _databaseService.getTopGifterStream(_streamId!),
            builder: (context, snapshot) {
              final topGifter = snapshot.data;
              final String photo = topGifter?['photo'] as String? ?? '';
              final String name = topGifter?['name'] as String? ?? 'Top Fan';
              final String? userId = topGifter?['userId'] as String?;

              return GestureDetector(
                onTap: () {
                  if (userId != null) {
                    _showUserProfileSheet(userId);
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF8C00), // Darker Orange
                            Color(0xFFFFA500), // Amber
                            Color(0xFFFFD700), // Gold
                          ],
                          stops: [0.0, 0.5, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.white24,
                                backgroundImage: photo.isNotEmpty
                                    ? NetworkImage(photo)
                                    : null,
                                child: photo.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        size: 12,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              // Golden Crown Overlay
                              Positioned(
                                top: -7,
                                left: -4,
                                child: Transform.rotate(
                                  angle: -0.2,
                                  child: Icon(
                                    Icons.workspace_premium,
                                    size: 14,
                                    color: Colors.amber[400],
                                    shadows: const [
                                      BoxShadow(
                                        color: Colors.black45,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 60),
                            child: Text(
                              topGifter != null ? name : 'Top Fan',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // Daily Goal Slot (Narrow Lavender Gloss)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFD1DC).withOpacity(0.3), // Soft Pink
                      const Color(0xFFE6E6FA).withOpacity(0.15),
                      const Color(0xFFFFFFFF).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite,
                      size: 12,
                      color: Color(0xFFFF1493),
                      shadows: [
                        Shadow(color: Color(0xFFFF1493), blurRadius: 6),
                      ],
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 40,
                      height: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: const LinearProgressIndicator(
                          value: 0.25,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFFF1493),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '0/1',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Spinning Vinyl Record (Reduced Size)
          RotationTransition(
            turns: _vinylController,
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.album,
                size: 24,
                color: Color(0xFF333333),
              ), // Slimmer size
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (_hostId != null) {
                  _showUserProfileSheet(_hostId!);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFFFD700),
                                Color(0xFFFF1493),
                                Color(0xFF8A2BE2),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: CircleAvatar(
                            backgroundColor: Colors.black,
                            radius: 16,
                            backgroundImage:
                                (_hostInfo?['hostPhoto'] != null &&
                                    _hostInfo!['hostPhoto']
                                        .toString()
                                        .isNotEmpty)
                                ? NetworkImage(_hostInfo!['hostPhoto'])
                                : null,
                            child:
                                (_hostInfo?['hostPhoto'] == null ||
                                    _hostInfo!['hostPhoto'].toString().isEmpty)
                                ? const Icon(
                                    Icons.person,
                                    size: 18,
                                    color: Colors.white70,
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: -2,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF1493), Color(0xFFFF69B4)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                                BoxShadow(
                                  color: Color(0xFFFF1493),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Text(
                              'Lv.${_hostInfo?['hostLevel'] ?? 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hostInfo?['hostName'] ?? 'Loading...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        // Replace ID with Beans/Seed Count
                        Row(
                          children: [
                            const Text('💎', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 4),
                            Text(
                              '$_hostTotalDiamonds',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (!widget.isBroadcaster) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () async {
                          if (_hostId == null) return;
                          final currentUser = Provider.of<UserProvider>(
                            context,
                            listen: false,
                          ).currentUser;
                          if (currentUser == null) return;

                          final success = await _databaseService.toggleFollow(
                            followerId: currentUser.uid,
                            followingId: _hostId!,
                          );
                          if (success && mounted) {
                            setState(
                              () => _isFollowingHost = !_isFollowingHost,
                            );
                            if (_isFollowingHost) {
                              await _databaseService.sendLiveMessage(
                                streamId: _streamId!,
                                userId: 'system',
                                userName: currentUser.displayName,
                                message: 'followed the host',
                                userPhoto: currentUser.photos.isNotEmpty
                                    ? currentUser.photos[0]
                                    : (currentUser.photoURL ?? ''),
                                type: 'social',
                                userLevel: currentUser.level,
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _isFollowingHost
                                ? Colors.grey.withOpacity(0.4)
                                : const Color(0xFFFF1493),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _isFollowingHost ? 'Following' : 'Follow',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (_streamId != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('live_streams')
                    .doc(_streamId)
                    .collection('viewer_sessions')
                    .orderBy('joinedAt', descending: true)
                    .limit(10)
                    .snapshots(),
                builder: (context, sessionSnapshot) {
                  final allSessions = sessionSnapshot.data?.docs ?? [];
                  if (allSessions.isEmpty) return const SizedBox.shrink();

                  // Cycle through sessions every 3 seconds
                  return StreamBuilder<int>(
                    stream: Stream<int>.periodic(
                      const Duration(seconds: 3),
                      (i) => i,
                    ),
                    builder: (context, timerSnapshot) {
                      final startIndex =
                          (timerSnapshot.data ?? 0) % allSessions.length;
                      final sessionsToShow = <DocumentSnapshot>[];

                      // Pick up to 2 sessions starting from startIndex
                      for (int i = 0; i < 2; i++) {
                        if (allSessions.isNotEmpty) {
                          sessionsToShow.add(
                            allSessions[(startIndex + i) % allSessions.length],
                          );
                        }
                      }

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...sessionsToShow.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final url = data['photo'] as String? ?? '';
                            return GestureDetector(
                              onTap: () {
                                final viewerId =
                                    data['userId'] as String? ?? '';
                                if (viewerId.isNotEmpty) {
                                  _showUserProfileSheet(viewerId);
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundImage: url.isNotEmpty
                                      ? NetworkImage(url)
                                      : null,
                                  backgroundColor: Colors.white12,
                                  child: url.isEmpty
                                      ? const Icon(
                                          Icons.person,
                                          size: 14,
                                          color: Colors.white54,
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  );
                },
              ),

            if (_streamId != null)
              StreamBuilder<int>(
                stream: _databaseService.getViewerCountBySessions(_streamId!),
                builder: (context, snapshot) {
                  final streamCount = snapshot.data ?? 0;
                  final displayCount = streamCount > _manualCount
                      ? streamCount
                      : _manualCount;

                  return Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Text(
                      '$displayCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    if (_streamId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('live_streams')
          .doc(_streamId)
          .collection('gifts')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, giftSnapshot) {
        if (giftSnapshot.hasData && giftSnapshot.data!.docs.isNotEmpty) {
          final lastGift =
              giftSnapshot.data!.docs.first.data() as Map<String, dynamic>;
          final timestamp = lastGift['timestamp'] as Timestamp?;
          if (timestamp != null &&
              DateTime.now().difference(timestamp.toDate()).inSeconds < 5) {
            final giftId = giftSnapshot.data!.docs.first.id;
            if (!_activeGifts.any((g) => g['id'] == giftId)) {
              final senderId = lastGift['senderId'] ?? '';
              final currentUser = Provider.of<UserProvider>(context, listen: false).currentUser;
              final currentUserId = currentUser?.uid ?? '';
              
              // Map to GiftModel
              final gift = GiftModel.fromMap(lastGift, lastGift['giftId']);

              Future.delayed(Duration.zero, () {
                setState(() {
                  _activeGifts.add({...lastGift, 'id': giftId});
                });
                
                // TRIGGER PREMIUM GLOBAL OVERLAY
                GiftAnimationOverlay.showGiftAnimation(
                  context,
                  gift: gift,
                  senderName: lastGift['senderName'] ?? 'Someone',
                  senderId: senderId,
                  currentUserId: currentUserId,
                  senderPhoto: lastGift['senderPhoto'],
                  comboCount: lastGift['quantity'] ?? 1,
                );
              });
            }
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _databaseService.getLiveMessages(_streamId!),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final messages = snapshot.data!.docs;

            return MediaQuery.removePadding(
              context: context,
              removeLeft: true,
              removeRight: true,
              child: ListView.builder(
                reverse: true,
                controller: _chatScrollController,
                padding: const EdgeInsets.only(top: 0, bottom: 0),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final data = messages[index].data() as Map<String, dynamic>;
                  final userLevel = data['userLevel'] ?? 0;
                  final type = data['type'] ?? 'text';
                  final isSocial = type == 'social';
                  final userPhoto = data['userPhoto'] ?? '';
                  final userName = data['userName'] ?? 'Someone';
                  final bool hasPhoto =
                      userPhoto.isNotEmpty && userPhoto.startsWith('http');

                  if (isSocial) {
                    final bool isPremiumUnlock = data['message'] == 'Unlocked Premium! 👑';

                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: isPremiumUnlock 
                            ? const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500), Colors.transparent],
                                stops: [0.0, 0.6, 1.0],
                              )
                            : LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.black.withOpacity(0.4),
                                  Colors.transparent,
                                ],
                              ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isPremiumUnlock ? [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 1,
                            )
                          ] : null,
                          border: isPremiumUnlock ? Border.all(color: Colors.white.withOpacity(0.5), width: 0.5) : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: Colors.white24,
                              backgroundImage: hasPhoto
                                  ? NetworkImage(userPhoto)
                                  : null,
                              child: !hasPhoto
                                  ? const Icon(
                                      Icons.person,
                                      size: 14,
                                      color: Colors.white70,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '$userName ',
                                      style: const TextStyle(
                                        color: Color(0xFFFFCC33),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    TextSpan(
                                      text: data['message'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
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
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: Colors.white24,
                          backgroundImage: hasPhoto
                              ? NetworkImage(userPhoto)
                              : null,
                          child: !hasPhoto
                              ? const Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Colors.white70,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                ),
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFFFFD700),
                                                Color(0xFFFFA500),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            'Lv.$userLevel',
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const WidgetSpan(
                                        child: SizedBox(width: 6),
                                      ),
                                      TextSpan(
                                        text: '$userName: ',
                                        style: const TextStyle(
                                          color: Color(0xFFFFCC33),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      TextSpan(
                                        text: data['message'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 16, bottom: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSystemNotice(),
          SizedBox(
            height: 170,
            width: MediaQuery.of(context).size.width * 0.75,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.white],
                  stops: [0.0, 0.2],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: _buildChatList(),
            ),
          ),
          const SizedBox(height: 6),
          _buildQuickMessages(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Theme(
                    data: ThemeData.dark(),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Say something...',
                        hintStyle: TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                        isDense: true,
                        filled: false,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      cursorColor: const Color(0xFFFF1493),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFFF1493),
                  child: Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              // Revenue CTA
              _buildRevenueCTA(),
              const SizedBox(width: 12),
              if (widget.isBroadcaster) ...[
                _buildControlButton(
                  _agoraService.isMuted ? Icons.mic_off : Icons.mic,
                  '',
                  () {
                    if (mounted) {
                      setState(() {
                        _agoraService.toggleMute();
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                _buildControlButton(Icons.face, 'Beauty', () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const BeautySettingsSheet(),
                  );
                }),
                _buildControlButton(Icons.close, 'Exit', _handleExit),
              ] else ...[
                _buildControlButton(Icons.card_giftcard, 'Gift', () {
                  if (_hostId != null && _streamId != null) {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => GiftPickerSheet(
                        streamId: _streamId!,
                        receiverId: _hostId!,
                      ),
                    );
                  }
                }),
                const SizedBox(width: 8),
                _buildControlButton(Icons.share, 'Share', () {}),
                const SizedBox(width: 8),
                _buildControlButton(Icons.close, 'Exit', _handleExit),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.black.withOpacity(0.4),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildQuickMessages() {
    final suggestions = [
      "Hi! 👋",
      "Beautiful! 😍",
      "Wow! 💎",
      "Hello! ✨",
      "Nice! 🌹",
    ];
    return SizedBox(
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              _messageController.text = suggestions[index];
              _sendMessage();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Center(
                child: Text(
                  suggestions[index],
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showUserProfileSheet(String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => FutureBuilder<UserModel?>(
        future: _databaseService.getUserById(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: 350,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF1493)),
              ),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return Container(
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: const Center(
                child: Text(
                  'User not found',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white12,
                    backgroundImage:
                        (user.mainPhoto != null && user.mainPhoto!.isNotEmpty)
                        ? NetworkImage(user.mainPhoto!)
                        : null,
                    child: (user.mainPhoto == null || user.mainPhoto!.isEmpty)
                        ? const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.white24,
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'ID: ${user.uid.length >= 8 ? user.uid.substring(0, 8) : user.uid}',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem('Followers', user.followers.toString()),
                      _buildStatItem('Following', user.following.toString()),
                      _buildStatItem(
                        'Beans',
                        user.totalBeansReceived.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Close the sheet
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    UserProfileDetailScreen(user: user),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF1493),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'View Profile',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionPillar() {
    if (!widget.isBroadcaster) return const SizedBox.shrink();

    return Column(
      children: [
        // 💎 Host Revenue Badge with Pulse Animation
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          tween: Tween(begin: 1.0, end: 1.2),
          curve: Curves.elasticOut,
          key: ValueKey(_sessionEarnings),
          builder: (context, value, child) {
            return Transform.scale(
              scale: _sessionEarnings == 0 ? 1.0 : value,
              child: _buildPillarItem(
                Icons.account_balance_wallet,
                '${(_sessionEarnings * 0.6).toInt()}',
                'Earned',
                onTap: () {
                  _showEarningsBreakdown();
                },
                isPulsing: true,
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildPillarItem(
          Icons.people,
          '$_manualCount',
          'Users',
          onTap: () {},
        ),
        const SizedBox(height: 12),
        // 👑 Premium Control Button (Host Only)
        _buildPillarItem(
          _premiumMode == 'none' ? Icons.stars_rounded : Icons.workspace_premium,
          _premiumMode == 'none' ? 'Free' : _premiumMode.toUpperCase(),
          'Status',
          onTap: _showPremiumSettingsSheet,
        ),
      ],
    );
  }

  Widget _buildPillarItem(IconData icon, String value, String label, {required VoidCallback onTap, bool isPulsing = false}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isPulsing && _sessionEarnings > 0 ? [
            BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            )
          ] : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                border: Border.all(
                  color: isPulsing && _sessionEarnings > 0 
                      ? Colors.amber.withOpacity(0.5) 
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  Icon(icon, color: Colors.amber, size: 18),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white54, fontSize: 8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPremiumSettingsSheet() {
    String tempMode = _premiumMode;
    final feeController = TextEditingController(text: _entryFee.toString());

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  const Text('Premium Settings', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Monetize your live stream in real-time', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildModeOption('Free', 'none', Icons.public, tempMode, (m) => setSheetState(() => tempMode = m)),
                      const SizedBox(width: 8),
                      _buildModeOption('Entrance', 'entrance', Icons.vpn_key, tempMode, (m) => setSheetState(() => tempMode = m)),
                      const SizedBox(width: 8),
                      _buildModeOption('Minute', 'minute', Icons.timer, tempMode, (m) => setSheetState(() => tempMode = m)),
                    ],
                  ),
                  if (tempMode != 'none') ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                      child: TextField(
                        controller: feeController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18),
                        decoration: InputDecoration(
                          hintText: 'Enter Diamond Amount',
                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                          border: InputBorder.none,
                          suffixText: tempMode == 'minute' ? ' 💎/min' : ' 💎 Total',
                          suffixStyle: const TextStyle(color: Colors.white38),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () async {
                        final fee = int.tryParse(feeController.text.trim()) ?? 0;
                        if (tempMode != 'none' && fee <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount')));
                          return;
                        }
                        
                        final success = await _databaseService.updateLiveStreamPremiumStatus(
                          streamId: _streamId!,
                          isPremium: tempMode != 'none',
                          premiumMode: tempMode,
                          entryFee: fee,
                        );

                        if (success) {
                          setState(() {
                            _premiumMode = tempMode;
                            _entryFee = fee;
                          });
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🚀 Premium Settings Updated!'), backgroundColor: Colors.green));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF1493),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                        shadowColor: const Color(0xFFFF1493).withOpacity(0.4),
                      ),
                      child: const Text('Confirm Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildModeOption(String label, String mode, IconData icon, String currentMode, Function(String) onSelect) {
    final isSelected = currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF1493).withOpacity(0.1) : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? const Color(0xFFFF1493).withOpacity(0.5) : Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFFFF1493) : Colors.white54, size: 22),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  void _showEarningsBreakdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Session Earnings',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildBreakdownRow('Total Received', '$_sessionEarnings Coins'),
            const SizedBox(height: 12),
            _buildBreakdownRow('Platform Fee (40%)', '-${(_sessionEarnings * 0.4).toInt()}'),
            const Divider(color: Colors.white12, height: 24),
            _buildBreakdownRow('Your Profit (60%)', '${(_sessionEarnings * 0.6).toInt()} Points', isHighlight: true),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF1493)),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isHighlight ? Colors.white : Colors.white70)),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? const Color(0xFFFFCC33) : Colors.white,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }


  Widget _buildSystemNotice() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.75,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: const Color(0xFFFFCC33).withOpacity(0.2),
              child: const Icon(
                Icons.notifications_active,
                color: Color(0xFFFFCC33),
                size: 12,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'System: ',
                            style: TextStyle(
                              color: Color(0xFFFFCC33),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const TextSpan(
                            text:
                                'Follow the host to get updates on their next live!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCTA() {
    return GestureDetector(
      onTap: () {
        // Broadcaster sees earnings, Viewer sees rate
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.isBroadcaster
                ? [const Color(0xFF8A2BE2), const Color(0xFFFF1493)] // Purple to Pink
                : [const Color(0xFFFFA500), const Color(0xFFFF4500)], // Orange
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (widget.isBroadcaster ? const Color(0xFFFF1493) : const Color(0xFFFFA500)).withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.isBroadcaster ? Icons.account_balance_wallet : Icons.stars,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              widget.isBroadcaster
                  ? '$_sessionEarnings Received'
                  : (_premiumMode == 'minute' ? '$_entryFee / min' : '$_entryFee to unlock'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPremiumOverlay() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: (_pulseController.value - 0.5) * 0.15,
                      child: Transform.scale(
                        scale: 1.0 + (_pulseController.value * 0.1),
                        child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 64),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Premium Stream',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _premiumMode == 'minute'
                      ? 'Enjoy this exclusive content for just $_entryFee 💎 per minute.'
                      : 'Unlock this exclusive content for a one-time fee of $_entryFee 💎.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                // Viewer Balance
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Your Balance: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('${_currentUser?.diamonds ?? 0} 💎', style: const TextStyle(color: Color(0xFFFFCC33), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_pulseController.value * 0.05),
                      child: ElevatedButton(
                        onPressed: _handlePremiumUnlock,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 8,
                          shadowColor: Colors.amber.withOpacity(0.5),
                        ),
                        child: const Text(
                          'Unlock Now',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Leave Stream', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCountdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, color: Colors.amber, size: 14),
          const SizedBox(width: 6),
          Text(
            'Free Preview: ${_previewSecondsRemaining}s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
