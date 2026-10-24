import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Friendly error block with a retry button. Never shows a stack trace.
class ErrorView extends StatelessWidget {
  /// Creates an error view.
  const ErrorView({super.key, this.title, this.message, this.onRetry});

  /// Headline; defaults to "Something went wrong".
  final String? title;

  /// Optional detail in plain language.
  final String? message;

  /// Shows a retry button when provided.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: AppColors.of(context).danger,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title ?? strings.somethingWentWrong,
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
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(strings.tryAgain),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
