import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/constants/storage_bucket_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/services/local_json_cache_service.dart';

class ProfileRepository {
  ProfileRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage =
          storage ??
          FirebaseStorage.instanceFor(
            bucket: StorageBucketConfig.activeBucketGsUri,
          );

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  static const String _userCachePrefix = 'user_profile::';

  Future<void> updateProfile({
    required String uid,
    required Map<String, dynamic> updates,
  }) async {
    await _firestore.collection(FirestorePaths.users).doc(uid).set({
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await LocalJsonCacheService.instance.remove('$_userCachePrefix$uid');
  }

  Future<String> uploadUserImage({
    required String uid,
    required PlatformFile file,
    required String folder,
  }) async {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const AppException(
        message: 'Unable to read selected image. Please choose again.',
      );
    }

    final extension = _fileExtension(file.name);
    final ref = _storage
        .ref()
        .child('users')
        .child(uid)
        .child(folder)
        .child('${DateTime.now().millisecondsSinceEpoch}.$extension');

    await ref.putData(
      bytes,
      SettableMetadata(contentType: _contentType(extension)),
    );

    return ref.fullPath;
  }

  Future<String> uploadUserImageBytes({
    required String uid,
    required Uint8List bytes,
    required String folder,
    required String extension,
  }) async {
    if (bytes.isEmpty) {
      throw const AppException(
        message: 'Unable to read selected image. Please choose again.',
      );
    }

    final normalizedExtension = extension.trim().toLowerCase().isEmpty
        ? 'jpg'
        : extension.trim().toLowerCase();

    final ref = _storage
        .ref()
        .child('users')
        .child(uid)
        .child(folder)
        .child('${DateTime.now().millisecondsSinceEpoch}.$normalizedExtension');

    await ref.putData(
      bytes,
      SettableMetadata(contentType: _contentType(normalizedExtension)),
    );

    return ref.fullPath;
  }

  String _fileExtension(String fileName) {
    final split = fileName.split('.');
    if (split.length < 2) {
      return 'jpg';
    }
    return split.last.toLowerCase();
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }
}
