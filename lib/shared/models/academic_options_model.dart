import '../../core/constants/course_branch_options.dart';

class AcademicOptionsModel {
  const AcademicOptionsModel({required this.courses, required this.branches});

  const AcademicOptionsModel.defaults()
    : courses = CourseBranchOptions.courses,
      branches = CourseBranchOptions.branches;

  final List<String> courses;
  final List<String> branches;

  factory AcademicOptionsModel.fromMap(Map<String, dynamic>? map) {
    final rawCourses = map?['courses'];
    final rawBranches = map?['branches'];

    final normalizedCourses = _normalizeOptions(rawCourses);
    final normalizedBranches = _normalizeOptions(rawBranches);

    return AcademicOptionsModel(
      courses: normalizedCourses.isEmpty
          ? CourseBranchOptions.courses
          : normalizedCourses,
      branches: normalizedBranches.isEmpty
          ? CourseBranchOptions.branches
          : normalizedBranches,
    );
  }

  Map<String, dynamic> toMap() {
    return {'courses': courses, 'branches': branches};
  }

  static List<String> _normalizeOptions(dynamic raw) {
    if (raw is! List) {
      return const <String>[];
    }

    final unique = <String>{};
    final values = <String>[];
    for (final item in raw) {
      final value = item.toString().trim();
      if (value.isEmpty) {
        continue;
      }
      final key = value.toLowerCase();
      if (unique.add(key)) {
        values.add(value);
      }
    }
    return values;
  }
}
