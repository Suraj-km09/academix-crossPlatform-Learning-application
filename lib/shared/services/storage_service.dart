import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/storage_bucket_config.dart';
import '../../core/errors/app_exception.dart';

class StorageService {
  StorageService({FirebaseStorage? storage, Dio? dio})
    : _storage =
          storage ??
          FirebaseStorage.instanceFor(
            bucket: StorageBucketConfig.activeBucketGsUri,
          ),
      _dio = dio ?? Dio();

  final FirebaseStorage _storage;
  final Dio _dio;
  final Uuid _uuid = const Uuid();

  Future<String?> pickPdfPath() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: false,
    );

    return result?.files.single.path;
  }

  Future<String> uploadPdf({
    required String filePath,
    required String bucketFolder,
  }) async {
    if (!_isPdf(filePath)) {
      throw const AppException(message: 'Only PDF files are allowed');
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      throw const AppException(message: 'Selected file does not exist');
    }

    final fileRef = _storage
        .ref()
        .child(bucketFolder)
        .child('${_uuid.v4().replaceAll('-', '')}.pdf');

    final metadata = SettableMetadata(contentType: 'application/pdf');
    await fileRef.putFile(file, metadata);
    return fileRef.getDownloadURL();
  }

  Future<File> downloadPdf({required String url, String? fileName}) async {
    final tempDirectory = await getTemporaryDirectory();
    final resolvedName = fileName == null || fileName.trim().isEmpty
        ? '${_uuid.v4()}.pdf'
        : fileName.endsWith('.pdf')
        ? fileName
        : '$fileName.pdf';

    final path = '${tempDirectory.path}${Platform.pathSeparator}$resolvedName';

    await _dio.download(url, path);
    return File(path);
  }

  Future<void> openPdfFromUrl({required String url, String? fileName}) async {
    final file = await downloadPdf(url: url, fileName: fileName);
    final openResult = await OpenFile.open(file.path);
    if (openResult.type != ResultType.done) {
      throw AppException(
        message: openResult.message,
        code: openResult.type.name,
      );
    }
  }

  Future<void> deleteByUrl(String fileUrl) async {
    final reference = _storage.refFromURL(fileUrl);
    await reference.delete();
  }

  bool _isPdf(String path) {
    return path.toLowerCase().endsWith('.pdf');
  }
}
