import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'database_service.dart';
import 'notification_service.dart';

/// ⭐⭐⭐ PRODUCTION-READY VIDEO VERIFICATION SERVICE ⭐⭐⭐
/// Handles user identity verification via video selfie
/// Features: Video upload, Verification requests, Admin approval, Status tracking
class VerificationService {
  static final VerificationService _instance = VerificationService._internal();
  factory VerificationService() => _instance;
  VerificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  // Collections
  CollectionReference get _verificationsCollection =>
      _firestore.collection('verifications');
  CollectionReference get _usersCollection => _firestore.collection('users');

  // ==================== VERIFICATION REQUEST ====================

  /// Submit a verification request with video
  Future<String?> submitVerificationRequest({
    required String userId,
    required String userName,
    required String videoPath,
    String? selfieImagePath,
    String? idDocumentPath,
    Uint8List? videoBytes,
    Uint8List? selfieBytes,
    Uint8List? idDocumentBytes,
  }) async {
    
    
    

    try {
      // Check if user already has a pending verification
      final existing = await _verificationsCollection
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existing.docs.isNotEmpty) {
        
        return null;
      }

      // Generate verification ID
      final verificationId = _verificationsCollection.doc().id;
      

      // Upload video
      
      final videoUrl = await _uploadFile(
        userId: userId,
        filePath: videoPath,
        type: 'video',
        verificationId: verificationId,
        webBytes: videoBytes,
      );

      if (videoUrl == null) {
        
        return null;
      }
      

      // Upload selfie image if provided
      String? selfieUrl;
      if (selfieImagePath != null) {
        
        selfieUrl = await _uploadFile(
          userId: userId,
          filePath: selfieImagePath,
          type: 'selfie',
          verificationId: verificationId,
          webBytes: selfieBytes,
        );
        
      }

      // Upload ID document if provided
      String? idDocumentUrl;
      if (idDocumentPath != null) {
        
        idDocumentUrl = await _uploadFile(
          userId: userId,
          filePath: idDocumentPath,
          type: 'id_document',
          verificationId: verificationId,
          webBytes: idDocumentBytes,
        );
        
      }

      // Create verification request document
      final verificationData = {
        'verificationId': verificationId,
        'userId': userId,
        'userName': userName,
        'videoUrl': videoUrl,
        'selfieUrl': selfieUrl,
        'idDocumentUrl': idDocumentUrl,
        'status': 'pending', // pending, approved, rejected, needs_resubmission
        'submittedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewedBy': null,
        'rejectionReason': null,
        'verificationScore': null,
        'notes': null,
        'attemptNumber': await _getAttemptNumber(userId),
      };

      await _verificationsCollection.doc(verificationId).set(verificationData);
      

      // Update user's verification status
      await _databaseService.updateUser(userId, {
        'verificationStatus': 'pending',
        'lastVerificationAttempt': FieldValue.serverTimestamp(),
      });

      
      return verificationId;
    } catch (e) {
      
      
      
      
      return null;
    }
  }

  /// Upload verification file to Firebase Storage
  Future<String?> _uploadFile({
    required String userId,
    required String verificationId,
    required String filePath,
    required String type,
    Uint8List? webBytes,
  }) async {
    

    try {
      final extension = filePath.contains('.') ? filePath.split('.').last : 'jpg';
      final ref = _storage.ref().child(
            'verifications/$userId/$verificationId/${type}_${DateTime.now().millisecondsSinceEpoch}.$extension',
          );

      if (kIsWeb && webBytes != null) {
        await ref.putData(webBytes);
      } else {
        final file = File(filePath);
        if (!await file.exists()) return null;
        await ref.putFile(file);
      }
      
      final downloadUrl = await ref.getDownloadURL();

      
      return downloadUrl;
    } catch (e) {
      
      return null;
    }
  }

  /// Get the number of verification attempts by user
  Future<int> _getAttemptNumber(String userId) async {
    final attempts = await _verificationsCollection
        .where('userId', isEqualTo: userId)
        .get();
    return attempts.docs.length + 1;
  }

  // ==================== VERIFICATION STATUS ====================

  /// Get verification status for a user
  Future<Map<String, dynamic>?> getVerificationStatus(String userId) async {
    
    

    try {
      // Get the latest verification request
      final snapshot = await _verificationsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('submittedAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        
        return null;
      }

      final data = snapshot.docs.first.data() as Map<String, dynamic>;
      
      

      return data;
    } catch (e) {
      
      return null;
    }
  }

  /// Stream verification status updates
  Stream<Map<String, dynamic>?> streamVerificationStatus(String userId) {
    return _verificationsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('submittedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.data() as Map<String, dynamic>;
    });
  }

  /// Check if user is verified
  Future<bool> isUserVerified(String userId) async {
    

    try {
      final userDoc = await _usersCollection.doc(userId).get();
      if (!userDoc.exists) return false;

      final data = userDoc.data() as Map<String, dynamic>;
      final isVerified = data['isVerified'] ?? false;

      
      return isVerified;
    } catch (e) {
      
      return false;
    }
  }

  // ==================== ADMIN FUNCTIONS ====================

  /// Get all pending verification requests (for admin)
  Stream<List<Map<String, dynamic>>> getPendingVerifications() {
    

    return _verificationsCollection
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: false)
        .snapshots()
        .map((snapshot) {
      
      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    });
  }

  /// Approve verification request (admin function)
  Future<bool> approveVerification({
    required String verificationId,
    required String adminId,
    int? verificationScore,
    String? notes,
  }) async {
    
    
    

    try {
      // Get verification details
      final verificationDoc =
          await _verificationsCollection.doc(verificationId).get();
      if (!verificationDoc.exists) {
        
        return false;
      }

      final verificationData = verificationDoc.data() as Map<String, dynamic>;
      final userId = verificationData['userId'] as String;
      final userName = verificationData['userName'] as String?;

      // Update verification status
      await _verificationsCollection.doc(verificationId).update({
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminId,
        'verificationScore': verificationScore ?? 100,
        'notes': notes,
      });

      // Update user as verified
      await _databaseService.updateUser(userId, {
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verificationStatus': 'verified',
      });

      // Send notification to user
      await _notificationService.sendNotification(
        userId: userId,
        title: 'Verification Approved!',
        body: 'Congratulations! Your profile has been verified.',
        type: 'verification_approved',
      );

      
      
      return true;
    } catch (e) {
      
      
      
      
      return false;
    }
  }

  /// Reject verification request (admin function)
  Future<bool> rejectVerification({
    required String verificationId,
    required String adminId,
    required String rejectionReason,
    String? notes,
    bool allowResubmission = true,
  }) async {
    
    
    

    try {
      // Get verification details
      final verificationDoc =
          await _verificationsCollection.doc(verificationId).get();
      if (!verificationDoc.exists) {
        
        return false;
      }

      final verificationData = verificationDoc.data() as Map<String, dynamic>;
      final userId = verificationData['userId'] as String;

      // Update verification status
      await _verificationsCollection.doc(verificationId).update({
        'status': allowResubmission ? 'needs_resubmission' : 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminId,
        'rejectionReason': rejectionReason,
        'notes': notes,
      });

      // Update user's verification status
      await _databaseService.updateUser(userId, {
        'verificationStatus':
            allowResubmission ? 'needs_resubmission' : 'rejected',
      });

      // Send notification to user
      await _notificationService.sendNotification(
        userId: userId,
        title: 'Verification Update',
        body: allowResubmission
            ? 'Your verification needs some updates. Please resubmit.'
            : 'Your verification request was not approved.',
        type: 'verification_rejected',
        data: {'reason': rejectionReason},
      );

      
      
      return true;
    } catch (e) {
      
      
      
      
      return false;
    }
  }

  // ==================== VERIFICATION GUIDELINES ====================

  /// Get verification guidelines/instructions
  Map<String, dynamic> getVerificationGuidelines() {
    return {
      'videoRequirements': {
        'duration': '5-15 seconds',
        'format': 'MP4, MOV',
        'instructions': [
          'Record in a well-lit area',
          'Show your face clearly',
          'Follow the on-screen prompts',
          'Hold a piece of paper with your username written on it',
          'Say your name out loud',
        ],
      },
      'selfieRequirements': {
        'format': 'JPG, PNG',
        'instructions': [
          'Take a clear photo of your face',
          'Make sure your face is fully visible',
          'Remove sunglasses and hats',
          'Use natural lighting',
        ],
      },
      'idDocumentRequirements': {
        'acceptedTypes': [
          'National ID Card',
          'Passport',
          'Driver\'s License',
        ],
        'instructions': [
          'Take a photo of your ID document',
          'Make sure all text is readable',
          'All corners should be visible',
          'Avoid glare and shadows',
        ],
      },
      'processingTime': '24-48 hours',
      'benefits': [
        'Verified badge on profile',
        'Higher visibility in search',
        'Access to premium features',
        'Increased trust from other users',
      ],
    };
  }

  // ==================== VERIFICATION PROMPTS ====================

  /// Get random verification prompts for video recording
  List<String> getVerificationPrompts() {
    return [
      'Please say "Hello, I am [your name]"',
      'Turn your head slowly left, then right',
      'Blink twice',
      'Show the paper with your username written on it',
      'Wave at the camera',
    ];
  }

  /// Get a specific verification prompt by index
  String getPrompt(int index) {
    final prompts = getVerificationPrompts();
    if (index >= 0 && index < prompts.length) {
      return prompts[index];
    }
    return prompts[0];
  }

  // ==================== VERIFICATION STATISTICS ====================

  /// Get verification statistics (for admin dashboard)
  Future<Map<String, dynamic>> getVerificationStats() async {
    

    try {
      final pendingCount = await _verificationsCollection
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      final approvedCount = await _verificationsCollection
          .where('status', isEqualTo: 'approved')
          .count()
          .get();

      final rejectedCount = await _verificationsCollection
          .where('status', isEqualTo: 'rejected')
          .count()
          .get();

      final needsResubmissionCount = await _verificationsCollection
          .where('status', isEqualTo: 'needs_resubmission')
          .count()
          .get();

      final stats = {
        'pending': pendingCount.count,
        'approved': approvedCount.count,
        'rejected': rejectedCount.count,
        'needsResubmission': needsResubmissionCount.count,
        'total': (pendingCount.count ?? 0) +
            (approvedCount.count ?? 0) +
            (rejectedCount.count ?? 0) +
            (needsResubmissionCount.count ?? 0),
      };

      
      

      return stats;
    } catch (e) {
      
      return {};
    }
  }

  // ==================== CLEANUP ====================

  /// Delete verification data for a user (for account deletion)
  Future<void> deleteUserVerifications(String userId) async {
    
    

    try {
      // Get all verifications for user
      final verifications = await _verificationsCollection
          .where('userId', isEqualTo: userId)
          .get();

      // Delete verification documents
      for (final doc in verifications.docs) {
        await doc.reference.delete();
      }

      // Delete verification files from storage
      try {
        final storageRef = _storage.ref().child('verifications/$userId');
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
        
      }

      
    } catch (e) {
      
    }
  }
}
