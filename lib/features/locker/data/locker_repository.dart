import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/constants/storage_bucket_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/services/cache_policy.dart';
import '../../../shared/services/local_json_cache_service.dart';
import 'locker_file_model.dart';

class LockerRepository {
  LockerRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    Dio? dio,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage =
           storage ??
           FirebaseStorage.instanceFor(
             bucket: StorageBucketConfig.activeBucketGsUri,
           ),
       _dio = dio ?? Dio();

  static const int maxUserStorageBytes = 100 * 1024 * 1024;
  static const int maxSingleFileBytes = 50 * 1024 * 1024;
  static const String _filesCachePrefix = 'locker_files::';

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final Dio _dio;

  Stream<List<LockerFileModel>> getFiles(String uid) async* {
    final cached = await _readCachedFiles(uid);
    if (cached.isNotEmpty) {
      yield cached;
    }

    final stream = _firestore
        .collection(FirestorePaths.lockers)
        .doc(uid)
        .collection('files')
        .orderBy('uploadedAt', descending: true)
        .snapshots();

    await for (final snapshot in stream) {
      final files = snapshot.docs
          .map((doc) => LockerFileModel.fromMap(doc.data(), doc.id))
          .toList();
      unawaited(_writeCachedFiles(uid, files));
      yield files;
    }
  }

  Future<int> getTotalUsedBytes(String uid) async {
    final cacheEntry = await LocalJsonCacheService.instance.read(
      _filesCacheKey(uid),
    );
    if (cacheEntry != null &&
        cacheEntry.isFresh(CachePolicy.lockerFilesMaxAge)) {
      final cached = _decodeLockerFiles(cacheEntry.payload);
      if (cached.isNotEmpty) {
        return cached.fold<int>(0, (sum, file) => sum + file.fileSize);
      }
    }

    final snapshot = await _firestore
        .collection(FirestorePaths.lockers)
        .doc(uid)
        .collection('files')
        .get();

    final models = snapshot.docs
        .map((doc) => LockerFileModel.fromMap(doc.data(), doc.id))
        .toList();

    unawaited(_writeCachedFiles(uid, models));
    return models.fold<int>(0, (sum, file) => sum + file.fileSize);
  }

  Future<void> uploadFile(
    String uid,
    PlatformFile file,
    String fileName,
    List<String> tags, {
    void Function(double progress)? onProgress,
  }) async {
    if (!_isPdf(file)) {
      throw const AppException(message: 'Only PDF files are allowed');
    }

    if (file.size <= 0) {
      throw const AppException(message: 'Selected file is invalid');
    }

    if (file.size > maxSingleFileBytes) {
      throw const AppException(message: 'Single file size cannot exceed 50 MB');
    }

    final sourceBytes = await _readFileBytes(file);

    onProgress?.call(0.05);
    final compressedBytes = await _compressPdf(sourceBytes);
    final finalBytes = compressedBytes ?? sourceBytes;

    final used = await getTotalUsedBytes(uid);
    if (used + finalBytes.length > maxUserStorageBytes) {
      throw const AppException(
        message: 'Storage limit exceeded. Locker allows up to 100 MB per user.',
      );
    }

    final fileRef = _firestore
        .collection(FirestorePaths.lockers)
        .doc(uid)
        .collection('files')
        .doc();
    final fileId = fileRef.id;

    final storageRef = _storage
        .ref()
        .child('lockers')
        .child(uid)
        .child('$fileId.pdf');

    final metadata = SettableMetadata(
      contentType: 'application/pdf',
      customMetadata: {
        'wasCompressed': (compressedBytes != null).toString(),
        'originalSize': sourceBytes.length.toString(),
      },
    );

    final uploadTask = storageRef.putData(finalBytes, metadata);
    final subscription = uploadTask.snapshotEvents.listen((snapshot) {
      final total = snapshot.totalBytes;
      if (total <= 0) return;
      final progress = 0.1 + (snapshot.bytesTransferred / total) * 0.9;
      onProgress?.call(progress.clamp(0, 1));
    });

    try {
      await uploadTask;
      await subscription.cancel();

      final downloadUrl = await storageRef.getDownloadURL();
      final model = LockerFileModel(
        fileId: fileId,
        fileName: _normalizeFileName(fileName, fallback: file.name),
        fileUrl: downloadUrl,
        fileSize: finalBytes.length,
        tags: _normalizeTags(tags),
        uploadedAt: DateTime.now(),
        isOfflineCached: false,
        localPath: null,
      );

      await fileRef.set(model.toMap());
      await LocalJsonCacheService.instance.remove(_filesCacheKey(uid));
    } catch (error) {
      await subscription.cancel();
      rethrow;
    }
  }

  Future<Uint8List?> _compressPdf(Uint8List bytes) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      document.compressionLevel = PdfCompressionLevel.best;
      final List<int> compressed = await document.save();
      document.dispose();
      return compressed.length < bytes.length
          ? Uint8List.fromList(compressed)
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteFile(String uid, String fileId, String fileUrl) async {
    final fileDoc = _firestore
        .collection(FirestorePaths.lockers)
        .doc(uid)
        .collection('files')
        .doc(fileId);

    final ref = fileUrl.startsWith('http://') || fileUrl.startsWith('https://')
        ? _storage.refFromURL(fileUrl)
        : _storage.ref(fileUrl);

    try {
      await ref.delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }

    await fileDoc.delete();

    final box = await _openCacheBox();
    final cacheKey = _cacheKey(uid, fileId);
    final cachedPath = box.get(cacheKey);
    if (cachedPath != null && cachedPath.trim().isNotEmpty) {
      final localFile = File(cachedPath);
      if (await localFile.exists()) await localFile.delete();
    }
    await box.delete(cacheKey);
    await LocalJsonCacheService.instance.remove(_filesCacheKey(uid));
  }

  Future<void> renameFile(String uid, String fileId, String newName) async {
    final normalized = _normalizeFileName(newName, fallback: newName);
    await _firestore
        .collection(FirestorePaths.lockers)
        .doc(uid)
        .collection('files')
        .doc(fileId)
        .update({'fileName': normalized});
    await LocalJsonCacheService.instance.remove(_filesCacheKey(uid));
  }

  Future<void> updateTags(String uid, String fileId, List<String> tags) async {
    await _firestore
        .collection(FirestorePaths.lockers)
        .doc(uid)
        .collection('files')
        .doc(fileId)
        .update({'tags': _normalizeTags(tags)});
    await LocalJsonCacheService.instance.remove(_filesCacheKey(uid));
  }

  Future<String> cacheOffline(
    String uid,
    String fileId,
    String fileUrl,
    String fileName, {
    void Function(double progress)? onProgress,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final folder = Directory(
      '${docsDir.path}${Platform.pathSeparator}locker_cache${Platform.pathSeparator}$uid',
    );
    if (!await folder.exists()) await folder.create(recursive: true);

    final localPath =
        '${folder.path}${Platform.pathSeparator}${_safeFileName(fileName)}_$fileId.pdf';

    await _dio.download(
      fileUrl,
      localPath,
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        onProgress?.call((received / total).clamp(0, 1));
      },
      options: Options(responseType: ResponseType.bytes),
    );

    final box = await _openCacheBox();
    await box.put(_cacheKey(uid, fileId), localPath);

    await _firestore
        .collection(FirestorePaths.lockers)
        .doc(uid)
        .collection('files')
        .doc(fileId)
        .update({'isOfflineCached': true, 'localPath': localPath});

    await LocalJsonCacheService.instance.remove(_filesCacheKey(uid));
    return localPath;
  }

  Future<String?> getCachedLocalPath(String uid, String fileId) async {
    final box = await _openCacheBox();
    final value = box.get(_cacheKey(uid, fileId));
    return (value == null || value.trim().isEmpty) ? null : value;
  }

  Future<Uint8List> _readFileBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) return file.bytes!;
    final path = file.path;
    if (path == null) throw const AppException(message: 'File path not found');
    return File(path).readAsBytes();
  }

  bool _isPdf(PlatformFile file) {
    final extension = (file.extension ?? '').toLowerCase();
    return extension == 'pdf' || file.name.toLowerCase().endsWith('.pdf');
  }

  String _normalizeFileName(String value, {required String fallback}) {
    final raw = value.trim().isEmpty ? fallback.trim() : value.trim();
    return raw.toLowerCase().endsWith('.pdf') ? raw : '$raw.pdf';
  }

  List<String> _normalizeTags(List<String> tags) {
    return tags
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  String _safeFileName(String name) {
    final withoutExt = name.toLowerCase().endsWith('.pdf')
        ? name.substring(0, name.length - 4)
        : name;
    return withoutExt.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  String _cacheKey(String uid, String fileId) => '$uid::$fileId';
  String _filesCacheKey(String uid) => '$_filesCachePrefix$uid';

  Future<List<LockerFileModel>> _readCachedFiles(String uid) async {
    final entry = await LocalJsonCacheService.instance.read(
      _filesCacheKey(uid),
    );
    return _decodeLockerFiles(entry?.payload);
  }

  Future<void> _writeCachedFiles(String uid, List<LockerFileModel> files) {
    final payload = files.map((file) => file.toMap()).toList();
    return LocalJsonCacheService.instance.write(_filesCacheKey(uid), payload);
  }

  List<LockerFileModel> _decodeLockerFiles(dynamic payload) {
    if (payload is! List) return const <LockerFileModel>[];
    return payload
        .map(
          (item) =>
              LockerFileModel.fromMap(Map<String, dynamic>.from(item), ''),
        )
        .toList()
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
  }

  Future<Box<String>> _openCacheBox() async {
    const boxName = 'locker_cache';
    return Hive.isBoxOpen(boxName)
        ? Hive.box<String>(boxName)
        : await Hive.openBox<String>(boxName);
  }
}
