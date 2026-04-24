import 'dart:async';
import 'dart:ui';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:dating_live_app/widgets/party_room_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../services/database_service.dart';
import '../../services/agora_service.dart';
import '../../services/aviator_game_service.dart';
import '../../services/dice_game_service.dart';
import '../../services/sound_service.dart';
import '../../models/seat_model.dart';
import '../../providers/user_provider.dart';
import '../../providers/beauty_settings_provider.dart';
import '../../models/user_model.dart';

import '../../widgets/party_room_background.dart';
import '../../widgets/party_room_simple_header.dart';
import '../../widgets/party_room_seat.dart';
import '../../widgets/party_room_header.dart';
import '../../widgets/party_room_chat_list_updated.dart';
import '../../widgets/party_room/entrance_effect_widget.dart';
import '../../widgets/party_room_entrance_effect.dart';
import '../../widgets/coin_rain_animation.dart';
import '../../widgets/live/global_gift_overlay.dart';
import '../../widgets/game_selection_widget.dart';
import '../../widgets/room_summary_dialog.dart';
import '../../widgets/party_room/host_controls_menu.dart';
import '../../widgets/live/guest_apply_sheet.dart';
import '../../widgets/party_room/room_settings_sheet.dart';
import '../../widgets/live/gift_picker_sheet.dart';
import '../../widgets/live/beauty_settings_sheet.dart';
import '../../widgets/party_room/spin_wheel_widget.dart';
import '../../widgets/party_room/room_stats_widget.dart';
import '../../widgets/party_room/entrance_notification_widget.dart';
import '../../widgets/party_room/user_quick_profile_sheet.dart';
import '../../widgets/party_room/block_confirmation_dialog.dart';
import '../../services/notification_service.dart';
import '../../widgets/live/grid_menu_sheet.dart';
import '../../widgets/live/room_messages_sheet.dart';
import '../../widgets/live/social_share_sheet.dart';
import '../../widgets/live/top_up_sheet.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../games/aviator_game_widget.dart';
import '../../games/dice_game_widget.dart';
import '../../games/car_racing_game_widget.dart';

class PartyRoomScreen extends StatefulWidget {
  const PartyRoomScreen({super.key});

  @override
  State<PartyRoomScreen> createState() => _PartyRoomScreenState();
}

class _PartyRoomScreenState extends State<PartyRoomScreen>
    with TickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final AgoraService _agoraService = AgoraService();
  final SoundService _soundService = SoundService();
  final TextEditingController _messageController = TextEditingController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final NotificationService _notificationService = NotificationService();

  Map<String, dynamic>? _roomData;
  bool _hasJoined = false;
  bool _isLoading = true;
  bool _showSimpleView = false;
  bool _showDiamondRain = false;
  bool _showChatInput = false;
  List<Map<String, dynamic>> _topContributors = [];

  // Phase 1 Variables
  StreamSubscription<Map<String, dynamic>?>? _roomSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _seatRequestSubscription;
  StreamSubscription<Map<String, bool>>? _micStatusSubscription;
  StreamSubscription<Map<String, dynamic>?>? _micInvitationSubscription;
  StreamSubscription<QuerySnapshot>? _eventsSubscription;

  // Entrance Effect Key
  final GlobalKey<EntranceEffectWidgetState> _entranceEffectKey = GlobalKey();

  bool _isAgoraInitialized = false;
  bool _isInVoiceChannel = false;
  Map<String, bool> _userMicStatus = {};
  final ValueNotifier<Map<String, bool>> _micStatusNotifier = ValueNotifier({});

  List<Map<String, dynamic>> _pendingSeatRequests = [];
  final ValueNotifier<int> _pendingRequestsCountNotifier = ValueNotifier(0);

  // Agora Video Tracking
  final Set<int> _remoteUids = {};
  final Set<int> _speakingUsers = {}; // ADDED
  final ValueNotifier<Set<int>> _speakingUsersNotifier = ValueNotifier({});

   // Phase 3 Variables
   bool _isFollowing = false;
   bool _isJoining = false;   // Lock to prevent infinite join loops
   bool _joinFailed = false;  // Mark if a join attempt permanently failed
   final bool _canPop = false; // Fix: Allow navigation control
  // Removed final _isVideoEnabled = false;

  // Games Module State
  String? _activeGameId;
  bool _isGameOverlayVisible = false;
  bool _wasSeated = false;

  // Overlay management
  final List<OverlayEntry> _overlayEntries = [];

  // ELITE PERFORMANCE 2.0: De-coupled Room Data
  late ValueNotifier<Map<String, dynamic>?> _roomDataNotifier;
  final Map<String, UserModel> _userCache = {};
  final Set<String> _fetchingUserIds = {};

  // Session Tracking
  late DateTime _sessionStartTime;

  bool get _isSeated {
    if (_roomData == null || _roomData!['seats'] == null) return false;
    final seats = _roomData!['seats'] as Map<dynamic, dynamic>;
    return seats.values.any((seat) {
      if (seat is String) return seat == _currentUserId;
      if (seat is Map) return seat['userId'] == _currentUserId;
      return false;
    });
  }

  bool get isHost => _roomData?['hostId'] == _currentUserId;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _pulseController; // Added for Hero Mic

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(1.0, 0.0)).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
        );

    // Initialize Pulse Controller
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // ELITE PERFORMANCE 2.0: Initialize Notifiers
    _roomDataNotifier = ValueNotifier<Map<String, dynamic>?>(null);

    _enableScreenshotProtection();
    _initializeAgora();
  }

  Future<void> _enableScreenshotProtection() async {
    await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
  }

  Future<void> _disableScreenshotProtection() async {
    await FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
  }

  Future<void> _initializeAgora() async {
    try {
      // 🚨 CRITICAL FIX: Request permissions first!
      final status = await [Permission.microphone, Permission.camera].request();
      debugPrint(
        '[AGORA_DEBUG] 🎤 Mic: ${status[Permission.microphone]}, 📷 Cam: ${status[Permission.camera]}',
      );

      // CRITICAL FIX: Actually call the initialization logic in the service first
      debugPrint('[AGORA_DEBUG] 📝 Starting Agora Service Initialization...');
      await _agoraService.initialize();

      // Register event handlers for tracking video users
      _agoraService.registerEventHandlers(
        onUserJoined: (connection, remoteUid, elapsed) {
          setState(() => _remoteUids.add(remoteUid));

          // Trigger Entrance Effect (Mock logic for now)
          _entranceEffectKey.currentState?.playEffect(
            EntranceEffectData(
              userName: 'User $remoteUid',
              animationName: 'VIP Entrance',
            ),
          );
        },
        onUserOffline: (connection, remoteUid, reason) {
          setState(() => _remoteUids.remove(remoteUid));
        },
        onAudioVolumeIndication:
            (connection, speakers, speakerNumber, totalVolume) {
              if (mounted) {
                final speaking = <int>{};
                for (var speaker in speakers) {
                  if ((speaker.volume ?? 0) > 5 && (speaker.vad ?? 0) == 1) {
                    if (speaker.uid == 0) {
                      speaking.add(_currentUserId.hashCode.abs() % 1000000);
                    } else {
                      speaking.add(speaker.uid!);
                    }
                  }
                }
                _speakingUsers.clear();
                _speakingUsers.addAll(speaking);
                _speakingUsersNotifier.value = Set.from(speaking);
              }
            },
      );

      // Enable volume indication
      await _agoraService.enableAudioVolumeIndication(
        interval: 200,
        smooth: 3,
        reportVad: true,
      );

      if (mounted) {
        setState(() => _isAgoraInitialized = true);
        debugPrint('[AGORA_DEBUG] ✅ PartyRoom Agora Initialization Complete');
      }
    } catch (e) {
      debugPrint('[AGORA_DEBUG] ❌ PartyRoom Agora Initialization Error: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_roomData == null && _isLoading) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map<String, dynamic>) {
        if (args.containsKey('roomId')) {
          _setupRoomStream(args['roomId'] as String);
        } else {
          _updateRoomData(args);
          if (!_hasJoined) _joinRoom();
          _loadTopContributors();
          _checkFollowStatus();
        }
      }
    }
  }

  void _setupRoomStream(String roomId) {
    _roomSubscription?.cancel();

    _roomSubscription = _databaseService
        .getPartyRoomStream(roomId)
        .listen(
          (data) {
            if (data != null && mounted) {
              _updateRoomData(data);
            } else {
              if (mounted && _roomData != null) {
                // Room was deleted/ended by host
                if (isHost) {
                  _showEndScreenAndExit();
                } else {
                  _exitToHome();
                }
              } else if (mounted) {
                _exitToHome();
              }
            }
          },
          onError: (error) {
            if (mounted) {
              _isLoading = false;
              debugPrint('[DEBUG_PARTY] 💥 Room stream error ignored: $error');
            }
          },
        );

    _seatRequestSubscription?.cancel();
    _seatRequestSubscription = _databaseService
        .getPendingSeatRequests(roomId)
        .listen((requests) {
          if (mounted) {
            debugPrint(
              '[DEBUG_SEAT] 📥 UI Listener received ${requests.length} requests for Room=$roomId',
            );
            // Show notification to host if request count increased
            if (isHost && requests.length > _pendingSeatRequests.length) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('New seat request received! ✋'),
                  duration: Duration(seconds: 2),
                  backgroundColor: Color(0xFFFF1493),
                ),
              );
            }

            _pendingSeatRequests = requests;
            _pendingRequestsCountNotifier.value = requests.length;
          }
        });

    _micStatusSubscription?.cancel();
    _micStatusSubscription = _databaseService.getMicStatusStream(roomId).listen(
      (status) {
        if (mounted) {
          _userMicStatus = status;
          _micStatusNotifier.value = Map.from(status);
        }
      },
    );

    _micInvitationSubscription?.cancel();
    _micInvitationSubscription = _databaseService
        .getMicInvitationStream(roomId, _currentUserId)
        .listen((invitation) {
          if (invitation != null &&
              invitation['status'] == 'pending' &&
              mounted) {
            _showMicInvitationDialog(invitation['hostName'] ?? 'Host');
          }
        });

    // 🌟 GLOBAL GIFT EVENTS LISTENER
    _eventsSubscription?.cancel();
    final joinTime = Timestamp.now();
    _eventsSubscription = FirebaseFirestore.instance
        .collection('party_rooms')
        .doc(roomId)
        .collection('events')
        .where('timestamp', isGreaterThan: joinTime)
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final event = change.doc.data();
              if (event != null && event['type'] == 'GIFT' && mounted) {
                _showGiftOverlay(event);
              }
            }
          }
        });
  }

  Future<void> _handleMicToggle(int seatIndex, bool val) async {
    debugPrint(
      '[DEEP_LOGIC] 🎬 _handleMicToggle START: Seat=$seatIndex, NewValue=$val',
    );
    if (_roomData == null) return;

    try {
      await _databaseService.updateUserMicStatus(
        roomId: _roomData!['roomId'],
        userId: _currentUserId,
        isMicOn: val,
      );

      // Apply to Agora engine if it's the current user
      if (val) {
        await _agoraService.unmute();
      } else {
        await _agoraService.mute();
      }

      if (mounted) {
        _userMicStatus[_currentUserId] = val;
        _micStatusNotifier.value = Map.from(_userMicStatus);
      }
    } catch (e) {
      debugPrint('[DEEP_LOGIC] ❌ _handleMicToggle FAILED: $e');
    }
  }

  void _updateRoomData(Map<String, dynamic> data) {
    if (!mounted) return;

    // 1. Update Notifier (Triggers localized rebuilds for Header/Seats)
    _roomDataNotifier.value = data;
    _roomData = data; // Keep for backward compatibility

    // 💰 CONTINUOUSLY SYNC GAME SERVICES WITH HOST STATUS
    final String roomId = data['roomId'] ?? data['id'] ?? '';
    if (roomId.isNotEmpty) {
      AviatorGameService().setRoomContext(roomId, 'party_room', isHost: isHost);
      DiceGameService().setRoomContext(roomId, 'party_room', isHost: isHost);
    }

    _hasJoined =
        (data['participants'] as List?)?.contains(_currentUserId) ?? false;

    // Sync Game State
    final dynamic rawActiveGame = data['activeGame'];
    if (rawActiveGame != null && rawActiveGame is Map) {
      final String? gameId = rawActiveGame['gameId']?.toString();
      if (gameId != null && gameId.isNotEmpty) {
        _activeGameId = gameId;
        _isGameOverlayVisible = true;
        if (gameId == 'aviator') {
          AviatorGameService().syncWithFirestore(
            rawActiveGame as Map<String, dynamic>,
          );
        } else if (gameId == 'dice') {
          DiceGameService().syncWithFirestore(
            rawActiveGame as Map<String, dynamic>,
          );
        }
      }
    } else {
      if (!isHost || _activeGameId == null) {
        _activeGameId = null;
        _isGameOverlayVisible = false;
      }
    }

    _syncHardwareWithRoomState();
    _isLoading = false;

    // 3. Trigger User Prefetching
    _prefetchUsers(data);

    // 4. Auto-Unmute logic
    _handleAutoUnmuteLogic();

    if (!_hasJoined && !_isJoining && !_joinFailed) {
      _joinRoom();
    } else if (_hasJoined && !_isInVoiceChannel && _isAgoraInitialized) {
      _joinVoiceChannel();
    }
    _loadTopContributors();
  }

  void _prefetchUsers(Map<String, dynamic> data) async {
    final List<String> userIdsToFetch = [];

    // Collect IDs from seats
    final seatsMap = data['seats'] as Map<dynamic, dynamic>?;
    if (seatsMap != null) {
      for (var val in seatsMap.values) {
        String? uid;
        if (val is String) {
          uid = val;
        } else if (val is Map)
          uid = val['userId']?.toString();

        if (uid != null &&
            !_userCache.containsKey(uid) &&
            !_fetchingUserIds.contains(uid)) {
          userIdsToFetch.add(uid);
          _fetchingUserIds.add(uid);
        }
      }
    }

    // Fetch in batches
    for (final uid in userIdsToFetch) {
      _databaseService.getUserById(uid).then((user) {
        if (user != null && mounted) {
          _userCache[uid] = user;
          // ELITE PERFORMANCE 2.0: Trigger localized rebuilds via notifyListeners replacement
          _roomDataNotifier.value = Map.from(_roomDataNotifier.value ?? {});
        }
        _fetchingUserIds.remove(uid);
      });
    }
  }

  void _handleAutoUnmuteLogic() {
    if (!_wasSeated && _isSeated) {
      _wasSeated = true;
      int mySeatIndex = -1;
      final seatsMap = _roomData!['seats'] as Map<dynamic, dynamic>?;
      if (seatsMap != null) {
        seatsMap.forEach((k, v) {
          if (v is Map && v['userId'] == _currentUserId) {
            mySeatIndex = int.tryParse(k.toString()) ?? -1;
          }
        });
      }
      if (mySeatIndex != -1) {
        _handleMicToggle(mySeatIndex, true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your seat request was approved! Mic is ON. 🎤'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else if (_wasSeated && !_isSeated) {
      _wasSeated = false;
      _handleMicToggle(-1, false);
    }
  }

  void _showGiftOverlay(Map<String, dynamic> event) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => GlobalGiftOverlay(
        event: event,
        onComplete: () {
          if (entry.mounted) {
            entry.remove();
            _overlayEntries.remove(entry);
          }
        },
      ),
    );
    _overlayEntries.add(entry);
    overlay.insert(entry);
  }

  void _loadTopContributors() {
    final participants = List<String>.from(_roomData!['participants'] ?? []);
    setState(() {
      _topContributors = participants.take(4).map((userId) {
        return {'userId': userId, 'diamonds': (userId.hashCode % 10000) + 1000};
      }).toList();
    });
  }

  Future<void> _checkFollowStatus() async {
    if (_roomData == null) return;

    final isFollowing = await _databaseService.isFollowingRoom(
      roomId: _roomData!['roomId'],
      userId: _currentUserId,
    );

    if (mounted) {
      setState(() => _isFollowing = isFollowing);
    }
  }

  Future<void> _joinRoom() async {
    if (_roomData == null || _isJoining || _joinFailed) return;

    setState(() {
      _isJoining = true;
    });

    final roomId = _roomData!['roomId'];

    debugPrint('[DEBUG_JOIN] 🚪 Attempting to join room: $roomId');

    // Check if user is blocked
    final isBlocked = await _databaseService.isUserBlockedFromRoom(
      roomId: roomId,
      userId: _currentUserId,
    );

    if (isBlocked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are blocked from this room'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    final success = await _databaseService.joinPartyRoom(
      roomId: roomId,
      userId: _currentUserId,
    );

    if (mounted) {
      setState(() {
        _isJoining = false;
        if (success) {
          _hasJoined = true;
          _joinFailed = false; // Reset if it was set before
          debugPrint('[DEBUG_JOIN] ✅ Successfully joined room');
        } else {
          _joinFailed = true; // Mark as failed to prevent re-join loops
          debugPrint('[DEBUG_JOIN] ❌ Failed to join room (Permission or other issue)');
        }
      });
    }

    if (success && mounted) {

      await _joinVoiceChannel();

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;

      if (currentUser != null) {
        // Track entrance
        await _databaseService.trackUserEntrance(
          roomId: roomId,
          userId: currentUser.uid,
          userName: currentUser.name,
          userPhoto: currentUser.photos.isNotEmpty
              ? currentUser.photos[0]
              : null,
          userLevel: currentUser.level,
          isVip: currentUser.isVip ?? false,
        );

        // SILENT CHAT JOIN MESSAGE (For everyone)
        await _databaseService.sendSystemMessage(
          roomId: roomId,
          text: '👋 ${currentUser.name} joined the room',
        );

        // VIP OR HIGH LEVEL ENTRY (Visual Show)
        final bool isVipOrHighLevel =
            (currentUser.isVip == true) || (currentUser.level >= 10);

        if (isVipOrHighLevel) {
          // Show entrance notification to all users
          EntranceNotificationManager.show(
            context: context,
            userName: currentUser.name,
            userPhoto: currentUser.photos.isNotEmpty
                ? currentUser.photos[0]
                : null,
            userLevel: currentUser.level,
            isVip: currentUser.isVip ?? false,
          );

          // Entrance effect animation
          final overlay = Overlay.of(context);
          late OverlayEntry entry;
          entry = OverlayEntry(
            builder: (context) => PartyRoomEntranceEffect(
              userName: currentUser.name,
              userPhoto: currentUser.photos.isNotEmpty
                  ? currentUser.photos[0]
                  : null,
              userLevel: currentUser.level,
              isVip: currentUser.isVip ?? false,
              onComplete: () => entry.remove(),
            ),
          );
          overlay.insert(entry);
        }
      }
    }
  }

  Future<void> _joinVoiceChannel() async {
    debugPrint(
      '[DEEP_DEBUG] PartyRoomScreen._joinVoiceChannel() called. _roomData: ${_roomData?.keys.toList()}',
    );
    if (_roomData == null) {
      debugPrint(
        '[DEEP_DEBUG] 🛑 Aborting _joinVoiceChannel: _roomData is null',
      );
      return;
    }

    // Safety check: Prevent infinite loop if Agora is not configured
    final activeAppId = AgoraService.appId;
    debugPrint(
      '[DEEP_DEBUG] 📝 PartyRoom checking App ID for Join: "$activeAppId"',
    );
    if (activeAppId.isEmpty) {
      debugPrint('[DEEP_DEBUG] 🛑 Aborting join: activeAppId is exactly empty');
      debugPrint('[AGORA_DEBUG] 🛑 Aborting join: Missing AGORA_APP_ID');
      return;
    }

    // Ensure Agora is initialized. If not, wait briefly and retry once.
    if (!_isAgoraInitialized) {
      debugPrint(
        '[AGORA_DEBUG] ⏳ Agora not ready during join trigger. Waiting 2 seconds...',
      );
      await Future.delayed(const Duration(seconds: 2));
      if (!_isAgoraInitialized) {
        debugPrint('[AGORA_DEBUG] ❌ Agora still not ready. Join aborted.');
        return;
      }
    }

    try {
      final ruid = _currentUserId.hashCode.abs() % 1000000;

      debugPrint('[DEBUG_TOKEN] 🔍 Using Unified UID for Token & Join: $ruid');

      final token = await _databaseService.generateAgoraToken(
        channelName: _roomData!['roomId'],
        uid: ruid,
      );

      debugPrint(
        '[DEBUG_TOKEN] 🗝️ TOKEN_VALUE: "$token" (Length: ${token.length})',
      );

      debugPrint(
        '[AGORA_DEBUG] 🔑 JOIN_TRIGGER: Channel=${_roomData!['roomId']} with UID=$ruid. AgoraReady=$_isAgoraInitialized',
      );

      final success = await _agoraService.joinChannel(
        channelId: _roomData!['roomId'],
        token: token,
        uid: ruid,
        isBroadcaster: true, // Default to broadcaster for party participants
        enableVideo:
            _roomData?['roomType'] == 'video' ||
            _roomData?['roomType'] ==
                'game', // Enable for both video and game modes
      );

      if (success && mounted) {
        setState(() => _isInVoiceChannel = true);

        // Apply persistent beauty settings if broadcaster
        final beautySettings = context.read<BeautySettingsProvider>();
        await _agoraService.updateAdvancedBeautyEffects(
          smooth: beautySettings.smooth,
          whiten: beautySettings.whiten,
          sharpen: beautySettings.sharpen,
          clarity: beautySettings.clarity,
          temp: beautySettings.colorTemp,
          tone: beautySettings.colorTone,
          saturation: beautySettings.saturation,
          brightness: beautySettings.brightness,
          contrast: beautySettings.contrast,
          faceSlim: beautySettings.faceSlim,
          eyeSize: beautySettings.eyeSize,
          filterName: beautySettings.activeFilter.name,
          filterIntensity: beautySettings.filterIntensity,
        );

        await _databaseService.updateUserMicStatus(
          roomId: _roomData!['roomId'],
          userId: _currentUserId,
          isMicOn: !_agoraService.isMuted,
        );

        // Auto-enable video for host in Video Mode
        if (_roomData?['roomType'] == 'video' &&
            _currentUserId == _roomData?['hostId']) {
          debugPrint('[DEBUG_PARTY] 🎭 Host auto-on triggered for Video Mode');
          final hostSeat = _getSeatModel(0);
          if (hostSeat.userId == _currentUserId) {
            await _toggleVideo(0, true);
          }
        }
      }
    } catch (e) {}
  }

  Future<void> _leaveRoom() async {
    if (_roomData == null) return;

    await _agoraService.leaveChannel();

    if (mounted) {
      setState(() => _isInVoiceChannel = false);
    }

    final isHost = _roomData!['hostId'] == _currentUserId;

    if (isHost) {
      await _databaseService.deletePartyRoom(_roomData!['roomId']);
    } else {
      await _databaseService.leavePartyRoom(
        roomId: _roomData!['roomId'],
        userId: _currentUserId,
      );
    }
  }

  Future<void> _toggleVideo(int index, bool val) async {
    debugPrint(
      '[DEEP_LOGIC] 🎬 _toggleVideo START: Seat=$index, NewValue=$val',
    );
    if (_roomData == null) {
      debugPrint('[DEEP_LOGIC] ⚠️ _roomData is null, aborting toggle');
      return;
    }

    // Check if it's Audio mode (Video toggle should be disabled overall but extra safety)
    if (_roomData!['roomType'] == 'audio' && val) {
      debugPrint('[DEEP_LOGIC] ⚠️ Blocking video toggle in Audio Mode');
      return;
    }

    try {
      debugPrint('[DEEP_DATA] 📡 Updating Firestore for Seat $index...');
      await _databaseService.updateSeatVideoStatus(
        roomId: _roomData!['roomId'],
        seatIndex: index,
        isVideoOn: val,
      );
      debugPrint('[DEEP_DATA] ✅ Firestore Update Success for Seat $index');
    } catch (e) {
      debugPrint('[DEEP_DATA] ❌ Firestore Update FAILED for Seat $index: $e');
    }

    // Also toggle local camera if it's the current user
    if (mounted) {
      debugPrint('[DEEP_LOGIC] 🎥 Toggling local camera engine track: $val');
      try {
        if (val) {
          // ACQUIRE Camera Hardware
          await _agoraService.requestCameraControl(CameraOwner.agora);
        } else {
          // RELEASE Camera Hardware
          await _agoraService.requestCameraControl(CameraOwner.none);
        }

        await _agoraService.engine?.enableLocalVideo(val);
        debugPrint('[DEEP_LOGIC] ✅ Agora enableLocalVideo($val) Success');
      } catch (e) {
        debugPrint('[DEEP_LOGIC] ❌ Agora enableLocalVideo($val) FAILED: $e');
      }
    }
  }

  Future<void> _toggleMic(int index, bool val) async {
    debugPrint('[DEEP_LOGIC] 🎬 _toggleMic START: Seat=$index, NewValue=$val');
    if (_roomData == null) return;

    try {
      debugPrint(
        '[DEEP_LOGIC] 🎤 TOGGLE_MIC: Seat=$index, NewValue=$val, CurrentMicStatus=${_userMicStatus[_currentUserId]}',
      );
      await _databaseService.updateUserMicStatus(
        roomId: _roomData!['roomId'],
        userId: _currentUserId,
        isMicOn: val,
      );

      // Update local Agora state if it's the current user
      final seat = _getSeatModel(index);
      if (seat.userId == _currentUserId) {
        debugPrint('[DEEP_LOGIC] 📡 Applying Mute to Engine: ${!val}');
        if (val) {
          await _agoraService.unmute();
        } else {
          await _agoraService.mute();
        }
        debugPrint('[DEEP_LOGIC] ✅ Agora mute update Success');
      }
    } catch (e) {
      debugPrint('[DEEP_LOGIC] ❌ _toggleMic FAILED: $e');
    }
  }

  Future<void> _syncHardwareWithRoomState() async {
    if (_roomData == null) return;

    // Safety: If Agora is NOT initialized, don't try to sync hardware to prevent -7 errors
    if (!_isAgoraInitialized || _agoraService.engine == null) return;

    try {
      final mySeatData = _roomData!['seats'][_currentUserId];
      bool targetVideoOn = false;
      if (mySeatData is Map) {
        targetVideoOn = mySeatData['isVideoOn'] ?? false;
      }

      // 1. Sync Video
      if (targetVideoOn != _agoraService.isCameraEnabled) {
        debugPrint(
          '[DEEP_LOGIC] 🔄 Remote Sync: Toggling Camera to $targetVideoOn',
        );
        if (targetVideoOn) {
          await _agoraService.requestCameraControl(CameraOwner.agora);
        } else {
          await _agoraService.requestCameraControl(CameraOwner.none);
        }
        await _agoraService.engine?.enableLocalVideo(targetVideoOn);
      }

      // 2. Sync Mic
      final targetMicOn = _userMicStatus[_currentUserId] ?? false;
      final targetMuted = !targetMicOn;

      // We want to ensure local track matches targetMicOn.
      if (_agoraService.isMuted != targetMuted) {
        debugPrint(
          '[DEEP_LOGIC] 🔄 Remote Sync: Toggling Engine Mic to $targetMicOn (TargetMuted: $targetMuted)',
        );
        if (targetMicOn) {
          await _agoraService.unmute();
        } else {
          await _agoraService.mute();
        }
      }
    } catch (e) {
      debugPrint('[DEEP_LOGIC] ⚠️ Sync Hardware Error: $e');
    }
  }

  SeatModel _getSeatModel(int index) {
    if (_roomData == null || _roomData!['seats'] == null) {
      return SeatModel(index: index);
    }
    final seats = Map<String, dynamic>.from(_roomData!['seats'] ?? {});
    final val = seats[index.toString()];

    SeatModel seat;
    if (val is String) {
      seat = SeatModel(index: index, userId: val, contributionDiamonds: 0);
    } else if (val is Map) {
      final seatData = Map<String, dynamic>.from(val);
      seat = SeatModel.fromMap(seatData).copyWith(index: index);
    } else {
      seat = SeatModel(index: index);
    }

    // SYNC MIC STATUS
    if (seat.userId != null) {
      final isMicOn = _userMicStatus[seat.userId!] ?? false;
      seat = seat.copyWith(isSelfMuted: !isMicOn);
    }

    return seat;
  }

  @override
  void dispose() {
    _disableScreenshotProtection();
    debugPrint('[PARTY_DEBUG] 🛑 Disposing PartyRoomScreen...');

    // 1. Cancel all subscriptions
    _eventsSubscription?.cancel();
    _roomSubscription?.cancel();
    _seatRequestSubscription?.cancel();
    _micStatusSubscription?.cancel();
    _micInvitationSubscription?.cancel();

    // 2. Clean up overlay entries
    for (var entry in _overlayEntries) {
      if (entry.mounted) entry.remove();
    }
    _overlayEntries.clear();

    // 3. Dispose controllers
    _slideController.dispose();
    _pulseController.dispose();
    _messageController.dispose();

    // 4. Dispose Notifiers
    _micStatusNotifier.dispose();
    _pendingRequestsCountNotifier.dispose();
    _speakingUsersNotifier.dispose();

    // 5. 💰 GAME SERVICE CLEANUP: Stop all active games to prevent listener leaks
    AviatorGameService().stopGame();
    DiceGameService().stopGame();

    // 4. Safely leave room and dispose services
    if (_hasJoined && _roomData != null) {
      // Note: We don't await here since dispose is sync,
      // but _leaveRoom handles its own cleanup.
      _leaveRoom();
    }

    _agoraService.dispose();
    // 🚨 FIX: SoundService is a singleton. DO NOT dispose its player here, 
    // as it will break sound for subsequent room entries.
    // _soundService.dispose(); 


    super.dispose();
  }

  void _toggleView() {
    setState(() {
      _showSimpleView = !_showSimpleView;
      if (_showSimpleView) {
        _slideController.forward();
      } else {
        _slideController.reverse();
      }
    });
  }

  void _toggleChatInput() {
    setState(() {
      _showChatInput = !_showChatInput;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: _roomDataNotifier,
      builder: (context, data, _) {
        if (data == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Room not found',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/main',
                      (route) => false,
                    ),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        // ELITE PERFORMANCE 2.0: Extract all reactive data from the notifier
        final roomName = data['roomName'] ?? 'Party Room';
        final hostName = data['hostName'] ?? 'Unknown Host';
        final participants = List<String>.from(data['participants'] ?? []);
        
        // Use participants.length as primary source for stability if count field is zero or missing
        final participantCount = data['participantCount'] ?? participants.length;
        
        final earnings = data['earnings'] ?? 0;
        final hostId = data['hostId'] ?? '';
        final maxSeats = data['maxSeats'] ?? 12;

        final theme = data['backgroundTheme'] ?? 'purple';
        final backgroundImage = data['backgroundImage'] as String?;
        final category = data['category'] ?? 'Chat';
        final seats = Map<String, dynamic>.from(data['seats'] ?? {});
        final hasEmptySeats = seats.length < maxSeats;

        final isHost = hostId == _currentUserId;
        final isSeated = seats.values.any(
          (seat) => seat is Map && seat['userId'] == _currentUserId,
        );

        return PopScope(
          canPop: _canPop,
          onPopInvokedWithResult: (bool didPop, dynamic result) async {
            if (didPop) return;
            await _handleClose();
          },
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.velocity.pixelsPerSecond.dx > 500) {
                  if (!_showSimpleView) _toggleView();
                } else if (details.velocity.pixelsPerSecond.dx < -500) {
                  if (_showSimpleView) _toggleView();
                }
              },
              child: Stack(
                children: [
                  // 1. Static Background
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: PartyRoomBackground(
                        theme: theme.toLowerCase(),
                        showParticles: true,
                        showCastle: true,
                        backgroundImage: backgroundImage,
                        category: category,
                      ),
                    ),
                  ),

                  // 2. Animations
                  Positioned.fill(
                    child: DiamondRainAnimation(isActive: _showDiamondRain),
                  ),

                  // 3. Simple View (Minimized)
                  _buildSimpleView(
                    hostId,
                    hostName,
                    earnings,
                    participants,
                    theme,
                    isHost,
                    maxSeats,
                    hasEmptySeats,
                  ),

                  // 4. Full View (Animated)
                  SlideTransition(
                    position: _slideAnimation,
                    child: _buildFullView(
                      roomName,
                      participantCount,
                      earnings,
                      hostId,
                      maxSeats,
                      participants,
                      theme,
                      hostName,
                      isHost,
                      hasEmptySeats,
                    ),
                  ),

                  // 5. Entrance Effect Overlay
                  EntranceEffectWidget(key: _entranceEffectKey),

                  // 6. Game Overlay
                  RepaintBoundary(child: _buildGameOverlay()),

                  // === FLOATING PREMIUM UI ===
                  // 1. Hero Mic Button
                  if (!_isGameOverlayVisible && ((_hasJoined && isSeated) || isHost))
                    Positioned(
                      right: 16,
                      bottom: 90,
                      child: _buildHeroMicButton(),
                    ),

                  // 2. Seat Request Badge
                  if (isHost)
                    ValueListenableBuilder<int>(
                      valueListenable: _pendingRequestsCountNotifier,
                      builder: (context, count, _) {
                        if (count == 0) return const SizedBox.shrink();
                        return Positioned(
                          right: 16,
                          bottom: 300,
                          child: GestureDetector(
                            onTap: _showSeatRequestsDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF1493),
                                    Color(0xFFFF69B4),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.pink.withOpacity(0.4),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.waving_hand,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // 3. Control Island Bottom Bar
                  if (!_isGameOverlayVisible)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: PartyRoomBottomBar(
                        isHost: isHost,
                        isSeated: isSeated,
                        onChatPressed: _toggleChatInput,
                        onGamePressed: _showGamesMenu,
                        onGiftPressed: _showGiftDialog,
                        onJoinSeatPressed: _handleJoinSeatRequest,
                        onSettingsPressed: _showMoreMenu,
                        onClosePressed: _handleClose,
                      ),
                    ),

                  // 4. Chat Input Overlay
                  if (_showChatInput)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildChatInput(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSimpleView(
    String hostId,
    String hostName,
    int earnings,
    List<String> participants,
    String theme,
    bool isHost,
    int maxSeats,
    bool hasEmptySeats,
  ) {
    if (!_showSimpleView) return const SizedBox.shrink();
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 61,
              child: _showSimpleView
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: RepaintBoundary(
                        child: PartyRoomSimpleHeader(
                          appName: 'Shemet',
                          hostName: hostName,
                          totalDiamonds: earnings,
                          onHostTap: () => _showUserProfile(hostId),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 0, left: 30, right: 30),
                child: RepaintBoundary(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _getCrossAxisCount(maxSeats),
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: maxSeats,
                    itemBuilder: (context, index) {
                      final seat = _getSeatModel(index);
                      final isOccupied = seat.isOccupied;

                      return ValueListenableBuilder<Set<int>>(
                        valueListenable: _speakingUsersNotifier,
                        builder: (context, speakingUsers, _) {
                          return PartyRoomSeat(
                            seat: seat,
                            isHost: index == 0,
                            diamonds: isOccupied
                                ? seat.contributionDiamonds
                                : null,
                            showBadges: true,
                            theme: theme,
                            isSpeaking: speakingUsers.contains(
                              seat.userId?.hashCode.abs() != null ? seat.userId!.hashCode.abs() % 1000000 : 0,
                            ),
                            roomType: _roomData?['roomType'],
                            onVideoToggle:
                                (isOccupied &&
                                    (seat.userId == _currentUserId || isHost))
                                ? (val) => _toggleVideo(index, val)
                                : null,
                            onMicToggle:
                                (isOccupied &&
                                    (seat.userId == _currentUserId || isHost))
                                ? (val) => _toggleMic(index, val)
                                : null,
                            onTap: () =>
                                _handleSeatTap(index, seat.userId, isHost),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
            _buildSimpleCloseButton(),
          ],
        ),
      ),
    );
  }

  int _getCrossAxisCount(int maxSeats) {
    if (maxSeats <= 4) return 2;
    if (maxSeats <= 6) return 3;
    if (maxSeats <= 9) return 3;
    return 4;
  }

  Widget _buildSimpleCloseButton() {
    if (!_showSimpleView) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: _handleClose,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildFullView(
    String roomName,
    int participantCount,
    int earnings,
    String hostId,
    int maxSeats,
    List<String> participants,
    String theme,
    String hostName,
    bool isHost,
    bool hasEmptySeats,
  ) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;

    return SafeArea(
      child: Column(
        children: [
          Stack(
            children: [
              RepaintBoundary(
                child: PartyRoomHeader(
                  roomId: _roomData!['roomId'],
                  roomName: roomName,
                  hostName: hostName,
                  followersCount: 1631,
                  totalDiamonds: earnings,
                  participantCount: participantCount,
                  topContributors: _topContributors,
                  isHost: isHost,
                  isFollowing: _isFollowing,
                  onInvitePressed: () {},
                  onFollowPressed: () async {
                    await _databaseService.toggleFollowRoom(
                      roomId: _roomData!['roomId'],
                      userId: _currentUserId,
                      follow: !_isFollowing,
                    );
                    setState(() => _isFollowing = !_isFollowing);
                  },
                  onHostTap: () => _showUserProfile(hostId),
                ),
              ),
              // Removed top-right FollowRoomButton as requested
            ],
          ),
          const SizedBox(height: 4),

          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 0, left: 30, right: 30),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // 1. Calculate Grid Dimensions
                      final crossAxisCount = _getCrossAxisCount(maxSeats);
                      final rows = (maxSeats / crossAxisCount).ceil();

                      // 2. Calculate Available Height per Row
                      // Subtract vertical spacing (2.0 per gap)
                      final totalSpacing = (rows - 1) * 2.0;
                      final availableHeight =
                          constraints.maxHeight - totalSpacing;
                      // Ensure availableHeight is positive to prevent errors
                      final safeAvailableHeight = availableHeight > 0
                          ? availableHeight
                          : 300.0;
                      final cellHeight = safeAvailableHeight / rows;

                      // 3. Calculate Width per Cell
                      final availableWidth =
                          constraints.maxWidth - ((crossAxisCount - 1) * 2.0);
                      final cellWidth = availableWidth / crossAxisCount;

                      // 4. Determine Aspect Ratio
                      // We use max(1.0, ...) to ensure seats NEVER become taller than they are wide.
                      // If rows fit easily (e.g. 8 seats), we keep them square (1.0).
                      // If rows are tight (e.g. 15 seats), we make them shorter (ratio > 1.0) to fit.
                      final rawAspectRatio = (cellHeight > 0)
                          ? (cellWidth / cellHeight)
                          : 1.0;
                      final childAspectRatio = rawAspectRatio < 1.0
                          ? 1.0
                          : rawAspectRatio;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio:
                              childAspectRatio, // Dynamic but bounded
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                        ),
                        itemCount: maxSeats,
                        itemBuilder: (context, index) {
                          final seat = _getSeatModel(index);
                          final isOccupied =
                              seat.isOccupied; // Using helper method
                          final userId =
                              seat.userId; // Helper for click handling

                          return Center(
                            child: FittedBox(
                              fit: BoxFit
                                  .scaleDown, // Only shrink, never grow larger than 110x145
                              child: SizedBox(
                                width: 110,
                                height: 145,
                                child: Stack(
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        // 🚨 PERFORMANCE & BUG FIX: Consistent UID hashing for Agora
                                        final int agoraUid = userId != null ? userId.hashCode.abs() % 1000000 : 0;
                                        final canRender =
                                            seat.isVideoOn &&
                                            userId != null &&
                                            (_remoteUids.contains(agoraUid) ||
                                                (userId == _currentUserId)) &&
                                            _agoraService.engine != null;

                                        if (seat.isVideoOn) {
                                          debugPrint(
                                            '[VIDEO_RENDER_DEBUG] 🔍 Seat $index (User: $userId) isVideoOn=true. '
                                            'RemoteUIDs: $_remoteUids, '
                                            'IsSelf: ${userId == _currentUserId}, '
                                            'EngineReady: ${_agoraService.engine != null}, '
                                            'RESULT: $canRender',
                                          );
                                        }

                                        if (canRender) {
                                          return Positioned(
                                            top: 20,
                                            left: 0,
                                            right: 0,
                                            child: Center(
                                              child: SizedBox(
                                                width: 85,
                                                height: 85,
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child:
                                                      _agoraService.engine ==
                                                          null
                                                      ? Container(
                                                          color: Colors.black54,
                                                          child: const Icon(
                                                            Icons.videocam_off,
                                                            color: Colors.white,
                                                          ),
                                                        )
                                                      : (userId ==
                                                            _currentUserId)
                                                      ? AgoraVideoView(
                                                          controller: VideoViewController(
                                                            rtcEngine:
                                                                _agoraService
                                                                    .engine!,
                                                            canvas: const VideoCanvas(
                                                              uid: 0,
                                                              renderMode:
                                                                  RenderModeType
                                                                      .renderModeHidden,
                                                            ),
                                                          ),
                                                        )
                                                      : AgoraVideoView(
                                                          controller: VideoViewController.remote(
                                                            rtcEngine:
                                                                _agoraService
                                                                    .engine!,
                                                            canvas: VideoCanvas(
                                                              uid: userId.hashCode.abs() % 1000000,
                                                              renderMode:
                                                                  RenderModeType
                                                                      .renderModeHidden,
                                                            ),
                                                            connection:
                                                                RtcConnection(
                                                                  channelId:
                                                                      _roomData?['roomId'],
                                                                ),
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),

                                    // 2. FRONT layer - PartyRoomSeat (Controls)
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: Center(
                                        child: PartyRoomSeat(
                                          seat: seat,
                                          isHost: index == 0,
                                          diamonds: isOccupied
                                              ? seat.contributionDiamonds
                                              : null,
                                          showBadges: true,
                                          theme: theme,
                                          isSpeaking: _speakingUsers.contains(
                                            userId?.hashCode.abs() != null ? userId!.hashCode.abs() % 1000000 : 0,
                                          ),
                                          roomType: _roomData?['roomType'],
                                          onVideoToggle:
                                              (isOccupied &&
                                                  (userId == _currentUserId ||
                                                      isHost))
                                              ? (val) {
                                                  debugPrint(
                                                    '[DEEP_DATA] 📥 Video Toggle Callback Triggered for Seat $index',
                                                  );
                                                  _toggleVideo(index, val);
                                                }
                                              : null,
                                          onMicToggle:
                                              (isOccupied &&
                                                  (userId == _currentUserId ||
                                                      isHost))
                                              ? (val) {
                                                  debugPrint(
                                                    '[DEEP_DATA] 📥 Mic Toggle Callback Triggered for Seat $index',
                                                  );
                                                  _toggleMic(index, val);
                                                }
                                              : null,
                                          onTap: () => _handleSeatTap(
                                            index,
                                            userId,
                                            isHost,
                                          ),
                                        ),
                                      ),
                                    ), // Stack
                                  ],
                                ),
                              ),
                            ),
                          );
                        }, // itemBuilder
                      ); // GridView.builder
                    }, // LayoutBuilder builder
                  ), // LayoutBuilder
                ),
              ],
            ),
          ),

          _buildBottomArea(
            _isSeated,
            currentUser,
            hasEmptySeats,
            isHost,
          ),
          // _buildBottomBar(isHost), // Removed for Floating Overlay
        ],
      ),
    );
  }

  Widget _buildBottomArea(
    bool isInSeat,
    UserModel? currentUser,
    bool hasEmptySeats,
    bool isHost,
  ) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 80,
            top: 0,
            bottom: 60,
            child: PartyRoomChatListUpdated(
              roomId: _roomData!['roomId'],
              currentUserId: _currentUserId,
              isVisible: true,
              isHost: isHost,
              onReviewRequest: _showSeatRequestsDialog,
            ),
          ),

          // SeatRequestButton removed as part of unified flow.
          // Audience members now use the "Join Mic" button or tap a seat.
          // Note: Host's "Waving Hand" badge is now in the main build stack for better visibility.

          // Removed Hardcoded "Green 75%", "Orange 80%", and "Charm Queens" widgets as per user request.
        ],
      ),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GridMenuSheet(
        onJoinPressed: () {
          Navigator.pop(context);
          _showJoinSheet();
        },
        onMessagesPressed: () {
          Navigator.pop(context);
          _showRoomMessages();
        },
        onSharePressed: () {
          Navigator.pop(context);
          _showShareSheet();
        },
        onTopUpPressed: () {
          Navigator.pop(context);
          _showTopUpSheet();
        },
        onSettingsPressed: isHost
            ? () {
                Navigator.pop(context);
                _showRoomSettings();
              }
            : null,
      ),
    );
  }

  void _showRoomSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RoomSettingsSheet(
        roomId: _roomData!['roomId'],
        initialAllowFreeJoin: _roomData!['allowFreeJoin'] ?? false,
      ),
    );
  }

  void _showBeautySettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const BeautySettingsSheet(),
    );
  }

  void _showGiftDialog() {
    if (_roomData == null) return;

    final currentUserId = Provider.of<UserProvider>(
      context,
      listen: false,
    ).currentUser?.uid;
    final hostId = _roomData!['hostId'];

    if (currentUserId != null && currentUserId == hostId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot send gifts to yourself! 🚫'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Find host's seat index
    int? hostSeatIndex;
    final seats = _roomData!['seats'] as Map<String, dynamic>?;
    if (seats != null) {
      seats.forEach((key, value) {
        final userId = (value is Map) ? value['userId'] : value;
        if (userId == hostId) {
          hostSeatIndex = int.tryParse(key);
        }
      });
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftPickerSheet(
        streamId: _roomData!['roomId'],
        receiverId: hostId,
        context: 'party_room',
        seatIndex: hostSeatIndex,
      ),
    );
  }

  void _showJoinSheet() {
    if (_roomData == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GuestApplySheet(
        roomId: _roomData!['roomId'],
        userId: _currentUserId,
        onApply: () {
          Navigator.pop(context);
          _handleJoinMic();
        },
      ),
    );
  }

  void _showRoomMessages() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const RoomMessagesSheet(),
    );
  }

  void _showShareSheet() {
    if (_roomData == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SocialShareSheet(
        roomId: _roomData!['roomId'],
        roomTitle: _roomData!['roomName'] ?? 'Party Room',
      ),
    );
  }

  void _showTopUpSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          TopUpSheet(currentDiamonds: _roomData!['earnings'] ?? 0),
    );
  }

  Future<void> _handleJoinMic() async {
    // Basic seat request logic
    if (_roomData == null) return;

    // Check if already in seat
    final seats = Map<String, dynamic>.from(_roomData!['seats'] ?? {});
    bool inSeat = false;
    seats.forEach((k, v) {
      if (v is Map && v['userId'] == _currentUserId) inSeat = true;
    });

    if (inSeat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already on a seat!')),
      );
      return;
    }

    // 3. Send request with full details
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;

    if (currentUser == null) return;

    final requestId = await _databaseService.createSeatRequest(
      roomId: _roomData!['roomId'],
      userId: _currentUserId,
      userName: currentUser.name,
      userPhoto: currentUser.photos.isNotEmpty ? currentUser.photos[0] : '',
      userLevel: currentUser.level,
      isVip: currentUser.isVip ?? false,
    );

    if (requestId != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seat request sent! Waiting for host...'),
            backgroundColor: Colors.pink,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleSeatTap(int seatIndex, String? userId, bool isSeatIndexZero) {
    final isCurrentUserHost = _roomData!['hostId'] == _currentUserId;

    if (userId != null) {
      if (isCurrentUserHost && userId != _currentUserId) {
        // Host viewing another user
        _showHostControls(userId, seatIndex);
      } else if (userId == _currentUserId) {
        // User viewing their own seat
        _showOwnSeatOptions(seatIndex);
      } else {
        // Anyone viewing another user's profile
        _showUserProfile(userId, seatIndex);
      }
    } else {
      // Empty seat clicked
      if (isCurrentUserHost) {
        // Host can lock/unlock the seat
        _showHostSeatControls(seatIndex);
      } else {
        // Audience member wants to join
        final allowFreeJoin = _roomData!['allowFreeJoin'] ?? false;
        if (allowFreeJoin) {
          _handleJoinMicDirectly(seatIndex);
        } else {
          _showJoinSheet(); // Shows GuestApplySheet
        }
      }
    }
  }

  void _showHostSeatControls(int seatIndex) {
    // Basic menu for host to lock empty seats
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2D1B69), Color(0xFF1A0F3D)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Seat $seatIndex Management',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.lock, color: Colors.purple),
              title: const Text(
                'Lock Seat',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _databaseService.toggleSeatLock(
                  roomId: _roomData!['roomId'],
                  seatNumber: seatIndex,
                  isLocked: true,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.green),
              title: const Text(
                'Invite Someone',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                // In a real app, this would show the audience list to pick someone
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Select a user from audience or chat to invite',
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

  Future<void> _handleJoinMicDirectly(int seatIndex) async {
    final success = await _databaseService.approveSeatRequest(
      roomId: _roomData!['roomId'],
      userId: _currentUserId,
      seatIndex: seatIndex,
    );
    if (success) {
      _toggleMic(seatIndex, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Joined seat!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showUserProfile(String userId, [int? seatIndex]) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => UserQuickProfileSheet(
        userId: userId,
        roomId: _roomData!['roomId'],
        isHost: _roomData!['hostId'] == _currentUserId,
        seatIndex: seatIndex,
        onBlock: () => _blockUser(userId),
        onKick: () => _kickUserAction(userId),
      ),
    );
  }

  void _showOwnSeatOptions(int seatIndex) {
    final isMicOn = _userMicStatus[_currentUserId] ?? false;
    final seat = _getSeatModel(seatIndex);
    final isVideoOn = seat.isVideoOn;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2D1B69), Color(0xFF1A0F3D)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your Seat',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Mic Toggle
            ListTile(
              leading: Icon(
                isMicOn ? Icons.mic : Icons.mic_off,
                color: isMicOn ? Colors.green : Colors.red,
              ),
              title: Text(
                isMicOn ? 'Mute Microphone' : 'Turn On Microphone',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleMic(seatIndex, !isMicOn);
              },
            ),

            // Video Toggle
            ListTile(
              leading: Icon(
                isVideoOn ? Icons.videocam : Icons.videocam_off,
                color: isVideoOn ? Colors.green : Colors.red,
              ),
              title: Text(
                isVideoOn ? 'Turn Off Camera' : 'Turn On Camera',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleVideo(seatIndex, !isVideoOn);
              },
            ),

            // Leave Seat
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.orange),
              title: const Text(
                'Leave Seat',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _leaveSeat();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHostControls(String userId, int seatIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => HostControlsMenu(
        roomId: _roomData!['roomId'],
        roomName: _roomData!['roomName'] ?? 'Party Room',
        targetUserId: userId,
        targetUserName: 'User',
        seatNumber: seatIndex,
        isHost: true,
      ),
    );
  }

  void _showSeatRequestsDialog() {
    debugPrint(
      '[DEBUG_SEAT] 🪟 Opening Seat Requests Dialog. Current count: ${_pendingSeatRequests.length}',
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Inner listener to refresh modal when parent state changes
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _databaseService.getPendingSeatRequests(
              _roomData!['roomId'],
            ),
            builder: (context, snapshot) {
              final requests = snapshot.data ?? _pendingSeatRequests;

              return Container(
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2D1B69), Color(0xFF1A0F3D)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.waving_hand,
                                color: Colors.pinkAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Seat Requests (${requests.length})',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // List
                    Expanded(
                      child: requests.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.hourglass_empty,
                                    color: Colors.white.withOpacity(0.2),
                                    size: 64,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No pending requests',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: requests.length,
                              itemBuilder: (context, index) {
                                return _buildRequestItem(requests[index]);
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestItem(Map<String, dynamic> request) {
    debugPrint(
      '[DEBUG_SEAT] 🏗️ Building Item: ${request['userName']} (ID: ${request['id']})',
    );
    final userName = request['userName'] ?? 'Unknown';
    final userPhoto = request['userPhoto'] ?? '';
    final userLevel = request['userLevel'] ?? 0;
    final requestId = request['id'] ?? '';
    final userId = request['userId'] ?? requestId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // Avatar (Clickable)
          GestureDetector(
            onTap: () {
              Navigator.pop(context); // Close requests list
              _showUserProfile(
                userId,
              ); // Request list doesn't have seatIndex yet as they aren't seated
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.pinkAccent.withOpacity(0.5),
                  width: 2,
                ),
                image: userPhoto.isNotEmpty
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(userPhoto),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: userPhoto.isEmpty
                  ? Center(
                      child: Text(
                        userName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Lv.$userLevel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Professional Actions
          Row(
            children: [
              // Agree Button
              GestureDetector(
                onTap: () => _approveRequest(requestId),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),

              // Reject Button
              GestureDetector(
                onTap: () => _rejectRequest(requestId),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approveRequest(String requestId) async {
    final seats = Map<String, dynamic>.from(_roomData!['seats'] ?? {});
    final maxSeats = _roomData!['maxSeats'] ?? 12;

    int? emptySeat;
    for (int i = 0; i < maxSeats; i++) {
      if (!seats.containsKey(i.toString())) {
        emptySeat = i;
        break;
      }
    }

    if (emptySeat != null) {
      // Get request data before approving
      String? userId;
      for (var request in _pendingSeatRequests) {
        if (request['id'] == requestId) {
          userId = request['userId'];
          break;
        }
      }

      // Fallback if userId not found in list (though it should be)
      userId ??=
          requestId; // Assuming requestId IS userId based on implementation

      final success = await _databaseService.approveSeatRequest(
        roomId: _roomData!['roomId'],
        userId: userId,
        seatIndex: emptySeat,
      );

      if (mounted && success) {
        // Show snackbar BEFORE popping to ensure context is still active
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Request approved')));
        Navigator.pop(context);

        // Send notification to user
        await _notificationService.sendSeatApprovedNotification(
          userId: userId,
          roomId: _roomData!['roomId'],
          roomName: _roomData!['roomName'] ?? 'Party Room',
        );
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    // Get request data before rejecting
    String? userId;
    for (var request in _pendingSeatRequests) {
      if (request['id'] == requestId) {
        userId = request['userId'];
        break;
      }
    }

    userId ??= requestId;

    final success = await _databaseService.rejectSeatRequest(
      roomId: _roomData!['roomId'],
      userId: userId,
    );

    if (mounted && success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Request rejected')));

      // Send notification to user
      await _notificationService.sendSeatRejectedNotification(
        userId: userId,
        roomName: _roomData!['roomName'] ?? 'Party Room',
      );
    }
  }

  Future<void> _leaveSeat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Leave Seat?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Do you want to leave your seat?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _databaseService.leavePartyRoom(
        roomId: _roomData!['roomId'],
        userId: _currentUserId,
      );
    }
  }

  Future<void> _blockUser(String userId) async {
    final userDoc = await _databaseService.getUserById(userId);
    if (userDoc == null) return;

    showBlockConfirmationDialog(
      context: context,
      userName: userDoc.name,
      onConfirm: () async {
        final success = await _databaseService.blockUserFromRoom(
          roomId: _roomData!['roomId'],
          userId: userId,
          blockedBy: _currentUserId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'User blocked' : 'Failed to block user'),
              backgroundColor: success ? Colors.red : Colors.grey,
            ),
          );

          // Send notification to blocked user
          if (success) {
            await _notificationService.sendBlockedNotification(
              userId: userId,
              roomName: _roomData!['roomName'] ?? 'Party Room',
            );
          }
        }
      },
    );
  }

  Future<void> _kickUserAction(String userId) async {
    final success = await _databaseService.kickUserFromRoom(
      roomId: _roomData!['roomId'],
      userId: userId,
      kickedBy: _currentUserId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'User kicked' : 'Failed to kick user'),
          backgroundColor: success ? Colors.orange : Colors.grey,
        ),
      );

      // Send notification to kicked user
      if (success) {
        await _notificationService.sendKickedNotification(
          userId: userId,
          roomName: _roomData!['roomName'] ?? 'Party Room',
        );
      }
    }
  }

  // Phase 3 Methods & Games Module
  void _showGamesMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GameSelectionWidget(
        onGameSelected: (gameId) async {
          // 1. ELITE LIFECYCLE: Stop all background games to prevent lag
          AviatorGameService().stopGame();
          DiceGameService().stopGame();

          // 2. Host triggers room-wide sync
          if (isHost) {
            // 💰 PRE-INITIALIZE SERVICES FOR HOST
            if (gameId == 'aviator') {
              AviatorGameService().setRoomContext(
                _roomData!['roomId'],
                'party_room',
                isHost: true,
              );
              AviatorGameService().startGame();
            } else if (gameId == 'dice') {
              DiceGameService().setRoomContext(
                _roomData!['roomId'],
                'party_room',
                isHost: true,
              );
              DiceGameService().startGame();
            }
          }

          // 3. Refresh local state
          setState(() {
            _activeGameId = gameId;
            _isGameOverlayVisible = true;
          });
        },
      ),
    );
  }

  void _closeGame() {
    debugPrint('[GAMES] 🛑 Closing active game: $_activeGameId');
    if (isHost && _roomData != null) {
      // Fire and forget to prevent async race condition where a delayed stopRoomGame
      // overwrites a newly started game's state.
      _databaseService.stopRoomGame(roomId: _roomData!['roomId']);
    }

    // ELITE LIFECYCLE: Cleanup all services
    AviatorGameService().stopGame();
    DiceGameService().stopGame();

    setState(() {
      _isGameOverlayVisible = false;
      _activeGameId = null;
    });
  }

  Widget _buildGameOverlay() {
    if (!_isGameOverlayVisible || _activeGameId == null) {
      return const SizedBox.shrink();
    }

    Widget? gameWidget;

    if (_activeGameId == 'aviator') {
      gameWidget = AviatorGameWidget(onClose: _closeGame);
    } else if (_activeGameId == 'racing') {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      gameWidget = CarRacingGameWidget(
        onClose: _closeGame,
        userDiamonds: userProvider.currentUser?.diamonds ?? 0,
        onDiamondUpdate: (newBalance) {
          userProvider.setLocalDiamonds(newBalance);
        },
      );
    } else if (_activeGameId == 'dice') {
      gameWidget = DiceGameWidget(onClose: _closeGame);
    }

    return Stack(
      children: [
        // Tap outside to close — dims party room above game
        GestureDetector(
          onTap: _closeGame,
          child: Container(color: Colors.black.withOpacity(0.6)),
        ),
        // ❌ HOST CLOSE BUTTON (Manual control for those who select the game)
        if (isHost)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: GestureDetector(
              onTap: _closeGame,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
        // Game panel — bottom 65% of screen
        if (gameWidget != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.5,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F1E),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag handle + title bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Row(
                        children: [
                          // Drag handle centred
                          Expanded(
                            child: Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Game content fills the rest
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                        ),
                        child: gameWidget,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ==================== NEW ACTIONS ====================

  void _handleJoinSeatRequest() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Request Seat',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Do you want to request a seat?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (_roomData == null) return;

              // Call database service to request seat
              final userProvider = Provider.of<UserProvider>(
                context,
                listen: false,
              );
              final currentUser = userProvider.currentUser;
              final success = await _databaseService.requestSeat(
                roomId: _roomData!['roomId'],
                userId: _currentUserId,
                userName: currentUser?.name ?? 'User',
                userPhoto: (currentUser?.photos.isNotEmpty ?? false)
                    ? currentUser!.photos[0]
                    : '',
                userLevel: currentUser?.level ?? 0,
                isVip: currentUser?.isVip ?? false,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Seat requested!' : 'Failed to request seat',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Request',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  void _showShareDialog() {
    // Placeholder share dialog
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share via',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(Icons.copy, 'Copy Link'),
                _buildShareOption(Icons.facebook, 'Facebook'),
                _buildShareOption(Icons.message, 'WhatsApp'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey[200],
          child: Icon(icon, color: Colors.black),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  void _showDiceGame() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Allow full height if needed by widget
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: DiceGameWidget(onClose: () => Navigator.pop(context)),
      ),
    );
  }

  void _showSpinWheel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SpinWheelWidget(
        entryCost: 100,
        onResult: (winnings) {
          _soundService.playGiftSound();
          Navigator.pop(context);

          if (winnings > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🎉 Won $winnings 💎!'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Better luck next time!'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
      ),
    );
  }

  void _showStats() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RoomStatsWidget(
        stats: _roomData ?? {},
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _handleClose() async {
    final isHost = _roomData != null && _roomData!['hostId'] == _currentUserId;

    if (isHost) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'End Party?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to end the party? This will close the room for everyone.',
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
                'End Party',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirm == true) {
        if (_hasJoined) await _leaveRoom();
        _showEndScreenAndExit();
      }
    } else {
      // Guest Logic: Leave and go to Home (Party tab)
      if (_hasJoined) await _leaveRoom();
      _exitToHome();
    }
  }

  void _exitToHome() {
    if (!mounted) return;

    // Safety check: Decoupled leave call before navigation to ensure it's triggered
    if (_hasJoined) {
      _databaseService
          .leavePartyRoom(roomId: _roomData!['roomId'], userId: _currentUserId)
          .catchError((e) {
            debugPrint('[EXIT_SAFETY] Failed to leave room: $e');
            return false;
          });
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/main',
      (route) => false,
      arguments: {'initialIndex': 1},
    );
  }

  Future<void> _showEndScreenAndExit() async {
    if (!mounted) return;

    // 1. Fetch Session Summary from Database
    Map<String, dynamic> summary = {};
    if (_roomData != null) {
      summary = await _databaseService.getRoomSessionSummary(
        _roomData!['roomId'],
        context: 'party_room',
      );
    }

    if (!mounted) return;

    // 2. Fallback to local session time if DB fails
    if (summary.isEmpty) {
      final now = DateTime.now();
      final diff = now.difference(_sessionStartTime);
      final hours = diff.inHours.toString().padLeft(2, '0');
      final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
      final durationStr = '$hours:$minutes:$seconds';

      summary = {
        'duration': durationStr,
        'totalVisitors': _roomData?['totalVisitors'] ?? 0,
        'giftEarnings': _roomData?['earnings'] ?? 0,
        'gameEarnings': _roomData?['gameEarnings'] ?? 0,
      };
    }

    // 3. Show Summary Dialog then Exit
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => RoomSummaryDialog(summary: summary),
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/main',
        (route) => false,
        arguments: {'initialIndex': 1},
      );
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _roomData == null) return;

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;

      if (currentUser == null) return;

      await _databaseService.sendPartyRoomMessage(
        roomId: _roomData!['roomId'],
        senderId: _currentUserId,
        senderName: currentUser.name,
        text: message,
      );

      _messageController.clear();

      setState(() {
        _showChatInput = false;
      });
    } catch (e) {}
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black.withOpacity(0.9),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
                autofocus: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF1493), Color(0xFFFF69B4)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // HERO MIC BUTTON (New)
  Widget _buildHeroMicButton() {
    final isMicOn = _userMicStatus[_currentUserId] ?? false;

    return GestureDetector(
      onTap: () {
        _handleMicToggle(-1, !isMicOn);
      },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            width: 64, // Larger FAB size
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMicOn
                  ? Colors.green.withOpacity(0.2)
                  : Colors.black.withOpacity(0.6), // Glass black when off
              border: Border.all(
                color: isMicOn
                    ? Colors.greenAccent.withOpacity(0.8)
                    : Colors.white.withOpacity(0.2),
                width: 2,
              ),
              boxShadow: isMicOn
                  ? [
                      BoxShadow(
                        color: Colors.greenAccent.withOpacity(
                          0.4 * _pulseController.value,
                        ),
                        blurRadius: 20 * _pulseController.value,
                        spreadRadius: 5 * _pulseController.value,
                      ),
                      BoxShadow(
                        color: Colors.green.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glass Blur
                ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // Icon
                Icon(
                  isMicOn ? Icons.mic : Icons.mic_off,
                  color: isMicOn ? Colors.white : Colors.white54,
                  size: 32, // Large Icon
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showMicInvitationDialog(String hostName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D1B69),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Mic Invitation',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '$hostName invited you to join the mic! 🎙️',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _databaseService.rejectMicInvitation(
                roomId: _roomData!['roomId'],
                userId: _currentUserId,
              );
            },
            child: const Text(
              'Decline',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _databaseService.acceptMicInvitation(
                roomId: _roomData!['roomId'],
                userId: _currentUserId,
              );
              _handleJoinMic(); // Reusing request logic for now
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}
