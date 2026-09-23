import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/settings_screen.dart';
import '../../features/auth/presentation/app_startup_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_logs_screen.dart';
import '../../features/admin/presentation/academic_options_management_screen.dart';
import '../../features/admin/presentation/chat_messaging_control_screen.dart';
import '../../features/admin/presentation/college_management_screen.dart';
import '../../features/admin/presentation/pending_notes_review_screen.dart';
import '../../features/admin/presentation/reports_screen.dart';
import '../../features/admin/presentation/teacher_code_settings_screen.dart';
import '../../features/admin/presentation/teacher_approval_panel.dart';
import '../../features/admin/presentation/user_management_screen.dart';
import '../../features/admin/presentation/dsa_questions_uploader_screen.dart';
import '../../features/admin/presentation/placement_material_uploader_screen.dart';
import '../../features/admin/presentation/placement_management_screen.dart';
import '../../features/admin/presentation/interview_pdf_uploader_screen.dart';
import '../../features/admin/presentation/mcq_pdf_uploader_screen.dart';
import '../../features/alumni/presentation/alumni_dashboard_screen.dart';
import '../../features/alumni/presentation/alumni_profile_screen.dart';
import '../../features/alumni/presentation/alumni_safe_screen.dart';
import '../../features/alumni/presentation/my_referrals_screen.dart';
import '../../features/alumni/presentation/referral_request_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/bulletin/data/bulletin_model.dart';
import '../../features/bulletin/presentation/bulletin_detail_screen.dart';
import '../../features/bulletin/presentation/bulletin_screen.dart';
import '../../features/bulletin/presentation/post_bulletin_screen.dart';
import '../../features/chat/data/chat_model.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/chats_list_screen.dart';
import '../../features/chat/presentation/create_group_chat_screen.dart';
import '../../features/chat/presentation/join_group_link_screen.dart';
import '../../features/chat/presentation/new_direct_chat_screen.dart';
import '../../features/curriculum/presentation/curriculum_screen.dart';
import '../../features/locker/data/locker_file_model.dart';
import '../../features/locker/presentation/locker_file_detail_screen.dart';
import '../../features/locker/presentation/locker_screen.dart';
import '../../features/locker/presentation/upload_to_locker_screen.dart';
import '../../features/notes/data/note_model.dart';
import '../../features/notes/presentation/note_detail_screen.dart';
import '../../features/notes/presentation/notes_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/placement/presentation/dsa_questions_screen.dart';
import '../../features/placement/presentation/placement_dashboard_screen.dart';
import '../../features/placement/presentation/placement_subject_detail_screen.dart';
import '../../features/placement/presentation/placement_pdf_viewer_screen.dart';
import '../../features/placement/presentation/placement_materials_screen.dart';
import '../../features/placement/presentation/mcq_module_screen.dart';
import '../../features/placement/presentation/mcq_test_screen.dart';
import '../../features/placement/presentation/interview_module_screen.dart';
import '../../features/placement/domain/mcq_models.dart';
import '../../features/resume/presentation/resume_template_selection_screen.dart';
import '../../features/resume/presentation/resume_builder_form_screen.dart';
import '../../features/ai/presentation/ai_hub_screen.dart';
import '../../features/ai/presentation/ai_copilot_screen.dart';
import '../../features/ai/presentation/ai_skill_gap_screen.dart';
import '../../features/ai/presentation/ai_roadmap_screen.dart';
import '../constants/firestore_paths.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return AppRouter.router;
});

class AppRouter {
  AppRouter._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthStateListenable(_auth.authStateChanges()),
    redirect: (context, state) async {
      final String location = state.uri.path;
      final user = _auth.currentUser;

      const publicRoutes = <String>{
        '/splash',
        '/onboarding',
        '/login',
        '/register',
        '/forgot-password',
      };

      final isPublicRoute = publicRoutes.contains(location);

      if (user == null) {
        if (location == '/verify-email') return '/login';
        return isPublicRoute ? null : '/login';
      }

      // Optimization: Avoid frequent user.reload() to prevent "Too many attempts"
      final emailVerified = user.emailVerified;

      if (!emailVerified &&
          location != '/verify-email' &&
          !publicRoutes.contains(location)) {
        return '/verify-email';
      }

      if (emailVerified && location == '/verify-email') {
        return '/home';
      }

      if (location == '/splash') return null;

      if (publicRoutes.contains(location)) {
        return '/home';
      }

      // Permission check for admin routes
      if (location.startsWith('/admin')) {
        final doc = await _firestore
            .collection(FirestorePaths.users)
            .doc(user.uid)
            .get();
        final role = (doc.data()?['role'] as String? ?? 'student')
            .toLowerCase();
        if (role != 'admin') return '/home';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        builder: (context, state) => const AppStartupScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordScreen(
          initialEmail: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/notes', builder: (context, state) => const NotesScreen()),
      GoRoute(
        path: '/curriculum',
        builder: (context, state) => const CurriculumScreen(),
      ),
      GoRoute(
        path: '/note-detail/:id',
        builder: (_, state) {
          final noteId = state.pathParameters['id'] ?? '';
          final extra = state.extra;
          return NoteDetailScreen(
            noteId: noteId,
            initialNote: extra is NoteModel ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/alumni',
        builder: (context, state) => const AlumniSafeScreen(),
      ),
      GoRoute(
        path: '/alumni-profile/:uid',
        builder: (_, state) =>
            AlumniProfileScreen(alumniUid: state.pathParameters['uid'] ?? ''),
      ),
      GoRoute(
        path: '/referral-request/:alumniUid',
        builder: (_, state) => ReferralRequestScreen(
          alumniUid: state.pathParameters['alumniUid'] ?? '',
        ),
      ),
      GoRoute(
        path: '/my-referrals',
        builder: (_, state) => const MyReferralsScreen(),
      ),
      GoRoute(
        path: '/alumni-dashboard',
        builder: (_, state) => const AlumniDashboardScreen(),
      ),
      GoRoute(path: '/chats', builder: (_, state) => const ChatsListScreen()),
      GoRoute(
        path: '/chat/new-direct',
        builder: (_, state) => const NewDirectChatScreen(),
      ),
      GoRoute(
        path: '/chat/create-group',
        builder: (_, state) => const CreateGroupChatScreen(),
      ),
      GoRoute(
        path: '/chat/join-group',
        builder: (_, state) => const JoinGroupLinkScreen(),
      ),
      GoRoute(
        path: '/chat/:chatId',
        builder: (_, state) {
          final chatId = state.pathParameters['chatId'] ?? '';
          final extra = state.extra;
          return ChatScreen(
            chatId: chatId,
            initialChat: extra is ChatModel ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/locker',
        builder: (context, state) => const LockerScreen(),
      ),
      GoRoute(
        path: '/locker-file/:id',
        builder: (_, state) {
          final fileId = state.pathParameters['id'] ?? '';
          final extra = state.extra;
          return LockerFileDetailScreen(
            fileId: fileId,
            initialFile: extra is LockerFileModel ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/upload-locker',
        builder: (context, state) => const UploadToLockerScreen(),
      ),
      GoRoute(path: '/bulletin', builder: (_, state) => const BulletinScreen()),
      GoRoute(
        path: '/bulletin/post',
        builder: (_, state) => const PostBulletinScreen(),
      ),
      GoRoute(
        path: '/bulletin/:bulletinId',
        builder: (_, state) {
          final bulletinId = state.pathParameters['bulletinId'] ?? '';
          final extra = state.extra;
          return BulletinDetailScreen(
            bulletinId: bulletinId,
            initialBulletin: extra is BulletinModel ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const UserManagementScreen(),
      ),
      GoRoute(
        path: '/admin/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/admin/colleges',
        builder: (context, state) => const CollegeManagementScreen(),
      ),
      GoRoute(
        path: '/admin/teacher-code',
        builder: (context, state) => const TeacherCodeSettingsScreen(),
      ),
      GoRoute(
        path: '/admin/teacher-approvals',
        builder: (context, state) => const TeacherApprovalPanel(),
      ),
      GoRoute(
        path: '/admin/pending-notes',
        builder: (context, state) => const PendingNotesReviewScreen(),
      ),
      GoRoute(
        path: '/admin/chat-messaging',
        builder: (context, state) => const ChatMessagingControlScreen(),
      ),
      GoRoute(
        path: '/admin/logs',
        builder: (context, state) => const AdminLogsScreen(),
      ),
      GoRoute(
        path: '/admin/academic-options',
        builder: (context, state) => const AcademicOptionsManagementScreen(),
      ),
      GoRoute(
        path: '/admin/placement',
        builder: (context, state) => const PlacementManagementScreen(),
      ),
      GoRoute(
        path: '/admin/placement/dsa-uploader',
        builder: (context, state) => const DsaQuestionsUploaderScreen(),
      ),
      GoRoute(
        path: '/admin/placement/materials',
        builder: (context, state) {
          final extra = state.extra as String?;
          return PlacementMaterialUploaderScreen(initialSubjectId: extra);
        },
      ),
      GoRoute(
        path: '/admin/placement/interview-uploader',
        builder: (context, state) => const InterviewPdfUploaderScreen(),
      ),
      GoRoute(
        path: '/admin/placement/mcq-uploader',
        builder: (context, state) => const McqPdfUploaderScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      // Placement Module Routes
      GoRoute(
        path: '/placement',
        builder: (context, state) => const PlacementDashboardScreen(),
      ),
      GoRoute(
        path: '/placement/dsa',
        builder: (context, state) => const DsaQuestionsScreen(),
      ),
      GoRoute(
        path: '/placement/subject/:subjectId',
        builder: (context, state) {
          final subjectId = state.pathParameters['subjectId'] ?? '';
          final subjectName = state.extra as String? ?? 'Subject';
          return PlacementSubjectDetailScreen(
            subjectId: subjectId,
            subjectName: subjectName,
          );
        },
      ),
      GoRoute(
        path: '/placement/subject/:subjectId/materials',
        builder: (context, state) {
          final subjectId = state.pathParameters['subjectId'] ?? '';
          final subjectName = state.extra as String? ?? 'Subject';
          return PlacementMaterialsScreen(
            subjectId: subjectId,
            subjectName: subjectName,
          );
        },
      ),
      GoRoute(
        path: '/placement/subject/:subjectId/mcqs',
        builder: (context, state) {
          final subjectId = state.pathParameters['subjectId'] ?? '';
          final subjectName = state.extra as String? ?? 'Subject';
          return McqModuleScreen(
            subjectId: subjectId,
            subjectName: subjectName,
          );
        },
      ),
      GoRoute(
        path: '/placement/subject/:subjectId/interview-qs',
        builder: (context, state) {
          final subjectId = state.pathParameters['subjectId'] ?? '';
          final subjectName = state.extra as String? ?? 'Subject';
          return InterviewModuleScreen(
            subjectId: subjectId,
            subjectName: subjectName,
          );
        },
      ),
      GoRoute(
        path: '/placement/mcq-test/:id',
        builder: (context, state) {
          final test = state.extra as McqTest;
          return McqTestScreen(test: test);
        },
      ),
      GoRoute(
        path: '/placement/pdf-viewer',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return PlacementPdfViewerScreen(
            title: extra['title'] as String,
            pdfUrl: extra['pdfUrl'] as String,
          );
        },
      ),
      // Resume Module Routes
      GoRoute(
        path: '/resume/templates',
        builder: (context, state) => const ResumeTemplateSelectionScreen(),
      ),
      GoRoute(
        path: '/resume/builder/:templateId',
        builder: (context, state) => ResumeBuilderFormScreen(
          templateId: state.pathParameters['templateId'] ?? 'modern',
        ),
      ),
      // Academix AI Prototype Routes
      GoRoute(
        path: '/ai',
        builder: (context, state) => const AcademixAiHubScreen(),
      ),
      GoRoute(
        path: '/ai/copilot',
        builder: (context, state) {
          final prompt = state.extra as String?;
          return AiCopilotScreen(initialPrompt: prompt);
        },
      ),
      GoRoute(
        path: '/ai/skill-gap',
        builder: (context, state) => const AiSkillGapScreen(),
      ),
      GoRoute(
        path: '/ai/roadmap',
        builder: (context, state) => const AiRoadmapScreen(),
      ),
    ],
  );
}

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Stream<User?> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<User?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
