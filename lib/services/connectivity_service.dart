import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Connectivity Status
enum ConnectivityStatus {
  online,
  offline,
  limited, // Has connection but slow or unstable
}

/// Connectivity Service - Monitors network status and handles offline mode
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _statusController = StreamController<ConnectivityStatus>.broadcast();
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  ConnectivityStatus _currentStatus = ConnectivityStatus.online;
  ConnectivityStatus get currentStatus => _currentStatus;

  Timer? _checkTimer;
  bool _isInitialized = false;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    if (_isInitialized) return;

    
    _isInitialized = true;

    // Initial check
    await checkConnectivity();

    // Periodic checks every 30 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkConnectivity();
    });
  }

  /// Check current connectivity
  Future<ConnectivityStatus> checkConnectivity() async {
    try {
      // Try to reach a known host
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        // Check if Firestore is reachable
        final firestoreReachable = await _checkFirestoreConnectivity();

        if (firestoreReachable) {
          _updateStatus(ConnectivityStatus.online);
        } else {
          _updateStatus(ConnectivityStatus.limited);
        }
      } else {
        _updateStatus(ConnectivityStatus.offline);
      }
    } on SocketException catch (_) {
      _updateStatus(ConnectivityStatus.offline);
    } on TimeoutException catch (_) {
      _updateStatus(ConnectivityStatus.limited);
    } catch (e) {
      
      _updateStatus(ConnectivityStatus.offline);
    }

    return _currentStatus;
  }

  Future<bool> _checkFirestoreConnectivity() async {
    try {
      // Try a simple Firestore operation
      await FirebaseFirestore.instance
          .collection('_connectivity_check')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      
      return false;
    }
  }

  void _updateStatus(ConnectivityStatus newStatus) {
    if (_currentStatus != newStatus) {
      
      _currentStatus = newStatus;
      _statusController.add(newStatus);
    }
  }

  /// Check if online
  bool get isOnline => _currentStatus == ConnectivityStatus.online;

  /// Check if offline
  bool get isOffline => _currentStatus == ConnectivityStatus.offline;

  /// Dispose
  void dispose() {
    _checkTimer?.cancel();
    _statusController.close();
  }
}

/// Offline Data Cache Service
class OfflineCacheService {
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // Cache keys
  static const String _userProfileKey = 'cached_user_profile';
  static const String _messagesKey = 'cached_messages';
  static const String _pendingActionsKey = 'pending_actions';
  static const String _lastSyncKey = 'last_sync_time';

  /// Initialize cache service
  Future<void> initialize() async {
    if (_isInitialized) return;

    
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
  }

  // ============ USER PROFILE CACHE ============

  /// Cache user profile
  Future<void> cacheUserProfile(Map<String, dynamic> profile) async {
    await _prefs.setString(_userProfileKey, _encodeJson(profile));
    
  }

  /// Get cached user profile
  Map<String, dynamic>? getCachedUserProfile() {
    final data = _prefs.getString(_userProfileKey);
    if (data != null) {
      return _decodeJson(data);
    }
    return null;
  }

  // ============ MESSAGES CACHE ============

  /// Cache messages for a conversation
  Future<void> cacheMessages(
    String conversationId,
    List<Map<String, dynamic>> messages,
  ) async {
    final key = '${_messagesKey}_$conversationId';
    await _prefs.setString(key, _encodeJsonList(messages));
    
  }

  /// Get cached messages
  List<Map<String, dynamic>> getCachedMessages(String conversationId) {
    final key = '${_messagesKey}_$conversationId';
    final data = _prefs.getString(key);
    if (data != null) {
      return _decodeJsonList(data);
    }
    return [];
  }

  // ============ PENDING ACTIONS ============

  /// Add pending action (to be synced when online)
  Future<void> addPendingAction(PendingAction action) async {
    final actions = getPendingActions();
    actions.add(action.toMap());
    await _prefs.setString(_pendingActionsKey, _encodeJsonList(actions));
    
  }

  /// Get all pending actions
  List<Map<String, dynamic>> getPendingActions() {
    final data = _prefs.getString(_pendingActionsKey);
    if (data != null) {
      return _decodeJsonList(data);
    }
    return [];
  }

  /// Clear pending actions
  Future<void> clearPendingActions() async {
    await _prefs.remove(_pendingActionsKey);
    
  }

  /// Remove specific pending action
  Future<void> removePendingAction(String actionId) async {
    final actions = getPendingActions();
    actions.removeWhere((a) => a['id'] == actionId);
    await _prefs.setString(_pendingActionsKey, _encodeJsonList(actions));
  }

  // ============ SYNC MANAGEMENT ============

  /// Update last sync time
  Future<void> updateLastSyncTime() async {
    await _prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Get last sync time
  DateTime? getLastSyncTime() {
    final timestamp = _prefs.getInt(_lastSyncKey);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  /// Check if needs sync (older than 5 minutes)
  bool needsSync() {
    final lastSync = getLastSyncTime();
    if (lastSync == null) return true;

    final diff = DateTime.now().difference(lastSync);
    return diff.inMinutes > 5;
  }

  // ============ GENERIC CACHE ============

  /// Cache any data
  Future<void> cacheData(String key, Map<String, dynamic> data) async {
    await _prefs.setString('cache_$key', _encodeJson(data));
  }

  /// Get cached data
  Map<String, dynamic>? getCachedData(String key) {
    final data = _prefs.getString('cache_$key');
    if (data != null) {
      return _decodeJson(data);
    }
    return null;
  }

  /// Clear specific cache
  Future<void> clearCache(String key) async {
    await _prefs.remove('cache_$key');
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith('cache_'));
    for (final key in keys) {
      await _prefs.remove(key);
    }
    
  }

  // ============ HELPERS ============

  String _encodeJson(Map<String, dynamic> data) {
    // Simple JSON encoding - in production use jsonEncode
    return data.entries.map((e) => '${e.key}=${e.value}').join('||');
  }

  Map<String, dynamic> _decodeJson(String data) {
    // Simple JSON decoding - in production use jsonDecode
    final result = <String, dynamic>{};
    for (final part in data.split('||')) {
      final kv = part.split('=');
      if (kv.length == 2) {
        result[kv[0]] = kv[1];
      }
    }
    return result;
  }

  String _encodeJsonList(List<Map<String, dynamic>> list) {
    return list.map((m) => _encodeJson(m)).join('|||');
  }

  List<Map<String, dynamic>> _decodeJsonList(String data) {
    if (data.isEmpty) return [];
    return data.split('|||').map((s) => _decodeJson(s)).toList();
  }
}

/// Pending Action Model
class PendingAction {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;

  PendingAction({
    required this.id,
    required this.type,
    required this.data,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PendingAction.fromMap(Map<String, dynamic> map) {
    return PendingAction(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(int.parse(map['createdAt']))
          : DateTime.now(),
      retryCount: int.tryParse(map['retryCount']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'data': _flattenData(data),
      'createdAt': createdAt.millisecondsSinceEpoch.toString(),
      'retryCount': retryCount.toString(),
    };
  }

  String _flattenData(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}:${e.value}').join(',');
  }
}

/// Sync Service - Handles syncing pending actions when online
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final ConnectivityService _connectivity = ConnectivityService();
  final OfflineCacheService _cache = OfflineCacheService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSyncing = false;
  StreamSubscription? _connectivitySubscription;

  /// Initialize sync service
  Future<void> initialize() async {
    

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.statusStream.listen((status) {
      if (status == ConnectivityStatus.online) {
        syncPendingActions();
      }
    });

    // Initial sync if online
    if (_connectivity.isOnline) {
      await syncPendingActions();
    }
  }

  /// Sync all pending actions
  Future<void> syncPendingActions() async {
    if (_isSyncing) {
      
      return;
    }

    final actions = _cache.getPendingActions();
    if (actions.isEmpty) {
      
      return;
    }

    
    _isSyncing = true;

    for (final actionMap in actions) {
      final action = PendingAction.fromMap(actionMap);

      try {
        await _executePendingAction(action);
        await _cache.removePendingAction(action.id);
        
      } catch (e) {
        

        // Increment retry count
        if (action.retryCount < 3) {
          final updatedAction = PendingAction(
            id: action.id,
            type: action.type,
            data: action.data,
            createdAt: action.createdAt,
            retryCount: action.retryCount + 1,
          );
          await _cache.removePendingAction(action.id);
          await _cache.addPendingAction(updatedAction);
        } else {
          // Too many retries, remove action
          await _cache.removePendingAction(action.id);
          
        }
      }
    }

    await _cache.updateLastSyncTime();
    _isSyncing = false;
    
  }

  Future<void> _executePendingAction(PendingAction action) async {
    switch (action.type) {
      case 'send_message':
        await _syncMessage(action.data);
        break;
      case 'update_profile':
        await _syncProfileUpdate(action.data);
        break;
      case 'like_post':
        await _syncLike(action.data);
        break;
      case 'send_gift':
        await _syncGift(action.data);
        break;
      default:
        
    }
  }

  Future<void> _syncMessage(Map<String, dynamic> data) async {
    final conversationId = data['conversationId'];
    final message = data['message'];

    if (conversationId != null && message != null) {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
        'content': message,
        'senderId': data['senderId'],
        'createdAt': FieldValue.serverTimestamp(),
        'syncedFromOffline': true,
      });
    }
  }

  Future<void> _syncProfileUpdate(Map<String, dynamic> data) async {
    final oderId = data['oderId'];
    if (oderId != null) {
      await _firestore.collection('users').doc(oderId).update(data);
    }
  }

  Future<void> _syncLike(Map<String, dynamic> data) async {
    final postId = data['postId'];
    final oderId = data['oderId'];

    if (postId != null && oderId != null) {
      await _firestore.collection('posts').doc(postId).update({
        'likes': FieldValue.arrayUnion([oderId]),
        'likeCount': FieldValue.increment(1),
      });
    }
  }

  Future<void> _syncGift(Map<String, dynamic> data) async {
    // Implement gift sync
    
  }

  /// Dispose
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}

/// Offline Banner Widget
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectivityStatus>(
      stream: ConnectivityService().statusStream,
      initialData: ConnectivityService().currentStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? ConnectivityStatus.online;

        if (status == ConnectivityStatus.online) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: status == ConnectivityStatus.offline
              ? Colors.red.shade700
              : Colors.orange.shade700,
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  status == ConnectivityStatus.offline
                      ? Icons.wifi_off
                      : Icons.signal_wifi_statusbar_connected_no_internet_4,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  status == ConnectivityStatus.offline
                      ? 'You are offline'
                      : 'Limited connectivity',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
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

/// Retry Button Widget
class RetryButton extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;

  const RetryButton({
    super.key,
    required this.onRetry,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message ?? 'Something went wrong',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE94057),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
