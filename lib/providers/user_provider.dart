import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class UserProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _userSubscription;

  void _authLog(String message) {
    final n = DateTime.now();
    final ts =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}.${n.millisecond.toString().padLeft(3, '0')}';
    debugPrint('[AUTH_TRACE][$ts][USER_PROVIDER] $message');
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  // Initialize user
  Future<void> initUser() async {
    _authLog('initUser session check start');
    final firebaseUser = _authService.currentUser;
    _authLog('initUser firebaseUid=${firebaseUser?.uid}');

    if (firebaseUser != null) {
      await loadUser(firebaseUser.uid);
    } else {
      _authLog('initUser skipped: firebase user is null');
    }
  }

  // Load user from database
  Future<void> loadUser(String userId) async {
    // If we're already loading this user, don't start again
    if (_isLoading && _currentUser?.uid == userId) return;

    _authLog('loadUser start uid=$userId');
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Cancel existing subscription if any
    await _userSubscription?.cancel();

    _authLog('loadUser start for uid=$userId');
    try {
      // 1. Initial Fetch
      var user = await _databaseService.getUserById(userId);
      _authLog('loadUser db exists=${user != null}');

      if (user == null) {
        _authLog('loadUser missing user doc uid=$userId -> ensure');
        await _ensureUserDocument(userId);
        user = await _databaseService.getUserById(userId);
      }

      if (user != null) {
        _currentUser = user;
        
        // SYNC CHECK: Ensure existing users also get their 8-digit Numeric ID
        if (user.id == null || user.id!.isEmpty) {
          _authLog('loadUser: Numeric ID missing, triggering sync for existing user');
          final fbUser = _authService.currentUser;
          if (fbUser != null) {
            // This will generate the ID and update Firestore; UI will update via listener
            _authService.ensureUserDocument(fbUser);
          }
        }
        _userSubscription = _databaseService.getUserStream(userId).listen((updatedUser) {
          if (updatedUser != null) {
            // Check for changes in critical fields to notify listeners
            bool hasChanged = _currentUser == null || 
                             _currentUser!.diamonds != updatedUser.diamonds ||
                             _currentUser!.earningsBeans != updatedUser.earningsBeans || // Host earnings
                             _currentUser!.points != updatedUser.points ||
                             _currentUser!.callRate != updatedUser.callRate ||           // Video call price
                             _currentUser!.level != updatedUser.level ||                 // User level
                             _currentUser!.name != updatedUser.name ||
                             _currentUser!.photoURL != updatedUser.photoURL ||
                             _currentUser!.isLive != updatedUser.isLive;

            if (hasChanged) {
              _authLog('Real-time update (data changed): UID=${updatedUser.uid}');
              _currentUser = updatedUser;
              notifyListeners();
            }
          }
        });

        // 3. One-time login tasks
        // REMOVED: updateLastSeen(userId) - This triggers a document change which fires the listener,
        // causing a potential build loop if the calling widget isn't careful.
        // Also removed redundant isLive update here to keep loadUser a 'read' operation.
      }
    } catch (e) {
      _error = e.toString();
      _authLog('loadUser exception error=$e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _ensureUserDocument(String userId) async {
    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser == null || firebaseUser.uid != userId) {
        _authLog(
          '_ensureUserDocument skipped firebaseUid=${firebaseUser?.uid} target=$userId',
        );
        return;
      }

      final fallback = _buildFallbackUser(firebaseUser);
      final created = await _databaseService.createUser(fallback);
      _authLog('_ensureUserDocument createUser result=$created uid=$userId');
    } catch (e) {
      _authLog('_ensureUserDocument exception type=${e.runtimeType} error=$e');
    }
  }

  // Trigger a full document sync (used for missing UIDs, etc.)
  Future<void> syncUserDocument() async {
    final fbUser = _authService.currentUser;
    if (fbUser != null) {
      _authLog('syncUserDocument: Manual/Auto trigger for UID sync');
      await _authService.ensureUserDocument(fbUser);
      // UI will update automatically via the Firestore stream in loadUser
    }
  }

  UserModel _buildFallbackUser(User user) {
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      phoneNumber: user.phoneNumber ?? '',
      name: user.displayName ?? 'User',
      photoURL: user.photoURL,
      photos: user.photoURL != null ? [user.photoURL!] : const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isOnline: true,
      profileComplete: false,
    );
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    _authLog('signInWithGoogle start');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle();
      _authLog('signInWithGoogle authService uid=${user?.uid}');

      if (user != null) {
        await loadUser(user.uid);
        _authLog('signInWithGoogle success');
        return true;
      }

      _authLog('signInWithGoogle failed: user null');
      return false;
    } catch (e) {
      _error = e.toString();
      _authLog('signInWithGoogle exception type=${e.runtimeType} error=$e');
      return false;
    } finally {
      _isLoading = false;
      _authLog('signInWithGoogle end isLoggedIn=${_currentUser != null}');
      notifyListeners();
    }
  }

  // Sign out
  Future<void> signOut() async {
    _authLog('signOut start currentUid=${_currentUser?.uid}');
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _currentUser = null;
      _authLog('signOut success');
    } catch (e) {
      _error = e.toString();
      _authLog('signOut exception type=${e.runtimeType} error=$e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user data
  Future<bool> updateUser(Map<String, dynamic> data) async {
    if (_currentUser == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final success = await _databaseService.updateUser(
        _currentUser!.uid,
        data,
      );

      if (success) {
        // Update local state immediately for snappy UI
        _currentUser = _currentUser!.copyWith(
          name: data['name'] ?? _currentUser!.name,
          photoURL: data['photoURL'] ?? _currentUser!.photoURL,
          bio: data['bio'] ?? _currentUser!.bio,
          callRate: data['callRate'] ?? _currentUser!.callRate,
          gender: data['gender'] ?? _currentUser!.gender,
          isHost: data['isHost'] ?? _currentUser!.isHost,
        );
        _authLog('Local state updated after updateUser: ${_currentUser!.uid}');
      }
      return success;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update diamonds
  Future<bool> updateDiamonds(int amount) async {
    if (_currentUser == null) return false;
    try {
      final success = await _databaseService.updateDiamonds(
        _currentUser!.uid,
        amount,
      );
      if (success) {
        setLocalDiamonds(_currentUser!.diamonds + amount);
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  // Update diamonds in memory only
  void setLocalDiamonds(int diamonds) {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(diamonds: diamonds);
    notifyListeners();
  }

  // Deduct diamonds locally (for instant UI feedback)
  void deductDiamondsLocal(int amount) {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(
      diamonds: _currentUser!.diamonds - amount,
    );
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
