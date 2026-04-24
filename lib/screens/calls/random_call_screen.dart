import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/random_call_service.dart';
import '../../services/database_service.dart';
import 'voice_call_screen.dart';
import '../discover/random_match_call_screen.dart';

/// ⭐⭐⭐ PRODUCTION-READY RANDOM CALL SCREEN ⭐⭐⭐
/// Features: Filter selection, Searching animation, Match popup, Call initiation
class RandomCallScreen extends StatefulWidget {
  final bool startSearchAutomatically;
  const RandomCallScreen({super.key, this.startSearchAutomatically = false});

  @override
  State<RandomCallScreen> createState() => _RandomCallScreenState();
}

class _RandomCallScreenState extends State<RandomCallScreen>
    with TickerProviderStateMixin {
  final RandomCallService _randomCallService = RandomCallService();
  final DatabaseService _databaseService = DatabaseService();

  // Current user
  String? _currentUserId;
  UserModel? _currentUser;

  // Search state
  bool _isSearching = false;
  String? _currentQueueId;
  StreamSubscription? _matchSubscription;

  // Call type
  String _selectedCallType = 'video'; // 'voice' or 'video'

  // Filter settings
  String? _preferredGender;
  int _minAge = 18;
  int _maxAge = 50;
  String? _preferredCountry;
  String? _preferredLanguage;

  // Search timer
  int _searchSeconds = 0;
  Timer? _searchTimer;

  // Animation controller
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _rotateController;

  // Queue stats
  int _usersSearching = 0;

  @override
  void initState() {
    super.initState();
    

    // Pulse animation for searching
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Rotate animation
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _loadCurrentUser();
    _loadQueueStats();

    // Auto-start search if requested
    if (widget.startSearchAutomatically) {
      _waitForUserAndStartSearch();
    }
  }

  Future<void> _waitForUserAndStartSearch() async {
    // Wait for _currentUser to be loaded from the stream
    int attempts = 0;
    while (_currentUser == null && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }
    if (mounted && _currentUser != null) {
      _startSearching();
    }
  }

  Future<void> _loadCurrentUser() async {
    

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      
      return;
    }

    _currentUserId = user.uid;
    

    _databaseService.getUserStream(_currentUserId!).listen((userModel) {
      if (mounted && userModel != null) {
        setState(() {
          _currentUser = userModel;
        });
        
      }
    });
  }

  Future<void> _loadQueueStats() async {
    

    try {
      final stats = await _randomCallService.getQueueStats();
      if (mounted) {
        setState(() {
          _usersSearching = stats['totalSearching'] ?? 0;
        });
        
      }
    } catch (e) {
      
    }
  }

  Future<void> _startSearching() async {
    

    if (_currentUser == null || _currentUserId == null) {
      
      _showErrorSnackbar('Please wait while we load your profile');
      return;
    }

    setState(() {
      _isSearching = true;
      _searchSeconds = 0;
    });

    // Start search timer
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _searchSeconds++;
        });
      }
    });

    // Join queue
    String? queueId;
    try {
      // Deduct card if this is a free trial start (checking local state)
      if (_currentUser!.freeTrialCards! > 0) {
        final success = await _databaseService.useFreeTrialCard(_currentUserId!);
        if (!success) {
           _showErrorSnackbar('Failed to use free trial card');
           setState(() => _isSearching = false);
           return;
        }
      }

      // 3. Join new queue
      
      queueId = await _randomCallService.joinQueue(
        userId: _currentUserId!,
        user: _currentUser!,
        callType: _selectedCallType,
        preferredGender: _preferredGender,
        minAge: _minAge,
        maxAge: _maxAge,
        preferredCountry: _preferredCountry,
        preferredLanguage: _preferredLanguage,
      );
    } catch (e) {
      
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join queue. Permission denied or error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return; // Exit if an error occurred
    }

    if (queueId == null) {
      
      _stopSearching();
      _showErrorSnackbar('Failed to start searching. Please try again.');
      return;
    }

    _currentQueueId = queueId;
    

    // Listen for match
    _matchSubscription =
        _randomCallService.streamMatchInfo(queueId).listen((data) {
      if (data != null && data['status'] == 'matched') {
        
        _handleMatchFound(data);
      }
    });
  }

  void _stopSearching() async {
    

    _searchTimer?.cancel();
    _matchSubscription?.cancel();

    if (_currentUserId != null) {
      await _randomCallService.leaveQueue(_currentUserId!);
    }

    if (mounted) {
      setState(() {
        _isSearching = false;
        _currentQueueId = null;
        _searchSeconds = 0;
      });
    }

    
  }

  Future<void> _handleMatchFound(Map<String, dynamic> queueData) async {
    

    _searchTimer?.cancel();
    _matchSubscription?.cancel();

    final matchedUserId = queueData['matchedWith'] as String;
    

    // Get match info
    final matchInfo = await _randomCallService.getMatchInfo(_currentQueueId!);

    if (matchInfo == null) {
      
      _stopSearching();
      return;
    }

    if (!mounted) return;

    // Show match popup ONLY for the User (Searcher)
    // Hosts just wait for the incoming call
    if (_currentUser?.isHost == true) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match found! Waiting for user to call you...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 30), // Long duration as we wait for call
        ),
      );
      // We don't stop searching here for the host UI, we keep the radar 
      // or we could switch to a "Connecting" state.
      // The IncomingCallScreen will take over shortly.
      return;
    }

    _showMatchFoundDialog(matchInfo);
  }

  void _showMatchFoundDialog(Map<String, dynamic> matchInfo) {
    
    

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MatchFoundDialog(
        matchInfo: matchInfo,
        onStartCall: () async {
          Navigator.pop(context);
          await _initiateCall(matchInfo);
        },
        onSkip: () {
          Navigator.pop(context);
          _stopSearching();
          // Optionally restart search
          _startSearching();
        },
      ),
    );
  }

  Future<void> _initiateCall(Map<String, dynamic> matchInfo) async {
    

    final callType = matchInfo['callType'] as String? ?? _selectedCallType;

    final callId = await _randomCallService.initiateCallWithMatch(
      callerId: _currentUserId!,
      callerName: _currentUser!.name,
      callerPhoto: _currentUser!.photoURL,
      receiverId: matchInfo['matchedUserId'] as String,
      receiverName: matchInfo['matchedUserName'] as String? ?? 'User',
      receiverPhoto: matchInfo['matchedUserPhoto'] as String?,
      callType: callType,
    );

    if (callId == null) {
      
      _showErrorSnackbar('Failed to start call. Please try again.');
      _stopSearching();
      return;
    }

    // Create a temporary UserModel for the matched user
    final matchedUser = UserModel(
      uid: matchInfo['matchedUserId'] as String,
      name: matchInfo['matchedUserName'] as String? ?? 'User',
      email: '',
      photoURL: matchInfo['matchedUserPhoto'] as String?,
      photos: matchInfo['matchedUserPhoto'] != null
          ? [matchInfo['matchedUserPhoto'] as String]
          : [],
      gender: matchInfo['matchedUserGender'] as String?,
      age: matchInfo['matchedUserAge'] as int?,
      country: matchInfo['matchedUserCountry'] as String?,
      level: matchInfo['matchedUserLevel'] as int? ?? 0,
      isVerified: matchInfo['matchedUserIsVerified'] as bool? ?? false,
      isVip: matchInfo['matchedUserIsVip'] as bool? ?? false,
      createdAt: DateTime.now(),
    );

    setState(() {
      _isSearching = false;
      _currentQueueId = null;
    });

    if (!mounted) return;

    // Navigate to call screen
    if (callType == 'video') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RandomMatchCallScreen(
            callId: callId,
            otherUser: matchedUser,
            isOutgoing: true,
          ),
        ),
      );
      
      if (result == 'match_next' && mounted) {
        _startSearching();
      }
    } else {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VoiceCallScreen(
            callId: callId,
            otherUser: matchedUser,
            isOutgoing: true,
          ),
        ),
      );

      if (result == 'match_next' && mounted) {
        _startSearching();
      }
    }
  }

  void _showFilterBottomSheet() {
    

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        preferredGender: _preferredGender,
        minAge: _minAge,
        maxAge: _maxAge,
        preferredCountry: _preferredCountry,
        preferredLanguage: _preferredLanguage,
        onApply: (gender, minAge, maxAge, country, language) {
          setState(() {
            _preferredGender = gender;
            _minAge = minAge;
            _maxAge = maxAge;
            _preferredCountry = country;
            _preferredLanguage = language;
          });
          Navigator.pop(context);
          
          
          
          
          
        },
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatSearchTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    
    _pulseController.dispose();
    _rotateController.dispose();
    _searchTimer?.cancel();
    _matchSubscription?.cancel();
    if (_currentUserId != null) {
      _randomCallService.leaveQueue(_currentUserId!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Random Call',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_isSearching) {
              _stopSearching();
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.tune, color: Colors.white),
              onPressed: _showFilterBottomSheet,
            ),
        ],
      ),
      body: SafeArea(
        child: _isSearching ? _buildSearchingView() : _buildIdleView(),
      ),
    );
  }

  Widget _buildIdleView() {
    return Stack(
      children: [
        // 1. Background Elements (Orbs)
        Positioned(
          top: -50,
          right: -50,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.purple.withOpacity(0.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.2),
                  blurRadius: 50,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -30,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withOpacity(0.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        ),

        // 2. Main Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Title Area
              Text(
                _currentUser?.isHost == true ? 'Go Online' : 'Explore\nthe World',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  _currentUser?.isHost == true 
                      ? 'Wait for incoming calls' 
                      : 'Meet random people instantly',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),

              const Spacer(),

              // 3. Central Interactive Area
              Center(
                child: Column(
                  children: [
                    // Call Type Selector (Removed Voice Option)
                    /*
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCallTypeOption('video', 'Video Chat', Icons.videocam_rounded),
                          const SizedBox(width: 8),
                          _buildCallTypeOption('voice', 'Voice Call', Icons.mic_rounded),
                        ],
                      ),
                    ),
                    */
                    
                    const SizedBox(height: 50),

                    // Start Button (Premium Glow)
                    GestureDetector(
                      onTap: _startSearching,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF1493), Color(0xFFFF69B4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF1493).withOpacity(0.5),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Inner Glow Ring
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _currentUser?.isHost == true ? Icons.sensors : Icons.rocket_launch, 
                                  color: Colors.white, 
                                  size: 48
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _currentUser?.isHost == true ? 'WAIT' : 'GO',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // 4. Online Stats
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.public, color: Colors.greenAccent, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '$_usersSearching Users Online',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
        
        // Settings Button (Top Right)
        Positioned(
          top: 10,
          right: 20,
           child: IconButton(
            icon: const Icon(Icons.tune, color: Colors.white),
            onPressed: _showFilterBottomSheet,
          ),
        ),
      ],
    );
  }

  Widget _buildCallTypeOption(String type, String label, IconData icon) {
    final isSelected = _selectedCallType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCallType = type;
        });
        
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E1E1E) : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFFF1493) : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget removed as it's merged into _buildIdleView directly
  // Widget _buildStartButton() { ... }



  Widget _buildSearchingView() {
    return Stack(
      children: [
        // 1. Radar Background (Painter)
        Positioned.fill(
          child: CustomPaint(
            painter: _RadarPainter(_rotateController),
          ),
        ),

        // 2. Center User Avatar (Pulsing)
        Center(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 100 * _pulseAnimation.value,
                height: 100 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFF1493).withOpacity(0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF1493).withOpacity(0.3),
                      blurRadius: 20 * _pulseAnimation.value,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  backgroundImage: _currentUser?.photos.isNotEmpty == true 
                      ? NetworkImage(_currentUser!.photos[0]) 
                      : null,
                  backgroundColor: Colors.grey[900],
                  child: _currentUser?.photos.isEmpty == true 
                      ? const Icon(Icons.person, color: Colors.white, size: 40) 
                      : null,
                ),
              );
            },
          ),
        ),

        // 3. Floating "Fake" Users (Simulating scan)
        ...List.generate(5, (index) {
          final angle = (index * 72 + _rotateController.value * 360) * 3.14159 / 180;
          final radius = 120.0 + (index % 2) * 50;
          return Positioned(
            left: MediaQuery.of(context).size.width / 2 + radius * 0.8 * -1 * (index % 2 == 0 ? 1 : -1) - 20, // Simple orbit logic
            top: MediaQuery.of(context).size.height / 2 + radius * 0.8 * (index % 3 == 0 ? 1 : -1) - 20,
            child: Opacity(
              opacity: 0.6,
              child: AnimatedBuilder(
                 animation: _rotateController,
                 builder: (context, child) {
                   // Simple mock orbit movement
                   return Transform.translate(
                     offset: Offset(
                       50 * (index % 2 == 0 ? 1 : -1) * _rotateController.value, 
                       30 * (index % 3 == 0 ? 1 : -1) * _rotateController.value
                     ),
                     child: _buildMockUserAvatar(index),
                   );
                 }
              ),
            ),
          );
        }),

        // 4. Bottom Controls
        Column(
          children: [
            const Spacer(flex: 3),
            
            // Searching Text
            Text(
              _currentUser?.isHost == true ? 'Waiting for users...' : 'Finding your perfect match...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                shadows: [Shadow(color: Colors.black, blurRadius: 10)],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                 _currentUser?.isHost == true ? 'You are visible to users' : 'Searching in global queue...',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
              ),
            ),

            const Spacer(flex: 1),

            // Cancel Button
            GestureDetector(
              onTap: _stopSearching,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  border: Border.all(color: Colors.white54, width: 2),
                ),
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ],
    );
  }

  Widget _buildMockUserAvatar(int index) {
    // Just mock avatars for visuals (could be real nearby users later)
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.5)),
        image: const DecorationImage(
           image: NetworkImage('https://i.pravatar.cc/150?img=10'), // Placeholder
           fit: BoxFit.cover,
        ),
      ),
    );
  }
}

// 🖌️ Radar Painter
class _RadarPainter extends CustomPainter {
  final Animation<double> animation;
  _RadarPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric circles
    for (int i = 1; i <= 3; i++) {
      paint.color = Colors.white.withOpacity(0.1 * i);
      canvas.drawCircle(center, 100.0 * i, paint);
    }

    // Draw Sweep Gradient
    final rect = Rect.fromCircle(center: center, radius: 300);
    final gradient = SweepGradient(
      startAngle: 0.0,
      endAngle: 6.28, // 360
      colors: [
        Colors.transparent,
        const Color(0xFFFF1493).withOpacity(0.1),
        const Color(0xFFFF1493).withOpacity(0.5),
      ],
      stops: const [0.0, 0.7, 1.0],
      transform: GradientRotation(animation.value * 6.28),
    );

    final radarPaint = Paint()
      ..shader = gradient.createShader(rect);

    canvas.drawCircle(center, 300, radarPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==================== MATCH FOUND DIALOG ====================

class _MatchFoundDialog extends StatelessWidget {
  final Map<String, dynamic> matchInfo;
  final VoidCallback onStartCall;
  final VoidCallback onSkip;

  const _MatchFoundDialog({
    required this.matchInfo,
    required this.onStartCall,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final name = matchInfo['matchedUserName'] as String? ?? 'User';
    final photo = matchInfo['matchedUserPhoto'] as String?;
    final age = matchInfo['matchedUserAge'] as int?;
    final country = matchInfo['matchedUserCountry'] as String?;
    final isVerified = matchInfo['matchedUserIsVerified'] as bool? ?? false;
    final gender = matchInfo['matchedUserGender'] as String?;
    final isVip = matchInfo['matchedUserIsVip'] as bool? ?? false;
    
    final bool hasPhoto = photo != null && photo.isNotEmpty && photo.startsWith('http');
    
    debugPrint('📸 [DEBUG] Match Found Popup - Photo URL: $photo | hasPhoto: $hasPhoto');

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E).withOpacity(0.85),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🏷️ Premium Match Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00F260), Color(0xFF0575E6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'MATCH FOUND!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 👤 Avatar with Glowing Frame
              Stack(
                alignment: Alignment.center,
                children: [
                   // Glowing outer ring
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.shade400,
                          Colors.pink.shade400,
                          Colors.blue.shade400,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // White border
                  Container(
                    width: 124,
                    height: 124,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Actual Avatar
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: hasPhoto
                          ? DecorationImage(
                              image: NetworkImage(photo),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: const Color(0xFF2E2E3E),
                    ),
                    child: !hasPhoto
                        ? Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                  ),
                  // Verified Icon
                  if (isVerified && gender?.toLowerCase() == 'male')
                    Positioned(
                      bottom: 5,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                        child: const Icon(
                          Icons.verified,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // 📝 Name & VIP Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (isVip) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'VIP',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 6),

              // 📍 Info (Age & Country)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${age ?? '??'} yrs • ${country ?? 'Global'}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // 🔘 Action Buttons
              Row(
                children: [
                  // Skip Button
                  Expanded(
                    child: TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        backgroundColor: Colors.white.withOpacity(0.05),
                      ),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Start Call Button (THE ACTION)
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF0080), Color(0xFFFF8C00)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF0080).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: onStartCall,
                        icon: const Icon(Icons.videocam_rounded, color: Colors.white),
                        label: const Text(
                          'Start Call',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== FILTER BOTTOM SHEET ====================

class _FilterBottomSheet extends StatefulWidget {
  final String? preferredGender;
  final int minAge;
  final int maxAge;
  final String? preferredCountry;
  final String? preferredLanguage;
  final Function(
          String? gender, int minAge, int maxAge, String? country, String? language)
      onApply;

  const _FilterBottomSheet({
    required this.preferredGender,
    required this.minAge,
    required this.maxAge,
    required this.preferredCountry,
    required this.preferredLanguage,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String? _gender;
  late RangeValues _ageRange;
  late String? _country;
  late String? _language;

  final List<String> _genderOptions = ['Any', 'Male', 'Female'];
  final List<String> _countryOptions = [
    'Any',
    'Philippines',
    'India',
    'Pakistan',
    'Bangladesh',
    'Vietnam',
    'USA',
    'UK',
    'Canada',
    'Australia',
    'Saudi Arabia',
    'UAE',
    'Thailand',
    'Indonesia',
    'Malaysia',
  ];
  final List<String> _languageOptions = [
    'Any',
    'English',
    'Hindi',
    'Tagalog',
    'Arabic',
    'Spanish',
    'Vietnamese',
    'Thai',
    'Indonesian',
    'Bengali',
    'Urdu',
  ];

  @override
  void initState() {
    super.initState();
    _gender = widget.preferredGender;
    _ageRange = RangeValues(widget.minAge.toDouble(), widget.maxAge.toDouble());
    _country = widget.preferredCountry;
    _language = widget.preferredLanguage;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _gender = null;
                    _ageRange = const RangeValues(18, 50);
                    _country = null;
                    _language = null;
                  });
                },
                child: const Text(
                  'Reset',
                  style: TextStyle(color: Colors.purple),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Gender
          const Text(
            'Gender',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _genderOptions.map((option) {
              final isSelected =
                  (option == 'Any' && _gender == null) || option == _gender;
              return ChoiceChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _gender = option == 'Any' ? null : option;
                  });
                },
                selectedColor: Colors.purple,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Age Range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Age Range',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${_ageRange.start.round()} - ${_ageRange.end.round()}',
                style: const TextStyle(
                  color: Colors.purple,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RangeSlider(
            values: _ageRange,
            min: 18,
            max: 80,
            divisions: 62,
            activeColor: Colors.purple,
            inactiveColor: Colors.white.withValues(alpha: 0.2),
            onChanged: (values) {
              setState(() {
                _ageRange = values;
              });
            },
          ),

          const SizedBox(height: 24),

          // Country
          const Text(
            'Country',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<String>(
              value: _country ?? 'Any',
              isExpanded: true,
              dropdownColor: const Color(0xFF2D1B69),
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white),
              items: _countryOptions
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _country = value == 'Any' ? null : value;
                });
              },
            ),
          ),

          const SizedBox(height: 24),

          // Language
          const Text(
            'Language',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<String>(
              value: _language ?? 'Any',
              isExpanded: true,
              dropdownColor: const Color(0xFF2D1B69),
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white),
              items: _languageOptions
                  .map((l) => DropdownMenuItem(
                        value: l,
                        child: Text(l),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _language = value == 'Any' ? null : value;
                });
              },
            ),
          ),

          const SizedBox(height: 32),

          // Apply button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(
                  _gender,
                  _ageRange.start.round(),
                  _ageRange.end.round(),
                  _country,
                  _language,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
