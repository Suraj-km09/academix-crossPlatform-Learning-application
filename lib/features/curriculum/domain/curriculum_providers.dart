import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/curriculum_item_model.dart';
import '../data/curriculum_repository.dart';

final curriculumRepositoryProvider = Provider<CurriculumRepository>((ref) {
  return CurriculumRepository();
});

final curriculumStreamProvider =
    StreamProvider.family<
      List<CurriculumItemModel>,
      ({
        String collegeId,
        String? course,
        String? semester,
        String? branch,
        String? category,
      })
    >((ref, params) {
      final repository = ref.watch(curriculumRepositoryProvider);
      return repository.getRecentCurriculumItems(
        params.collegeId,
        limit: CurriculumRepository.defaultRecentCurriculumLimit,
        course: params.course,
        semester: params.semester,
        branch: params.branch,
        category: params.category,
      );
    });
