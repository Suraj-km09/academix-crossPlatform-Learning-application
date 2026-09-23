import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

extension StringX on String {
  String get capitalize {
    if (trim().isEmpty) {
      return this;
    }
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}

extension DateTimeX on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
}

extension BuildContextX on BuildContext {
  ThemeData get appTheme => Theme.of(this);
  TextTheme get appText => Theme.of(this).textTheme;
  ColorScheme get appColors => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  ThemeData get defaultAppTheme {
    return isDark ? AppTheme.darkTheme : AppTheme.lightTheme;
  }
}
