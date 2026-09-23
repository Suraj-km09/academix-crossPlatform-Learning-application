import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class AcademixLogo extends StatelessWidget {
  const AcademixLogo({
    super.key,
    this.size = 44,
    this.showAppName = false,
    this.gap = 10,
    this.textStyle,
  });

  static const String assetPath = 'assets/images/academix_logo.png';

  final double size;
  final bool showAppName;
  final double gap;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) {
          final colorScheme = Theme.of(context).colorScheme;
          return Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(size * 0.2),
            ),
            child: Icon(
              Icons.school_rounded,
              size: size * 0.55,
              color: colorScheme.primary,
            ),
          );
        },
      ),
    );

    if (!showAppName) {
      return logo;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        SizedBox(width: gap),
        Text(
          AppConstants.appName,
          style:
              textStyle ??
              Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
