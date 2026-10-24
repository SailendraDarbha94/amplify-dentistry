import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Thin banner shown at the top of a screen when the device is offline or has
/// local changes waiting to sync. Renders nothing when online with no
/// pending changes.
class OfflineBanner extends StatelessWidget {
  /// Creates the banner.
  const OfflineBanner({
    super.key,
    required this.isOffline,
    this.pendingCount = 0,
    this.onTap,
  });

  /// True when there is no network.
  final bool isOffline;

  /// Number of local writes not yet synced.
  final int pendingCount;

  /// Optional tap handler (open the sync screen).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (!isOffline && pendingCount <= 0) return const SizedBox.shrink();
    final strings = AppStrings.of(context);
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final color = isOffline ? colors.warning : colors.info;
    final icon = isOffline ? Icons.cloud_off_outlined : Icons.sync;
    final text = isOffline
        ? pendingCount > 0
              ? '${strings.offline} - ${strings.pendingChangesCount(pendingCount)}'
              : strings.offline
        : '${strings.syncing} - ${strings.pendingChangesCount(pendingCount)}';
    return Semantics(
      liveRegion: true,
      child: Material(
        color: color.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.22 : 0.14,
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.labelLarge?.copyWith(color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
