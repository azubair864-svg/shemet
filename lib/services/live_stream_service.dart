import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/live_stream_model.dart';

/// ⭐⭐⭐ PRODUCTION-READY LIVE STREAM SERVICE ⭐⭐⭐
/// Manages all live streaming operations with Firestore
/// Features: Create, start, stop, update, discover streams
class LiveStreamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern for memory efficiency
  static final LiveStreamService _instance = LiveStreamService._internal();
  factory LiveStreamService() => _instance;
  LiveStreamService._internal();

  /// 🎥 Create a new live stream
  /// Returns the stream ID if successful, null otherwise
  Future<String?> createLiveStream({
    required String title,
    String? description,
    List<String> tags = const [],
    String? thumbnailUrl,
  }) async {
    
    
    
    
    

    try {
      // 1. Get current user info
      
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        
        return null;
      }

      final userId = currentUser.uid;
      final userName = currentUser.displayName ?? 'Unknown';
      final userPhoto = currentUser.photoURL ?? '';
      

      // 2. Check if user already has an active stream
      
      final existingStreams = await _firestore
          .collection('live_streams')
          .where('hostId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      if (existingStreams.docs.isNotEmpty) {
        
        final existingStreamId = existingStreams.docs.first.id;
        
        
        return existingStreamId;
      }
      

      // 2b. Cleanup OLD streams for this user (Prevent Ghost streams)
      final oldStreams = await _firestore
          .collection('live_streams')
          .where('hostId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();
      
      if (oldStreams.docs.isNotEmpty) {
        final cleanupBatch = _firestore.batch();
        for (var doc in oldStreams.docs) {
          cleanupBatch.update(doc.reference, {'isActive': false});
        }
        await cleanupBatch.commit();
        // debugPrint('[LIVE_DEBUG] 🧹 Cleaned up ${oldStreams.docs.length} stale streams for $userId');
      }
      
      // 3. Generate unique stream ID and channel name
      
      final streamId = _firestore.collection('live_streams').doc().id;
      final channelName = 'live_$streamId';
      
      

      // 4. Create live stream model
      
      final liveStream = LiveStreamModel(
        streamId: streamId,
        hostId: userId,
        hostName: userName,
        hostPhoto: userPhoto,
        title: title,
        description: description,
        viewerCount: 0,
        isActive: false, // Will be set to true when broadcasting starts
        startedAt: DateTime.now(),
        channelName: channelName,
        thumbnailUrl: thumbnailUrl,
        tags: tags,
        totalDiamondsReceived: 0,
        totalGiftsReceived: 0,
      );

      // 5. Save to Firestore
      
      await _firestore
          .collection('live_streams')
          .doc(streamId)
          .set(liveStream.toMap());
      

      // 6. Update user's streaming status (ONLY lastLiveStreamAt here)
      await _firestore.collection('users').doc(userId).update({
        'lastLiveStreamAt': FieldValue.serverTimestamp(),
      });
      

      
      
      
      

      return streamId;
    } catch (e) {
      
      
      
      
      return null;
    }
  }

  /// 🚀 Start broadcasting (set stream as active)
  Future<bool> startBroadcasting(String streamId) async {
    
    

    try {
      // 1. Get stream document
      
      final streamDoc = await _firestore
          .collection('live_streams')
          .doc(streamId)
          .get();

      if (!streamDoc.exists) {
        
        return false;
      }
      

      // 3. Set user as LIVE
      final streamData = streamDoc.data()!;
      final userId = streamData['hostId'];
      
      final batch = _firestore.batch();
      
      // Update stream status
      batch.update(_firestore.collection('live_streams').doc(streamId), {
        'isActive': true,
        'startedAt': FieldValue.serverTimestamp(),
      });

      // Update user status
      batch.update(_firestore.collection('users').doc(userId), {
        'isLive': true,
        'currentStreamId': streamId,
      });

      // Add activity
      final activityRef = _firestore.collection('activities').doc();
      batch.set(activityRef, {
        'type': 'live_stream_started',
        'userId': userId,
        'userName': streamData['hostName'],
        'streamId': streamId,
        'streamTitle': streamData['title'],
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
      

      
      return true;
    } catch (e) {
      
      
      
      
      return false;
    }
  }

  /// 🛑 Stop broadcasting (end stream)
  Future<bool> stopBroadcasting(String streamId) async {
    
    

    try {
      // 1. Get stream document
      
      final streamDoc = await _firestore
          .collection('live_streams')
          .doc(streamId)
          .get();

      if (!streamDoc.exists) {
        
        return false;
      }

      final streamData = streamDoc.data()!;
      
      
      
      

      // 2. Use a Batch for atomic update
      final batch = _firestore.batch();
      final hostId = streamData['hostId'];

      // Update stream to inactive
      batch.update(_firestore.collection('live_streams').doc(streamId), {
        'isActive': false,
        'endedAt': FieldValue.serverTimestamp(),
      });

      // Update user status (CLEANUP)
      batch.update(_firestore.collection('users').doc(hostId), {
        'isLive': false,
        'currentStreamId': null,
        'totalLiveStreams': FieldValue.increment(1),
      });

      // Save statistics
      final statsRef = _firestore.collection('stream_statistics').doc(streamId);
      batch.set(statsRef, {
        'streamId': streamId,
        'hostId': hostId,
        'hostName': streamData['hostName'],
        'title': streamData['title'],
        'startedAt': streamData['startedAt'],
        'endedAt': FieldValue.serverTimestamp(),
        'viewerCount': streamData['viewerCount'],
        'totalDiamondsReceived': streamData['totalDiamondsReceived'],
        'totalGiftsReceived': streamData['totalGiftsReceived'],
        'tags': streamData['tags'] ?? [],
      });

      await batch.commit();
      // debugPrint('[LIVE_DEBUG] ✅ stopBroadcasting: Reset user $hostId isLive to false');
      return true;
      

      
      return true;
    } catch (e) {
      
      
      
      
      return false;
    }
  }

  /// 👥 Update viewer count
  Future<bool> updateViewerCount(String streamId, int count) async {
    
    
    

    try {
      await _firestore.collection('live_streams').doc(streamId).update({
        'viewerCount': count,
      });
      
      
      return true;
    } catch (e) {
      
      
      
      
      return false;
    }
  }

  /// ➕ Increment viewer count
  Future<bool> incrementViewerCount(String streamId) async {
    
    

    try {
      await _firestore.collection('live_streams').doc(streamId).update({
        'viewerCount': FieldValue.increment(1),
      });
      
      
      return true;
    } catch (e) {
      
      
      
      
      return false;
    }
  }

  /// ➖ Decrement viewer count
  Future<bool> decrementViewerCount(String streamId) async {
    
    

    try {
      await _firestore.collection('live_streams').doc(streamId).update({
        'viewerCount': FieldValue.increment(-1),
      });
      
      
      return true;
    } catch (e) {
      
      
      
      
      return false;
    }
  }

  /// 🔍 Get all active live streams
  Future<List<LiveStreamModel>> getActiveLiveStreams({
    int limit = 20,
    List<String>? tags,
  }) async {
    
    
    

    try {
      Query query = _firestore
          .collection('live_streams')
          .where('isActive', isEqualTo: true)
          .orderBy('viewerCount', descending: true)
          .limit(limit);

      if (tags != null && tags.isNotEmpty) {
        
        query = query.where('tags', arrayContainsAny: tags);
      }

      final snapshot = await query.get();
      

      final streams = snapshot.docs
          .map((doc) => LiveStreamModel.fromMap({
                ...doc.data() as Map<String, dynamic>,
                'streamId': doc.id,
              }))
          .toList();

      for (var stream in streams) {
        
      }

      
      

      return streams;
    } catch (e) {
      
      
      
      
      return [];
    }
  }

  /// 📺 Get single live stream by ID
  Future<LiveStreamModel?> getLiveStream(String streamId) async {
    
    

    try {
      final doc = await _firestore
          .collection('live_streams')
          .doc(streamId)
          .get();

      if (!doc.exists) {
        
        return null;
      }

      final stream = LiveStreamModel.fromMap({
        ...doc.data() as Map<String, dynamic>,
        'streamId': doc.id,
      });

      
      
      
      
      

      return stream;
    } catch (e) {
      
      
      
      
      return null;
    }
  }

  /// 🎬 Stream live streams in real-time
  Stream<List<LiveStreamModel>> streamActiveLiveStreams({
    int limit = 20,
    List<String>? tags,
  }) {
    
    
    

    Query query = _firestore
        .collection('live_streams')
        .where('isActive', isEqualTo: true)
        .orderBy('viewerCount', descending: true)
        .limit(limit);

    if (tags != null && tags.isNotEmpty) {
      query = query.where('tags', arrayContainsAny: tags);
    }

    return query.snapshots().map((snapshot) {
      

      return snapshot.docs
          .map((doc) => LiveStreamModel.fromMap({
                ...doc.data() as Map<String, dynamic>,
                'streamId': doc.id,
              }))
          .toList();
    });
  }

  /// 🎁 Record gift sent in live stream
  Future<bool> recordGift({
    required String streamId,
    required String senderId,
    required String senderName,
    required int giftValue,
  }) async {
    
    
    
    

    try {
      // Update stream totals
      await _firestore.collection('live_streams').doc(streamId).update({
        'totalDiamondsReceived': FieldValue.increment(giftValue),
        'totalGiftsReceived': FieldValue.increment(1),
      });
      
      
      return true;
    } catch (e) {
      
      
      
      
      return false;
    }
  }

  /// 🗑️ Delete live stream (admin only)
  Future<bool> deleteLiveStream(String streamId) async {
    
    

    try {
      await _firestore.collection('live_streams').doc(streamId).delete();
      
      
      return true;
    } catch (e) {
      
      
      
      
      return false;
    }
  }

  /// 📊 Get stream statistics
  Future<Map<String, dynamic>?> getStreamStatistics(String streamId) async {
    
    

    try {
      final doc = await _firestore
          .collection('stream_statistics')
          .doc(streamId)
          .get();

      if (!doc.exists) {
        
        return null;
      }

      final stats = doc.data()!;
      
      
      
      
      
      

      
      

      return stats;
    } catch (e) {
      
      
      
      
      return null;
    }
  }
}
