/// The shell's sync banner for a real engine: offline, N waiting, syncing,
/// synced at hh:mm (shown briefly) and error with tap-to-retry. The pure
/// [syncBannerSpec] is what the tests pin; [CloudSyncBanner] renders it.
library;

import 'package:ampdent_data/ampdent_data.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';

import 'formatting.dart';

/// Which banner is up.
enum SyncBannerKind {
  /// Backend unreachable (or signed out); writes keep queueing.
  offline,

  /// Idle with outbox rows waiting for the next run.
  waiting,

  /// Push or pull in flight.
  syncing,

  /// Everything uploaded and downloaded moments ago.
  synced,

  /// The last run was rejected; tap retries.
  error,
}

/// What the banner shows.
@immutable
class SyncBannerSpec {
  /// Creates a spec.
  const SyncBannerSpec({
    required this.kind,
    required this.text,
    required this.icon,
    required this.tone,
  });

  /// Kind.
  final SyncBannerKind kind;

  /// Single-line copy.
  final String text;

  /// Leading icon.
  final IconData icon;

  /// Colour tone.
  final BadgeTone tone;

  /// Whether tapping retries the sync.
  bool get canRetry => kind == SyncBannerKind.error;

  @override
  String toString() => 'SyncBannerSpec($kind, $text)';
}

/// How long "Synced at hh:mm" stays up after a successful run.
const Duration syncedBannerWindow = Duration(seconds: 45);

/// Banner for [state] at [now], or null when nothing needs saying (idle with
/// an empty outbox and no recent sync). Returns null for
/// [SyncStatus.disabled]: the shell keeps the offline-only banner for that.
SyncBannerSpec? syncBannerSpec(
  SyncState state, {
  required AppStrings strings,
  required DateTime now,
}) {
  final pending = state.pendingCount;
  switch (state.status) {
    case SyncStatus.disabled:
      return null;
    case SyncStatus.offline:
      return SyncBannerSpec(
        kind: SyncBannerKind.offline,
        text: pending > 0
            ? '${strings.offline} - ${strings.changesWaitingCount(pending)}'
            : strings.offline,
        icon: Icons.cloud_off_outlined,
        tone: BadgeTone.warning,
      );
    case SyncStatus.pushing:
    case SyncStatus.pulling:
      return SyncBannerSpec(
        kind: SyncBannerKind.syncing,
        text: pending > 0
            ? '${strings.syncing}... ${strings.changesWaitingCount(pending)}'
            : '${strings.syncing}...',
        icon: Icons.cloud_sync_outlined,
        tone: BadgeTone.info,
      );
    case SyncStatus.error:
      return SyncBannerSpec(
        kind: SyncBannerKind.error,
        text: 'Sync error: ${state.error ?? 'unknown'}. Tap to retry',
        icon: Icons.sync_problem_outlined,
        tone: BadgeTone.danger,
      );
    case SyncStatus.idle:
      if (pending > 0) {
        return SyncBannerSpec(
          kind: SyncBannerKind.waiting,
          text: strings.changesWaitingCount(pending),
          icon: Icons.cloud_upload_outlined,
          tone: BadgeTone.info,
        );
      }
      final at = state.lastSyncedAt;
      if (at != null && now.difference(at) <= syncedBannerWindow) {
        return SyncBannerSpec(
          kind: SyncBannerKind.synced,
          text: 'Synced at ${AppFormat.time(at)}',
          icon: Icons.cloud_done_outlined,
          tone: BadgeTone.success,
        );
      }
      return null;
  }
}

/// Time left before a synced banner for [state] should hide, or null.
Duration? syncedBannerRemaining(SyncState state, DateTime now) {
  final at = state.lastSyncedAt;
  if (state.status != SyncStatus.idle || state.pendingCount > 0 || at == null) {
    return null;
  }
  final remaining = syncedBannerWindow - now.difference(at);
  return remaining.isNegative ? null : remaining;
}

/// One-line banner in the shell's top safe area, same shape as
/// `OfflineBanner` but driven by a [SyncBannerSpec].
class CloudSyncBanner extends StatelessWidget {
  /// Creates the banner.
  const CloudSyncBanner({super.key, required this.spec, this.onRetry});

  /// What to show.
  final SyncBannerSpec spec;

  /// Called on tap when [SyncBannerSpec.canRetry].
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = spec.tone.resolve(context);
    return Semantics(
      liveRegion: true,
      child: Material(
        color: color.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.22 : 0.14,
        ),
        child: InkWell(
          onTap: spec.canRetry ? onRetry : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(spec.icon, size: 18, color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    spec.text,
                    style: theme.textTheme.labelLarge?.copyWith(color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (spec.canRetry) Icon(Icons.refresh, size: 18, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
