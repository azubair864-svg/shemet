import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import 'database_service.dart';
import 'device_service.dart';
import 'moment_service.dart';
import 'verification_service.dart';
import 'ip_location_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '351905956852-saocmqn5m29omosp5urmhv5r7mvaqg6i.apps.googleusercontent.com',
  );
  final DatabaseService _databaseService = DatabaseService();

  void _authLog(String message) {
    final n = DateTime.now();
    final ts =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}.${n.millisecond.toString().padLeft(3, '0')}';
    debugPrint('[AUTH_TRACE][$ts][AUTH_SERVICE] $message');
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Standardized Google Sign-In with robust error reporting
  Future<User?> signInWithGoogle() async {
    final sw = Stopwatch()..start();
    _authLog('DEBUG[1]: signInWithGoogle process started');
    
    try {
      // 1. Initial Google Sign In
      _authLog('DEBUG[2]: Attempting _googleSignIn.signIn()...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        _authLog('DEBUG[3]: Google sign-in cancelled by user (googleUser is null)');
        return null;
      }

      _authLog('DEBUG[4]: Google account selected: ${googleUser.email}');

      // 2. Obtain Authentication Details
      _authLog('DEBUG[5]: Attempting googleUser.authentication...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      _authLog('DEBUG[6]: Tokens obtained: idToken=${googleAuth.idToken != null}, accessToken=${googleAuth.accessToken != null}');

      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        _authLog('DEBUG[7]: CRITICAL ERROR: Both tokens are null. Configuration (SHA-1) issue suspected.');
        return null;
      }

      // 3. Create Firebase Credential
      _authLog('DEBUG[8]: Creating Firebase AuthCredential...');
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase
      _authLog('DEBUG[9]: Attempting _auth.signInWithCredential(credential)...');
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null) {
        _authLog('DEBUG[10]: Firebase sign-in failed: userCredential.user is null');
        return null;
      }

      _authLog('DEBUG[11]: Firebase sign-in SUCCESS: uid=${user.uid}');

      // 5. Ensure user document in Firestore
      _authLog('DEBUG[12]: Syncing with Firestore via ensureUserDocument...');
      final docReady = await ensureUserDocument(user);
      _authLog('DEBUG[13]: Firestore sync status: $docReady');

      _authLog('DEBUG[14]: signInWithGoogle COMPLETED SUCCESS elapsed=${sw.elapsedMilliseconds}ms');
      return user;

    } catch (e) {
      String errorMessage = e.toString();
      String errorCode = 'UNKNOWN';
      
      if (e is FirebaseAuthException) {
        errorCode = e.code;
        errorMessage = 'Firebase Auth Error [${e.code}]: ${e.message}';
      } else if (e is PlatformException) {
        final pe = e;
        errorCode = pe.code;
        errorMessage = 'Platform Error [${pe.code}]: ${pe.message} (Details: ${pe.details})';
      }
      
      _authLog('DEBUG[ERROR]: CRITICAL FAILURE IN signInWithGoogle');
      _authLog('DEBUG[ERROR]: Error Code: $errorCode');
      _authLog('DEBUG[ERROR]: Full Message: $errorMessage');
      
      if (errorCode == '10' || errorCode == 'DEVELOPER_ERROR') {
        _authLog('DEBUG[HINT]: SHA-1 Fingerprint is likely missing in Firebase Console.');
      }
      
      return null;
    }
  }

  Future<bool> ensureUserDocument(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userDoc = await docRef.get();
    final localDeviceId = await DeviceService.getUniqueId();

    if (userDoc.exists) {
      _authLog('ensureUserDocument existing doc -> updateLastSeen & sync checks');
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final Map<String, dynamic> updates = {
        'lastDeviceId': localDeviceId,
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      };

      // SYNC 1: Ensure Numeric ID exists for existing users
      try {
        if (userData['id'] == null) {
          _authLog('Syncing: Missing numeric ID detected -> fetching new ID');
          final nextId = await _databaseService.getNextSequenceId();
          updates['id'] = nextId.toString();
          _authLog('Syncing: Numeric ID obtained: ${updates['id']}');
        }
      } catch (e) {
        _authLog('WARNING: Numeric ID sync failed (skipping): $e');
      }
      
      // SYNC 2: Auto-Host logic for females
      try {
        final currentGender = (userData['gender'] as String?)?.toLowerCase();
        if (currentGender == 'female' && userData['isHost'] != true) {
          updates['isHost'] = true;
          _authLog('Syncing: Auto-Host assigned for existing female user');
        }
      } catch (e) {
        _authLog('WARNING: Auto-host sync failed (skipping): $e');
      }

      try {
        debugPrint('[AUTH_DEBUG] 📝 Attempting ensureUserDocument update:');
        debugPrint('[AUTH_DEBUG]    -> UID: ${user.uid}');
        debugPrint('[AUTH_DEBUG]    -> Auth Current UID: ${FirebaseAuth.instance.currentUser?.uid}');
        debugPrint('[AUTH_DEBUG]    -> Updates: $updates');
        await _databaseService.updateUser(user.uid, updates);
        debugPrint('[AUTH_DEBUG] ✅ ensureUserDocument update SUCCESS');
      } catch (e) {
        _authLog('WARNING: Firestore update check failed (likely permissions): $e');
        // Continue anyway as the user is authenticated; real-time listener will handle UI
      }
      return true;
    }

    _authLog('ensureUserDocument missing doc -> create via DatabaseService');
    
    // Auto-detect country for new users
    String detectedCountry = 'Unknown';
    try {
      if (user.phoneNumber != null) {
        final details = IpLocationService.getCountryFromPrefix(user.phoneNumber!);
        if (details != null) detectedCountry = details['name']!;
      }
      if (detectedCountry == 'Unknown') {
        final details = await IpLocationService.detectCountryDetails();
        detectedCountry = details['name']!;
      }
    } catch (e) {
      _authLog('Country detection failed: $e');
    }

    // Generate numeric ID for new user
    final nextId = await _databaseService.getNextSequenceId();

    final initialData = {
      'uid': user.uid,
      'id': nextId.toString(),
      'name': user.displayName ?? 'User',
      'email': user.email ?? '',
      'phoneNumber': user.phoneNumber ?? '',
      'photoURL': user.photoURL ?? '',
      'photos': user.photoURL != null ? [user.photoURL] : <String>[],
      'profileComplete': false,
      'country': detectedCountry,
      'isHost': false, // Will be set to true if/when gender is set to female
      'isVerified': false,
      'isOnline': true,
      'diamonds': 0,
      'points': 0,
      'lastDeviceId': localDeviceId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
    };

    debugPrint('[AUTH_DEBUG] 📝 Attempting ensureUserDocument NEW DOC CREATE/SET:');
    debugPrint('[AUTH_DEBUG]    -> UID: ${user.uid}');
    debugPrint('[AUTH_DEBUG]    -> Payload: $initialData');

    await docRef.set(initialData, SetOptions(merge: true));
    debugPrint('[AUTH_DEBUG] ✅ ensureUserDocument NEW DOC SUCCESS');

    final afterFallback = await docRef.get();
    return afterFallback.exists;
  }

  /// Verifies if the current device is the authorized one for this user.
  /// Should be called on app start/resume.
  Future<bool> verifyDeviceSecurity() async {
    final user = _auth.currentUser;
    if (user == null) return true;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return true;

      final storedDeviceId = userDoc.data()?['lastDeviceId'];
      final localDeviceId = await DeviceService.getUniqueId();

      if (storedDeviceId != null && storedDeviceId != localDeviceId) {
        _authLog('Security Trigger: Device mismatch detected. Force logout.');
        await signOut();
        return false;
      }
      return true;
    } catch (e) {
      _authLog('Error verifying device security: $e');
      return true; // Avoid locking users out on network failure
    }
  }

  // Sign in anonymously - FIXED
  Future<UserCredential?> signInAnonymously() async {
    try {
      // Start listening to auth state changes
      bool signedIn = false;
      String? userId;

      final subscription = _auth.authStateChanges().listen((user) {
        if (user != null && user.isAnonymous) {
          signedIn = true;
          userId = user.uid;
        }
      });

      try {
        // Try to sign in
        await _auth.signInAnonymously();
      } catch (e) {
        // Ignore the error - wait for auth state to change instead
      }

      // Wait for auth state to update (max 3 seconds)

      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (signedIn) break;
      }

      subscription.cancel();

      if (!signedIn || userId == null) {
        return null;
      }

      final user = _auth.currentUser;

      if (user == null) {
        return null;
      }

      // Create user document

      await _createUserInFirestore(user);

      return null; // We don't have UserCredential but user is signed in
    } catch (e) {
    }
    return null;
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final sw = Stopwatch()..start();
    _authLog('email signIn start email=$email');
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _updateLastSeen(userCredential.user!.uid);
      _authLog(
        'email signIn success uid=${userCredential.user?.uid} elapsed=${sw.elapsedMilliseconds}ms',
      );

      return userCredential;
    } catch (e) {
      _authLog(
        'email signIn exception type=${e.runtimeType} error=$e elapsed=${sw.elapsedMilliseconds}ms',
      );
      return null;
    }
  }

  // Login with Nickname - Step 1: Resolve Nickname to Synthetic Email
  Future<UserCredential?> signInWithNicknameAndPassword(
    String nickname,
    String password,
  ) async {
    _authLog('nickname signIn start nickname=$nickname');
    try {
      // 1. Search for user with this name/nickname
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isEqualTo: nickname)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        _authLog('nickname signIn failure: nickname not found');
        return null;
      }

      final userData = snap.docs.first.data();
      String? email = userData['email'] as String?;
      final phoneNumber = userData['phoneNumber'] as String?;

      // 2. If no email, use synthetic email from phone
      if ((email == null || email.isEmpty) && phoneNumber != null) {
        email = getSyntheticEmail(phoneNumber);
      }

      if (email == null || email.isEmpty) {
        _authLog('nickname signIn failure: no email or phone associated');
        return null;
      }

      // 3. Perform standard login
      return await signInWithEmailAndPassword(email, password);
    } catch (e) {
      _authLog('nickname signIn exception: $e');
      return null;
    }
  }

  String getSyntheticEmail(String phoneNumber) {
    // Normalize phone: remove non-digits
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    return '$cleanPhone@shemet.agency';
  }

  // Create user with email and password
  Future<UserCredential?> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final sw = Stopwatch()..start();
    _authLog('email signUp start email=$email');
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _createUserInFirestore(userCredential.user!);
      _authLog(
        'email signUp success uid=${userCredential.user?.uid} elapsed=${sw.elapsedMilliseconds}ms',
      );

      return userCredential;
    } catch (e) {
      _authLog(
        'email signUp exception type=${e.runtimeType} error=$e elapsed=${sw.elapsedMilliseconds}ms',
      );
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    _authLog('signOut start uid=${_auth.currentUser?.uid}');
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      _authLog('signOut success');
    } catch (e) {
      _authLog('signOut exception type=${e.runtimeType} error=$e');
    }
  }

  // Private helper methods
  Future<void> _createUserInFirestore(User user, [String? deviceId]) async {
    _authLog('_createUserInFirestore uid=${user.uid}');
    try {
      final userModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        phoneNumber: user.phoneNumber ?? '',
        name: user.displayName ?? 'User',
        photoURL: user.photoURL,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isOnline: true,
        profileComplete: false,
        lastDeviceId: deviceId, // Pass device ID if available
      );

      await _databaseService.createUser(userModel);
      _authLog('_createUserInFirestore success uid=${user.uid}');
    } catch (e) {
      _authLog(
        '_createUserInFirestore exception type=${e.runtimeType} error=$e',
      );
    }
  }

  Future<void> _updateLastSeen(String userId) async {
    _authLog('_updateLastSeen uid=$userId');
    try {
      await _databaseService.updateUser(userId, {
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      });
      _authLog('_updateLastSeen success uid=$userId');
    } catch (e) {
      _authLog('_updateLastSeen exception type=${e.runtimeType} error=$e');
    }
  }

  // Check if profile is complete
  Future<bool> isProfileComplete() async {
    _authLog('isProfileComplete start currentUid=${_auth.currentUser?.uid}');
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _authLog('isProfileComplete -> false (user null)');
        return false;
      }

      final userModel = await _databaseService.getUserById(user.uid);

      if (userModel == null) {
        _authLog('isProfileComplete -> false (userModel null)');
        return false;
      }

      _authLog('isProfileComplete -> ${userModel.profileComplete}');
      return userModel.profileComplete;
    } catch (e) {
      _authLog('isProfileComplete exception type=${e.runtimeType} error=$e');
      return false;
    }
  }

  // Delete account (Complete Deep Wipe for Compliance)
  Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }
      
      final userId = user.uid;
      _authLog('deleteAccount: Performing deep wipe for uid=$userId');

      // 1. Delete Moments and associated storage (handled by MomentService)
      await MomentService().deleteAllUserMoments(userId);

      // 2. Delete Verification data and storage (handled by VerificationService)
      await VerificationService().deleteUserVerifications(userId);

      // 3. Delete general User Data, Subcollections, and Profile Storage (handled by DatabaseService)
      await _databaseService.deleteUser(userId);

      // 4. Finally delete the Firebase Auth user
      await user.delete();

      _authLog('deleteAccount: Deep wipe and auth deletion success for uid=$userId');
      return true;
    } catch (e) {
      _authLog('deleteAccount: Error during deep wipe or deletion: $e');
      return false;
    }
  }
}
