import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Bottom-sheet confirmation with a big confirm button and a cancel button.
/// [destructive] switches the confirm button to the danger colour.
class ConfirmSheet extends StatelessWidget {
  /// Creates the sheet body; prefer [ConfirmSheet.show].
  const ConfirmSheet({
    super.key,
    required this.title,
    this.message,
    this.confirmLabel,
    this.cancelLabel,
    this.destructive = false,
    this.icon,
    this.onConfirm,
    this.onCancel,
  });

  /// Question asked of the user.
  final String title;

  /// Supporting detail.
  final String? message;

  /// Confirm button text; defaults to Confirm (or Delete when destructive).
  final String? confirmLabel;

  /// Cancel button text; defaults to Cancel.
  final String? cancelLabel;

  /// Styles the confirm action in the danger colour.
  final bool destructive;

  /// Optional icon above the title.
  final IconData? icon;

  /// Called on confirm; the default pops with `true`.
  final VoidCallback? onConfirm;

  /// Called on cancel; the default pops with `false`.
  final VoidCallback? onCancel;

  /// Presents the sheet and resolves to `true` when confirmed, `false`
  /// otherwise (cancel, swipe-down or barrier tap).
  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? message,
    String? confirmLabel,
    String? cancelLabel,
    bool destructive = false,
    IconData? icon,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: false,
      useSafeArea: true,
      builder: (ctx) => ConfirmSheet(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        icon: icon,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final danger = AppColors.of(context).danger;
    final confirmStyle = destructive
        ? FilledButton.styleFrom(
            backgroundColor: danger,
            foregroundColor: theme.colorScheme.onError,
            minimumSize: const Size.fromHeight(AppSpacing.bigButtonHeight),
          )
        : FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSpacing.bigButtonHeight),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 40,
              color: destructive ? danger : theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            title,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            style: confirmStyle,
            onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
            child: Text(
              confirmLabel ?? (destructive ? strings.delete : strings.confirm),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSpacing.bigButtonHeight),
            ),
            onPressed: onCancel ?? () => Navigator.of(context).pop(false),
            child: Text(cancelLabel ?? strings.cancel),
          ),
        ],
      ),
    );
  }
}
