import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_model.dart';
import '../core/constants/api_constants.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _authDbLog(String message) {
    final n = DateTime.now();
    final ts =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}.${n.millisecond.toString().padLeft(3, '0')}';
    debugPrint('[AUTH_TRACE][$ts][DB_SERVICE] $message');
  }

  // ==================== USER CRUD OPERATIONS ====================

  /// Internal method to get the next sequential ID (starting from 1000)
  /// Internal method to get the next sequential ID (starting from 10M)
  Future<int> getNextSequenceId() async {
    final counterRef = _firestore.collection('settings').doc('counters');
    
    return await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      
      if (!snapshot.exists) {
        // Initialize if doesn't exist - Starting from 10,000,000
        transaction.set(counterRef, {'lastUserId': 10000000});
        return 10000000;
      }
      
      final lastId = snapshot.data()?['lastUserId'] ?? 9999999;
      final nextId = (lastId as int) + 1;
      
      transaction.update(counterRef, {'lastUserId': nextId});
      return nextId;
    });
  }

  /// Ensures a user has a numeric ID, generates one if missing.
  Future<String?> ensureNumericId(String userId) async {
    try {
      final userRef = _firestore.collection(ApiConstants.usersCollection).doc(userId);
      final doc = await userRef.get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      if (data['id'] != null) return data['id'].toString();

      final nextId = await getNextSequenceId();
      final stringId = nextId.toString();
      await userRef.update({'id': stringId});
      return stringId;
    } catch (e) {
      debugPrint('Error ensuring numeric ID: $e');
      return null;
    }
  }

  Future<void> saveUserData(UserModel user) async {
    try {
      final userRef = _firestore.collection(ApiConstants.usersCollection).doc(user.uid);
      final doc = await userRef.get();

      if (!doc.exists) {
        // It's a new user! Generate their sequential ID
        final nextId = await getNextSequenceId();
        
        // Create new user data with sequence ID
        final data = user.toMap();
        data['id'] = nextId.toString(); // Sequential ID
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();
        
        await userRef.set(data);
      } else {
        // Existing user, just update
        final data = user.toMap();
        
        // Canonical format for gender-based discovery
        if (data['gender'] != null) {
          data['gender'] = data['gender'].toString().toLowerCase();
        }
        
        data['updatedAt'] = FieldValue.serverTimestamp();
        // Remove 'id' from update to prevent overwriting sequential ID if somehow changed
        data.remove('id'); 
        
        await userRef.update(data);
      }
    } catch (e) {
      debugPrint('Error saving user data: $e');
      rethrow;
    }
  }

  // Create user
  Future<bool> createUser(UserModel user) async {
    try {
      await saveUserData(user);
      _authDbLog('createUser success uid=${user.uid}');
      return true;
    } catch (e) {
      _authDbLog('createUser exception uid=${user.uid} error=$e');
      return false;
    }
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore
          .collection(ApiConstants.usersCollection)
          .doc(userId)
          .get();

      if (!doc.exists) {
        debugPrint('[SOCIAL_DEBUG] getUserById: document does not exist for uid=$userId');
        return null;
      }

      final user = UserModel.fromFirestore(doc);
      debugPrint('[SOCIAL_DEBUG] getUserById: success for uid=$userId (name=${user.name})');
      return user;
    } catch (e) {
      _authDbLog('getUserById exception uid=$userId error=$e');
      rethrow; // Do not return null on error; let the caller know it failed
    }
  }

  // Get user stream
  Stream<UserModel?> getUserStream(String userId) {
    return _firestore
        .collection(ApiConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return UserModel.fromFirestore(doc);
        });
  }

  // Get users by IDs
  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    
    try {
      // Use Future.wait to fetch documents in parallel by ID. 
      // This avoids collection-wide query permission issues.
      final docFutures = userIds.take(20).map((id) => _firestore.collection(ApiConstants.usersCollection).doc(id).get()).toList();
      final snapshots = await Future.wait(docFutures);
      
      return snapshots
          .where((doc) => doc.exists && doc.data() != null)
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      _authDbLog('getUsersByIds exception error=$e');
      return [];
    }
  }

  // Get users Stream by IDs (Simplified snapshot)
  Stream<List<UserModel>> getUsersStream(List<String> userIds) {
    if (userIds.isEmpty) return Stream.value([]);
    // Simplified: Return a stream that emits Once.
    return Stream.fromFuture(getUsersByIds(userIds));
  }

  // Update user
  Future<bool> updateUser(String userId, Map<String, dynamic> data) async {
    debugPrint('[DB_DEBUG] updateUser called for uid=$userId with data=$data');
    try {
      // Canonical format for gender-based discovery
      if (data.containsKey('gender') && data['gender'] != null) {
        data['gender'] = data['gender'].toString().toLowerCase();
      }
      
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore
          .collection(ApiConstants.usersCollection)
          .doc(userId)
          .update(data);
      return true;
    } catch (e) {
      _authDbLog('updateUser exception uid=$userId error=$e');
      return false;
    }
  }

  // Update last seen
  Future<void> updateLastSeen(String userId) async {
    try {
      await _firestore
          .collection(ApiConstants.usersCollection)
          .doc(userId)
          .update({'lastSeen': FieldValue.serverTimestamp(), 'isOnline': true});
    } catch (e) {}
  }

  // Set user offline
  Future<void> setUserOffline(String userId) async {
    try {
      await _firestore
          .collection(ApiConstants.usersCollection)
          .doc(userId)
          .update({
            'isOnline': false,
            'lastSeen': FieldValue.serverTimestamp(),
          });
    } catch (e) {}
  }

  // Update coins
  Future<bool> updateCoins(String userId, int amount) async {
    try {
      await _firestore
          .collection(ApiConstants.usersCollection)
          .doc(userId)
          .update({'diamonds': FieldValue.increment(amount)});
      return true;
    } catch (e) {
      return false;
    }
  }

  // Update diamonds
  Future<bool> updateDiamonds(String userId, int amount) async {
    try {
      await _firestore
          .collection(ApiConstants.usersCollection)
          .doc(userId)
          .update({'diamonds': FieldValue.increment(amount)});
      return true;
    } catch (e) {
      return false;
    }
  }

  // Update points
  Future<bool> updatePoints(String userId, int amount) async {
    try {
      await _firestore
          .collection(ApiConstants.usersCollection)
          .doc(userId)
          .update({'points': FieldValue.increment(amount)});
      return true;
    } catch (e) {
      return false;
    }
  }

  // Update user location
  Future<bool> updateUserLocation(String userId, GeoPoint location) async {
    try {
      await _firestore
          .collection(ApiConstants.usersCollection)
          .doc(userId)
          .update({
            'location': location,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Check if user exists
  Future<bool> userExists(String userId) async {
    try {
      final doc = await _firestore
          .collection(ApiConstants.usersCollection)
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Delete user (Complete Deep Wipe for Compliance)
  Future<bool> deleteUser(String userId) async {
    try {
      // 1. Delete Firestore Sub-collections first
      await _deleteSubcollection('${ApiConstants.usersCollection}/$userId/followers');
      await _deleteSubcollection('${ApiConstants.usersCollection}/$userId/following');
      await _deleteSubcollection('${ApiConstants.usersCollection}/$userId/blocked');
      await _deleteSubcollection('${ApiConstants.usersCollection}/$userId/reportHistory');

      // 2. Delete user-specific storage folder
      await _deleteUserStorage(userId);

      // 3. Delete main user document
      await _firestore
          .collection(ApiConstants.usersCollection)
          .doc(userId)
          .delete();
          
      _authDbLog('deleteUser complete wipe success for uid=$userId');
      return true;
    } catch (e) {
      _authDbLog('deleteUser complete wipe failed for uid=$userId error=$e');
      return false;
    }
  }

  // Helper: Delete Firestore subcollection (Doc by Doc)
  Future<void> _deleteSubcollection(String path) async {
    final ref = _firestore.collection(path);
    final snapshot = await ref.get();
    
    if (snapshot.docs.isEmpty) return;
    
    debugPrint('[CLEANUP] Deleting ${snapshot.docs.length} docs from $path');
    final batchSize = 100; // Batch limit for stability
    for (var i = 0; i < snapshot.docs.length; i += batchSize) {
      final batch = _firestore.batch();
      final chunk = snapshot.docs.skip(i).take(batchSize);
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  // Helper: Delete User Storage
  Future<void> _deleteUserStorage(String userId) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('user_photos/$userId');
      final listResult = await storageRef.listAll();
      
      for (final item in listResult.items) {
        await item.delete();
      }
      
      for (final prefix in listResult.prefixes) {
        final subItems = await prefix.listAll();
        for (final item in subItems.items) {
          await item.delete();
        }
      }
    } catch (e) {
      debugPrint('Error deleting user storage: $e');
    }
  }

  /// Uploads a profile image to Firebase Storage and returns the download URL
  Future<String?> uploadProfileImage(String userId, File imageFile) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_photos')
          .child(userId)
          .child('profile.jpg');

      // Upload with metadata
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = storageRef.putFile(imageFile, metadata);
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      debugPrint('[DB_DEBUG] ❌ Error uploading profile image: $e');
      return null;
    }
  }

  // Save FCM token
  Future<bool> saveFcmToken(String userId, String token) async {
    try {
      await _firestore
          .collection(ApiConstants.usersCollection)
          .doc(userId)
          .update({'fcmToken': token});
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== SOCIAL & RELATIONSHIPS ====================

  // Toggle Follow
  Future<bool> toggleFollow({required String followerId, required String followingId}) async {
    try {
      final followRef = _firestore
          .collection(ApiConstants.usersCollection)
          .doc(followingId)
          .collection('followers')
          .doc(followerId);

      final followingRef = _firestore
          .collection(ApiConstants.usersCollection)
          .doc(followerId)
          .collection('following')
          .doc(followingId);

      final doc = await followRef.get();

      WriteBatch batch = _firestore.batch();

      if (doc.exists) {
        // Unfollow
        batch.delete(followRef);
        batch.delete(followingRef);
        // Decrement counts
        batch.update(_firestore.collection(ApiConstants.usersCollection).doc(followingId), {
          'followers': FieldValue.increment(-1),
        });
        batch.update(_firestore.collection(ApiConstants.usersCollection).doc(followerId), {
          'following': FieldValue.increment(-1),
        });
      } else {
        // Follow
        batch.set(followRef, {
          'uid': followerId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        batch.set(followingRef, {
          'uid': followingId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        // Increment counts
        batch.update(_firestore.collection(ApiConstants.usersCollection).doc(followingId), {
          'followers': FieldValue.increment(1),
        });
        batch.update(_firestore.collection(ApiConstants.usersCollection).doc(followerId), {
          'following': FieldValue.increment(1),
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('[SOCIAL_DEBUG] Error toggling follow: $e');
      return false;
    }
  }

  /// Checks if a user is following another user
  Future<bool> isFollowingUser({required String followerId, required String followingId}) async {
    try {
      final doc = await _firestore
          .collection(ApiConstants.usersCollection)
          .doc(followingId)
          .collection('followers')
          .doc(followerId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // ==================== LIVE STREAM HEARTBEAT ====================

  // Update Viewer Session (Join/Leave) - ATOMIC TRANSACTION
  // Update Viewer Session (Join/Leave) - BULLETPROOF DIRECT WRITES
  Future<void> updateViewerSession({
    required String streamId,
    required String userId,
    required String name,
    required String photo,
    required bool isJoining,
  }) async {
    final streamRef = _firestore.collection('live_streams').doc(streamId);
    final sessionRef = streamRef.collection('viewer_sessions').doc(userId);

    final docPath = 'live_streams/$streamId/viewer_sessions/$userId';
    // debugPrint('[LIVE_DEBUG] 🛰️ updateViewerSession call: $docPath (Joining: $isJoining)');
    
    final docRef = _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('viewer_sessions')
        .doc(userId);

    try {
      if (isJoining) {
        await docRef.set({
          'userId': userId,
          'name': name,
          'photo': photo,
          'joinedAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });
        // debugPrint('[LIVE_DEBUG] ✅ Joined session: $docPath');
        
        // 2. Best-effort update for the legacy integer count (discovery)
        streamRef.update({
          'viewerCount': FieldValue.increment(1),
        }).catchError((_) => null);
      } else {
        // 1. Direct delete
        // debugPrint('[LIVE_DEBUG] Deleting session doc: ${sessionRef.path}');
        await sessionRef.delete();

        // 2. Best-effort decrement
        streamRef.update({
          'viewerCount': FieldValue.increment(-1),
        }).catchError((_) => null);
      }
      // debugPrint('[LIVE_HEARTBEAT] Direct write success for $userId (Joining: $isJoining)');
    } catch (e) {
      debugPrint('[LIVE_DEBUG] CRITICAL ERROR in updateViewerSession: $e');
    }
  }

  // Get Real-time Viewer Count (Based on active sessions for 100% accuracy)
  Stream<int> getViewerCountBySessions(String streamId) {
    // debugPrint('[LIVE_DEBUG] Initializing count stream for: $streamId');
    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('viewer_sessions')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final source = snapshot.metadata.isFromCache ? 'CACHE' : 'SERVER';
          // debugPrint('[LIVE_DEBUG] 📊 Count update for $streamId: ${snapshot.docs.length} (Source: $source)');
          return snapshot.docs.length;
        });
  }

  // Get Live Viewer Count Stream
  Stream<int> getViewerCountStream(String streamId) {
    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .snapshots()
        .map((snapshot) => snapshot.data()?['viewerCount'] ?? 0);
  }

  // Get Live Viewers Avatars Stream
  Stream<List<String>> getTopViewersPhotos(String streamId) {
    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('viewer_sessions')
        .orderBy('joinedAt', descending: true)
        .limit(5)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data()['photo'] as String)
            .where((p) => p.isNotEmpty)
            .toList());
  }

  Future<String?> createLiveStream({
    required String hostId,
    required String hostName,
    required String hostPhoto,
    required String title,
    required String coverImage,
    required List<String> tags,
    bool isPremium = false,
    int entryFee = 0,
    String premiumMode = 'none',
  }) async {
    try {
      final docRef = _firestore.collection('live_streams').doc();
      
      // Batch update: Create stream record AND update user status
      WriteBatch batch = _firestore.batch();
      
      batch.set(docRef, {
        'streamId': docRef.id,
        'hostId': hostId,
        'hostName': hostName,
        'hostPhoto': hostPhoto,
        'title': title,
        'coverImage': coverImage,
        'tags': tags,
        'viewerCount': 0,
        'isLive': true,
        'isActive': true,
        'isPremium': isPremium,
        'entryFee': entryFee,
        'premiumMode': premiumMode,
        'createdAt': FieldValue.serverTimestamp(),
        'viewers': [],
      });

      // Update the user document - we only set streamId here.
      // Global 'isLive' will be set when the broadcaster is actually ready in the room.
      DocumentReference userRef = _firestore.collection(ApiConstants.usersCollection).doc(hostId);
      batch.update(userRef, {
        'currentStreamId': docRef.id,
      });

      await batch.commit();
      
      // debugPrint('[LIVE_DEBUG] ✅ createLiveStream: Created stream ${docRef.id} and set user $hostId to isLive: true with streamId: ${docRef.id}');
      
      return docRef.id;
    } catch (e) {
      debugPrint('[LIVE_DEBUG] ❌ createLiveStream Error: $e');
      return null;
    }
  }

  // Set Global Live Status (Called when broadcaster is actually ready)
  Future<void> startLiveGlobalStatus(String userId) async {
    try {
      await _firestore.collection(ApiConstants.usersCollection).doc(userId).update({
        'isLive': true,
      });
      // debugPrint('[LIVE_DEBUG] 🚀 startLiveGlobalStatus: User $userId is now visible on Discovery');
    } catch (e) {
      debugPrint('[LIVE_DEBUG] ❌ startLiveGlobalStatus Error: $e');
    }
  }

  // End Live Stream
  Future<void> endLiveStream(String streamId, {String? hostId}) async {
    try {
      // debugPrint('[LIVE_DEBUG] 🎬 endLiveStream: Initializing cleanup for $streamId');
      
      String? actualHostId = hostId;
      
      // 1. If hostId is missing, fetch it from the stream document first
      if (actualHostId == null) {
        final doc = await _firestore.collection('live_streams').doc(streamId).get();
        if (doc.exists) {
          actualHostId = doc.data()?['hostId'];
          // debugPrint('[LIVE_DEBUG] 🔎 endLiveStream: Recovered hostId $actualHostId from stream document');
        }
      }

      WriteBatch batch = _firestore.batch();
      
      // 2. Mark stream as not live
      batch.update(_firestore.collection('live_streams').doc(streamId), {
        'isLive': false,
        'isActive': false, // Add isActive for consistency with other services
        'endedAt': FieldValue.serverTimestamp(),
      });

      // 3. Clear user's live status
      if (actualHostId != null) {
        batch.update(_firestore.collection(ApiConstants.usersCollection).doc(actualHostId), {
          'isLive': false,
          'currentStreamId': null,
        });
        // debugPrint('[LIVE_DEBUG] ✅ endLiveStream: Atomic cleanup queued for user $actualHostId');
      } else {
        debugPrint('[LIVE_DEBUG] ❌ endLiveStream: Critical Error - Could not identify host to clear status!');
      }

      await batch.commit();
      // debugPrint('[LIVE_DEBUG] ✅ endLiveStream: All status updates committed atomically.');
    } catch (e) {
      debugPrint('[LIVE_DEBUG] ❌ endLiveStream Exception: $e');
    }
  }

  // Update Live Stream Premium Status
  Future<bool> updateLiveStreamPremiumStatus({
    required String streamId,
    required bool isPremium,
    required String premiumMode,
    required int entryFee,
  }) async {
    try {
      await _firestore.collection('live_streams').doc(streamId).update({
        'isPremium': isPremium,
        'premiumMode': premiumMode,
        'entryFee': entryFee,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[LIVE_DEBUG] ❌ updateLiveStreamPremiumStatus Error: $e');
      return false;
    }
  }

  // ==================== PREMIUM LIVE BILLING ====================

  Future<bool> processPremiumBilling({
    required String viewerId,
    required String hostId,
    required String streamId,
    required int amount,
    required String mode, // 'entrance' or 'minute'
  }) async {
    try {
      debugPrint('💳 [BILLING_DEBUG] Starting billing for Viewer: $viewerId, Host: $hostId, Amount: $amount');
      final viewerRef = _firestore.collection(ApiConstants.usersCollection).doc(viewerId);
      final hostRef = _firestore.collection(ApiConstants.usersCollection).doc(hostId);

      return await _firestore.runTransaction((transaction) async {
        // 1. Check viewer balance
        final viewerSnapshot = await transaction.get(viewerRef);
        if (!viewerSnapshot.exists) {
          debugPrint('❌ [BILLING_DEBUG] Viewer document NOT FOUND: $viewerId');
          return false;
        }

        final data = viewerSnapshot.data();
        final int currentDiamonds = data?['diamonds'] ?? 0;
        
        debugPrint('📊 [BILLING_DEBUG] Viewer Data: diamonds=$currentDiamonds, Required=$amount');

        if (currentDiamonds < amount) {
          debugPrint('❌ [BILLING_DEBUG] Insufficient diamonds in Firestore! (Has $currentDiamonds, Needs $amount)');
          return false;
        }

        // 1. Deduct from Viewer (Diamonds)
        transaction.update(viewerRef, {
          'diamonds': FieldValue.increment(-amount),
        });

        // 3. Add to host (60/40 Split)
        final int hostPoints = (amount * 0.6).toInt();
        transaction.update(hostRef, {'points': FieldValue.increment(hostPoints)});

        // 2. Add to Streamer/Host (Diamonds)
        transaction.update(hostRef, {
          'diamonds': FieldValue.increment(amount),
        });

        // 5. Record Transaction
        final transactionRef = _firestore.collection('premium_transactions').doc();
        transaction.set(transactionRef, {
          'transactionId': transactionRef.id,
          'viewerId': viewerId,
          'hostId': hostId,
          'streamId': streamId,
          'amount': amount,
          'hostPoints': hostPoints,
          'mode': mode,
          'timestamp': FieldValue.serverTimestamp(),
        });

        debugPrint('✅ [BILLING_DEBUG] Transaction Successful');
        return true;
      });
    } catch (e) {
      debugPrint('🚨 [BILLING_DEBUG] CRITICAL ERROR: $e');
      return false;
    }
  }

  Future<bool> hasPaidEntranceFee(String userId, String streamId) async {
    try {
      final snapshot = await _firestore
          .collection('premium_transactions')
          .where('viewerId', isEqualTo: userId)
          .where('streamId', isEqualTo: streamId)
          .where('mode', isEqualTo: 'entrance')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('[LIVE_DEBUG] ❌ hasPaidEntranceFee Error: $e');
      return false;
    }
  }


  // ==================== LIVE STREAM CHAT ====================

  // Send Message
  Future<void> sendLiveMessage({
    required String streamId,
    required String userId,
    required String userName,
    required String message,
    String? userPhoto,
    int userLevel = 0,
    String type = 'text',
  }) async {
    try {
      await _firestore
          .collection('live_streams')
          .doc(streamId)
          .collection('messages')
          .add({
            'userId': userId,
            'userName': userName,
            'userPhoto': userPhoto ?? '',
            'message': message,
            'userLevel': userLevel,
            'type': type,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {}
  }

  // Get Messages Stream
  Stream<QuerySnapshot> getLiveMessages(String streamId) {
    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ==================== GIFTING SYSTEM ====================

  // Send Gift (Transactional)
  Future<bool> sendLiveGift({
    required String streamId,
    required String senderId,
    required String senderName,
    required String senderPhoto,
    required String receiverId,
    required String giftId,
    required String giftName,
    required int cost,
    required String giftIconUrl,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        // 1. Check Sender Balance
        final senderRef = _firestore
            .collection(ApiConstants.usersCollection)
            .doc(senderId);
        final senderDoc = await transaction.get(senderRef);

        if (!senderDoc.exists) throw Exception('Sender not found');

        final currentDiamonds = senderDoc.data()?['diamonds'] ?? 0;
        if (currentDiamonds < cost) {
          throw Exception('Insufficient balance');
        }

        // 2. Deduct Diamonds from Sender
        transaction.update(senderRef, {'diamonds': FieldValue.increment(-cost)});

        // 3. Add Diamonds and USD Balance to Receiver (Host)
        final receiverRef = _firestore
            .collection(ApiConstants.usersCollection)
            .doc(receiverId);
        
        final double incomeUSD = (cost * 0.6) / 100;
        
        transaction.update(receiverRef, {
          'diamonds': FieldValue.increment(cost),
          'walletBalanceUSD': FieldValue.increment(incomeUSD),
        });

        // 4. Record Wallet Transaction for Income
        final walletTxRef = _firestore.collection('wallet_transactions').doc();
        transaction.set(walletTxRef, {
          'userId': receiverId,
          'type': 'income',
          'amount': incomeUSD,
          'currency': 'USD',
          'description': 'Live Gift: $giftName',
          'status': 'completed',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 4. Record Gift in Stream Room
        final giftRef = _firestore
            .collection('live_streams')
            .doc(streamId)
            .collection('gifts')
            .doc();

        transaction.set(giftRef, {
          'senderId': senderId,
          'senderName': senderName,
          'senderPhoto': senderPhoto,
          'receiverId': receiverId,
          'giftId': giftId,
          'giftName': giftName,
          'cost': cost,
          'giftIconUrl': giftIconUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'combo': 1, // Prepare for combo logic
        });

        // 5. Send a System Message to Chat
        final msgRef = _firestore
            .collection('live_streams')
            .doc(streamId)
            .collection('messages')
            .doc();

        transaction.set(msgRef, {
          'userId': 'SYSTEM',
          'userName': 'System',
          'userPhoto': '',
          'message': 'Sent $giftName x1',
          'type': 'gift',
          'giftIcon': giftIconUrl,
          'timestamp': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      return false;
    }
  }

  // Get Gifts Stream
  Stream<QuerySnapshot> getLiveGifts(String streamId) {
    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('gifts')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots();
  }

  // Get Top Gifter Stream (Client-side aggregation for session-based ranking)
  Stream<Map<String, dynamic>?> getTopGifterStream(String streamId) {
    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('gifts')
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;

      final Map<String, Map<String, dynamic>> userTotals = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['senderId'] as String?;
        if (userId == null) continue;
        
        final cost = (data['cost'] ?? 0) as int;
        final name = data['senderName'] as String? ?? 'User';
        final photo = data['senderPhoto'] as String? ?? '';

        if (!userTotals.containsKey(userId)) {
          userTotals[userId] = {
            'userId': userId,
            'name': name,
            'photo': photo,
            'total': 0,
          };
        }
        userTotals[userId]!['total'] = (userTotals[userId]!['total'] as int) + cost;
      }

      // Find the top gifter
      Map<String, dynamic>? topGifter;
      int maxTotal = -1;

      userTotals.forEach((userId, info) {
        final total = info['total'] as int;
        if (total > maxTotal) {
          maxTotal = total;
          topGifter = info;
        }
      });

      return topGifter;
    });
  }

  // Upload chat image
  Future<String?> uploadChatImage(String chatId, String imagePath, {Uint8List? webBytes}) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child('$chatId/${DateTime.now().millisecondsSinceEpoch}.jpg');

      if (kIsWeb && webBytes != null) {
        await ref.putData(webBytes);
      } else {
        await ref.putFile(File(imagePath));
      }
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  // ==================== USER DISCOVERY ====================

  // Get all users with filters
  Stream<List<UserModel>> getAllUsers({
    required String currentUserId,
    UserModel? currentUser, // Priority 3: Current user for distance calculation
    int limit = 50,
    String? filterCountry,
    String? filterLanguage,
    String? filterGender, // Priority 1: Gender filter
    bool? filterIsLive, // New: Filter by live status
    int? minAge, // Priority 2: Age filter
    int? maxAge, // Priority 2: Age filter
    double? maxDistance, // Priority 3: Distance filter in km
  }) {
    Query query = _firestore
        .collection(ApiConstants.usersCollection)
        .where('uid', isNotEqualTo: currentUserId)
        .where('profileComplete', isEqualTo: true);

    if (filterCountry != null && filterCountry != 'All') {
      query = query.where('country', isEqualTo: filterCountry);
    }

    if (filterLanguage != null && filterLanguage != 'All') {
      query = query.where('language', isEqualTo: filterLanguage);
    }

    // Priority 1: Gender filter - Normalize to lowercase for canonical matching
    if (filterGender != null && filterGender != 'All') {
      // We search for lowercase version to match our standardized data
      query = query.where('gender', isEqualTo: filterGender.toLowerCase());
    }

    if (filterIsLive != null) {
      query = query.where('isLive', isEqualTo: filterIsLive);
    }

    debugPrint('[DB_DEBUG] getAllUsers Query Params: '
               'CurrentUID=$currentUserId, '
               'Gender=$filterGender, '
               'isLive=$filterIsLive, '
               'Country=$filterCountry, '
               'Language=$filterLanguage');

    return query.limit(limit).snapshots().map((snapshot) {
      debugPrint('[DB_DEBUG] Snapshot received with ${snapshot.docs.length} docs');
      
      if (snapshot.docs.isEmpty) {
        debugPrint('[DB_DEBUG] ⚠️ No documents returned from Firestore query.');
      }

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        debugPrint('[DB_DEBUG] Found doc: ${doc.id}');
        debugPrint('[DB_DEBUG]   - name: ${data['name']}');
        debugPrint('[DB_DEBUG]   - gender: ${data['gender']}');
        debugPrint('[DB_DEBUG]   - isLive: ${data['isLive']} (type: ${data['isLive']?.runtimeType})');
        debugPrint('[DB_DEBUG]   - profileComplete: ${data['profileComplete']}');
      }

      var users = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // Priority 2: Age filter (client-side filtering)
      if (minAge != null || maxAge != null) {
        final initialCount = users.length;
        users = users.where((user) {
          if (user.age == null) return false;

          if (minAge != null && user.age! < minAge) {
            return false;
          }

          if (maxAge != null && user.age! > maxAge) {
            return false;
          }

          return true;
        }).toList();
      }

      // Priority 3: Distance filter (client-side filtering)
      if (maxDistance != null &&
          currentUser != null &&
          currentUser.location != null) {
        final initialCount = users.length;

        users = users.where((user) {
          if (user.location == null) {
            return false;
          }

          final distance = currentUser.distanceTo(user);
          if (distance == null) {
            return false;
          }

          final isWithinDistance = distance <= maxDistance;

          return isWithinDistance;
        }).toList();
      } else if (maxDistance != null) {}

      return users;
    });
  }

  // Get Discover users (Future version for one-time fetch)
  Future<List<UserModel>> getDiscoverUsers({
    required String currentUserId,
    UserModel? currentUser,
    int limit = 50,
    String? filterCountry,
    String? filterLanguage,
    String? filterGender,
    bool? filterIsLive,
    int? minAge,
    int? maxAge,
    double? maxDistance,
  }) async {
    return getAllUsers(
      currentUserId: currentUserId,
      currentUser: currentUser,
      limit: limit,
      filterCountry: filterCountry,
      filterLanguage: filterLanguage,
      filterGender: filterGender,
      filterIsLive: filterIsLive,
      minAge: minAge,
      maxAge: maxAge,
      maxDistance: maxDistance,
    ).first;
  }

  // Get friends (mutual followers) once
  Future<List<UserModel>> getFriendsOnce(String userId) async {
    try {
      final followingSnapshot = await _firestore
          .collection(ApiConstants.usersCollection)
          .doc(userId)
          .collection('following')
          .get();
      
      final followingIds = followingSnapshot.docs.map((doc) => doc.id).toList();
      if (followingIds.isEmpty) return [];

      final List<String> friendIds = [];
      for (var fId in followingIds) {
        final isFollower = await isFollowingUser(followerId: fId, followingId: userId);
        if (isFollower) friendIds.add(fId);
      }

      if (friendIds.isEmpty) return [];
      return getUsersByIds(friendIds);
    } catch (e) {
      return [];
    }
  }

  // Use free trial card
  Future<bool> useFreeTrialCard(String userId) async {
    try {
      await _firestore.collection(ApiConstants.usersCollection).doc(userId).update({
        'freeTrialCards': FieldValue.increment(-1),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Process call charge
  Future<Map<String, dynamic>> processCallCharge({
    required String hostId,
    required String callId,
    required int amount,
  }) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('processCallCharge');
      final result = await callable.call({
        'hostId': hostId,
        'callId': callId,
        'amount': amount,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get users by gender
  Stream<List<UserModel>> getUsersByGender({
    required String currentUserId,
    required String gender,
    int limit = 50,
  }) {
    return _firestore
        .collection(ApiConstants.usersCollection)
        .where('uid', isNotEqualTo: currentUserId)
        .where('gender', isEqualTo: gender)
        .where('profileComplete', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data()))
              .toList();
        });
  }

  // Get online users
  Stream<List<UserModel>> getOnlineUsers({
    required String currentUserId,
    int limit = 50,
  }) {
    return _firestore
        .collection(ApiConstants.usersCollection)
        .where('uid', isNotEqualTo: currentUserId)
        .where('isOnline', isEqualTo: true)
        .where('profileComplete', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data()))
              .toList();
        });
  }

  // Get nearby users
  Future<List<UserModel>> getNearbyUsers({
    required String currentUserId,
    required double latitude,
    required double longitude,
    double radiusInKm = 50.0,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(ApiConstants.usersCollection)
          .where('uid', isNotEqualTo: currentUserId)
          .where('profileComplete', isEqualTo: true)
          .limit(100)
          .get();

      List<UserModel> nearbyUsers = [];

      for (var doc in snapshot.docs) {
        final user = UserModel.fromMap(doc.data());

        if (user.location != null) {
          final distance = Geolocator.distanceBetween(
            latitude,
            longitude,
            user.location!.latitude,
            user.location!.longitude,
          );

          final distanceInKm = distance / 1000;

          if (distanceInKm <= radiusInKm) {
            nearbyUsers.add(user);
          }
        }
      }

      nearbyUsers.sort((a, b) {
        final distanceA = Geolocator.distanceBetween(
          latitude,
          longitude,
          a.location!.latitude,
          a.location!.longitude,
        );
        final distanceB = Geolocator.distanceBetween(
          latitude,
          longitude,
          b.location!.latitude,
          b.location!.longitude,
        );
        return distanceA.compareTo(distanceB);
      });

      return nearbyUsers.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  // Get users by country
  Stream<List<UserModel>> getUsersByCountry({
    required String currentUserId,
    required String country,
    int limit = 50,
  }) {
    return _firestore
        .collection(ApiConstants.usersCollection)
        .where('uid', isNotEqualTo: currentUserId)
        .where('country', isEqualTo: country)
        .where('profileComplete', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data()))
              .toList();
        });
  }

  // ==================== MATCHING SYSTEM ====================

  // Like a user
  Future<bool> likeUser({
    required String fromUserId,
    required String toUserId,
  }) async {
    try {
      final likeId = '${fromUserId}_$toUserId';
      await _firestore.collection('likes').doc(likeId).set({
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await _checkAndCreateMatch(fromUserId, toUserId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Pass a user
  Future<bool> passUser({
    required String fromUserId,
    required String toUserId,
  }) async {
    try {
      final passId = '${fromUserId}_$toUserId';
      await _firestore.collection('passes').doc(passId).set({
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Check and create match
  Future<void> _checkAndCreateMatch(String user1Id, String user2Id) async {
    try {
      final reverseLikeId = '${user2Id}_$user1Id';
      final reverseLikeDoc = await _firestore
          .collection('likes')
          .doc(reverseLikeId)
          .get();

      if (reverseLikeDoc.exists) {
        final matchId = _generateMatchId(user1Id, user2Id);
        await _firestore.collection('matches').doc(matchId).set({
          'users': [user1Id, user2Id],
          'user1Id': user1Id,
          'user2Id': user2Id,
          'matchedAt': FieldValue.serverTimestamp(),
          'lastMessageAt': null,
          'unreadCount1': 0,
          'unreadCount2': 0,
        });
      }
    } catch (e) {}
  }

  // Generate match ID
  String _generateMatchId(String user1Id, String user2Id) {
    final ids = [user1Id, user2Id]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  // Check if liked
  Future<bool> hasLiked({
    required String fromUserId,
    required String toUserId,
  }) async {
    try {
      final likeId = '${fromUserId}_$toUserId';
      final doc = await _firestore.collection('likes').doc(likeId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Check if matched
  Future<bool> isMatched({
    required String user1Id,
    required String user2Id,
  }) async {
    try {
      final matchId = _generateMatchId(user1Id, user2Id);
      final doc = await _firestore.collection('matches').doc(matchId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get matches
  Stream<List<Map<String, dynamic>>> getUserMatches(String userId) {
    return _firestore
        .collection('matches')
        .where('users', arrayContains: userId)
        .orderBy('matchedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  // Get match with user info
  Future<Map<String, dynamic>?> getMatchWithUserInfo({
    required String currentUserId,
    required String matchId,
  }) async {
    try {
      final matchDoc = await _firestore
          .collection('matches')
          .doc(matchId)
          .get();

      if (!matchDoc.exists) return null;

      final matchData = matchDoc.data()!;
      final users = List<String>.from(matchData['users']);
      final otherUserId = users.firstWhere((id) => id != currentUserId);
      final otherUser = await getUserById(otherUserId);

      return {
        'matchId': matchId,
        'matchedAt': matchData['matchedAt'],
        'otherUser': otherUser,
      };
    } catch (e) {
      return null;
    }
  }

  // Super like a user
  Future<bool> superLikeUser({
    required String fromUserId,
    required String toUserId,
  }) async {
    try {
      final superLikeId = '${fromUserId}_$toUserId';

      // Save super like
      await _firestore.collection('super_likes').doc(superLikeId).set({
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Also create a regular like
      await likeUser(fromUserId: fromUserId, toUserId: toUserId);

      return true;
    } catch (e) {
      return false;
    }
  }

  // Unlike user
  Future<bool> unlikeUser({
    required String fromUserId,
    required String toUserId,
  }) async {
    try {
      final likeId = '${fromUserId}_$toUserId';
      await _firestore.collection('likes').doc(likeId).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Unpass user (for undo)
  Future<bool> unpassUser({
    required String fromUserId,
    required String toUserId,
  }) async {
    try {
      final passId = '${fromUserId}_$toUserId';
      await _firestore.collection('passes').doc(passId).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Unmatch users
  Future<bool> unmatchUsers({
    required String user1Id,
    required String user2Id,
  }) async {
    try {
      final matchId = _generateMatchId(user1Id, user2Id);
      await _firestore.collection('matches').doc(matchId).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== FOLLOWERS SYSTEM ====================

  // Follow user
  Future<bool> followUser({
    required String followerId,
    required String followingId,
    String? followerName,
  }) async {
    debugPrint('[SOCIAL_DEBUG] followUser: start follower=$followerId, following=$followingId');
    try {
      final batch = _firestore.batch();

      // Set following relationship
      batch.set(
        _firestore
            .collection('users')
            .doc(followerId)
            .collection('following')
            .doc(followingId),
        {
          'userId': followingId,
          'timestamp': FieldValue.serverTimestamp(),
        },
      );

      // Set followers relationship
      batch.set(
        _firestore
            .collection('users')
            .doc(followingId)
            .collection('followers')
            .doc(followerId),
        {
          'userId': followerId,
          'timestamp': FieldValue.serverTimestamp(),
        },
      );

      // Update following/followers counts
      batch.update(_firestore.collection('users').doc(followerId), {
        'following': FieldValue.increment(1),
      });

      batch.update(_firestore.collection('users').doc(followingId), {
        'followers': FieldValue.increment(1),
      });

      // Check for mutual follow (Friendship)
      // FIX: Check OWN followers instead of other's following to avoid Permission Denied
      final mutualDoc = await _firestore
          .collection(ApiConstants.usersCollection)
          .doc(followerId)
          .collection('followers')
          .doc(followingId)
          .get();

      if (mutualDoc.exists) {
        batch.update(_firestore.collection('users').doc(followerId), {
          'friends': FieldValue.increment(1),
        });
        batch.update(_firestore.collection('users').doc(followingId), {
          'friends': FieldValue.increment(1),
        });
      }

      await batch.commit();
      debugPrint('[SOCIAL_DEBUG] followUser: success (batch committed)');

      // Trigger notification
      if (followerName != null) {
        await sendUserNotification(
          userId: followingId,
          title: 'New Follower',
          body: '$followerName started following you',
          data: {
            'type': 'follow',
            'followerId': followerId,
          },
        );
      }

      return true;
    } catch (e) {
      debugPrint('[SOCIAL_DEBUG] followUser: ERROR = $e');
      return false;
    }
  }

  // Unfollow user
  Future<bool> unfollowUser({
    required String followerId,
    required String followingId,
  }) async {
    debugPrint('[SOCIAL_DEBUG] unfollowUser: start follower=$followerId, following=$followingId');
    try {
      final batch = _firestore.batch();

      // Delete following relationship
      batch.delete(
        _firestore
            .collection('users')
            .doc(followerId)
            .collection('following')
            .doc(followingId),
      );

      // Delete followers relationship
      batch.delete(
        _firestore
            .collection('users')
            .doc(followingId)
            .collection('followers')
            .doc(followerId),
      );

      // Update following/followers counts
      batch.update(_firestore.collection('users').doc(followerId), {
        'following': FieldValue.increment(-1),
      });

      batch.update(_firestore.collection('users').doc(followingId), {
        'followers': FieldValue.increment(-1),
      });

      // Check if they were friends
      // FIX: Check OWN followers instead of other's following to avoid Permission Denied
      final mutualDoc = await _firestore
          .collection(ApiConstants.usersCollection)
          .doc(followerId)
          .collection('followers')
          .doc(followingId)
          .get();

      if (mutualDoc.exists) {
        batch.update(_firestore.collection('users').doc(followerId), {
          'friends': FieldValue.increment(-1),
        });
        batch.update(_firestore.collection('users').doc(followingId), {
          'friends': FieldValue.increment(-1),
        });
      }

      await batch.commit();
      debugPrint('[SOCIAL_DEBUG] unfollowUser: success (batch committed)');
      return true;
    } catch (e) {
      debugPrint('[SOCIAL_DEBUG] unfollowUser: ERROR = $e');
      return false;
    }
  }

  // Check if following
  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(followerId)
          .collection('following')
          .doc(followingId)
          .get();

      final exists = doc.exists;
      debugPrint('[SOCIAL_DEBUG] isFollowing: result=$exists (follower=$followerId, following=$followingId)');
      return exists;
    } catch (e) {
      debugPrint('[SOCIAL_DEBUG] isFollowing: ERROR = $e');
      return false;
    }
  }

  // Get followers
  Stream<List<String>> getFollowers(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => doc.id).toList();
        });
  }

  // Get following
  Stream<List<String>> getFollowing(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => doc.id).toList();
        });
  }

  // ==================== FRIENDS SYSTEM ====================

  // Get friends
  Future<List<UserModel>> getFriends(String userId) async {
    try {
      final followersSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .get();

      final followingSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();

      final followers = followersSnapshot.docs.map((doc) => doc.id).toSet();
      final following = followingSnapshot.docs.map((doc) => doc.id).toSet();
      final friendIds = followers.intersection(following).toList();

      List<UserModel> friends = [];
      for (String friendId in friendIds) {
        final user = await getUserById(friendId);
        if (user != null) {
          friends.add(user);
        }
      }

      return friends;
    } catch (e) {
      return [];
    }
  }

  // ==================== CHAT SYSTEM ====================

  // Generate chat ID
  String _generateChatId(String user1Id, String user2Id) {
    final ids = [user1Id, user2Id]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  // Create or get chat
  Future<String> createOrGetChat({
    required String user1Id,
    required String user2Id,
  }) async {
    try {
      final chatId = _generateChatId(user1Id, user2Id);
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();

      if (!chatDoc.exists) {
        await _firestore.collection('chats').doc(chatId).set({
          'participants': [user1Id, user2Id],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': null,
          'lastMessageAt': null,
          'unreadCount': {user1Id: 0, user2Id: 0},
        });
      }

      return chatId;
    } catch (e) {
      rethrow;
    }
  }

  // Get user chats
  Stream<List<Map<String, dynamic>>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['chatId'] = doc.id;
            return data;
          }).toList();
        });
  }

  // Send message
  Future<bool> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    String type = 'text',
    String? imageUrl,
  }) async {
    try {
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      await messageRef.set({
        'chatId': chatId,
        'senderId': senderId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': type,
        'imageUrl': imageUrl,
      });

      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final participants = List<String>.from(
        chatDoc.data()?['participants'] ?? [],
      );
      final receiverId = participants.firstWhere((id) => id != senderId);

      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount.$receiverId': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get chat messages
  Stream<List<Map<String, dynamic>>> getChatMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['messageId'] = doc.id;
            return data;
          }).toList();
        });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead({
    required String chatId,
    required String userId,
  }) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'unreadCount.$userId': 0,
      });

      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('read', isEqualTo: false)
          .where('senderId', isNotEqualTo: userId)
          .get();

      for (var doc in messagesSnapshot.docs) {
        await doc.reference.update({'read': true});
      }
    } catch (e) {}
  }

  // Delete chat
  Future<bool> deleteChat(String chatId) async {
    try {
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      for (var doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }

      await _firestore.collection('chats').doc(chatId).delete();

      return true;
    } catch (e) {
      return false;
    }
  }
  // ==================== PARTY ROOM SYSTEM ====================

  // Get all active party rooms
  Stream<List<Map<String, dynamic>>> getActivePartyRooms({
    String? category,
    String? country,
  }) {
    Query query = _firestore
        .collection('party_rooms')
        .where('isActive', isEqualTo: true)
        .orderBy('participantCount', descending: true);

    if (category != null && category != 'All') {
      query = query.where('category', isEqualTo: category);
    }

    if (country != null && country != 'All') {
      query = query.where('country', isEqualTo: country);
    }

    return query.limit(50).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['roomId'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Join party room
  Future<bool> joinPartyRoom({
    required String roomId,
    required String userId,
  }) async {
    try {
      final roomDoc = await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .get();
      
      if (!roomDoc.exists) {
        return false;
      }

      final roomData = roomDoc.data()!;
      final List<String> participants = List<String>.from(roomData['participants'] ?? []);
      final bool isAlreadyInRoom = participants.contains(userId);

      // Track unique visitor
      bool isNewVisitor = false;
      final visitorsRef = _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('visitors');
      
      try {
        final visitorDoc = await visitorsRef.doc(userId).get();
        if (!visitorDoc.exists) {
          isNewVisitor = true;
          await visitorsRef.doc(userId).set({
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('Error tracking visitor: $e');
      }

      final updates = <String, dynamic>{
        'participants': FieldValue.arrayUnion([userId]),
      };

      // Only increment participantCount if they weren't already tracked as current participant
      if (!isAlreadyInRoom) {
        updates['participantCount'] = FieldValue.increment(1);
      }

      // Only increment totalVisitors if this is their first time ever in this room
      if (isNewVisitor) {
        updates['totalVisitors'] = FieldValue.increment(1);
      }

      debugPrint('[DB_DEBUG] 📝 Attempting joinPartyRoom update:');
      debugPrint('[DB_DEBUG]    -> Room: $roomId');
      debugPrint('[DB_DEBUG]    -> User: $userId');
      debugPrint('[DB_DEBUG]    -> Payload: $updates');

      await _firestore.collection('party_rooms').doc(roomId).update(updates);
      debugPrint('[DB_DEBUG] ✅ joinPartyRoom update SUCCESS');
      return true;
    } catch (e) {
      debugPrint('[DB_DEBUG] ❌ joinPartyRoom failed: $e');
      return false;
    }
  }

  // Leave party room
  Future<bool> leavePartyRoom({
    required String roomId,
    required String userId,
  }) async {
    try {
      final roomDoc = await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .get();
      
      if (!roomDoc.exists) return false;
      
      final roomData = roomDoc.data();
      final List<String> participants = List<String>.from(roomData?['participants'] ?? []);
      final bool isInRoom = participants.contains(userId);
      
      final seats = Map<String, dynamic>.from(roomData?['seats'] ?? {});

      // Find user's seat
      String? userSeat;
      seats.forEach((key, value) {
        if (value is String && value == userId) {
          userSeat = key;
        } else if (value is Map && value['userId'] == userId) {
          userSeat = key;
        }
      });

      final updates = <String, dynamic>{
        'participants': FieldValue.arrayRemove([userId]),
      };

      // Only decrement if they were actually in the list
      if (isInRoom) {
        updates['participantCount'] = FieldValue.increment(-1);
      }

      if (userSeat != null) {
        updates['seats.$userSeat'] = FieldValue.delete(); // Remove seat
      }

      debugPrint('[DB_DEBUG] 🚪 Attempting leavePartyRoom update for Room: $roomId');
      await _firestore.collection('party_rooms').doc(roomId).update(updates);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Delete party room (End party with Deep Cleanup) - OPTIMIZED WITH CLOUD FUNCTION
  Future<bool> deletePartyRoom(String roomId) async {
    try {
      debugPrint('[CLEANUP] 🧹 Triggering SERVER-SIDE Deep Cleanup for Room: $roomId');
      
      // Use Firebase Functions to handle recursive deletion (Cost: 0 client-side reads)
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('deletePartyRoomRecursive');
      final results = await callable.call(<String, dynamic>{
        'roomId': roomId,
      });

      if (results.data['success'] == true) {
        debugPrint('[CLEANUP] ✅ Server-side Cleanup successful for $roomId');
        return true;
      } else {
        debugPrint('[CLEANUP] ⚠️ Server-side Cleanup returned failure for $roomId');
        return false;
      }
    } catch (e) {
      debugPrint('[CLEANUP] ❌ Server-side Cleanup failed for $roomId: $e');
      
      // Fallback: Attempt manual top-level delete if function fails (might fail with permission)
      try {
        await _firestore.collection('party_rooms').doc(roomId).delete();
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  // Get party room by ID
  Future<Map<String, dynamic>?> getPartyRoomById(String roomId) async {
    try {
      final doc = await _firestore.collection('party_rooms').doc(roomId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      data['roomId'] = doc.id;
      return data;
    } catch (e) {
      return null;
    }
  }

  // Send party room message
  Future<bool> sendPartyRoomMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    try {
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('messages')
          .add({
            'senderId': senderId,
            'senderName': senderName,
            'text': text,
            'timestamp': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get party room messages
  Stream<List<Map<String, dynamic>>> getPartyRoomMessages(String roomId) {
    return _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['messageId'] = doc.id;
            return data;
          }).toList();
        });
  }

  // Close party room
  Future<String> createPartyRoom({
    required String hostId,
    required String hostName,
    required String hostPhoto,
    required String roomName,
    required String category,
    required String country,
    required String countryFlag,
    required int hostLevel,
    int maxSeats = 8,
    String coverPhoto = '',
    String backgroundTheme = '',
    String password = '',
    String roomType = 'audio',
    String? gameId,
    String? backgroundImage,
  }) async {
    try {
      final roomRef = _firestore.collection('party_rooms').doc();
      final roomId = roomRef.id;
      
      await roomRef.set({
        'roomId': roomId,
        'hostId': hostId,
        'hostName': hostName,
        'hostPhoto': hostPhoto,
        'roomName': roomName,
        'category': category,
        'maxSeats': maxSeats,
        'participants': [hostId],
        'seats': {
          '0': {
            'index': 0,
            'userId': hostId,
            'isLocked': false,
            'isMutedByHost': false,
            'isSelfMuted': false,
            'isVideoOn': false,
          },
        },
        'participantCount': 1,
        'pendingRequestsCount': 0,
        'isActive': true,
        'earnings': 0,
        'gameEarnings': 0, // Track game-specific tips
        'totalVisitors': 1, // Start with host
        'createdAt': FieldValue.serverTimestamp(),
        'country': country,
        'countryFlag': countryFlag,
        'hostLevel': hostLevel,
        'coverPhoto': coverPhoto,
        'backgroundTheme': backgroundTheme,
        'backgroundImage': backgroundImage, // Added for sync
        'password': password,
        'roomType': roomType,
        'gameId': gameId,
      });

      return roomId;
    } catch (e) {
      rethrow;
    }
  }
  // ==================== LIVE STREAM CHAT SYSTEM ====================

  // Send live stream message
  Future<bool> sendLiveStreamMessage({
    required String streamId,
    required String senderId,
    required String senderName,
    required String senderPhoto,
    required String text,
  }) async {
    try {
      await _firestore
          .collection('live_streams')
          .doc(streamId)
          .collection('messages')
          .add({
            'senderId': senderId,
            'senderName': senderName,
            'senderPhoto': senderPhoto,
            'text': text,
            'timestamp': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get live stream messages
  Stream<List<Map<String, dynamic>>> getLiveStreamMessages(String streamId) {
    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['messageId'] = doc.id;
            return data;
          }).toList();
        });
  }

  // Send live stream gift
  Future<bool> sendLiveStreamGift({
    required String streamId,
    required String senderId,
    required String senderName,
    required String giftId,
    required String giftName,
    required int giftValue,
  }) async {
    try {
      await _firestore
          .collection('live_streams')
          .doc(streamId)
          .collection('gifts')
          .add({
            'senderId': senderId,
            'senderName': senderName,
            'giftId': giftId,
            'giftName': giftName,
            'giftValue': giftValue,
            'timestamp': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== ADDITIONAL PARTY ROOM METHODS ====================
  // Add these methods to your existing DatabaseService class in database_service.dart

  // Get seat contributors for a room
  Future<Map<String, int>> getSeatContributions(String roomId) async {
    try {
      final doc = await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('contributions')
          .doc('totals')
          .get();

      if (!doc.exists) return {};

      final data = doc.data() as Map<String, dynamic>;
      return data.map((key, value) => MapEntry(key, value as int));
    } catch (e) {
      return {};
    }
  }

  // Update seat contribution
  Future<bool> updateSeatContribution({
    required String roomId,
    required String userId,
    required int diamondsAmount,
  }) async {
    try {
      // 1. Update background contributions collection
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('contributions')
          .doc('totals')
          .set({
            userId: FieldValue.increment(diamondsAmount),
          }, SetOptions(merge: true));

      // 2. Find and update the specific seat in the seats map
      final roomSnap = await _firestore.collection('party_rooms').doc(roomId).get();
      if (roomSnap.exists) {
        final Map? seats = roomSnap.data()?['seats'];
        if (seats != null) {
          String? targetIndex;
          seats.forEach((key, value) {
            final seatUserId = (value is Map) ? value['userId'] : value;
            if (seatUserId == userId) {
              targetIndex = key;
            }
          });

          if (targetIndex != null) {
            await _firestore.collection('party_rooms').doc(roomId).update({
              'seats.$targetIndex.contributionCoins': FieldValue.increment(diamondsAmount),
            });
          }
        }
      }

      // 3. Also update room total earnings
      await _firestore.collection('party_rooms').doc(roomId).update({
        'earnings': FieldValue.increment(diamondsAmount),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== ROOM GAME SYNCHRONIZATION ====================

  /// Start a game in a room (broadcasting to all participants)
  Future<bool> startRoomGame({
    required String roomId,
    required String gameId,
    required double crashPoint,
    String? context = 'party_room',
  }) async {
    try {
      final collection = context == 'live_stream' ? 'live_streams' : 'party_rooms';
      
      await _firestore.collection(collection).doc(roomId).update({
        'activeGame': {
          'gameId': gameId,
          'status': 'betting',
          'startTime': FieldValue.serverTimestamp(),
          'crashPoint': crashPoint, // Synced crash point
          'roundId': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update the status/metadata of the active game (for phase transitions)
  Future<bool> updateRoomGameState({
    required String roomId,
    required Map<String, dynamic> updates,
    String? context = 'party_room',
  }) async {
    try {
      final collection = context == 'live_stream' ? 'live_streams' : 'party_rooms';
      
      // We update nested fields in the activeGame object
      final Map<String, dynamic> firestoreUpdates = {};
      updates.forEach((key, value) {
        firestoreUpdates['activeGame.$key'] = value;
      });
      firestoreUpdates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection(collection).doc(roomId).update(firestoreUpdates);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Stop the active game in a room
  Future<bool> stopRoomGame({
    required String roomId,
    String? context = 'party_room',
  }) async {
    try {
      final collection = context == 'live_stream' ? 'live_streams' : 'party_rooms';
      
      await _firestore.collection(collection).doc(roomId).update({
        'activeGame': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Track earnings from games (host commission)
  Future<bool> addGameEarnings({
    required String roomId,
    required int amount,
    String? context = 'party_room',
  }) async {
    try {
      final collection = context == 'live_stream' ? 'live_streams' : 'party_rooms';
      await _firestore.collection(collection).doc(roomId).update({
        'gameEarnings': FieldValue.increment(amount),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get session summary for end screen
  Future<Map<String, dynamic>> getRoomSessionSummary(String roomId, {String? context = 'party_room'}) async {
    try {
      final collection = context == 'live_stream' ? 'live_streams' : 'party_rooms';
      final doc = await _firestore.collection(collection).doc(roomId).get();
      
      if (!doc.exists) return {};
      
      final data = doc.data()!;
      return {
        'totalGifts': data['earnings'] ?? 0,
        'totalGames': data['gameEarnings'] ?? 0,
        'totalDiamonds': (data['earnings'] ?? 0) + (data['gameEarnings'] ?? 0),
        'duration': DateTime.now().difference((data['createdAt'] as Timestamp).toDate()).inMinutes,
        'participants': (data['participants'] as List?)?.length ?? 0,
      };
    } catch (e) {
      return {};
    }
  }

  // Get top contributors for a room
  Future<List<Map<String, dynamic>>> getTopContributors({
    required String roomId,
    int limit = 4,
  }) async {
    try {
      final doc = await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('contributions')
          .doc('totals')
          .get();

      if (!doc.exists) return [];

      final data = doc.data() as Map<String, dynamic>;

      // Convert to list and sort by coins
      final contributors = data.entries
          .map((entry) => {'userId': entry.key, 'diamonds': entry.value as int})
          .toList();

      contributors.sort(
        (a, b) => (b['diamonds'] as int).compareTo(a['diamonds'] as int),
      );

      return contributors.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  // Stream of party room updates (real-time)
  Stream<Map<String, dynamic>?> getPartyRoomStream(String roomId) {
    return _firestore.collection('party_rooms').doc(roomId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['roomId'] = doc.id;
      return data;
    });
  }

  // Update seat mic status
  Future<bool> updateSeatMicStatus({
    required String roomId,
    required String userId,
    required bool isMicOn,
  }) async {
    try {
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('seats')
          .doc(userId)
          .update({'isMicOn': isMicOn});
      return true;
    } catch (e) {
      return false;
    }
  }

  // Update seat camera status
  Future<bool> updateSeatCameraStatus({
    required String roomId,
    required String userId,
    required bool isCameraOn,
  }) async {
    try {
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('seats')
          .doc(userId)
          .update({'isCameraOn': isCameraOn});
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get seat data for a user
  Future<Map<String, dynamic>?> getSeatData({
    required String roomId,
    required String userId,
  }) async {
    try {
      final doc = await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('seats')
          .doc(userId)
          .get();

      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // Kick user from seat
  Future<bool> kickUserFromSeat({
    required String roomId,
    required String userId,
    required String kickedByUserId,
  }) async {
    try {
      // Remove from participants
      await _firestore.collection('party_rooms').doc(roomId).update({
        'participants': FieldValue.arrayRemove([userId]),
        'participantCount': FieldValue.increment(-1),
      });

      // Remove seat data
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('seats')
          .doc(userId)
          .delete();

      // Log the action
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('logs')
          .add({
            'action': 'kick',
            'userId': userId,
            'kickedBy': kickedByUserId,
            'timestamp': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      return false;
    }
  }

  // Mute/unmute user
  Future<bool> toggleUserMute({
    required String roomId,
    required String userId,
    required bool mute,
  }) async {
    try {
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('seats')
          .doc(userId)
          .update({
            'isMuted': mute,
            'mutedBy': 'host',
            'mutedAt': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Send gift in party room
  Future<bool> sendPartyRoomGift({
    required String roomId,
    required String senderId,
    required String senderName,
    required String receiverId,
    required String receiverName,
    required String giftId,
    required String giftName,
    required String giftEmoji,
    required int giftValue,
  }) async {
    try {
      // Add gift to room gifts collection
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('gifts')
          .add({
            'senderId': senderId,
            'senderName': senderName,
            'receiverId': receiverId,
            'receiverName': receiverName,
            'giftId': giftId,
            'giftName': giftName,
            'giftEmoji': giftEmoji,
            'giftValue': giftValue,
            'timestamp': FieldValue.serverTimestamp(),
          });

      // Update sender's contribution
      await updateSeatContribution(
        roomId: roomId,
        userId: senderId,
        diamondsAmount: giftValue,
      );

      // Deduct diamonds from sender
      await _firestore.collection('users').doc(senderId).update({
        'diamonds': FieldValue.increment(-giftValue),
      });

      // Add diamonds to receiver
      final receiverShare = (giftValue * 0.5).toInt(); // 50% to receiver
      await _firestore.collection('users').doc(receiverId).update({
        'diamonds': FieldValue.increment(receiverShare),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // Send a system message to the party room chat
  Future<bool> sendSystemMessage({
    required String roomId,
    required String text,
  }) async {
    try {
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('messages')
          .add({
            'senderId': 'system',
            'senderName':
                'System', // Keep this distinct or empty depending on UI
            'text': text,
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'system', // Differentiate from normal chat
          });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Stream of party room gifts
  Stream<List<Map<String, dynamic>>> getPartyRoomGifts(String roomId) {
    return _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('gifts')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['giftId'] = doc.id;
            return data;
          }).toList();
        });
  }

  // Update room followers count
  Future<bool> updateRoomFollowers({
    required String roomId,
    required int change,
  }) async {
    try {
      await _firestore.collection('party_rooms').doc(roomId).update({
        'followersCount': FieldValue.increment(change),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Update room settings (e.g. allowFreeJoin)
  Future<bool> updateRoomSettings({
    required String roomId,
    required Map<String, dynamic> settings,
  }) async {
    try {
      await _firestore.collection('party_rooms').doc(roomId).update(settings);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== ADVANCED SEAT MANAGEMENT (PHASE 2) ====================

  // Request a seat (Join Queue)
  // Check if user has pending request
  Future<bool> hasPendingSeatRequest({
    required String roomId,
    required String userId,
  }) async {
    try {
      final doc = await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('seat_requests')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  Future<String?> createSeatRequest({
    required String roomId,
    required String userId,
    required String userName,
    required String userPhoto,
    required int userLevel,
    required bool isVip,
  }) async {
    try {
      // Check if already exists to avoid duplicate increments
      final existing = await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('seat_requests')
          .doc(userId)
          .get();

      if (existing.exists && existing.data()?['status'] == 'pending') {
        debugPrint(
          '[DEBUG_SEAT] ⚠️ Request already exists, skipping increment',
        );
        return existing.id;
      }

      final batch = _firestore.batch();

      final requestRef = _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('seat_requests')
          .doc(userId);

      batch.set(requestRef, {
        'userId': userId,
        'userName': userName,
        'userPhoto': userPhoto,
        'userLevel': userLevel,
        'isVip': isVip,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      final roomRef = _firestore.collection('party_rooms').doc(roomId);
      batch.update(roomRef, {'pendingRequestsCount': FieldValue.increment(1)});

      debugPrint(
        '[DEBUG_SEAT] 📝 Creating seat request: Room=$roomId, User=$userId, Name=$userName',
      );
      await batch.commit();
      debugPrint('[DEBUG_SEAT] ✅ Seat request batch committed successfully');

      // 4. Send enriched system notification to chat
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('messages')
          .add({
            'senderId': 'system',
            'senderName': 'System',
            'text': '$userName has applied for a seat',
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'seat_request',
            'userId': userId,
            'userName': userName,
          });

      return userId;
    } catch (e) {
      return null;
    }
  }

  Future<bool> requestSeat({
    required String roomId,
    required String userId,
    required String userName,
    String? userPhoto,
    int? userLevel,
    bool? isVip,
  }) async {
    final success = await createSeatRequest(
      roomId: roomId,
      userId: userId,
      userName: userName,
      userPhoto: userPhoto ?? '',
      userLevel: userLevel ?? 0,
      isVip: isVip ?? false,
    );
    return success != null;
  }

  // Cancel seat request (User side)
  Future<bool> cancelSeatRequest({
    required String roomId,
    required String userId,
  }) async {
    return rejectSeatRequest(roomId: roomId, userId: userId);
  }

  // ==================== MIC INVITATIONS ====================

  // Invite user to mic (Host side)
  Future<bool> inviteUserToMic({
    required String roomId,
    required String userId,
    required String hostName,
  }) async {
    try {
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('mic_invitations')
          .doc(userId)
          .set({
            'userId': userId,
            'hostName': hostName,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'pending',
          });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Stream of mic invitations for a specific user in a room
  Stream<Map<String, dynamic>?> getMicInvitationStream(
    String roomId,
    String userId,
  ) {
    return _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('mic_invitations')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  // Accept mic invitation (User side)
  Future<bool> acceptMicInvitation({
    required String roomId,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('mic_invitations')
          .doc(userId)
          .delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Reject mic invitation (User side)
  Future<bool> rejectMicInvitation({
    required String roomId,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('mic_invitations')
          .doc(userId)
          .delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Approve seat request (Move to specific seat)
  Future<bool> approveSeatRequest({
    required String roomId,
    required String userId,
    required int seatIndex,
    bool isLocked = false,
    bool isMutedByHost = false,
  }) async {
    try {
      // 1. Assign to seat
      await _firestore.collection('party_rooms').doc(roomId).update({
        'seats.$seatIndex': {
          'index': seatIndex,
          'userId': userId,
          'isLocked': isLocked,
          'isMutedByHost': isMutedByHost,
          'isSelfMuted': false,
          'isVideoOn': false,
        },
      });

      // 2. Remove from request queue
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('seat_requests')
          .doc(userId)
          .delete();

      // 3. Decrement count
      await _firestore.collection('party_rooms').doc(roomId).update({
        'pendingRequestsCount': FieldValue.increment(-1),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // Reject seat request
  Future<bool> rejectSeatRequest({
    required String roomId,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('seat_requests')
          .doc(userId)
          .delete();

      // Decrement count
      await _firestore.collection('party_rooms').doc(roomId).update({
        'pendingRequestsCount': FieldValue.increment(-1),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Leave seat
  Future<bool> leaveSeat({
    required String roomId,
    required int seatIndex,
  }) async {
    try {
      // Clear the seat but keep it unlocked/unmuted by default or preserve state?
      // System usually resets state when user leaves, unless locked.
      // For now, remove the entry entirely or set to null
      await _firestore.collection('party_rooms').doc(roomId).update({
        'seats.$seatIndex': FieldValue.delete(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Lock/Unlock Seat
  Future<bool> setSeatLock({
    required String roomId,
    required int seatIndex,
    required bool isLocked,
  }) async {
    try {
      // If seat exists, update it. If not, create a placeholder locked seat.
      await _firestore.collection('party_rooms').doc(roomId).set({
        'seats': {
          '$seatIndex': {
            'index': seatIndex,
            'isLocked': isLocked,
            // Preserve other fields if merging, but here we can't easily read-modify-write atomically without transaction.
            // Simplified: We assume we just merge 'isLocked'.
            // However, strictly 'seats.$index.isLocked' works if object exists.
            // If object doesn't exist, we need to create it.
          },
        },
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      return false;
    }
  }

  // Mute/Unmute Seat by Host
  Future<bool> setSeatMute({
    required String roomId,
    required int seatIndex,
    required bool isMuted,
  }) async {
    try {
      await _firestore.collection('party_rooms').doc(roomId).set({
        'seats': {
          '$seatIndex': {'isMutedByHost': isMuted},
        },
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- MISSING METHODS RESTORED/ADAPTED ---

  // Get pending seat requests
  Stream<List<Map<String, dynamic>>> getPendingSeatRequests(String roomId) {
    debugPrint(
      '[DEBUG_SEAT] 🔍 Monitoring ALL documents in path: party_rooms/$roomId/seat_requests',
    );
    return _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('seat_requests')
        .snapshots()
        .map((snapshot) {
          debugPrint(
            '[DEBUG_SEAT] 📡 Raw snapshots emitted: ${snapshot.docs.length} documents found',
          );
          final allReqs = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

          final pendingReqs = allReqs
              .where((r) => r['status'] == 'pending')
              .toList();
          debugPrint(
            '[DEBUG_SEAT] 📊 Filtered status==pending: ${pendingReqs.length} / ${allReqs.length} (Room=$roomId)',
          );

          if (pendingReqs.isNotEmpty) {
            debugPrint(
              '[DEBUG_SEAT] 👋 First Request User: ${pendingReqs[0]['userName']} (ID: ${pendingReqs[0]['userId']})',
            );
          }

          // Self-healing: Update the room document if the count is out of sync
          _syncPendingRequestsCount(roomId, pendingReqs.length);

          return pendingReqs;
        });
  }

  Future<void> _syncPendingRequestsCount(String roomId, int actualCount) async {
    try {
      final roomDoc = await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .get();
      if (roomDoc.exists) {
        final storedCount = roomDoc.data()?['pendingRequestsCount'] ?? 0;
        if (storedCount != actualCount) {
          debugPrint(
            '[DEBUG_SEAT] 🔧 SELF-HEALING: Syncing count $storedCount -> $actualCount',
          );
          await _firestore.collection('party_rooms').doc(roomId).update({
            'pendingRequestsCount': actualCount,
          });
        }
      }
    } catch (e) {
      debugPrint('[DEBUG_SEAT] 🔧 SELF-HEALING ERROR: $e');
    }
  }

  Stream<Map<String, dynamic>?> getSeatRequestStream({
    required String roomId,
    required String userId,
  }) {
    return _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('seat_requests')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  // Toggle seat lock (Wrapper/Alias for setSeatLock)
  Future<bool> toggleSeatLock({
    required String roomId,
    required int seatNumber, // assuming references index
    required bool isLocked,
  }) async {
    return setSeatLock(
      roomId: roomId,
      seatIndex: seatNumber,
      isLocked: isLocked,
    );
  }

  // Kick user from room
  Future<bool> kickUserFromRoom({
    required String roomId,
    required String userId,
    required String kickedBy,
  }) async {
    try {
      // 1. Remove from participants
      await _firestore.collection('party_rooms').doc(roomId).update({
        'participants': FieldValue.arrayRemove([userId]),
        'participantCount': FieldValue.increment(-1),
      });

      // 2. Remove from seat if occupied (Inefficient without knowing seat index, but safe)
      // We can iterate or try to delete from all potential seat keys? No, unsafe.
      // Better: The caller usually knows, but if not, we rely on leaveSeat logic or update 'seats' map by value?
      // Firestore doesn't support 'delete map entry where value == X'.
      // For now, implemented as just removing from participants.
      // Ideally we should find the seat.
      // Let's read the room doc to find the seat.
      final roomDoc = await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .get();
      if (roomDoc.exists) {
        final seats = roomDoc.data()?['seats'] as Map<dynamic, dynamic>?;
        if (seats != null) {
          String? seatIndexToRemove;
          seats.forEach((key, value) {
            if (value is Map && value['userId'] == userId) {
              seatIndexToRemove = key.toString();
            } else if (value == userId) {
              // Legacy format
              seatIndexToRemove = key.toString();
            }
          });
          if (seatIndexToRemove != null) {
            await leaveSeat(
              roomId: roomId,
              seatIndex: int.parse(seatIndexToRemove!),
            );
          }
        }
      }

      // 3. Log kick
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('logs')
          .add({
            'action': 'kick',
            'userId': userId,
            'kickedBy': kickedBy,
            'timestamp': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      return false;
    }
  }

  // Mute user in room (General mute, distinct from seat mute)
  Future<bool> muteUserInRoom({
    required String roomId,
    required String userId,
    required bool isMuted,
    required String mutedBy,
  }) async {
    try {
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('muted_users')
          .doc(userId)
          .set({
            'userId': userId,
            'isMuted': isMuted,
            'mutedBy': mutedBy,
            'mutedAt': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Follow room
  Future<bool> followRoom({
    required String roomId,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('followers')
          .doc(userId)
          .set({'userId': userId, 'followedAt': FieldValue.serverTimestamp()});

      await updateRoomFollowers(roomId: roomId, change: 1);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Unfollow room
  Future<bool> unfollowRoom({
    required String roomId,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('followers')
          .doc(userId)
          .delete();

      await updateRoomFollowers(roomId: roomId, change: -1);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Check if user is following room
  Future<bool> isFollowingRoom({
    required String roomId,
    required String userId,
  }) async {
    try {
      final doc = await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('followers')
          .doc(userId)
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get room statistics
  Future<Map<String, dynamic>> getRoomStatistics(String roomId) async {
    try {
      final roomDoc = await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .get();

      if (!roomDoc.exists) {
        return {};
      }

      final messagesCount = await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('messages')
          .count()
          .get();

      final giftsCount = await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('gifts')
          .count()
          .get();

      final followersCount = await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('followers')
          .count()
          .get();

      return {
        'totalMessages': messagesCount.count,
        'totalGifts': giftsCount.count,
        'totalFollowers': followersCount.count,
        'earnings': roomDoc.data()?['earnings'] ?? 0,
        'participantCount': roomDoc.data()?['participantCount'] ?? 0,
      };
    } catch (e) {
      return {};
    }
  }

  // ADD TO database_service.dart

  Stream<List<Map<String, dynamic>>> getNearbyPartyRooms({
    String? country,
    String? language,
  }) {
    Query query = _firestore
        .collection('party_rooms')
        .where('isActive', isEqualTo: true)
        .orderBy('participantCount', descending: true);

    if (country != null) {
      query = query.where('hostCountry', isEqualTo: country);
    }

    if (language != null) {
      query = query.where('language', isEqualTo: language);
    }

    return query.limit(50).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['roomId'] = doc.id;
        return data;
      }).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getFollowingPartyRooms(
    String userId,
  ) async* {
    try {
      final followingDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();

      final followingIds = followingDoc.docs.map((doc) => doc.id).toList();

      if (followingIds.isEmpty) {
        yield [];
        return;
      }

      List<Map<String, dynamic>> allRooms = [];

      for (int i = 0; i < followingIds.length; i += 10) {
        final chunk = followingIds.skip(i).take(10).toList();

        final roomsSnapshot = await _firestore
            .collection('party_rooms')
            .where('isActive', isEqualTo: true)
            .where('hostId', whereIn: chunk)
            .get();

        allRooms.addAll(
          roomsSnapshot.docs.map((doc) {
            final data = doc.data();
            data['roomId'] = doc.id;
            return data;
          }),
        );
      }

      allRooms.sort(
        (a, b) =>
            (b['participantCount'] ?? 0).compareTo(a['participantCount'] ?? 0),
      );

      yield allRooms;
    } catch (e) {
      yield [];
    }
  }
  // Add these methods to your existing DatabaseService class:

  // ==================== FAVORITES SYSTEM ====================

  Future<bool> addToFavorites(String userId, String favoriteUserId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(favoriteUserId)
          .set({
            'userId': favoriteUserId,
            'addedAt': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeFromFavorites(String userId, String favoriteUserId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(favoriteUserId)
          .delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isFavorite(String userId, String favoriteUserId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(favoriteUserId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  Stream<List<String>> getUserFavorites(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => doc.id).toList();
        });
  }

  // ==================== GIFT SYSTEM ====================

  Future<bool> sendGift({
    required String senderId,
    required String receiverId,
    required String giftId,
    required String giftName,
    required String giftEmoji,
    required int giftValue,
  }) async {
    try {
      // Record gift transaction
      await _firestore.collection('gifts').add({
        'senderId': senderId,
        'receiverId': receiverId,
        'giftId': giftId,
        'giftName': giftName,
        'giftEmoji': giftEmoji,
        'giftValue': giftValue,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Deduct diamonds from sender
      await _firestore.collection('users').doc(senderId).update({
        'diamonds': FieldValue.increment(-giftValue),
      });

      // Add diamonds to receiver (50% commission)
      final receiverDiamonds = (giftValue * 0.5).toInt();
      await _firestore.collection('users').doc(receiverId).update({
        'diamonds': FieldValue.increment(receiverDiamonds),
        'giftsReceived': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getUserGifts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('gifts')
          .where('receiverId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, int>> getGiftsSummary(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('gifts')
          .where('receiverId', isEqualTo: userId)
          .get();

      final Map<String, int> giftCounts = {};

      for (var doc in snapshot.docs) {
        final giftName = doc.data()['giftName'] as String;
        giftCounts[giftName] = (giftCounts[giftName] ?? 0) + 1;
      }

      return giftCounts;
    } catch (e) {
      return {};
    }
  }

  Future<bool> reportUser({
    required String reporterId,
    required String reportedUserId,
    required String reason,
    String? description,
  }) async {
    try {
      await _firestore.collection('reports').add({
        'reporterId': reporterId,
        'reportedUserId': reportedUserId,
        'reason': reason,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== BLOCK SYSTEM ====================

  Future<bool> blockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(blockerId)
          .collection('blocked')
          .doc(blockedId)
          .set({
        'userId': blockedId,
        'blockedAt': FieldValue.serverTimestamp(),
      });

      // Also unfollow if following (Mutual unfollow for block)
      await unfollowUser(followerId: blockerId, followingId: blockedId);
      await unfollowUser(followerId: blockedId, followingId: blockerId);

      return true;
    } catch (e) {
      debugPrint('[BLOCK_ERROR] Failed to block user: $e');
      return false;
    }
  }

  Future<bool> unblockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(blockerId)
          .collection('blocked')
          .doc(blockedId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('[BLOCK_ERROR] Failed to unblock user: $e');
      return false;
    }
  }

  Future<bool> isBlocked({
    required String currentUserId,
    required String otherUserId,
  }) async {
    debugPrint('[SOCIAL_DEBUG] isBlocked: checking $currentUserId blocks $otherUserId');
    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked')
          .doc(otherUserId)
          .get();
      final result = doc.exists;
      debugPrint('[SOCIAL_DEBUG] isBlocked: result=$result');
      return result;
    } catch (e) {
      debugPrint('[SOCIAL_DEBUG] isBlocked: error=$e');
      return false;
    }
  }

  Stream<bool> isBlockedStream({
    required String currentUserId,
    required String otherUserId,
  }) {
    debugPrint('[SOCIAL_DEBUG] isBlockedStream: listening $currentUserId -> $otherUserId');
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked')
        .doc(otherUserId)
        .snapshots()
        .map((doc) {
          final result = doc.exists;
          debugPrint('[SOCIAL_DEBUG] isBlockedStream: update result=$result ($currentUserId -> $otherUserId)');
          return result;
        });
  }

  Future<List<String>> getBlockedUsers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('blocked')
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== ONLINE STATUS ====================

  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {}
  }

  Stream<bool> getUserOnlineStatus(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      return doc.data()?['isOnline'] ?? false;
    });
  }

  // ==================== VOICE INTRODUCTION ====================

  Future<bool> uploadVoiceIntro({
    required String userId,
    required String voiceUrl,
    required int duration,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'voiceIntroUrl': voiceUrl,
        'voiceIntroDuration': duration,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteVoiceIntro(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'voiceIntroUrl': FieldValue.delete(),
        'voiceIntroDuration': FieldValue.delete(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== VERIFICATION ====================

  Future<bool> requestVerification({
    required String userId,
    required List<String> documentUrls,
  }) async {
    try {
      await _firestore.collection('verification_requests').add({
        'userId': userId,
        'documentUrls': documentUrls,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== CALL SYSTEM ====================

  Future<bool> updateCallRate(String userId, int ratePerMinute) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'callRate': ratePerMinute,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> recordCallTransaction({
    required String callerId,
    required String receiverId,
    required int duration, // in seconds
    required int totalCost,
  }) async {
    try {
      await _firestore.collection('call_transactions').add({
        'callerId': callerId,
        'receiverId': receiverId,
        'duration': duration,
        'totalCost': totalCost,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Deduct diamonds from caller
      await _firestore.collection('users').doc(callerId).update({
        'diamonds': FieldValue.increment(-totalCost),
      });

      // Add diamonds to receiver (70% commission)
      final receiverEarnings = (totalCost * 0.7).toInt();
      await _firestore.collection('users').doc(receiverId).update({
        'diamonds': FieldValue.increment(receiverEarnings),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== VIP SYSTEM ====================

  Future<bool> upgradeToVip({
    required String userId,
    required int days,
    required int cost,
  }) async {
    try {
      final expiryDate = DateTime.now().add(Duration(days: days));

      await _firestore.collection('users').doc(userId).update({
        'isVip': true,
        'vipExpiryDate': expiryDate.toIso8601String(),
        'diamonds': FieldValue.increment(-cost),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> checkVipExpiry(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();

      if (data != null && data['isVip'] == true) {
        final expiryDateStr = data['vipExpiryDate'] as String?;
        if (expiryDateStr != null) {
          final expiryDate = DateTime.parse(expiryDateStr);
          if (DateTime.now().isAfter(expiryDate)) {
            await _firestore.collection('users').doc(userId).update({
              'isVip': false,
              'vipExpiryDate': FieldValue.delete(),
            });
          }
        }
      }
    } catch (e) {}
  }

  // ==================== GIFT SYSTEM (PARTY ROOM) ====================

  // Send gift in party room with real-time update
  Future<bool> sendPartyRoomGiftTransaction({
    required String roomId,
    required String senderId,
    required String senderName,
    String? senderPhoto,
    required String receiverId,
    required String receiverName,
    String? receiverPhoto,
    required String giftId,
    required String giftName,
    required String giftEmoji,
    required int giftValue,
    int comboCount = 1,
  }) async {
    try {
      final totalValue = giftValue * comboCount;
      final receiverShare = (totalValue * 0.5).toInt(); // 50% to receiver

      // Add gift transaction
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('gifts')
          .add({
            'senderId': senderId,
            'senderName': senderName,
            'senderPhoto': senderPhoto,
            'receiverId': receiverId,
            'receiverName': receiverName,
            'receiverPhoto': receiverPhoto,
            'giftId': giftId,
            'giftName': giftName,
            'giftEmoji': giftEmoji,
            'giftValue': giftValue,
            'comboCount': comboCount,
            'totalValue': totalValue,
            'timestamp': FieldValue.serverTimestamp(),
          });

      // Update sender's diamonds
      await _firestore.collection('users').doc(senderId).update({
        'diamonds': FieldValue.increment(-totalValue),
      });

      // Update receiver's coins
      await _firestore.collection('users').doc(receiverId).update({
        'diamonds': FieldValue.increment(receiverShare),
      });

      // Update room earnings
      await _firestore.collection('party_rooms').doc(roomId).update({
        'earnings': FieldValue.increment(totalValue),
      });

      // Update seat contribution
      await updateSeatContribution(
        roomId: roomId,
        userId: senderId,
        diamondsAmount: totalValue,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get real-time gift stream
  Stream<List<Map<String, dynamic>>> getPartyRoomGiftStream(String roomId) {
    return _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('gifts')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  // ==================== AGORA TOKEN GENERATION ====================

  // Generate Agora token using Firebase Cloud Functions
  Future<String> generateAgoraToken({
    required String channelName,
    required int uid,
  }) async {
    debugPrint(
      '[DEBUG_TOKEN] 🔑 generateAgoraToken called for Channel=$channelName, UID=$uid',
    );
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'generateAgoraToken',
      );

      final response = await callable.call({
        'channelName': channelName,
        'uid': uid,
      });

      debugPrint('[DEBUG_TOKEN] 📥 RAW_RESPONSE: ${response.data}');
      final String? token = response.data['token'];

      if (token == null || token.isEmpty) {
        debugPrint(
          '[DEBUG_TOKEN] ❌ Cloud Function returned NULL or EMPTY token',
        );
        return '';
      }

      debugPrint(
        '[DEBUG_TOKEN] ✅ Successfully fetched token from Cloud Function',
      );
      return token;
    } catch (e) {
      debugPrint(
        '[DEBUG_TOKEN] ❌ Error in generateAgoraToken Cloud Function: $e',
      );
      return '';
    }
  }

  // ==================== REAL-TIME PARTICIPANT TRACKING ====================

  // Get participant details with real-time updates
  Stream<List<Map<String, dynamic>>> getRoomParticipantsStream(String roomId) {
    return _firestore
        .collection('party_rooms')
        .doc(roomId)
        .snapshots()
        .asyncMap((roomDoc) async {
          if (!roomDoc.exists) return [];

          final participants = List<String>.from(
            roomDoc.data()?['participants'] ?? [],
          );
          List<Map<String, dynamic>> participantDetails = [];

          for (String userId in participants) {
            final userDoc = await _firestore
                .collection('users')
                .doc(userId)
                .get();
            if (userDoc.exists) {
              final userData = userDoc.data()!;
              userData['userId'] = userId;
              participantDetails.add(userData);
            }
          }

          return participantDetails;
        });
  }

  // Update user microphone status
  Future<void> updateUserMicStatus({
    required String roomId,
    required String userId,
    required bool isMicOn,
  }) async {
    try {
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('mic_status')
          .doc(userId)
          .set({
            'userId': userId,
            'isMicOn': isMicOn,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {}
  }

  // Update user video status
  Future<void> updateSeatVideoStatus({
    required String roomId,
    required int seatIndex,
    required bool isVideoOn,
  }) async {
    try {
      await _firestore.collection('party_rooms').doc(roomId).update({
        'seats.${seatIndex.toString()}.isVideoOn': isVideoOn,
      });
    } catch (e) {
    }
  }

  // Get mic status stream
  Stream<Map<String, bool>> getMicStatusStream(String roomId) {
    return _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('mic_status')
        .snapshots()
        .map((snapshot) {
          Map<String, bool> micStatus = {};
          for (var doc in snapshot.docs) {
            micStatus[doc.id] = doc.data()['isMicOn'] ?? false;
          }
          return micStatus;
        });
  }

  // ==================== ROOM STATISTICS ====================

  // Increment room view count
  Future<void> incrementRoomViews(String roomId) async {
    try {
      await _firestore.collection('party_rooms').doc(roomId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {}
  }

  // Track peak participants
  Future<void> updatePeakParticipants({
    required String roomId,
    required int currentCount,
  }) async {
    try {
      final roomDoc = await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .get();
      final currentPeak = roomDoc.data()?['peakParticipants'] ?? 0;

      if (currentCount > currentPeak) {
        await _firestore.collection('party_rooms').doc(roomId).update({
          'peakParticipants': currentCount,
        });
      }
    } catch (e) {}
  }

  // ==================== ADD TO END OF database_service.dart ====================

  // Get top contributors in real-time
  Stream<List<Map<String, dynamic>>> getTopContributorsStream(String roomId) {
    return _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('contributions')
        .orderBy('totalDiamonds', descending: true)
        .limit(10)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> contributors = [];

          for (var doc in snapshot.docs) {
            final userId = doc.id;
            final totalDiamonds = doc.data()['totalDiamonds'] ?? 0;

            final userDoc = await _firestore
                .collection('users')
                .doc(userId)
                .get();
            if (userDoc.exists) {
              contributors.add({
                'userId': userId,
                'name': userDoc.data()?['name'] ?? 'Unknown',
                'photoUrl': userDoc.data()?['photos']?[0],
                'diamonds': totalDiamonds,
              });
            }
          }

          return contributors;
        });
  }

  // Track combo gifts
  Future<void> trackComboGift({
    required String roomId,
    required String senderId,
    required String receiverId,
    required String giftId,
    required int comboCount,
  }) async {
    try {
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('combos')
          .doc('${senderId}_${receiverId}_$giftId')
          .set({
            'senderId': senderId,
            'receiverId': receiverId,
            'giftId': giftId,
            'count': comboCount,
            'lastUpdate': FieldValue.serverTimestamp(),
          });
    } catch (e) {}
  }

  // Send tip in game
  Future<bool> sendGameTip({
    required String roomId,
    required String hostId,
    required String senderId,
    required int amount,
  }) async {
    try {
      // 1. Deduct diamonds from sender
      await _firestore.collection('users').doc(senderId).update({
        'diamonds': FieldValue.increment(-amount),
      });

      // 2. Add diamonds to host (50% share)
      await _firestore.collection('users').doc(hostId).update({
        'diamonds': FieldValue.increment((amount * 0.5).toInt()),
      });

      // 3. Update room game earnings
      await _firestore.collection('party_rooms').doc(roomId).update({
        'gameEarnings': FieldValue.increment(amount),
      });

      // 4. Update host's seat contribution in map
      final roomSnap = await _firestore.collection('party_rooms').doc(roomId).get();
      if (roomSnap.exists) {
        final Map? seats = roomSnap.data()?['seats'];
        if (seats != null) {
          String? targetIndex;
          seats.forEach((key, value) {
            final seatUserId = (value is Map) ? value['userId'] : value;
            if (seatUserId == hostId) {
              targetIndex = key;
            }
          });

          if (targetIndex != null) {
            await _firestore.collection('party_rooms').doc(roomId).update({
              'seats.$targetIndex.contributionCoins': FieldValue.increment(amount),
            });
          }
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get active combos
  Stream<Map<String, int>> getActiveCombosStream(String roomId) {
    return _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('combos')
        .where(
          'lastUpdate',
          isGreaterThan: DateTime.now().subtract(const Duration(seconds: 10)),
        )
        .snapshots()
        .map((snapshot) {
          Map<String, int> combos = {};
          for (var doc in snapshot.docs) {
            combos[doc.id] = doc.data()['count'] ?? 1;
          }
          return combos;
        });
  }

  // ==================== ADD TO END OF database_service.dart ====================

  // Games - Play game
  Future<Map<String, dynamic>?> playGame({
    required String roomId,
    required String userId,
    required String gameId,
    required int entryCost,
    required int winnings,
  }) async {
    try {
      // Deduct entry cost
      await _firestore.collection('users').doc(userId).update({
        'diamonds': FieldValue.increment(-entryCost),
      });

      // Add winnings
      if (winnings > 0) {
        await _firestore.collection('users').doc(userId).update({
          'diamonds': FieldValue.increment(winnings),
        });
      }

      // Save game result
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('game_results')
          .add({
            'userId': userId,
            'gameId': gameId,
            'entryCost': entryCost,
            'winnings': winnings,
            'timestamp': FieldValue.serverTimestamp(),
          });

      return {'success': true, 'winnings': winnings};
    } catch (e) {
      return null;
    }
  }

  // Follow/Unfollow room
  Future<bool> toggleFollowRoom({
    required String roomId,
    required String userId,
    required bool follow,
  }) async {
    try {
      if (follow) {
        await _firestore
            .collection('party_rooms')
            .doc(roomId)
            .collection('followers')
            .doc(userId)
            .set({
              'userId': userId,
              'followedAt': FieldValue.serverTimestamp(),
            });

        await _firestore.collection('party_rooms').doc(roomId).update({
          'followerCount': FieldValue.increment(1),
        });
      } else {
        await _firestore
            .collection('party_rooms')
            .doc(roomId)
            .collection('followers')
            .doc(userId)
            .delete();

        await _firestore.collection('party_rooms').doc(roomId).update({
          'followerCount': FieldValue.increment(-1),
        });
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // Check if following room
  // Add reaction to message
  Future<void> addMessageReaction({
    required String roomId,
    required String messageId,
    required String userId,
    required String reaction,
  }) async {
    try {
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('messages')
          .doc(messageId)
          .collection('reactions')
          .doc(userId)
          .set({
            'reaction': reaction,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {}
  }

  // Get message reactions stream
  Stream<Map<String, int>> getMessageReactionsStream({
    required String roomId,
    required String messageId,
  }) {
    return _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .collection('reactions')
        .snapshots()
        .map((snapshot) {
          Map<String, int> reactions = {};
          for (var doc in snapshot.docs) {
            final reaction = doc.data()['reaction'] as String;
            reactions[reaction] = (reactions[reaction] ?? 0) + 1;
          }
          return reactions;
        });
  }

  // Update room statistics
  Future<void> updateRoomStats({
    required String roomId,
    int? uptime,
    int? peakParticipants,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (uptime != null) {
        updates['uptime'] = uptime;
      }

      if (peakParticipants != null) {
        final roomDoc = await _firestore
            .collection('party_rooms')
            .doc(roomId)
            .get();
        final currentPeak = roomDoc.data()?['peakParticipants'] ?? 0;

        if (peakParticipants > currentPeak) {
          updates['peakParticipants'] = peakParticipants;
        }
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('party_rooms').doc(roomId).update(updates);
      }
    } catch (e) {}
  }

  // ==================== ADD THESE METHODS TO END OF database_service.dart ====================
  // Copy and paste these methods BEFORE the final closing brace } of DatabaseService class

  // ==================== BLOCK USER SYSTEM (PARTY ROOM) ====================

  /// Block user from specific room
  Future<bool> blockUserFromRoom({
    required String roomId,
    required String userId,
    required String blockedBy,
    String? reason,
  }) async {
    try {
      // Add to room's blocked list
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('blocked_users')
          .doc(userId)
          .set({
            'userId': userId,
            'blockedBy': blockedBy,
            'blockedAt': FieldValue.serverTimestamp(),
            'reason': reason,
          });

      // Add room to user's blocked rooms
      await _firestore.collection('users').doc(userId).update({
        'blockedRooms': FieldValue.arrayUnion([roomId]),
      });

      // Kick user from room
      await kickUserFromRoom(
        roomId: roomId,
        userId: userId,
        kickedBy: blockedBy,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Unblock user from room
  Future<bool> unblockUserFromRoom({
    required String roomId,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('blocked_users')
          .doc(userId)
          .delete();

      await _firestore.collection('users').doc(userId).update({
        'blockedRooms': FieldValue.arrayRemove([roomId]),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if user is blocked from room
  Future<bool> isUserBlockedFromRoom({
    required String roomId,
    required String userId,
  }) async {
    try {
      final doc = await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('blocked_users')
          .doc(userId)
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Get blocked users list for a room
  Future<List<Map<String, dynamic>>> getBlockedUsersFromRoom(
    String roomId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('blocked_users')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['userId'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== NOTIFICATION SYSTEM ====================

  /// Send notification to user
  Future<bool> sendUserNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM token (still fetch for possible Push send)
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'];

      // Store notification in Firestore for history - ALWAYS DO THIS
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
            'title': title,
            'body': body,
            'data': data ?? {},
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // If token exists, we could call an FCM server here (Future enhancement)
      if (fcmToken != null) {
         debugPrint('[SOCIAL_DEBUG] sendUserNotification: FCM token found, would send push if server configured');
      }

      return true;
    } catch (e) {
      debugPrint('[SOCIAL_DEBUG] sendUserNotification: ERROR = $e');
      return false;
    }
  }

  /// Get user notifications
  Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  /// Mark notification as read
  Future<bool> markNotificationAsRead(
    String userId,
    String notificationId,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear all notifications
  Future<bool> clearAllNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== ENTRANCE TRACKING ====================

  /// Track user entrance to room
  Future<void> trackUserEntrance({
    required String roomId,
    required String userId,
    required String userName,
    String? userPhoto,
    required int userLevel,
    required bool isVip,
  }) async {
    try {
      await _firestore
          .collection('party_rooms')
          .doc(roomId)
          .collection('entrances')
          .add({
            'userId': userId,
            'userName': userName,
            'userPhoto': userPhoto,
            'userLevel': userLevel,
            'isVip': isVip,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {}
  }

  /// Get recent entrances stream
  Stream<List<Map<String, dynamic>>> getRecentEntrances(String roomId) {
    return _firestore
        .collection('party_rooms')
        .doc(roomId)
        .collection('entrances')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  // ==================== VIEWER MODE TRACKING ====================

  /// Add user to viewers (non-seated participants)
  Future<bool> addToViewers({
    required String roomId,
    required String userId,
  }) async {
    try {
      await _firestore.collection('party_rooms').doc(roomId).update({
        'viewers': FieldValue.arrayUnion([userId]),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Remove user from viewers
  Future<bool> removeFromViewers({
    required String roomId,
    required String userId,
  }) async {
    try {
      await _firestore.collection('party_rooms').doc(roomId).update({
        'viewers': FieldValue.arrayRemove([userId]),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get viewers count
  Future<int> getViewersCount(String roomId) async {
    try {
      final doc = await _firestore.collection('party_rooms').doc(roomId).get();
      final viewers = List<String>.from(doc.data()?['viewers'] ?? []);
      return viewers.length;
    } catch (e) {
      return 0;
    }
  }

  // ==================== CHAT ENHANCEMENTS - VOICE, REACTIONS, TYPING ====================

  // Send voice message
  Future<bool> sendVoiceMessage({
    required String chatId,
    required String senderId,
    required String voiceUrl,
    required int duration,
  }) async {
    try {
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      await messageRef.set({
        'chatId': chatId,
        'senderId': senderId,
        'text': '',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'voice',
        'voiceUrl': voiceUrl,
        'voiceDuration': duration,
      });

      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final participants = List<String>.from(
        chatDoc.data()?['participants'] ?? [],
      );
      final receiverId = participants.firstWhere((id) => id != senderId);

      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': '🎤 Voice message',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount.$receiverId': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // Add reaction to message
  Future<bool> addReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'reactions.$userId': emoji});
      return true;
    } catch (e) {
      return false;
    }
  }

  // Remove reaction
  Future<bool> removeReaction({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'reactions.$userId': FieldValue.delete()});
      return true;
    } catch (e) {
      return false;
    }
  }

  // Update typing status
  Future<void> updateTypingStatus({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'typing.$userId': isTyping,
        'typingAt.$userId': FieldValue.serverTimestamp(),
      });
    } catch (e) {}
  }

  // Get typing status stream
  Stream<bool> getTypingStatus(String chatId, String otherUserId) {
    debugPrint('[SOCIAL_DEBUG] getTypingStatus: listening chatId=$chatId, otherUser=$otherUserId');
    return _firestore.collection('chats').doc(chatId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) {
        debugPrint('[SOCIAL_DEBUG] getTypingStatus: chat doc does not exist ($chatId)');
        return false;
      }
      final data = snapshot.data();
      if (data == null) return false;

      final typing = data['typing'] as Map<String, dynamic>?;
      final typingAt = data['typingAt'] as Map<String, dynamic>?;

      if (typing == null || typingAt == null) return false;

      final isTyping = typing[otherUserId] ?? false;
      debugPrint('[SOCIAL_DEBUG] getTypingStatus: isTyping=$isTyping for $otherUserId in $chatId');
      final typingTimestamp = typingAt[otherUserId];

      if (!isTyping || typingTimestamp == null) return false;

      // Check if typing was updated in last 3 seconds
      final lastUpdate = (typingTimestamp as Timestamp).toDate();
      final now = DateTime.now();
      final difference = now.difference(lastUpdate).inSeconds;

      return difference < 3;
    });
  }

  // Send gift in chat
  Future<bool> sendGiftInChat({
    required String chatId,
    required String senderId,
    required String giftId,
    required String giftName,
    required String giftEmoji,
    required int giftValue,
  }) async {
    try {
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      await messageRef.set({
        'chatId': chatId,
        'senderId': senderId,
        'text': '',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'gift',
        'giftId': giftId,
        'giftName': giftName,
        'giftEmoji': giftEmoji,
        'giftValue': giftValue,
      });

      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final participants = List<String>.from(
        chatDoc.data()?['participants'] ?? [],
      );
      final receiverId = participants.firstWhere((id) => id != senderId);

      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': '🎁 Gift',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount.$receiverId': FieldValue.increment(1),
      });

      // Deduct diamonds from sender
      await _firestore.collection('users').doc(senderId).update({
        'diamonds': FieldValue.increment(-giftValue),
      });

      // Add diamonds to receiver (50% commission)
      final receiverDiamonds = (giftValue * 0.5).toInt();
      await _firestore.collection('users').doc(receiverId).update({
        'diamonds': FieldValue.increment(receiverDiamonds),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // Delete message
  Future<bool> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'isDeleted': true, 'text': 'Message deleted'});
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== END OF NEW METHODS ====================

  // ==================== SEAT REQUEST SYSTEM ====================

  // ==================== CALL REVENUE & FEES ====================

  /// Charges call fee: Deducts from Caller, Credits 60% to Host (Points), 40% Admin Profit
  Future<bool> chargeCallFee({
    required String callerId,
    required String receiverId,
    required int amount, // Total cost (e.g., 2000)
    required String callId,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final callerRef = _firestore
            .collection(ApiConstants.usersCollection)
            .doc(callerId);
        final receiverRef = _firestore
            .collection(ApiConstants.usersCollection)
            .doc(receiverId);

        final callerDoc = await transaction.get(callerRef);

        if (!callerDoc.exists) return false;

        final currentDiamonds = (callerDoc.data()?['diamonds'] ?? 0) as int;

        if (currentDiamonds < amount) {
          return false; // Insufficient funds
        }

        // 1. Deduct full amount from Caller
        transaction.update(callerRef, {'diamonds': FieldValue.increment(-amount)});

        // 2. Calculate Payout (60%) and Commission (40%)
        final int hostPoints = (amount * 0.60).floor();
        final int adminCommission = amount - hostPoints;

        // 3. Credit Host (Points)
        transaction.update(receiverRef, {
          'points': FieldValue.increment(hostPoints),
          'totalEarnings': FieldValue.increment(
            hostPoints,
          ), // Create this field if not exists
        });

        // 4. Log Transaction (With Split Details)
        final transactionRef = _firestore.collection('transactions').doc();
        transaction.set(transactionRef, {
          'type': 'video_call_fee',
          'callId': callId,
          'senderId': callerId,
          'receiverId': receiverId,
          'amount': amount,
          'dist_host_points': hostPoints, // 60%
          'dist_system_commission': adminCommission, // 40% (Profit)
          'timestamp': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      debugPrint('Error charging call fee: $e');
      return false;
    }
  }

  // ==================== AGENCY INVITATIONS ====================

  /// Stream of pending host invitations for a user
  Stream<List<Map<String, dynamic>>> getHostInvitationsStream(String userId) {
    return _firestore
        .collection('host_invitations')
        .where('targetUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  /// Accept host invitation
  Future<bool> acceptHostInvitation({
    required String invitationId,
    required String userId,
    required String agencyId,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final invitationRef = _firestore
            .collection('host_invitations')
            .doc(invitationId);
        final userRef = _firestore
            .collection(ApiConstants.usersCollection)
            .doc(userId);

        // 1. Update invitation status
        transaction.update(invitationRef, {
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        // 2. Update user to become a host for this agency
        transaction.update(userRef, {
          'isHost': true,
          'agencyId': agencyId,
          'becameHostAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      debugPrint('Error accepting host invitation: $e');
      return false;
    }
  }

  /// Reject host invitation
  Future<bool> rejectHostInvitation(String invitationId) async {
    try {
      await _firestore.collection('host_invitations').doc(invitationId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error rejecting host invitation: $e');
      return false;
    }
  }

  // ==================== AGENT INVITATIONS ====================

  /// Stream of pending agent invitations for a user
  Stream<List<Map<String, dynamic>>> getAgentInvitationsStream(String userId) {
    return _firestore
        .collection('agent_invitations')
        .where('targetUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  /// Accept agent invitation
  Future<bool> acceptAgentInvitation({
    required String invitationId,
    required String userId,
    required String inviterAgencyId,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final invitationRef = _firestore
            .collection('agent_invitations')
            .doc(invitationId);
        final userRef = _firestore
            .collection(ApiConstants.usersCollection)
            .doc(userId);

        // 1. Update invitation status
        transaction.update(invitationRef, {
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        // 2. Update user to become a sub-agent
        transaction.update(userRef, {
          'isAgent': true,
          'parentAgencyId': inviterAgencyId,
          'becameAgentAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      debugPrint('Error accepting agent invitation: $e');
      return false;
    }
  }

  /// Reject agent invitation
  Future<bool> rejectAgentInvitation(String invitationId) async {
    try {
      await _firestore.collection('agent_invitations').doc(invitationId).update(
        {'status': 'rejected', 'rejectedAt': FieldValue.serverTimestamp()},
      );
      return true;
    } catch (e) {
      debugPrint('Error rejecting agent invitation: $e');
      return false;
    }
  }

  // ==================== INVITATION & REFERRAL SYSTEM ====================

  // Ensure user has an invitation code
  Future<String> ensureUserHasInvitationCode(String userId) async {
    try {
      final doc = await _firestore
          .collection(ApiConstants.usersCollection)
          .doc(userId)
          .get();

      if (!doc.exists) return '';

      final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      final existingCode = data['invitationCode'];
      if (existingCode != null && (existingCode as String).isNotEmpty) {
        return existingCode;
      }

      // Generate a simple unique code: prefix of UID + random suffix
      final newCode =
          '${userId.substring(0, 4).toUpperCase()}${DateTime.now().millisecond}';

      await _firestore
          .collection(ApiConstants.usersCollection)
          .doc(userId)
          .update({'invitationCode': newCode});

      return newCode;
    } catch (e) {
      debugPrint('Error ensuring invitation code: $e');
      return '';
    }
  }

  // Get users invited by this user
  Stream<List<UserModel>> getInvitedUsersStream(String userId) {
    return _firestore
        .collection(ApiConstants.usersCollection)
        .where('invitedBy', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
  }

  // Get Monthly Ranking (Mocked for now but structured for real data)
  Future<List<Map<String, dynamic>>> getInvitationRankings() async {
    try {
      final snapshot = await _firestore
          .collection(ApiConstants.usersCollection)
          .orderBy('followers', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final user = UserModel.fromFirestore(doc);
        return {
          'uid': user.uid,
          'name': user.name,
          'photo': user.mainPhoto,
          'level': user.level,
          'country': user.country,
          'invites': (user.followers / 2).floor() + 5,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting invitation rankings: $e');
      return [];
    }
  }

  /// EMERGENCY UTILITY: Clean up legacy data inconsistencies
  /// This will:
  /// 1. Convert 'Female' -> 'female' and 'Male' -> 'male'
  /// 2. Ensure 'isLive' field exists (defaults to false)
  /// 3. Remove legacy 'isLiveStreaming' field
  Future<Map<String, int>> fixStandardization() async {
    int totalProcessed = 0;
    int totalUpdated = 0;
    
    try {
      final snapshot = await _firestore.collection(ApiConstants.usersCollection).get();
      
      for (var doc in snapshot.docs) {
        totalProcessed++;
        final data = doc.data();
        final updates = <String, dynamic>{};
        
        // 1. Gender Casing
        final currentGender = data['gender']?.toString();
        if (currentGender == 'Female') updates['gender'] = 'female';
        if (currentGender == 'Male') updates['gender'] = 'male';
        
        // 2. isLive Field Synchronization
        if (!data.containsKey('isLive')) {
          updates['isLive'] = false;
        }
        
        // 3. Cleanup legacy field
        if (data.containsKey('isLiveStreaming')) {
          updates['isLiveStreaming'] = FieldValue.delete();
        }

        if (updates.isNotEmpty) {
          await doc.reference.update(updates);
          totalUpdated++;
        }
      }
      
      return {
        'processed': totalProcessed,
        'updated': totalUpdated,
      };
    } catch (e) {
      debugPrint('[DATA_REPAIR] Error during standardization: $e');
      rethrow;
    }
  }

  // ==================== SEARCH & RANKINGS ====================

  /// Search users by name or sequential ID (prefix match)
  Stream<List<UserModel>> searchUsers(String query) {
    if (query.isEmpty) return Stream.value([]);

    // We search by name (prefix match)
    return _firestore
        .collection(ApiConstants.usersCollection)
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
  }

  /// Get leaderboard data 
  Stream<List<UserModel>> getLeaderboard({required String category, int limit = 20}) {
    String field = category == 'earners' ? 'diamonds' : 'points';
    
    return _firestore
        .collection(ApiConstants.usersCollection)
        .orderBy(field, descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
  }

  // ==================== AVIATOR GAME SYNC & EARNINGS ====================
  /// Stream active viewers with their diamond balances (Host only)
  Stream<List<Map<String, dynamic>>> streamViewerBalances(String streamId, {String context = 'live_stream'}) {
    if (context == 'party_room') {
      // Party rooms don't legally have viewer_sessions, return empty to prevent permission error.
      // We can implement party_room specific logic here later if needed (e.g. tracking room occupants).
      return Stream.value([]);
    }

    return _firestore
        .collection('live_streams')
        .doc(streamId)
        .collection('viewer_sessions')
        .orderBy('joinedAt', descending: true)
        .limit(20) // Only top 20 for performance
        .snapshots()
        .asyncMap((snapshot) async {
          final List<Map<String, dynamic>> viewers = [];
          
          for (var doc in snapshot.docs) {
            final userId = doc.data()['userId'] as String?;
            if (userId == null) continue;

            // Fetch current balance from users collection
            final userDoc = await _firestore.collection(ApiConstants.usersCollection).doc(userId).get();
            if (userDoc.exists) {
              viewers.add({
                'userId': userId,
                'name': doc.data()['name'] ?? 'User',
                'photo': doc.data()['photo'] ?? '',
                'diamonds': userDoc.data()?['diamonds'] ?? 0,
              });
            }
          }
          return viewers;
        });
  }
}
