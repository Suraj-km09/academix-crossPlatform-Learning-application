import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user_model.dart';
import '../data/alumni_qa_model.dart';
import '../data/alumni_repository.dart';
import '../data/referral_request_model.dart';

final alumniRepositoryProvider = Provider<AlumniRepository>((ref) {
  return AlumniRepository();
});

final alumniStreamProvider = StreamProvider.family<List<UserModel>, String>((
  ref,
  collegeId,
) {
  final repository = ref.watch(alumniRepositoryProvider);
  return repository.getAlumni(collegeId);
});

final publicQaProvider = StreamProvider.family<List<AlumniQAModel>, String>((
  ref,
  collegeId,
) {
  final repository = ref.watch(alumniRepositoryProvider);
  return repository.getPublicQA(collegeId);
});

final alumniPendingReferralsProvider =
    StreamProvider.family<List<ReferralRequestModel>, String>((ref, alumniUid) {
      final repository = ref.watch(alumniRepositoryProvider);
      return repository.getReferralRequests(alumniUid);
    });

final studentReferralsProvider =
    StreamProvider.family<List<ReferralRequestModel>, String>((
      ref,
      studentUid,
    ) {
      final repository = ref.watch(alumniRepositoryProvider);
      return repository.getStudentReferrals(studentUid);
    });

final alumniAllReferralsProvider =
    StreamProvider.family<List<ReferralRequestModel>, String>((ref, alumniUid) {
      final repository = ref.watch(alumniRepositoryProvider);
      return repository.getAlumniReferrals(alumniUid);
    });

final alumniUnansweredQuestionsProvider =
    StreamProvider.family<List<AlumniQAModel>, String>((ref, alumniUid) {
      final repository = ref.watch(alumniRepositoryProvider);
      return repository.getAlumniUnansweredQuestions(alumniUid);
    });

final completedReferralsBetweenProvider =
    StreamProvider.family<
      List<ReferralRequestModel>,
      ({String studentUid, String alumniUid})
    >((ref, params) {
      final repository = ref.watch(alumniRepositoryProvider);
      return repository.getCompletedReferralsBetween(
        params.studentUid,
        params.alumniUid,
      );
    });
