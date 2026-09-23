import 'package:flutter/material.dart';

/// A small responsive layout helper that centers content and constrains
/// the maximum width based on common breakpoints (mobile/tablet/desktop).
///
/// Use `ResponsiveLayout` to wrap long scrollable column/list content so
/// cards and forms don't stretch uncomfortably on wide screens.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.maxWidthDesktop = 1000,
    this.maxWidthTablet = 760,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidthDesktop;
  final double maxWidthTablet;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const mobileBp = 600.0;
        const tabletBp = 1024.0;

        final contentMaxWidth = width >= tabletBp
            ? maxWidthDesktop
            : width >= mobileBp
            ? maxWidthTablet
            : width;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: Padding(padding: padding, child: child),
          ),
        );
      },
    );
  }
}

/// Wrap a Card (or any block) with a centered max-width so the Card never
/// stretches too wide on large screens. Default card max width is 600px.
class ResponsiveCard extends StatelessWidget {
  const ResponsiveCard({
    super.key,
    required this.child,
    this.maxCardWidth = 600,
    this.margin = const EdgeInsets.symmetric(vertical: 6),
  });

  final Widget child;
  final double maxCardWidth;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final effectiveMax = available < maxCardWidth
            ? available
            : maxCardWidth;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: effectiveMax),
            child: Container(margin: margin, child: child),
          ),
        );
      },
    );
  }
}
