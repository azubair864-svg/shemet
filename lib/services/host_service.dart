import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/host_application_model.dart';
import 'notification_service.dart';

class HostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Singleton pattern
  static final HostService _instance = HostService._internal();
  factory HostService() => _instance;
  HostService._internal();

  /// Submit host application
  Future<bool> submitApplication(HostApplicationModel application) async {
    
    
    
    

    try {
      // Save application
      
      await _firestore
          .collection('host_applications')
          .doc(application.applicationId)
          .set(application.toMap());

      

      // Update user document
      
      await _firestore.collection('users').doc(application.userId).update({
        'hasAppliedForHost': true,
        'hostApplicationStatus': 'pending',
        'hostApplicationDate': FieldValue.serverTimestamp(),
      });

      
      

      return true;
    } catch (e) {
      
      
      
      
      return false;
    }
  }

  /// Get pending applications (for admin)
  Future<List<HostApplicationModel>> getPendingApplications({
    int limit = 50,
  }) async {
    
    

    try {
      final snapshot = await _firestore
          .collection('host_applications')
          .where('status', isEqualTo: 'pending')
          .orderBy('submittedAt', descending: true)
          .limit(limit)
          .get();

      

      final applications = snapshot.docs
          .map((doc) => HostApplicationModel.fromSnapshot(doc))
          .toList();

      
      

      return applications;
    } catch (e) {
      
      
      
      
      return [];
    }
  }

  /// Get all applications with optional status filter
  Future<List<HostApplicationModel>> getApplications({
    String? status,
    int limit = 100,
  }) async {
    
    
    

    try {
      Query query = _firestore
          .collection('host_applications')
          .orderBy('submittedAt', descending: true)
          .limit(limit);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
        
      }

      final snapshot = await query.get();
      

      final applications = snapshot.docs
          .map((doc) => HostApplicationModel.fromSnapshot(doc))
          .toList();

      // Calculate statistics
      if (status == null) {
        final pending = applications.where((app) => app.status == 'pending').length;
        final approved = applications.where((app) => app.status == 'approved').length;
        final rejected = applications.where((app) => app.status == 'rejected').length;

        
        
        
        
      }

      
      

      return applications;
    } catch (e) {
      
      
      
      
      return [];
    }
  }

  /// Get application by user ID
  Future<HostApplicationModel?> getApplicationByUserId(String userId) async {
    
    

    try {
      final snapshot = await _firestore
          .collection('host_applications')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        
        
        return null;
      }

      final application = HostApplicationModel.fromSnapshot(snapshot.docs.first);
      
      
      

      return application;
    } catch (e) {
      
      
      
      
      return null;
    }
  }

  /// Approve host application
  Future<bool> approveApplication({
    required String applicationId,
    required String adminId,
    String? reviewNotes,
  }) async {
    
    
    
    

    try {
      // Get application
      
      final appDoc = await _firestore
          .collection('host_applications')
          .doc(applicationId)
          .get();

      if (!appDoc.exists) {
        
        return false;
      }

      final application = HostApplicationModel.fromSnapshot(appDoc);
      

      // Update application status
      
      await _firestore
          .collection('host_applications')
          .doc(applicationId)
          .update({
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminId,
        'reviewNotes': reviewNotes,
      });

      

      // Update user document
      
      await _firestore.collection('users').doc(application.userId).update({
        'isHost': true,
        'hostApplicationStatus': 'approved',
        'becameHostAt': FieldValue.serverTimestamp(),
      });

      

      // Send notification
      
      // TODO: Send notification to user
      // await _notificationService.sendNotification(...);

      

      return true;
    } catch (e) {
      
      
      
      
      return false;
    }
  }

  /// Reject host application
  Future<bool> rejectApplication({
    required String applicationId,
    required String adminId,
    required String rejectionReason,
    String? reviewNotes,
  }) async {
    
    
    
    

    try {
      // Get application
      
      final appDoc = await _firestore
          .collection('host_applications')
          .doc(applicationId)
          .get();

      if (!appDoc.exists) {
        
        return false;
      }

      final application = HostApplicationModel.fromSnapshot(appDoc);
      

      // Update application status
      
      await _firestore
          .collection('host_applications')
          .doc(applicationId)
          .update({
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminId,
        'reviewNotes': reviewNotes,
        'rejectionReason': rejectionReason,
      });

      

      // Update user document
      
      await _firestore.collection('users').doc(application.userId).update({
        'hostApplicationStatus': 'rejected',
      });

      

      // Send notification
      
      // TODO: Send notification to user
      // await _notificationService.sendNotification(...);

      

      return true;
    } catch (e) {
      
      
      
      
      return false;
    }
  }

  /// Remove host status
  Future<bool> removeHostStatus({
    required String userId,
    required String adminId,
    required String reason,
  }) async {
    
    
    
    

    try {
      // Update user document
      
      await _firestore.collection('users').doc(userId).update({
        'isHost': false,
        'hostRemovedAt': FieldValue.serverTimestamp(),
        'hostRemovalReason': reason,
        'hostRemovedBy': adminId,
      });

      

      // Log the action
      
      await _firestore.collection('host_removals').add({
        'userId': userId,
        'adminId': adminId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });

      

      // Send notification
      
      // TODO: Send notification to user
      // await _notificationService.sendNotification(...);

      

      return true;
    } catch (e) {
      
      
      
      
      return false;
    }
  }

  /// Get host statistics
  Future<Map<String, dynamic>> getHostStatistics() async {
    

    try {
      // Get all applications
      final allApps = await _firestore
          .collection('host_applications')
          .get();

      // Get active hosts
      final hostsSnapshot = await _firestore
          .collection('users')
          .where('isHost', isEqualTo: true)
          .get();

      final totalApplications = allApps.docs.length;
      final pendingApplications = allApps.docs
          .where((doc) => doc.data()['status'] == 'pending')
          .length;
      final approvedApplications = allApps.docs
          .where((doc) => doc.data()['status'] == 'approved')
          .length;
      final rejectedApplications = allApps.docs
          .where((doc) => doc.data()['status'] == 'rejected')
          .length;
      final activeHosts = hostsSnapshot.docs.length;

      final statistics = {
        'totalApplications': totalApplications,
        'pendingApplications': pendingApplications,
        'approvedApplications': approvedApplications,
        'rejectedApplications': rejectedApplications,
        'activeHosts': activeHosts,
        'approvalRate': totalApplications > 0
            ? (approvedApplications / totalApplications * 100).toStringAsFixed(1)
            : '0.0',
      };

      
      
      
      
      
      
      

      
      

      return statistics;
    } catch (e) {
      
      
      
      
      return {
        'totalApplications': 0,
        'pendingApplications': 0,
        'approvedApplications': 0,
        'rejectedApplications': 0,
        'activeHosts': 0,
        'approvalRate': '0.0',
      };
    }
  }

  /// Check if user is a host
  Future<bool> isHost(String userId) async {
    
    

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        
        return false;
      }

      final isHost = userDoc.data()?['isHost'] ?? false;
      
      

      return isHost;
    } catch (e) {
      
      
      
      
      return false;
    }
  }

  /// Get all active hosts
  Future<List<Map<String, dynamic>>> getActiveHosts({
    int limit = 50,
  }) async {
    
    

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('isHost', isEqualTo: true)
          .limit(limit)
          .get();

      

      final hosts = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      
      

      return hosts;
    } catch (e) {
      
      
      
      
      return [];
    }
  }

  /// Delete application
  Future<bool> deleteApplication(String applicationId) async {
    
    

    try {
      await _firestore
          .collection('host_applications')
          .doc(applicationId)
          .delete();

      
      

      return true;
    } catch (e) {
      
      
      
      
      return false;
    }
  }
}
