import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import '../theme/app_spacing.dart';

/// Scaffold with a centred progress indicator; use while the first data load
/// for a screen is in flight.
class LoadingScaffold extends StatelessWidget {
  /// Creates a loading scaffold.
  const LoadingScaffold({super.key, this.message, this.appBar});

  /// Optional message under the spinner; defaults to "Loading".
  final String? message;

  /// Optional app bar so the title stays stable across loading and loaded.
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: appBar,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message ?? AppStrings.of(context).loading,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
