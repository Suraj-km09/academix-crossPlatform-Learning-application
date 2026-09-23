import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/college_model.dart';
import '../../../shared/models/user_model.dart';
import '../data/admin_repository.dart';
import '../data/report_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/services/security_config_service.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

final adminDashboardStatsProvider = StreamProvider<Map<String, int>>((ref) {
  return ref.watch(adminRepositoryProvider).getDashboardStats();
});

final adminUsersProvider =
    StreamProvider.family<List<UserModel>, ({String? role, String? collegeId})>(
      (ref, params) {
        return ref
            .watch(adminRepositoryProvider)
            .getAllUsers(role: params.role, collegeId: params.collegeId);
      },
    );

final adminPendingReportsProvider = StreamProvider<List<ReportModel>>((ref) {
  return ref.watch(adminRepositoryProvider).getPendingReports();
});

// `adminRecentLogsProvider` removed from dashboard; Admin Logs screen uses
// `AdminRepository.fetchAdminLogsPage` directly via the UI.

final adminPendingReportsCountProvider = StreamProvider<int>((ref) {
  return ref.watch(adminRepositoryProvider).getPendingReportsCount();
});

final adminPendingAlumniCountProvider = StreamProvider<int>((ref) {
  return ref.watch(adminRepositoryProvider).getPendingAlumniVerificationCount();
});

final adminPendingTeacherRequestsCountProvider = StreamProvider<int>((ref) {
  return ref.watch(adminRepositoryProvider).getPendingTeacherRequestCount();
});

final adminPendingTeacherRequestsProvider = StreamProvider<List<UserModel>>((
  ref,
) {
  return ref.watch(adminRepositoryProvider).streamPendingTeacherRequests();
});

final teacherCodeConfigProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return ref.watch(adminRepositoryProvider).getTeacherCodeConfig();
});

final chatMessagingControlConfigProvider = StreamProvider<Map<String, dynamic>>(
  (ref) {
    return ref.watch(adminRepositoryProvider).getChatMessagingControlConfig();
  },
);

final adminUploadAccessConfigProvider = StreamProvider<Map<String, dynamic>>((
  ref,
) {
  final service = SecurityConfigService.instance(FirebaseFirestore.instance);
  return service.configStream.map((data) {
    final uploads =
        data['uploadsAllowedForRoles'] as Map<String, dynamic>? ?? {};

    Map<String, dynamic> roleEntry(dynamic entry) {
      if (entry == null) return {'notes': true, 'curriculum': true};
      if (entry is bool) return {'notes': entry, 'curriculum': entry};
      if (entry is Map<String, dynamic>) {
        return {
          'notes': entry['notes'] as bool? ?? true,
          'curriculum': entry['curriculum'] as bool? ?? true,
        };
      }
      return {'notes': true, 'curriculum': true};
    }

    final studentEntry = uploads['student'];
    final teacherEntry = uploads['teacher'];
    final alumniEntry = uploads['alumni'];

    return {
      'student': roleEntry(studentEntry),
      'teacher': roleEntry(teacherEntry),
      'alumni': roleEntry(alumniEntry),
      'uploadAccessUpdatedBy': data['uploadAccessUpdatedBy'] as String? ?? '',
      'uploadAccessUpdatedAt': data['uploadAccessUpdatedAt'],
    };
  });
});

final adminPendingNotesCountProvider = StreamProvider<int>((ref) {
  return ref.watch(adminRepositoryProvider).getPendingNotesCount();
});

final adminCollegesProvider = StreamProvider<List<CollegeModel>>((ref) {
  return ref.watch(adminRepositoryProvider).getAllColleges();
});
