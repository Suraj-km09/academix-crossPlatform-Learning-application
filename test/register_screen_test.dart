import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:student_hub/core/errors/app_exception.dart';
import 'package:student_hub/features/auth/data/auth_repository.dart';
import 'package:student_hub/features/auth/data/colleges_repository.dart';
import 'package:student_hub/features/auth/domain/auth_providers.dart';
import 'package:student_hub/features/auth/presentation/register_screen.dart';
// Removed unused imports causing analyzer warnings
import 'package:student_hub/shared/models/college_model.dart';
import 'package:student_hub/shared/models/user_model.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<UserModel> signUp(
    String name,
    String email,
    String password,
    String role,
    String collegeId,
    String? course,
    String? branch,
    int? semester,
    int? batchYear,
    String? company,
    String? jobRole,
    PlatformFile? profileImage,
    PlatformFile? idCardImage,
    String? teacherAccessCode,
  ) async {
    // Simulate server-side invalid teacher code
    throw AppException(
      message: 'Invalid teacher access code',
      code: 'invalid_teacher_code',
    );
  }

  // Minimal stub implementations for the rest of the interface
  @override
  Future<UserModel> login(String email, String password) async =>
      throw UnimplementedError();

  @override
  Future<void> logout({
    String? alertMessage,
    bool clearRemoteSession = true,
  }) async {}

  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  Future<void> updateFcmToken(String uid, String token) async {}

  @override
  Future<void> markApprovalMessageShown(String uid) async {}

  @override
  Future<void> markTeacherRequestMessageShown(String uid) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> sendEmailVerificationToCurrentUser() async {}

  @override
  Future<void> resendVerificationForCredentials(
    String email,
    String password,
  ) async {}

  @override
  Future<void> markCurrentUserVerified() async {}

  @override
  Future<UserModel?> getUserById(String uid) async => null;
}

class FakeCollegesRepository implements CollegesRepository {
  @override
  Future<CollegesPage> fetchColleges({
    required String searchQuery,
    required int pageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int offset = 0,
  }) async {
    final college = CollegeModel(
      collegeId: 'C1',
      name: 'Test College',
      state: 'State',
      city: 'City',
      emailDomain: '',
    );
    return CollegesPage(
      colleges: [college],
      lastDocument: null,
      hasMore: false,
    );
  }

  @override
  Future<int> seedCollegesFromAsset() async => 0;
}

void main() {
  testWidgets(
    'shows inline teacher code error when signUp throws invalid code',
    (tester) async {
      final fakeAuth = FakeAuthRepository();
      final fakeColleges = FakeCollegesRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            collegesRepositoryProvider.overrideWithValue(fakeColleges),
          ],
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Fill required fields
      await tester.enterText(find.bySemanticsLabel('Name'), 'Test Teacher');
      await tester.enterText(
        find.bySemanticsLabel('Email'),
        'teacher@example.com',
      );
      await tester.enterText(find.bySemanticsLabel('Password'), 'Password123!');
      await tester.enterText(
        find.bySemanticsLabel('Confirm Password'),
        'Password123!',
      );

      // Select role -> Teacher
      final roleDropdown = find.byWidgetPredicate((w) {
        return w is DropdownButtonFormField<String> &&
            (w.decoration.labelText ?? '').toLowerCase() == 'role';
      });
      await tester.tap(roleDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Teacher (Code + Admin Approval)').last);
      await tester.pumpAndSettle();

      // Enter teacher code
      await tester.enterText(
        find.bySemanticsLabel('Teacher Access Code'),
        'wrongcode',
      );

      // Select college from suggestions
      await tester.tap(find.bySemanticsLabel('College Search'));
      await tester.pumpAndSettle();
      expect(find.text('Test College'), findsOneWidget);
      await tester.tap(find.text('Test College'));
      await tester.pumpAndSettle();

      // Submit form (ensure button is visible first)
      await tester.ensureVisible(find.text('Register'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      // Inline error should appear
      expect(
        find.text('Security code is invalid. Please try again.'),
        findsOneWidget,
      );
    },
  );
}
