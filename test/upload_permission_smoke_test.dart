import 'package:flutter_test/flutter_test.dart';

// Lightweight smoke tests that validate the client-side gating logic
// using small, local helper classes mirroring the production API surface.

class FakeSecurityConfigService {
  final Map<String, Map<String, bool>> _data;
  FakeSecurityConfigService(this._data);

  bool isRoleResourceAllowed(String role, String resource) {
    final r = role.trim().toLowerCase();
    final map = _data[r];
    if (map == null) return true; // default allow if not configured
    return map[resource] ?? true;
  }
}

class FakeUserModel {
  final String uid;
  final String role;
  final bool canUploadNotesPyqs;
  FakeUserModel({
    required this.uid,
    required this.role,
    this.canUploadNotesPyqs = true,
  });
}

bool canUserUploadNotes(FakeUserModel user, FakeSecurityConfigService cfg) {
  if (!user.canUploadNotesPyqs) return false;
  return cfg.isRoleResourceAllowed(user.role, 'notes');
}

bool canUserUploadCurriculum(
  FakeUserModel user,
  FakeSecurityConfigService cfg,
) {
  if (!user.canUploadNotesPyqs) return false;
  return cfg.isRoleResourceAllowed(user.role, 'curriculum');
}

void main() {
  test('admin toggle disables notes upload for student role', () {
    final cfg = FakeSecurityConfigService({
      'student': {'notes': false, 'curriculum': true},
    });
    final student = FakeUserModel(
      uid: 'u1',
      role: 'student',
      canUploadNotesPyqs: true,
    );

    expect(canUserUploadNotes(student, cfg), isFalse);
    expect(canUserUploadCurriculum(student, cfg), isTrue);
  });

  test('per-user flag overrides role allow', () {
    final cfg = FakeSecurityConfigService({
      'teacher': {'notes': true, 'curriculum': false},
    });
    final teacher = FakeUserModel(
      uid: 't1',
      role: 'teacher',
      canUploadNotesPyqs: false,
    );

    expect(canUserUploadNotes(teacher, cfg), isFalse);
    expect(canUserUploadCurriculum(teacher, cfg), isFalse);
  });

  test('missing role config defaults to allow', () {
    final cfg = FakeSecurityConfigService({});
    final alumni = FakeUserModel(
      uid: 'a1',
      role: 'alumni',
      canUploadNotesPyqs: true,
    );

    expect(canUserUploadNotes(alumni, cfg), isTrue);
    expect(canUserUploadCurriculum(alumni, cfg), isTrue);
  });

  test('admin role always respects role config (admin can be disabled)', () {
    final cfg = FakeSecurityConfigService({
      'admin': {'notes': false, 'curriculum': false},
    });
    final admin = FakeUserModel(
      uid: 'admin1',
      role: 'admin',
      canUploadNotesPyqs: true,
    );

    expect(canUserUploadNotes(admin, cfg), isFalse);
    expect(canUserUploadCurriculum(admin, cfg), isFalse);
  });
}
