import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/errors/app_exception.dart';

class WriteRateLimiter {
  WriteRateLimiter({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> enforce({
    required String uid,
    required String action,
    required int maxRequests,
    required Duration window,
    String? messagePrefix,
  }) async {
    final normalizedUid = uid.trim();
    final normalizedAction = action.trim().toLowerCase();

    if (normalizedUid.isEmpty) {
      throw const AppException(message: 'Invalid user session');
    }
    if (normalizedAction.isEmpty || maxRequests <= 0) {
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final windowMs = window.inMilliseconds;
    final limiterRef = _firestore
        .collection(FirestorePaths.users)
        .doc(normalizedUid)
        .collection('rate_limits')
        .doc(normalizedAction);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(limiterRef);
      final data = snapshot.data() ?? const <String, dynamic>{};

      final storedWindowStartMs = _toInt(data['windowStartMs']) ?? nowMs;
      final storedCount = _toInt(data['count']) ?? 0;

      final withinSameWindow = nowMs - storedWindowStartMs < windowMs;
      final windowStartMs = withinSameWindow ? storedWindowStartMs : nowMs;
      final currentCount = withinSameWindow ? storedCount : 0;

      if (currentCount >= maxRequests) {
        final remainingMs = windowMs - (nowMs - windowStartMs);
        final waitSeconds = remainingMs <= 0 ? 1 : (remainingMs / 1000).ceil();
        final prefix = (messagePrefix ?? 'Too many requests').trim();
        throw AppException(message: '$prefix. Try again in ${waitSeconds}s.');
      }

      transaction.set(limiterRef, {
        'count': currentCount + 1,
        'windowStartMs': windowStartMs,
        'windowMs': windowMs,
        'maxRequests': maxRequests,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
