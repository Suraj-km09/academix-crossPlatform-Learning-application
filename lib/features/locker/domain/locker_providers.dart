import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/locker_file_model.dart';
import '../data/locker_repository.dart';

final lockerRepositoryProvider = Provider<LockerRepository>((ref) {
  return LockerRepository();
});

final lockerFilesProvider =
    StreamProvider.family<List<LockerFileModel>, String>((ref, uid) {
      final repository = ref.watch(lockerRepositoryProvider);
      return repository.getFiles(uid);
    });

final lockerTotalUsedBytesProvider = Provider.family<AsyncValue<int>, String>((
  ref,
  uid,
) {
  final filesAsync = ref.watch(lockerFilesProvider(uid));
  return filesAsync.whenData(
    (files) => files.fold<int>(0, (sum, file) => sum + file.fileSize),
  );
});
