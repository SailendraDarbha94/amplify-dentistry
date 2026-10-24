import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Titled group of form fields with consistent vertical rhythm.
class FormSection extends StatelessWidget {
  /// Creates a form section.
  const FormSection({
    super.key,
    required this.title,
    required this.children,
    this.description,
    this.trailing,
    this.gap = AppSpacing.md,
  });

  /// Section heading.
  final String title;

  /// Optional helper sentence under the heading.
  final String? description;

  /// Optional widget at the end of the heading row.
  final Widget? trailing;

  /// Fields, laid out vertically with [gap] between them.
  final List<Widget> children;

  /// Vertical gap between fields.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// Horizontal row of fields that share the width equally, with a gap between
/// them. Pass [flex] to weight columns (defaults to equal).
class FormRow extends StatelessWidget {
  /// Creates a form row.
  const FormRow({
    super.key,
    required this.children,
    this.flex,
    this.gap = AppSpacing.md,
  }) : assert(
         flex == null || flex.length == children.length,
         'flex must match children',
       );

  /// Fields in the row.
  final List<Widget> children;

  /// Optional flex factor per child.
  final List<int>? flex;

  /// Horizontal gap between fields.
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(flex: flex?[i] ?? 1, child: children[i]),
        ],
      ],
    );
  }
}

/// Standard vertical gap between form fields.
class FormGap extends StatelessWidget {
  /// Creates a gap of [height] (defaults to 12 px).
  const FormGap({super.key, this.height = AppSpacing.md});

  /// Gap height.
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}
