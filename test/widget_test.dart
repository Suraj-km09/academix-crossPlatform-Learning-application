import 'package:flutter_test/flutter_test.dart';
import 'package:student_hub/core/constants/app_constants.dart';

void main() {
  test('app name constant is set', () {
    expect(AppConstants.appName, 'Academix');
  });
}
