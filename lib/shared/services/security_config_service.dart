import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';

class SecurityConfigService {
  SecurityConfigService._(this._firestore) {
    _init();
  }

  final FirebaseFirestore _firestore;
  static SecurityConfigService? _instance;

  static SecurityConfigService instance(FirebaseFirestore firestore) {
    _instance ??= SecurityConfigService._(firestore);
    return _instance!;
  }

  Map<String, dynamic> _config = <String, dynamic>{};
  Map<String, dynamic> get config => _config;

  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get configStream async* {
    // Emit the current cached config immediately for new subscribers,
    // then forward subsequent updates from the internal controller.
    yield _config;
    yield* _controller.stream;
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  void _init() {
    final docRef = _firestore
        .collection(FirestorePaths.appConfig)
        .doc('security');
    _sub = docRef.snapshots().listen((snapshot) {
      _config = snapshot.data() ?? <String, dynamic>{};
      try {
        _controller.add(_config);
      } catch (_) {}
    });
  }

  bool isRoleResourceAllowed(String role, String resource) {
    final uploads = _config['uploadsAllowedForRoles'] as Map<String, dynamic>?;
    if (uploads == null) return true;
    final roleEntry = uploads[role];
    if (roleEntry == null) return true;

    if (roleEntry is bool) {
      // legacy single-flag per role -> treat as both resources allowed/disabled
      return roleEntry;
    }

    final roleMap = roleEntry as Map<String, dynamic>?;
    if (roleMap == null) return true;
    final allowed = roleMap[resource];
    if (allowed is bool) return allowed;
    return true;
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    try {
      _controller.close();
    } catch (_) {}
    _instance = null;
  }
}
