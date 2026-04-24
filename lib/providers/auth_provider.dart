import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart'; // NEW

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  void _authLog(String message) {
    final n = DateTime.now();
    final ts =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}.${n.millisecond.toString().padLeft(3, '0')}';
    debugPrint('[AUTH_TRACE][$ts][AUTH_PROVIDER] $message');
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _authLog('init');
    _auth.authStateChanges().listen((User? user) {
      _authLog('authStateChanges uid=${user?.uid} email=${user?.email}');
      _user = user;
      notifyListeners();
    });
  }

  // Get current user
  User? get currentUser {
    return _auth.currentUser;
  }

  // Auth state changes stream
  Stream<User?> get authStateChanges {
    return _auth.authStateChanges();
  }

  // Google Sign In
  Future<bool> signInWithGoogle() async {
    final sw = Stopwatch()..start();
    _authLog('signInWithGoogle start');
    try {
      _isLoading = true;
      _errorMessage = null;

      notifyListeners();

      // Trigger Google Sign In flow

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      _authLog('googleUser=${googleUser?.email ?? "null"}');

      if (googleUser == null) {
        _authLog('google cancelled by user');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Obtain auth details from request

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create credential

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      _authLog('google firebase sign-in uid=${userCredential.user?.uid}');

      // Create user document if new user
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        final authService = AuthService();
        await authService.ensureUserDocument(userCredential.user!); // Use AuthService for sequential IDs
      }

      _user = userCredential.user;
      _isLoading = false;

      notifyListeners();

      _authLog('signInWithGoogle success elapsed=${sw.elapsedMilliseconds}ms');
      return true;
    } catch (e) {
      _authLog(
        'signInWithGoogle exception type=${e.runtimeType} error=$e elapsed=${sw.elapsedMilliseconds}ms',
      );
      _errorMessage = 'Google Sign In Error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Email & Password Sign In
  Future<bool> signInWithEmailPassword(String email, String password) async {
    final sw = Stopwatch()..start();
    _authLog('signInWithEmailPassword start email=$email');
    try {
      _isLoading = true;
      _errorMessage = null;

      notifyListeners();

      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);

      _user = userCredential.user;
      _isLoading = false;

      notifyListeners();

      _authLog(
        'signInWithEmailPassword success uid=${userCredential.user?.uid} elapsed=${sw.elapsedMilliseconds}ms',
      );
      debugPrint('[AUTH_DEBUG] ✅ AuthProvider signIn SUCCESS: ${userCredential.user?.uid}');
      return true;
    } on FirebaseAuthException catch (e) {
      _authLog(
        'signInWithEmailPassword FirebaseAuthException code=${e.code} message=${e.message}',
      );
      if (e.code == 'invalid-credential' ||
          e.code == 'invalid-login-credentials') {
        _errorMessage = 'Invalid email/password or account not found';
      } else {
        _errorMessage = e.message ?? 'Sign in failed (${e.code})';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _authLog(
        'signInWithEmailPassword exception type=${e.runtimeType} error=$e elapsed=${sw.elapsedMilliseconds}ms',
      );
      _errorMessage = 'Sign In Error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Email & Password Sign Up
  Future<bool> signUpWithEmailPassword(
    String email,
    String password,
    String name,
  ) async {
    final sw = Stopwatch()..start();
    _authLog('signUpWithEmailPassword start email=$email name=$name');
    try {
      _isLoading = true;
      _errorMessage = null;

      notifyListeners();

      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Update display name

      await userCredential.user?.updateDisplayName(name);

      // Create user document

      final authService = AuthService();
      await authService.ensureUserDocument(userCredential.user!); // Unified path for sequential IDs

      _user = userCredential.user;
      _isLoading = false;

      notifyListeners();

      _authLog(
        'signUpWithEmailPassword success uid=${userCredential.user?.uid} elapsed=${sw.elapsedMilliseconds}ms',
      );
      return true;
    } on FirebaseAuthException catch (e) {
      _authLog(
        'signUpWithEmailPassword FirebaseAuthException code=${e.code} message=${e.message}',
      );
      _errorMessage = e.message ?? 'Sign up failed (${e.code})';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _authLog(
        'signUpWithEmailPassword exception type=${e.runtimeType} error=$e elapsed=${sw.elapsedMilliseconds}ms',
      );
      _errorMessage = 'Sign Up Error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // REMOVED redundant _createUserDocument - now using DatabaseService via AuthService


  // Sign Out
  Future<void> signOut() async {
    _authLog('signOut start uid=${_auth.currentUser?.uid}');
    try {
      _isLoading = true;

      notifyListeners();

      await _googleSignIn.signOut();

      await _auth.signOut();

      _user = null;
      _isLoading = false;

      notifyListeners();
      _authLog('signOut success');
    } catch (e) {
      _authLog('signOut exception type=${e.runtimeType} error=$e');
      _errorMessage = 'Sign Out Error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset Password
  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _errorMessage = null;

      notifyListeners();

      await _auth.sendPasswordResetEmail(email: email);

      _isLoading = false;

      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = 'Reset Password Error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update User Profile
  Future<bool> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      _isLoading = true;

      notifyListeners();

      if (displayName != null) {
        await _user?.updateDisplayName(displayName);
      }

      if (photoURL != null) {
        await _user?.updatePhotoURL(photoURL);
      }

      await _user?.reload();
      _user = _auth.currentUser;

      _isLoading = false;

      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = 'Update Profile Error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
