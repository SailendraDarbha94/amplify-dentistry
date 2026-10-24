import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Small grey label above a bold value: "Phone / +91 98765 43210".
class LabeledValue extends StatelessWidget {
  /// Creates a labelled value.
  const LabeledValue({
    super.key,
    required this.label,
    required this.value,
    this.valueWidget,
    this.trailing,
    this.dense = false,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  /// Caption shown above the value.
  final String label;

  /// Value text; ignored when [valueWidget] is given.
  final String value;

  /// Custom value widget (for example a [StatusBadge] or `MoneyText`).
  final Widget? valueWidget;

  /// Optional widget at the end of the row.
  final Widget? trailing;

  /// Tighter spacing and smaller value text.
  final bool dense;

  /// Alignment of label and value.
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final column = Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: dense ? 2 : AppSpacing.xs),
        valueWidget ??
            Text(
              value,
              style: dense
                  ? theme.textTheme.bodyMedium
                  : theme.textTheme.bodyLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      ],
    );
    if (trailing == null) return column;
    return Row(
      children: [
        Expanded(child: column),
        const SizedBox(width: AppSpacing.sm),
        trailing!,
      ],
    );
  }
}
