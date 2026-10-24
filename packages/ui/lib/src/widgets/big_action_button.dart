import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Full-width 56 px primary action with an icon and a label. The one button a
/// dentist hits with a gloved thumb to move to the next step.
class BigActionButton extends StatelessWidget {
  /// Creates a filled button; set [tonal] for a secondary emphasis variant.
  const BigActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tonal = false,
    this.loading = false,
  });

  /// Button text.
  final String label;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Use the tonal (secondary container) style instead of the primary fill.
  final bool tonal;

  /// Shows a spinner in place of the icon and disables the button.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(AppSpacing.bigButtonHeight),
      textStyle: Theme.of(context).textTheme.titleMedium,
    );
    final Widget leading = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Icon(icon, size: 24);
    final effectiveOnPressed = loading ? null : onPressed;
    final labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final hasIcon = icon != null || loading;
    if (tonal) {
      return hasIcon
          ? FilledButton.tonalIcon(
              onPressed: effectiveOnPressed,
              style: style,
              icon: leading,
              label: labelWidget,
            )
          : FilledButton.tonal(
              onPressed: effectiveOnPressed,
              style: style,
              child: labelWidget,
            );
    }
    return hasIcon
        ? FilledButton.icon(
            onPressed: effectiveOnPressed,
            style: style,
            icon: leading,
            label: labelWidget,
          )
        : FilledButton(
            onPressed: effectiveOnPressed,
            style: style,
            child: labelWidget,
          );
  }
}
