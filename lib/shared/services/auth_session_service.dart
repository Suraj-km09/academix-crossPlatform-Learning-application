import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/firestore_paths.dart';
import 'local_json_cache_service.dart';

class AuthSessionService {
  AuthSessionService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _sessionUidKey = 'auth_session_uid';
  static const String _sessionIdKey = 'auth_session_id';
  static const String _logoutAlertKey = 'pending_logout_alert';
  static const String _sessionConflictAlertMessage =
      'Your account is logged in on another device. Please sign in again.';
  static const Duration _sessionValidationInterval = Duration(seconds: 30);

  static bool _handlingSessionConflict = false;
  static bool _handlingAccountBan = false;
  // NOTE: This subscription is the central auth-state watcher used by the
  // app (for example, GoRouter's refreshListenable). Do NOT cancel this
  // subscription during a normal logout — letting the authStateChanges
  // stream emit `null` allows the router to redirect the user to the
  // login screen. Only cancel this on service/app shutdown.
  static StreamSubscription<User?>? _authSubscription;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _sessionSubscription;
  static Timer? _sessionValidationTimer;
  static final WidgetsBindingObserver _lifecycleObserver =
      _AuthSessionLifecycleObserver(
        onResumed: _handleAppResumed,
        onPaused: _handleAppPaused,
      );

  static Future<void> start() async {
    if (_authSubscription != null) {
      return;
    }

    WidgetsBinding.instance.addObserver(_lifecycleObserver);

    _authSubscription = _auth.authStateChanges().listen((user) {
      unawaited(_handleAuthStateChanged(user));
    });

    unawaited(_handleAuthStateChanged(_auth.currentUser));
  }

  static Future<void> registerSessionForUser(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return;
    }

    final sessionId = _generateSessionId();
    await _setRemoteSession(uid: normalizedUid, sessionId: sessionId);
    await _writeLocalSession(uid: normalizedUid, sessionId: sessionId);
  }

  static Future<void> logoutCurrentUser({
    bool clearRemoteSession = true,
    String? alertMessage,
  }) async {
    final message = (alertMessage ?? '').trim();
    if (message.isNotEmpty) {
      await _storeLogoutAlert(message);
    }

    final currentUser = _auth.currentUser;
    if (clearRemoteSession && currentUser != null) {
      await _clearRemoteSessionIfOwned(currentUser.uid);
    }

    // Mark offline before signing out to avoid stale presence.
    if (currentUser != null) {
      unawaited(_setUserOnlineFlag(false));
    }

    await _auth.signOut();

    // Important: allow authStateChanges to propagate (so GoRouter and other
    // global listeners receive the `user == null` event) before performing
    // destructive cleanup. On Windows deleting Hive disk files or closing
    // Hive here can interrupt that flow or produce platform-specific
    // issues (app exit). To avoid closing the app after logout on Windows
    // keep cleanup minimal and only clear session-related keys.
    if (defaultTargetPlatform == TargetPlatform.windows) {
      // Remove only session-specific keys so router and listeners remain
      // functional. Do NOT cancel the main auth subscription here.
      await _clearLocalSession();
      return;
    }

    // For non-Windows platforms (mobile) keep the previous behavior so
    // existing mobile cleanup is preserved.
    await LocalJsonCacheService.instance.clearAllManaged();
    await Hive.close();
    await Hive.deleteFromDisk();
    await _clearLocalSession();
  }

  static Future<String?> consumePendingLogoutAlert() async {
    final prefs = await SharedPreferences.getInstance();
    final message = (prefs.getString(_logoutAlertKey) ?? '').trim();
    if (message.isEmpty) {
      return null;
    }

    await prefs.remove(_logoutAlertKey);
    return message;
  }

  static Future<void> _handleAuthStateChanged(User? user) async {
    await _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _sessionValidationTimer?.cancel();
    _sessionValidationTimer = null;

    if (user == null) {
      await _clearLocalSession();
      return;
    }

    final uid = user.uid;
    try {
      await _ensureLocalSession(uid);
    } catch (_) {
      // Best effort: continue and rely on live validation/listeners.
    }

    await _validateCurrentSessionNow(uid);
    _startSessionValidationTimer(uid);

    _sessionSubscription = _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
          unawaited(_validateSingleSession(uid, snapshot));
        });
    // Mark user online when session becomes active locally.
    unawaited(_setUserOnlineFlag(true));
  }

  static Future<void> _ensureLocalSession(String uid) async {
    final local = await _readLocalSession();
    if (local.uid == uid && local.sessionId.isNotEmpty) {
      return;
    }

    final sessionId = _generateSessionId();
    await _setRemoteSession(uid: uid, sessionId: sessionId);
    await _writeLocalSession(uid: uid, sessionId: sessionId);
  }

  static void _startSessionValidationTimer(String uid) {
    _sessionValidationTimer?.cancel();
    _sessionValidationTimer = Timer.periodic(_sessionValidationInterval, (_) {
      final current = _auth.currentUser;
      if (current == null || current.uid != uid) {
        return;
      }
      unawaited(_validateCurrentSessionNow(uid));
    });
  }

  static Future<void> _validateSessionOnResume() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }
    await _validateCurrentSessionNow(user.uid);
  }

  static Future<void> _validateCurrentSessionNow(String uid) async {
    if (_handlingSessionConflict) {
      return;
    }

    final local = await _readLocalSession();
    if (local.uid != uid || local.sessionId.isEmpty) {
      return;
    }

    final remoteSessionId = await _readRemoteSessionId(uid);
    if (remoteSessionId.isEmpty || remoteSessionId == local.sessionId) {
      return;
    }

    _handlingSessionConflict = true;
    try {
      await logoutCurrentUser(
        clearRemoteSession: false,
        alertMessage: _sessionConflictAlertMessage,
      );
    } finally {
      _handlingSessionConflict = false;
    }
  }

  static Future<void> _validateSingleSession(
    String uid,
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) async {
    // If account was banned from the server, force immediate logout with
    // a clear message that will be shown on the login screen.
    if (_handlingAccountBan) return;
    try {
      final data = snapshot.data();
      final isBanned = data == null
          ? false
          : (data['isBanned'] as bool? ?? false);
      if (isBanned) {
        _handlingAccountBan = true;
        try {
          await logoutCurrentUser(
            clearRemoteSession: false,
            alertMessage:
                'Your account has been restricted by an administrator.',
          );
        } finally {
          _handlingAccountBan = false;
        }
        return;
      }

      if (_handlingSessionConflict) {
        return;
      }

      final remoteSessionId =
          (snapshot.data()?['activeSessionId'] as String? ?? '').trim();
      final local = await _readLocalSession();

      if (local.uid != uid || local.sessionId.isEmpty) {
        if (remoteSessionId.isNotEmpty) {
          await _writeLocalSession(uid: uid, sessionId: remoteSessionId);
        }
        return;
      }

      if (remoteSessionId.isEmpty || remoteSessionId == local.sessionId) {
        return;
      }

      _handlingSessionConflict = true;
      try {
        await logoutCurrentUser(
          clearRemoteSession: false,
          alertMessage: _sessionConflictAlertMessage,
        );
      } finally {
        _handlingSessionConflict = false;
      }
    } catch (_) {
      // Best-effort only: do not let failures crash session watcher.
    }
  }

  static Future<void> _storeLogoutAlert(String message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_logoutAlertKey, message);
  }

  static Future<void> _clearRemoteSessionIfOwned(String uid) async {
    try {
      final local = await _readLocalSession();
      if (local.uid != uid || local.sessionId.isEmpty) {
        return;
      }

      final docRef = _firestore.collection(FirestorePaths.users).doc(uid);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          return;
        }

        final remoteSessionId =
            (snapshot.data()?['activeSessionId'] as String? ?? '').trim();
        if (remoteSessionId != local.sessionId) {
          return;
        }

        transaction.set(docRef, {
          'activeSessionId': FieldValue.delete(),
          'activeSessionUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (_) {
      // Best effort cleanup; do not block logout.
    }
  }

  static Future<String> _readRemoteSessionId(String uid) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePaths.users)
          .doc(uid)
          .get();
      return (snapshot.data()?['activeSessionId'] as String? ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  static Future<void> _setUserOnlineFlag(bool online) async {
    try {
      final current = _auth.currentUser;
      if (current == null) return;
      final docRef = _firestore
          .collection(FirestorePaths.users)
          .doc(current.uid);
      if (online) {
        await docRef.set({
          'isOnline': true,
          'activeSessionUpdatedAt': FieldValue.serverTimestamp(),
          'lastActiveAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await docRef.set({
          'isOnline': false,
          'activeChatId': FieldValue.delete(),
          'activeSessionUpdatedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // Best-effort only
    }
  }

  static Future<void> _handleAppResumed() async {
    try {
      await _validateSessionOnResume();
    } catch (_) {}
    unawaited(_setUserOnlineFlag(true));
  }

  static Future<void> _handleAppPaused() async {
    unawaited(_setUserOnlineFlag(false));
  }

  static Future<void> _setRemoteSession({
    required String uid,
    required String sessionId,
  }) async {
    await _firestore.collection(FirestorePaths.users).doc(uid).set({
      'activeSessionId': sessionId,
      'activeSessionUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _writeLocalSession({
    required String uid,
    required String sessionId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionUidKey, uid);
    await prefs.setString(_sessionIdKey, sessionId);
  }

  static Future<void> _clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionUidKey);
    await prefs.remove(_sessionIdKey);
  }

  static Future<_LocalSessionState> _readLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = (prefs.getString(_sessionUidKey) ?? '').trim();
    final sessionId = (prefs.getString(_sessionIdKey) ?? '').trim();
    return _LocalSessionState(uid: uid, sessionId: sessionId);
  }

  static String _generateSessionId() {
    final random = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    return '$micros$random';
  }
}

class _LocalSessionState {
  const _LocalSessionState({required this.uid, required this.sessionId});

  final String uid;
  final String sessionId;
}

class _AuthSessionLifecycleObserver extends WidgetsBindingObserver {
  _AuthSessionLifecycleObserver({
    required this.onResumed,
    required this.onPaused,
  });

  final Future<void> Function() onResumed;
  final Future<void> Function() onPaused;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(onResumed());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(onPaused());
    }
  }
}
