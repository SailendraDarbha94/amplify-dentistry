import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Semantic tone of a [StatusBadge]; maps to [AppColors].
enum BadgeTone {
  /// Grey, no judgement.
  neutral,

  /// Green: paid, synced, done.
  success,

  /// Amber: pending, due soon.
  warning,

  /// Red: overdue, failed.
  danger,

  /// Blue: informational.
  info,

  /// Treatment-planned (dental red).
  planned,

  /// Completed treatment (dental blue).
  completed,

  /// Caries mark.
  caries,

  /// Pre-existing work.
  existing;

  /// Resolves this tone's colour from the theme.
  Color resolve(BuildContext context) {
    final colors = AppColors.of(context);
    return switch (this) {
      BadgeTone.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
      BadgeTone.success => colors.success,
      BadgeTone.warning => colors.warning,
      BadgeTone.danger => colors.danger,
      BadgeTone.info => colors.info,
      BadgeTone.planned => colors.planned,
      BadgeTone.completed => colors.completed,
      BadgeTone.caries => colors.caries,
      BadgeTone.existing => colors.existing,
    };
  }
}

/// Compact pill with a tinted background and a bold label, e.g. "Planned",
/// "Paid", "Overdue".
class StatusBadge extends StatelessWidget {
  /// Creates a badge.
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
    this.dense = false,
  });

  /// Badge text.
  final String label;

  /// Colour tone.
  final BadgeTone tone;

  /// Optional leading icon.
  final IconData? icon;

  /// Smaller padding and text for use inside list tiles.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = tone.resolve(context);
    final background = color.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.22 : 0.12,
    );
    final textStyle =
        (dense ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
            ?.copyWith(color: color, fontWeight: FontWeight.w700);
    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? AppSpacing.sm : AppSpacing.md,
          vertical: dense ? 2 : AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadii.pillAll,
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: dense ? 12 : 14, color: color),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
