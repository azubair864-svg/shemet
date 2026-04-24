import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/call_model.dart';
import 'diamond_service.dart';
import 'agora_service.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'dart:async';

/// ⭐⭐⭐ PRODUCTION-READY CALL SERVICE ⭐⭐⭐
/// Handles voice/video calls with Agora SDK
/// Features: Diamond earning for receivers, call history, network quality
class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DiamondService _diamondService = DiamondService();

  // Diamond earning rates per minute
  static const int _voiceCallDiamondsPerMinute =
      10; // 10 diamonds/min for voice
  static const int _videoCallDiamondsPerMinute =
      20; // 20 diamonds/min for video

  final AgoraService _agoraService = AgoraService(); // Use singleton
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true; // For camera switching
  int? _localUid;
  int? _remoteUid;
  String? _currentCallId;
  Timer? _transactionTimer;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isFrontCamera => _isFrontCamera;
  int? get localUid => _localUid;
  int? get remoteUid => _remoteUid;
  RtcEngine? get engine => _agoraService.engine;
  String? get currentCallId => _currentCallId;

  // Network quality (will be updated during calls)
  int _localNetworkQuality =
      0; // 0-6: 0=unknown, 1=excellent, 2=good, 3=poor, 4=bad, 5=vbad, 6=down
  int _remoteNetworkQuality = 0; // Will be updated by event handler
  int get localNetworkQuality => _localNetworkQuality;
  int get remoteNetworkQuality => _remoteNetworkQuality;

  // ==================== INITIALIZATION ====================

  Future<bool> initialize() async {
    debugPrint(
      '\n[AGORA_DEBUG] 📞 ========== CALL SERVICE INITIALIZATION START ==========',
    );
    try {
      if (_isInitialized) {
        debugPrint('[AGORA_DEBUG] 📝 CallService already initialized');
        return true;
      }

      // Request permissions
      debugPrint('[AGORA_DEBUG] 📝 Requesting permissions...');
      await _requestPermissions();

      // Ensure AgoraService is initialized (this creates the engine singleton)
      debugPrint('[AGORA_DEBUG] 📝 Ensuring AgoraService is initialized...');
      await _agoraService.initialize();

      if (_agoraService.engine == null) {
        throw Exception('Failed to create Agora RTC Engine');
      }

      // Note: Do NOT call setChannelProfile(Communication) here if initialized as LiveBroadcasting.
      // We will set the profile specifically in the joinChannel options.

      // Set default audio route to speaker
      await _agoraService.engine?.setDefaultAudioRouteToSpeakerphone(true);

      _isInitialized = true;
      debugPrint(
        '[AGORA_DEBUG] ✅ ========== CALL SERVICE INITIALIZATION SUCCESS ==========\n',
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint(
        '[AGORA_DEBUG] ❌ ========== CALL SERVICE INITIALIZATION ERROR ==========',
      );
      debugPrint('[AGORA_DEBUG] ❌ Error: $e');
      debugPrint('[AGORA_DEBUG] 📍 Stack trace: $stackTrace');
      debugPrint(
        '[AGORA_DEBUG] ❌ =============================================\n',
      );
      return false;
    }
  }

  /// Listen to real-time status changes of a call
  Stream<CallModel?> listenToCallStatus(String callId) {
    return _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .map((doc) => doc.exists ? CallModel.fromMap(doc.data()!, doc.id) : null);
  }

  Future<void> _requestPermissions() async {
    await [Permission.microphone, Permission.camera].request();
  }

  // ==================== VOICE CALL ====================

  Future<bool> startVoiceCall({
    required String channelName,
    required String token,
    required int uid,
    required Function(int uid, int elapsed) onUserJoined,
    required Function(int uid, UserOfflineReasonType reason) onUserOffline,
  }) async {
    debugPrint(
      '\n[AGORA_DEBUG] 🎙️ ========== START VOICE CALL START ==========',
    );
    debugPrint('[AGORA_DEBUG] 📝 Channel: $channelName');
    debugPrint(
      '[AGORA_DEBUG] 📝 Token: ${token.isNotEmpty ? "PRESENT" : "EMPTY"}',
    );
    debugPrint('[AGORA_DEBUG] 📝 UID: $uid');

    try {
      if (!_isInitialized) {
        debugPrint(
          '[AGORA_DEBUG] 📝 CallService not initialized, initializing now...',
        );
        await initialize();
      }

      // Disable video for voice call
      await _agoraService.engine?.disableVideo();

      // Register event handlers
      _agoraService.engine?.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint(
              '[AGORA_DEBUG] ✅ Joined channel: ${connection.channelId}',
            );
            _localUid = connection.localUid;
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('[AGORA_DEBUG] 👥 Remote user joined: $remoteUid');
            _remoteUid = remoteUid;
            onUserJoined(remoteUid, elapsed);
          },
          onUserOffline:
              (
                RtcConnection connection,
                int remoteUid,
                UserOfflineReasonType reason,
              ) {
                debugPrint(
                  '[AGORA_DEBUG] 👋 Remote user offline: $remoteUid, Reason: $reason',
                );
                _remoteUid = null;
                onUserOffline(remoteUid, reason);
              },
          onNetworkQuality:
              (
                RtcConnection connection,
                int remoteUid,
                QualityType txQuality,
                QualityType rxQuality,
              ) {
                // Update local quality (txQuality)
                _localNetworkQuality = txQuality.index;
                // Update remote quality (rxQuality)
                _remoteNetworkQuality = rxQuality.index;
              },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[AGORA_DEBUG] ❌ Agora Error: $err, Message: $msg');
          },
        ),
      );

      // Join channel
      debugPrint('[AGORA_DEBUG] 📝 Joining channel...');
      await _agoraService.engine?.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: false,
        ),
      );

      debugPrint(
        '[AGORA_DEBUG] ✅ ========== START VOICE CALL SUCCESS ==========\n',
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint(
        '[AGORA_DEBUG] ❌ ========== START VOICE CALL ERROR ==========',
      );
      debugPrint('[AGORA_DEBUG] ❌ Error: $e');
      debugPrint('[AGORA_DEBUG] 📍 Stack trace: $stackTrace');
      debugPrint(
        '[AGORA_DEBUG] ❌ =============================================\n',
      );
      return false;
    }
  }

  // ==================== VIDEO CALL ====================

  Future<bool> startVideoCall({
    required String channelName,
    required String token,
    required int uid,
    required Function(int uid, int elapsed) onUserJoined,
    required Function(int uid, UserOfflineReasonType reason) onUserOffline,
  }) async {
    debugPrint('[AGORA_TRACE] 🟢 CallService.startVideoCall() called');
    debugPrint(
      '\n[AGORA_DEBUG] 📹 ========== START VIDEO CALL START ==========',
    );
    debugPrint('[AGORA_DEBUG] 📝 Channel: $channelName');
    debugPrint(
      '[AGORA_DEBUG] 📝 Token: ${token.isNotEmpty ? "PRESENT" : "EMPTY"}',
    );
    debugPrint('[AGORA_DEBUG] 📝 UID: $uid');

    try {
      if (!_isInitialized) {
        debugPrint(
          '[AGORA_DEBUG] 📝 CallService not initialized, initializing now...',
        );
        await initialize();
      }

      // Use explicit handover logic (Clean capture for calls)
      await _agoraService.requestCameraControl(CameraOwner.agora);

      // Register event handlers
      _agoraService.engine?.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint(
              '[AGORA_DEBUG] ✅ Joined channel: ${connection.channelId}',
            );
            _localUid = connection.localUid;
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('[AGORA_DEBUG] 👥 Remote user joined: $remoteUid');
            _remoteUid = remoteUid;
            onUserJoined(remoteUid, elapsed);
          },
          onUserOffline:
              (
                RtcConnection connection,
                int remoteUid,
                UserOfflineReasonType reason,
              ) {
                debugPrint(
                  '[AGORA_DEBUG] 👋 Remote user offline: $remoteUid, Reason: $reason',
                );
                _remoteUid = null;
                onUserOffline(remoteUid, reason);
              },
          onNetworkQuality:
              (
                RtcConnection connection,
                int remoteUid,
                QualityType txQuality,
                QualityType rxQuality,
              ) {
                // Update local quality (txQuality)
                _localNetworkQuality = txQuality.index;
                // Update remote quality (rxQuality)
                _remoteNetworkQuality = rxQuality.index;
              },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[AGORA_DEBUG] ❌ Agora Error: $err, Message: $msg');
          },
        ),
      );

      // Ensure we leave any existing channel first (Fixes Error -17 Join Rejected)
      try {
        await _agoraService.engine?.leaveChannel();
      } catch (_) {}

      // Join channel
      debugPrint('[AGORA_DEBUG] 📝 Joining channel...');
      await _agoraService.engine?.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: true,
        ),
      );

      debugPrint(
        '[AGORA_DEBUG] ✅ ========== START VIDEO CALL SUCCESS ==========\n',
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint(
        '[AGORA_DEBUG] ❌ ========== START VIDEO CALL ERROR ==========',
      );
      debugPrint('[AGORA_DEBUG] ❌ Error: $e');
      debugPrint('[AGORA_DEBUG] 📍 Stack trace: $stackTrace');
      debugPrint(
        '[AGORA_DEBUG] ❌ =============================================\n',
      );
      return false;
    }
  }

  // ==================== CALL CONTROLS ====================

  Future<void> toggleMute() async {
    try {
      _isMuted = !_isMuted;
      await _agoraService.engine?.muteLocalAudioStream(_isMuted);
    } catch (e) {}
  }

  Future<void> toggleSpeaker() async {
    try {
      _isSpeakerOn = !_isSpeakerOn;
      await _agoraService.engine?.setEnableSpeakerphone(_isSpeakerOn);
    } catch (e) {}
  }

  Future<void> toggleVideo() async {
    try {
      _isVideoEnabled = !_isVideoEnabled;
      await _agoraService.engine?.muteLocalVideoStream(!_isVideoEnabled);
    } catch (e) {}
  }

  Future<void> switchCamera() async {
    debugPrint('[AGORA_TRACE] 🔄 CallService.switchCamera() called');
    try {
      if (_agoraService.engine != null && _isVideoEnabled) {
        await _agoraService.engine?.switchCamera();
        _isFrontCamera = !_isFrontCamera;
      }
    } catch (e) {}
  }

  // ==================== END CALL ====================

  // ==================== BILLING / REVENUE TICKER ====================

  void startTransactionTicker({
    required String callId,
    required String callerId,
    required String receiverId,
    required int ratePerMinute,
    required VoidCallback onInsufficientFunds,
  }) {
    // Cancel existing timer
    _transactionTimer?.cancel();

    debugPrint(
      '[CALL_BILLING] ⏳ Starting SECURE transaction ticker for call $callId at $ratePerMinute/min',
    );

    // Ticker runs every 60 seconds
    _transactionTimer = Timer.periodic(const Duration(seconds: 60), (
      timer,
    ) async {
      debugPrint('[CALL_BILLING] 💸 Charging fee for minute ${timer.tick} via Cloud Function...');

      final result = await DatabaseService().processCallCharge(
        hostId: receiverId,
        callId: callId,
        amount: ratePerMinute,
      );

      if (result['success'] != true) {
        debugPrint(
          '[CALL_BILLING] ❌ Charge failed: ${result['message']}. Ending call.',
        );
        onInsufficientFunds();
        stopTransactionTicker();
      } else {
        debugPrint('[CALL_BILLING] ✅ Usage fee charged successfully. Host earned: ${result['hostEarned']}');
      }
    });
  }

  void stopTransactionTicker() {
    _transactionTimer?.cancel();
    _transactionTimer = null;
    debugPrint('[CALL_BILLING] 🛑 Transaction ticker stopped.');
  }

  // ==================== END CALL ====================

  Future<void> endCall() async {
    try {
      await _agoraService.engine?.leaveChannel();
      stopTransactionTicker(); // Stop billing
      await _agoraService.engine?.stopPreview();
      _localUid = null;
      _remoteUid = null;
      _isMuted = false;
      _isSpeakerOn = true;
      _isVideoEnabled = true;
    } catch (e) {}
  }

  // ==================== FIRESTORE CALL MANAGEMENT ====================

  /// Creates a new call record in Firestore
  Future<String> initiateCall({
    required String callerId,
    required String callerName,
    String? callerPhoto,
    required String receiverId,
    required String receiverName,
    String? receiverPhoto,
    required CallType type,
  }) async {
    debugPrint('\n[AGORA_DEBUG] 📝 ========== INITIATE CALL START ==========');
    debugPrint('[AGORA_DEBUG] 📝 Caller: $callerName ($callerId)');
    debugPrint('[AGORA_DEBUG] 📝 Receiver: $receiverName ($receiverId)');
    debugPrint('[AGORA_DEBUG] 📝 Type: $type');

    try {
      final callDoc = await _firestore.collection('calls').add({
        'callerId': callerId,
        'callerName': callerName,
        'callerPhoto': callerPhoto,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'receiverPhoto': receiverPhoto,
        'type': type.name,
        'status': CallStatus.ringing.name,
        'createdAt': FieldValue.serverTimestamp(),
        'startedAt': null,
        'endedAt': null,
        'duration': null,
        'agoraChannelId': null,
        'agoraToken': null,
        'endReason': null,
        'isRead': false,
        'participants': [callerId, receiverId],
      });

      _currentCallId = callDoc.id;
      
      // Send push notification to receiver
      try {
        await NotificationService().sendIncomingCallNotification(
          receiverId: receiverId,
          callerName: callerName,
          callType: type.name,
          callId: callDoc.id,
        );
      } catch (e) {
        debugPrint('[AGORA_DEBUG] ⚠️ Failed to send push notification: $e');
      }

      return callDoc.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Accepts an incoming call
  Future<void> acceptCall({
    required String callId,
    required String channelId,
    String? agoraToken,
  }) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.ongoing.name,
        'startedAt': FieldValue.serverTimestamp(),
        'agoraChannelId': channelId,
        'agoraToken': agoraToken,
      });

      _currentCallId = callId;
    } catch (e) {
      debugPrint('[CALL_SERVICE] ❌ Error in acceptCall: $e');
      rethrow;
    }
  }

  /// Rejects an incoming call
  Future<void> rejectCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.rejected.name,
        'endedAt': FieldValue.serverTimestamp(),
        'endReason': 'rejected_by_receiver',
      });
    } catch (e) {}
  }

  /// Cancels an outgoing call
  Future<void> cancelCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.cancelled.name,
        'endedAt': FieldValue.serverTimestamp(),
        'endReason': 'cancelled_by_caller',
      });

      if (_currentCallId == callId) {
        _currentCallId = null;
      }
    } catch (e) {}
  }

  /// Ends an ongoing call with duration and awards diamonds to receiver
  Future<void> endCallWithDuration({
    required String callId,
    required int duration,
    String? endReason,
  }) async {
    try {
      // Get call details first
      final callDoc = await _firestore.collection('calls').doc(callId).get();

      if (callDoc.exists) {
        final callData = callDoc.data()!;
        final receiverId = callData['receiverId'] as String;
        final callType = callData['type'] as String;
        final callerId = callData['callerId'] as String;
        final callerName = callData['callerName'] as String? ?? 'Unknown';

        // Calculate diamonds earned based on call duration and type
        final durationMinutes = (duration / 60).ceil();
        final diamondsPerMinute = callType == 'video'
            ? _videoCallDiamondsPerMinute
            : _voiceCallDiamondsPerMinute;
        final diamondsEarned = durationMinutes * diamondsPerMinute;

        // Award diamonds to receiver if call lasted at least 1 minute
        if (duration >= 60 && diamondsEarned > 0) {
          await _awardCallDiamonds(
            receiverId: receiverId,
            callerId: callerId,
            callerName: callerName,
            callId: callId,
            callType: callType,
            durationSeconds: duration,
            diamondsEarned: diamondsEarned,
          );
        } else {}

        // 3. Get receiver's agencyId for reporting
        final receiverDoc = await _firestore
            .collection('users')
            .doc(receiverId)
            .get();
        final agencyId = receiverDoc.data()?['agencyId'];

        // Update call record with diamond info
        await _firestore.collection('calls').doc(callId).update({
          'status': CallStatus.ended.name,
          'endedAt': FieldValue.serverTimestamp(),
          'duration': duration,
          'endReason': endReason ?? 'ended_normally',
          'diamondsEarned': diamondsEarned,
          'diamondsAwarded': duration >= 60,
          'agencyId': agencyId, // for dashboard filtering
        });
      } else {
        // Call doc doesn't exist, just update status
        await _firestore.collection('calls').doc(callId).update({
          'status': CallStatus.ended.name,
          'endedAt': FieldValue.serverTimestamp(),
          'duration': duration,
          'endReason': endReason ?? 'ended_normally',
        });
      }

      if (_currentCallId == callId) {
        _currentCallId = null;
      }
    } catch (e) {}
  }

  /// Awards diamonds to call receiver
  Future<void> _awardCallDiamonds({
    required String receiverId,
    required String callerId,
    required String callerName,
    required String callId,
    required String callType,
    required int durationSeconds,
    required int diamondsEarned,
  }) async {
    try {
      // Add diamonds to receiver
      await _diamondService.addDiamonds(
        userId: receiverId,
        amount: diamondsEarned,
        source: '${callType}_call',
        sourceId: callId,
        metadata: {
          'callerId': callerId,
          'callerName': callerName,
          'callType': callType,
          'durationSeconds': durationSeconds,
          'durationMinutes': (durationSeconds / 60).ceil(),
          'description':
              '$callType call with $callerName (${(durationSeconds / 60).ceil()} min)',
        },
      );
    } catch (e) {}
  }

  /// Get call earnings summary for a user
  Future<Map<String, dynamic>> getCallEarningsSummary(String userId) async {
    try {
      // Get all calls where user was receiver
      final snapshot = await _firestore
          .collection('calls')
          .where('receiverId', isEqualTo: userId)
          .where('status', isEqualTo: CallStatus.ended.name)
          .where('diamondsAwarded', isEqualTo: true)
          .get();

      int totalCalls = snapshot.docs.length;
      int totalDuration = 0;
      int totalDiamonds = 0;
      int voiceCalls = 0;
      int videoCalls = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalDuration += (data['duration'] ?? 0) as int;
        totalDiamonds += (data['diamondsEarned'] ?? 0) as int;

        if (data['type'] == 'video') {
          videoCalls++;
        } else {
          voiceCalls++;
        }
      }

      final summary = {
        'totalCalls': totalCalls,
        'voiceCalls': voiceCalls,
        'videoCalls': videoCalls,
        'totalDurationSeconds': totalDuration,
        'totalDurationMinutes': (totalDuration / 60).ceil(),
        'totalDiamondsEarned': totalDiamonds,
        'averageDiamondsPerCall': totalCalls > 0
            ? totalDiamonds ~/ totalCalls
            : 0,
      };

      return summary;
    } catch (e) {
      return {
        'totalCalls': 0,
        'voiceCalls': 0,
        'videoCalls': 0,
        'totalDurationSeconds': 0,
        'totalDurationMinutes': 0,
        'totalDiamondsEarned': 0,
        'averageDiamondsPerCall': 0,
      };
    }
  }

  /// Marks a call as missed
  Future<void> markAsMissed(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.missed.name,
        'endedAt': FieldValue.serverTimestamp(),
        'endReason': 'not_answered',
      });
    } catch (e) {}
  }

  /// Gets call history for a user
  Stream<List<CallModel>> getCallHistory(String userId, {int limit = 50}) {
    return _firestore
        .collection('calls')
        .where('participants', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CallModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// Listens to incoming calls for a user
  Stream<CallModel?> listenForIncomingCalls(String userId) {
    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: CallStatus.ringing.name)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return CallModel.fromMap(
            snapshot.docs.first.data(),
            snapshot.docs.first.id,
          );
        });
  }

  /// Gets unread missed call count
  Future<int> getMissedCallCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('calls')
          .where('receiverId', isEqualTo: userId)
          .where('status', isEqualTo: CallStatus.missed.name)
          .where('isRead', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Marks missed calls as read
  Future<void> markMissedCallsAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('calls')
          .where('receiverId', isEqualTo: userId)
          .where('status', isEqualTo: CallStatus.missed.name)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {}
  }

  // ==================== AGORA TOKEN ====================

  Future<String> generateAgoraToken({
    required String channelName,
    required int uid,
  }) async {
    return _agoraService.generateAgoraToken(channelName: channelName, uid: uid);
  }

  // ==================== CLEANUP ====================

  Future<void> dispose() async {
    debugPrint('[FLOW_TRACE] 🧱 CallService.dispose() initiated');
    try {
      await endCall();
      stopTransactionTicker();

      // Release camera hardware without killing the singleton engine
      await _agoraService.requestCameraControl(CameraOwner.none);

      _isInitialized = false;
      debugPrint('[FLOW_TRACE] ✅ CallService.dispose() completed');
    } catch (e) {
      debugPrint('[FLOW_TRACE] ❌ CallService.dispose() error: $e');
    }
  }
}
