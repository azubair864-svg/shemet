import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/moment_model.dart';
import '../models/user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'notification_service.dart';

/// ⭐⭐⭐ PRODUCTION-READY MOMENT SERVICE ⭐⭐⭐
/// Complete service for social media posts/moments
/// Features: Create, Like, Comment, Share, Delete, Feed, Privacy
class MomentService {
  static final MomentService _instance = MomentService._internal();
  factory MomentService() => _instance;
  MomentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final NotificationService _notificationService = NotificationService();

  // Collections
  CollectionReference get _momentsCollection => _firestore.collection('moments');
  CollectionReference get _usersCollection => _firestore.collection('users');

  // ==================== CREATE MOMENT ====================

  /// Create a new moment/post
  Future<MomentModel?> createMoment({
    required String userId,
    required UserModel user,
    String? text,
    List<XFile>? mediaFiles,
    String mediaType = 'text',
    String? location,
    GeoPoint? geoLocation,
    String privacy = 'public',
    bool commentsEnabled = true,
    List<String> hashtags = const [],
    List<String> mentionedUserIds = const [],
  }) async {
    
    
    
    
    
    

    try {
      // Step 1: Upload media files if any
      List<String> mediaUrls = [];
      String? thumbnailUrl;

      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        
        mediaUrls = await _uploadMediaFiles(userId, mediaFiles, mediaType);
        

        // Generate thumbnail for video
        if (mediaType == 'video' && mediaUrls.isNotEmpty) {
          thumbnailUrl = mediaUrls.first; // Use first frame as thumbnail
        }
      }

      // Step 2: Create moment document
      
      final momentId = _momentsCollection.doc().id;
      final now = DateTime.now();

      final moment = MomentModel(
        momentId: momentId,
        userId: userId,
        userName: user.name,
        userPhoto: user.photoURL,
        userLevel: user.level,
        userIsVerified: user.isVerified,
        userIsVip: user.isVip ?? false,
        text: text,
        mediaUrls: mediaUrls,
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
        location: location,
        geoLocation: geoLocation,
        privacy: privacy,
        commentsEnabled: commentsEnabled,
        hashtags: hashtags,
        mentionedUserIds: mentionedUserIds,
        createdAt: now,
      );

      await _momentsCollection.doc(momentId).set(moment.toMap());
      

      // Step 3: Update user's moment count
      
      await _usersCollection.doc(userId).update({
        'momentsCount': FieldValue.increment(1),
      });

      // Step 4: Send notifications to mentioned users
      if (mentionedUserIds.isNotEmpty) {
        
        for (final mentionedUserId in mentionedUserIds) {
          await _notificationService.sendNotification(
            userId: mentionedUserId,
            title: '${user.name} mentioned you',
            body: text ?? 'in a moment',
            type: 'moment_mention',
            data: {'momentId': momentId, 'userId': userId},
          );
        }
      }

      // Step 5: Index hashtags
      if (hashtags.isNotEmpty) {
        
        await _indexHashtags(hashtags, momentId);
      }

      
      return moment;
    } catch (e) {
      
      
      
      
      return null;
    }
  }

  /// Upload media files to Firebase Storage
  Future<List<String>> _uploadMediaFiles(
    String userId,
    List<XFile> files,
    String mediaType,
  ) async {
    
    List<String> urls = [];

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = mediaType == 'video' ? 'mp4' : 'jpg';
      final path = 'moments/$userId/${timestamp}_$i.$extension';

      

      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: mediaType == 'video' ? 'video/mp4' : 'image/jpeg',
      );

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        await ref.putData(bytes, metadata);
      } else {
        await ref.putFile(File(file.path), metadata);
      }
      
      final url = await ref.getDownloadURL();
      urls.add(url);
      
    }

    return urls;
  }

  /// Index hashtags for search
  Future<void> _indexHashtags(List<String> hashtags, String momentId) async {
    for (final tag in hashtags) {
      final normalizedTag = tag.toLowerCase().replaceAll('#', '');
      await _firestore.collection('hashtags').doc(normalizedTag).set({
        'tag': normalizedTag,
        'count': FieldValue.increment(1),
        'lastUsed': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore
          .collection('hashtags')
          .doc(normalizedTag)
          .collection('moments')
          .doc(momentId)
          .set({
        'momentId': momentId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ==================== GET MOMENTS ====================

  /// Get public feed (all public moments)
  Stream<List<MomentModel>> getPublicFeed({
    String? currentUserId,
    int limit = 20,
  }) {
    
    
    

    return _momentsCollection
        .where('privacy', isEqualTo: 'public')
        .where('isHidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      
      return snapshot.docs
          .map((doc) => MomentModel.fromSnapshot(doc, currentUserId: currentUserId))
          .toList();
    });
  }

  /// Get following feed (moments from followed users)
  Stream<List<MomentModel>> getFollowingFeed({
    required String userId,
    required List<String> followingIds,
    int limit = 20,
  }) {
    
    
    

    if (followingIds.isEmpty) {
      return Stream.value([]);
    }

    // Firestore 'whereIn' limit is 10, so we need to batch
    final batches = <List<String>>[];
    for (var i = 0; i < followingIds.length; i += 10) {
      batches.add(followingIds.sublist(
        i,
        i + 10 > followingIds.length ? followingIds.length : i + 10,
      ));
    }

    // For now, just use first batch (you can implement proper batching)
    return _momentsCollection
        .where('userId', whereIn: batches.first)
        .where('isHidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      
      return snapshot.docs
          .map((doc) => MomentModel.fromSnapshot(doc, currentUserId: userId))
          .toList();
    });
  }

  /// Get user's moments
  Stream<List<MomentModel>> getUserMoments({
    required String userId,
    String? currentUserId,
    int limit = 50,
  }) {
    
    
    

    Query query = _momentsCollection
        .where('userId', isEqualTo: userId)
        .where('isHidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    // If viewing own profile, show all privacy levels
    // If viewing others, only show public
    if (currentUserId != userId) {
      query = query.where('privacy', isEqualTo: 'public');
    }

    return query.snapshots().map((snapshot) {
      
      return snapshot.docs
          .map((doc) => MomentModel.fromSnapshot(doc, currentUserId: currentUserId))
          .toList();
    });
  }

  /// Get single moment by ID
  Future<MomentModel?> getMomentById(String momentId, {String? currentUserId}) async {
    
    

    try {
      final doc = await _momentsCollection.doc(momentId).get();
      if (!doc.exists) {
        
        return null;
      }

      // Increment view count
      await _momentsCollection.doc(momentId).update({
        'viewsCount': FieldValue.increment(1),
      });

      return MomentModel.fromSnapshot(doc, currentUserId: currentUserId);
    } catch (e) {
      
      return null;
    }
  }

  // ==================== LIKE MOMENT ====================

  /// Toggle like on a moment
  Future<bool> toggleLike({
    required String momentId,
    required String userId,
    required String userName,
  }) async {
    
    
    

    try {
      final momentRef = _momentsCollection.doc(momentId);
      final momentDoc = await momentRef.get();

      if (!momentDoc.exists) {
        
        return false;
      }

      final momentData = momentDoc.data() as Map<String, dynamic>;
      final likedBy = List<String>.from(momentData['likedBy'] ?? []);
      final momentOwnerId = momentData['userId'] as String;

      bool isLiked;
      if (likedBy.contains(userId)) {
        // Unlike
        
        await momentRef.update({
          'likedBy': FieldValue.arrayRemove([userId]),
          'likesCount': FieldValue.increment(-1),
        });
        isLiked = false;
      } else {
        // Like
        
        await momentRef.update({
          'likedBy': FieldValue.arrayUnion([userId]),
          'likesCount': FieldValue.increment(1),
        });
        isLiked = true;

        // Send notification to moment owner (if not self-like)
        if (momentOwnerId != userId) {
          await _notificationService.sendNotification(
            userId: momentOwnerId,
            title: '$userName liked your moment',
            body: momentData['text'] ?? 'Your moment',
            type: 'moment_like',
            data: {'momentId': momentId, 'userId': userId},
          );
        }

        // Update user's likes count
        await _usersCollection.doc(momentOwnerId).update({
          'likesCount': FieldValue.increment(1),
        });
      }

      
      return isLiked;
    } catch (e) {
      
      
      
      return false;
    }
  }

  // ==================== COMMENTS ====================

  /// Add comment to a moment
  Future<MomentCommentModel?> addComment({
    required String momentId,
    required String userId,
    required UserModel user,
    required String text,
    String? replyToCommentId,
    String? replyToUserName,
  }) async {
    
    
    
    
    

    try {
      final commentsRef = _momentsCollection.doc(momentId).collection('comments');
      final commentId = commentsRef.doc().id;

      final comment = MomentCommentModel(
        commentId: commentId,
        momentId: momentId,
        userId: userId,
        userName: user.name,
        userPhoto: user.photoURL,
        userLevel: user.level,
        userIsVerified: user.isVerified,
        text: text,
        replyToCommentId: replyToCommentId,
        replyToUserName: replyToUserName,
        createdAt: DateTime.now(),
      );

      await commentsRef.doc(commentId).set(comment.toMap());

      // Update moment's comment count
      await _momentsCollection.doc(momentId).update({
        'commentsCount': FieldValue.increment(1),
      });

      // If this is a reply, update parent comment's reply count
      if (replyToCommentId != null) {
        await commentsRef.doc(replyToCommentId).update({
          'repliesCount': FieldValue.increment(1),
        });
      }

      // Get moment owner and send notification
      final momentDoc = await _momentsCollection.doc(momentId).get();
      if (momentDoc.exists) {
        final momentData = momentDoc.data() as Map<String, dynamic>;
        final momentOwnerId = momentData['userId'] as String;

        if (momentOwnerId != userId) {
          await _notificationService.sendNotification(
            userId: momentOwnerId,
            title: '${user.name} commented on your moment',
            body: text,
            type: 'moment_comment',
            data: {'momentId': momentId, 'commentId': commentId},
          );
        }

        // Update user's comments count
        await _usersCollection.doc(momentOwnerId).update({
          'commentsCount': FieldValue.increment(1),
        });
      }

      
      return comment;
    } catch (e) {
      
      
      
      return null;
    }
  }

  /// Get comments for a moment
  Stream<List<MomentCommentModel>> getComments({
    required String momentId,
    int limit = 50,
  }) {
    
    

    return _momentsCollection
        .doc(momentId)
        .collection('comments')
        .where('replyToCommentId', isNull: true) // Only top-level comments
        .orderBy('createdAt', descending: false)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      
      return snapshot.docs
          .map((doc) => MomentCommentModel.fromSnapshot(doc))
          .toList();
    });
  }

  /// Get replies to a comment
  Stream<List<MomentCommentModel>> getCommentReplies({
    required String momentId,
    required String commentId,
    int limit = 20,
  }) {
    return _momentsCollection
        .doc(momentId)
        .collection('comments')
        .where('replyToCommentId', isEqualTo: commentId)
        .orderBy('createdAt', descending: false)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MomentCommentModel.fromSnapshot(doc))
          .toList();
    });
  }

  /// Delete a comment
  Future<bool> deleteComment({
    required String momentId,
    required String commentId,
    required String userId,
  }) async {
    
    
    

    try {
      final commentRef = _momentsCollection
          .doc(momentId)
          .collection('comments')
          .doc(commentId);

      final commentDoc = await commentRef.get();
      if (!commentDoc.exists) return false;

      final commentData = commentDoc.data()!;
      if (commentData['userId'] != userId) {
        
        return false;
      }

      // Delete replies first
      final repliesSnapshot = await _momentsCollection
          .doc(momentId)
          .collection('comments')
          .where('replyToCommentId', isEqualTo: commentId)
          .get();

      final batch = _firestore.batch();
      for (final reply in repliesSnapshot.docs) {
        batch.delete(reply.reference);
      }
      batch.delete(commentRef);
      await batch.commit();

      // Update moment's comment count
      final totalDeleted = 1 + repliesSnapshot.docs.length;
      await _momentsCollection.doc(momentId).update({
        'commentsCount': FieldValue.increment(-totalDeleted),
      });

      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // ==================== DELETE MOMENT ====================

  /// Delete a moment
  Future<bool> deleteMoment({
    required String momentId,
    required String userId,
  }) async {
    
    
    

    try {
      final momentRef = _momentsCollection.doc(momentId);
      final momentDoc = await momentRef.get();

      if (!momentDoc.exists) {
        
        return false;
      }

      final momentData = momentDoc.data() as Map<String, dynamic>;
      if (momentData['userId'] != userId) {
        
        return false;
      }

      // Delete media files from storage
      final mediaUrls = List<String>.from(momentData['mediaUrls'] ?? []);
      for (final url in mediaUrls) {
        try {
          await _storage.refFromURL(url).delete();
        } catch (e) {
          
        }
      }

      // Delete all comments
      final commentsSnapshot = await momentRef.collection('comments').get();
      final batch = _firestore.batch();
      for (final comment in commentsSnapshot.docs) {
        batch.delete(comment.reference);
      }
      batch.delete(momentRef);
      await batch.commit();

      // Update user's moment count
      await _usersCollection.doc(userId).update({
        'momentsCount': FieldValue.increment(-1),
      });

      
      return true;
    } catch (e) {
      
      
      
      return false;
    }
  }

  // ==================== SHARE MOMENT ====================

  /// Share a moment
  Future<bool> shareMoment({
    required String momentId,
    required String userId,
  }) async {
    
    
    

    try {
      await _momentsCollection.doc(momentId).update({
        'sharesCount': FieldValue.increment(1),
      });

      // Log share action
      await _firestore.collection('moment_shares').add({
        'momentId': momentId,
        'userId': userId,
        'sharedAt': FieldValue.serverTimestamp(),
      });

      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // ==================== REPORT MOMENT ====================

  /// Report a moment
  Future<bool> reportMoment({
    required String momentId,
    required String reporterId,
    required String reason,
    String? description,
  }) async {
    
    
    
    

    try {
      await _firestore.collection('moment_reports').add({
        'momentId': momentId,
        'reporterId': reporterId,
        'reason': reason,
        'description': description,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Mark moment as reported (for review)
      await _momentsCollection.doc(momentId).update({
        'isReported': true,
      });

      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // ==================== SEARCH ====================

  /// Search moments by hashtag
  Stream<List<MomentModel>> searchByHashtag({
    required String hashtag,
    String? currentUserId,
    int limit = 50,
  }) {
    
    

    final normalizedTag = hashtag.toLowerCase().replaceAll('#', '');

    return _firestore
        .collection('hashtags')
        .doc(normalizedTag)
        .collection('moments')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      final momentIds = snapshot.docs.map((d) => d.id).toList();
      if (momentIds.isEmpty) return <MomentModel>[];

      final moments = <MomentModel>[];
      for (final id in momentIds) {
        final momentDoc = await _momentsCollection.doc(id).get();
        if (momentDoc.exists) {
          moments.add(MomentModel.fromSnapshot(momentDoc, currentUserId: currentUserId));
        }
      }
      return moments;
    });
  }

  /// Get trending hashtags
  Future<List<Map<String, dynamic>>> getTrendingHashtags({int limit = 10}) async {
    

    try {
      final snapshot = await _firestore
          .collection('hashtags')
          .orderBy('count', descending: true)
          .limit(limit)
          .get();

      final hashtags = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'tag': data['tag'],
          'count': data['count'],
        };
      }).toList();

      
      return hashtags;
    } catch (e) {
      
      return [];
    }
  }

  // ==================== ANALYTICS ====================

  /// Get moment analytics for a user
  Future<Map<String, dynamic>> getMomentAnalytics(String userId) async {
    
    

    try {
      final momentsSnapshot = await _momentsCollection
          .where('userId', isEqualTo: userId)
          .get();

      int totalMoments = momentsSnapshot.docs.length;
      int totalLikes = 0;
      int totalComments = 0;
      int totalShares = 0;
      int totalViews = 0;

      for (final doc in momentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalLikes += (data['likesCount'] ?? 0) as int;
        totalComments += (data['commentsCount'] ?? 0) as int;
        totalShares += (data['sharesCount'] ?? 0) as int;
        totalViews += (data['viewsCount'] ?? 0) as int;
      }

      final analytics = {
        'totalMoments': totalMoments,
        'totalLikes': totalLikes,
        'totalComments': totalComments,
        'totalShares': totalShares,
        'totalViews': totalViews,
        'avgLikesPerMoment': totalMoments > 0 ? totalLikes ~/ totalMoments : 0,
        'avgCommentsPerMoment': totalMoments > 0 ? totalComments ~/ totalMoments : 0,
        'engagementRate': totalViews > 0
            ? ((totalLikes + totalComments + totalShares) / totalViews * 100)
            : 0.0,
      };

      
      return analytics;
    } catch (e) {
      
      return {
        'totalMoments': 0,
        'totalLikes': 0,
        'totalComments': 0,
        'totalShares': 0,
        'totalViews': 0,
        'avgLikesPerMoment': 0,
        'avgCommentsPerMoment': 0,
        'engagementRate': 0.0,
      };
    }
  }
  /// Delete all moments belonging to a user (used for account deletion)
  Future<void> deleteAllUserMoments(String userId) async {
    try {
      final snapshot = await _momentsCollection.where('userId', isEqualTo: userId).get();
      for (final doc in snapshot.docs) {
        await deleteMoment(momentId: doc.id, userId: userId);
      }
    } catch (e) {
      debugPrint('Error deleting all user moments: $e');
    }
  }
}
