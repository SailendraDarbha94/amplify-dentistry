import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Icon-over-label tile for a grid of quick actions (New patient, Bill,
/// Consent, ...). Minimum 88 px tall so it is easy to hit in a hurry.
class QuickActionTile extends StatelessWidget {
  /// Creates a tile.
  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.badgeCount,
  });

  /// Tile icon.
  final IconData icon;

  /// Short label (one or two words).
  final String label;

  /// Called on tap; null disables the tile.
  final VoidCallback? onTap;

  /// Accent colour for the icon; defaults to the primary colour.
  final Color? color;

  /// Optional count shown in a small badge on the icon.
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = color ?? scheme.primary;
    final enabled = onTap != null;
    Widget iconWidget = Icon(
      icon,
      size: 32,
      color: enabled ? accent : scheme.outline,
    );
    if (badgeCount != null && badgeCount! > 0) {
      iconWidget = Badge.count(count: badgeCount!, child: iconWidget);
    }
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mdAll,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88, minWidth: 88),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconWidget,
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: enabled ? scheme.onSurface : scheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
