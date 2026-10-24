import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Card with a title row (title + optional trailing widget) above its content.
/// The standard building block of every detail screen.
class SectionCard extends StatelessWidget {
  /// Creates a section card.
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
    this.padding = AppSpacing.cardPadding,
    this.onTap,
  });

  /// Section heading.
  final String title;

  /// Optional line under the heading.
  final String? subtitle;

  /// Widget at the end of the heading row (badge, action button, count).
  final Widget? trailing;

  /// Section body.
  final Widget child;

  /// Padding around the whole card content.
  final EdgeInsetsGeometry padding;

  /// Makes the whole card tappable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
    return Card(
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
