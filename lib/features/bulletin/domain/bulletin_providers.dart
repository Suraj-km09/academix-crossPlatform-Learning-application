import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bulletin_model.dart';
import '../data/bulletin_repository.dart';

final bulletinRepositoryProvider = Provider<BulletinRepository>((ref) {
  return BulletinRepository();
});

final bulletinStreamProvider = StreamProvider.family<
    List<BulletinModel>,
    ({String collegeId, int? semester, String? course, String? role})>((ref, params) {
  final repository = ref.watch(bulletinRepositoryProvider);
  return repository.getBulletins(
    params.collegeId,
    semester: params.semester,
    course: params.course,
    role: params.role,
  );
});

final bulletinByIdProvider = StreamProvider.family<BulletinModel?, String>((
  ref,
  bulletinId,
) {
  final repository = ref.watch(bulletinRepositoryProvider);
  return repository.getBulletinById(bulletinId);
});

final unreadBulletinCountProvider = Provider.family<
    AsyncValue<int>,
    ({String collegeId, int? semester, String? course, String? role, String uid})>((ref, params) {
  final bulletinsAsync = ref.watch(
    bulletinStreamProvider((
      collegeId: params.collegeId,
      semester: params.semester,
      course: params.course,
      role: params.role,
    )),
  );

  return bulletinsAsync.whenData(
    (items) => items.where((item) => !item.readBy.contains(params.uid)).length,
  );
});
